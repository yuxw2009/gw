-module(swap).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(STUNV2, "2").
-define(CC_RTP,1).      % component-id of candidate
-define(CC_RTCP,2).

-record(st, {
    session,
    proto,
    fsm,
    lport1,
    lport2,
    o_sdp,
    o_sdp2,
    o_ip,
    o_srtp,
    a_sdp,
    a_sdp2,
    a_ip,
    a_srtp
}).

init([udp]) ->
    {ok,LPort1,LPort2} = relayudp:get_udp_port2(udp_port_man),
    llog("udp swap-er started, get ports: ~p ~p",[LPort1,LPort2]),
    {ok,#st{proto=udp,fsm=idle,lport1=LPort1,lport2=LPort2}};
init([tcp]) ->
    {ok,LPort1,LPort2} = relay443:get_port2(0),
    llog("tcp swap-er started, get ports: ~p ~p",[LPort1,LPort2]),
    {ok,#st{proto=tcp,fsm=idle,lport1=LPort1,lport2=LPort2}}.

handle_call({offer,_Uid,Sdp}, _From, #st{fsm=idle,proto=Proto,lport1=LPort1}=ST) ->
    {OSRTP,OIP,Sdp2} = modi_candidate(Proto,LPort1,Sdp),
    io:format("modify offer SDP: ~p~n",[Sdp]),
    {reply,{successful,offer,Sdp2},ST#st{fsm=offer,o_sdp=Sdp,o_sdp2=Sdp2,o_srtp=OSRTP,o_ip=OIP}};
handle_call({answer,_Uid,Sdp}, _From, #st{fsm=offer,proto=Proto,o_srtp= #srtp_desc{ice=STUN1},lport2=LPort2}=ST) ->
    {#srtp_desc{ice=STUN2}=ASRTP,AIP,Sdp2} = modi_candidate(Proto,LPort2,Sdp),
    io:format("modify answer SDP: ~p~n",[Sdp]),
    Msg = {stun_informations,STUN1,STUN2},
    {ok,RId,_LP} = asyn_call(Proto,Msg),
    llog("~p relayer ~p started.",[Proto,RId]),
    {reply,{successful,answer,Sdp2},ST#st{session=RId,fsm=answer,a_sdp=Sdp,a_sdp2=Sdp2,a_srtp=ASRTP,a_ip=AIP}};
handle_call(get_info,_From,ST) ->
    {reply,ST,ST}.

handle_cast(stop,#st{session=RId,proto=Proto}) ->
    llog("~p relayer ~p stopped.",[Proto,RId]),
    asyn_call(Proto,{kill_relayer, RId}),
    {stop,normal,[]}.

terminate(_,_ST) ->
    ok.

% ----------------------------------
llog(F,P) ->
    case whereis(llog) of
        undefined -> io:format(F++"~n",P);
        Pid when is_pid(Pid) -> llog ! {self(), F, P}
    end.

modi_candidate(Proto,LPort,Sdp) ->
    {Session,[StrmA,StrmV]} = sdp:decode(Sdp),
    {_SVer, OrigID} = wkr:fetchorig(Session),
    {{Ufrag,Pwd},{_Ch,K_S}} = wkr:fetchkey2(StrmV),
    {Addr,Port} = wkr:fetchpeer(StrmV),
    {SSRC,_CName} = wkr:fetchssrc(StrmA),
    {VSSRC,CName} = wkr:fetchssrc(StrmV),
    SRTP = #srtp_desc{origid = integer_to_list(OrigID),
                      ssrc = SSRC,
                      vssrc = VSSRC,
                      ckey = K_S,
                      cname= CName,
                      ice = {ice,Ufrag,Pwd}},

    Host = avscfg:get(host_ip),
    StrmA2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[Host],LPort,Proto,StrmA),
    StrmV2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[Host],LPort,Proto,StrmV),
    Sdp2 = sdp:encode(Session,[StrmA2,StrmV2]),
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
	C2 = cndd:repl(founda,random:uniform(LPort),C1),
	C3 = cndd:repl(proto,Proto,C2),
	cndd:repl(ipp, {Host,LPort},C3).

asyn_call(Proto,Msg) ->
    Rlyr = fun(udp) -> rUDP;(tcp) -> r443 end,
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
create_relayer(Proto)  ->
    case whereis(llog) of
        undefined -> llog:start();
        _ -> ok
    end,
    {ok,Pid} = my_server:start(?MODULE,[Proto],[]),
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