-module(swap).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").
-include("swapcfg.hrl").


-define(STUNV2, "2").
-define(CC_RTP,1).      % component-id of candidate
-define(CC_RTCP,2).

-record(st, {
    session,
    proto,
    fsm,
    a_link,
    o_link,
    a_port,  %for answer side
    o_port,  %for offer side
    o_sdp,
    o_sdp2,
    o_ip,
    o_srtp,
    o_opts,
    a_opts,
    a_sdp,
    a_sdp2,
    a_ip,
    a_srtp
}).

host(Opts) when is_list(Opts)->
    Network = proplists:get_value("network", Opts),
    if Network == <<"telecom">> -> ?HOST_NWK1; true-> ?HOST_NWK2 end.

ip(Opts)->
    Ip_str=host(Opts),
    list_to_tuple(lists:map(fun erlang:list_to_integer/1, string:tokens(Ip_str,[$.]))).
 
init([Pls]) ->
    O_opts = proplists:get_value(o_opts, Pls,[]),
    A_opts = proplists:get_value(a_opts, Pls,[]),
    Udp_PF = fun()-> relayudp:get_udp_port2([{pid,relayudp:udp_port_man()},{o_ip,ip(O_opts)},{a_ip,ip(A_opts)}]) end,
    Tcp_Pf = fun()-> relay443:get_port2(0) end,
    Proto = proplists:get_value(proto, Pls),
    {ok,LPort1,LPort2,Link1,Link2} = if Proto==udp-> Udp_PF(); true-> Tcp_Pf() end,
    llog("~p swap-er ~p started, get ports: ~p ~p, alink:~p olink:~p",[Proto, self(), LPort1,LPort2,Link1,Link2]),
    erlang:monitor(process,Link1),
    erlang:monitor(process,Link2),
    {ok,#st{proto=Proto,fsm=idle,a_port=LPort1,o_port=LPort2,o_opts=O_opts, a_opts=A_opts,a_link=Link1,o_link=Link2}}.

handle_call({offer,_Uid,Sdp}, _From, #st{fsm=idle,proto=Proto,a_port=LPort1, a_opts=Peer_Opts}=ST) ->
%    Peer_ip = proplists:get_value(from_ip, Peer_Opts,{0,0,0,0}),
    {OSRTP,OIP,Sdp2} = modi_candidate([{proto,Proto},{port,LPort1},{sdp,Sdp},{peer_ip, host(Peer_Opts)}]),
    {reply,{successful,offer,Sdp2},ST#st{fsm=offer,o_sdp=Sdp,o_sdp2=Sdp2,o_srtp=OSRTP,o_ip=OIP}};
handle_call({answer,_Uid,Sdp}, _From, #st{fsm=offer,proto=Proto,o_srtp= #srtp_desc{ice=STUN1},o_port=LPort2,o_opts=Peer_Opts}=ST) ->
    {#srtp_desc{ice=STUN2}=ASRTP,AIP,Sdp2} = modi_candidate([{proto,Proto},{port,LPort2},{sdp,Sdp},{peer_ip, host(Peer_Opts)}]),
    Msg = {stun_informations,STUN1,STUN2},
    {ok,RId,_LP} = asyn_call(Proto,Msg),
    llog("~p relayer ~p started.",[Proto,RId]),
    {reply,{successful,answer,Sdp2},ST#st{session=RId,fsm=answer,a_sdp=Sdp,a_sdp2=Sdp2,a_srtp=ASRTP,a_ip=AIP}};
handle_call(get_info,_From,ST) ->
    {reply,ST,ST}.

handle_cast(stop,St=#st{session=RId,proto=Proto}) ->
    llog("~p relayer ~p stopped.",[Proto,RId]),
    asyn_call(Proto,{kill_relayer, RId}),
    {stop,normal,St}.

handle_info({'DOWN', _MonitorRef, process, From, Info},State) ->
    llog("swap monitor process: ~p down, Reason:~p~n", [From, Info]),
    {noreply, State};

handle_info(_,State) ->
    {noreply, State}.


terminate(_,_ST=#st{a_link=Alink,o_link=Olink}) ->
    llog("swap:~p stop, alink:~p, o_link:~p~n", [self(),Alink,Olink]),
    [if is_pid(L)-> L !stop; true-> void end || L <-[Alink,Olink]],
    ok.

% ----------------------------------
llog(F,P) ->
    case whereis(llog) of
        undefined -> llog:start(), llog ! {self(), F, P};
        Pid when is_pid(Pid) -> llog ! {self(), F, P}
    end.
is_lan_addr({A,_,_,_}) when A==10; A==192-> true;
is_lan_addr(_)-> false.

modi_candidate(Pls) ->
       Proto=proplists:get_value(proto, Pls),
       LPort=proplists:get_value(port, Pls),
       Sdp=proplists:get_value(sdp,Pls),
       Peer_network_ip = proplists:get_value(peer_ip,Pls),
	{Session,Strms=[Strm1|_]} = sdp:decode(Sdp),
       
       
	{_SVer, OrigID} = wkr:fetchorig(Session),
	{{Ufrag,Pwd},{_Ch,K_S}} = wkr:fetchkey2(Strm1),
	{Addr,Port} = wkr:fetchpeer(Strm1),
	{SSRC,CName} = wkr:fetchssrc(Strm1),
	SRTP = #srtp_desc{origid = integer_to_list(OrigID),
					  ssrc = SSRC,
					  ckey = K_S,
					  cname= CName,
					  ice = {ice,Ufrag,Pwd}},

	Med_seq = [sdp_add_candidates([?CC_RTP,?CC_RTCP],[Peer_network_ip],LPort,Proto,Strm) || Strm<-Strms],
	Sdp2 = sdp:encode(Session,Med_seq),
	{SRTP,{Addr,Port},Sdp2}.

sdp_rm_redupl(#media_desc{payloads=[PN1,_,_]}=Desc) ->
    Desc#media_desc{payloads=[PN1]};
sdp_rm_redupl(Desc) ->
    Desc.

sdp_add_candidates(Compns,Hosts,Port,Proto,Desc) ->
    Candids = [make_candidate(Proto,Compn,Host,Port)||Compn<-Compns,Host<-Hosts],
    Desc#media_desc{candidates=Candids}.

make_candidate(Proto,Compon,Host,LPort) ->
	Candid_sample = <<"a=candidate:1001 1 udp 2113937151 10.60.108.144 63833 typ host generation 0\r\n">>,
	C_offr = cndd:decode(Candid_sample),
	C1 = cndd:repl(compon,Compon,C_offr),
	C2 = cndd:repl(proto,Proto,C1),
	cndd:repl(ipp, {Host,LPort},C2).

asyn_call(Proto,Msg) ->
    Rlyr = fun(udp) -> relayudp:rUDP();(tcp) -> r443 end,
    Rlyr(Proto) ! {self(),Msg},
    receive
        {_,Response} -> Response
    after 1500 -> []
    end.


% ----------------------------------
start() ->
    {ok,_Pid} = my_server:start({local,lrman},?MODULE,[udp],[]),
    ok.

% ----------------------------------
create_relayer(Pls)  ->
    case whereis(llog) of
        undefined -> llog:start();
        _ -> ok
    end,
    {ok,Pid} = my_server:start(?MODULE,[Pls],[]),
    Pid.

update_offer(PID, SDP) ->
    case my_server:call(PID,{offer,0,SDP}) of
        {successful,_,NewSDP} -> NewSDP;
        {failure,_Reason} -> SDP
    end.

update_answer(PID, SDP) ->
    case my_server:call(PID,{answer,0,SDP}) of
        {successful,_,NewSDP} -> NewSDP;
        {failure,_Reason} -> SDP
    end.
    
destroy_relayer(PID) ->
    my_server:cast(PID,stop),
    ok.
