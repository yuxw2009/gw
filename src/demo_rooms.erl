-module(demo_rooms).
-compile(export_all).

-define(NAMEPREFIX,"room_").
-define(COOKIE,"hkxyz").
-define(MAXPARTIES,4).
-define(MAXROOMS,2).
-define(DEMOTIME,330000).

-record(rm, {
	n,		% sequence no
	node,	% node name
	nst,	% node status
	ip,
	udpports,
	name,	% room name
	ver,	% count reboot times
	pid,	% undefined means initializing
	members,
	stime,	% start time
	nick=0	% random no for room No
}).

init([]) ->
	Nodes = start_all_node(?MAXROOMS),
	Rooms = [#rm{n=N,node=Node,nst=created} || {N,Node}<-Nodes],
	timer:send_interval(10000,demo_timer),
	{ok,Rooms,1000}.

handle_info(timeout,RMs) ->
	NRMs = lists:map(fun(RM) -> monitor_1_node(RM) end,RMs),
	Rooms = start_all_room(NRMs),
	{noreply,Rooms};
handle_info({nodedown, DownNode},Rooms) ->
	io:format("node ~p down.~n",[DownNode]),
	{value,RM} = lists:keysearch(DownNode,#rm.node,Rooms),
	NRM = start_room_node(RM#rm{nst=down}),
	timer:send_after(1000,{start_room,DownNode}),
	{noreply,lists:keyreplace(DownNode,#rm.node,Rooms,NRM)};
handle_info({start_room, Node}, Rooms) ->
	{value,RM} = lists:keysearch(Node,#rm.node,Rooms),
	NRM = monitor_1_node(RM),
	NRM2 = make_room_on_node(NRM),
	{noreply,lists:keyreplace(Node,#rm.node,Rooms,NRM2)};
handle_info(demo_timer,Rooms) ->
	user_keep_alive(Rooms),
	{noreply,kick_demo_timeout(Rooms)};
handle_info({From,list},Rooms) ->
	From ! Rooms,
	{noreply,Rooms}.

user_keep_alive([]) ->
	[];
user_keep_alive([#rm{nick=0}=RM|T]) ->
	[RM|user_keep_alive(T)];
user_keep_alive([#rm{pid=Pid,name=Name,members=Membs}=RM|T]) ->
	poll_members(Pid,Name,tl(Membs)),
	[RM|user_keep_alive(T)].

poll_members(_,_,[]) ->
	ok;
poll_members(Pid,Room,[{Uid,_Pos}|T]) ->
	cast_room(Pid,{get_conf,Uid,Room}),
	poll_members(Pid,Room,T).

kick_demo_timeout([]) ->
	[];
kick_demo_timeout([#rm{nick=0}=RM|T]) ->
	[RM|kick_demo_timeout(T)];
kick_demo_timeout([#rm{pid=Pid,nick=Nick,name=Name,stime=Stime}=RM|T]) ->
	Diff = timer:now_diff(now(),Stime) div 1000,
	if Diff > ?DEMOTIME ->
		cast_room(Pid,{clean_room,Name}),
		llog("room ~p@~p timeout",[Nick,Name]),
		[RM#rm{nick=0,members=[]}|kick_demo_timeout(T)];
	true ->
		[RM|kick_demo_timeout(T)]
	end.


handle_call(get_info,_,Rooms) ->
	{reply,Rooms,Rooms};
handle_call(get_room,_From,Rooms) ->
	case lists:keysearch(0,#rm.nick,Rooms) of
		{value,#rm{name=Name,pid=Pid}=RM} ->
			Nick = make_nick(),
			Room1 = RM#rm{nick=Nick,members=[{make_uid(0),chairman}],stime=now()},
			cast_room(Pid,{init_room,{Name,Room1#rm.members}}),
			llog("initiate ~p@~p",[Nick,Name]),
			{reply,{successful,Nick},lists:keyreplace(Name,#rm.name,Rooms,Room1)};
		false ->
			{reply,{failure,out_of_rooms},Rooms}
	end;
handle_call({release_room,Nick},_From,Rooms) ->
	case lists:keysearch(Nick,#rm.nick,Rooms) of
		{value,#rm{name=Name,pid=Pid}=RM} ->
			cast_room(Pid,{clean_room,Name}),
			llog("release room ~p@~p",[Nick,Name]),
			{reply,{successful,[]},lists:keyreplace(Name,#rm.name,Rooms,RM#rm{nick=0,members=[]})};
		false ->
			{reply,{failure,not_exist},Rooms}
	end;
handle_call({get_status,Nick},_From,Rooms) ->
	case lists:keysearch(Nick,#rm.nick,Rooms) of
		{value,#rm{name=Name}=RM} ->
			{reply,{successful,Name},Rooms};
		false ->
			{reply,{failure,not_exist},Rooms}
	end;
handle_call({enter_room, Nick, Sdp},_From, Rooms) ->
	case lists:keysearch(Nick,#rm.nick,Rooms) of
		{value,#rm{pid=Pid,name=Name,members=Membs}=RM} ->
			case memb_enter(Membs) of
				{ok,Pos,Membs2} ->
					cast_room(Pid,{invite_party,Name,{make_uid(Pos),Pos}}),
					Reply = cast_room(Pid,{enter,Name,Pos,make_uid(Pos),Sdp}),
					llog("~p enter room ~p",[Pos,Nick]),
					{reply,Reply,lists:keyreplace(Name,#rm.name,Rooms,RM#rm{members=Membs2})};
				{error,_} ->
					{reply,{failure,out_of_position},Rooms}
			end;
		false ->
			{reply,{failure,not_exist},Rooms}
	end;
handle_call(Msg, _,Rooms) ->
	{reply, ok, Rooms}.

terminate(_,ST) ->
	stop_room_nodes(?MAXROOMS),
	io:format("rooms manager stopped @~p~n",[ST]),
	ok.
% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.


make_nick() ->
	random:uniform(16#ffff).

make_uid(Pos) when is_integer(Pos) ->
	integer_to_list(Pos).

memb_enter(Membs) ->
	case lists:last(Membs) of
		{_,chairman} ->
			{ok,0,Membs++[{make_uid(0),0}]};
		{_,Pos} when Pos>=?MAXPARTIES-1 ->
			{error,out_of_position};
		{_,Pos} ->
			{ok,Pos+1,Membs++[{make_uid(Pos+1),Pos+1}]}
	end.
% ----------------------------------
start() ->
	{ok,_Pid} = my_server:start({local,rooms},?MODULE,[],[]),
	llog:start(),
	ok.

start_all_node(Total) ->
	start_room_nodes({1,Total+1},[]).
start_room_nodes({MaxN,MaxN},Names) ->
	lists:reverse(Names);
start_room_nodes({N,MaxN}, R) ->
	io:format("start node ~p.~n",[N]),
	Name = rname_of(N),
	[_,Node] = string:tokens(atom_to_list(node()),"@"),
	os:cmd("erl -name "++Name++"@"++Node++" -setcookie "++?COOKIE++" -pa ./ebin -detached"),
	start_room_nodes({N+1,MaxN},[{N,nodeof(Name)}|R]).

start_room_node(#rm{node=Node}=RM) ->
	[Name,ND] = string:tokens(atom_to_list(Node),"@"),
	os:cmd("erl -name "++Name++"@"++ND++" -setcookie "++?COOKIE++" -pa ./ebin -detached"),
	RM#rm{nst=created}.

monitor_1_node(#rm{node=Node,nst=created}=RM) ->
	true = monitor_node(Node,true),
	RM#rm{nst=monitored}.

stop_room_nodes(Total) ->
	stop_room_nodes({1,Total+1},[]).
stop_room_nodes({MaxN,MaxN},R) ->
	lists:reverse(R);
stop_room_nodes({N,MaxN}, R) ->
	io:format("stop node ~p.~n",[N]),
	Name = rname_of(N),
	[_,ND] = string:tokens(atom_to_list(node()),"@"),
	WND = list_to_atom(Name++"@"++ND),
	monitor_node(WND,false),
	NR = rpc:call(WND, init, stop, []),
	stop_room_nodes({N+1,MaxN},[NR|R]).

start_all_room(Nodes) ->
	start_meeting_room(Nodes,[]).
start_meeting_room([],RMs) ->
	lists:reverse(RMs);
start_meeting_room([#rm{n=N}=H|T], RMs) ->
	{ROOM_BEGIN_UDP,_} = avscfg:get(wconf_udp_range),
	ROOM_UDP = avscfg:get(room_udp_used),
	HOST = avscfg:get(host_ip),
	WANADDR = avscfg:get(wan_ip),
	io:format("make room on node ~p.~n",[N]),
	UdpRange = {ROOM_BEGIN_UDP+((N-1)*ROOM_UDP),ROOM_BEGIN_UDP+(N*ROOM_UDP)-1},
	NRM = make_room_on_node(H#rm{name=rname_of(N),ver=0,ip=[HOST,WANADDR],udpports=UdpRange}),
	start_meeting_room(T,[NRM|RMs]).

make_room_on_node(#rm{node=WND,name=Name,ver=Ver,nst=monitored,ip=HostIP,udpports={Begin_UDP,End_UDP}}=RM) ->
	case net_adm:ping(WND) of
	pong ->
		{successful,RName,RPid} = rpc:call(WND, man, internal_start, [[Name,HostIP,{Begin_UDP,End_UDP}]]),
		RM#rm{nst=up,ver=Ver+1,name=RName,pid=RPid,members=[]};
	pang ->
		RM#rm{nst=down,pid=undefined,members=[]}
	end;
make_room_on_node(RM) ->
	RM#rm{pid=undefined,members=[]}.

rname_of(No) ->
	?NAMEPREFIX++integer_to_list(No).
rno_of(?NAMEPREFIX++No) ->
	list_to_integer(No).
	

nodeof(Name) ->
	[_,ND] = string:tokens(atom_to_list(node()),"@"),
	WND = list_to_atom(Name++"@"++ND),
	WND.

search_room_1by1([],_UID) ->
	{failure,notfound};
search_room_1by1([{Name,Pid}|T],UID) ->
	case cast_room(Pid,{search_party, Name, UID}) of
		{successful,Info} -> {successful,Info};
		{failure,_} -> search_room_1by1(T,UID)
	end.

cast_room(Room,CMD) when is_pid(Room) ->
	Ref = make_ref(),
	my_server:cast(Room,{{self(),Ref},CMD}),
	receive
		{Ref,Reply} -> Reply
	after 5000 ->
		{failure,room_timeout}
	end.
%
% ----------------------------------
%	Interfaces of manager
%	rpc:called from yaws
% ----------------------------------
%
get_free_rooms() ->
	case my_server:call(rooms,get_room) of
		{successful,No} -> {ok, No};
		{failure,_Reason} -> failed
	end.
release_room(RoomNo) when is_integer(RoomNo),RoomNo=/=0 ->
	case my_server:call(rooms,{release_room,RoomNo}) of
		{successful,_} -> ok;
		{failure,_Reason} -> ok
	end.
enter_room(RoomNo,Sdp) when is_integer(RoomNo),RoomNo=/=0,is_binary(Sdp) ->
	case my_server:call(rooms,{enter_room,RoomNo,Sdp}) of
		{successful,AnswerSDP} -> {ok, AnswerSDP};
		{failure,_Reason} -> failed
	end.
get_status(RoomNo) when is_integer(RoomNo),RoomNo=/=0 ->
	case my_server:call(rooms,{get_status,RoomNo}) of
		{successful,_} -> normal;
		{failure,_Reason} -> release
	end.
