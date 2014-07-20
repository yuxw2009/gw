-module(rtp).
-compile(export_all).

-include("desc.hrl").
-indlude("rtp_rtcp.hrl").
-include("dtls4srtp.hrl").

-define(DIGESTLENGTH,10).
-define(RTPHEADLENGTH,12).
-define(RTCPHEADLENGTH,8).
-define(RTCPEIDXLENGTH,4).
-define(RTCPINTERVAL, 2000).

-define(PCMU,0).
-define(CN,13).
-define(iLBC, 102).
-define(OPUS, 111).
-define(oCNG, 107).
-define(iSAC,103).
-define(iCNG,105).
-define(wPHN,126).
-define(VP8,100).
-define(LOSTAUDIO,1003).

-define(MINVBITRATE,96000).

-define(JITTERLENGTH,32).
-define(SENTSAVELENGTH,64).
-define(PSIZE,160).
-define(is_rtcp(PT), (PT==200 orelse PT==201 orelse PT==202 orelse PT==203 orelse PT==205 orelse PT==206)).
-record(st, {
	ice,
	wan_ip
}).

-record(vp8_cdc, {
	level = 0,
	vp = 0
}).

-record(esti, {
	v_target_br = ?MINVBITRATE,
	v_br = ?MINVBITRATE,
	v_rcvd_seq,
	v_rcvd_pkts = 0,
	v_rcvd_lost = 0,
	v_snd_eseq = 0,
	v_snd_pkts = 0,
	v_snd_lost = 0,
	v_snd_level = 0,
	v_snd_remb
}).

-record(state, {
	sess,
	socket,
	rtcp_sck,
	mobile=false,
	peer,
	peer_rtcp_addr,
	key_strategy,       % dtls | crypto.
	transport_status = stunning, % stunning | handshaking | inservice
	dtls,
	r_base,
	vr_base,
	v_sentsave,
	r_srtp,
	l_srtp,
	r_srtcp,
	l_srtcp,
	out_media,	% rtp -> media (Pid)
	in_media,	% media -> rtp
	in_audio,	% local media rtp desc #base_rtp
	in_video,	% local video rtp desc
	vp8,
	ice_state,
	bw = #esti{},
	base_wall_clock,
	report_to,
	v_jttr,
	moni		% audio monitor rtp port
}).

