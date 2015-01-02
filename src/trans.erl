-module(trans).
-compile(export_all).

-define(RTCPHEADLENGTH,8).
-define(iSAC,103).
-define(LOSTSEQ,1003).
-define(RTCPINTERVAL,2500).

-define(DEFAULTPSIZE,480).

-define(PCMU,0).
-define(G729,18).
-define(L16K,108).
-define(L8K,107).
-define(u16K,80).

-define(PHN,101).
-define(PT160,160).

-include("desc.hrl").

-record(ms,{			% record for media source. ms -> udp -> rtp, rtp receive endpoint
	type,
	to_pid,
	codec,
	cssrc,
	ssrc,
	roc,
	seq,
	ts,
	packets=0,			% received total packets.
	bytes=0,			% received total bytes. compute bandwidth
	last_ts_wc,
	ia_jitter=0,		% interarrivial jitter
	received=0,			% received packet count, compute fraction_lost
	lost=0,				% receive packets lost, compute fraction_lost
	total_lost=0,		% receive cumu lost
	rtcp_ts_wc			% last received rtcp ts and wallclock
}).

-record(strm,{			% record for stream. strm -> rtp -> udp, rtp send endpoint
	type,
	from_pid,
	codec,
	cssrc,
	ssrc,
	cname= <<>>,
	roc,
	seq,
	ts,
	wall_clock,
	packets=0,			% total sent packets.
	bytes=0,			% total sent bytes.
	rtcp_timer,
	rtt,
	sr_total_lost=0,	% #sourcce_report.cumu_lost
	sr_lost=0,			% compute from #soruce_report.fraction_lost and eseq
	sr_eseq
}).

-record(ev,{
	actived = false,
	step,
	tcount,			% count tone in samples
	gcount,			% count gap
	t_begin,
	t_end,			% used for tone gap
	nu,
	vol,
	dura,
	queue = []
}).

-record(st,{
	session,
	start_time,
	report_to,
	rtp_socket,
	rtcp_socket,
	peerok,
	peer,
	cdc_st,
	snd_pev = #ev{},	% rtp send phone event
	isSS=false,
	media_source,
	stream
}).

-record(cst,{
	ctx,
	timer,
	type,
	params,
	abuf = <<>>
}).

init([Sess,Sock1,Sock2]) -> init([Sess,Sock1,Sock2,false]);
init([Sess,Sock1,Sock2, IsSS]) ->
	StartTime = {date(),time()},
