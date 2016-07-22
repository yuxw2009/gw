-module(wkr).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(STUNV1, "1").
-define(STUNV2, "2").

-define(CC_RTP,1).		% component-id of candidate
-define(CC_RTCP,2).

-define(RTP_SUP,rtp_sup).


%% ---------------------------------
decodeWebSDP(SDP,LPort)->decodeWebSDP(SDP,LPort,whereis(rbt)).
decodeWebSDP(SDP,LPort,Media)->
	try sdp:decode(SDP) of
		{Session,Streams} ->
			{HasAudio,Streama} =
				case [Strm||Strm<-Streams,Strm#media_desc.type==audio] of
					[Strm1] -> {true,Strm1};
					[] -> {false,undefined}
				end,
			if HasAudio ->
				case check_sdp_params_for_voip({Session,Streams}) of
					{ok,Type} ->
						get_rtp_params({Session,[Streama]},Type,getrandom(),LPort,Media);
					_ ->
						{failure,sdp_bad_audio}
				end;
			true -> {failure,sdp_need_audio}
			end
	catch
		error:_X ->
			{failure,sdp_error}
	end.

get_rtp_params({Session,[Streama]},PLType,L_OrigID,LPort,Media) ->
	{OSVer, R_OrigID} = fetchorig(Session),
	%{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{RUfrag,RPwd} = fetchicepara(Streama),
	KeyStrategy = fetchkeystrategy(Streama),
    {PeerCrypto, PeerFingerPrint} = 
        case KeyStrategy of
		    crypto ->
		    	{fetchcrypto(Streama), undefined};
		    dtls ->
		        {undefined, fetchfingerprint(Streama)}
		end,
	{Meth,PeerKS}= if PeerCrypto == undefined -> {undefined, undefined}; true -> PeerCrypto end,
	%io:format("{KeyStrategy:~p,PeerCrypto:~p,PeerFingerPrint:~p}.~n", [KeyStrategy, PeerCrypto, PeerFingerPrint]),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Session,Streama),
	
	{ICEUfrag,ICEpwd,K_S} = makey(),	
	{L_SSRC,L_CName} = makessrc(),
	SelfCrypto = if KeyStrategy == crypto -> {Meth,K_S};
		     true -> undefined end,
	
	L_rtp = #srtp_desc{origid = integer_to_list(L_OrigID),
					   ssrc = L_SSRC,
					   ckey = K_S,
					   cname= L_CName,
					   ice = {ice,ICEUfrag,ICEpwd}},
	R_rtp = #srtp_desc{origid = integer_to_list(R_OrigID),
					   ssrc = R_SSRC,
					   ckey = PeerKS,
					   cname = R_CName,
					   ice = {ice,RUfrag,RPwd}},
	
	Options1 = [{outmedia,Media},
	           {key_strategy, KeyStrategy},
	           {fingerprint, PeerFingerPrint},
			   {crypto,PeerCrypto},
			   {ssrc,[R_rtp#srtp_desc.ssrc,R_rtp#srtp_desc.cname]},
			   {vssrc,[R_rtp#srtp_desc.vssrc,R_rtp#srtp_desc.cname]},
			   {stun,{controlled,?STUNV2,L_rtp#srtp_desc.ice,R_rtp#srtp_desc.ice}}],
	Options2 = [{media,Media},
	           {key_strategy, KeyStrategy},
			   {crypto,SelfCrypto},
			   {ssrc,[L_rtp#srtp_desc.ssrc,L_rtp#srtp_desc.cname]}],
			   
	L_session = make_default_session(L_OrigID, OSVer, false, undefined),
	L_audio = make_voip_audio(PLType,L_SSRC, LPort, {ICEUfrag,ICEpwd,SelfCrypto}),
    C1 = make_candidate(?CC_RTP,avscfg:get(host_ip),LPort),
	C2 = make_candidate(?CC_RTCP,avscfg:get(host_ip),LPort),
    C3 = make_candidate(?CC_RTP,avscfg:get(internal_ip),LPort),
	C4 = make_candidate(?CC_RTCP,avscfg:get(internal_ip),LPort),
	AnsSDP = sdp:encode(L_session, [L_audio#media_desc{candidates=[C1,C2,C3,C4]}]),
	{ok,Options1,Options2,AnsSDP,{R_Addr,R_Port}}.

processVOIP(SDP,PhInfo) when is_binary(SDP),is_list(PhInfo) ->
 {value, Calls} = app_manager:get_app_count(),
 MaxCalls = avscfg:get(max_calls),
    if
        Calls >  MaxCalls ->
            {failure, over_load};
        true ->
            processVOIP(SDP,getrandom(),PhInfo)
	end.

processVOIP(SDP,PartySess,PhInfo) ->
	try sdp:decode(SDP) of
		{Session,Streams} ->
			{HasAudio,Streama} =
				case [Strm||Strm<-Streams,Strm#media_desc.type==audio] of
					[Strm1] -> {true,Strm1};
					[] -> {false,undefined}
				end,
			if HasAudio ->
			      Fun=fun()->
			                 case proplists:get_value(uuid,PhInfo) of
			                 {_,"18017813673"}->  amr;
			                 _-> avscfg:get(webrtc_web_codec)
			                 end end,
				case check_sdp_params_for_voip({Session,Streams},Fun()) of
					{ok,Type} ->
						doVOIP({Session,[Streama]},Type,PartySess,PhInfo);
					_ ->
						{failure,sdp_bad_audio}
				end;
			true -> {failure,sdp_need_audio}
			end
	catch
		error:_X ->
			{failure,sdp_error}
	end.

doVOIP({Session,[Streama]},PLType,L_OrigID,PhInfo) ->
	{OSVer, R_OrigID} = fetchorig(Session),
	%{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{RUfrag,RPwd} = fetchicepara(Streama),
	KeyStrategy = fetchkeystrategy(Streama),
    {PeerCrypto, PeerFingerPrint} = 
        case KeyStrategy of
		    crypto ->
		    	{fetchcrypto(Streama), undefined};
		    dtls ->
		        {undefined, fetchfingerprint(Streama)}
		end,
	{Meth,PeerKS}= if PeerCrypto == undefined -> {undefined, undefined}; true -> PeerCrypto end,
	%io:format("{KeyStrategy:~p,PeerCrypto:~p,PeerFingerPrint:~p}.~n", [KeyStrategy, PeerCrypto, PeerFingerPrint]),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Session,Streama),
	
	{ICEUfrag,ICEpwd,K_S} = makey(),	
	{L_SSRC,L_CName} = makessrc(),
	SelfCrypto = if KeyStrategy == crypto -> {Meth,K_S};
		     true -> undefined end,
	
	L_rtp = #srtp_desc{origid = integer_to_list(L_OrigID),
					   ssrc = L_SSRC,
					   ckey = K_S,
					   cname= L_CName,
					   ice = {ice,ICEUfrag,ICEpwd}},
	R_rtp = #srtp_desc{origid = integer_to_list(R_OrigID),
					   ssrc = R_SSRC,
					   ckey = PeerKS,
					   cname = R_CName,
					   ice = {ice,RUfrag,RPwd}},
	
	Media = whereis(rbt),
	Options1 = [{outmedia,Media},
	           {key_strategy, KeyStrategy},
	           {fingerprint, PeerFingerPrint},
			   {crypto,PeerCrypto},
			   {ssrc,[R_rtp#srtp_desc.ssrc,R_rtp#srtp_desc.cname]},
			   {vssrc,[R_rtp#srtp_desc.vssrc,R_rtp#srtp_desc.cname]},
			   {stun,{controlled,?STUNV2,L_rtp#srtp_desc.ice,R_rtp#srtp_desc.ice}}],
	Options2 = [{media,Media},
	           {key_strategy, KeyStrategy},
			   {crypto,SelfCrypto},
			   {ssrc,[L_rtp#srtp_desc.ssrc,L_rtp#srtp_desc.cname]}],
			   
	{value, Aid, LPort} = w2p:start(Options1, Options2, PhInfo,PLType, {R_Addr,R_Port}),
	L_session = make_default_session(L_OrigID, OSVer, false, undefined),
	L_audio = make_voip_audio(PLType,L_SSRC, LPort, {ICEUfrag,ICEpwd,SelfCrypto}),
    C1 = make_candidate(?CC_RTP,avscfg:get(host_ip),LPort),
	C2 = make_candidate(?CC_RTCP,avscfg:get(host_ip),LPort),
    C3 = make_candidate(?CC_RTP,avscfg:get(internal_ip),LPort),
	C4 = make_candidate(?CC_RTCP,avscfg:get(internal_ip),LPort),
	AnsSDP = sdp:encode(L_session, [L_audio#media_desc{candidates=[C1,C2,C3,C4]}]),
	{successful,Aid,AnsSDP}.
	
stopVOIP(Orig) when is_integer(Orig) ->
    w2p:stop(Orig),
	ok.

getVOIP(Orig) when is_integer(Orig) ->
	{value, Status,_Stats} = w2p:get_call_status(Orig),
	{ok,Status}.
	
getVOIP_with_stats(Orig) when is_integer(Orig) ->
       case w2p:get_call_status(Orig) of
       {value, Status,Stats}->{ok,Status,Stats};
       R->{failed,R}
       end.
	
eventVOIP(Orig,{dail,[H|T]}) when length(T)>0 ->
    eventVOIP(Orig,{dail,[H]}),
    eventVOIP(Orig,{dail,T});
eventVOIP(Orig,{dail,N}) when is_integer(Orig),is_list(N) ->
    w2p:dial(Orig,parsePEv(N)).
	
make_sess_from_ip(IP) ->
	{ok,{A,B,C,D}} = inet_parse:address(IP),
	<<Sess:32>> = <<A:8,B:8,C:8,D:8>>,
	Sess.

processIosTpVOIP(SDP,Aid) when is_binary(SDP) ->
 {value, Calls} = app_manager:get_app_count(),
 MaxCalls = avscfg:get(max_calls),
    if
        Calls >  MaxCalls ->
            {failed, over_load};
        true ->
            R=processIosTpVOIP(SDP,getrandom(),Aid),
            w2p:sip_p2p_answer(Aid),
            io:format("processIosTpVOIP:~p~n",[R]),
            R
	end.

processIosTpVOIP(SDP,PartySess,Aid) ->
	try sdp:decode(SDP) of
		{Session,Streams} ->
			{HasAudio,Streama} =
				case [Strm||Strm<-Streams,Strm#media_desc.type==audio] of
					[Strm1] -> {true,Strm1};
					[] -> {false,undefined}
				end,
			if HasAudio ->
				case check_sdp_params_for_voip({Session,Streams}) of
					{ok,Type} ->
						do_ios_sip_tp_VOIP({Session,[Streama]},Type,PartySess,Aid);
					_ ->
						{failure,sdp_bad_audio}
				end;
			true -> {failure,sdp_need_audio}
			end
	catch
		error:_X ->
			{failure,sdp_error}
	end.

do_ios_sip_tp_VOIP({Session,[Streama]},PLType,L_OrigID,Aid) ->
	io:format("**************************************************************~n"),
	{OSVer, R_OrigID} = fetchorig(Session),
	%{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{RUfrag,RPwd} = fetchicepara(Streama),
	KeyStrategy = fetchkeystrategy(Streama),
    {PeerCrypto, PeerFingerPrint} = 
        case KeyStrategy of
		    crypto ->
		    	{fetchcrypto(Streama), undefined};
		    dtls ->
		        {undefined, fetchfingerprint(Streama)}
		end,
	{Meth,PeerKS}= if PeerCrypto == undefined -> {undefined, undefined}; true -> PeerCrypto end,
	%io:format("{KeyStrategy:~p,PeerCrypto:~p,PeerFingerPrint:~p}.~n", [KeyStrategy, PeerCrypto, PeerFingerPrint]),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Session,Streama),
	
	{ICEUfrag,ICEpwd,K_S} = makey(),	
	{L_SSRC,L_CName} = makessrc(),
	SelfCrypto = if KeyStrategy == crypto -> {Meth,K_S};
		     true -> undefined end,
	
	L_rtp = #srtp_desc{origid = integer_to_list(Aid),
					   ssrc = L_SSRC,
					   ckey = K_S,
					   cname= L_CName,
					   ice = {ice,ICEUfrag,ICEpwd}},
	R_rtp = #srtp_desc{origid = integer_to_list(R_OrigID),
					   ssrc = R_SSRC,
					   ckey = PeerKS,
					   cname = R_CName,
					   ice = {ice,RUfrag,RPwd}},
	
	Media = whereis(rbt),
	Options1 = [{outmedia,Media},
	           {key_strategy, KeyStrategy},
	           {fingerprint, PeerFingerPrint},
			   {crypto,PeerCrypto},
			   {ssrc,[R_rtp#srtp_desc.ssrc,R_rtp#srtp_desc.cname]},
			   {vssrc,[R_rtp#srtp_desc.vssrc,R_rtp#srtp_desc.cname]},
			   {stun,{controlled,?STUNV2,L_rtp#srtp_desc.ice,R_rtp#srtp_desc.ice}}],
	Options2 = [{media,Media},
	           {key_strategy, KeyStrategy},
			   {crypto,SelfCrypto},
			   {ssrc,[L_rtp#srtp_desc.ssrc,L_rtp#srtp_desc.cname]}],
			   
	{value, LPort}=w2p:get_rtp_port(Aid),
	RTP= w2p:get_rtp_pid(Aid),
      rtp:info(RTP,{add_stream,audio,Options2}),
      my_server:call(RTP,{options,Options1}),
	L_session = make_default_session(L_OrigID, OSVer, false, undefined),
	L_audio = make_voip_audio(PLType,L_SSRC, LPort, {ICEUfrag,ICEpwd,SelfCrypto}),
    C1 = make_candidate(?CC_RTP,avscfg:get(host_ip),LPort),
	C2 = make_candidate(?CC_RTCP,avscfg:get(host_ip),LPort),
    C3 = make_candidate(?CC_RTP,avscfg:get(internal_ip),LPort),
	C4 = make_candidate(?CC_RTCP,avscfg:get(internal_ip),LPort),
	AnsSDP = sdp:encode(L_session, [L_audio#media_desc{candidates=[C1,C2,C3,C4]}]),
	{successful,Aid,AnsSDP}.

parsePEv("*") -> 10;
parsePEv("#") -> 11;
parsePEv(N) when N>="0",N=<"9" -> list_to_integer(N);
parsePEv(_) -> 11.		% invalid 

make_info(PhNo) ->
[{phone,PhNo},
 {uuid,{"1",86}},
 {audit_info,{obj,[{"uuid",86},
                   {"company",<<231,136,177,232,191,133,232,190,190,239,188,136,230,183,177,229,156,179,239,188,137,231,167,145,230,138,128,230,156,137,233,153,144,229,133,172,229,143,184,47,230,150,176,228,184,154,229,138,161,229,188,128,229,143,145,233,131,168>>},
                   {"name",<<233,146,177,230,178,155>>},
                   {"account",<<"0131000019">>},{"orgid",1}]}},
 {cid,"0085268895100"}].

check_sdp_params_for_voip(Desc) ->check_sdp_params_for_voip(Desc,avscfg:get(webrtc_web_codec)).
check_sdp_params_for_voip(Desc,PLType) ->
	case check_sdp_params(Desc) of
		{_,[{audio,PLs,[true,true],true,true,_}|_]} ->
			case PLType of
				isac ->
					case {lists:member(103,PLs),lists:member(105,PLs)} of
						{true,true} -> {ok,isac};
						_ ->
							case {lists:member(0,PLs),lists:member(13,PLs)} of
								{true,true} -> {ok,pcmu};
								_ -> err
							end
					end;
				ilbc ->
					case {lists:member(102,PLs),lists:member(13,PLs)} of
						{true,true} -> {ok,ilbc};
						_ ->
							case {lists:member(103,PLs),lists:member(105,PLs)} of
								{true,true} -> {ok,isac};
								_ ->
									case {lists:member(0,PLs),lists:member(13,PLs)} of
										{true,true} -> {ok,pcmu};
										_ -> err
									end

							end
					end;
				opus ->
					case {lists:member(111,PLs)} of
						{true} -> {ok,opus};
						_ ->
							case {lists:member(0,PLs),lists:member(13,PLs)} of
								{true,true} -> {ok,pcmu};
								_ -> err
							end
					end;
			      amr->
					case {lists:member(114,PLs)} of
						{true} -> {ok,amr};
						_ ->
							case {lists:member(103,PLs),lists:member(105,PLs)} of
								{true,true} -> {ok,isac};
								_ ->
									case {lists:member(0,PLs),lists:member(13,PLs)} of
										{true,true} -> {ok,pcmu};
										_ -> err
									end

							end
					end;
				pcmu ->
					case {lists:member(0,PLs),lists:member(13,PLs)} of
						{true,true} -> {ok,pcmu};
						_ -> err
					end
			end;
		_ -> err
	end.

check_sdp_params({Session,Streams}) ->
	Ver = (Session#session_desc.originator)#sdp_o.version,
	{Ver,
	case string:tokens(proplists:get_value(group, Session#session_desc.attrs)," ") of
		["BUNDLE"|Medias] ->
			if length(Medias)==length(Streams) ->
				lists:map(fun(X)->check_sdp_media(X) end,Streams);
			true -> [] end;
		_ -> []
	end	}.

check_sdp_media(#media_desc{type=Type,
							payloads=PLs,
							attrs=Attrs,
							ice=ICE,
							key_strategy=KeyStra,
							crypto=Cryp,
							fingerprint=FingerPrint,
							ssrc_info=_SSRCinfo,
							profile=Profile}) ->
	PNs = [PN||#payload{num=PN}<-PLs],
	Trans = [lists:keymember("sendrecv",1,Attrs),lists:keymember("rtcp-mux",1,Attrs)],
	{Type,PNs,Trans,check_ice_params(ICE),check_cryp_params(KeyStra, Cryp, FingerPrint),Profile}.
	
check_ice_params({L1,L2}) when is_list(L1),is_list(L2) ->
	if length(L1)==16 andalso length(L2)==24 -> true;
	true -> false end;
check_ice_params(_) -> false.

check_cryp_params(crypto, {_,_,K}, _) when is_list(K) ->
	if length(K)==40 -> true;
	true -> false end;
check_cryp_params(dtls, _, {sha, FP}) when is_binary(FP), byte_size(FP) == 20 -> true;
check_cryp_params(dtls, _, {sha128, FP}) when is_binary(FP), byte_size(FP) == 16 -> true;
check_cryp_params(dtls, _, {sha256, FP}) when is_binary(FP), byte_size(FP) == 32 -> true;
check_cryp_params(_, _, _) -> false.

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
			MediaType = "audio video",
			Session2 = Session#session_desc{attrs =  [{group,"BUNDLE "++MediaType}]},
			if HasAudio -> doCONF({Session2,[Streama,Streamv]},Media,PartySess,[MyIP,UDP_RANGE]);
			true -> {failure,sdp_need_audio}
			end
	catch
		error:_X ->
			{failure,sdp_error}
	end.

doCONF({Session,[Streama,undefined]},Media,PartySess,[MyIP,UDP_RANGE]) ->
	{OSVer, R_OrigID} = fetchorig(Session),
	{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Streama),

	L_OrigID = random:uniform(16#FFFFFFFF),
	{ICEUfrag,ICEpwd,K_S} = makey(),	
	{L_SSRC,L_CName} = {random:uniform(16#FFFFFFFF),list_to_binary(default_cname())},
		
	L_rtp = #srtp_desc{origid = integer_to_list(L_OrigID),
					   ssrc = L_SSRC,
					   ckey = K_S,
					   cname= L_CName,
					   ice = {ice,ICEUfrag,ICEpwd}},
	R_rtp = #srtp_desc{origid = integer_to_list(R_OrigID),
					   ssrc = R_SSRC,
					   ckey = RK_S,
					   cname = R_CName,
					   ice = {ice,RUfrag,RPwd}},
	
	Options1 = [{outmedia,Media},{report_to,self()},		%% report to room man
			   {crypto,["AES_CM_128_HMAC_SHA1_80",R_rtp#srtp_desc.ckey]},
			   {ssrc,[R_rtp#srtp_desc.ssrc,R_rtp#srtp_desc.cname]},
			   {stun,{controlled,?STUNV2,L_rtp#srtp_desc.ice,R_rtp#srtp_desc.ice}}],
	Options2 = [{media,Media},
			   {crypto,["AES_CM_128_HMAC_SHA1_80",L_rtp#srtp_desc.ckey]},
			   {ssrc,[L_rtp#srtp_desc.ssrc,L_rtp#srtp_desc.cname]}],

	case rtp:start_within(PartySess,Options1,UDP_RANGE) of
		{ok,LPort,RTP} ->
			L_session = make_default_session(L_OrigID, OSVer, false),
			L_audio = make_conference_audio(L_SSRC, LPort, {ICEUfrag,ICEpwd,K_S}),
			CandRTCP = [make_candidate(?CC_RTCP,IP,LPort)||IP<-MyIP],
			CandRTP = [make_candidate(?CC_RTP,IP,LPort)||IP<-MyIP],
			Call = CandRTP++CandRTCP,
			AnsSDP = sdp:encode(L_session, [L_audio#media_desc{candidates=Call}]),
			rtp:info(RTP,{add_stream,audio,Options2}),
			rtp:info(RTP,{add_candidate,{R_Addr,R_Port}}),
			{successful,RTP,[],AnsSDP};
		{failure,Reason} when is_atom(Reason) ->
			{failure,Reason}
	end;
doCONF({Session,[Streama,Streamv]},Media,PartySess,[MyIP,UDP_RANGE]) ->
	{OSVer, R_OrigID} = fetchorig(Session),
	{RUfrag,RPwd,RK_S} = fetchkey(Streama),
	{R_SSRC,R_CName} = fetchssrc(Streama),
	{R_Addr,R_Port} = fetchpeer(Streama),
	{RV_SSRC,_} = fetchssrc(Streamv),
	KeyStrategy = fetchkeystrategy(Streama),
    {PeerCrypto, PeerFingerPrint} = 
        case KeyStrategy of
		    crypto ->
		    	{fetchcrypto(Streama), undefined};
		    dtls ->
		        {undefined, fetchfingerprint(Streama)}
		end,
	{Meth,PeerKS}= if PeerCrypto == undefined -> {undefined, undefined}; true -> PeerCrypto end,
	
	L_OrigID = random:uniform(16#FFFFFFFF),
	{ICEUfrag,ICEpwd,K_S} = makey(),	

	SelfCrypto = if KeyStrategy == crypto -> {Meth,K_S};
		     true -> undefined end,

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
	           {key_strategy, KeyStrategy},
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
			L_session = make_default_session(L_OrigID, OSVer, true),
			L_audio = make_conference_audio(L_SSRC, LPort, {ICEUfrag,ICEpwd,K_S}),
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

make_default_session(OrigID,OVer,HasVideo, SelfFingerPrint) ->
	Orig = #sdp_o{sessionid = integer_to_list(OrigID),
				  version = OVer,    % string
				  address = "127.0.0.1"},
	MediaType = if HasVideo -> "audio video";
				true -> "audio" end,
    Attrs = if SelfFingerPrint == undefined -> [{group,"BUNDLE "++MediaType}];
    	    true -> [{group,"BUNDLE "++MediaType}, {fingerprint, fingerprint_str(SelfFingerPrint)}] end,
	#session_desc{originator = Orig,
				  name = "-",
				  attrs = Attrs}.

fingerprint_str({Algo, Digest}) -> [algo_str(Algo), $ , digest_str(Digest)].
algo_str(sha) -> "sha-1";
algo_str(sha128) -> "sha-128";
algo_str(sha256) -> "sha-256".

digest_str(Bin) -> lists:foldr(fun(E, []) -> [E]; 
	                              (E, [H|T]) -> [E, $:, H|T] end, 
	                           [], 
	                           lists:map(fun(E) -> 
	                           	             if E > 16#0F -> integer_to_list(E, 16); 
	                           	             true -> "0" ++ integer_to_list(E, 16) end 
	                           	         end, 
	                           	         binary_to_list(Bin))).

make_voip_audio(PLType,SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}) ->
	make_default_audio_of(audio_payloads(PLType),SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}).

make_default_audio(SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}) ->
	make_default_audio_of(audio_payloads(isac),SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}).
make_conference_audio(SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}) ->
	make_default_audio_of(audio_payloads(pcmu),SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}).

audio_payloads(pcmu) ->
	PL0 = #payload{num = 0,codec = pcmu,clock_map = 8000},
	PL1 = #payload{num = 13,codec = noise,clock_map = 8000},
	PL2 = #payload{num = 126,codec=telephone,clock_map=8000},
	[PL0,PL1,PL2];
audio_payloads(opus) ->
	PL0 = #payload{num = 111,codec = opus,clock_map = 48000,channel=stereo,config=[{minptime,20}]},
%	PL1 = #payload{num = 107,codec = noise,clock_map = 48000},
	PL2 = #payload{num = 126,codec=telephone,clock_map=8000},
	[PL0,PL2];
audio_payloads(isac) ->
	PL0 = #payload{num = 103,codec = iSAC,clock_map = 16000},
	PL1 = #payload{num = 105,codec = noise,clock_map = 16000},
	PL2 = #payload{num=126,codec=telephone,clock_map=8000},
	[PL0,PL1,PL2];
audio_payloads(ilbc) ->
	PL0 = #payload{num = 102,codec = iLBC,clock_map = 8000},
	PL1 = #payload{num = 13,codec = noise,clock_map = 8000},
	PL2 = #payload{num=126,codec=telephone,clock_map=8000},
	[PL0,PL1,PL2].

make_default_audio_of(PLs,SSRC,Port,{ICEUfrag,ICEpwd,SelfCrypto}) ->
	{Connect,MPort} = if Port==undefined -> {{inet4,"0.0.0.0"},1};
			  true -> {{inet4,avscfg:get(host_ip)},Port} end,
    {KeyStrategy, Cryp} = 
    	          case SelfCrypto of
    	              undefined -> {dtls, undefined};
    	              {"AES_CM_128_HMAC_SHA1_32", K_S} -> {crypto, {"0","AES_CM_128_HMAC_SHA1_32", K_S}};
    	              {"AES_CM_128_HMAC_SHA1_80", K_S} -> {crypto, {"1","AES_CM_128_HMAC_SHA1_80", K_S}}
    	          end,
	St = #media_desc{type = audio,
					 profile = "SAVPF",
					 port = MPort,
					 connect = Connect,
					 rtcp = {MPort, Connect},
					 payloads = PLs,  %% [#payload{}],
					 config = [#ptime{max=60}],
					 attrs = [{"sendrecv",[]},
							  {"mid","audio"},
							  {"rtcp-mux",[]}],
					 ice = {ICEUfrag,ICEpwd},
					 key_strategy = KeyStrategy,
					 crypto = Cryp,
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
	Candid_sample = list_to_binary([<<"a=candidate:1001 1 ">>,
									atom_to_list(avscfg:get(web_proto)),
					  				<<" 2113937151 10.60.108.144 63833 typ host generation 0\r\n">>]),
	C_offr = cndd:decode(Candid_sample),
	C1 = cndd:repl(compon,Compon,C_offr),
	cndd:repl(ipp, {Host,LPort},C1).

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
      {_,M,N}=os:timestamp(), 
      (M rem 1000)*1000+ (N div 1000).

fetchorig(#session_desc{originator=Origin}) ->
	{Origin#sdp_o.version,list_to_integer(Origin#sdp_o.sessionid) band 16#ffffff}.

fetchkeystrategy(#media_desc{key_strategy=KeyStrategy}) ->
    KeyStrategy.

fetchcrypto(#media_desc{crypto={_,Alg,Inline}}) ->
    {Alg, Inline}.

fetchfingerprint(#media_desc{fingerprint=FingerPrint}) ->
    FingerPrint.

fetchicepara(#media_desc{ice={Ufrag,Pwd}}) ->
    {Ufrag,Pwd}.

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
	Udps = [{iptype(C#cdd.addr),C#cdd.addr,C#cdd.port}||C<-Candids,C#cdd.compon==?CC_RTP,C#cdd.proto==udp],
	AP = choose_peer(Udps),
	%%llog("candidate winner: ~p",[AP]),
	AP.

fetchpeer(_Session, #media_desc{candidates=Candids}) ->
	Udps = [{iptype(C#cdd.addr),C#cdd.addr,C#cdd.port}||C<-Candids,C#cdd.compon==?CC_RTP,C#cdd.proto==udp],
	AP = choose_peer(Udps),
	%%llog("~p candidate winner: ~p",[Session,AP]),
	AP.

choose_peer(Udps) ->
	case [{Addr,Port}||{wan,Addr,Port}<-Udps] of
		[] -> choose_peer(lan_a,Udps);
		Ad2 -> hd(Ad2)
	end.

choose_peer(lan_a,Udps) ->
	case [{Addr,Port}||{lan_a,Addr,Port}<-Udps] of
		[] -> choose_peer(lan_b,Udps);
		Ad2 -> hd(Ad2)
	end;
choose_peer(lan_b,Udps) ->
	case [{Addr,Port}||{lan_b,Addr,Port}<-Udps] of
		[] -> choose_peer(lan_c,Udps);
		Ad2 -> hd(Ad2)
	end;
choose_peer(lan_c,Udps) ->
	case [{Addr,Port}||{lan_c,Addr,Port}<-Udps] of
		[] -> {"127.0.0.1",55555};
		Ad2 -> hd(Ad2)
	end.
	

iptype(Addr) ->	
	case inet_parse:address(Addr) of
        {ok,{A,B,_C,_D}}->
			if A==10 -> lan_a;
			   A==172 andalso (B>=16 andalso B=<31) -> lan_b;
			   A==192 andalso B==168 -> lan_c;
			   A==169 andalso B==254 -> unused;
			true -> wan
			end;
		_-> wan
	end.

% ----------------------------------
llog(F,M) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",M);
		Pid -> Pid ! {self(),F,M}
	end.

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
	%%io:format("candidate out: ~p~n",[C_ans]),
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

start(WsPid) ->
	{ok,Pid} = my_server:start(wkr,[WsPid],[]),
	Pid.

stop(Wkr) ->
	my_server:cast(Wkr,stop).
