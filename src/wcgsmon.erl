-module(wcgsmon).
-compile(export_all).
%-export([start/0, get_count/0, get_node/0]).
-define(BASE_DIR, "../..").

-record(st,{last_packets=[],count=0,mgside_peerip=sets:new(), unexpected_mgsid_peer=[],normal_mgip=sets:new()}).

get_state() ->
    ?MODULE ! {get_state, self()},
	receive
	    {value, R} -> R
		after 2000 -> timeout
	end.
	
get_node() ->
    ?MODULE ! {get_node, self()},
	receive
	    {value, R} -> R
		after 2000 -> timeout
	end.

get_normal_mgs()->
    St= get_state(),
    sets:to_list(St#st.normal_mgip).

get_mgs()->
    St= get_state(),
    sets:to_list(St#st.mgside_peerip).

get_unexp()->
    St= get_state(),
    St#st.unexpected_mgsid_peer.

stop_node(Nd) when is_list(Nd)-> stop_node(list_to_atom(Nd));
stop_node(Nd)-> ?MODULE ! {stop_node,Nd}.
stop_monitor(Wcg)->    ?MODULE ! {stop_monitor,Wcg}.

add_monitor(Wcg)->    add_monitor(Wcg,?BASE_DIR++"/gw_run/").
add_monitor(Wcg,BaseDir)->    ?MODULE ! {add_monitor,Wcg,BaseDir}.

start() ->start(avscfg:get(wcgs)).
start(Wcgs) ->
      NodeDirs=[start_wcg(Wcg)||Wcg<-Wcgs],
      case whereis(?MODULE) of
      	undefined->	register(?MODULE, spawn(fun() -> init(NodeDirs) end));
      	_-> void
      end.

start_wcg(Wcg) when is_atom(Wcg)-> start_wcg(atom_to_list(Wcg));
start_wcg(Wcg) when is_list(Wcg)->  start_wcg(Wcg,?BASE_DIR++"/gw_run/");
start_wcg({NodeName, Base_dir})-> start_wcg(NodeName,Base_dir).    

start_wcg(Wcg,Base) when is_atom(Wcg)-> start_wcg(atom_to_list(Wcg),Base);
start_wcg(Wcg,Base) when is_list(Wcg)->
	[_,AtNode] = string:tokens(atom_to_list(node()),"@"),
      COOKIE = atom_to_list(erlang:get_cookie()),
      NodeStr= Wcg++"@"++AtNode,
    CodePath = Base++"/ebin",
    WorkPath = Base++"/applications",
    {ok,Pwd}=file:get_cwd(),
    c:cd(WorkPath),
	Cmd = "erl -name "++NodeStr++" -setcookie "++COOKIE++" -pa "++ CodePath++" +K true -s voip -detached",
	os:cmd(Cmd),
	c:cd(Pwd),
	{list_to_atom(NodeStr),Base}.

restart_node(Node,BaseDir)->
	[Wcg,_] = string:tokens(atom_to_list(Node),"@"),
      start_wcg(Wcg,BaseDir).

init(NodeDirs) ->
    llog:start(),
    timer:send_after(5000,{monitor_it,NodeDirs}),
    loop(NodeDirs,#st{}).
	
loop(NodeDirs,St=#st{count=Count,last_packets=LP,mgside_peerip=MgIps,unexpected_mgsid_peer=UnexpPeers,normal_mgip=NormMgIps}) ->
    receive
	    {nodedown, Node} ->
	        io:format("node:~p down~n",[Node]),
	        case lists:keysearch(Node,1,NodeDirs) of
	        	{value,{Node,Dir}}->
			        log(Node,LP),
			        restart_node(Node,Dir),
					timer:send_after(5000, {monitor_it,[{Node,Dir}]});
				_-> void
			end,
			loop(NodeDirs,St#st{count=Count+1});
		{get_state, From} ->
		    From ! {value, St},
			loop(NodeDirs, St);
	    {get_node, From} ->
		    From ! {value, NodeDirs},
			loop(NodeDirs, St);
		{stop_node,Wcg}->
		    rpc:call(Wcg,init,stop,[]),
		    loop(lists:keydelete(Wcg,1,NodeDirs),St);
		{stop_monitor,Wcg}->
		    loop( lists:keydelete(Wcg,1,NodeDirs),St);
		{add_monitor,WcgName,BaseDir}->
			NodeDir =start_wcg(WcgName,BaseDir),
		    timer:send_after(5000,{monitor_it, [NodeDir]}),
		    loop([NodeDir| NodeDirs--[NodeDir]],St);
		{last,Node,Packet,_From}->
		    loop(NodeDirs, St#st{last_packets=lists:keystore(Node,1,LP,{Node, Packet}) });
		{unexpected_mgsid_peer,Info}->
		    loop(NodeDirs, St#st{unexpected_mgsid_peer=[Info|UnexpPeers]});
		{mgside_peerip,Info}->
		    loop(NodeDirs, St#st{mgside_peerip=sets:add_element(Info,MgIps)});
		{normal_mgip,NormalMgIp}->
		    loop(NodeDirs, St#st{normal_mgip=sets:add_element(NormalMgIp,NormMgIps)});
		{monitor_it,NodeDirs_mon} ->
		    [monitor_node(Node,true)||{Node,_}<-NodeDirs_mon],
		    io:format("monitor ~p~n", [NodeDirs_mon]),
			loop(NodeDirs, St);
	      _Other->
	          io:format("."),
	          loop(NodeDirs,St)
	end.
	
log(Node,LP)->
    Msg = proplists:get_value(Node,LP),
	{ok, Handle} = file:open("monitors.log", [append]),
	io:fwrite(Handle, llog:ts() ++ " ~p down Msg:~p~n", [Node,Msg]),
	file:close(Handle).
	
record_last_msg(Node,Msg)->
    case whereis(?MODULE) of
    	undefined-> void;
    	P->  	    
    	    P! {last,Node,Msg,self()}
    	end.

monitor_pid()->  whereis(?MODULE).

llog(F,P) ->
	case whereis(llog) of
		undefined ->
		    llog:start(); 
		_Pid -> ok
	end,
	llog ! {self(), F, P}.

