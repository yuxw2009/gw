-module(rrp).	% the relay rtp with buffer module
-compile(export_all).

-define(RTPHEADLENGTH,12).
-define(RTCPHEADLENGTH,8).

-define(FS16K,16000).
-define(FS8K,8000).
-define(PTIME,20).
-define(PSIZE,160).
-define(ISACPTIME,30).
-define(ILBCPTIME,30).
-define(OPUSPTIME,60).

-define(PCMU,0).
-define(PCMA,8).
-define(LINEAR,99).
-define(G729,18).
-define(CN,13).
-define(PHN,101).
-define(iLBC,102).
-define(iSAC,103).
-define(iCNG,105).
-define(OPUS,111).
-define(LOSTiSAC,1003).

-define(VADMODE,3).

-define(ILBCFRAMESIZE,50).
-define(PT160,160).

-define(V29BUFLEN, 120).    % chrome v29 voice buf length = 120ms
-define(VBUFOVERFLOW,2000). % voice buf overflow length = 2000ms

-include("desc.hrl").

-record(apip, {		% audio pipe-line
	trace,			% voice / noise
	noise_deep,		% noise:1,2,3  voice:-1,0
	noise_duration,	% 1,2 = 0,1,2  3 = 0,1,2,3
	abuf,			% PCM16 audio buf, as isac_nb used, the sample-rate here is 8Khz
	passed,			% passed voice samples
	last_samples,	% for lost frame recovery
	vad,
	cnge,
	cngd,
	cdc
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

-record(st, {
	session,
	webcodec,
	sipcodec,
	cdcparams,
	socket,
	peer,
	peerok=false,
	media,		% rtp <-> media (Pid)
	r_base,
	in_stream,	% local media audio_desc
	snd_pev = #ev{},	% rtp send phone event
	rcv_pev = #ev{},	% udp received phone event
	u2sip = <<>>,
	passu,
	noise,
	vcr,
	vcr_buf= <<>>,	% temp store web audio
	timer,
	timeru,
	to_sip,		% isac -> pcmu -> MG9000
	to_web		% pcmu -> isac -> webrtc
}).

init([Session,Socket,{WebCdc,SipCdc}=Params,Vcr]) ->
	VCR = if Vcr==has_vcr-> vcr:start(mkvfn("wvoip")); true-> undefined end,
%	{ok,Noise} = file:read_file("cn.pcm"),
	Noise = tone:cn_pcm(),
	ST = case WebCdc of
			pcmu ->
				llog("rrp ~p started: pcmu@web",[Session]),
				#st{webcodec=pcmu,r_base=#base_info{timecode=0}};
			{ilbc,Ilbc,VAD,VAD2,{CNGE,CNGD}} ->
				ToWeb = #apip{trace=voice,noise_deep=0,noise_duration=0,passed=zero_pcm16(?FS8K,60),abuf= <<>>,
						vad=VAD,cnge=CNGE,cdc=Ilbc},	% ilbc encoder used
				ToSip = #apip{trace=voice,passed=zero_pcm16(?FS8K,20),abuf= <<>>,
						vad=VAD2,cngd=CNGD,cdc=Ilbc},	% ilbc decoder used
				llog("rrp ~p get ilbc,~p vad:~p vad:~p cng:~p,~p",[Session,Ilbc,VAD,VAD2,CNGE,CNGD]),  % for convient to query seize and release
				#st{webcodec=ilbc,r_base=#base_info{timecode=0},to_web=ToWeb,to_sip=ToSip};
			{opus,Opus,VAD,VAD2,{CNGE,CNGD}} ->
				ToWeb = #apip{trace=voice,noise_deep=0,noise_duration=0,passed=zero_pcm16(?FS8K,60),abuf= <<>>,
						vad=VAD,cnge=CNGE,cdc=Opus},	% opus encoder used
				ToSip = #apip{trace=voice,passed=zero_pcm16(?FS8K,20),abuf= <<>>,
						vad=VAD2,cngd=CNGD,cdc=Opus},	% opus decoder used
				llog("rrp ~p get ~p:~p vad:~p vad:~p cng:~p,~p",[Session,opus,Opus,VAD,VAD2,CNGE,CNGD]),
				#st{webcodec=opus,r_base=#base_info{timecode=0},to_web=ToWeb,to_sip=ToSip};
			{isac,Isac,VAD,VAD2,{CNGE,CNGD}} ->
				ToWeb = #apip{trace=voice,noise_deep=0,noise_duration=0,passed=zero_pcm16(?FS16K,60),abuf= <<>>,
						vad=VAD,cnge=CNGE,cdc=Isac},	% isac encoder used
				ToSip = #apip{trace=voice,passed=zero_pcm16(?FS16K,20),abuf= <<>>,
						vad=VAD2,cngd=CNGD,cdc=Isac},	% isac decoder used
				llog("rrp ~p get ~p:~p vad:~p vad:~p cng:~p,~p",[Session,isac,Isac,VAD,VAD2,CNGE,CNGD]),
				#st{webcodec=isac,r_base=#base_info{timecode=0},to_web=ToWeb,to_sip=ToSip}
			end,
	SipC = case SipCdc of
			pcmu -> pcmu;
			{g729,Ctx} -> llog("rrp ~p g729=~p @sip.",[Session,Ctx]), {g729,Ctx}
			end,
	{ok,ST#st{sipcodec=SipC,session=Session,socket=Socket,cdcparams=Params,vcr=VCR,noise=Noise}}.

handle_call({options,Options},_From,State) ->
	[IP,Port] = proplists:get_value(remoteip,Options),
	{reply,ok,State#st{peer={IP,Port},peerok=true}};
handle_call(stop, _From, #st{vcr=VCR, timer=TR,timeru=TRU}=ST) ->
	llog("rrtp ~p stopped.",[ST#st.session]),
	vcr:stop(VCR),
	my_timer:cancel(TR),
	if TRU=/=undefined -> my_timer:cancel(TRU); true->pass end,
	{stop,normal, ok, ST#st{peerok=false}};
handle_call(_Call, _From, State) ->
    {noreply,State}.	
	
handle_info({play,WebRTP}, State) ->
	%%io:format("RRP get webrtc ~p.~n",[WebRTP]),
	WallClock = now(),
	Timecode = init_rnd_timecode(),
	BaseRTP = #base_rtp{ssrc = init_rnd_ssrc(),
						seq = init_rnd_seq(),
						base_timecode = Timecode,
						timecode = Timecode,
						wall_clock = WallClock},
	WCdc = State#st.webcodec,
	llog("rrp start timer for ~p",[WCdc]),
	TR = case WCdc of
		   isac ->
			{ok,Tr} = my_timer:send_interval(?ISACPTIME,isac_to_webrtc),
			{ok,_} = my_timer:send_after(60,delay_pcmu_to_sip),
			Tr;
		   ilbc ->
			{ok,Tr} = my_timer:send_interval(?ILBCPTIME,ilbc_to_webrtc),
			{ok,_} = my_timer:send_after(60,delay_pcmu_to_sip),
			Tr;
		   opus ->
			{ok,Tr} = my_timer:send_interval(?OPUSPTIME,opus_to_webrtc),
			{ok,_} = my_timer:send_after(60,delay_pcmu_to_sip),
			Tr;
		   pcmu ->		% pcmu old method
			{ok,Tr} = my_timer:send_interval(?PTIME,send_sample_interval),
			Tr
		end,
	{noreply,State#st{media=WebRTP,in_stream=BaseRTP,timer=TR,u2sip= <<>>}};
handle_info(delay_pcmu_to_sip, ST) ->
	{ok,TR} = my_timer:send_interval(?PTIME,pcmu_to_sip),
	{noreply,ST#st{timeru=TR}};
handle_info({deplay,WebRTP}, #st{timer=TR,timeru=TRU}=State) ->
	%%io:format("RRP leave rtp: ~p.~n",[WebRTP]),
	my_timer:cancel(TR),
	if TRU=/=undefined -> my_timer:cancel(TRU); true->pass end,
	{noreply,State#st{peerok=false}};
%
% send phone event to sip
%
handle_info({send_phone_event,Nu,Vol,Dura},#st{snd_pev=SPEv}=ST) ->
	llog("~p send DTMF ~p",[ST#st.session,Nu]),
	SPEv2 = if SPEv#ev.actived==false -> 
				#ev{actived=true,step=init,t_begin=now(),nu=Nu,vol=Vol,dura=Dura};
			true ->
				InQ = SPEv#ev.queue,
				SPEv#ev{queue=InQ++[{Nu,Vol,Dura}]}
			end,
	{noreply,ST#st{snd_pev=SPEv2}};
handle_info(pcmu_to_sip,#st{snd_pev=#ev{actived=true}=SPEv,socket=Socket,peer={IP,Port},in_stream=BaseRTP}=ST) ->
	flush_msg(pcmu_to_sip),
	{SPEv2,M,Samples,F1} = processSPE(SPEv),
	%%io:format("~p ~p~n",[M,F1]),
	NewBaseRTP = inc_timecode(BaseRTP,Samples),
	{Strm3,OutBin} = compose_rtp(NewBaseRTP#base_rtp{marker=M},?PHN,F1),
	send_udp(Socket,IP,Port,OutBin),
	Strm4 = if SPEv2#ev.step==init orelse SPEv2#ev.actived==false ->
				inc_timecode(Strm3,SPEv2#ev.tcount + SPEv2#ev.gcount*160 -160);
			true -> Strm3 end,
	{noreply,ST#st{in_stream=Strm4,snd_pev=SPEv2}};
%
% pcm-u send to msg9000 web (isac/opus mode)
%
handle_info(pcmu_to_sip,#st{peerok=false,to_sip=#apip{vad=VAD,passed=Passed,abuf=AB}=ToSip} = ST) -> 	% peerok is true after MSG9000's sdp received
	flush_msg(pcmu_to_sip),
	{{_,F1},RestAB} = shift_to_voice_keep_get_samples(VAD,if ST#st.webcodec==isac -> ?FS16K;
	                                                     true -> ?FS8K end,
	                                                 ?PTIME,Passed,AB),
    {noreply,ST#st{to_sip=ToSip#apip{abuf=RestAB,passed=F1}}};
handle_info(pcmu_to_sip,#st{webcodec=isac, to_sip=#apip{trace=Trace,vad=VAD,passed=Passed,abuf=AB}=ToSip,
							in_stream=BaseRTP,socket=Socket,peer={IP,Port},vcr=VCR,vcr_buf=VB}=ST) ->
	flush_msg(pcmu_to_sip),
	{{Type,F1},RestAB} = if Trace==noise ->
							shift_to_voice_keep_get_samples(VAD,?FS16K,?PTIME,Passed,AB);
						 true ->
						 	get_samples(VAD,?FS16K,?PTIME,Passed,AB)
						 end,
	PCM = erl_resample:down8k(F1),
	{PN,Enc} = compress_voice(ST#st.sipcodec,PCM),
	{NewBaseRTP, RTP} = compose_rtp(inc_timecode(BaseRTP,?PSIZE),PN,Enc),
	send_udp(Socket,IP,Port,RTP),
	VB2 = if is_pid(VCR)-> <<VB/binary,PCM/binary>>;true->VB end,
	{noreply,ST#st{in_stream=NewBaseRTP,to_sip=ToSip#apip{abuf=RestAB,trace=Type,passed=F1},vcr_buf=VB2}};
handle_info(pcmu_to_sip,#st{webcodec=Wcdc, to_sip=#apip{trace=Trace,vad=VAD,passed=Passed,abuf=AB}=ToSip,
							in_stream=BaseRTP,socket=Socket,peer={IP,Port},vcr=VCR,vcr_buf=VB}=ST)
							when Wcdc==opus;Wcdc==ilbc ->
	flush_msg(pcmu_to_sip),
	{{Type,F1},RestAB} = if Trace==noise ->
							shift_to_voice_keep_get_samples(VAD,?FS8K,?PTIME,Passed,AB);
						 true ->
						 	get_samples(VAD,?FS8K,?PTIME,Passed,AB)
						 end,
	{PN,Enc} = compress_voice(ST#st.sipcodec,F1),
	{NewBaseRTP, RTP} = compose_rtp(inc_timecode(BaseRTP,?PSIZE),PN,Enc),
	send_udp(Socket,IP,Port,RTP),
	VB2 = if is_pid(VCR)-> <<VB/binary,F1/binary>>;true->VB end,
	{noreply,ST#st{in_stream=NewBaseRTP,to_sip=ToSip#apip{abuf=RestAB,trace=Type,passed=F1},vcr_buf=VB2}};

%
% isac/icng send to webrtc
%
handle_info(isac_to_webrtc,#st{webcodec=isac,to_web=#apip{trace=voice,noise_deep=0}=ToWeb}=ST) ->
	flush_msg(isac_to_webrtc),
	{noreply,ST#st{to_web=ToWeb#apip{noise_deep=-1}}};
handle_info(isac_to_webrtc,#st{webcodec=isac,media=Web,to_web=#apip{trace=voice,noise_deep=-1}=ToWeb}=ST) ->
	flush_msg(isac_to_webrtc),
	#apip{vad=VAD,cnge=CNGE,cdc=Isac,passed=Passed,abuf=AB} = ToWeb,
	case get_samples(VAD,?FS16K,60,Passed,AB) of	% 16Khz 60ms 16-bit samples = 960
		{{voice,F1},RestAB} ->
			{0,_,Aenc} = erl_isac_nb:xenc(Isac,F1),
			Web ! #audio_frame{codec=?iSAC,marker=false,body=Aenc,samples=960},
			{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,noise_deep=0,passed=F1}}};
		{{noise,<<ND1:960/binary,ND2/binary>>},RestAB} ->
%			{0,<<>>} = erl_cng_xenc(CNGE,ND1,0),
%			{0,Asid} = erl_cng:xenc(CNGE,ND2,1),
%			Web ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=960},
			{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,trace=noise,noise_deep=1,noise_duration=0,passed=ND2}}}
	end;
handle_info(isac_to_webrtc,#st{webcodec=isac,media=Web,to_web=#apip{trace=noise,noise_deep=NDeep}=ToWeb}=ST) when NDeep>0 ->
	flush_msg(isac_to_webrtc),
	#apip{vad=VAD,cnge=CNGE,cdc=Isac,passed=Passed,abuf=AB,noise_duration=NDur} = ToWeb,
	case shift_to_voice_and_get_samples(VAD,?FS16K,30,Passed,AB) of
		{{voice,F1},RestAB} ->
			{BlkN,F2} = get_nearest_samples(0,?FS16K,30,Passed),
			{0,_,Aenc} = erl_isac_nb:xenc(Isac,<<F2/binary,F1/binary>>),
			Web ! #audio_frame{codec=?iSAC,marker=true,body=Aenc,samples=(BlkN+1)*480},
			{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,trace=voice,noise_deep=0,passed= <<F2/binary,F1/binary>>}}};
		{{noise,F1},RestAB} ->
			if NDeep==1;NDeep==2 ->
				if NDur==0;NDur==1 ->
					{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,noise_duration=NDur+1,passed= <<Passed/binary,F1/binary>>}}};
				true ->
					<<_:960/binary,ND1:960/binary,ND2/binary>> =Passed,
%					{0,_} = erl_cng_xenc(CNGE,ND1,0),	% why 0 has 9-byte output?
%					{0,_} = erl_cng_xenc(CNGE,ND2,0),
%					{0,Asid} = erl_cng:xenc(CNGE,F1, 1),
%					Web ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=1440},
					{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,noise_deep=NDeep+1,noise_duration=0,passed=F1}}}
				end;
			true ->		% NDeep==3
				if NDur==0;NDur==1;NDur==2 ->
					{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,noise_duration=NDur+1,passed= <<Passed/binary,F1/binary>>}}};
				true ->
					<<_:960/binary,ND1:960/binary,ND2:960/binary,ND3/binary>> =Passed,
%					{0,<<>>} = erl_cng_xenc(CNGE,ND1,0),
%					{0,<<>>} = erl_cng_xenc(CNGE,ND2,0),
%					{0,<<>>} = erl_cng_xenc(CNGE,ND3,0),
%					{0,Asid} = erl_cng:xenc(CNGE,F1, 1),
%					Web ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=1920},
					{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,noise_deep=1,noise_duration=0,passed=F1}}}
				end
			end
	end;
%
%
% opus send to webrtc
%
handle_info(opus_to_webrtc,#st{webcodec=opus,to_web=#apip{trace=voice,noise_deep=0}=ToWeb}=ST) ->
	flush_msg(opus_to_webrtc),
	{noreply,ST#st{to_web=ToWeb#apip{noise_deep=-1}}};
handle_info(opus_to_webrtc,#st{webcodec=opus,media=Web,to_web=#apip{trace=voice,noise_deep=-1}=ToWeb}=ST) ->
	flush_msg(opus_to_webrtc),
	#apip{vad=VAD,cnge=CNGE,cdc=Opus,passed=Passed,abuf=AB} = ToWeb,
	{{_Type,F1},RestAB} = shift_to_voice_and_get_samples(VAD,?FS8K,60,Passed,AB),	% 8Khz 20ms 16-bit
	{0,Aenc} = erl_opus:xenc(Opus,F1),
	Web ! #audio_frame{codec=?OPUS,marker=false,body=Aenc,samples=2880},
	{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,passed=F1}}};
%
%
% ilbc send to webrtc
%
handle_info(ilbc_to_webrtc,#st{webcodec=ilbc,to_web=#apip{trace=voice,noise_deep=0}=ToWeb}=ST) ->
	flush_msg(ilbc_to_webrtc),
	{noreply,ST#st{to_web=ToWeb#apip{noise_deep=-1}}};
handle_info(ilbc_to_webrtc,#st{webcodec=ilbc,media=Web,to_web=#apip{trace=voice,noise_deep=-1}=ToWeb}=ST) ->
	flush_msg(ilbc_to_webrtc),
	#apip{vad=VAD,cnge=CNGE,cdc=Ilbc,passed=Passed,abuf=AB} = ToWeb,
	case shift_to_voice_and_get_samples(VAD,?FS8K,60,Passed,AB) of	% 8Khz 30ms 16-bit
		{{voice,F1},RestAB} ->
			Aenc = ilbc_enc60(Ilbc,F1),
			Web ! #audio_frame{codec=?iLBC,marker=false,body=Aenc,samples=480},
			{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,passed=F1,noise_deep=0}}};
		{{noise,F1},RestAB} ->
%			{0,Asid} = erl_cng:xenc(CNGE,F1,1),
%			Web ! #audio_frame{codec=?CN,marker=false,body=Asid,samples=480},
			{noreply,ST#st{to_web=ToWeb#apip{abuf=RestAB,passed=F1,noise_deep=0}}}
	end;
%
%
% udp received
%
handle_info({udp,_Socket,_Addr,_Port,<<2:2,_:6,Mark:1,?PHN:7,Seq:16,TS:32,SSRC:4/binary,Info:4/binary,_/binary>>},
			#st{media=OM,r_base=#base_info{seq=LastSeq,timecode=LastTs},rcv_pev=RPEv}=ST) ->
%	<<Nu:8,IsEnd:1,_IsRsv:1,Volume:6,Dura:16>> = Info,
	M = if Mark==0 -> false; true-> true end,
	RPEv2 = processRPE(RPEv,{LastSeq,LastTs},{Seq,TS},M,Info),
	{ok,VB2} = processVCR(ST#st.vcr,ST#st.vcr_buf,erl_isac_nb:udec(get_random_160s(ST#st.noise))),
	{noreply,ST#st{r_base=#base_info{seq=Seq,timecode=TS},rcv_pev=RPEv2,vcr_buf=VB2}};
% sip@pcmu old(test) version,no voice_buf version
handle_info({udp,_Sck,_A,_P,<<2:2,_:6,_Mark:1,PN:7,Seq:16,TS:32,SSRC:4/binary,Body/binary>>},
			#st{webcodec=pcmu,media=OM,r_base=#base_info{seq=LastSeq},to_web=ToWeb,passu=PsU}=ST)
			when PN==?PCMU;PN==?G729 ->
	{PCMU,PCM} = if PN==?PCMU -> {Body,erl_isac_nb:udec(Body)};
	             true -> Linear = uncompress_voice(ST#st.sipcodec,PN,Body),
	                     {erl_isac_nb:uenc(Linear),Linear}
	             end,
	Frame = #audio_frame{codec = ?PCMU, body = PCMU,samples=?PSIZE},
	if is_pid(OM) -> OM ! Frame;
	true -> pass end,
	{ok,VB2} = processVCR(ST#st.vcr,ST#st.vcr_buf,PCM),
	{noreply,ST#st{r_base=#base_info{seq=Seq,timecode=TS},vcr_buf=VB2}};
% sip@isac/opus/ilbc
handle_info({udp,_Sck,_A,_P,<<2:2,_:6,_Mark:1,PN:7,Seq:16,TS:32,SSRC:4/binary,Body/binary>>},
			#st{webcodec=Wcdc,media=OM,r_base=#base_info{seq=LastSeq},to_web=ToWeb,passu=PsU}=ST)
			when PN==?PCMU;PN==?G729 ->
	AB = ToWeb#apip.abuf,
	if size(AB) > ?VBUFOVERFLOW * (?FS8K div 1000) * 2 ->
	  {noreply,ST#st{r_base=#base_info{seq=Seq,timecode=TS}}};
	true ->
	    if Wcdc==isac ->
	        PCM = uncompress_voice(ST#st.sipcodec,PN,Body),
	        PCM16_16K = if LastSeq==undefined -> erl_resample:up16k(PCM,<<0,0,0,0,0,0,0,0,0,0>>);
                                   size(PsU) < 10 -> erl_resample:up16k(PCM,<<0,0,0,0,0,0,0,0,0,0>>);
			            true -> erl_resample:up16k(PCM,PsU) end,
	        Abuf2 = <<AB/binary,PCM16_16K/binary>>,
	        <<_:310/binary,PsU2/binary>> = PCM,
	        {ok,VB2} = processVCR(ST#st.vcr,ST#st.vcr_buf,PCM),
	        {noreply,ST#st{r_base=#base_info{seq=Seq,timecode=TS},to_web=ToWeb#apip{abuf=Abuf2},passu=PsU2,vcr_buf=VB2}};
	    true ->     % ilbc or opus
	        PCM = uncompress_voice(ST#st.sipcodec,PN,Body),
	        Abuf2 = <<AB/binary,PCM/binary>>,
	        {ok,VB2} = processVCR(ST#st.vcr,ST#st.vcr_buf,PCM),
	        {noreply,ST#st{r_base=#base_info{seq=Seq,timecode=TS},to_web=ToWeb#apip{abuf=Abuf2},vcr_buf=VB2}}
	    end
    end;
handle_info({udp,_,A,P,B},ST) ->
	%%io:format("unexcept binary from ~p:~p~n~p~n",[A,P,B]),
	{noreply,ST};
%
%   isac codec (wcg -> sip)
%
handle_info(#audio_frame{codec=?LOSTiSAC,samples=_N},#st{to_sip=#apip{abuf=AB,cdc=Isac,last_samples=LastSamples}=ToSip}=ST) ->
	{noreply,ST}; % #st{to_sip=ToSip#apip{abuf=AB2}}};
handle_info(AudioFrame=#audio_frame{},ST) -> 
    handle_audio_frame(AudioFrame,ST);
%
handle_info(send_sample_interval,#st{peerok=false} = State) ->
	{noreply,State};
handle_info(send_sample_interval,#st{snd_pev=#ev{actived=false},peerok=true,in_stream=BaseRTP,socket=Socket,peer={IP,Port},u2sip=U2Sip} = State) ->
	{Body,Rest} = if size(U2Sip)>=160 -> split_binary(U2Sip,160);
				 true -> {get_random_160s(State#st.noise),U2Sip}
				 end,
	{PN,Enc} = if State#st.sipcodec==pcmu -> {?PCMU,Body};
	           true -> PCM=erl_isac_nb:udec(Body), compress_voice(State#st.sipcodec,PCM)
	           end,
	{NewBaseRTP, RTP} = compose_rtp(inc_timecode(BaseRTP,?PSIZE),PN,Enc),
	send_udp(Socket,IP,Port,RTP),
	{noreply, State#st{in_stream = NewBaseRTP,u2sip=Rest}};

%
handle_info(Msg, ST) ->
	llog("rrp unexcept msg ~p.~n",[Msg]),
	{noreply,ST}.

terminate(normal,_) ->
	ok.

handle_audio_frame(#audio_frame{codec=?LOSTiSAC,samples=_N},#st{to_sip=#apip{abuf=AB,cdc=Isac,last_samples=LastSamples}=ToSip}=ST) ->
	{noreply,ST}; % #st{to_sip=ToSip#apip{abuf=AB2}}};
handle_audio_frame(#audio_frame{codec=?iSAC,body=Body,samples=Samples},#st{webcodec=isac,to_sip=#apip{abuf=AB,cdc=Isac}=ToSip}=ST) ->
	if size(AB) > ?VBUFOVERFLOW * (?FS16K div 1000) * 2 ->
	    {noreply,ST#st{to_sip=ToSip#apip{last_samples=Samples}}};
	true ->
	  {OK, Adec} = erl_isac_nb:xdec(Isac,Body,960,Samples),
	  Adec2 = if OK==0 -> Adec;
			     OK==1;OK==2 -> Adec;		% error occurred
			  true -> L2=OK*2, <<A1:L2/binary,_/binary>> = Adec, A1
			  end,
	  {noreply,ST#st{to_sip=ToSip#apip{abuf= <<AB/binary,Adec2/binary>>,last_samples=Samples}}}
	end;
handle_audio_frame(#audio_frame{codec=?iCNG,body=Body,samples=Samples},#st{to_sip=#apip{abuf=AB,cngd=CNGD}=ToSip}=ST) ->
	if size(AB) > ?VBUFOVERFLOW * (?FS16K div 1000) * 2 ->
	    {noreply, ST#st{to_sip=ToSip#apip{last_samples=Samples}}};
	true ->
	    0 = erl_cng:xupd(CNGD,Body),
	    Noise = generate_noise_nb(CNGD,Samples,<<>>),
	    {noreply,ST#st{to_sip=ToSip#apip{abuf= <<AB/binary,Noise/binary>>}}}
	end;

%
%  test opus codec (wcg -> ss)
%
handle_audio_frame(#audio_frame{codec=?OPUS,body=Body,samples=Samples},#st{webcodec=opus,to_sip=#apip{abuf=AB,cdc=Isac}=ToSip}=ST) ->
	if size(AB) > ?VBUFOVERFLOW * (?FS8K div 1000) * 2 ->
	    {noreply,ST#st{to_sip=ToSip#apip{last_samples=Samples}}};
	true ->
	    {0, FrameSize, Adec} = erl_opus:xdec(Isac,Body),
	    {noreply,ST#st{to_sip=ToSip#apip{abuf= <<AB/binary,Adec/binary>>,last_samples=Samples}}}
	end;

%
%  test ilbc codec (wcg -> ss)
%
handle_audio_frame(#audio_frame{codec=?iLBC,body=Body,samples=Samples},#st{webcodec=ilbc,to_sip=#apip{abuf=AB,cdc=Ilbc}=ToSip}=ST) ->
	if size(AB) > ?VBUFOVERFLOW * (?FS8K div 1000) * 2 ->
	    {noreply,ST#st{to_sip=ToSip#apip{last_samples=Samples}}};
	true ->
	    Adec = ilbc_dec_pkgs(Ilbc, Body, <<>>),
	    {noreply,ST#st{to_sip=ToSip#apip{abuf= <<AB/binary,Adec/binary>>,last_samples=Samples}}}
	end;
handle_audio_frame(#audio_frame{codec=?CN,body=Body,samples=Samples},#st{webcodec=ilbc,to_sip=#apip{abuf=AB,cngd=CNGD}=ToSip}=ST) ->
	if size(AB) > ?VBUFOVERFLOW * (?FS8K div 1000) * 2 ->
	    {noreply,ST#st{to_sip=ToSip#apip{last_samples=Samples}}};
	true ->
	    0 = erl_cng:xupd(CNGD,Body),
	    Noise = generate_noise_nb(CNGD,Samples,<<>>),
	    {noreply,ST#st{to_sip=ToSip#apip{abuf= <<AB/binary,Noise/binary>>,last_samples=Samples}}}
	end;

%
% sip pcmu <-> web pcmu with cng (old version)
%
handle_audio_frame(#audio_frame{codec=Codec},#st{webcodec=pcmu,peerok=false} = State) when Codec==?PCMU;Codec==?CN ->
    {noreply,State};
handle_audio_frame(#audio_frame{codec=?PCMU,body=Body}, #st{u2sip=U2Sip,vcr=VCR,vcr_buf=VB}=State) ->
	VB2 = if is_pid(VCR)-> <<VB/binary,Body/binary>>; true-> VB end,
	{noreply, State#st{u2sip= <<U2Sip/binary,Body/binary>>,vcr_buf=VB2}};
handle_audio_frame(#audio_frame{codec=?CN}, #st{webcodec=pcmu,u2sip=U2Sip,noise=Noise}=State) ->
	Body=get_random_160s(Noise),
	{noreply, State#st{u2sip= <<U2Sip/binary,Body/binary>>}};
handle_audio_frame(#audio_frame{}=Frame,State) ->
	llog("rrp unexcept audio_frame ~p.~n",[Frame]),
	{noreply, State}.
	

erl_cng_xenc(CNGE,ND1,0) ->
	case erl_cng:xenc(CNGE,ND1,0) of
		{0,<<>>} -> ok;
		{0,Sid} -> llog("~p cng unexpected out ~p",[self(),Sid])
	end,
	{0,<<>>}.

ilbc_dec_pkgs(Ilbc, Body, Out) when size(Body) >= ?ILBCFRAMESIZE ->
	<<F1:?ILBCFRAMESIZE/binary,Rest/binary>> = Body,
	{0,Adec} = erl_ilbc:xdec(Ilbc,F1),
	ilbc_dec_pkgs(Ilbc,Rest,<<Out/binary,Adec/binary>>);
ilbc_dec_pkgs(_,_,Out) ->
	Out.

ilbc_enc60(Ilbc,<<F1:480/binary,F2:480/binary>>) ->
	{0,Aenc1} = erl_ilbc:xenc(Ilbc,F1),
	{0,Aenc2} = erl_ilbc:xenc(Ilbc,F2),
	<<Aenc1/binary,Aenc2/binary>>.
	
% ----------------------------------
%
flush_msg(Msg) ->
	%% receive Msg -> flush_msg(Msg)
	%% after 0 -> ok
	%% end.
	pass.

mkvfn(Name) ->
	{_,Mo,D} = date(),
	{H,M,S} = time(),
	Name++"_"++xt:int2(Mo)
			 ++xt:int2(D)
			 ++"_"
			 ++xt:int2(H)
			 ++xt:int2(M)
			 ++xt:int2(S).

llog(F,P) ->
	case whereis(llog) of
		undefined -> 
		    llog:start(),
		    llog ! {self(),F,P};
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

compress_voice(pcmu,BodyL) ->
	Enc = erl_isac_nb:uenc(BodyL),
	{?PCMU,Enc};
compress_voice({g729,Ctx},BodyL) ->
	{0,2,Enc} = erl_g729:xenc(Ctx,BodyL),
	{?G729,Enc}.

uncompress_voice(pcmu,?PCMU,BodyU) ->
    BodyL = erl_isac_nb:udec(BodyU),
	BodyL;
uncompress_voice({g729,Ctx},?G729,Body) when size(Body)==2 ->
	{0,<<Body1:160/binary,_/binary>>} = erl_g729:xdec(Ctx,Body),
	{0,<<Body2:160/binary,_/binary>>} = erl_g729:xdec(Ctx,Body),
	<<Body1/binary,Body2/binary>>;
uncompress_voice({g729,Ctx},?G729,Body) ->
	{0,BodyL} = erl_g729:xdec(Ctx,Body),
	BodyL.

zero_pcm16(Freq,Time) ->
	Samples = Time * Freq div 1000,
	list_to_binary(lists:duplicate(Samples*2,0)).

shift_for_real_ts(PCM16,Samples) ->
	Bytes = size(PCM16),
	if Bytes=<Samples*2 ->
		PCM16;		% time passed, recovery is not needed
	true ->
		{_,Out} = split_binary(PCM16,Bytes-Samples*2),
		Out
	end.

generate_noise_nb(CNGD,Samples,Noise) when Samples=<640 ->
	{0,NN} = erl_cng:xgen(CNGD,Samples),
	<<Noise/binary,NN/binary>>;
generate_noise_nb(CNGD,Samples,Noise) ->
	{0,NN} = erl_cng:xgen(CNGD,640),
	generate_noise_nb(CNGD,Samples-640,<<Noise/binary,NN/binary>>).

get_nearest_samples(0,Freq,Dura,Passed) ->
	Samples = Freq*Dura div 1000,
	get_nearest_samples(0,Samples*2,Passed).

get_nearest_samples(Jump,Bytes,PCM16) when size(PCM16)==Bytes ->
	{Jump,PCM16};
get_nearest_samples(Jump,Bytes,PCM16) ->
	<<_:Bytes/binary,Rest/binary>> =PCM16,
	get_nearest_samples(Jump+1,Bytes,Rest).

shift_to_voice_keep_get_samples(Vad,Freq,Dura,PrevAB,AB) ->
    KeepSize = ?V29BUFLEN * (Freq div 1000) * 2,
    Samples = Freq * Dura div 1000,
    Bytes30ms = 2*Freq*30 div 1000,
    Bytes10ms = 2*Freq*10 div 1000,
	if
	   size(AB) > Samples*2+Bytes30ms+KeepSize ->
	    {F10ms,Rest} = split_binary(AB,Bytes10ms),
	    case voice_type(Freq,Vad,F10ms) of
			unactive ->
				shift_to_voice_keep_get_samples(Vad,Freq,Dura,PrevAB,Rest);		% just drop noise left previousAB to be unchanged
			actived ->
				get_voice_samples(Vad,Freq,Samples*2,PrevAB,AB)
	    end;
	   size(AB) < KeepSize ->
	        {{voice, PrevAB},AB};
    true ->
		  get_samples2(Vad,Freq,Samples*2,PrevAB,AB)
	end.


shift_to_voice_and_get_samples(Vad,Freq,Dura,PrevAB,AB) ->
    Samples = Freq * Dura div 1000,
    Bytes10ms = 2*Freq*10 div 1000,
	if size(AB)>Samples*2+Bytes10ms ->
	    {F10ms,Rest} = split_binary(AB,Bytes10ms),
	    case voice_type(Freq,Vad,F10ms) of
			unactive ->
				shift_to_voice_and_get_samples(Vad,Freq,Dura,PrevAB,Rest);		% just drop noise left previousAB to be unchanged
			actived ->
				get_voice_samples(Vad,Freq,Samples*2,PrevAB,AB)
	    end;
    true ->
		  get_samples2(Vad,Freq,Samples*2,PrevAB,AB)
	end.

get_samples(VAD,Freq,Dura,Passed,AB) ->
	get_samples2(VAD,Freq,(Freq*Dura div 1000)*2,Passed,AB).

get_samples2(Vad,Freq,Bytes,_Prev,AB) when size(AB)>=Bytes ->
	{Outp,Rest} = split_binary(AB,Bytes),
	case voice_type(Freq,Vad,Outp) of
		actived ->  {{voice,Outp},Rest};
		unactive -> {{noise,Outp},Rest}
	end;
get_samples2(Vad,Freq,Bytes,PrevAB,AB) -> % size(AB)<Bytes
	{_,Patch} = split_binary(PrevAB,size(PrevAB)-(Bytes-size(AB))),
	case voice_type(Freq,Vad,<<Patch/binary,AB/binary>>) of
		actived ->  {{voice,<<Patch/binary,AB/binary>>},<<>>};
		unactive -> {{noise,<<Patch/binary,AB/binary>>},<<>>}
	end.

get_voice_samples(_Vad,_Freq,Bytes,_Prev,AB) when size(AB)>=Bytes ->
	{Outp,Rest} = split_binary(AB,Bytes),
	{{voice,Outp},Rest};
get_voice_samples(_Vad,_Freq,Bytes,PrevAB,AB) -> % size(AB)<Bytes
	{_,Patch} = split_binary(PrevAB,size(PrevAB)-(Bytes-size(AB))),
	{{voice,<<Patch/binary,AB/binary>>},<<>>}.

voice_type(?FS8K,Vad,PCM16) when size(PCM16)==160 ->	% 8Khz 10ms 80samples, PCMU
	case erl_vad:xprcs(Vad,PCM16,?FS8K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==320 ->	% 8Khz 20ms 160samples, PCMU
	case erl_vad:xprcs(Vad,PCM16,?FS8K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==480 ->	% 8Khz 30ms 240samples, iLBC
	case erl_vad:xprcs(Vad,PCM16,?FS8K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==960 ->	% 8Khz 30ms 480samples, iLBC
	<<D1:480/binary,D2/binary>> = PCM16,
	case erl_vad:xprcs(Vad,D1,?FS8K) of
		{0,0} ->
			case erl_vad:xprcs(Vad,D2,?FS8K) of
				{0,0} -> unactive;
				{0,1} -> actived
			end;
		{0,1} -> actived
	end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==320 ->	% 16Khz 10ms 80samples, iSAC & u16K
	case erl_vad:xprcs(Vad,PCM16,?FS16K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==640 ->	% 16Khz 20ms 160samples, u16K
	case erl_vad:xprcs(Vad,PCM16,?FS16K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==960 ->	% 16Khz 30ms 240samples, iSAC
	case erl_vad:xprcs(Vad,PCM16,?FS16K) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==1920 ->	% 16Khz 60ms 480samples, iSAC
	<<D1:960/binary,D2/binary>> = PCM16,
	case erl_vad:xprcs(Vad,D1,?FS16K) of
		{0,0} ->
			case erl_vad:xprcs(Vad,D2,?FS16K) of
				{0,0} -> unactive;
				{0,1} -> actived
			end;
		{0,1} -> actived
	end;
voice_type(_,_,_) ->
	actived.
%
% ----------------------------------
%% Compose one RTP-packet from whole Data
%
compose_rtp(#base_rtp{seq = Sequence, marker = Marker,
                      packets = Packets, bytes = Bytes} = Base, Codec, Data) ->
	if Marker -> M = 1; true -> M = 0 end,
	Pack = make_rtp_pack(Base, M, Codec, Data),
	NewSeq = inc_seq(Sequence),
	{Base#base_rtp{codec = Codec,
				   seq = NewSeq,
				   packets = inc_packets(Packets, 1),
				   bytes = inc_bytes(Bytes, size(Pack))}, Pack}.

make_rtp_pack(#base_rtp{seq = Sequence,
                        timecode = Timestamp,
                        ssrc = SSRC}, Marker, PayloadType, Payload) ->
  Version = 2,
  Padding = 0,
  Extension = 0,
  CSRC = 0,
  <<Version:2, Padding:1, Extension:1, CSRC:4, Marker:1, PayloadType:7, Sequence:16, Timestamp:32, SSRC:32, Payload/binary>>.


init_rnd_seq() ->
  random:uniform(16#FF).	% star with a small number
  
init_rnd_ssrc() ->
  random:uniform(16#FFFFFFFF).

init_rnd_timecode() ->
  Range = 1000000000,
  random:uniform(Range) + Range.

inc_timecode(#base_rtp{wall_clock = _WC,
                       timecode = TC} = State,Inc) ->
  NewWC = now(),
  NewTC = TC + Inc,
  State#base_rtp{timecode = NewTC, wall_clock = NewWC}.

inc_seq(S) ->
	(S+1) band 16#FFFF.

inc_packets(S, V) ->
  (S+V) band 16#FFFFFFFF.

inc_bytes(S, V) ->
  (S+V) band 16#FFFFFFFF.

get_random_160s(Noise) ->
	Rndm = random:uniform(8000 - 160),
	<<_:Rndm/binary,O160:160/binary,_/binary>> = Noise,
	O160.

processSPE(#ev{step=init,nu=Nu,vol=Vol}=SPEv) ->
	{SPEv#ev{step=tone,tcount=?PT160*2},true,?PT160,<<Nu:8,0:1,0:1,Vol:6,?PT160:16>>};
processSPE(#ev{step=tone,tcount=TC,nu=Nu,vol=Vol,dura=Dura}=SPEv) when Dura>TC ->
	{SPEv#ev{tcount=TC+?PT160},false,0,<<Nu:8,0:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=tone,tcount=TC,nu=Nu,vol=Vol,dura=Dura}=SPEv) when Dura=<TC ->
	{SPEv#ev{step=gap,gcount=1},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol}=SPEv) when GC<3 ->
	{SPEv#ev{gcount=GC+1},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol,queue=[]}=SPEv) when GC>=3 ->
	{SPEv#ev{actived=false},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol,queue=[{Nu2,Vol2,Dura}|QT]}=SPEv) when GC>=3 ->
	{SPEv#ev{step=init,nu=Nu2,vol=Vol2,dura=Dura,queue=QT},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>}.
	
processRPE(#ev{actived=false},_,_,true, <<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->
	#ev{actived=true,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=false},_,_,false,<<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->	% no mark with valid info, just accepted it
	#ev{actived=true,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=false}=RPEv,_,_,_,_Info) ->	% error parameters or end_flag set.
	RPEv;
processRPE(#ev{actived=true,nu=Nu}=RPEv,{_,TS},{_,TS},false,<<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->
	RPEv#ev{vol=Volume,dura=Dura};
processRPE(#ev{actived=true,nu=Nu}=RPEv,{_,TS},{_,TS},false,<<0:4,Nu:4,1:1,_IsRsv:1,Volume:6,Dura:16>>) ->
	llog("dtmf ~p detected.",[Nu]),
	RPEv#ev{actived=false,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=true,nu=Nu1},_,_,_,<<0:4,Nu2:4,0:1,_IsRsv:1,Volume:6,Dura:16>>)
		   when Nu1=/=Nu2 ->	% all end_flag lost.
	llog("dtmf ~p dailed.",[Nu1]),
	#ev{actived=true,nu=Nu2,vol=Volume,dura=Dura};
processRPE(Ev,_,_,_,Info)->	% not handled
%	llog("dtmf packet unhandled EV:~p  Info:~p~n.",[Ev, Info]),
	Ev.

processVCR(VCR,Vbuf,PCM) when is_pid(VCR),size(Vbuf)>=320 ->
	{Sig1,Rest}=split_binary(Vbuf,320),
	{0,Sum} = erl_amix:phn(Sig1,PCM),
	VCR ! #audio_frame{codec=?LINEAR,body=Sum,samples=?PSIZE},
	{ok,Rest};
processVCR(VCR,Vbuf,PCM) when is_pid(VCR) ->
	VCR ! #audio_frame{codec=?LINEAR,body=PCM,samples=?PSIZE},
	{ok,Vbuf};
processVCR(_,_,_) ->
	{ok,<<>>}.

% ----------------------------------

rrp_get_web_codec(isac) ->
	{0,Isac} = erl_isac_nb:icdc(0,15000,960),	%% bitrate=15kbits
	{0,VAD} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD,?VADMODE),				%% aggresive mode
	{0,VAD2} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD2,?VADMODE),			%% to SS-MG9000 there is no CNG. vad is used for noise duration compress
	{0,CNGE} = erl_cng:ienc(?FS16K,100,8), 		%% 16Khz 100ms 8-byte Sid
	{0,CNGD} = erl_cng:idec(),
	{isac,Isac,VAD,VAD2,{CNGE,CNGD}};
rrp_get_web_codec(ilbc) ->
	{0,Ilbc} = erl_ilbc:icdc(?ILBCPTIME),
	{0,VAD} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD,?VADMODE),				%% aggresive mode
	{0,VAD2} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD2,?VADMODE),			%% to SS-MG9000 there is no CNG. vad is used for noise duration compress
	{0,CNGE} = erl_cng:ienc(?FS8K,100,8), 		%% 16Khz 100ms 8-byte Sid
	{0,CNGD} = erl_cng:idec(),
	{ilbc,Ilbc,VAD,VAD2,{CNGE,CNGD}};
rrp_get_web_codec(opus) ->
	{0,Opus} = erl_opus:icdc(8000,5),			%% bitrate=1000
	{0,VAD} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD,?VADMODE),				%% aggresive mode
	{0,VAD2} = erl_vad:ivad(),
	0 = erl_vad:xset(VAD2,?VADMODE),			%% to SS-MG9000 there is no CNG. vad is used for noise duration compress
	{0,CNGE} = erl_cng:ienc(?FS8K,100,8), 		%% 8Khz 100ms 8-byte Sid
	{0,CNGD} = erl_cng:idec(),
	{opus,Opus,VAD,VAD2,{CNGE,CNGD}}.

rrp_release_codec(undefined) ->
	ok;
rrp_release_codec({WebCdc,SipCdc}) ->
	rrp_release_codec2(WebCdc),
	rrp_release_codec2(SipCdc),
	ok.


rrp_release_codec2(pcmu) ->
	pass;
rrp_release_codec2({g729,Ctx}) ->
	0 = erl_g729:xdtr(Ctx);
rrp_release_codec2({isac,Isac,VAD,VAD2,{CNGE,CNGD}}) ->
	0 = erl_isac_nb:xdtr(Isac),
	0 = erl_vad:xdtr(VAD),
	0 = erl_vad:xdtr(VAD2),
	0 = erl_cng:xdtr(CNGE,0),
	0 = erl_cng:xdtr(CNGD,1);
rrp_release_codec2({ilbc,Ilbc,VAD,VAD2,{CNGE,CNGD}}) ->
	0 = erl_ilbc:xdtr(Ilbc),
	0 = erl_vad:xdtr(VAD),
	0 = erl_vad:xdtr(VAD2),
	0 = erl_cng:xdtr(CNGE,0),
	0 = erl_cng:xdtr(CNGD,1);
rrp_release_codec2({opus,Opus,VAD,VAD2,{CNGE,CNGD}}) ->
	0 = erl_opus:xdtr(Opus),
	0 = erl_vad:xdtr(VAD),
	0 = erl_vad:xdtr(VAD2),
	0 = erl_cng:xdtr(CNGE,0),
	0 = erl_cng:xdtr(CNGD,1).

rrp_get_sip_codec() ->
	case avscfg:get(sip_codec) of
		pcmu -> pcmu;
		g729 ->
			{0,Ctx} = erl_g729:icdc(),
			{g729,Ctx}
	end.

start(Session, Codec) ->
	{SS_BEGIN_UDP_RANGE,_} = avscfg:get(ss_udp_range),
	{Port,Socket} = try_port(SS_BEGIN_UDP_RANGE),
	{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Codec,no_vcr],[]),
	gen_udp:controlling_process(Socket, Pid),
	{ok,Pid,Port}.

stop(RRP) ->
	my_server:call(RRP,stop).

set_peer_addr(RrpPid, Addr) ->
    my_server:call(RrpPid,{options,Addr}).
	
try_port(Port) ->
    {ok,IP4sip} = inet:parse_address(avscfg:get(sip_socket_ip)),
	case gen_udp:open(Port, [binary, {active, true},{ip,IP4sip}, {recbuf, 4096}]) of
		{ok, Socket} ->
			{Port,Socket};
		{error, _} ->
			try_port(Port + 2)
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
