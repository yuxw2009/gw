-module(udpswap).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(HOST,"10.61.34.58").
-define(UDPRANGE,{50050,50051}).
-define(LISTENPORT,55000).

-define(STUNV2, "2").
-define(CC_RTP,1).		% component-id of candidate
-define(CC_RTCP,2).

-record(st, {
	fsm,
	rid,	% relayer id
	rtp1,
	lport1,
	sock1,
	link1,
	rtp2,
	lport2,
	sock2,
	link2,
	session,
	called,
	o_sdp,
	o_sdp1,
	o_sdp2,
	o_ip,
	o_srtp,
	a_sdp,
	a_sdp1,
	a_sdp2,
	a_ip,
	a_srtp
}).

init([]) ->
	{ok,P1,P2} = relayudp:get_udp_port2(udp_port_man),
	{ok,#st{fsm=idle,lport1=P1,lport2=P2}}.

handle_call({waiting,Uid}, _From, #st{fsm=idle}=ST) ->
	Session = integer_to_list(Uid),
	{reply,{failure,waiting},ST#st{fsm=waiting,session=Session,called=Uid}};
handle_call({waiting,Uid}, _From, #st{fsm=waiting,called=Uid}=ST) ->
	{reply,{failure,waiting},ST};
handle_call({waiting,Uid}, _From, #st{fsm=offer,session=Session,called=Uid,o_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST};
handle_call({answer,Uid,Sdp}, _From, #st{fsm=offer,session=Session,lport2=LPort2,called=Uid}=ST) ->
	Sdp1 = modi_opus_params(LPort2,Sdp),
	{#srtp_desc{ice=STUN2}=ASRTP,{A2,P2}=AIP,Sdp2} = modi_candidate2(LPort2,Sdp),
	#st{o_srtp= #srtp_desc{ice=STUN1},o_ip={A1,P1},sock1=Sock1,link1=Link1,sock2=Sock2,link2=Link2} = ST,
	{ok,Ad1} = inet_parse:address(A1),
	{ok,Ad2} = inet_parse:address(A2),
	Msg = {stun_informations,STUN1,STUN2},
	io:format("send r443:~p~n",[Msg]),
	{ok,RId,_LP} = asyn_call(rUDP,Msg),
	{reply,{successful,Session},ST#st{fsm=answer,rid=RId,a_sdp=Sdp,a_sdp1=Sdp1,a_sdp2=Sdp2,a_srtp=ASRTP,a_ip=AIP}};

handle_call({offer,Uid,Sdp}, _From, #st{fsm=waiting,lport1=LPort1,called=Uid,session=Session}=ST) ->
	Sdp1 = modi_opus_params(LPort1,Sdp),
	{OSRTP,OIP,Sdp2} = modi_candidate2(LPort1,Sdp),
	{reply,{successful,Session},ST#st{fsm=offer,called=Uid,o_sdp=Sdp,o_sdp1=Sdp1,o_sdp2=Sdp2,o_srtp=OSRTP,o_ip=OIP}};
handle_call({polling,Session}, _From, #st{fsm=answer,session=Session,a_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST#st{fsm=busy}};
handle_call({release,Session}, _From, #st{fsm=FSM,session=Session}=ST) ->
	io:format("released @ ~p.~n",[FSM]),
	{reply,successful,ST#st{fsm=release}};

handle_call({rtp_report,Sess,Cmd},_From,ST) ->
	io:format("~p report ~p.~n",[Sess,Cmd]),
	{reply,ok,ST};
handle_call(list,_From,ST) ->
	{reply,ST,ST};
handle_call(clear,_From,#st{rtp1=R1,rtp2=R2}) ->
	{ok,#st{fsm=idle}};
handle_call(Cmd,_From,ST) ->
	io:format("unavailable cmd: ~p @ ~p.~n",[Cmd,ST]),
	{reply,{failure,unprocessed},ST}.

terminate(_,ST) ->
	io:format("left_2_right manager stopped @~p~n",[ST]),
	ok.

% ----------------------------------
modi_candidate(LPort,Sdp) ->
	{Session,[StrmA]} = sdp:decode(Sdp),
	{_SVer, OrigID} = wkr:fetchorig(Session),
	{{Ufrag,Pwd},{_Ch,K_S}} = wkr:fetchkey2(StrmA),
	{Addr,Port} = wkr:fetchpeer(StrmA),
	{SSRC,CName} = wkr:fetchssrc(StrmA),
	SRTP = #srtp_desc{origid = integer_to_list(OrigID),
					  ssrc = SSRC,
					  ckey = K_S,
					  cname= CName,
					  ice = {ice,Ufrag,Pwd}},

	StrmA2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[?HOST],LPort,StrmA),
	Sdp2 = sdp:encode(Session,[StrmA2]),
	{SRTP,{Addr,Port},Sdp2}.

modi_candidate2(LPort,Sdp) ->
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

	StrmA2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[?HOST],LPort,StrmA),
	StrmV2 = sdp_add_candidates([?CC_RTP,?CC_RTCP],[?HOST],LPort,sdp_rm_redupl(StrmV)),
	Sdp2 = sdp:encode(Session,[StrmA2,StrmV2]),
	{SRTP,{Addr,Port},Sdp2}.

modi_opus_params(LPort,Sdp) ->
	Tks = string:tokens(binary_to_list(Sdp), "\r\n"),
%	Tks2 = replace_line(Tks,"a=fmtp:111 minptime=10","a=fmtp:111 maxplaybackrate=8000\r\na=ptime:40"),	% 
	Tks3 = replace_line(Tks,"a=rtpmap:111 opus/48000/2",""),
	Tks4 = replace_line(Tks3,"a=fmtp:111 minptime=10",""),
%	Tks5 = replace_line(Tks4,"a=rtpmap:105 CN/16000",""),
%	Tks10 = replace_line(Tks5,"a=msid-semantic: WMS",""),
	Tks10 = replace_line(Tks,"a=extmap:1 urn",""),

	Tks11 = locate_then_replace_candidate(append_rn(Tks10),?HOST,LPort),
	list_to_binary(Tks11).

replace_line(Ls,Rpls,With) ->
	replace_line(Ls,Rpls,With,[]).
replace_line([],_,_,R) ->
	lists:reverse(R);
replace_line([H|T],Rpls,With,R) when length(H)>=length(Rpls) ->
	case lists:split(length(Rpls),H) of
		{Rpls,_} ->
			if With=="" -> replace_line(T,Rpls,With,R);
			true -> replace_line(T,Rpls,With,[With|R])
			end;
		_ ->
			replace_line(T,Rpls,With,[H|R])
	end;
replace_line([H|T],Rpls,With,R) ->
	replace_line(T,Rpls,With,[H|R]).

locate_then_replace_candidate(Tks,Ip,Port) ->
	locate_then_replace_candidate(Tks,Ip,Port,[]).
locate_then_replace_candidate([],_,_,R) ->
	lists:reverse(R);
locate_then_replace_candidate(["a=candidate"++_ = H|T],Ip,Port,R) ->
	C1 = cndd:decode(list_to_binary(H)),
	C2 = cndd:repl(ipp,{Ip,Port},C1),
	C3 = binary_to_list(cndd:encode(C2)),
	locate_then_replace_candidate(T,Ip,Port,[C3|R]);
locate_then_replace_candidate([H|T],Ip,Port,R) ->
	locate_then_replace_candidate(T,Ip,Port,[H|R]).

append_rn([]) -> [];
append_rn([H|T]) -> [H++"\r\n"|append_rn(T)].

sdp_rm_redupl(#media_desc{payloads=[PN1,_,_]}=Desc) ->
	Desc#media_desc{payloads=[PN1]};
sdp_rm_redupl(Desc) ->
	Desc.

set_lr_rtp({RTP1,{AIP,APort}}, {RTP2,{OIP,OPort}},
	#srtp_desc{ssrc=O_A_SSRC,vssrc=O_V_SSRC,ckey=O_K_S,cname=O_CName,ice=O_ICE},
	#srtp_desc{ssrc=A_A_SSRC,vssrc=A_V_SSRC,ckey=A_K_S,cname=A_CName,ice=A_ICE}) ->
	
	io:format("offer ~p ~p answer ~p ~p.~n",[O_A_SSRC,O_V_SSRC,A_A_SSRC,A_V_SSRC]),
	
	Media = lr_switch:start([RTP1,RTP2]),
	Options11 = [{outmedia,Media},
				 {crypto,["AES_CM_128_HMAC_SHA1_80",O_K_S]},
				 {ssrc,[O_A_SSRC,O_CName]},
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
				 {ssrc,[A_A_SSRC,A_CName]},
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

sdp_make_chrome_default(Dir,Type,{ICEUfrag,ICEpwd},K_S) ->	% sendrecv/recvonly, audio/video
	PayLoads = sdp_make_chrome_payloads(Type),
	#media_desc{type = Type,
				profile = "SAVPF",
				payloads = PayLoads,
				attrs = [{atom_to_list(Dir),[]},
						 {"mid",atom_to_list(Type)},
						 {"rtcp-mux",[]}],
				ice = {ICEUfrag,ICEpwd},
				crypto = {"1","AES_CM_128_HMAC_SHA1_80",K_S},
				ssrc_info = []}.

sdp_make_chrome_payloads(audio) ->
	PL0= #payload{num = 103,codec = iSAC, clock_map = 16000},
	PL1= #payload{num = 105,codec = noise,clock_map = 16000},
	[PL0,PL1].

sdp_add_media(Type,CName,Label,SSRC,Desc) ->
	[Tag|_] = atom_to_list(Type),
	SSRC_INFO = [{integer_to_list(SSRC),"cname",binary_to_list(CName)},
				 {integer_to_list(SSRC),"msid",binary_to_list(Label)++" "++[Tag]++"0"},
 				 {integer_to_list(SSRC),"mslabel",binary_to_list(Label)},
				 {integer_to_list(SSRC),"label",binary_to_list(Label)++[Tag]++"0"}],
	Desc#media_desc{ssrc_info=SSRC_INFO}.

sdp_add_connect(IP,Port,Desc) ->
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,IP},Port} end,
	Desc#media_desc{port=MPort,connect=Connect,rtcp={MPort,Connect}}.

sdp_add_candidates(Compns,Hosts,Port,Desc) ->
	Candids = [make_candidate(Compn,Host,Port)||Compn<-Compns,Host<-Hosts],
	Desc#media_desc{candidates=Candids}.

make_candidate(Compon,Host,LPort) ->
	Candid_sample = <<"a=candidate:1001 1 udp 2113937151 10.60.108.144 63833 typ host generation 0\r\n">>,
	C_offr = cndd:decode(Candid_sample),
	C1 = cndd:repl(compon,Compon,C_offr),
	cndd:repl(ipp, {Host,LPort},C1).

asyn_call(Pid,Msg) ->
	Pid ! {self(),Msg},
	receive
		{_,Response} -> Response
	after 1500 -> []
	end.
			

% ----------------------------------
start() ->
	case whereis(my_timer) of
		undefined -> my_timer:start();
		_ -> pass
	end,
	{ok,_Pid} = my_server:start({local,lrman},?MODULE,[],[]),
	relayudp:start(),
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
