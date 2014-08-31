-module(wcgsmon).
-compile(export_all).
%-export([start/0, get_count/0, get_node/0]).
-define(BASE_DIR, "/home/wcg/run/").
-define(EBIN_DIR, "/home/wcg/gw_git0/ebin/").

-record(st,{last_packets=[],
                   status=working,
			count=0,
			mgside_peerip=sets:new(), 
			unexpected_mgsid_peer=[],
			normal_mgip=sets:new(),
			codec_st=up,
			ccalls=[]
			}).

start()->
    Wcg_node_nums=rpc:call(avscfg:get(www),  wcg_disp, get_all_wcgs, []),
    Wcgs=[Wcg||{Wcg,_N}<-Wcg_node_nums],
    start(Wcgs).
start(Wcgs)->
    NameDirs0= [get_name_dir(Wcg) || Wcg<-Wcgs],
    NameDirs=[ND||ND<-NameDirs0, ND=/= node_down],
    start0(NameDirs).
add_node(Node)->
    case get_name_dir(Node) of
    node_down-> void;
    {Name,Dir}->  add_monitor(Name,Dir)
    end.
delete_node(Node)->
    stop_monitor(Node).
get_name_dir(Wcg_node)->
    [Name,_Host]=string:tokens(atom_to_list(Wcg_node), "@"),
    case rpc:call(Wcg_node,file,get_cwd,[]) of
    {ok,Dir}-> {Name,Dir};
    _-> node_down
    end.
    
get(Member)->
    R_attrs=record_info(fields,st),
    case get_state() of
    timeout->
        timeout;
    St->
        StPls=lists:zip([st|R_attrs],tuple_to_list(St)),
        lists:keyfind(Member,1,StPls)
    end.
    
get_state() ->
    send( {get_state, self()}),
	receive
	    {value, R} -> R
		after 2000 -> timeout
	end.
	
get_node() ->
    send({get_node, self()}),
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
stop_node(Nd)-> send({stop_node,Nd}).
stop_monitor(Node)->   send( {stop_monitor,Node}).


%%------------------------------------------------------------------------------------------------------
add_monitor(WcgName) when is_atom(WcgName)->  add_monitor(atom_to_list(WcgName));
add_monitor(WcgName)->    add_monitor(WcgName,?BASE_DIR++WcgName).
add_monitor(WcgName,BaseDir)->    send({add_monitor,WcgName,BaseDir}).


start0(Wcgs) ->
      NodeDirs=[start_wcg(Wcg)||Wcg<-Wcgs],
      case whereis(?MODULE) of
      	undefined->	register(?MODULE, spawn(fun() -> init(NodeDirs) end));
      	_-> void
      end.

start_wcg(WcgName) when is_atom(WcgName)-> start_wcg(atom_to_list(WcgName));
start_wcg(WcgName) when is_list(WcgName)->  start_wcg(WcgName,?BASE_DIR++WcgName);
start_wcg({WcgName, Base_dir})-> start_wcg(WcgName,Base_dir).    

start_wcg(Wcg,WorkPath) when is_atom(Wcg)-> start_wcg(atom_to_list(Wcg),WorkPath);
start_wcg(Wcg,WorkPath) when is_list(Wcg)->
	[_,AtNode] = string:tokens(atom_to_list(node()),"@"),
      COOKIE = atom_to_list(erlang:get_cookie()),
      NodeStr= Wcg++"@"++AtNode,
    {ok,Pwd}=file:get_cwd(),
    c:cd(WorkPath),
	Cmd = "erl -name "++NodeStr++" -setcookie "++COOKIE++" -pa "++ ?EBIN_DIR++" -pa . "++" +K true -s voip -detached",
	os:cmd(Cmd),
	c:cd(Pwd),
	{list_to_atom(NodeStr),WorkPath}.

restart_node(Node,BaseDir)->
	[Wcg,_] = string:tokens(atom_to_list(Node),"@"),
      start_wcg(Wcg,BaseDir).

get_ccalls()->
    St=get_state(),
    St#st.ccalls.
    
init(NodeDirs) ->
    timer:send_after(5000,{monitor_it,NodeDirs}),
    loop(NodeDirs,#st{}).
	
loop(NodeDirs,St=#st{count=Count,last_packets=LP,mgside_peerip=MgIps,unexpected_mgsid_peer=UnexpPeers,normal_mgip=NormMgIps,
				ccalls=Ccalls}) ->
    receive
	        {nodedown, 'gw_test1@58.221.60.37'} ->
		        io:format("node: 'gw_test1@58.221.60.37' down write log to gw_test1.log~n"),
		        {Node,Dir}={'gw_test1@58.221.60.37',"/home/wcg/gw_test/applications"},
			  restart_node(Node,Dir),
			  timer:send_after(5000, {monitor_it,[{Node,Dir}]}),
		        utility:log("gw_test1.log", "gw_test1 down, ccalls is: ~n~p~n", [Ccalls]),
                     loop(NodeDirs,St#st{ccalls=[]});
	        {nodedown, Node} ->
	            io:format("node:~p down~n",[Node]),
	            case lists:keysearch(Node,1,NodeDirs) of
	        	{value,{Node,Dir}}->
			    log(Node,LP),
			    restart_node(Node,Dir),
			    timer:send_after(5000, {monitor_it,[{Node,Dir}]}),
			    timer:send_after(1000*60*3,{restore_normal}),
			    loop(NodeDirs,St#st{count=Count+1,status=justdown});
			_-> 
			    loop(NodeDirs,St)
			end;
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
	      {restore_normal}-> loop(NodeDirs,St#st{status=working});
	      {ccalls,Info={badrpc,_}} when St#st.codec_st =/=down ->
	          loop(NodeDirs,St#st{codec_st=down,ccalls=[Info|Ccalls]});
	      {ccalls,Info}->
	          if St#st.codec_st == up-> 
	                NewCcalls = if length(Ccalls)>10000->  
	                                       [_last|T]= lists:reverse(Ccalls),
	                                       [Info|lists:reverse(T)];
	                                true-> [Info|Ccalls]
	                                end,
	                loop(NodeDirs,St#st{ ccalls=NewCcalls});
	              true-> loop(NodeDirs,St)
	          end;
	      _Other->
	          io:format("."),
	          loop(NodeDirs,St)
	end.
	
log(Node,LP)->
    Msg = proplists:get_value(Node,LP),
	{ok, Handle} = file:open("monitors.log", [append]),
	io:fwrite(Handle, llog:ts() ++ " ~p down Msg:~p~n", [Node,Msg]),
	file:close(Handle).
	
record_last_msg(Node,Msg)-> send({last,Node,Msg,self()}).

monitor_pid()->  whereis(?MODULE).

send(Info)->
    case whereis(?MODULE) of
    	undefined-> void;
    	P->  	    
    	    P! Info
    	end.
    
llog(F,P) ->
	case whereis(llog) of
		undefined ->
		    llog:start(); 
		_Pid -> ok
	end,
	llog ! {self(), F, P}.


