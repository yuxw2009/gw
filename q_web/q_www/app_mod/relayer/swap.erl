-module(swap).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(HOST_FIRST_BYTE,10).%"116.228.53.181").
-define(HOST,"116.228.53.181").
-define(LRUDPRANGE,{55000,55019}).

-define(STUNV2, "2").
-define(CC_RTP,1).		% component-id of candidate
-define(CC_RTCP,2).

-record(st, {
	fsm,
	rtp1,
	lport1,
	rtp2,
	lport2,
	session,
	o_sdp,
	o_sdp1,
	o_sdp2,
	o_ip,
	o_srtp,
	a_sdp,
	a_sdp2,
	a_ip,
	a_srtp
}).

host()->
    {ok,Ifs}=inet:getif(),
    case [Ip||{Ip={?HOST_FIRST_BYTE,_,_,_},_,_}<-Ifs] of
    [{A,B,C,D}|_]-> string:join([integer_to_list(I)||I<-[A,B,C,D]], ".");
    _-> ?HOST
    end.
    
init([]) ->
	case rtp_relay:start_relay_pair({"offer","answer"},[{report_to,self()}],?LRUDPRANGE) of
		{ok,LPort1,LPort2,RTP1,RTP2} ->
			llog("lr swap started, ~p and ~p created.",[RTP1,RTP2]),
			{ok,#st{fsm=idle,rtp1=RTP1,lport1=LPort1,rtp2=RTP2,lport2=LPort2}};
		{error,Reason} ->
			llog("lr swap started: ~p @ transparent mode.",[Reason]),
			{ok,#st{fsm=error}}
	end.

handle_call({offer,_Uid,Sdp}, _From, #st{fsm=idle,lport1=LPort1,session=Session}=ST) ->
	Sdp1 = Sdp,
	{OSRTP,OIP,Sdp2} = modi_candidate(LPort1,Sdp),
	llog("modify offer SDP: ~p",[Sdp]),
	{reply,{successful,Session,Sdp2},ST#st{fsm=offer,o_sdp=Sdp,o_sdp1=Sdp1,o_sdp2=Sdp2,o_srtp=OSRTP,o_ip=OIP}};
handle_call({answer,_Uid,Sdp}, _From, #st{fsm=offer,session=Session,lport2=LPort2}=ST) ->
	{ASRTP,AIP,Sdp2} = modi_candidate(LPort2,Sdp),
	llog("modify answer SDP: ~p",[Sdp]),
	set_lr_rtp({ST#st.rtp1,AIP},{ST#st.rtp2,ST#st.o_ip},ST#st.o_srtp,ASRTP),
	{reply,{successful,Session,Sdp2},ST#st{fsm=answer,a_sdp=Sdp,a_sdp2=Sdp2,a_srtp=ASRTP,a_ip=AIP}};
handle_call({Cmd,_,Sdp}, _From, #st{fsm=error}=ST) when Cmd==offer;Cmd==answer ->
	llog("no change ~p SDP: ~p",[Cmd,Sdp]),
	{reply,{successful,0,Sdp},ST};
handle_call({rtp_report,Sess,Cmd},_From,ST) ->
	llog("~p report ~p.",[Sess,Cmd]),
	{reply,ok,ST};
handle_call(list,_From,ST) ->
	{reply,ST,ST}.

handle_cast(stop,#st{rtp1=R1,rtp2=R2}) ->
	llog("relayer ~p ~p stopped.",[R1,R2]),
	rtp_relay:stop(R1),
	rtp_relay:stop(R2),
	{stop,normal,[]}.

terminate(_,_ST) ->
	ok.

% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

modi_candidate(LPort,Sdp) ->
	{Session,[StrmA|MT]} = sdp:decode(Sdp),
	{_SVer, OrigID} = wkr:fetchorig(Session),
	{SSRC,CName} = wkr:fetchssrc(StrmA),
	{{Ufrag,Pwd},{_Ch,K_S}} = wkr:fetchkey2(StrmA),
%	{Addr,Port} = wkr:fetchpeer(StrmA),
	{VSSRC,MT2} = case MT of
				[StrmV] ->
					{VID,_}=wkr:fetchssrc(StrmV),
					VSt2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[host()],LPort,sdp_rm_redupl(StrmV)),
					{VID,[VSt2]};
				[] -> {undefined,[]}
			end,
	StrmA2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[host()],LPort,StrmA),

	SRTP = #srtp_desc{origid = integer_to_list(OrigID),
					  ssrc = SSRC,
					  vssrc = VSSRC,
					  ckey = K_S,
					  cname= CName,
					  ice = {ice,Ufrag,Pwd}},

	Sdp2 = sdp:encode(Session,[StrmA2|MT2]),
	{SRTP,{"10.60.108.131",60000},Sdp2}.

sdp_rm_redupl(#media_desc{payloads=[PN1,_,_]}=Desc) ->
	Desc#media_desc{payloads=[PN1]};
sdp_rm_redupl(Desc) ->
	Desc.

set_lr_rtp({RTP1,{AIP,APort}}, {RTP2,{OIP,OPort}},
	#srtp_desc{ssrc=O_A_SSRC,vssrc=O_V_SSRC,ckey=O_K_S,cname=O_CName,ice=O_ICE},
	#srtp_desc{ssrc=A_A_SSRC,vssrc=A_V_SSRC,ckey=A_K_S,cname=A_CName,ice=A_ICE}) ->
	
	Options11 = [{outmedia,RTP1},
				 {stun,{controlled,?STUNV2,A_ICE,O_ICE}}],
	rtp_relay:info(RTP2,{options,Options11}),
	rtp_relay:info(RTP2,{add_candidate,{OIP,OPort}}),

	Options21 = [{outmedia,RTP2},
				 {stun,{controlling,?STUNV2,O_ICE,A_ICE}}],
	rtp_relay:info(RTP1,{options,Options21}),
	rtp_relay:info(RTP1,{add_candidate,{AIP,APort}}),
	ok.

sdp_add_candidates(Compns,Hosts,Port,Desc) ->
	Candids = [wkr:make_candidate(Compn,Host,Port)||Compn<-Compns,Host<-Hosts],
	Desc#media_desc{candidates=Candids}.

% ----------------------------------
start() ->
	{ok,_Pid} = my_server:start({local,lrman},?MODULE,[],[]),
	ok.

% ----------------------------------
create_relayer(_Type)  ->
	case whereis(llog) of
		undefined -> llog:start();
		_ -> ok
	end,
	{ok,Pid} = my_server:start(?MODULE,[],[]),
	Pid.

update_offer(PID, SDP) ->
	case my_server:call(PID,{offer,0,SDP}) of
		{successful,Session,NewSDP} -> NewSDP;
		{failure,Reason} -> SDP
	end.

update_answer(PID, SDP) ->
	case my_server:call(PID,{answer,0,SDP}) of
		{successful,Session,NewSDP} -> NewSDP;
		{failure,Reason} -> SDP
	end.
	
destroy_relayer(PID) ->
	my_server:cast(PID,stop),
	ok.