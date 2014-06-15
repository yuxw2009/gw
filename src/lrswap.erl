-module(lrswap).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(HOST,"10.61.34.53").
-define(LRUDPRANGE,{50050,50051}).

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
	called,
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

init([]) ->
	{ok,LPort1,RTP1} = rtp:start_within("1000",[{report_to,self()}],?LRUDPRANGE),
	{ok,LPort2,RTP2} = rtp:start_within("1001",[{report_to,self()}],?LRUDPRANGE),
	io:format("lr swap started, ~p and ~p created.~n",[RTP1,RTP2]),
	{ok,#st{fsm=idle,rtp1=RTP1,lport1=LPort1,rtp2=RTP2,lport2=LPort2}}.

handle_call({waiting,Uid}, _From, #st{fsm=idle}=ST) ->
	Session = integer_to_list(Uid),
	{reply,{failure,waiting},ST#st{fsm=waiting,session=Session,called=Uid}};
handle_call({waiting,Uid}, _From, #st{fsm=waiting,called=Uid}=ST) ->
	{reply,{failure,waiting},ST};
handle_call({waiting,Uid}, _From, #st{fsm=offer,session=Session,called=Uid,o_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST};
handle_call({answer,Uid,Sdp}, _From, #st{fsm=offer,session=Session,lport2=LPort2,called=Uid}=ST) ->
	{ASRTP,AIP,Sdp2} = modi_candidate(LPort2,Sdp),
	set_lr_rtp({ST#st.rtp1,AIP},{ST#st.rtp2,ST#st.o_ip},ST#st.o_srtp,ASRTP),
	{reply,{successful,Session},ST#st{fsm=answer,a_sdp=Sdp,a_sdp2=Sdp2,a_srtp=ASRTP,a_ip=AIP}};

handle_call({offer,Uid,Sdp}, _From, #st{fsm=waiting,lport1=LPort1,called=Uid,session=Session}=ST) ->
	Sdp1 = Sdp,
	{OSRTP,OIP,Sdp2} = modi_candidate(LPort1,Sdp),
	{reply,{successful,Session},ST#st{fsm=offer,called=Uid,o_sdp=Sdp,o_sdp1=Sdp1,o_sdp2=Sdp2,o_srtp=OSRTP,o_ip=OIP}};
handle_call({polling,Session}, _From, #st{fsm=answer,session=Session,a_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST#st{fsm=busy}};
handle_call({release,Session}, _From, #st{fsm=FSM,session=Session,rtp1=RTP1,rtp2=RTP2}=ST) ->
	io:format("released @ ~p.~n",[FSM]),
	{reply,successful,ST#st{fsm=release}};

handle_call({rtp_report,Sess,Cmd},_From,ST) ->
	io:format("~p report ~p.~n",[Sess,Cmd]),
	{reply,ok,ST};
handle_call(list,_From,ST) ->
	{reply,ST,ST};
handle_call(clear,_From,#st{rtp1=R1,rtp2=R2}) ->
	rtp:stop(R1),
	rtp:stop(R2),
	{ok,LPort1,RTP1} = rtp:start_within("1000",[{report_to,self()}],?LRUDPRANGE),
	{ok,LPort2,RTP2} = rtp:start_within("1001",[{report_to,self()}],?LRUDPRANGE),
	io:format("lr swap started, ~p and ~p created.~n",[RTP1,RTP2]),
	{ok,#st{fsm=idle,rtp1=RTP1,lport1=LPort1,rtp2=RTP2,lport2=LPort2}};
handle_call(Cmd,_From,ST) ->
	io:format("unavailable cmd: ~p @ ~p.~n",[Cmd,ST]),
	{reply,{failure,unprocessed},ST}.

terminate(_,ST) ->
	io:format("left_2_right manager stopped @~p~n",[ST]),
	ok.

% ----------------------------------
modi_payload(Sdp) ->
	PLA0= #payload{num = 103,
				   codec = iSAC,
				   clock_map = 16000},
	PLV0= #payload{num = 100,
				   codec = vp8,
				   clock_map = 90000},
	case sdp:decode(Sdp) of
	{Session,[AStream,VStream]} ->
		AStream2 = AStream#media_desc{payloads=[PLA0]},
		VStream2 = VStream#media_desc{payloads=[PLV0]},
		Sdp1 = sdp:encode(Session,[AStream2,VStream2]),
		Sdp1;
	{Session,[AStream]} ->
		AStream2 = AStream#media_desc{payloads=[PLA0]},
		Sdp1 = sdp:encode(Session,[AStream2]),
		Sdp1
	end.
	
modi_candidate(LPort,Sdp) ->
	{Session,Stream} = sdp:decode(Sdp),
	{_SVer, OrigID} = wkr:fetchorig(Session),
	{{Ufrag,Pwd},{Ch,K_S}} = wkr:fetchkey2(hd(Stream)),
	MsLabel = wkr:fetch_mslabel(hd(Stream)),
	{Addr,Port} = wkr:fetchpeer(hd(Stream)),
%	{ASSRC,CName} = wkr:fetchssrc(lists:nth(1,Stream)),
	ASSRC = 0,
	{SSRC,CName} = wkr:fetchssrc(lists:nth(1,Stream)),
	SRTP = #srtp_desc{origid = integer_to_list(OrigID),
					  ssrc = ASSRC,
					  vssrc = SSRC,
					  ckey = K_S,
					  cname= CName,
					  ice = {ice,Ufrag,Pwd}},

%	AStream2 = make_advance_audio(CName,MsLabel,ASSRC,LPort,{Ufrag,Pwd},{Ch,K_S}),
	VStream2 = make_advance_video(CName,MsLabel,SSRC,LPort,{Ufrag,Pwd},{Ch,K_S}),
	case (hd(Stream))#media_desc.candidates of
		[_] ->
			Candids = [wkr:make_candidate(?CC_RTP,?HOST,LPort)],
			io:format("candid: ~p~n",[Candids]),
			Sdp2 = sdp:encode(Session, [
%										AStream2#media_desc{candidates=Candids,rtcp = {1,{inet4,"0.0.0.0"}}},
										VStream2#media_desc{candidates=Candids,rtcp = {1,{inet4,"0.0.0.0"}}}
										]),
			{SRTP,{Addr,Port},Sdp2};			
		[_,_|_] ->
			Candids = [wkr:make_candidate(?CC_RTP,?HOST,LPort), wkr:make_candidate(?CC_RTCP,?HOST,LPort)],
			io:format("candid: ~p~n",[Candids]),
			Sdp2 = sdp:encode(Session, [
%										AStream2#media_desc{candidates=Candids},
										VStream2#media_desc{candidates=Candids}
										]),
			{SRTP,{Addr,Port},Sdp2}
	end.

make_advance_audio(CName,Label,SSRC,Port,{ICEUfrag,ICEpwd},{Ch,K_S}) ->
	PL0= #payload{num = 103,
				  codec = iSAC,
				  clock_map = 16000},
	PL1= #payload{num = 105,
				  codec = noise,
				  clock_map = 16000},
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,?HOST},Port} end,
	Sta= #media_desc{type = audio,
					 profile = "SAVPF",
					 port = MPort,
					 connect = Connect,
					 rtcp = {MPort,Connect},
					 payloads = [PL0,PL1],
					 attrs = [{"sendrecv",[]},
							  {"mid","audio"},
							  {"rtcp-mux",[]}],
					 ice = {ICEUfrag,ICEpwd},
					 crypto = {Ch,"AES_CM_128_HMAC_SHA1_80",K_S},		% why channel == 0?
					 ssrc_info = []},
	SSRC_INFO = case {CName,Label} of
			{undefined, undefined} ->
				SSRC2 = 1,
				Label2 = <<"AQYbTKW4sjBC21nUpDl6gzxVWeHiOMPmArzw">>,
				[{integer_to_list(SSRC2),"cname","Z9EEhTf+OkKUAcA0"},
				 {integer_to_list(SSRC2),"msid",binary_to_list(Label2)++" a0"},
 				 {integer_to_list(SSRC2),"mslabel",binary_to_list(Label2)},
				 {integer_to_list(SSRC2),"label",binary_to_list(Label2)++"a0"}],
				[];
			_ ->
				[{integer_to_list(SSRC),"cname",binary_to_list(CName)},
				 {integer_to_list(SSRC),"msid",binary_to_list(Label)++" a0"},
 				 {integer_to_list(SSRC),"mslabel",binary_to_list(Label)},
				 {integer_to_list(SSRC),"label",binary_to_list(Label)++"a0"}]
		end,
	Sta#media_desc{ssrc_info = SSRC_INFO}.

make_advance_video(CName,Label,SSRC,Port,{ICEUfrag,ICEpwd},{Ch,K_S}) ->
	PLV0= #payload{num = 100,
				   codec = vp8,
				   clock_map = 90000},
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,?HOST},Port} end,
	Stv= #media_desc{type = video,
					 profile = "SAVPF",
					 port = MPort,
					 connect = Connect,
					 rtcp = {MPort,Connect},
					 payloads = [PLV0],  %% [#payload{}],
					 attrs = [{"sendrecv",[]},
							  {"mid","video"},
							  {"rtcp-mux",[]}],
					 ice = {ICEUfrag,ICEpwd},
					 crypto = {Ch,"AES_CM_128_HMAC_SHA1_80",K_S},		% why channel == 0?
					 ssrc_info = []},
	SSRC_INFO = case {CName,Label} of
			{undefined, undefined} ->
				[];
			_ ->
				[{integer_to_list(SSRC),"cname",binary_to_list(CName)},
				 {integer_to_list(SSRC),"msid",binary_to_list(Label)++" v0"},
 				 {integer_to_list(SSRC),"mslabel",binary_to_list(Label)},
				 {integer_to_list(SSRC),"label",binary_to_list(Label)++"v0"}]
		end,
	Stv#media_desc{ssrc_info = SSRC_INFO}.

set_lr_rtp({RTP1,{AIP,APort}}, {RTP2,{OIP,OPort}},
	#srtp_desc{ssrc=O_A_SSRC,vssrc=O_V_SSRC,ckey=O_K_S,cname=O_CName,ice=O_ICE},
	#srtp_desc{ssrc=A_A_SSRC,vssrc=A_V_SSRC,ckey=A_K_S,cname=A_CName,ice=A_ICE}) ->
	
	Media = lr_switch:start([RTP1,RTP2]),
	Options11 = [{outmedia,Media},
				 {crypto,["AES_CM_128_HMAC_SHA1_80",O_K_S]},
				 {vssrc,[O_V_SSRC,O_CName]},
				 {stun,{controlled,?STUNV2,A_ICE,O_ICE}}],
	Options12 = [{media,Media},
				 {ssrc,[A_A_SSRC,A_CName]},
				 {crypto,["AES_CM_128_HMAC_SHA1_80",A_K_S]}],
	Options13 = [{ssrc,[A_V_SSRC,A_CName]}],
	rtp:info(RTP2,{options,Options11}),
	rtp:info(RTP2,{add_stream,audio,Options12}),
	rtp:info(RTP2,{add_stream,video,Options13}),
	rtp:info(RTP2,{add_candidate,{OIP,OPort}}),

	Options21 = [{outmedia,Media},
				 {crypto,["AES_CM_128_HMAC_SHA1_80",A_K_S]},
				 {vssrc,[A_V_SSRC,A_CName]},
				 {stun,{controlling,?STUNV2,O_ICE,A_ICE}}],
	Options22 = [{media,Media},
				 {ssrc,[O_A_SSRC,O_CName]},
				 {crypto,["AES_CM_128_HMAC_SHA1_80",O_K_S]}],
	Options23 = [{ssrc,[O_V_SSRC,O_CName]}],
	rtp:info(RTP1,{options,Options21}),
	rtp:info(RTP1,{add_stream,audio,Options22}),
	rtp:info(RTP1,{add_stream,video,Options23}),
	rtp:info(RTP1,{add_candidate,{AIP,APort}}),
	ok.

% ----------------------------------
start() ->
	{ok,_Pid} = my_server:start({local,lrman},?MODULE,[],[]),
	ok.

go() ->
	my_timer:start(),
	start().
%
% ----------------------------------
%	Interfaces of manager
%	rpc:called from yaws
% ----------------------------------
%
offer(Uuid, Sdp) when is_integer(Uuid) ->
	case my_server:call(lrman,{offer,Uuid,Sdp}) of
		{successful,Session} -> {ok,Session};
		{failure,Reason} -> {failed, Reason}
	end.
polling(Session) when is_list(Session) ->
	case my_server:call(lrman,{polling,Session}) of
		{successful,Session,AnswerSDP} -> {ok,Session,AnswerSDP};
		{failure,Reason} -> {failed, Reason}
	end.
release(Session) when is_list(Session) ->
	my_server:call(lrman,{release,Session}),
	ok.
	
waiting(Uuid) when is_integer(Uuid) ->
	case my_server:call(lrman,{waiting,Uuid}) of
		{successful,Session,OfferSDP} -> {ok,Session,OfferSDP};
		{failure,Reason} -> {failed, Reason}
	end.
answer(Uuid, Sdp) when is_integer(Uuid) ->
	case my_server:call(lrman,{answer,Uuid,Sdp}) of
		{successful,Session} -> {ok,Session};
		{failure,Reason} -> {failed, Reason}
	end.