%	io:format("trans ~p started.~n",[self()]),
	{ok,#st{isSS=IsSS, session=Sess,start_time=StartTime,rtp_socket=Sock1,rtcp_socket=Sock2,stream=#strm{},media_source=#ms{}}}.
%
handle_call({add_media,audio,[Id,Processor,CtrlId,MoniId]},_From,ST) ->
	{reply,ok,ST#st{media_source=#ms{type=audio,to_pid=Processor,ssrc=Id,cssrc=CtrlId},stream=#strm{cssrc=MoniId}}};
handle_call({add_stream,audio,[Codec,Dest,Id,CtrlId]},_From,ST) ->
	TRef = if CtrlId=/=undefined ->
				my_timer:send_after(100, {send_sr,TR=make_ref(),audio}),
				TR;
		true -> undefined end,
	{reply, ok, ST#st{peer=Dest,stream=#strm{type=audio,codec=Codec,ssrc=Id,cssrc=CtrlId,seq=0,roc=0,ts=0,wall_clock=now(),rtcp_timer=TRef}}};
handle_call({add_codec,Type,Params},_From,ST) ->
	{ok,Ctx,PTime} = codec:init_codec(Type,Params),
	{ok,TR} = my_timer:send_interval(PTime,play_interval),
%	io:format("~p start interval play @~p~n",[self(),PTime]),
	{reply,ok,ST#st{cdc_st=#cst{timer=TR,type=Type,params=Params,ctx=Ctx}}};
handle_call({report_to,Boss}, _From,ST) ->
	{reply, ok, ST#st{report_to=Boss}};
handle_call({media_relay,closed},_From, #st{media_source=MS,stream=Strm}=ST) ->
	{reply, ok, ST#st{media_source=MS#ms{to_pid=undefined},stream=Strm#strm{from_pid=undefined}}};
handle_call({media_relay,Media},_From, #st{media_source=MS,stream=Strm}=ST) when is_pid(Media) ->
	my_server:cast(Media, {play,self()}),
%	io:format("trans (~p) get media ~p.~n",[self(),Media]),
	{reply, ok, ST#st{media_source=MS#ms{to_pid=Media},stream=Strm#strm{from_pid=Media}}};
handle_call({options,Options},_From,ST) ->
	[IP,Port] = proplists:get_value(remoteip,Options),
%	io:format("trans ~p get ~p~n",[self(),{IP,Port}]),
	{reply, ok, ST#st{peer={IP,Port}}};
handle_call(get_info,_From,ST) ->
	{reply,ST,ST}.
%
handle_info({send_phone_event,Nu,Vol,Dura},#st{snd_pev=SPEv}=ST) ->
	SPEv2 = if SPEv#ev.actived==false -> 
				#ev{actived=true,step=init,t_begin=now(),nu=Nu,vol=Vol,dura=Dura};
			true ->
				InQ = SPEv#ev.queue,
				SPEv#ev{queue=InQ++[{Nu,Vol,Dura}]}
			end,
	{noreply,ST#st{snd_pev=SPEv2}};
handle_info(#audio_frame{codec=Codec,body=Body},#st{cdc_st=#cst{abuf=AB}=Cst}=ST) when Codec==?L16K;Codec==?L8K ->
	AB2 = if ST#st.peer==undefined -> <<>>;
			 (ST#st.snd_pev)#ev.actived==true -> <<>>;
		  true -> <<AB/binary,Body/binary>>
		  end,
	{noreply,ST#st{cdc_st=Cst#cst{abuf=AB2}}};
handle_info(play_interval,#st{peer=undefined}=ST) ->
	{noreply,ST};
handle_info(play_interval,#st{snd_pev=#ev{actived=true}=SPEv,rtp_socket=Sock1,peer={IP,Port},stream=Strm}=ST) ->
	{SPEv2,Marker,Samples,F1} = rrp:processSPE(SPEv),
	Strm2 = inc_timecode_fixed(Strm,Samples),
	{Strm3,OutBin} = compose_rtp(Strm2,?PHN,Marker,F1),
	send_udp(Sock1,IP,Port,OutBin),
	Strm4 = if SPEv2#ev.step==init orelse SPEv2#ev.actived==false ->
				inc_timecode_fixed(Strm3,SPEv2#ev.tcount + SPEv2#ev.gcount*160 -160);
			true -> Strm3 end,
	{noreply,ST#st{stream=Strm4,snd_pev=SPEv2}};
handle_info(play_interval,#st{cdc_st=Cst,rtp_socket=Sock1,peer={IP,Port},stream=Strm}=ST) ->
	#cst{type=Type,ctx=Ctx,abuf=AB} = Cst,
	{Ctx2,Marker,Samples,F1,RestAB} = codec:enc(Type,Ctx,AB),
	Strm2 = inc_timecode_fixed(Strm,Samples),
	{Strm3,OutBin} = compose_rtp(Strm2,Strm#strm.codec,Marker,F1),
	send_udp(Sock1,IP,Port,OutBin),
	insert_RTCP_SR(Strm3),
	{noreply, ST#st{stream=Strm3,cdc_st=Cst#cst{ctx=Ctx2,abuf=RestAB}}};
handle_info({send_sr,Ref,audio},#st{rtcp_socket=Socket,peer={IP,Port},stream=#strm{rtcp_timer=TR0}=Strm}=ST) when Ref==0;Ref==TR0 ->
	Now=now(),
	TRef = make_ref(),
	my_timer:send_after(?RTCPINTERVAL, {send_sr,TRef,audio}),
	{MS2,Head,Body} = make_rtcp_sr(Now,ST#st.stream,ST#st.media_source),
	send_udp(Socket,IP,Port+1,<<Head/binary,Body/binary>>),
	{noreply,ST#st{stream=Strm#strm{rtcp_timer=TRef},media_source=MS2}};
handle_info({send_sr,_,audio},ST) ->
	{noreply,ST};
%
handle_info({udp,Socket,IP,Port,<<2:2,_:6,_:1,PT:7,_:16,_:32,_SSRC:32,_/binary>> =Bin},	% RTP packet
			#st{peerok=undefined}=ST) when (PT==114 orelse PT==102)->                  %102  means ilbc web side
	Peer = check_peer(ST#st.peer,{make_ip_str(IP),Port}),
	handle_info({udp,Socket,IP,Port,Bin},ST#st{peerok=true,peer=Peer});
handle_info({udp,Socket,IP,Port,<<2:2,_:6,_:1,PT:7,_:16,_:32,_SSRC:32,_/binary>> =Bin},	% RTP packet
			#st{isSS=IsSS,rtcp_socket=CSock,media_source=MS}=ST)
			when IsSS andalso (PT==0 orelse PT==8 orelse PT==18 orelse PT==102 orelse PT==103 orelse PT==114) ->   % IsSS means ss side, not match
	if MS#ms.seq==undefined -> rtp_report(ST#st.report_to,ST#st.session,{stream_locked,self()});
	true -> pass end,
	{AFs,MS2} = processRTP(now(),MS,Bin),
	Cst2 = processMedia(ST#st.cdc_st,MS#ms.to_pid,AFs),
	{Strm2,MS3} = do_RTCP_RR(CSock,ST#st.peer,ST#st.stream,MS2),
       Peer = check_ss_peer(ST#st.peer,{make_ip_str(IP),Port}),
	{noreply,ST#st{stream=Strm2,media_source=MS3,cdc_st=Cst2, peer=Peer}};
handle_info({udp,Socket,IP,Port,<<2:2,_:6,_:1,PT:7,_:16,_:32,SSRC:32,_/binary>> =Bin},	% RTP packet
			#st{rtp_socket=Socket,rtcp_socket=CSock,media_source=#ms{ssrc=ID}=MS}=ST)
			when (ID==according orelse ID==SSRC) andalso (PT==0 orelse PT==8 orelse PT==18 orelse PT==102 orelse PT==103  orelse PT==114) ->
	if MS#ms.seq==undefined -> rtp_report(ST#st.report_to,ST#st.session,{stream_locked,self()});
	true -> pass end,
	{AFs,MS2} = processRTP(now(),MS,Bin),
	Cst2 = processMedia(ST#st.cdc_st,MS#ms.to_pid,AFs),
	{Strm2,MS3} = do_RTCP_RR(CSock,ST#st.peer,ST#st.stream,MS2),
	{noreply,ST#st{stream=Strm2,media_source=MS3,cdc_st=Cst2}};
handle_info({udp,Socket,IP,Port,<<2:2,_:6,PT:8,_:16,SSRC:32,_/binary>> =Bin},
			#st{rtcp_socket=Socket,media_source=#ms{cssrc=CtrID}=MS,stream=Strm}=ST)
			when (CtrID==according orelse CtrID==SSRC) andalso (PT==200 orelse PT==201 orelse PT==202 orelse PT==203 orelse PT==205 orelse PT==206) ->
	Now = now(),
	RTCP = rtcp:parse(Bin),
	MS2 = save_sr_timecode(MS,Now,RTCP),
	Strm2 = update_source_report(Strm,Now,RTCP),
	{noreply,ST#st{media_source=MS2,stream=Strm2}};
%
handle_info({udp,Socket,Addr,Port,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},ST) ->
	llog("STUN message ~p from ~p.~nsource: ~p ~p",[Bin,Socket,Addr,Port]),
	{noreply,ST};
handle_info({udp,Socket,Addr,Port,<<0:2,_:1,1:1,_:1,1:1,_:2,_/binary>> =Bin},ST) ->
	llog("DTLS message ~p from ~p.~nsource: ~p ~p",[Bin,Socket,Addr,Port]),
	{noreply,ST};
handle_info({udp,Socket,Addr,Port,Bin},ST=#st{peerok=PeerOk, peer=Peer,isSS=IsSS,media_source=#ms{ssrc=ID}}) ->
	llog("unexpect packet ~p from ~p.~nsource: ~p ~p. trans data:~p~n",[Bin,Socket,Addr,Port, {PeerOk,Peer,IsSS,ID}]),
	{noreply,ST}.
%
handle_cast({play,Media},#st{media_source=MS,stream=Strm}=ST) ->
	{noreply,ST#st{media_source=MS#ms{to_pid=Media},stream=Strm#strm{from_pid=Media}}};
handle_cast({deplay,_Media},#st{media_source=MS,stream=Strm}=ST) ->
	{noreply,ST#st{media_source=MS#ms{to_pid=undefined},stream=Strm#strm{from_pid=undefined}}};
handle_cast(stop,#st{stream=#strm{from_pid=Media},cdc_st=#cst{type=Type,ctx=Ctx},session=Sess}=ST) ->
	llog("~p stopped.",[Sess]),
	process_traffic_statistic(ST),
	if is_pid(Media) -> my_server:cast(Media, {deplay,self()});
	true -> ok end,
	ok = codec:destory_codec(Type,Ctx),
	{stop,normal,[]}.
terminate(normal,_) ->
	ok.


% ----------------------------------
check_peer({IP1,Port1},{IP2,Port2}) ->
	if IP1=/=IP2 ->
%		llog("rtp address change: ~p to ~p",[make_ip_str(IP1)++":"++portstr(Port1),make_ip_str(IP2)++":"++portstr(Port2)]);
		void;
	true -> pass end,
	{IP2,Port2}.

check_ss_peer({IP1,Port1},{IP2,Port2}) ->
	if IP1=/=IP2 orelse Port1 =/= Port2 ->
%	      io:format("!!!!!!!!!!!ss rtp address change: ~p to ~p~n",[{IP1,Port1},{IP2,Port2}]),
		llog("ss rtp address change: ~p to ~p",[{IP1,Port1},{IP2,Port2}]);
	true -> pass end,
	{IP2,Port2};
check_ss_peer(Addr0, _) ->
	Addr0.
portstr(Port) when  is_integer(Port) -> integer_to_list(Port);
portstr(_)-> "unkown".

make_ip_str({A,B,C,D}) ->
	integer_to_list(A)++"."++integer_to_list(B)++"."++integer_to_list(C)++"."++integer_to_list(D);
make_ip_str(_)-> "unknown".

processRTP(Now,#ms{seq=undefined}=MS,
		   <<2:2,_:6,Mark:1,Codec:7,InSeq:16,TS:32,ID:32,PL/binary>>) ->
	AF1 = if Mark==0 -> [#audio_frame{codec=?LOSTSEQ,samples=0}];
		  true -> [] end,		% first packet must be Marked, else it's lost.
	AF2 = AF1++[#audio_frame{codec=Codec,marker=Mark,body=PL,samples=?DEFAULTPSIZE}],
	{AF2,MS#ms{ssrc=ID,roc=0,seq=InSeq,ts=TS,packets=1,bytes=size(PL),received=1,last_ts_wc={TS,Now}}};
processRTP(Now,#ms{roc=ROC,seq=Seq,ts=LTs,last_ts_wc=LastWC,ia_jitter=IAJitter,
				   packets=Pkts,bytes=Byts,received=Rcvd,lost=Lost,total_lost=TotLost}=MS,
		   <<2:2,_:6,Mark:1,Codec:7,InSeq:16,TS:32,_:32,PL/binary>>) ->
	{ExpRoc,ExpSeq} = get_expect_seq(ROC,Seq),
	{AFs,MS2} = if InSeq==ExpSeq ->
			AF1 = [#audio_frame{codec=Codec,marker=Mark,body=PL,samples=TS-LTs}],
			IAJ2 = compute_interarrival_jitter(MS#ms.type,IAJitter,{TS,Now},LastWC),
			{AF1,MS#ms{roc=ExpRoc,seq=ExpSeq,ts=TS,ia_jitter=IAJ2}};
		true ->
			case judge_bad_seq(Seq,InSeq) of
				{forward,N} ->
					AF1 = #audio_frame{codec=?LOSTSEQ,samples=N},
					{_,ROC2,_} = count_up_to_seq(InSeq,{ROC,Seq}),
					AF2 = [AF1,#audio_frame{codec=Codec,marker=Mark,body=PL,samples=?DEFAULTPSIZE}],
					{AF2,MS#ms{roc=ROC2,seq=InSeq,ts=TS,lost=Lost+N-1,total_lost=TotLost+N-1}};
				{backward,_} ->
					{[],MS}
			end
		end,
	{AFs,MS2#ms{packets=Pkts+1,bytes=Byts+size(PL),received=Rcvd+1,last_ts_wc={TS,Now}}}.

%
% processRTCP
%
save_sr_timecode(#ms{cssrc=CtrID}=MS,Now,RTCPElmts) ->
	case [{X#rtcp_sr.ssrc,X#rtcp_sr.ts64}||X<-RTCPElmts,is_record(X,rtcp_sr)] of
		[{SSRC,<<_:16,TS1:32,_:16>>}] when CtrID==according;CtrID==SSRC ->
			MS#ms{rtcp_ts_wc={TS1,Now}};
		_ ->
			MS
	end.

update_source_report(#strm{ssrc=MsID,sr_lost=RLost0,sr_eseq=ESeq0}=Strm,Now,RTCPElmts) ->
	case fetch_source_report(RTCPElmts) of
		[#source_report{ssrc=MsID,eseq=ESeq,lost={FLost,CumuLost},sr_ts=SRTS,sr_delay=SRDelay}] ->
			Rtt = compute_rtt(Now,SRTS,SRDelay),
			ThisLost = if ESeq0==undefined -> 0;
					   true -> trunc((ESeq-ESeq0)*FLost) end,
			Strm#strm{rtt=Rtt,sr_total_lost=CumuLost,sr_lost=RLost0+ThisLost,sr_eseq=ESeq};
		_ ->
			Strm
	end.

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
	RTT0 = MidTS - LastTS - Delay,		% rfc3550 Page40
	<<RTT:16,Fra:16>> = <<RTT0:32>>,
	RTT + Fra / 16#10000.

make_ts64({A1,A2,A3}) ->
  {(A1*1000000)+A2 + ?YEARS_70, trunc((A3/1000000)*16#100000000)}.

sync_rtp_ts(Now,#strm{type=audio,codec=Codec,wall_clock=LastWC,ts=TS}) ->
	Diff = timer:now_diff(Now,LastWC) div 1000,		% maybe minus value
	Delta = if Codec==?iSAC -> 16;
			true -> 8 end,		% iLBC PCMU PCMA
	Delta * Diff + TS.

% ----------------------------------
insert_RTCP_SR(#strm{cssrc=undefined}) ->
	pass;
insert_RTCP_SR(#strm{packets=Sents}) when (Sents rem 110)==0 ->
	my_timer:send_after(?RTCPINTERVAL, {send_sr,0,audio});
insert_RTCP_SR(_) ->
	pass.

make_rtcp_sr(Now,#strm{ssrc=SSRC,cname=CName,packets=Pkgs,bytes=Byts}=Strm,MS) ->
	Src1 = make_rtcp_source_desc(Now,MS),
	{MSW, LSW} = make_ts64(Now),
	SR = #rtcp_sr{ssrc = SSRC,
				  ts64 = <<MSW:32,LSW:32>>,
				  rtp_ts = sync_rtp_ts(Now,Strm),
				  packages = Pkgs,
				  bytes = Byts,
				  receptions = Src1},
	SD = #rtcp_sd{ssrc=SSRC, cname=CName},
	<<Head:?RTCPHEADLENGTH/binary,Body/binary>> = rtcp:enpack([SR,SD]),
	{MS#ms{received=0,lost=0},Head,Body}.

do_RTCP_RR(_CSock,_,#strm{type=Type}=Strm,MS) when Type=/=undefined ->
	{Strm,MS};
do_RTCP_RR(_CSock,_Peer,#strm{type=undefined,cssrc=undefined}=Strm,MS) ->	% no rtcp
	{Strm,MS};
do_RTCP_RR(CSock,{IP,Port},#strm{type=undefined,cssrc=CSSR}=Strm,MS) when is_integer(CSSR) -> % has no out_media_stream, rtcp_rr send needed.
	case make_rtcp_rr(now(),CSSR,MS) of
		{null,MS2} -> {Strm,MS2};
		{OutRTCP,MS2} ->
			gen_udp:send(CSock,IP,Port+1,OutRTCP),
			{Strm,MS2}
	end.

make_rtcp_rr(Now,SSRC,#ms{seq=Seq}=MS) when (Seq rem 110)==0 ->		% send rr every 110 packets received
	Src1 = make_rtcp_source_desc(Now,MS),
	RR = #rtcp_rr{ssrc=SSRC, receptions=Src1},
	{rtcp:enpack([RR]),MS#ms{received=0,lost=0}};
make_rtcp_rr(_,_,MS) ->
	{null,MS}.

make_rtcp_source_desc(Now,#ms{seq=Seq}=MS) when Seq=/=undefined ->
	#ms{ssrc=RSSRC,roc=ROC,rtcp_ts_wc=LastSR,total_lost=CumuLost,received=PktR,lost=PktL,ia_jitter=IAJ} = MS,
		{TS1,RTC1} = if LastSR==undefined -> {0,0};
					 true ->
					 	{TS32,RTime} = LastSR,
					 	{TS32,make_dlsr(timer:now_diff(Now,RTime))}
					 end,
		FracLost = if PktR==0 andalso PktL==0 -> 0;
					  PktL<0 -> 0;
				   true -> trunc((PktL / (PktL+PktR))*16#100) end,
		[#source_report{ssrc = RSSRC,
						lost = {FracLost,CumuLost},
						eseq = ROC*16#10000+Seq,
						jitter = IAJ,
						sr_ts = TS1,
						sr_delay = RTC1}];
make_rtcp_source_desc(_,_) ->
	[].

make_dlsr(Diff) ->
	{Sec,Us} = {Diff div 1000000,Diff rem 1000000},
	Frac = trunc((Us/1000000)*16#10000),
	<<DLsr:32>> = <<Sec:16,Frac:16>>,
	DLsr.


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

count_up_to_seq(InSeq,{LastROC,LastSeq}) ->
	count_up_to_seq(0,InSeq,{LastROC,LastSeq}).
count_up_to_seq(N,InSeq,{ROC,Seq}) when InSeq==Seq ->
	{N,ROC,InSeq};
count_up_to_seq(N,InSeq,{LastROC,LastSeq}) ->
	{ROC,Seq} = get_expect_seq(LastROC,LastSeq),
	count_up_to_seq(N+1,InSeq,{ROC,Seq}).

compute_interarrival_jitter(Type,IAJ,{TS,Now},{PTS,PNow}) ->
	Map = if Type==audio -> 8; true -> 90 end,
	Rji = Map * timer:now_diff(Now,PNow) div 1000,
	Sji = TS - PTS,
	IAJ + (abs(Rji-Sji) - IAJ) div 16.

% ----------------------------------
compose_rtp(#strm{roc=ROC,seq=Sequence,packets=Packets, bytes=Bytes}=Strm,Codec,M,Data) ->
	Pack = make_rtp_pack(Strm,M,Codec,Data),
	{NewROC,NewSeq} = get_expect_seq(ROC,Sequence),
	{Strm#strm{seq=NewSeq,roc=NewROC,packets=Packets+1,bytes=Bytes+size(Data)}, Pack}.

make_rtp_pack(#strm{seq=Sequence,ts=Timestamp,ssrc=SSRC},Marker,PayloadType,Data) ->
  Version = 2,
  Padding = 0,
  Extension = 0,
  CSRC = 0,
  M = if Marker -> 1; true->0 end,
  <<Version:2,Padding:1,Extension:1,CSRC:4,M:1,PayloadType:7,Sequence:16,Timestamp:32,SSRC:32,Data/binary>>.

inc_timecode_fixed(#strm{type=audio,ts=0}=Strm, Samples) ->		% first packet
	Now = now(),
	TS = sync_rtp_ts(Now,Strm),
	Strm#strm{ts=Samples+TS,wall_clock=Now};
inc_timecode_fixed(#strm{type=audio,ts=TS}=Strm, Samples) ->
	Strm#strm{ts=Samples+TS,wall_clock=now()}.

% ----------------------------------

processMedia(Cst,_Processor,[]) ->
	Cst;
processMedia(Cst,Processor,[#audio_frame{codec=?LOSTSEQ,samples=0}|AFL]) ->
	processMedia(Cst,Processor,AFL);
processMedia(#cst{type=Type,ctx=Ctx}=Cst,Processor,[#audio_frame{codec=?LOSTSEQ,samples=N}|AFL]) ->
	{ok,Ctx2,_Type2,_Raw} = codec:plc(Type,Ctx,?DEFAULTPSIZE),
	processMedia(Cst#cst{ctx=Ctx2},Processor,AFL);
processMedia(#cst{type=Type,ctx=Ctx}=Cst,Processor,[#audio_frame{codec=Codec,marker=M,body=Body,samples=Samples}|AFL]) ->
	Ctx3 = case codec_check_match(Type,Codec) of
			true ->
				{ok,Ctx2,Type2,Raw} = codec:dec(Type,Ctx,M,Samples,Body),
				send_media(Processor,#audio_frame{codec=Type2,body=Raw,samples=Samples}),
				Ctx2;
			false ->
				Ctx
		end,
	processMedia(Cst#cst{ctx=Ctx3},Processor,AFL).

process_traffic_statistic(#st{session=Sess,start_time=SDT,report_to=To,peer=Peer,media_source=MS,stream=Strm,isSS=IsSS}) ->
	StopT = xt:t2str(time()),
	StartDT = xt:dt2str(SDT),
	#ms{packets=R_Pkts,bytes=R_Byts,total_lost=RTotalLost,ssrc=SSRC} = MS,
	#strm{packets=S_Pkts,bytes=S_Byts,rtt=RTT,sr_total_lost=SRTotalLost} = Strm,
	llog("session: ~p ssrc: ~p  (~p - ~p)",[Sess,SSRC,StartDT,StopT]),
	llog("~p ~p ~p~n~p~n~p",[Peer,RTT,IsSS,{S_Pkts,S_Byts,SRTotalLost},{R_Pkts,R_Byts,RTotalLost}]),
	ok.

codec_check_match(Type, Codec) when Type==Codec -> true;	% iSAC,PCMU,iLBC
codec_check_match(?u16K, ?PCMU) -> true;
codec_check_match(_, _) -> io:format("d"), false.
% ----------------------------------

llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

start_pair_within(Session,{BEGIN_UDP_RANGE,END_UDP_RANGE}) ->
	case try_port_pair(BEGIN_UDP_RANGE,END_UDP_RANGE) of
		{ok,Port,Sock1,Sock2} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Sock1,Sock2],[]),
			gen_udp:controlling_process(Sock1, Pid),
			gen_udp:controlling_process(Sock2, Pid),
			{ok,Pid,{Port,Sock1},{Port+1,Sock2}};
		{error, Reason} ->
			{error,Reason}
	end.

start_pair(Session) ->
	{MOBILE_BEGIN_UDP_RANGE,MOBILE_END_UDP_RANGE} = avscfg:get(mweb_udp_range),
	start_pair_within(Session,{MOBILE_BEGIN_UDP_RANGE,MOBILE_END_UDP_RANGE}).

stop(RTP) ->
	my_server:cast(RTP,stop).
info(Pid,Info) ->
	my_server:call(Pid,Info).

rtp_report(undefined,_Sess,_Cmd) ->
	pass;
rtp_report(To,Sess,Cmd) ->
	my_server:call(To,{rtp_report,Sess,Cmd}).

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
	
try_port4ss(Begin, End)->
    From = 
    case app_manager:get_last_used_ssport() of
    undefined-> Begin;
    {ok, From1}-> From1
    end,
    try_port4ss(Begin, End, From, From+2).
    
try_port4ss(BPort,EPort,FPort, Port) when Port == FPort; Port==FPort+1 ->
	{error,out_of_udp};
try_port4ss(BPort,EPort,FPort, Port) when Port > EPort ->
	try_port4ss(BPort,EPort,FPort, BPort);
try_port4ss(BPort,EPort,FPort, Port) ->
	case gen_udp:open(Port, [binary, {active, true}, {recbuf, 4096}]) of
		{ok, Socket} ->
		       app_manager:set_last_used_ssport(Port),
			{ok,Port,Socket};
		{error, _} ->
			try_port4ss(BPort,EPort,FPort, Port+2)
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
send_media(loop, Frame) ->
	self() ! Frame;
send_media(_,_) ->
	drop.

start4ss(Session) ->
%	{PLN,Codec} = {?PCMU,?u16K},
	{PLN,Codec} = {?G729,?G729},
	{ok,Pid,Port} = open_udp(Session),
    	llog("rrp socket pid ~p get ss port ~p",[Pid,Port]),
	my_server:call(Pid,{add_media,audio,[according,undefined,undefined,undefined]}),
	my_server:call(Pid,{add_stream,audio,[PLN,undefined,10001,undefined]}),
	my_server:call(Pid,{add_codec,Codec,[]}),
	{ok,Pid,Port}.
stop4ss(Pid) ->
	stop(Pid).

open_udp(Session) ->
	{SS_BEGIN_UDP_RANGE,SS_END_UDP_RANGE} = avscfg:get(ss_udp_range),
	case try_port4ss(SS_BEGIN_UDP_RANGE,SS_END_UDP_RANGE) of
		{ok,Port,Socket} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Socket,undefined,true],[]),
			gen_udp:controlling_process(Socket, Pid),
			{ok,Pid,Port};
		{error, Reason} ->
			{error,Reason}
	end.

