-module(rooms).
-compile(export_all).

-define(NAMEPREFIX,"room_").
-define(MAXROOMS,2).

-record(rm, {
	n,		% sequence no
	node,	% node name
	nst,	% node status
	ip,
	udpports,
	name,	% room name
	ver,	% count reboot times
	pid,	% undefined means initializing
	members
}).

init([]) ->
	Nodes = start_all_node(?MAXROOMS),
	Rooms = [#rm{n=N,node=Node,nst=created} || {N,Node}<-Nodes],
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
handle_info({From,list},Rooms) ->
	From ! Rooms,
	{noreply,Rooms}.

handle_call({start_conf, ChairMan, Members},_From,Rooms) ->
	case lists:keysearch([],#rm.members,Rooms) of
		{value,#rm{name=Name,pid=Pid}=RM} ->
			Room1 = RM#rm{members=[{ChairMan,chairman}|Members]},
			cast_room(Pid,{init_room,{Name,Room1#rm.members}}),
			{reply,{successful,Name},lists:keyreplace(Name,#rm.name,Rooms,Room1)};
		false ->
			{reply,{failure,out_of_rooms},Rooms}
	end;
handle_call({stop_conf,ChairMan,Name},_From,Rooms) ->
	case lists:keysearch(Name,#rm.name,Rooms) of
	{value,#rm{pid=Pid,members=Members}=RM} ->
		case lists:keysearch(chairman,2,Members) of
			{value,{Man,_}} ->
				if Man == ChairMan ->
					cast_room(Pid,{clean_room,Name}),
					{reply,{successful,[]},lists:keyreplace(Name,#rm.name,Rooms,RM#rm{members=[]})};
				true ->
					{reply,{failure,not_allowed},Rooms}
				end;
			false ->
				{reply,{failure,invalid_command},Rooms}
		end;
	false ->
		{reply,{failure,not_exist},Rooms}
	end;
handle_call({transfer,To,CMD}, _From, Rooms) ->
	case lists:keysearch(To,#rm.name,Rooms) of
    	{value,#rm{members=[]}} ->
    		{reply,{failure,not_exist},Rooms};
    	{value,#rm{pid=Pid}} ->
    		Reply = cast_room(Pid,CMD),
    		{reply,Reply,Rooms};
    	false ->
    		{reply,{failure,not_exist},Rooms}
    end;
handle_call({search_room, UID},_From, Rooms) ->
	UsedRooms = [{Name,Pid}||#rm{name=Name,pid=Pid,members=Members}<-Rooms,Members=/=[]],
	Reply = search_room_1by1(UsedRooms,UID),
	{reply,Reply,Rooms}.

terminate(_,ST) ->
	stop_room_nodes(?MAXROOMS),
	io:format("rooms manager stopped @~p~n",[ST]),
	ok.
% ----------------------------------
start() ->
	{ok,_Pid} = my_server:start({local,rooms},?MODULE,[],[]),
	ok.

start_all_node(Total) ->
	start_room_nodes({1,Total+1},[]).
start_room_nodes({MaxN,MaxN},Names) ->
	lists:reverse(Names);
start_room_nodes({N,MaxN}, R) ->
	io:format("start node ~p.~n",[N]),
	Name = rname_of(N),
	COOKIE = atom_to_list(erlang:get_cookie()),
	os:cmd("erl -sname "++Name++" -setcookie "++COOKIE++" -pa ./ebin -detached"),
	start_room_nodes({N+1,MaxN},[{N,nodeof(Name)}|R]).

start_room_node(#rm{node=Node}=RM) ->
	[Name,_ND] = string:tokens(atom_to_list(Node),"@"),
	COOKIE = atom_to_list(erlang:get_cookie()),
	os:cmd("erl -sname "++Name++" -setcookie "++COOKIE++" -pa ./ebin -detached"),
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
	list_to_integer(No);
rno_of(_) -> 0. 	% error


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

stop_all(N) ->
	rooms ! sleep,
	stop_room_nodes(N).
%
% ----------------------------------
%	Interfaces of manager
%	rpc:called from yaws
% ----------------------------------
%
start_conf(ChairMan, MembersInfo) when is_integer(ChairMan) ->		%% MembersInfo = [{Uuid,Position}]
	case my_server:call(rooms,{start_conf, integer_to_list(ChairMan), [{integer_to_list(Uid),Posi}||{Uid,Posi}<-MembersInfo]}) of
		{successful,Room} -> {ok, Room};
		{failure,Reason} -> {failed, Reason}
	end.
stop_conf(ChairMan,RoomNo) when is_integer(ChairMan) ->
	case my_server:call(rooms,{stop_conf,integer_to_list(ChairMan),RoomNo}) of
		{successful,_} -> ok;
		{failure,_Reason} -> ok
	end.
	
invite_to_room(RoomNo,Uuid,Position) when is_integer(Uuid),is_integer(Position) ->
	my_server:call(rooms,{transfer,RoomNo,{invite_party,RoomNo,{integer_to_list(Uuid),Position}}}),
	ok.
query_ongoing_room(Uuid) when is_integer(Uuid) ->
	case my_server:call(rooms,{search_room,integer_to_list(Uuid)}) of
		{successful,{RoomNo,Position,Chairman}} -> {ok, RoomNo, list_to_integer(Chairman), Position};
		{failure,_Reason} -> room_not_exist
	end.

% ---- transfer cmd are send_to/reply_from 'room_keeper' ----
enter_room(RoomNo, Uuid, Position, Sdp) when is_integer(Uuid),is_integer(Position) ->
	case my_server:call(rooms,{transfer,RoomNo,{enter,RoomNo,Position,integer_to_list(Uuid),Sdp}}) of
		{successful,AnswerSDP} -> {ok, AnswerSDP};
		{failure,Reason} -> {failed, Reason}
	end.
leave_room(RoomNo, Uuid) when is_integer(Uuid) ->
	case my_server:call(rooms,{transfer,RoomNo,{leave,RoomNo,integer_to_list(Uuid)}}) of
		{successful,_} -> ok;
		{failure,Reason} -> io:format("~p leave room failed: ~p~n",[Uuid,Reason]),ok
	end.
get_room_status(Uuid, RoomNo) when is_integer(Uuid) ->
	case my_server:call(rooms,{transfer,RoomNo,{get_conf,integer_to_list(Uuid),RoomNo}}) of
		{successful, RoomStatus} ->		%% RoomStatus = [{uuid:UUID, position:Position, status:Status}] 
			io:format("room ~p status: ~p~n", [RoomNo,RoomStatus]),
			{ok, [{list_to_integer(U),P,S}||{U,P,S}<-RoomStatus]};
		{failure, Reason} ->
			io:format("room status error: ~p~n",[Reason]),
			{ok,[]}
	end.

% ---- manager command -------------
get_all_rooms() ->
	rooms ! {self(),list},
	Reply = receive
			  Rooms -> [{N,Name,NodeSt,Ver}||#rm{n=N,nst=NodeSt,name=Name,ver=Ver}<-Rooms]
			after 3000 -> []
			end,
	{ok,Reply}.
restart_room(Name) when is_list(Name) ->	% RoomNo is name, for example: "room_1"
	N = rno_of(Name),
	if N>0 andalso N=<?MAXROOMS ->
		[_,ND] = string:tokens(atom_to_list(node()),"@"),
		WND = list_to_atom(Name++"@"++ND),
		rpc:call(WND, init, stop, []);	% ok.
	true -> pass
	end.
