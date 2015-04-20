-module(relay443).
-compile(export_all).

-define(LISTENPORT,55000).
-define(CONNECTTIMEOUT,3000).
-define(GUARDT1,30000).

-record(st, {
	ice,
	wan_ip
}).

-record(pr,{
	id,
	conn = 0,
	t1,
	oice,
	opid,
	aice,
	apid
}).

-record(rlyr, {
	id,
	sock,
	tlink,
	to_pid,
	ice_state,
	peerok = false,
	peer,
	r_srtp,
	r_srtcp,
	c_rcvd = 0,
	c_snt = 0,
	c_drop = 0
}).

-record(tlst, {
	sock,
	buf = <<>>,
	r443,
	up_pid,
	ice_state,
	peerok = false,
	peer,
	c_rcvd = 0,
	c_snt = 0
}).

-record(ice, {
	ufrag,
	pwd
}).

-include("stun.hrl").

r443(Sn,LP,Prs) ->
  receive
	{From,{stun_informations,OIce,AIce}} ->
		From ! {self(),{ok,Sn,LP}},
		{ok,Pid1,Pid2} = make_tcp_relayer(Sn,OIce,AIce),
		r443(Sn+1,LP,[#pr{id=Sn,t1=now(),oice=OIce,aice=AIce,opid=Pid1,apid=Pid2}|Prs]);
	{From, stun_username, UName, Sock} ->
		case match_offer_uname(UName,Prs) of
			{ok,#pr{id=Id,opid=OPid,conn=C}=Pr} ->
				OPid ! {From, stun_check, Sock},
				r443(Sn,LP,lists:keyreplace(Id,#pr.id,Prs,Pr#pr{conn=C+1}));
			false ->
				case match_answer_uname(UName,Prs) of
					{ok,#pr{id=Id,apid=APid,conn=C}=Pr} ->
						APid ! {From, stun_check, Sock},
						r443(Sn,LP,lists:keyreplace(Id,#pr.id,Prs,Pr#pr{conn=C+1}));
					false ->
						r443(Sn,LP,Prs)
				end
		end;
	{From,tcp_closed,Id} ->
		case lists:keysearch(Id,#pr.id,Prs) of
			{value,#pr{opid=From,apid=Peer}} -> Peer ! stop;
			{value,#pr{apid=From,opid=Peer}} -> Peer ! stop;
			false ->void
		end,
		r443(Sn,LP,lists:keydelete(Id,#pr.id,Prs));
	guard_timer ->
		r443(Sn,LP,kick_dead(now(),Prs,[]));
	{From,get_info} ->
		From ! Prs,
		r443(Sn,LP,Prs);
	stop ->
		[{Pid1!stop,Pid2!stop}||#pr{opid=Pid1,apid=Pid2}<-Prs],
		void
  end.

match_offer_uname(_,[]) ->
	false;
match_offer_uname(UName,[#pr{oice=#ice{ufrag=UName}}=Pr|_T]) ->
	{ok,Pr};
match_offer_uname(UName,[_Pr|T]) ->
	match_offer_uname(UName,T).

match_answer_uname(_,[]) ->
	false;
match_answer_uname(UName,[#pr{aice=#ice{ufrag=UName}}=Pr|_T]) ->
	{ok,Pr};
match_answer_uname(UName,[_Pr|T]) ->
	match_answer_uname(UName,T).

kick_dead(_,[],NPrs) ->
	lists:reverse(NPrs);
kick_dead(Now,[#pr{conn=2}=Pr|T],NPrs) ->
	kick_dead(Now,T,[Pr|NPrs]);
kick_dead(Now,[#pr{t1=T1,opid=Pid1,apid=Pid2}=Pr|T],NPrs) ->
	Diff = timer:now_diff(Now,T1) div 1000000,
	if Diff > 33 ->
		Pid1 ! Pid2 ! stop,
		kick_dead(Now,T,NPrs);
	true ->
		kick_dead(Now,T,[Pr|NPrs])
	end.

% ------------------------------------
tcp_relayer(#rlyr{id=Id,to_pid=To,c_rcvd=RC,c_snt=SC}=ST) ->
  receive
	{add_peer,Pid} ->
		tcp_relayer(ST#rlyr{to_pid=Pid});
	{From, stun_check, Sock2} ->
		From ! {self(),config_tlink,ST#rlyr.ice_state},
		tcp_relayer(ST#rlyr{tlink=From,sock=Sock2});
	{From, stun_locked, _} ->
		tcp_relayer(ST#rlyr{peerok=true});
	{relay_send,Bin} ->
		if ST#rlyr.peerok ->
			send_tcp(ST#rlyr.sock,Bin),
			tcp_relayer(ST#rlyr{c_snt=SC+1});
		true ->
			#rlyr{c_drop=DC} = ST,
			tcp_relayer(ST#rlyr{c_drop=DC+1})
		end;
	{_,tcp_received,Bin} ->
		To ! {relay_send,Bin},
		tcp_relayer(ST#rlyr{c_rcvd=RC+1});
	{_,tcp_closed,Sock} ->
		r443 ! {self(), tcp_closed, Id},
		ok;
	stop ->
		TPid = ST#rlyr.tlink,
		if is_pid(TPid) -> TPid ! stop;
		true -> pass end;
	{From,get_info} ->
		From ! ST,
		tcp_relayer(ST)
  end.


send_tcp(undefined,_) ->
	pass;
send_tcp(Sock,Response) ->
	Len = size(Response),
	gen_tcp:send(Sock, <<Len:16/big,Response/binary>>).

% ------------------------------------
listen(R443,Port) ->
	{ok, LSock} = gen_tcp:listen(Port, [binary, {packet, 0}, {active, true}]),
	listener(R443,LSock).


listener(R443,LSock) ->
	case gen_tcp:accept(LSock,3000) of
		{ok, Sock} ->
			{ok,{Addr,Port}} = inet:peername(Sock),
			Link=spawn(fun() -> tcp_link(#tlst{r443=R443,sock=Sock,peer={Addr,Port}}) end),
			ok = gen_tcp:controlling_process(Sock,Link),
			ok;
		{error,_} ->
			pass
	end,
	receive
		stop -> ok
	after 0 ->
		listener(R443,LSock)
	end.

tcp_link(#tlst{sock=Sock,up_pid=UP}=ST) ->
  receive
	{tcp,Sock,Bin} ->
		ST2=processTCP(Bin,ST),
		tcp_link(ST2);
	{From,config_tlink,ICE} ->
		timer:send_after(300,stun_bindreq),
		tcp_link(ST#tlst{up_pid=From,ice_state=ICE});
	stun_bindreq ->
		#tlst{sock=Sock,ice_state=ICE}=ST,
		{ok,{request,Request},_} = stun:handle_msg(bindreq,ICE),
		send_tcp(Sock,Request),
		timer:send_after(500,stun_bindreq),
		tcp_link(ST);
	{tcp_closed,Sock} ->
		UP ! {self(),tcp_closed,Sock},
		ok;
	stop ->
		gen_tcp:close(Sock),
		ok
  end.

processTCP(<<>>, ST) ->
	ST;
processTCP(<<D:8>>,#tlst{buf= Bin1}=ST) ->
	ST#tlst{buf= <<Bin1/binary,D:8>>};
processTCP(<<PLen:16,PKT/binary>> =Bin,#tlst{buf= <<>>}=ST) ->
	if size(PKT)<PLen ->
		ST#tlst{buf=Bin};
	true ->
		<<PL1:PLen/binary,Rest/binary>> = PKT,
		processTCP(Rest,processPKT(PL1,ST))
	end;
processTCP(Bin2,#tlst{buf= Bin1}=ST) when Bin1=/= <<>> ->
	processTCP(<<Bin1/binary,Bin2/binary>>, ST#tlst{buf= <<>>}).


processPKT(<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin,
		   #tlst{r443=R443,sock=Sock,peerok=false,ice_state=undefined}=ST) ->
	case stun_codec:decode(Bin) of
		{ok, #stun{'USERNAME'=UN}, <<>>} -> 
			MyUN = get_my_uname(UN),
			R443 ! {self(), stun_username, MyUN, Sock};
		_ -> pass
	end,
	ST;
processPKT(<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin,
		   #tlst{sock=Sock,up_pid=UP,peer={Addr,Port},ice_state=ICE}=ST) when ICE=/=undefined ->
	case stun:handle_msg({udp_receive,Addr,Port,Bin},ICE) of
		{ok,{request,Response},NewICE} ->
			send_tcp(Sock,Response),
			ST#tlst{ice_state=NewICE};
		{ok,response,NewICE} ->
			if not ST#tlst.peerok ->
				UP ! {self(),stun_locked,NewICE#st.wan_ip},
				ST#tlst{peerok=true,peer=NewICE#st.wan_ip,ice_state=NewICE};
			true -> ST end;
		R ->
			ST
	end;
processPKT(Bin,#tlst{up_pid=UP,c_rcvd=RC}=ST) when is_pid(UP) ->	%% no packet before stun, actually.
	UP ! {self(),tcp_received, Bin},
	ST#tlst{c_rcvd=RC+1};
processPKT(Bin,ST) ->												%% will never happenned.
	ST.

make_tcp_relayer(Id,OIce,AIce) ->
	Pid1 = spawn(fun()->tcp_relayer(#rlyr{id=Id,ice_state=#st{ice={controlled, "2",AIce,OIce}}}) end),
	Pid2 = spawn(fun()->tcp_relayer(#rlyr{id=Id,ice_state=#st{ice={controlling,"2",OIce,AIce}}}) end),
	Pid1 ! {add_peer,Pid2},
	Pid2 ! {add_peer,Pid1},
	{ok,Pid1,Pid2}.

get_my_uname(Un2) ->
	Len = size(Un2),
	{_,Un1} = split_binary(Un2,Len div 2 + 1),
	binary_to_list(Un1).

get_port2(_) ->
	{ok,?LISTENPORT,?LISTENPORT,undefined,undefined}.
% ------------------------------------
start() ->
	R443 = spawn(fun() -> r443(1,?LISTENPORT,[]) end),
	register(r443,R443),
	timer:send_interval(?GUARDT1,R443,guard_timer),
	Listener = spawn(fun() -> listen(R443,?LISTENPORT) end),
	register(listener,Listener).

stop() ->
	listener ! stop,
	r443 ! stop.
