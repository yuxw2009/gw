-module(avanda).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(STUNV1, "1").
-define(STUNV2, "2").

-define(CC_RTP,1).		% component-id of candidate
-define(CC_RTCP,2).


processNATIVE(R_Addrs,R_Port,PhNo) when is_list(R_Addrs),is_integer(R_Port),is_list(PhNo) ->
	R_Addr = get_waddr(R_Addrs),
	processNATIVE2({R_Addr,R_Port},PhNo).

processNATIVE2({R_Addr,R_Port},PhNo) when is_list(R_Addr),is_integer(R_Port),is_list(PhNo) ->
    Sdp={_PLN,_Codec,_Params,PLType}=
    case proplists:get_value(codec, PhNo) of
    "12"-> {114,114,[0,4750],amr};
    "11"->  {102,102,[30],ilbc};
    Type-> 
        io:format("unknown mobile webrtc type:~p~n", [Type]),
        {103,103,[0,24000,480],isac}
    end,
%	{PLN,Codec,Params} = {103,103,[0,24000,480]},
%	{PLN,Codec,Params} = {0,0,[]},
	{L_SSRC,L_CName} = makessrc(),
	Media = whereis(rbt),
	R_Options= [{media,Media}],
	L_Options= [{media,Media},
	           {key_strategy, undefined},
	           {ssrc,[L_SSRC,L_CName]},
	           {sdp,Sdp}],
			   
	{value, Aid, LPort} = w2p:start({mobile,R_Options}, L_Options, PhNo,PLType, {R_Addr,R_Port}),
	{successful,Aid,{avscfg:get(mhost_ip),LPort}}.

stopNATIVE(Orig) ->
%	io:format("58.37 kill ~p~n",[Orig]),
	w2p:stop(Orig),
	ok.

getNATIVE(Orig) when is_integer(Orig) ->
	{value, Status,_Stats} = w2p:get_call_status(Orig),
	{ok,Status}.

get_waddr(Addrs) ->
	Ads = [{inet_parse:address(X),X}||X<-Addrs],
%	hd([Ad||{{ok,{A,_,_,_}},Ad}<-Ads,A=/=192]).
	case [Ad||{{ok,{A,_,_,_}},Ad}<-Ads,A=/=192] of
	[]-> "192.0.0.1";
	L-> hd(L)
	end.

get_192(["192."++_=A1|T]) -> A1;
get_192([_|T]) -> get_192(T).
% ----------------------------------

make_info(PhNo) ->
[{phone,PhNo},
 {uuid,{"1",86}},
 {audit_info,{obj,[{"uuid",86},
                   {"company",<<231,136,177,232,191,133,232,190,190,239,188,136,230,183,177,229,156,179,239,188,137,231,167,145,230,138,128,230,156,137,233,153,144,229,133,172,229,143,184,47,230,150,176,228,184,154,229,138,161,229,188,128,229,143,145,233,131,168>>},
                   {"name",<<233,146,177,230,178,155>>},
                   {"account",<<"0131000019">>},{"orgid",1}]}},
 {cid,"0085268895100"}].


