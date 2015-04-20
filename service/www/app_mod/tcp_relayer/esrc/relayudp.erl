-module(relayudp).
-compile(export_all).

-define(PORTRANGE,{50000,51099}).   % range is even number
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
    dest,
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
    bindsent = 0,
    c_rcvd = 0,
    c_snt = 0
}).

-record(ice, {
    ufrag,
    pwd
}).

-include("stun.hrl").

rUDP(Sn,LP,Prs) ->
  receive
    {From,{stun_informations,OIce,AIce}} ->
        From ! {self(),{ok,Sn,udp_port_man()}},
        {ok,Pid1,Pid2} = make_udp_relayer(Sn,OIce,AIce),
        rUDP(Sn+1,LP,[#pr{id=Sn,t1=now(),oice=OIce,aice=AIce,opid=Pid1,apid=Pid2}|Prs]);
    {From, stun_username, UName, Sock, {Addr,Port}} ->
        case match_offer_uname(UName,Prs) of
            {ok,#pr{id=Id,opid=OPid,conn=C}=Pr} ->
                OPid ! {From, stun_check, Sock, {Addr,Port}},
                rUDP(Sn,LP,lists:keyreplace(Id,#pr.id,Prs,Pr#pr{conn=C+1}));
            false ->
                case match_answer_uname(UName,Prs) of
                    {ok,#pr{id=Id,apid=APid,conn=C}=Pr} ->
                        APid ! {From, stun_check, Sock, {Addr,Port}},
                        rUDP(Sn,LP,lists:keyreplace(Id,#pr.id,Prs,Pr#pr{conn=C+1}));
                    false ->
                        rUDP(Sn,LP,Prs)
                end
        end;
    {From,trans_closed,Id} ->
        case lists:keysearch(Id,#pr.id,Prs) of
            {value,#pr{opid=From,apid=Peer}} -> Peer ! stop;
            {value,#pr{apid=From,opid=Peer}} -> Peer ! stop;
            false -> void 
        end,
        rUDP(Sn,LP,lists:keydelete(Id,#pr.id,Prs));
    guard_timer ->
        rUDP(Sn,LP,kick_dead(now(),Prs,[]));
    {From,{kill_relayer,Id}} ->
        From ! {self(),ok},
        case lists:keysearch(Id,#pr.id,Prs) of
            {value,#pr{opid=Op,apid=Ap}} -> Op ! Ap ! stop;
            false -> void 
        end,
        rUDP(Sn,LP,lists:keydelete(Id,#pr.id,Prs));
    {From,get_info} ->
        From ! Prs,
        rUDP(Sn,LP,Prs);
    stop ->
        R=[{Pid1!stop,Pid2!stop}||#pr{opid=Pid1,apid=Pid2}<-Prs],
        swap:llog("relay_udp stopped @~p.~n~p~n",[Sn,R]);
    _ ->
        rUDP(Sn,LP,Prs)
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
        swap:llog("relayudp:kick_dead: ~p ~p", [Pid1,Pid2]),
        kick_dead(Now,T,NPrs);
    true ->
        kick_dead(Now,T,[Pr|NPrs])
    end.

% ------------------------------------
trans_relayer(#rlyr{id=Id,to_pid=To,c_rcvd=RC,c_snt=SC}=ST) ->
  receive
    {add_peer,Pid} ->
        trans_relayer(ST#rlyr{to_pid=Pid});
    {From, stun_check, Sock2, Dest} ->
        From ! {self(),config_tlink,ST#rlyr.ice_state},
        trans_relayer(ST#rlyr{tlink=From,sock=Sock2,dest=Dest});
    {_From, stun_locked, _} ->
        trans_relayer(ST#rlyr{peerok=true});
    {relay_send,Bin} ->
        if ST#rlyr.peerok ->
            {Addr,Port} = ST#rlyr.dest,
            gen_udp:send(ST#rlyr.sock,Addr,Port,Bin),
            trans_relayer(ST#rlyr{c_snt=SC+1});
        true ->
            #rlyr{c_drop=DC} = ST,
            trans_relayer(ST#rlyr{c_drop=DC+1})
        end;
    {_,trans_received,Bin} ->
        To ! {relay_send,Bin},
        trans_relayer(ST#rlyr{c_rcvd=RC+1});
    {_,sock_closed,_Sock} ->
        rUDP() ! {self(), trans_closed, Id},
        ok;
    stop ->
        TPid = ST#rlyr.tlink,
        if is_pid(TPid) -> TPid ! stop;
        true -> pass end;
    {From,get_info} ->
        From ! ST,
        trans_relayer(ST)
  end.

get_info(Pid)->
    Pid ! {self(), get_info},
    receive
        M-> M
    after 1000->
        timeout
    end.
% ------------------------------------
udp_link0(ST) ->
    timer:send_after(20*60*1000, check_link),
    udp_link(ST).
udp_link(#tlst{sock=Sock,up_pid=UP}=ST) ->
  receive
    {udp,Sock,Addr,Port,Bin} ->
        ST2=processPKT({Addr,Port},Bin,ST),
        udp_link(ST2);
    {From,config_tlink,ICE} ->
        timer:send_after(100,stun_bindreq),
        udp_link(ST#tlst{up_pid=From,ice_state=ICE});
    stun_bindreq ->
        #tlst{sock=Sock,peer={Addr,Port},ice_state=ICE}=ST,
        {ok,{request,Request},_} = stun:handle_msg(bindreq,ICE),
        gen_udp:send(Sock,Addr,Port,Request),
        timer:send_after(500,stun_bindreq),
        if ST#tlst.peerok ->
            BindSent = ST#tlst.bindsent,
            if BindSent=<10 ->
                udp_link(ST#tlst{bindsent=BindSent+1});
            true ->
                UP ! {self(),sock_closed,Sock},
                gen_udp:close(Sock),
                swap:llog("udp ~p lost.~n",[Sock])
            end;
        true ->
            udp_link(ST)
        end;
    check_link->
        case is_pid(UP) andalso is_process_alive(UP) of
            true-> udp_link(ST);
        _->
            gen_udp:close(Sock),
            swap:llog("check_link: udp ~p left.~n",[self()]),
            ok
        end;
        
    stop ->
        gen_udp:close(Sock),
        swap:llog("udp ~p left.~n",[self()]),
        ok;
    {From,get_info}-> 
        From ! ST,
        udp_link(ST);
    Msg ->
        swap:llog("udp unknow: ~p~n",[Msg]),
        udp_link(ST)
    end.

processPKT({Addr,Port}, <<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin,
           #tlst{r443=_R443,sock=Sock,peerok=false,ice_state=undefined}=ST) ->
    case stun_codec:decode(Bin) of
        {ok, #stun{'USERNAME'=UN}, <<>>} -> 
            MyUN = get_my_uname(UN),
            rUDP() ! {self(), stun_username, MyUN, Sock,{Addr,Port}};
        _ -> pass
    end,
    ST#tlst{peer={Addr,Port}};
processPKT(_, <<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin,
           #tlst{sock=Sock,up_pid=UP,peer={Addr,Port},ice_state=ICE}=ST) when ICE=/=undefined ->
    case stun:handle_msg({udp_receive,Addr,Port,Bin},ICE) of
        {ok,{request,Response},NewICE} ->
            gen_udp:send(Sock,Addr,Port,Response),
            ST#tlst{ice_state=NewICE};
        {ok,response,NewICE} ->
            if not ST#tlst.peerok ->
                UP ! {self(),stun_locked,NewICE#st.wan_ip},
                ST#tlst{peerok=true,peer=NewICE#st.wan_ip,ice_state=NewICE};
            true -> ST#tlst{bindsent=0} end;
        _R ->
            ST
    end;
processPKT(_,Bin,#tlst{up_pid=UP,c_rcvd=RC}=ST) when is_pid(UP) ->  %% no packet before stun, actually.
    UP ! {self(),trans_received, Bin},
    ST#tlst{c_rcvd=RC+1};
processPKT(_,_Bin,ST) ->                                             %% will never happenned.
    ST.

make_udp_relayer(Id,OIce,AIce) ->
    Pid1 = spawn(fun()->trans_relayer(#rlyr{id=Id,ice_state=#st{ice={controlled, "2",AIce,OIce}}}) end),
    Pid2 = spawn(fun()->trans_relayer(#rlyr{id=Id,ice_state=#st{ice={controlling,"2",OIce,AIce}}}) end),
    Pid1 ! {add_peer,Pid2},
    Pid2 ! {add_peer,Pid1},
    {ok,Pid1,Pid2}.

get_my_uname(Un2) ->
    Len = size(Un2),
    {_,Un1} = split_binary(Un2,Len div 2 + 1),
    binary_to_list(Un1).
    
get_udp_port2(Pls) ->
    case get_udp_link2(Pls) of
        {ok,{P1,_S1,L1},{P2,_,L2}} -> {ok,P1,P2,L1,L2};
        {error,_}=Msg -> Msg
    end.

get_udp_link2(Pls) ->
    Pid = proplists:get_value(pid, Pls),
    A_ip=proplists:get_value(a_ip, Pls),
    O_ip=proplists:get_value(o_ip, Pls),
    case get_udp_link(Pid,A_ip) of
        {ok,P1,S1,L1} ->
            case get_udp_link(Pid,O_ip) of
                {ok,P2,S2,L2} -> {ok,{P1,S1,L1},{P2,S2,L2}};
                {error,_}=Ret -> L1 ! stop, Ret
            end;
        {error,_}=Ret -> 
            Ret
    end.
                

get_udp_link(Pid,Ip) ->
    Ref = make_ref(),
    Pid ! {self(),Ref,get_port,Ip},
    receive
        {_Pid,Ref,Msg} -> Msg
    after 5000 ->
        {error,timeout}
    end.

udp_port_man(Highest) ->
    receive
        {From, Ref, get_port,Ip} ->
            case try_port(0,Highest,?PORTRANGE,Ip) of
                {error,Reason} ->
                    From ! {self(),Ref,{error,Reason}},
                    udp_port_man(Highest);
                {ok,Port,Sock} ->
                    Link=spawn(fun() -> udp_link0(#tlst{sock=Sock}) end),
                    ok = gen_udp:controlling_process(Sock,Link),
                    swap:llog("open udp port:~p, link:~p~n", [Port,Link]),
                    From ! {self(),Ref,{ok,Port,Sock,Link}},
                    udp_port_man(Port+2)
            end
    end.

try_port(N,_Port,{BEGIN_UDP_RANGE,END_UDP_RANGE},_) when N > END_UDP_RANGE-BEGIN_UDP_RANGE ->
    {error,udp_over_range};
try_port(N,Port,{BEGIN_UDP_RANGE,END_UDP_RANGE},_Ip) when Port > END_UDP_RANGE ->
    try_port(N,BEGIN_UDP_RANGE,{BEGIN_UDP_RANGE,END_UDP_RANGE},_Ip);
try_port(N,Port,{BEGIN_UDP_RANGE,END_UDP_RANGE},Ip) ->
    Opts =
    if Ip ==undefined-> [binary, {active, true}, {recbuf, 4096}];
        true-> [binary, {active, true}, {recbuf, 4096},{ip,Ip}]
    end,
    case gen_udp:open(Port, Opts) of
        {ok, Socket} ->
            {ok,Port,Socket};
        {error, _} ->
            try_port(N+1,Port+1,{BEGIN_UDP_RANGE,END_UDP_RANGE},Ip)
    end.

% ------------------------------------
start() ->
	udp_port_man(),
	rUDP().
rUDP()->    
    case whereis(rUDP) of
    undefined->
	    R443 = spawn(fun() -> rUDP(1,udp_port_man(),[]) end),
	    register(rUDP,R443),
%	    timer:send_interval(?GUARDT1,R443,guard_timer),
	    R443;
    P->P
    end.

udp_port_man()->
    case whereis(udp_port_man) of
    undefined->
	    {BeginPort,_} = ?PORTRANGE,
	    PortMan = spawn(fun() -> udp_port_man(BeginPort) end),
	    register(udp_port_man,PortMan);
    _-> void
    end,
    whereis(udp_port_man).
    
stop() ->
    exit(udp_port_man(), kill),
    case whereis(rUDP) of
    undefined->void;
    P1-> P1 ! stop
    end.
