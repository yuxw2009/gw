-module(man).
-compile(export_all).

-define(NAMEPREFIX,"room_").
-define(MAXCHAIRS,4).
-define(MAXPARTIES,7).

-define(ROOM_N,1).
-define(WEB_BEGIN_UDP_RANGE,55010).
-define(WEB_END_UDP_RANGE,55014).
-define(HOST,"10.61.34.51").
-define(POOLTIME,30000).

-record(st,{
	name,
	ver,	% count room down times
	hostip,
	udp_range,
	room,
	ref,
	pool_timer,
	pools,
	chairs,
	parties
}).

init([[Name,HostIP,{PortBegin,PortEnd}]]) ->
	{_,Room} = meeting_room:start(Name),
	Ref = erlang:monitor(process,Room),
	{ok,PT} = my_timer:send_interval(?POOLTIME,pool_timer),
	{ok,#st{name=Name,ver=0,hostip=HostIP,udp_range={PortBegin,PortEnd},room=Room,ref=Ref,pool_timer=PT,pools=[],chairs=[],parties=[]}}.

handle_call({rtp_report,Session,{stun_locked,RTP}},_From,ST) ->
	{reply,ok,ST}.

handle_cast({From,{init_room,{Name,Members}}},#st{name=Name,chairs=[]}=ST) ->
	reply_room(From,{successful,Name}),
	{noreply,ST#st{chairs=lists:keysort(2,Members)}};
handle_cast({From,{clean_room,Name}},#st{name=Name,room=Room,parties=Parties}=ST) ->
	meeting_room:leave(Room,{all,all}),
	lists:map(fun(X)->my_server:cast(X,stop) end, [RTP||{_,RTP,_}<-Parties]),
	reply_room(From,{successful,[]}),
	{noreply,ST#st{chairs=[],parties=[]}};
handle_cast({From,{invite_party,Name,{Uid,Chair}}},#st{name=Name,chairs=Chairs,parties=Prts}=ST) ->
	if Chair<?MAXPARTIES ->
		case lists:keysearch(Chair,3,Prts) of
			false ->
				NewChairs = lists:keysort(2,lists:keystore(Chair,2,Chairs,{Uid,Chair})),
				reply_room(From,{successful,NewChairs}),
				{noreply,ST#st{chairs=NewChairs}};
			{value,_} ->
				reply_room(From,{successful,Chairs}),
				{noreply,ST}
		end;
	true ->
		reply_room(From,{failure,out_of_chair}),
		{noreply,ST}
	end;
handle_cast({From,{enter,Name,Chair,UID,SDP}},#st{name=Name,room=Room,chairs=Chairs,parties=Prts,pools=Pools}=ST) ->
    case {lists:keysearch(UID,1,Chairs), lists:keysearch(UID,1,Prts)} of
		{{value,{_,Chair}},false} ->
			SessId = make_session_id(Name,UID),
			case wkr:processCONF(SDP,Room,SessId,[ST#st.hostip,ST#st.udp_range]) of
				{successful,RTP,_,AnsSDP} ->
					NewPools = lists:keystore(UID,2,Pools,{Name,UID,now()}),
					meeting_room:enter(Room,{Chair,RTP}),
					reply_room(From,{successful,AnsSDP}),
					{noreply,ST#st{parties=[{UID,RTP,Chair}|Prts],pools=NewPools}};
				{failure,Reason} ->
					reply_room(From,{failure,Reason}),
					{noreply,ST}
			end;
		{_, {value,_}} ->	% chairs return false or Chair is not-match
            reply_room(From,{failure,uid_already_exist}),
            {noreply,ST};
        {_, _} ->
            reply_room(From,{failure,access_deny}),
			{noreply,ST}
    end;
handle_cast({From,{leave,Name,UID}},#st{name=Name,room=Room,parties=Prts,pools=Pools}=ST) ->
    case lists:keysearch(UID,1,Prts) of
        {value,{_,RTP,Chair}} ->
        	rtp:stop(RTP),
        	NewPools = lists:keydelete(UID,2,Pools),
        	meeting_room:leave(Room,{Chair,RTP}),
        	reply_room(From,{successful,length(Prts)-1}),
			{noreply,ST#st{parties=lists:keydelete(UID,1,Prts),pools=NewPools}};
        false ->
        	reply_room(From,{failure,uid_not_exist}),
        	{noreply,ST}
    end;
handle_cast({From,{get_conf,Usr,Name}},#st{name=Name,pools=Pools,chairs=Chairs,parties=Prts}=ST) ->
	S1 = [{Uid,Chair,occupy}||{Uid,Chair}<-Chairs,is_integer(Chair)],
	S2 = lists:foldr(fun({Uid,_,Chair},S12) -> lists:keystore(Uid,1,S12,{Uid,Chair,busy}) end, S1, Prts),
	NewPools = lists:keyreplace(Usr,2,Pools,{Name,Usr,now()}),
	reply_room(From,{successful,lists:keysort(2,S2)}),		% sorted by chair
	{noreply,ST#st{pools=NewPools}};
handle_cast({From,{search_party, Name, UID}},#st{name=Name,chairs=Chairs}=ST) ->
	Reply = case lists:keysearch(UID,1,Chairs) of
			{value,{_,Chair}} ->
				case lists:keysearch(chairman,2,Chairs) of
					{value,{Chairman,_}} -> {successful,{Name,Chair,Chairman}};
					false -> {successful,{Name,Chair,""}}	%todo: if room crash and rebuilt, there no chairman
				end;				
			false ->
				{failure,notfound}
		end,
	reply_room(From,Reply),
	{noreply,ST}.

handle_info(pool_timer,#st{pools=Pools}=ST) ->
	NewPools = kick_broken(Pools),
	{noreply,ST#st{pools=NewPools}};
handle_info({link_broken,Name,UID},#st{name=Name,room=Room,parties=Prts}=ST) ->
    NewPrts = case lists:keysearch(UID,1,Prts) of
        	{value,{_,RTP,Chair}} ->
        		rtp:stop(RTP),
        		meeting_room:leave(Room,{Chair,RTP}),
				lists:keydelete(UID,1,Prts);
        	false ->
	        	Prts
    	end,
	{noreply,ST#st{parties=NewPrts}};
handle_info({'DOWN',_Ref,process,Room1,_Reason},#st{name=Name,ver=Ver,room=Room1,parties=Parties}=ST) ->
	llog("~p down.",[Name]),
	lists:map(fun(X)->my_server:cast(X,stop) end, [RTP||{_,RTP,_}<-Parties]),
	erl_vp8:xenc(0,<<>>,0,1,0),
	erl_vp8:xdtr(0,0),	% 0=enc
	lists:map(fun(N) -> erl_vp8:xdtr(N,1) end, lists:seq(0,?MAXCHAIRS-1)),
	%% restore the crashed room
	{_,Room} = meeting_room:start(Name),
	Ref = erlang:monitor(process,Room),
	{noreply,ST#st{room=Room,ver=Ver+1,ref=Ref,pools=[],parties=[]}};
handle_info({From,list},ST) ->
	From ! ST,
	{noreply,ST};
handle_info(Msg,ST) ->
	llog("room ~p unknow message ~p",[ST#st.name, Msg]),
	{noreply,ST}.

terminate(_Reason,_ST) ->
	ok.	
	

% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

make_session_id(Name,UID) ->
	Name++"_"++UID.

kick_broken([]) ->
	[];
kick_broken([{Name,Uid,LastTime}|T]) ->
	Diff = timer:now_diff(now(),LastTime) div 1000,
	if Diff > ?POOLTIME ->
		self() ! {link_broken, Name, Uid},
		kick_broken(T);
	true ->
		[{Name,Uid,LastTime}|kick_broken(T)]
	end.

reply_room({From,Ref},Reply) ->
	From ! {Ref,Reply}.

% ----------------------------------
internal_start([Name,HostIP,UDP_RANGE]) ->
	{ok,Pid} = my_server:start(?MODULE,[[Name,HostIP,UDP_RANGE]],[]),
	erlang:monitor(process,Pid),
	register(room_keeper,Pid),
	my_timer:start(),
	llog:start(),
	{successful,Name,Pid}.

start() ->
	Name = ?NAMEPREFIX ++ integer_to_list(?ROOM_N),
	{ok,Pid} = my_server:start(?MODULE,[[Name,?HOST,{?WEB_BEGIN_UDP_RANGE,?WEB_END_UDP_RANGE}]],[]),
	erlang:monitor(process,Pid),
	register(room_keeper,Pid).