init([Session,{Sock1,Sock2},Options]) ->
	{Mega,Sec,_Micro} = now(),
	BaseWC = {Mega,Sec,0},
	NewState = processOptions(#state{},Options),
	ReportTo = proplists:get_value(report_to,Options),
	Media = proplists:get_value(media,Options),
	{ok,NewState#state{out_media=Media,in_media=Media,sess=Session, transport_status=stunning, socket=Sock1,
	                                                                           rtcp_sck=Sock2,vp8=#vp8_cdc{},report_to=ReportTo,mobile=true}};
init([Session,Socket,Options]) ->
	{Mega,Sec,_Micro} = now(),
	BaseWC = {Mega,Sec,0},
	NewState = processOptions(#state{},Options),
	ReportTo = proplists:get_value(report_to,Options),
	{ok,NewState#state{sess=Session, transport_status=stunning, socket=Socket,vp8=#vp8_cdc{},base_wall_clock=BaseWC,report_to=ReportTo}}.

handle_call({options,Options},_From,State) ->
	NewState = processOptions(State,Options),
	{reply,ok,NewState};

handle_call(get_self_fingerprint, _From, #state{dtls=Dtls}=State) ->
    {reply, dtls4srtp:get_self_cert_fingerpirnt(Dtls), State};


handle_call({set_video_level, Level}, _, #state{vp8=Vcdc}=ST) ->

	{reply, {ok,Vcdc#vp8_cdc.level}, ST#state{vp8=Vcdc#vp8_cdc{level=Level}}};

handle_call(get_rtp_statistics, _, #state{peer=Peer, r_base=RcvCtx,in_audio=SndCtx}=ST) ->
    {reply, calc_rtp_statistics(Peer, RcvCtx, SndCtx), ST};

handle_call(stop,_Frome, #state{peer=Peer, r_base=RcvCtx, in_audio=SndCtx, sess=Sess, dtls=DtlsP}=ST) ->
	if is_pid(ST#state.moni) -> stop_moni(ST#state.moni);
	true -> ok end,
	[{ip, IP},
	 {pr, CumuR}, 
	 {pl, CumuL}, 
	 {jitter, AvgIJ}, 
	 {rtt, AvgRTT}] = calc_rtp_statistics(Peer, RcvCtx, SndCtx),
	llog("rtp session ~p(ip:~p) statistics:{pr:~p;pl:~p;jitter:~.3fms;rtt:~.3fms}~n", [Sess, IP, CumuR, CumuL, AvgIJ, AvgRTT]),
	if is_pid(DtlsP) -> io:format("shutdown dtls~n"),dtls4srtp:shutdown(DtlsP); true -> pass end,
	{stop,normal,ok,ST};
handle_call(_Call, _From, State) ->
    {noreply,State}.

	
handle_cast({add_stream,audio,Options},State) ->
	Media = proplists:get_value(media,Options),
	KeyStrategy = proplists:get_value(key_strategy, Options),
	{WriteSRTP, WriteSRTCP} = 
		case KeyStrategy of
			crypto ->
			    {Meth,KeySalt} = proplists:get_value(crypto,Options),
			    {E_k,E_s,A_k}=srtp_keydrivate(KeySalt),
				{E_ck,E_cs,A_ck}=srtcp_keydrivate(KeySalt),
				{#cryp{method=Meth,e_k=E_k,e_s=E_s,a_k=A_k},
				  #cryp{method=Meth,e_k=E_ck,e_s=E_cs,a_k=A_ck}};
			_ ->
			    {undefined, undefined}
		end,
	{SSRC,CName} = case proplists:get_value(ssrc,Options) of
			[Id,Name] ->
				{Id,Name};
			undefined ->
				{undefined,undefined}
		end,
	CSSRC = if SSRC==undefined -> 1000;
			true -> SSRC end,
	{Mega,Sec,Micro} = now(),
	WallClock = {Mega,Sec,mini10sec(Micro)},
	TimeCode = init_rnd_timecode(),
	BaseRTP = #base_rtp{media = audio,
						cname = CName,
						ssrc = SSRC,
						cssrc = CSSRC,
						marker = true,
						roc = 0,
						seq = init_rnd_seq(),
						base_timecode = TimeCode,
						timecode = TimeCode,
						wall_clock = WallClock,
						last_sr = 0},
	if is_pid(Media) -> Media ! {play,self()};
	true -> ok end,
%	Moni = start_moni(Options),
	{noreply,State#state{in_media=Media,in_audio=BaseRTP,l_srtp=WriteSRTP,l_srtcp=WriteSRTCP}};
handle_cast({add_stream,video,Options},State) ->
	[SSRC,CName] = proplists:get_value(ssrc,Options),
	CSSRC = if SSRC==undefined -> 1001;
			true -> SSRC end,
	{Mega,Sec,Micro} = now(),
	WallClock = {Mega,Sec,minisec(Micro)},
	TimeCode = init_rnd_timecode(),
	BaseRTP = #base_rtp{media = video,
						cname = CName,
						ssrc = SSRC,
						cssrc = CSSRC,
						marker = true,
						roc = 0,
						seq = init_rnd_seq(),
						base_timecode = TimeCode,
						timecode = TimeCode,
						wall_clock = WallClock,
						last_sr = 0},
	{noreply,  State#state{in_video=BaseRTP,v_sentsave=[]}};
handle_cast({add_candidate,{IP,Port}},State) ->
	%%io:format("candidate ~p add @ice: ~p.~n",[{IP,Port},(State#state.ice_state)#st.ice]),
	case (State#state.ice_state)#st.ice of
		undefined ->
		    case State#state.key_strategy of
		    	dtls ->
		    	    dtls4srtp:start(State#state.dtls),
		    	    {noreply, State#state{transport_status=handshaking, peer={IP,Port}}};
		    	_cryptoOrUndefined ->
		    	    {noreply, State#state{transport_status=inservice, peer={IP,Port}}}
		    end;
		_ ->
		    my_timer:send_after(50,stun_bindreq),
		    {noreply, State#state{transport_status=stunning, peer={IP,Port}}}
	end;
	
handle_cast({media_relay,closed}, State) ->
	{noreply, State#state{in_media=undefined,out_media=undefined}};
handle_cast({media_relay,Media}, #state{in_media=OldMedia}=State) when is_pid(Media) ->
	if is_pid(OldMedia) -> OldMedia ! {deplay,self()};
	true -> ok end,
	Media ! {play,self()},
	%%io:format("rtp get media ~p.~n",[Media]),
	{noreply, State#state{in_media=Media,out_media=Media}};	
handle_cast(_Msg, State) ->
    {noreply, State}.	
	
%% ******** RTP SENDOUT ********
handle_info(Frame,#state{transport_status=TS} = State) when (is_record(Frame,audio_frame) or is_list(Frame)) and TS =/= inservice ->
    {noreply,State};
%
% ******** video vp8 frame / frames *******
%
handle_info({leVeled_vp8,_KF,_Level,_EncDat}, #state{in_video=undefined} = ST) ->
	{noreply,ST};
handle_info({leVeled_vp8,KF,Level,EncDat}, #state{transport_status=inservice,peer={IP,Port},vp8=Vcdc} = ST) ->
	#vp8_cdc{vp=VP,level=Limit} = Vcdc,
	SentC = if Level=<Limit ->
		VH = meeting_room:packetVP8(VP,KF,0,EncDat),
		self() ! VH,
		1;
	true -> 0 end,
	{noreply,ST#state{vp8=Vcdc#vp8_cdc{vp=VP+SentC}}};
handle_info(VP8Frames, #state{transport_status=inservice,peer={IP,Port}} = ST) when is_list(VP8Frames) ->
	BaseRTP0 = inc_timecode(ST#state.in_video),
	{NewBaseRTP,EncVP8s} = lists:foldl(fun(X,{BaseRTP,OUTs}) ->
											{NBRTP,Enc} = makeVP8(X,ST#state.l_srtp,BaseRTP),
											{NBRTP,[Enc|OUTs]}								  
									   end,
					   				   {BaseRTP0,[]},
					   				   VP8Frames),
	Sent = lists:foldr(fun(X,AccIn) -> send_udp(ST#state.socket,IP,Port,X),[X|AccIn] end,
					   [],
					   EncVP8s),
	NSentSave = save_sent(lists:reverse(Sent),ST#state.v_sentsave),
	{noreply,ST#state{in_video=NewBaseRTP,v_sentsave=NSentSave}};
handle_info(#audio_frame{codec=?VP8}=Frame,#state{transport_status=inservice,peer={IP,Port},in_video=BaseRTP0} = ST) ->
	BaseRTP = inc_timecode(BaseRTP0#base_rtp{codec=?VP8}),
	{NewBaseRTP,EncRTP} = makeVP8(Frame,ST#state.l_srtp,BaseRTP),
	send_udp(ST#state.socket,IP,Port,EncRTP),
	NSentSave = save_sent([EncRTP],ST#state.v_sentsave),
	{noreply,ST#state{in_video=NewBaseRTP,v_sentsave=NSentSave}};
%% 
handle_info({send_lost,video,Seqs},#state{transport_status=inservice,peer={IP,Port},v_sentsave=VSentSave}=ST) ->
	Losts = get_all_seqs(Seqs,VSentSave),
	N = lists:foldl(fun(X,AccIn) -> send_udp(ST#state.socket,IP,Port,X),AccIn+1 end,
					0,
					Losts),
	%% io:format("~p resent.~n",[N]),
	{noreply,ST};

%
% ******** audio frame pcmu with cn and isac with cn *******
%
handle_info(#audio_frame{codec=Codec,marker=Marker,body=Body,samples=Samples},
            #state{transport_status=TS,peer={IP,Port},in_audio=BaseRTP,l_srtp=Crypto,socket=Socket} = ST)
            when Codec==?PCMU;Codec==?CN;Codec==?iSAC;Codec==?iCNG;Codec==?iLBC;Codec==?OPUS ->
	BaseRTP2 = inc_timecode_fixed(BaseRTP#base_rtp{codec=Codec,marker=Marker},Samples),
	{OutBin,NewBase} = if Crypto==undefined ->
							{BaseRTP3, RTP} = compose_rtp(BaseRTP2,Body),
							{RTP, BaseRTP3};
					   true ->
							#cryp{method=Method,e_k=E_k,e_s=E_s,a_k=A_k}=Crypto,
							#base_rtp{ssrc=SSRC,roc=ROC,seq=Seq} = BaseRTP2,
							Enc = srtp_enc({E_k,E_s},{<<SSRC:32>>,ROC,Seq},Body),
							{BaseRTP3, RTP} = compose_rtp(BaseRTP2,Enc),
							Digest = srtp_digest(A_k,<<RTP/binary,ROC:32>>, Method),
							{<<RTP/binary,Digest/binary>>, BaseRTP3}
					   end,
	send_udp(Socket,IP,Port,OutBin),
	{noreply, ST#state{in_audio=NewBase}};

%% ******** RTP RECEIVE ********
%
% pcmu audio frame and comfortable_noise received.
%
handle_info(UdpMsg={udp,_Socket,Addr,Port,<<2:2,_:6,Mark:1,Codec:7,InSeq:16,TS:32,SSRC:32,_/binary>> =Bin},
			#state{sess=Sess, r_base=#base_info{seq=undefined,ssrc=undefined}=Remote0,r_srtp=Cryp,mobile=true}=ST)
			when Codec==?PCMU;Codec==?CN;Codec==?iSAC;Codec==?iCNG;Codec==?iLBC;Codec==?OPUS ->
	Peer = trans:check_peer(ST#state.peer,{Addr,Port}),
	rtp_report(ST#state.report_to,Sess,{stun_locked,Sess}),
	send_media(ST#state.out_media,{stun_locked,self()}),
					
	Remote = Remote0#base_info{base_timecode=TS,base_seq=InSeq,ssrc=SSRC,pln=Codec,roc=0,seq=InSeq,timecode=TS,previous_ts={TS,now()},pkts_rcvd=1,cumu_rcvd=1},
	Samples = if Codec==?PCMU;Codec==?CN -> ?PSIZE;
			  true -> 960 end,
	AParams = [ST#state.out_media,Mark,Codec,{0,InSeq},Samples,SSRC,Cryp=undefined],
	decryp_and_send_audio(AParams,UdpMsg),
	start_rtcp(ST#state.in_audio,ST#state.in_video,Remote,ST#state.vr_base),
	{noreply,ST#state{peer=Peer,r_base=Remote}};

handle_info(UdpMsg={udp,_Socket,Addr,Port,<<2:2,_:6,Mark:1,Codec:7,InSeq:16,TS:32,SSRC:32,_/binary>> =Bin},
			#state{r_base=#base_info{seq=undefined,ssrc=SSRC}=Remote0,r_srtp=Cryp,transport_status=inservice,peer={Addr,Port}}=ST)
			when Codec==?PCMU;Codec==?CN;Codec==?iSAC;Codec==?iCNG;Codec==?iLBC;Codec==?OPUS ->
	Remote = Remote0#base_info{base_timecode=TS,base_seq=InSeq},
	Samples = if Codec==?PCMU;Codec==?CN -> ?PSIZE;
			  true -> 960 end,
	AParams = [ST#state.out_media,Mark,Codec,{0,InSeq},Samples,SSRC,Cryp],
	decryp_and_send_audio(AParams,UdpMsg),
	{noreply,ST#state{r_base=Remote#base_info{pln=Codec,roc=0,seq=InSeq,timecode=TS,previous_ts={TS,now()},pkts_rcvd=1,cumu_rcvd=1}}};

handle_info(UdpMsg={udp,_Socket,Addr,Port,<<2:2,_:6,Mark:1,Codec:7,InSeq:16,TS:32,SSRC:32,_/binary>> =Bin},
			#state{r_base=#base_info{roc=LastROC,seq=LastSeq,timecode=LastTs,ssrc=SSRC}=Remote,r_srtp=Cryp,transport_status=inservice,peer={Addr,Port}}=ST)
			when Codec==?PCMU;Codec==?CN;Codec==?iSAC;Codec==?iCNG;Codec==?iLBC;Codec==?OPUS ->
	Now = now(),
	#base_info{interarrival_jitter=IAJitter,previous_ts=PreTS}=Remote,
	#base_info{pkts_rcvd=PktR,pkts_lost=PktL,cumu_lost=CumuL,lost_seqs=LastLost, cumu_rcvd=CumuR}=Remote,
	IAJitter2 = compute_interarrival_jitter(codec_factor(Codec),IAJitter,{TS,Now},PreTS),
	{ExpectROC,ExpectSeq} = get_expect_seq(LastROC,LastSeq),
	if InSeq==ExpectSeq ->
		AParams = [ST#state.out_media,Mark,Codec,{ExpectROC,InSeq},TS-LastTs,SSRC,Cryp],
		decryp_and_send_audio(AParams,UdpMsg),
		{noreply,ST#state{r_base=Remote#base_info{pln=Codec,roc=ExpectROC,seq=ExpectSeq,timecode=TS,previous_ts={TS,Now},interarrival_jitter=IAJitter2,pkts_rcvd=PktR+1,cumu_rcvd=CumuR+1}}};
	true ->
		case judge_bad_seq(LastSeq,InSeq) of
			{forward,N} ->
				send_media(ST#state.out_media,#audio_frame{codec=?LOSTAUDIO,samples=N,body= <<>>}),
				{_,ROC,_} = count_up_to_seq(InSeq,{LastROC,LastSeq}),
				Samples = if Codec==?PCMU;Codec==?CN -> ?PSIZE;
						  true -> 960 end,
				AParams = [ST#state.out_media,Mark,Codec,{ROC,InSeq},Samples,SSRC,Cryp],
				decryp_and_send_audio(AParams,UdpMsg),
				{noreply,ST#state{r_base=Remote#base_info{pln=Codec,roc=ROC,seq=InSeq,timecode=TS,previous_ts={TS,Now},interarrival_jitter=IAJitter2,pkts_rcvd=PktR+1,pkts_lost=PktL+(N-1), cumu_lost=CumuL+(N-1),cumu_rcvd=CumuR+1}}};
			{backward,_} ->
				{noreply,ST}
		end
	end;

%
% vp8 video frame received,add jitter buffer.
%
handle_info({udp,_,_,_,<<2:2,_:6,Mark:1,?VP8:7,InSeq:16,TS:32,SSRC:32,_/binary>> =Bin},
			#state{vr_base=#base_info{seq=undefined,ssrc=SSRC}=Remote, r_srtp=Cryp}=ST) ->
	Now = now(),
	self() ! {receive_packet,InSeq,Now,size(Bin)},
	Marker = if Mark==1 -> true; true -> false end,
	NewRemo = Remote#base_info{base_timecode=TS,timecode=TS,base_seq=InSeq,seq=InSeq,previous_ts={TS,Now}},
	VMParams = [ST#state.out_media,Marker,90,SSRC,0,InSeq,Cryp],
	decryp_and_send_media_frame(VMParams,Bin),
	{noreply,ST#state{vr_base=NewRemo#base_info{pln=?VP8,pkts_rcvd=1},v_jttr=[]}};
handle_info({udp,_,_,_,<<2:2,_:6,Mark:1,?VP8:7,InSeq:16,TS:32,SSRC:32,_/binary>> =Bin},
			#state{vr_base=#base_info{ssrc=SSRC}=Remote,v_jttr=VJttr, r_srtp=Cryp}=ST) ->
	Now = now(),
	self() ! {receive_packet,InSeq,Now,size(Bin)},
	#base_info{roc=LastROC,seq=LastSeq,timecode=LastTS,interarrival_jitter=IAJitter,previous_ts=PreTS}=Remote,
	#base_info{pkts_rcvd=PktR,pkts_lost=PktL,cumu_lost=CumuL,lost_seqs=LastLost}=Remote,
	Marker = if Mark==1 -> true; true -> false end,
	{ExpectROC,ExpectSeq} = get_expect_seq(LastROC,LastSeq),
	if InSeq==ExpectSeq ->
		VMParams = [ST#state.out_media,Marker,TS-LastTS,SSRC,ExpectROC,ExpectSeq,Cryp],
		decryp_and_send_media_frame(VMParams,Bin),
		if VJttr==[] ->
			IAJitter2 = compute_interarrival_jitter(codec_factor(?VP8),IAJitter,{TS,Now},PreTS),
			{noreply,ST#state{vr_base=Remote#base_info{roc=ExpectROC,seq=ExpectSeq,timecode=TS,
													   pkts_rcvd=PktR+1,
													   interarrival_jitter=IAJitter2,
													   previous_ts={TS,Now}},
							  v_jttr=[]}};
		true ->
			VMParams2 = [ST#state.out_media,TS,SSRC,ExpectROC,ExpectSeq,Cryp],
			{_SntN,ROC2,Seq2,TS2,NVJ2} = decryp_and_send_onseq_from_vjttr(0,VMParams2,VJttr),
			io:format("vp8 seq recover: {~p,~p} to {~p,~p}~n",[ExpectROC,ExpectSeq,ROC2,Seq2]),
			{noreply,ST#state{vr_base=Remote#base_info{roc=ROC2,seq=Seq2,timecode=TS2,
													   pkts_rcvd=PktR+1,
													   pkts_lost=PktL-1,
													   cumu_lost=CumuL-1,
													   lost_seqs=lists:delete(InSeq,LastLost)},
							  v_jttr=NVJ2}}
		end;
	true ->
		case judge_bad_seq(LastSeq,InSeq) of
			{forward,N} when N<?JITTERLENGTH ->
				IAJitter2 = compute_interarrival_jitter(codec_factor(?VP8),IAJitter,{TS,Now},PreTS),
				{ThisLost,NewVJttr} = insert2proper_posi(N,InSeq,Bin,VJttr),
				LostSeqs = make_lost_seqs(ExpectSeq,[SX||<<_:16,SX:16,_/binary>> <- NewVJttr]),
				case lists:member(hd(LostSeqs),LastLost) of
					false -> self() ! {send_nack,0,video};
					true -> pass
				end,
				{noreply,ST#state{vr_base=Remote#base_info{pkts_rcvd=PktR+1,
														   pkts_lost=PktL+ThisLost,
														   cumu_lost=CumuL+ThisLost,
														   lost_seqs=LostSeqs,
														   interarrival_jitter=IAJitter2,
														   previous_ts={TS,Now}},
								  v_jttr=NewVJttr}};
			{forward,N} ->
				{ThisLost,VJttr2} = insert2proper_posi(N,InSeq,Bin,VJttr),
				VMParams2 = [ST#state.out_media,LastTS,SSRC,LastROC,LastSeq,Cryp],
				{ROC2,Seq2,TS2,_LostSeqs} = flush_media_from_vjttr(VMParams2,VJttr2,[]),
				io:format("vp8 seq flush: {~p,~p} to {~p,~p} ",[LastROC,LastSeq,ROC2,Seq2]),
				{noreply,ST#state{vr_base=Remote#base_info{roc=ROC2,seq=Seq2,timecode=TS2,
														   pkts_rcvd=PktR+1,
														   pkts_lost=PktL+ThisLost,
														   cumu_lost=CumuL+ThisLost,
														   lost_seqs=[]},
								  v_jttr=[]}};
			{backward,_N} ->		% resend package, dropped!
				io:format("vp8 seq ~p backward, expect: {~p,~p}~n",[InSeq,ExpectROC,ExpectSeq]),
				{noreply,ST#state{vr_base=Remote#base_info{pkts_rcvd=PktR+1,pkts_lost=PktL-1,cumu_lost=CumuL-1}}}
		end
	end;

%
%% ******** RTCP ********
%
handle_info(Udp={udp, _Socket, Addr, Port, <<2:2,_P:1,_C:5,PT:8,_LenDW:16,_SSRC:32,_/binary>>},
	#state{mobile=true,peer_rtcp_addr=undefined}=ST) when ?is_rtcp(PT) ->
       handle_info(Udp,ST#state{peer_rtcp_addr={Addr,Port}});
handle_info({udp, _Socket, Addr, Port, <<2:2,_P:1,_C:5,PT:8,_LenDW:16,SSRC:32,_/binary>> =Bin},
	#state{socket=Socket,mobile=true,vp8=Vcdc,bw=BWE,peer_rtcp_addr={Addr, Port}}=ST) when ?is_rtcp(PT) ->
	Now = now(),
	Parsed = rtcp:parse(Bin),
	{Rbase2,VRbase2} = update_sr_timecode(Now,Parsed,{ST#state.r_base,ST#state.vr_base}),
	{InAudio1,InVideo2} = update_fb_info(Now,Parsed,{ST#state.in_audio,ST#state.in_video}),
	InAudio2 = update_avg_rtt(InAudio1),
	notify_lost_seqs(Now,Parsed,{ST#state.in_audio,ST#state.in_video}),
	notify_video_pli(Parsed,ST#state.in_media),
	if is_record(ST#state.in_video,base_rtp) ->		% rpt expect peer-rtcp source_report
		{Level2,BWE2} =
			estimate_video_level3((ST#state.vp8)#vp8_cdc.level,(ST#state.in_video)#base_rtp.ssrc,Parsed,BWE),
		{noreply,ST#state{in_audio=InAudio2,in_video=InVideo2,r_base=Rbase2,vr_base=VRbase2,
					  vp8=Vcdc#vp8_cdc{level=Level2},bw=BWE2}};
	true ->
		{noreply,ST#state{in_audio=InAudio2,in_video=InVideo2,r_base=Rbase2,vr_base=VRbase2}}
	end;

handle_info({udp, _Socket, Addr, _Port, <<2:2,_P:1,_C:5,PT:8,_LenDW:16,SSRC:32,_/binary>> =Bin},
	#state{socket=Socket,r_srtcp=#cryp{method=Method, e_k=Key,e_s=Salt,a_k=A_k},vp8=Vcdc,bw=BWE}=ST) when PT==?RTCP_SR;PT==?RTCP_RR ->
	Now = now(),
	ISize = size(Bin) - ?RTCPHEADLENGTH - srtcp_digest_length(Method) - ?RTCPEIDXLENGTH,
	<<Head:?RTCPHEADLENGTH/binary,Info:ISize/binary,EIdx:?RTCPEIDXLENGTH/binary,Digest/binary>> = Bin,
	case check_srtcp_digest(Digest,A_k,<<Head/binary,Info/binary,EIdx/binary>>, Method) of
		true ->
	<<_:1,Idx:31>> = EIdx,
	IVec = xor3(<<Salt/binary,0:16>>, <<0:32,SSRC:32,0:64>>, <<0:64,0:16,Idx:32,0:16>>),
	RTCP=aes_ctr_enc(Info,Key,IVec),
%	send_udp(Socket,Addr,60000,<<Head/binary,RTCP/binary, EIdx/binary, Digest/binary>>),
	Parsed = rtcp:show_rtcp(self(),<<Head/binary,RTCP/binary>>),
	{Rbase2,VRbase2} = update_sr_timecode(Now,Parsed,{ST#state.r_base,ST#state.vr_base}),
	{InAudio1,InVideo2} = update_fb_info(Now,Parsed,{ST#state.in_audio,ST#state.in_video}),
	InAudio2 = update_avg_rtt(InAudio1),
	notify_lost_seqs(Now,Parsed,{ST#state.in_audio,ST#state.in_video}),
	notify_video_pli(Parsed,ST#state.in_media),
	if is_record(ST#state.in_video,base_rtp) ->		% rpt expect peer-rtcp source_report
		{Level2,BWE2} =
			estimate_video_level3((ST#state.vp8)#vp8_cdc.level,(ST#state.in_video)#base_rtp.ssrc,Parsed,BWE),
		{noreply,ST#state{in_audio=InAudio2,in_video=InVideo2,r_base=Rbase2,vr_base=VRbase2,
					  vp8=Vcdc#vp8_cdc{level=Level2},bw=BWE2}};
	true ->
		{noreply,ST#state{in_audio=InAudio2,in_video=InVideo2,r_base=Rbase2,vr_base=VRbase2}}
	end;
		false ->	% digest error
			{noreply,ST}
	end;
handle_info({send_sr,_,_},#state{transport_status=TS} = ST) when TS =/= inservice ->
	{noreply,ST};
	
handle_info({send_sr,_,audio},#state{sess=Session, peer_rtcp_addr=Peer,rtcp_sck=Socket,r_base=RcvCtx, in_audio=InAudio,
                                     mobile=true} = ST) ->
	Now = now(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,0,audio}),
	#base_rtp{cssrc=VSSRC,last_sr=LastSR} = InAudio,
	{NRBase1,Head,Body} = make_rtcp(Now,InAudio,ST#state.r_base),
	NRBase = update_avg_ij(NRBase1),
	Stat = calc_rtp_statistics(Peer, RcvCtx, InAudio),
	
	rtp_report(ST#state.report_to,Session,{call_stats, Session, Stat}),
	case Peer of
	{IP,Port}->	send_udp(Socket, IP, Port, <<Head/binary,Body/binary>>);
	_-> void
	end,
	{noreply, ST#state{in_audio=InAudio#base_rtp{last_sr=LastSR+1},r_base=NRBase}};
handle_info({send_sr,_,audio},#state{sess=Session, peer={IP,Port}=Peer,socket=Socket,r_base=RcvCtx, in_audio=InAudio,
                                     l_srtcp=#cryp{method=Method,e_k=Key,e_s=Salt,a_k=A_k}} = ST) ->
	Now = now(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,0,audio}),
	#base_rtp{cssrc=VSSRC,last_sr=LastSR} = InAudio,
	{IVec,EIdx} = makeIVec(Salt,VSSRC,LastSR+1),
	{NRBase1,Head,Body} = make_rtcp(Now,InAudio,ST#state.r_base),
	NRBase = update_avg_ij(NRBase1),
	RTCP = aes_ctr_enc(Body,Key,IVec),
	Digest = srtcp_digest(A_k,<<Head/binary,RTCP/binary,EIdx/binary>>, Method),
	
	Stat = calc_rtp_statistics(Peer, RcvCtx, InAudio),
	
	rtp_report(ST#state.report_to,Session,{call_stats, Session, Stat}),
	
	send_udp(Socket, IP, Port, <<Head/binary,RTCP/binary,EIdx/binary,Digest/binary>>),
%	send_udp(Socket, IP, 60001, <<Head/binary,Body/binary,EIdx/binary,Digest/binary>>),
    
	{noreply, ST#state{in_audio=InAudio#base_rtp{last_sr=LastSR+1},r_base=NRBase}};
handle_info({send_sr,Ref1,video},#state{in_video=#base_rtp{sr_ref=Ref2}} = ST) when Ref1=/=Ref2 ->
	{noreply,ST};
handle_info({send_sr,_Ref1,video},#state{peer={IP,Port},socket=Socket,in_video=InVideo,l_srtcp=#cryp{method=Method,e_k=Key,e_s=Salt,a_k=A_k}} = ST) ->
	Now = now(),
	Ref2 = make_ref(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,Ref2,video}),
	#base_rtp{cssrc=VSSRC,last_sr=LastSR} = InVideo,
	{IVec,EIdx} = makeIVec(Salt,VSSRC,LastSR+1),
	{NVRBase,Head,SR} = make_rtcp(Now,InVideo,ST#state.vr_base),	% read and clear pkts lost/rcvd
	REMB = make_rtcp_remb(InVideo#base_rtp.cssrc,NVRBase#base_info.ssrc,NVRBase#base_info.remb),
	Body = <<SR/binary,REMB/binary>>,
	RTCP = aes_ctr_enc(Body,Key,IVec),
	Digest = srtcp_digest(A_k,<<Head/binary,RTCP/binary,EIdx/binary>>, Method),
	send_udp(Socket, IP, Port, <<Head/binary,RTCP/binary,EIdx/binary,Digest/binary>>),
%	send_udp(Socket, IP, 60002, <<Head/binary,Body/binary,EIdx/binary,Digest/binary>>),
	{noreply, ST#state{in_video=InVideo#base_rtp{sr_ref=Ref2,last_sr=LastSR+1},vr_base=NVRBase}};
handle_info({send_nack,_,video},#state{peer={IP,Port},socket=Socket,in_video=InVideo,l_srtcp=#cryp{method=Method,e_k=Key,e_s=Salt,a_k=A_k}} = ST) ->
	Now = now(),
	#base_rtp{cssrc=VSSRC,last_sr=LastSR} = InVideo,
	{IVec,EIdx} = makeIVec(Salt,VSSRC,LastSR+1),
%	io:format(" NACK~p ",[LastSR+1]),
	{NVRBase,Head,SR} = make_rtcp(Now,InVideo,ST#state.vr_base),
	NACK = make_rtcp_nack(InVideo,ST#state.vr_base),
	Body = <<SR/binary,NACK/binary>>,
	RTCP = aes_ctr_enc(Body,Key,IVec),
	Digest = srtcp_digest(A_k,<<Head/binary,RTCP/binary,EIdx/binary>>,Method),
	send_udp(Socket, IP, Port, <<Head/binary,RTCP/binary,EIdx/binary,Digest/binary>>),
%	send_udp(Socket, IP, 60002, <<Head/binary,Body/binary,EIdx/binary,Digest/binary>>),
	Ref2 = make_ref(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,Ref2,video}),
	{noreply, ST#state{in_video=InVideo#base_rtp{sr_ref=Ref2,last_sr=LastSR+1},vr_base=NVRBase}};
handle_info({send_pli,_,video},#state{peer={IP,Port},socket=Socket,in_video=InVideo,l_srtcp=#cryp{method=Method,e_k=Key,e_s=Salt,a_k=A_k}} = ST) ->
	Now = now(),
	#base_rtp{cssrc=VSSRC,last_sr=LastSR} = InVideo,
	{IVec,EIdx} = makeIVec(Salt,VSSRC,LastSR+1),
	{NVRBase,Head,SR} = make_rtcp(Now,InVideo,ST#state.vr_base),
	PLI = make_rtcp_pli(InVideo,ST#state.vr_base),
	Body = <<SR/binary,PLI/binary>>,
	RTCP = aes_ctr_enc(Body,Key,IVec),
	Digest = srtcp_digest(A_k,<<Head/binary,RTCP/binary,EIdx/binary>>,Method),
	send_udp(Socket, IP, Port, <<Head/binary,RTCP/binary,EIdx/binary,Digest/binary>>),
%	send_udp(Socket, IP, 60002, <<Head/binary,Body/binary,EIdx/binary,Digest/binary>>),
	Ref2 = make_ref(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,Ref2,video}),
	{noreply, ST#state{in_video=InVideo#base_rtp{sr_ref=Ref2,last_sr=LastSR+1},vr_base=NVRBase}};
handle_info({send_remb,_,TBr},#state{bw=BWE}=ST) ->
	{noreply, ST#state{bw=BWE#esti{v_target_br=TBr}}};
handle_info({receive_packet,Seq,_WC,_Size}, #state{vr_base=RVideo,bw=BWE}=ST) ->
	{TBr,BWE2} = upd_rcv_bw(BWE, Seq),			% estimate pkts lost/rcvd, add to bw #esti
	{noreply, ST#state{bw=BWE2,vr_base=RVideo#base_info{remb=TBr}}};

%% ******** STUN ********
handle_info({udp,_,_,_,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},#state{ice_state=#st{ice=undefined}}=ST) ->			% STUN
%	io:format("unknow/unset stun bin: ~p.~n",[Bin]),
	{noreply,ST};
handle_info({udp,Socket,Addr,Port,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},#state{sess=Sess,ice_state=ICE}=ST) ->			% STUN
	case stun:handle_msg({udp_receive,Addr,Port,Bin},ICE) of
		{ok,{request,Response},NewICE} ->
			send_udp(Socket,Addr,Port,Response),
			{noreply,ST#state{ice_state=NewICE}};
		{ok,response,NewICE} ->
			case ST#state.transport_status of
				stunning ->
				    llog("report_to ~p",[ST#state.report_to]),
					rtp_report(ST#state.report_to,Sess,{stun_locked,Sess}),
					llog("peer_ip_looked ~p",[NewICE#st.wan_ip]),
					send_media(ST#state.out_media,{stun_locked,self()}),
					case ST#state.key_strategy of
					    dtls ->
					        dtls4srtp:start(ST#state.dtls),
							{noreply,ST#state{transport_status=handshaking,peer=NewICE#st.wan_ip,ice_state=NewICE}};
					    crypto ->
							start_rtcp(ST#state.in_audio,ST#state.in_video,ST#state.r_base,ST#state.vr_base),
							{noreply,ST#state{transport_status=inservice,peer=NewICE#st.wan_ip,ice_state=NewICE}}
					end;
                _ ->
                    {noreply,ST}
            end;
		_ -> {noreply, ST}
	end;
handle_info(stun_bindreq,#state{socket=Socket,peer={Addr,Port},ice_state=ICE}=ST) ->
	{ok,{request,Request},_} = stun:handle_msg(bindreq,ICE),
	case ICE#st.wan_ip of
		undefined ->
			send_udp(Socket,Addr,Port,Request);
		{WAddr,WPort} ->
			send_udp(Socket,WAddr,WPort,Request)
	end,
	my_timer:send_after(500,stun_bindreq),
	{noreply,ST};

%
% ******** DTLS *******
%
handle_info({udp, _Socket, Addr, Port, <<0:2,_:1,1:1,_:1,1:1,_:2,_/binary>>},#state{dtls=undefined}=ST) ->
%	io:format("DTLS message from~p ~p. But self not ready~n",[Addr,Port]),
	{noreply,ST};
handle_info({udp, _Socket, Addr, Port, <<0:2,_:1,1:1,_:1,1:1,_:2,_/binary>>=DtlsFlight},#state{dtls=Dtls}=ST) ->
%	io:format("DTLS message from~p ~p.~n",[Addr,Port]),
	dtls4srtp:on_received(Dtls, DtlsFlight),
	{noreply,ST};

handle_info({dtls, flight, Bin}, #state{socket=Socket,peer={Addr,Port}}=ST) -> 
    send_udp(Socket,Addr,Port,Bin),
    {noreply, ST};
handle_info({dtls, key_material, #srtp_params{protection_profile_name=PPN,
	                                          client_write_SRTP_master_key=CWMK,
											  server_write_SRTP_master_key=SWMK,
											  client_write_SRTP_master_salt=CWMS,
											  server_write_SRTP_master_salt=SWMS}}, #state{}=ST) ->
    {WE_k,WE_s,WA_k}=srtp_keydrivate(CWMK, CWMS),
	{WE_ck,WE_cs,WA_ck}=srtcp_keydrivate(CWMK, CWMS),
	Write_SRTP = #cryp{method=PPN,e_k=WE_k,e_s=WE_s,a_k=WA_k},
	Write_SRTCP = #cryp{method=PPN,e_k=WE_ck,e_s=WE_cs,a_k=WA_ck},
	{RE_k,RE_s,RA_k}=srtp_keydrivate(SWMK, SWMS),
	{RE_ck,RE_cs,RA_ck}=srtcp_keydrivate(SWMK, SWMS),
	Read_SRTP = #cryp{method=PPN,e_k=RE_k,e_s=RE_s,a_k=RA_k},
	Read_SRTCP = #cryp{method=PPN,e_k=RE_ck,e_s=RE_cs,a_k=RA_ck},
	start_rtcp(ST#state.in_audio,ST#state.in_video,ST#state.r_base,ST#state.vr_base),
%	io:format("dtls setup keys!~n"),
    {noreply, ST#state{transport_status=inservice, l_srtp=Write_SRTP, l_srtcp=Write_SRTCP, r_srtp=Read_SRTP, r_srtcp=Read_SRTCP}};

%
% ******** bad message, socket received *******
%
handle_info({udp, _Socket, Addr, Port, Bin},ST=#state{transport_status=TranStatus}) ->
	%%io:format("rtp bad msg from ~p ~p~n~p~n",[Addr,Port,Bin]),
	if TranStatus == inservice-> 	llog("rtp bad msg from ~p ~p~n~p~nST:~p~n",[Addr,Port,Bin,ST]);
	   true-> void
	end,
	{noreply,ST};
handle_info(Msg,ST) ->
	%%io:format("rtp bad msg from ~p ~p~n~p~n",[Addr,Port,Bin]),
	llog("rtp unknown msg ~p~nST:~p~n",[Msg,ST]),
	{noreply,ST}.

%
% ******** socket closed *******
%

terminate(normal, _) ->
	ok.

% ----------------------------------
%	internal functions
% ----------------------------------
%
processOptions(State,Options) ->
	OM = proplists:get_value(outmedia,Options),
	KeyStrategy = proplists:get_value(key_strategy, Options),
	{{ReadSRTP, ReadSRTCP}, Dtls} = 
		case KeyStrategy of
		      undefined->{{undefined,undefined},undefined};
			crypto ->
			    {Meth,KeySalt} = proplists:get_value(crypto,Options),
			    %io:format("Options:~p,KeySalt:~p.~n", [Options, KeySalt]),
			    {E_k,E_s,A_k}=srtp_keydrivate(KeySalt),
				{E_ck,E_cs,A_ck}=srtcp_keydrivate(KeySalt),
				{{#cryp{method=Meth,e_k=E_k,e_s=E_s,a_k=A_k},
				  #cryp{method=Meth,e_k=E_ck,e_s=E_cs,a_k=A_ck}}, 
				  undefined};
			dtls ->
			    PeerFingerprint = proplists:get_value(fingerprint, Options),
			    {CertF, KeyF} = avscfg:get(certificate),
			    DtlsP = dtls4srtp:new(client, self(), PeerFingerprint, CertF, KeyF),
			    {{undefined, undefined}, DtlsP}
		end,
	SSRC = case proplists:get_value(ssrc,Options) of
			[ID,_] ->
				ID;
			undefined ->
				undefined
		end,
	Remote = #base_info{ssrc=SSRC,roc=0},
	VSSRC = case proplists:get_value(vssrc,Options) of
			[VID,_] ->
				VID;
			undefined ->
				undefined
		end,
	VRemote = #base_info{ssrc=VSSRC,roc=0},
	STUN = proplists:get_value(stun,Options),
	ICE = #st{ice=STUN},
	State#state{out_media=OM,key_strategy=KeyStrategy, dtls=Dtls, r_srtp=ReadSRTP,r_srtcp=ReadSRTCP,r_base=Remote,vr_base=VRemote,ice_state=ICE}.

save_sent([],Saved) ->
	Saved;
save_sent([H|T],Saved) when length(Saved)<?SENTSAVELENGTH ->
	save_sent(T, [H|Saved]);
save_sent([H|T]=Sent,Saved) ->
	{Saved1,_} = lists:split(?SENTSAVELENGTH-length(Sent),Saved),
	save_sent(T, [H|Saved1]).

get_all_seqs(_,[]) ->
	[];
get_all_seqs(Seqs,RSentSave) ->
	SentSave = lists:reverse(RSentSave),
	<<_:16,FirstSaved:16,_/binary>> = hd(SentSave),
	case judge_bad_seq(FirstSaved,hd(Seqs)) of
		{backward,N} when N=/=0 ->
			[];
		_ ->
			get_seq_1by1(Seqs,SentSave)
	end.

get_seq_1by1([],_) ->
	[];
get_seq_1by1(Seqs,[]) ->
%	io:format("bad nack ~p request.~n",[Seqs]),
	[];
get_seq_1by1([Seq|T],[<<_:16,Seq:16,_/binary>> =Bin|Rest]) ->
	[Bin|get_seq_1by1(T,Rest)];
get_seq_1by1([Seq|T],[_|Rest]) ->
	get_seq_1by1([Seq|T],Rest).

update_sr_timecode(Now,RTCPElmts,{#base_info{ssrc=Audio}=Rbase,#base_info{ssrc=Video}=VRbase}) ->
	case [{X#rtcp_sr.ssrc,X#rtcp_sr.ts64}||X<-RTCPElmts,is_record(X,rtcp_sr)] of
		[{Video,<<_:16,TS1:32,_:16>>}] ->
			{Rbase,VRbase#base_info{ts_m32=TS1,rcv_timecode=Now}};
		[{Audio,<<_:16,TS1:32,_:16>>}] ->
   			{Rbase#base_info{ts_m32=TS1,rcv_timecode=Now},VRbase};
		_ ->
			{Rbase,VRbase}
	end.

update_fb_info(Now,RTCPElmts,{#base_rtp{ssrc=Audio}=InAudio,undefined}) ->
	{InAudio2,_} = case fetch_source_report(RTCPElmts)  of
			[#source_report{ssrc=Audio,lost={FLost,_},sr_ts=SRTS,sr_delay=SRDelay}] ->
				%io:format(",t1':~p,t2:~p,delay:~p~n", [SRTS, Now, SRDelay]),
				Rtt = compute_rtt(Now,SRTS,SRDelay),
				{InAudio#base_rtp{rtt=Rtt,fraction_lost=FLost},undefined};
			_ -> {InAudio,undefined}
		end,
	{InAudio2,undefined};
update_fb_info(Now,RTCPElmts,{#base_rtp{ssrc=Audio}=InAudio,#base_rtp{ssrc=Video}=InVideo}) ->
	{InAudio2,InVideo2} = case fetch_source_report(RTCPElmts)  of
			[#source_report{ssrc=Video,lost={FLost,_},sr_ts=SRTS,sr_delay=SRDelay}] ->
				Rtt = compute_rtt(Now,SRTS,SRDelay),
				{InAudio,InVideo#base_rtp{rtt=Rtt,fraction_lost=FLost}};
			[#source_report{ssrc=Audio,lost={FLost,_},sr_ts=SRTS,sr_delay=SRDelay}] ->
				Rtt = compute_rtt(Now,SRTS,SRDelay),
				{InAudio#base_rtp{rtt=Rtt,fraction_lost=FLost},InVideo};
			_ -> {InAudio,InVideo}
		end,
	{InAudio3,InVideo3} = case [{X#rtcp_pl.ms,X#rtcp_pl.pli,X#rtcp_pl.nack,X#rtcp_pl.remb}||X<-RTCPElmts,is_record(X,rtcp_pl)] of
			[{Video,Pli,_Losts,REMB}] ->
				{InAudio2,InVideo2#base_rtp{fb_pli=Pli,fb_remb=REMB}};
			_ -> {InAudio2,InVideo2}
		end,
	{InAudio3,InVideo3}.

fetch_source_report(RTCPElmts) ->
	case lists:keysearch(rtcp_sr,1,RTCPElmts) of
		{value,#rtcp_sr{receptions=Source}} ->
			Source;
		false ->
			case lists:keysearch(rtcp_rr,1,RTCPElmts) of
				{value,#rtcp_rr{receptions=Source}} ->
					Source;
				false -> []
			end
	end.

compute_rtt(Now,LastTS,Delay) ->
	{MSW, LSW} = make_ts64(Now),
	<<_:16,MidTS:32,_:16>> = <<MSW:32,LSW:32>>,
	RTT0 = MidTS - LastTS - Delay,		% rfc3550 P40
	RTT1 = if RTT0 < 0 -> 0; true -> RTT0 end,
	<<RTT:16,Fra:16>> = <<RTT1:32>>,
	RTT + Fra / 16#10000.

calc_rtp_statistics(Peer,
	                #base_info{pln=Codec,
		                              cumu_rcvd=CumuR,
		                              cumu_lost=CumuL,
		                              avg_ij=AvgIJ}, 
		            #base_rtp{avg_rtt=AvgRTT}) ->
    IP = case Peer of
    	    {Addr, _Port} -> Addr;
    	    _ -> unknow
    	 end,
    AvgIJms = (AvgIJ / codec_factor(Codec)) * 1.0,
	AvgRTTms = AvgRTT * 1000 * 1.0,
	[{ip, IP},{pr, CumuR}, {pl, CumuL}, {jitter, AvgIJms}, {rtt, AvgRTTms}].

estimate_video_level3(OldL,Video,RTCPElmts,#esti{v_snd_eseq=LastESeq,v_snd_pkts=SPkts,v_snd_lost=SPLost,v_snd_remb=SRemb}=BWE) ->
	{PRcvd,PLost,ESeq} = case fetch_source_report(RTCPElmts)  of
			[#source_report{ssrc=Video,lost={FLost,_},eseq=Seq}] ->
				N=rpackets(Seq,LastESeq),
				{N,trunc(N*FLost),Seq};
			_ -> 
				{0,0,LastESeq}
		end,
	{RPli,RRemb} = case [{X#rtcp_pl.ms,X#rtcp_pl.pli,X#rtcp_pl.nack,X#rtcp_pl.remb}||X<-RTCPElmts,is_record(X,rtcp_pl)] of
			[{Video,Pli,_Losts,REMB}] -> {Pli,REMB};
			_ -> {false,undefined}
		end,
	if SPkts+PRcvd>100 ->
		LostRate = (SPLost+PLost)/(SPkts+PRcvd),
%		io:format("send lostrate: ~p~n",[LostRate]),
		L2 = estimate_video_level2(OldL,#base_rtp{fb_pli=RPli,fb_remb=SRemb,fraction_lost=LostRate}),
		{L2,BWE#esti{v_snd_eseq=ESeq,v_snd_pkts=0,v_snd_lost=0,v_snd_remb=RRemb}};
	true ->
		{OldL,BWE#esti{v_snd_eseq=ESeq,v_snd_pkts=SPkts+PRcvd,v_snd_lost=SPLost+PLost,v_snd_remb=RRemb}}
	end.

rpackets(ESeq,LastESeq) ->
	Inc = ESeq - LastESeq,
	if Inc>=0 -> Inc;
	true -> 16#100000000+Inc
	end.

estimate_video_level2(_,undefined) ->
	0;
estimate_video_level2(Old,InVideo) ->
	NL = estimate_video_level(Old,InVideo),
	if NL=/=Old -> io:format("level change ~p -> ~p.~n",[Old,NL]);
	true -> pass end,
	NL.
	
estimate_video_level(_Old,#base_rtp{fb_pli=true}) ->
	0;
estimate_video_level(_Old,#base_rtp{fb_remb=BW}) when BW<150000 ->
	0;
estimate_video_level(_Old,#base_rtp{fb_remb=BW,fraction_lost=FracLost}) when BW>=150000,BW<300000 ->
	if FracLost > 0.1 -> 0;
	true -> 1 end;
estimate_video_level(Old,#base_rtp{fb_remb=BW,fraction_lost=FracLost,rtt=Rtt}) when BW>=300000 ->
	if FracLost > 0.1 -> 1;
	   Old==0 -> 1;
	   Rtt>0.050 -> 1;
	true -> 2 end.

notify_video_pli(RTCPElmts,InMedia) ->
	case [true||X<-RTCPElmts,is_record(X,rtcp_pl),X#rtcp_pl.pli==true] of
		[] -> pass;
		_  -> InMedia ! {video_pli,self()}
	end.

notify_lost_seqs(_,_RTCPElmts,{#base_rtp{ssrc=_Audio},undefined}) ->
	pass;
notify_lost_seqs(_,RTCPElmts,{#base_rtp{ssrc=Audio},#base_rtp{ssrc=Video}}) ->
	case [{X#rtcp_pl.ms,X#rtcp_pl.nack}||X<-RTCPElmts,is_record(X,rtcp_pl),X#rtcp_pl.nack=/=[]] of
		[{Video,Losts}] -> self() ! {send_lost, video, Losts};
		[{Ms,Losts}] -> io:format("report ~p lost ~p dropped.~n",[Ms,Losts]),
						io:format("audio ~p video ~p.~n",[Audio,Video]);
		_ -> pass
	end.

% ----------------------------------
upd_rcv_bw(#esti{v_rcvd_seq=undefined}=BWE, InSeq) ->
	{?MINVBITRATE, BWE#esti{v_br=?MINVBITRATE,v_rcvd_pkts=1,v_rcvd_lost=0,v_rcvd_seq=InSeq}};
upd_rcv_bw(#esti{v_target_br=TargetBr,v_br=Br,v_rcvd_seq=PSeq,v_rcvd_pkts=VPRcvd,v_rcvd_lost=VPLost}=BWE,
		   InSeq) ->
	ThisLost = case judge_bad_seq(PSeq,InSeq) of
			{forward,N} when N>1 -> N-1;
			_ -> 0
		end,
	if VPRcvd+1>500 orelse ThisLost>20->
		LostRate = (VPLost+ThisLost)/(VPRcvd+1),
%		io:format("receive lostrate: ~p~n",[LostRate]),
		if Br<TargetBr andalso LostRate<0.05 ->
			Br2 = trunc(Br*1.02),
			if Br2>TargetBr ->
				{TargetBr,BWE#esti{v_rcvd_pkts=0,v_rcvd_lost=0,v_rcvd_seq=InSeq}};
			true ->
				{Br2,BWE#esti{v_br=Br2,v_rcvd_pkts=0,v_rcvd_lost=0,v_rcvd_seq=InSeq}}
			end;
		  LostRate>0.20 ->
			{?MINVBITRATE,BWE#esti{v_br=?MINVBITRATE,v_rcvd_pkts=0,v_rcvd_lost=0,v_rcvd_seq=InSeq}};
		true ->		%%		  Br>TargetBr orelse (LostRate>0.10 andalso Br<?MINVBITRATE)
			Br2 = trunc(Br*0.95),
			if Br2<?MINVBITRATE ->
				{?MINVBITRATE,BWE#esti{v_rcvd_pkts=0,v_rcvd_lost=0,v_rcvd_seq=InSeq}};
			true ->
				{Br2,BWE#esti{v_br=Br2,v_rcvd_pkts=0,v_rcvd_lost=0,v_rcvd_seq=InSeq}}
			end
		end;
	true ->
		{Br,BWE#esti{v_rcvd_pkts=VPRcvd+1,v_rcvd_lost=VPLost+ThisLost,v_rcvd_seq=InSeq}}
	end.

start_rtcp(#base_rtp{ssrc=InAudio},undefined,#base_info{ssrc=OutAudio},_) ->
	if InAudio=/=undefined orelse OutAudio=/=undefined ->
		%%io:format("start audio rtcp.~p ~p~n",[InAudio,OutAudio]),
		self() ! {send_sr,undefined,audio};
	true -> pass end;
start_rtcp(#base_rtp{ssrc=InAudio},#base_rtp{ssrc=InVideo},#base_info{ssrc=OutAudio},#base_info{ssrc=OutVideo}) ->
	if InAudio=/=undefined orelse OutAudio=/=undefined ->
		%%io:format("start audio rtcp.~p ~p~n",[InAudio,OutAudio]),
		self() ! {send_sr,undefined,audio};
	true -> pass end,
	if InVideo=/=undefined orelse OutVideo=/=undefined ->
		%%io:format("start video rtcp.~p ~p~n",[InVideo,OutVideo]),
		self() ! {send_sr,undefined,video};
	true -> pass end;
start_rtcp(_,_,_,_) ->pass.

makeIVec(Salt,SSRC,LastSR) ->
	EIdx = <<1:1,LastSR:31>>,
	IVec = xor3(<<Salt/binary,0:16>>, <<0:32,SSRC:32,0:64>>, <<0:64,0:16,LastSR:32,0:16>>),
	{IVec,EIdx}.

make_rtcp(Now,InMedia,RMediaInfo) ->
	if InMedia#base_rtp.ssrc=/=undefined -> make_rtcp_sr(Now,InMedia,RMediaInfo);
	true -> make_rtcp_rr(Now,InMedia,RMediaInfo) end.

make_rtcp_sr(Now,BaseRTP,RemoteInfo) ->
	Src1 = make_rtcp_source_desc(Now,RemoteInfo),
	#base_rtp{ssrc=SSRC,cname=CName,packets=Pkgs,bytes=Byts, codec=Codec} = BaseRTP,
	{MSW, LSW} = make_ts64(Now),
	SR = #rtcp_sr{ssrc = SSRC,
				  ts64 = <<MSW:32,LSW:32>>,
				  rtp_ts = sync_rtp_ts(codec_factor(Codec), Now,BaseRTP),
				  packages = Pkgs,
				  bytes = Byts,
				  receptions = Src1},
	SD = #rtcp_sd{ssrc=SSRC, cname=CName},
	%io:format("t1:~p",[Now]),
	<<Head:?RTCPHEADLENGTH/binary,Body/binary>> = rtcp:enpack([SR,SD]),
	{RemoteInfo#base_info{pkts_rcvd=0,pkts_lost=0},Head,Body}.

make_rtcp_rr(Now,BaseRTP,RemoteInfo) ->
	Src1 = make_rtcp_source_desc(Now,RemoteInfo),
	RR = #rtcp_rr{ssrc = BaseRTP#base_rtp.cssrc, receptions = Src1},
	<<Head:?RTCPHEADLENGTH/binary,Body/binary>> = rtcp:enpack([RR]),
	{RemoteInfo#base_info{pkts_rcvd=0,pkts_lost=0},Head,Body}.

make_rtcp_nack(BaseRTP,#base_info{lost_seqs=LostSeqs}=RemoteInfo) ->
	PL = #rtcp_pl{ssrc=BaseRTP#base_rtp.cssrc,ms=RemoteInfo#base_info.ssrc,nack=LostSeqs},
	rtcp:enpack([PL]).

make_rtcp_pli(BaseRTP,RemoteInfo) ->
	PL = #rtcp_pl{ssrc = BaseRTP#base_rtp.cssrc,ms=RemoteInfo#base_info.ssrc,pli=true},
	rtcp:enpack([PL]).

make_rtcp_remb(_SSRC,_MS,undefined) ->
	<<>>;
make_rtcp_remb(SSRC,MS,BW) ->
	REMB = #rtcp_pl{ssrc=SSRC, ms=MS, remb=BW},
	rtcp:enpack([REMB]).

make_rtcp_source_desc(Now,BaseInfo) ->
	if BaseInfo#base_info.seq=/=undefined ->
		#base_info{ssrc=RSSRC,roc=ROC,seq=Seq,ts_m32=TS32,rcv_timecode=RTime,interarrival_jitter=IAJitter,
				   cumu_lost=CumuLost,pkts_rcvd=PktR,pkts_lost=PktL} = BaseInfo,
		{TS1,RTC1} = if TS32==undefined -> {0,0};
					 true -> {TS32,make_dlsr(timer:now_diff(Now,RTime))} end,
		FracLost = if PktR==0 andalso PktL==0 -> 0;
					  PktL<0 -> 0;
				   true -> trunc((PktL / (PktL+PktR))*16#100) end,
		[#source_report{ssrc = RSSRC,
						lost = {FracLost,CumuLost},
						eseq = ROC*16#10000+Seq,
						jitter = IAJitter,
						sr_ts = TS1,
						sr_delay = RTC1}];
	true -> [] end.

% ----------------------------------
makeVP8(#audio_frame{codec=?VP8,marker=Mark,body=Body,samples=_Samples},
		undefined,
		#base_rtp{ssrc=SSRC,roc=ROC,seq=Seq}=BaseRTP) ->
	{NewBaseRTP, RTP} = compose_rtp(BaseRTP#base_rtp{marker=Mark,codec=?VP8},Body),
	{NewBaseRTP,RTP};
makeVP8(#audio_frame{codec=?VP8,marker=Mark,body=Body,samples=_Samples},
		#cryp{method="AES_CM_128_HMAC_SHA1_80",e_k=E_k,e_s=E_s,a_k=A_k},
		#base_rtp{ssrc=SSRC,roc=ROC,seq=Seq}=BaseRTP) ->
	Enc = srtp_enc({E_k,E_s},{<<SSRC:32>>,ROC,Seq},Body),
	{NewBaseRTP, RTP} = compose_rtp(BaseRTP#base_rtp{marker=Mark,codec=?VP8},Enc),
	Digest = srtp_digest(A_k,<<RTP/binary,ROC:32>>),
	EncRTP = <<RTP/binary,Digest/binary>>,
	{NewBaseRTP,EncRTP}.
			
srtp_keydrivate(K_S) ->
			<<K_a:16/binary,K_s:14/binary>> = base64:decode(K_S),
			srtp_keydrivate(K_a, K_s).

srtp_keydrivate(K_a, K_s) ->
			Xk = make_AES_input(K_s,16#00),
			E_k = 'Ek128'(K_a,Xk),
			Xs = make_AES_input(K_s,16#02),
			<<E_s:14/binary,_/binary>> = 'Ek128'(K_a, Xs),
			<<A_k:20/binary,_/binary>> = make_auth_key(K_a,K_s),
			{E_k,E_s,A_k}.

make_auth_key(K_a,K_s) ->
	<<Xa:14/binary,_/binary>> = make_AES_input(K_s,16#01),
	A_k0 = 'Ek128'(K_a,<<Xa/binary,0:16>>),
	A_k1 = 'Ek128'(K_a,<<Xa/binary,1:16>>),
	A_k2 = 'Ek128'(K_a,<<Xa/binary,2:16>>),
	A_k3 = 'Ek128'(K_a,<<Xa/binary,3:16>>),
	A_k4 = 'Ek128'(K_a,<<Xa/binary,4:16>>),
	<<A_k5:14/binary,_/binary>> = 'Ek128'(K_a,<<Xa/binary,5:16>>),
	A_k = <<A_k0/binary,A_k1/binary,A_k2/binary,A_k3/binary,A_k4/binary,A_k5/binary>>,
	A_k.

srtcp_keydrivate(K_S) ->
			<<K_a:16/binary,K_s:14/binary>> = base64:decode(K_S),
			srtcp_keydrivate(K_a, K_s).
srtcp_keydrivate(K_a, K_s) ->
			Xk = make_AES_input(K_s,16#03),
			E_k = 'Ek128'(K_a,Xk),
			Xs = make_AES_input(K_s,16#05),
			<<E_s:14/binary,_/binary>> = 'Ek128'(K_a,Xs),
			<<Xa:14/binary,_/binary>> = make_AES_input(K_s,16#04),
			<<A_k:20/binary,_/binary>> = make_auth_key2(K_a,Xa),
			{E_k,E_s,A_k}.
			
make_auth_key2(K_a,Xa) ->
	A_k0 = 'Ek128'(K_a,<<Xa/binary,0:16>>),
	A_k1 = 'Ek128'(K_a,<<Xa/binary,1:16>>),
	A_k2 = 'Ek128'(K_a,<<Xa/binary,2:16>>),
	A_k3 = 'Ek128'(K_a,<<Xa/binary,3:16>>),
	A_k4 = 'Ek128'(K_a,<<Xa/binary,4:16>>),
	<<A_k5:14/binary,_/binary>> = 'Ek128'(K_a,<<Xa/binary,5:16>>),
	A_k = <<A_k0/binary,A_k1/binary,A_k2/binary,A_k3/binary,A_k4/binary,A_k5/binary>>,
	A_k.

make_AES_input(<<H:7/binary,L:8,T:6/binary>>,Label) ->
	L2 = L bxor Label,
	<<H/binary,L2:8,T/binary,0:16>>.
	
'Ek128'(K_a,Xk) ->
	Blk = list_to_binary(lists:duplicate(16,0)),
	{_NewSt, Bin} = crypto:stream_encrypt(crypto:stream_init(aes_ctr, K_a, Xk),Blk),
	Bin.

xor3(<<A:128>>,<<B:128>>,<<C:128>>) ->
	Dat = A bxor B bxor C,
	<<Dat:128>>.


aes_ctr_enc(Enc,Key,IVec) when size(Enc)>16 ->
	aes_ctr_enc(Enc,Key,IVec,0,<<>>);
aes_ctr_enc(Enc,Key,IVec) ->
	{_NewSt, Bin} = crypto:stream_encrypt(crypto:stream_init(aes_ctr, Key,IVec),Enc),
	Bin.
	
aes_ctr_enc(<<>>,_,_,_,R) ->
	R;
aes_ctr_enc(<<Blk:16/binary,Rest/binary>>,Key,<<IV1:15/binary,0:8>> =IVec,N,R) ->
	IV = <<IV1/binary,N:8>>,
	{_NewSt, Dec} = crypto:stream_encrypt(crypto:stream_init(aes_ctr, Key,IV),Blk),
	aes_ctr_enc(Rest,Key,IVec,N+1,<<R/binary,Dec/binary>>);
aes_ctr_enc(Bin,Key,<<IV1:15/binary,0:8>>,N,R) ->
	BSize = size(Bin),
	PadSize = 16 - BSize,
	Pad = list_to_binary(lists:duplicate(0,PadSize)),
	Blk = <<Bin/binary,Pad/binary>>,
	IV = <<IV1/binary,N:8>>,
	{_NewSt, <<Dec:BSize/binary,_/binary>>} = crypto:stream_encrypt(crypto:stream_init(aes_ctr, Key,IV),Blk),
	<<R/binary,Dec/binary>>.

srtp_enc({E_k,E_s},{SSRC,ROC,Seq},Body) ->
	I = (ROC bsl 16) bor Seq,
	IVec = xor3(<<E_s/binary,0:16>>, <<0:32,SSRC/binary,0:64>>, <<0:64,I:48/integer,0:16>>),
	PCM = aes_ctr_enc(Body,E_k,IVec),
	PCM.

check_digest(Digest,A_k,Bin) ->
	Digest2 = srtp_digest(A_k,Bin),
	if
		Digest == Digest2 -> true;
		true ->
		    %io:format("bad digest:~n~p~n~p~n",[Digest,Digest2]),
		    false
	end.

check_digest(Digest,A_k,Bin, Method) ->
	Digest2 = srtp_digest(A_k,Bin, Method),
	if
		Digest == Digest2 -> true;
		true -> 
		    %% io:format("bad digest2:~n~p~n~p~n",[Digest,Digest2]),
			false
	end.

check_srtcp_digest(Digest, A_k, Bin, Method) ->
    Digest2 = srtcp_digest(A_k,Bin, Method),
	if
		Digest == Digest2 -> true;
		true -> 
		 %% io:format("bad digest:~n~p~n~p~n",[Digest,Digest2]),
		 false
	end.

srtp_digest(A_k,Bin) ->
	<<Sha:10/binary, _/binary>> = crypto:hmac(sha, A_k,Bin),
	Sha.

srtp_digest(A_k, Bin, "AES_CM_128_HMAC_SHA1_80") ->
    <<Sha:10/binary, _/binary>> = crypto:hmac(sha, A_k,Bin),
	Sha;
srtp_digest(A_k, Bin, "AES_CM_128_HMAC_SHA1_32") ->
    <<Sha:4/binary, _/binary>> = crypto:hmac(sha, A_k,Bin),
	Sha. 

srtcp_digest(A_k, Bin, Method) when Method == "AES_CM_128_HMAC_SHA1_80";Method == "AES_CM_128_HMAC_SHA1_32" ->
    <<Sha:10/binary, _/binary>> = crypto:hmac(sha, A_k,Bin),
	Sha.

srtp_digest_length("AES_CM_128_HMAC_SHA1_80") -> 10;
srtp_digest_length("AES_CM_128_HMAC_SHA1_32") -> 4.

srtcp_digest_length("AES_CM_128_HMAC_SHA1_80") -> 10;
srtcp_digest_length("AES_CM_128_HMAC_SHA1_32") -> 10.


% ----------------------------------
count_up_to_seq(InSeq,{LastROC,LastSeq}) ->
	count_up_to_seq(0,InSeq,{LastROC,LastSeq}).
count_up_to_seq(N,InSeq,{ROC,Seq}) when InSeq==Seq ->
	{N,ROC,InSeq};
count_up_to_seq(N,InSeq,{LastROC,LastSeq}) ->
	{ROC,Seq} = get_expect_seq(LastROC,LastSeq),
	count_up_to_seq(N+1,InSeq,{ROC,Seq}).

decryp_and_send_audio([OutMedia,Mark,Codec,{ROC,InSeq},Samples0,SSRC,Cryp], {udp,_Socket,Addr,Port,Bin}) ->
	Marker = if Mark==1 -> true; true -> false end,
	Samples = if Samples0 < 0 -> Samples0 + 16#100000000; true -> Samples0 end,
	case get_media_frame(SSRC,ROC,InSeq,Cryp,Bin) of
		{ok,Body} ->
			Frame = #audio_frame{codec=Codec,marker=Marker,body=Body,samples=Samples,addr=Addr,port=Port},
			send_media(OutMedia, Frame);
		bad_digest ->
			%%io:format("~p audio ~p bad_digest.~n",[self(),SSRC]),
			pass
	end,
	ok.

% ----------------------------------
get_expect_seq(LastROC,65535) ->
	{LastROC+1,0};
get_expect_seq(LastROC,Seq) ->
	{LastROC,Seq+1}.

judge_bad_seq(LastSeq,InSeq) ->
	judge_bad_seq(abs(InSeq - LastSeq),LastSeq,InSeq).
judge_bad_seq(D,Last,In) when D < 32768 ->
	if In > Last -> {forward,In-Last};
	true -> {backward,Last-In} end;		% 0 is back
judge_bad_seq(_D,Last,In) ->
	if Last > 32768 -> {forward,65536+In-Last};
	true -> {backward,(65536+Last)-In} end.

insert2proper_posi(N,_InSeq,Bin,[]) ->
	{N-1,[Bin]};
insert2proper_posi(_,InSeq,Bin,JBuf) ->
	insert2proper_posi2(InSeq,Bin,JBuf,[]).

insert2proper_posi2(InSeq,Bin,[],R) ->
	<<_:16,Seq:16,_:64,_/binary>> =hd(R),
	{forward,N} = judge_bad_seq(Seq,InSeq),
	{N-1,lists:reverse([Bin|R])};
insert2proper_posi2(InSeq,Bin,[<<_:16,Seq:16,_:64,_/binary>> =H|T],R) ->
	case judge_bad_seq(Seq,InSeq) of
		{forward,_} ->  insert2proper_posi2(InSeq,Bin,T,[H|R]);
		{backward,_} -> {-1,lists:reverse([Bin|R])++[H|T]}		% minus before lost count by 1
	end.

make_lost_seqs(_,[]) ->
	[];
make_lost_seqs(X,[X|T]) ->
	{_,X2} = get_expect_seq(0,X),
	make_lost_seqs(X2,T);
make_lost_seqs(X,[H|T]) ->
	{_,X2} = get_expect_seq(0,X),
	[X|make_lost_seqs(X2,[H|T])].

flush_media_from_vjttr([_OM,LastTS,_SSRC,LastROC,LastSeq,_Cryp],[],LostSeqs) ->
	{LastROC,LastSeq,LastTS,lists:reverse(LostSeqs)};
flush_media_from_vjttr([OutMedia,LastTS,SSRC,LastROC,LastSeq,Cryp],[HVJ|TVJ],LostSeqs) ->
	{ExpROC,ExpSeq} = get_expect_seq(LastROC,LastSeq),
	<<2:2,_:6,Mark:1,?VP8:7,InSeq:16,TS:32,SSRC:32,_/binary>> = HVJ,
	if InSeq==ExpSeq ->
		Marker = if Mark==1 -> true; true -> false end,
		decryp_and_send_media_frame([OutMedia,Marker,TS-LastTS,SSRC,ExpROC,ExpSeq,Cryp],HVJ),
		io:format("jump frame ~p~n",[ExpSeq]),
		flush_media_from_vjttr([OutMedia,TS,SSRC,ExpROC,ExpSeq,Cryp],TVJ,LostSeqs);
	true ->
		io:format("indicate lost frame ~p~n",[ExpSeq]),
		send_media(OutMedia,#audio_frame{content=lost_vp8,codec = ?VP8,body= <<>>}),
		flush_media_from_vjttr([OutMedia,LastTS,SSRC,ExpROC,ExpSeq,Cryp],[HVJ|TVJ],[ExpSeq|LostSeqs])
	end.

decryp_and_send_onseq_from_vjttr(SntN,[_,LastTS,_SSRC,ROC,Seq,_Cryp],[]) ->
	{SntN,ROC,Seq,LastTS,[]};
decryp_and_send_onseq_from_vjttr(SntN,[OutMedia,LastTS,SSRC,ROC,Seq,Cryp],[HVJ|TVJ]) ->
	{ExpectROC,ExpectSeq} = get_expect_seq(ROC,Seq),
	<<2:2,_:6,Mark:1,?VP8:7,InSeq:16,TS:32,SSRC:32,_/binary>> = HVJ,
	if InSeq==ExpectSeq ->
		Marker = if Mark==1 -> true; true -> false end,
		decryp_and_send_media_frame([OutMedia,Marker,TS-LastTS,SSRC,ExpectROC,ExpectSeq,Cryp],HVJ),
		decryp_and_send_onseq_from_vjttr(SntN+1,[OutMedia,TS,SSRC,ExpectROC,ExpectSeq,Cryp],TVJ);
	true ->
		{SntN,ROC,Seq,LastTS,[HVJ|TVJ]}
	end.
	

decryp_and_send_media_frame([OutMedia,Marker,Samples,SSRC,ROC,InSeq,Cryp],Bin) ->
	case get_media_frame(SSRC,ROC,InSeq,Cryp,Bin) of
		{ok,Body} ->
			Frame = #audio_frame{codec = ?VP8,marker=Marker,body = Body,samples=Samples},
			send_media(OutMedia, Frame);
		bad_digest ->
			io:format("~p drop bad digest vp8.~n",[self()]),
			pass
	end,
	ok.

get_media_frame(_SSRC,_ROC,_Seq,undefined,<<_Head:?RTPHEADLENGTH/binary,Media/binary>>) ->
	{ok,Media};
get_media_frame(SSRC,ROC,Seq,#cryp{method=Method,e_k=Key,e_s=Salt,a_k=A_k},Bin) ->
	MSize = size(Bin) - ?RTPHEADLENGTH - srtp_digest_length(Method),
	<<Head:?RTPHEADLENGTH/binary,Media:MSize/binary,Digest/binary>> = Bin,
	case check_digest(Digest,A_k,<<Head/binary,Media/binary,ROC:32>>, Method) of
		true ->
			I = (ROC bsl 16) bor Seq,
			IVec = xor3(<<Salt/binary,0:16>>, <<0:32,SSRC:32,0:64>>, <<0:64,I:48/integer,0:16>>),
			VP=aes_ctr_enc(Media,Key,IVec),
			{ok,VP};
		false ->
			bad_digest
	end.

% ----------------------------------
%% Compose one RTP-packet from whole Data
compose_rtp(#base_rtp{roc=ROC, seq=Sequence, marker=Marker,codec=Codec,
                      packets=Packets, bytes=Bytes}=Base, Data) ->
	if Marker -> M = 1; true -> M = 0 end,
	Pack = make_rtp_pack(Base, M, Codec, Data),
	{NewROC,NewSeq} = get_expect_seq(ROC,Sequence),
	{Base#base_rtp{codec = Codec,
				   seq = NewSeq,
				   roc = NewROC,
				   packets = inc_packets(Packets, 1),
				   bytes = inc_bytes(Bytes, size(Pack)-?RTPHEADLENGTH)},
	 Pack}.

make_rtp_pack(#base_rtp{seq = Sequence,
                        timecode = Timestamp,
                        ssrc = SSRC}, Marker, PayloadType, Payload) ->
  Version = 2,
  Padding = 0,
  Extension = 0,
  CSRC = 0,
  <<Version:2, Padding:1, Extension:1, CSRC:4, Marker:1, PayloadType:7, Sequence:16, Timestamp:32, SSRC:32, Payload/binary>>.

minisec(Micro) ->
	(Micro div 1000)*1000.
mini10sec(Micro) ->
	(Micro div 10000)*10000.

init_rnd_seq() ->
  random:uniform(16#FF).	% start with a small number

init_rnd_timecode() ->
  Range = 1000000000,
  random:uniform(Range) + Range.


inc_timecode_fixed(#base_rtp{media=audio,wall_clock=_WC,timecode=TC} = ST, Samples) ->
	{Mega,Sec,Micro} = now(),
	Now = {Mega,Sec,minisec(Micro)},
	ST#base_rtp{wall_clock=Now,timecode=Samples+TC}.

inc_timecode(#base_rtp{media=video,wall_clock=LastWC,timecode=TC} = ST) ->
	{Mega,Sec,Micro} = now(),
	Now = {Mega,Sec,minisec(Micro)},
	Diffms = timer:now_diff(Now, LastWC) div 1000,
  	ST#base_rtp{wall_clock=Now,timecode=Diffms*90+TC}.

sync_rtp_ts(CodecFactor, Now,#base_rtp{media=Type,wall_clock=LastWC,timecode=TC}) ->
	Diff = timer:now_diff(Now,LastWC) div 1000,		% maybe minus value
	CodecFactor * Diff + TC.

inc_packets(S, V) ->
  (S+V) band 16#FFFFFFFF.

inc_bytes(S, V) ->
  (S+V) band 16#FFFFFFFF.

make_ts64({A1,A2,A3}) ->
  {(A1*1000000)+A2 + ?YEARS_70, trunc((A3/1000000)*16#100000000)}.

make_dlsr(Diff) ->
	{Sec,Us} = {Diff div 1000000,Diff rem 1000000},
	Frac = trunc((Us/1000000)*16#10000),
	<<DLsr:32>> = <<Sec:16,Frac:16>>,
	DLsr.

codec_factor(?PCMU) -> 8;
codec_factor(?iSAC) -> 16;
codec_factor(?iCNG) -> 16;
codec_factor(?iLBC) -> 8;
codec_factor(?OPUS) -> 48;
codec_factor(?VP8) -> 90;
codec_factor(_) -> 8.

compute_interarrival_jitter(CodecFactor,IAJ,{TS,Now},{PTS,PNow}) ->
	Rji = CodecFactor * timer:now_diff(Now,PNow) div 1000,
	Sji = TS - PTS,
	IAJ + (abs(Rji-Sji) - IAJ) div 16.

update_avg_ij(#base_info{avg_ij=IJ0, ij_count=Count0, interarrival_jitter=Ij}=RCtx0) ->
    Count = Count0 + 1,
    IJ = if  Count0 < 3 -> IJ0;
    	     true -> (IJ0 * (Count0-2)+Ij) / (Count-2)
    	 end,
    RCtx0#base_info{avg_ij=IJ, ij_count=Count}.

update_avg_rtt(#base_rtp{avg_rtt=RTT0, rtt_count=Count0, rtt=Rtt}=SCtx0) ->
    Count = Count0 + 1,
    RTT = if  Count0 < 3 -> RTT0;
    	      true -> (RTT0 * (Count0-2)+Rtt) / (Count-2)
    	  end,
    SCtx0#base_rtp{avg_rtt=RTT, rtt_count=Count}.

% ----------------------------------
start_within(Session,Options,{BEGIN_UDP_RANGE,END_UDP_RANGE}) ->
	case try_port(BEGIN_UDP_RANGE,END_UDP_RANGE) of
		{ok,Port,Socket} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Options],[]),
			gen_udp:controlling_process(Socket, Pid),
			{ok,Port,Pid};
		{error, Reason} ->
			{error,Reason}
	end.

start_mobile(Session,Options) ->
	{MOBILE_BEGIN_UDP_RANGE,MOBILE_END_UDP_RANGE} = avscfg:get(mweb_udp_range),
	case try_port_pair(MOBILE_BEGIN_UDP_RANGE,MOBILE_END_UDP_RANGE) of
		{ok,Port,Sock1,Sock2} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,{Sock1,Sock2},Options],[]),
			gen_udp:controlling_process(Sock1, Pid),
			gen_udp:controlling_process(Sock2, Pid),
			{ok,Pid,Port};
		{error, Reason} ->
			{error,Reason}
	end.

start(Session,Options) ->
	{WEB_BEGIN_UDP_RANGE,WEB_END_UDP_RANGE} = avscfg:get(web_udp_range),
	case try_port(WEB_BEGIN_UDP_RANGE,WEB_END_UDP_RANGE) of
		{ok,Port,Socket} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Options],[]),
			gen_udp:controlling_process(Socket, Pid),
			{ok,Pid,Port};
		{error, Reason} ->
			{error,Reason}
	end.
	
stop(RTP) ->
	my_server:call(RTP,stop).
	
info(Pid,Info) ->
	my_server:cast(Pid,Info).
	
rtp_report(To, _Sess, Cmd) ->
	my_server:cast(To, Cmd).
	
try_port(Port,END_UDP_RANGE) when Port > END_UDP_RANGE ->
	{error,udp_over_range};
try_port(Port,END_UDP_RANGE) ->
    {ok,HostIP} = inet:parse_address(avscfg:get(web_socket_ip)),
	case gen_udp:open(Port, [binary, {active, true}, {ip,HostIP}, {recbuf, 8192}]) of
		{ok, Socket} ->
			{ok,Port,Socket};
		{error, _} ->
			try_port(Port + 1,END_UDP_RANGE)
	end.

try_port_pair(Begin, End) ->
    From =   case app_manager:get_last_used_webport() of
        undefined-> Begin;
        {ok, From1}-> From1
        end,
    try_port_pair(Begin, End, From, From+2).
    
try_port_pair(Begin, End, From, Port) when (Port rem 2)=/=0 ->
	try_port_pair(Begin, End, From, Port+1);
try_port_pair(Begin, End, From, Port) when Port==From;Port==From+1 ->
	{error,udp_over_range};
try_port_pair(Begin, End, From, Port) when Port>End ->
	try_port_pair(Begin, End, From, Begin);
try_port_pair(Begin, End, From, Port) ->
	case gen_udp:open(Port, [binary, {active, true}, {recbuf, 4096}]) of
		{ok,Sock1} ->
			case gen_udp:open(Port+1, [binary, {active, true}, {recbuf, 4096}]) of
				{ok,Sock2} ->
				       app_manager:set_last_used_webport(Port),
					{ok,Port,Sock1,Sock2};
				{error, _} ->
					gen_udp:close(Sock1),
					try_port_pair(Begin, End, From, Port+2)
			end;
		{error, _} ->
			try_port_pair(Begin, End, From, Port+2)
	end.
	
send_udp(Socket, Addr, Port, RTPs) ->
  F = fun(P) ->
          gen_udp:send(Socket, Addr, Port, P)
      end,
  send_rtp(F, RTPs).

send_rtp(F, RTP) when is_binary(RTP) ->
  F(RTP);
send_rtp(F, RTPs) when is_list(RTPs) ->
  [begin
     if is_list(R) ->
         [F(Rr) || Rr <- R];
        true ->
         F(R)
     end
   end || R <- RTPs].

send_media(OM, Frame) when is_pid(OM),is_record(Frame,audio_frame) ->
	OM ! Frame#audio_frame{owner=self()};
send_media(OM, SR) when is_pid(OM) ->
	OM ! SR;
send_media(loop, Frame) when is_record(Frame,audio_frame) ->
	self() ! Frame;
send_media(undefined,_) ->
	ok.

%
% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.


show_tc_ts(?iCNG,{LastTS,PrevTC},{TS,Now}) ->
	Diffms = timer:now_diff(Now,PrevTC) div 1000,
	io:format("| [~pn@~p]~n",[(TS-LastTS) div 16, Diffms]),
	ok;
show_tc_ts(?iSAC,{LastTS,PrevTC},{TS,Now}) ->
	Diffms = timer:now_diff(Now,PrevTC) div 1000,
	io:format("|     [~pa@~p]~n",[(TS-LastTS) div 16, Diffms]),
	ok.

start_moni(Opts) ->
	["AES_CM_128_HMAC_SHA1_80",KeySalt] = proplists:get_value(crypto,Opts),
	Media = media:start("rec",null),
	Options = [{outmedia,Media},
			   {crypto,["AES_CM_128_HMAC_SHA1_80",KeySalt]}],
	{ok,Pid,LPort} = rtp:start("666666",Options),
	{Pid,LPort,Media}.
			
send_moni(Sock,{_,Port,_},Bin) ->
	gen_udp:send(Sock, "10.61.34.50", Port, Bin).

stop_moni({Pid,_, Media}) ->
	media:stop(Media),
	rtp:stop(Pid),
	ok.
	