% ------- video conference ---------
processCONF(SDP,Media,PartySess,[MyIP,UDP_RANGE]) when is_binary(SDP),is_pid(Media),is_list(PartySess) ->
	try sdp:decode(SDP) of
		{Session,Streams} ->
			{HasAudio,Streama} =
				case [Strm||Strm<-Streams,Strm#media_desc.type==audio] of
					[Strm1] -> {true,Strm1};
					[] -> {false,undefined}
				end,
			{_HasVideo,Streamv} =
				case [Strm||Strm<-Streams,Strm#media_desc.type==video] of
					[Strm2] -> {true,Strm2};
					[] -> {false,undefined}
				end,
			if HasAudio -> doCONF({Session,[Streama,Streamv]},Media,PartySess,[MyIP,UDP_RANGE]);
			true -> {failure,sdp_need_audio}
			end
	catch
		error:_X ->
			{failure,sdp_error}
	end.

doCONF({Session,[Streama,Streamv]},Media,PartySess,[MyIP,UDP_RANGE]) ->
	{OSVer, R_OrigID} = fetchorig(Session),
	{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Streama),
	{RV_SSRC,_} = fetchssrc(Streamv),

	L_OrigID = random:uniform(16#FFFFFFFF),
	{ICEUfrag,ICEpwd,K_S} = makey(),	
	{L_SSRC,L_CName} = {random:uniform(16#FFFFFFFF),list_to_binary(default_cname())},
	LV_SSRC = 2,
		
	L_rtp = #srtp_desc{origid = integer_to_list(L_OrigID),
					   ssrc = L_SSRC,
					   vssrc = LV_SSRC,
					   ckey = K_S,
					   cname= L_CName,
					   ice = {ice,ICEUfrag,ICEpwd}},
	R_rtp = #srtp_desc{origid = integer_to_list(R_OrigID),
					   ssrc = R_SSRC,
					   vssrc = RV_SSRC,
					   ckey = RK_S,
					   cname = R_CName,
					   ice = {ice,RUfrag,RPwd}},
	
	Options1 = [{outmedia,Media},{report_to,self()},		%% report to room man
			   {crypto,["AES_CM_128_HMAC_SHA1_80",R_rtp#srtp_desc.ckey]},
			   {ssrc,[R_rtp#srtp_desc.ssrc,R_rtp#srtp_desc.cname]},
			   {vssrc,[R_rtp#srtp_desc.vssrc,R_rtp#srtp_desc.cname]},
			   {stun,{controlled,?STUNV2,L_rtp#srtp_desc.ice,R_rtp#srtp_desc.ice}}],
	Options2 = [{media,Media},
			   {crypto,["AES_CM_128_HMAC_SHA1_80",L_rtp#srtp_desc.ckey]},
			   {ssrc,[L_rtp#srtp_desc.ssrc,L_rtp#srtp_desc.cname]}],
	Options3 = [{ssrc,[L_rtp#srtp_desc.vssrc,L_rtp#srtp_desc.cname]}],	% user same cname with audio

	case rtp:start_within(PartySess,Options1,UDP_RANGE) of
		{ok,LPort,RTP} ->
			L_session = make_default_session(L_OrigID, OSVer, false),
			L_audio = make_default_audio(L_SSRC, LPort, {ICEUfrag,ICEpwd,K_S}),
			L_video = make_default_video(LV_SSRC, LPort, {ICEUfrag,ICEpwd,K_S}),
			CandRTCP = [make_candidate(?CC_RTCP,IP,LPort)||IP<-MyIP],
			CandRTP = [make_candidate(?CC_RTP,IP,LPort)||IP<-MyIP],
			Call = CandRTP++CandRTCP,
			AnsSDP = sdp:encode(L_session, [L_audio#media_desc{candidates=Call},L_video#media_desc{candidates=Call}]),
			rtp:info(RTP,{add_stream,audio,Options2}),
			rtp:info(RTP,{add_stream,video,Options3}),
			rtp:info(RTP,{add_candidate,{R_Addr,R_Port}}),
			{successful,RTP,[],AnsSDP};
		{failure,Reason} when is_atom(Reason) ->
			{failure,Reason}
	end.


%% ---------------------------------

make_default_session(OrigID,OVer,HasVideo) ->
	Orig = #sdp_o{sessionid = integer_to_list(OrigID),
				  version = OVer,    % string
				  address = "127.0.0.1"},
	MediaType = if HasVideo -> "audio video";
				true -> "audio" end,
	#session_desc{originator = Orig,
				  name = "-",
				  attrs =  [{group,"BUNDLE "++MediaType}]}.
				  
make_default_audio(SSRC,Port,{ICEUfrag,ICEpwd,K_S}) ->
	PL0 = #payload{num = 0,
				   codec = pcmu,
				   clock_map = 8000},
	PL1 = #payload{num = 13,
				   codec = noise,
				   clock_map = 8000},
	PL2 = #payload{num = 103,
				   codec = iSAC,
				   clock_map = 16000},
	PL3 = #payload{num = 105,
				   codec = noise,
				   clock_map = 16000},
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,avscfg:get(host_ip)},Port} end,
	St = #media_desc{type = audio,
					 profile = "SAVPF",
					 port = MPort,
					 connect = Connect,
					 rtcp = {MPort, Connect},
					 payloads = [PL0,PL1],  %% [#payload{}],
					 attrs = [{"sendrecv",[]},
							  {"mid","audio"},
							  {"rtcp-mux",[]}],
					 ice = {ICEUfrag,ICEpwd},
					 crypto = {"1","AES_CM_128_HMAC_SHA1_80",K_S},
					 ssrc_info = []},
	SSRC_INFO = [{integer_to_list(SSRC),"cname",default_cname()},
				 {integer_to_list(SSRC),"msid",default_label()++" a0"},
 				 {integer_to_list(SSRC),"mslabel",default_label()},
				 {integer_to_list(SSRC),"label",default_label()++"a0"}],
	St#media_desc{ssrc_info = SSRC_INFO}.

make_default_video(SSRC,Port,{ICEUfrag,ICEpwd,K_S}) ->
	PLV0= #payload{num = 100,
				   codec = vp8,
				   clock_map = 90000},
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,avscfg:get(host_ip)},Port} end,
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
					 crypto = {"1","AES_CM_128_HMAC_SHA1_80",K_S},
					 ssrc_info = []},
	SSRC_INFO = [{integer_to_list(SSRC),"cname",default_cname()},
				 {integer_to_list(SSRC),"msid",default_label()++" v0"},
 				 {integer_to_list(SSRC),"mslabel",default_label()},
				 {integer_to_list(SSRC),"label",default_label()++"v0"}],
	Stv#media_desc{ssrc_info = SSRC_INFO}.

make_candidate(Compon,Host,LPort) ->
	Candid_sample = <<"a=candidate:1001 1 udp 2113937151 10.60.108.144 63833 typ host generation 0\r\n">>,
	C_offr = cndd:decode(Candid_sample),
	C1 = cndd:repl(compon,Compon,C_offr),
	cndd:repl(ipp, {Host,LPort},C1).

make_default_sdp(SSRC,OrigId,ICEKey,OVer) ->
	make_default_av_sdp(SSRC,undefined,OrigId,ICEKey,OVer).
	
make_default_av_sdp(SSRC,undefined,OrigID,{ICEUfrag,ICEpwd,K_S},OSVer) ->
	Session = make_default_session(OrigID, OSVer, false),
	Audio = make_default_audio(SSRC, undefined, {ICEUfrag,ICEpwd,K_S}),
	PL103 = #payload{num = 103,
					 codec = iSAC,
					 clock_map = 16000},				   
	OfferSDP = sdp:encode(Session,[Audio#media_desc{payloads=[PL103]}]),
	AnswSDP = sdp:encode(Session,[Audio]),
	{OfferSDP,AnswSDP};

make_default_av_sdp(SSRC,VSSRC,OrigID,{ICEUfrag,ICEpwd,K_S},OSVer) ->
	Session = make_default_session(OrigID, OSVer, false),
	Audio = make_default_audio(SSRC, undefined, {ICEUfrag,ICEpwd,K_S}),
	Video = make_default_video(VSSRC,undefined, {ICEUfrag,ICEpwd,K_S}),
	OfferSDP = sdp:encode(Session,[Audio]),
	AnswSDP = sdp:encode(Session,[Audio,Video]),
	{OfferSDP,AnswSDP}.

default_cname() -> "Rqm01FNyCgMqLqB6".
default_label() -> "m3MKMbraavrgT3S1857IJ6bo015jifuLfVZ9".

makey() ->
	{"DJ7niVqN0mSu7Y/Y","cTw830KuJ2G/e32fIbzd5dCs", "8bROQburRIumhDMV7P6A8G3J9pl/0VdiPhro7Z5v"}.

makessrc() ->
	{getrandom(),list_to_binary(default_cname())}.
	
make_rnd_dword() ->
	integer_to_list(getrandom()).

getrandom() ->
	1234567.
%	my_server:call(rtp_sup,random32).

fetchorig(#session_desc{originator=Origin}) ->
	{Origin#sdp_o.version,list_to_integer(Origin#sdp_o.sessionid) band 16#ffffff}.
	
fetchkey(#media_desc{ice={Ufrag,Pwd},crypto={_,_Alg,Inline}}) ->
	{Ufrag,Pwd,Inline}.

fetchkey2(#media_desc{ice={Ufrag,Pwd},crypto={Ch,_Alg,Inline}}) ->
	{{Ufrag,Pwd},{Ch,Inline}}.

fetchssrc(#media_desc{ssrc_info=[{Str1,"cname",Cname}|_]}) ->
	{list_to_integer(Str1),list_to_binary(Cname)};
fetchssrc(_) ->
	{undefined,undefined}.

fetch_mslabel(#media_desc{ssrc_info=SSRCInfo}) ->
	case lists:keysearch("mslabel",2,SSRCInfo) of
		{value, {_, _, MsLabel}} -> list_to_binary(MsLabel);
		false -> undefined
	end.

fetchpeer(#media_desc{candidates=Candids}) ->
	hd([{C#cdd.addr,C#cdd.port}||C<-Candids,C#cdd.compon==?CC_RTP,C#cdd.proto==udp]).

% ----------------------------------
offer(WS,SDP) ->
	JOut = rfc4627:encode({obj,[{type,<<"offer">>},{sdp,SDP}]}),
	send2(WS,JOut),
	ok.
	
answer(WS,SDP) ->
	JOut = rfc4627:encode({obj,[{type,<<"answer">>},{sdp,SDP}]}),
	send2(WS,JOut),
	ok.

candidate3(WS,true,[H1,_],LPort) ->
	candidate(WS,0,?CC_RTP,H1,LPort),
	candidate(WS,1,?CC_RTP,H1,LPort),
	candidate(WS,0,?CC_RTCP,H1,LPort),
	candidate(WS,1,?CC_RTCP,H1,LPort),
	ok.
	
candidate2(WS,true,[H1,H2],LPort) ->
	candidate(WS,0,?CC_RTP,H1,LPort),
	candidate(WS,0,?CC_RTP,H2,LPort),
	candidate(WS,1,?CC_RTP,H1,LPort),
	candidate(WS,1,?CC_RTP,H2,LPort),
	ok;
candidate2(WS,false,[H1,H2],LPort) ->
	candidate(WS,0,?CC_RTP,H1,LPort),
	candidate(WS,0,?CC_RTP,H2,LPort),
	ok.
candidate(_,_,_,"",_) ->
	<<>>;
candidate(WS,Label,Compon,Host,LPort) when is_integer(LPort) ->
	Candid_sample = <<"a=candidate:1001 1 udp 2113937151 10.60.108.144 63833 typ host generation 0\r\n">>,
	C_offr = cndd:decode(Candid_sample),
	C1 = cndd:repl(compon,Compon,C_offr),
	C6 = cndd:repl(ipp, {Host,LPort},C1),
	C_ans = cndd:encode(C6),
	JOut = rfc4627:encode({obj,[{type,<<"candidate">>},{label,list_to_binary(integer_to_list(Label))},{candidate,C_ans}]}),
	send2(WS,JOut),
	io:format("candidate out: ~p~n",[C_ans]),
	C_ans.

send2(Pid,JOut) ->
	yaws_api:websocket_send(Pid, {text, list_to_binary(JOut)}),
	ok.
showcallst(Pid,Status) ->
	JOut = rfc4627:encode({obj,[{type,<<"status">>},{name,Status}]}),
	yaws_api:websocket_send(Pid, {text, list_to_binary(JOut)}),
	ok.
hang_up(Pid) ->
	JOut = rfc4627:encode({obj,[{type,<<"bye">>},{name,phone}]}),
	yaws_api:websocket_send(Pid, {text, list_to_binary(JOut)}),
	ok.

% ----------------------------------

relay_call(UUID, Phno,OrigId,Monitor) ->
	F = fun(Pid) ->
			my_server:call(rtp_sup,{info_rtp,OrigId,{media_relay,Pid}})
		end,
	relay_sup:start_call(OrigId,Phno,Monitor,F),		% call status monitor message
	llog ! {self(),"~p browser ~p call ~p",[UUID,OrigId,Phno]},
	ok.

relay_bye(OrigId) ->
	relay_sup:stop_call(OrigId),
	llog ! {self(),"browser ~p leave.",[OrigId]},
	ok.
	
% ----------------------------------
start(WsPid) ->
	{ok,Pid} = my_server:start(wkr,[WsPid],[]),
	Pid.

stop(Wkr) ->
	my_server:cast(Wkr,stop).
