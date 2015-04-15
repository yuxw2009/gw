-module(lr_switch).
-compile(export_all).

-include("desc.hrl").

-define(iSAC,103).
-define(iCNG,105).
-define(OPUS,111).
-define(oCNG,107).
-define(LOSTiSAC,1003).
-define(VP8,100).
-define(RED,101).
-define(FEC,102).

-define(DBITRATE,300).
-define(VWIDTH,640).
-define(VHEIGHT,480).

-define(AUDIOFS,16000).

-record(vd_st,{
	locked,
	expid,
	w_h,
	samples,
	tmpframe,
	ctx
}).

-record(ve_st,{
	n = 0,
	flags,
	level = {0,2,1,2},
	base_tc,
	last_tc,
	last_ts = 0,
	ctx
}).

-record(st, {
	icdc,
	peer,
	ms,
	limit=0,
	acdc,
	avad,
	acng,
	abuf = <<>>,
	noise_deep = 0,
	noise_dur = 0,
	noise_data,
	aengst,
	venc,
	vdec,
	vp,
	vbuf,
	bytes,
	fh0,
	fh,
	fpos
}).

init([[RTP1,RTP2]]) ->
	{0,ECtx,TFlags,_} = erl_vp8:ienc(?VWIDTH,?VHEIGHT,?DBITRATE),
	{Mega,Sec,Micro} = now(),
	BaseTC = {Mega,Sec,0},
	LastTC = {Mega,Sec,meeting_room:minisec(Micro)},
	Venc = #ve_st{n=0,ctx=ECtx,flags=TFlags,base_tc=BaseTC,last_tc=LastTC,last_ts=0},
	{0,DCtx} = erl_vp8:idec(),
	Vdec = #vd_st{locked=false,expid=0,w_h={?VWIDTH,?VHEIGHT},samples=0,tmpframe= <<>>,ctx=DCtx},
	timer:send_interval(1000,estimate_bw),
	{0,Isac} = erl_isac_nb:icdc(0,10000,960),
	{0,Opus} = erl_opus:icdc(16000,2, 2049,60),
	erl_opus:enc_ctl(Opus),
	{ok,FH0} = file:open("rec0.pcm", [write,raw,binary]),
	{ok,FH} = file:open("rec1.pcm", [write,raw,binary]),
	{0,Vad} = erl_vad:ivad(),
	0 = erl_vad:xset(Vad,2),
	{0,CNGE} = erl_cng:ienc(16000,100,8), %% 16Khz 100ms 8-byte Sid
	{0,CNGD} = erl_cng:idec(),
%	timer:send_interval(30,play_audio),
	{ok,#st{peer={RTP1,RTP2},venc=Venc,vdec=Vdec,icdc=Opus,
			acdc=Isac,avad=Vad,acng={CNGE,CNGD},
			aengst = voice,noise_data=list_to_binary(lists:duplicate(1920,0)),
			vp=1,vbuf=[],bytes=0,fh=FH,fh0=FH0,fpos=0}}.

handle_info(#audio_frame{content=lost_vp8},ST) ->
	{noreply,ST};
handle_info(#audio_frame{owner=Owner,codec=?LOSTiSAC}=VF,
			#st{peer=Peer,acdc=Isac,fh=FH,fpos=FPos}=ST) ->
	{0, Adec} = erl_isac_nb:xplc(Isac,960),
	Pos = FPos + size(Adec),
	{0,_,Aenc} = erl_isac_nb:xenc(Isac,Adec),
%	peerof(Owner,Peer) ! VF#audio_frame{body=Aenc,samples=960},
	{noreply,ST#st{fpos=Pos}};
handle_info(#audio_frame{owner=Owner,codec=?iSAC,body=Body,samples=Samples}=VF,
			#st{peer=Peer,bytes=Bytes,acdc=Isac,avad=Vad,abuf=AB,fh=FH,fpos=FPos}=ST) ->
	To = peerof(Owner,ST#st.peer),
    To ! VF,
%	{0, Adec} = erl_isac_nb:xdec(Isac,Body,960,Samples),
%	Pos = FPos + size(Adec),
	{noreply,ST#st{ms=Owner}};
handle_info(#audio_frame{owner=Owner,codec=?OPUS,body=Body,samples=Samples}=VF,
			#st{peer=Peer,bytes=Bytes,acdc=Isac,avad=Vad,abuf=AB,fh=FH,fh0=FH0,fpos=FPos,icdc=Opus}=ST) ->
	To = peerof(Owner,ST#st.peer),
    To ! VF,
    Len=size(Body),
    file:write(FH0, <<Len:32>>),
	ok = file:write(FH0, Body),
	S = 960*6,
	{Retcode, Adec} = erl_opus:xdec(Opus,Body,S),
	if
		Retcode > 0 ->
		    <<Payload:Retcode/binary, _/binary>> = Adec,
  		    ok = file:write(FH, Payload);
  		true-> void
	end,
	io:format("opus ~p dec: Retcode:~p opus len:~p samples:~p~n",[Opus, Retcode, size(Body), Samples]),
%	Pos = FPos + size(Adec),
%    self() ! play_audio,
	{noreply,ST#st{ms=Owner,bytes=Bytes+size(Body)}};
handle_info(#audio_frame{owner=Owner,codec=?oCNG,body=Body,samples=Samples}=VF,
			#st{peer=Peer,acng={_,CNGD},abuf=AB,bytes=Bytes}=ST) ->
%	0 = erl_cng:xupd(CNGD,Body),
%	Noise = generate_noise(CNGD,Samples,<<>>),
	To = peerof(Owner,ST#st.peer),
    To ! VF,
%	ok = file:write(FH, Body),
	{noreply,ST#st{ms=Owner,bytes=Bytes+size(Body)}};
handle_info(#audio_frame{owner=Owner,codec=?iCNG,body=Body,samples=Samples}=VF,
			#st{peer=Peer,acng={_,CNGD},abuf=AB,bytes=Bytes}=ST) ->
	0 = erl_cng:xupd(CNGD,Body),
	Noise = generate_noise(CNGD,Samples,<<>>),
	{noreply,ST#st{abuf= <<AB/binary,Noise/binary>>,ms=Owner,bytes=Bytes+size(Body)}};
handle_info(play_audio,#st{aengst=voice,noise_deep=0}=ST) ->
	{noreply,ST#st{noise_deep=-1}};
handle_info(play_audio,#st{ms=Owner,abuf=AB,aengst=voice,noise_deep=-1,avad=Vad,acdc=Isac,acng={CNGE,_}}=ST) ->
	To = peerof(Owner,ST#st.peer),
	case get_samples(Vad,'60ms',ST#st.noise_data,AB) of
		{{voice,F1},RestAB} ->
			{0,_,Aenc} = erl_isac_nb:xenc(Isac,F1),
			To ! #audio_frame{codec=?iSAC,marker=false,body=Aenc,samples=960},
			{noreply,ST#st{abuf=RestAB,noise_deep=0,noise_data=F1}};
		{{noise,<<ND1:960/binary,ND2/binary>>},RestAB} ->
			{0,_} = erl_cng:xenc(CNGE,ND1,0),
			{0,Asid} = erl_cng:xenc(CNGE,ND2,1),
			To ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=960},
			{noreply,ST#st{abuf=RestAB,aengst=noise,noise_deep=1,noise_dur=0,noise_data=ND2}}
	end;
%handle_info(play_audio,#st{ms=Owner,abuf=AB,aengst=voice,noise_deep=-1,avad=Vad,acdc=Isac,acng={CNGE,_}}=ST) ->
%	To = peerof(Owner,ST#st.peer),
%	case get_samples(Vad,'60ms',ST#st.noise_data,AB) of
%		{{voice,F1},RestAB} ->
%			{0,_,Aenc} = erl_isac_nb:xenc(Isac,F1),
%			To ! #audio_frame{codec=?iSAC,marker=false,body=Aenc,samples=960},
%			{noreply,ST#st{abuf=RestAB,noise_deep=0,noise_data=F1}};
%		{{noise,<<ND1:960/binary,ND2/binary>>},RestAB} ->
%			{0,_} = erl_cng:xenc(CNGE,ND1,0),
%			{0,Asid} = erl_cng:xenc(CNGE,ND2,1),
%			To ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=960},
%			{noreply,ST#st{abuf=RestAB,aengst=noise,noise_deep=1,noise_dur=0,noise_data=ND2}}
%	end;
handle_info(play_audio,#st{ms=Owner,abuf=AB,aengst=noise,noise_deep=NDeep}=ST) when NDeep>0 ->
	#st{avad=Vad,acdc=Isac,acng={CNGE,_}} = ST,
	To = peerof(Owner,ST#st.peer),
	case shift_to_voice_and_get_samples(Vad,'30ms',ST#st.noise_data,AB) of
		{{voice,F1},RestAB} ->
			{Interval,F2} = get_last_30ms_noise(0,ST#st.noise_data),
			{0,_,Aenc} = erl_isac_nb:xenc(Isac,<<F2/binary,F1/binary>>),
			To ! #audio_frame{codec=?iSAC,marker=true,body=Aenc,samples=(Interval+1)*480},
			{noreply,ST#st{abuf=RestAB,aengst=voice,noise_deep=0,noise_data= <<F2/binary,F1/binary>>}};
		{{noise,F1},RestAB} ->
			#st{noise_dur=NDur,noise_data=NData}=ST,
			if NDeep==1;NDeep==2 ->
				if NDur==0;NDur==1 ->
					{noreply,ST#st{abuf=RestAB,noise_dur=NDur+1,noise_data= <<NData/binary,F1/binary>>}};
				true ->
					<<_:960/binary,ND1:960/binary,ND2/binary>> =NData,
					{0,_} = erl_cng:xenc(CNGE,ND1,0),
					{0,_} = erl_cng:xenc(CNGE,ND2,0),
					{0,Asid} = erl_cng:xenc(CNGE,F1, 1),
					To ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=1440},
					{noreply,ST#st{abuf=RestAB,noise_deep=NDeep+1,noise_dur=0,noise_data=F1}}
				end;
			true ->		% NDeep==3
				if NDur==0;NDur==1;NDur==2 ->
					{noreply,ST#st{abuf=RestAB,noise_dur=NDur+1,noise_data= <<NData/binary,F1/binary>>}};
				true ->
					<<_:960/binary,ND1:960/binary,ND2:960/binary,ND3/binary>> =NData,
					{0,_} = erl_cng:xenc(CNGE,ND1,0),
					{0,_} = erl_cng:xenc(CNGE,ND2,0),
					{0,_} = erl_cng:xenc(CNGE,ND3,0),
					{0,Asid} = erl_cng:xenc(CNGE,F1, 1),
					To ! #audio_frame{codec=?iCNG,marker=false,body=Asid,samples=1920},
					{noreply,ST#st{abuf=RestAB,noise_deep=1,noise_dur=0,noise_data=F1}}
				end
			end
	end;

handle_info(#audio_frame{owner=Owner,codec=?VP8,body=Body}=VF, #st{peer=Peer,vbuf=VB,vdec=VDec,bytes=Bytes}=ST) ->
	VDec = ST#st.vdec,
	DCtx = VDec#vd_st.ctx,
	{NewVB,NewVDec} = case meeting_room:repackVP8(VF,VDec) of
			{null, NewCdc} ->
				{VB,NewCdc};
			{drop,_} ->
				Owner ! {send_pli,self(),video},
				{VB,VDec};
			{{Samples,Rsult,NewV}, NewCdc} ->
				YV12 = meeting_room:safe_vp8dec(DCtx,NewV,Rsult,{?VWIDTH,?VHEIGHT}),
				self() ! send_frame,
				{VB++[{peerof(Owner,Peer),Samples,{?VWIDTH,?VHEIGHT},YV12}],NewCdc}
			end,
	{noreply,ST#st{vbuf=NewVB,vdec=NewVDec,ms=Owner,bytes=Bytes+size(Body)}};
handle_info(send_frame, #st{venc=VEnc,vp=VP,vbuf=[{To,Samples,_,YV12}|VBT],limit=Limit}=ST) ->
	{Key,Level,_TC,EncDat,NewVEnc} = meeting_room:encVP8(false,{?VWIDTH,?VHEIGHT},Samples,YV12,VEnc),
	To ! {leVeled_vp8,Key,Level,EncDat},
	{noreply,ST#st{venc=NewVEnc,vp=VP+1,vbuf=VBT}};
handle_info({rtp_bin,From,_}=Msg, #st{peer=Peer}=ST) ->
	peerof(From,Peer) ! Msg,
	{noreply,ST};
handle_info({rtcp_rec,From,_,_}=Msg, #st{peer=Peer}=ST) ->
	peerof(From,Peer) ! Msg,
	{noreply,ST};
handle_info(estimate_bw,#st{ms=MS,bytes=Bytes}=ST) when MS=/=undefined ->
%	if Bytes=/=0 -> io:format(" ~pkBs  ",[Bytes/1000]);
%	true -> pass end,
%	if Bytes<200000 -> MS ! {send_remb,self(),Bytes};
%	true -> MS ! {send_remb,self(),220000} end,
	{noreply,ST#st{bytes=0}};
handle_info(estimate_bw, ST) ->
	{noreply,ST};

handle_info(Msg, ST) ->
%	io:format("lr_switch unkn ~p.~n",[Msg]),
	{noreply,ST}.

handle_call({limit,L},_,ST) ->
	{reply,ok,ST#st{limit=L}}.
	
handle_cast(stop,#st{acdc=Isac,avad=Vad,acng={CNGE,CNGD},fh=FH}=ST) ->
	erl_isac_nb:xdtr(Isac),
	erl_vad:xdtr(Vad),
	erl_cng:xdtr(CNGE,0),
	erl_cng:xdtr(CNGD,1),
%	io:format("lr switch ~p stopped.~n",[ST]),
	file:close(FH),
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.
	
% ----------------------------------
send_leveled_video(_To,Limit,_,{_Key,Level,_,_}) when Level>Limit ->
	0;
send_leveled_video(To,Limit,VP,{Key,Level,TS,EncDat}) ->
	To ! {leVeled_vp8, Key, Level, EncDat},
	1.

peerof(undefined,{P1,_}) ->
	P1;
peerof(Me,{Me,You}) ->
	You;
peerof(Me,{You,Me}) ->
	You.

generate_noise(CNGD,Samples,Noise) when Samples=<640 ->
	{0,NN} = erl_cng:xgen(CNGD,Samples),
	<<Noise/binary,NN/binary>>;
generate_noise(CNGD,Samples,Noise) ->
	{0,NN} = erl_cng:xgen(CNGD,640),
	generate_noise(CNGD,Samples-640,<<Noise/binary,NN/binary>>).

get_last_30ms_noise(Jump,Noise) when size(Noise)==960 ->
	{Jump,Noise};
get_last_30ms_noise(Jump,<<_:960/binary,Noise/binary>>) ->
	get_last_30ms_noise(Jump+1,Noise).

shift_to_voice_and_get_samples(Vad,'30ms',PrevAB,AB) when size(AB)>960 ->
	{F10ms,Rest} = split_binary(AB,320),	% 10ms samples
	case voice_type(Vad,F10ms) of
		unactive ->
			shift_to_voice_and_get_samples(Vad,'30ms',PrevAB,Rest);		% just drop noise left previousAB to be unchanged
		actived ->
			get_samples(Vad,'30ms',PrevAB,AB)
	end;
shift_to_voice_and_get_samples(Vad,'30ms',PrevAB,AB) ->  % =< 480samples
	get_samples(Vad,'30ms',PrevAB,AB).

get_samples(Vad,'30ms',PrevAB,AB) ->
	get_samples2(Vad,960,PrevAB,AB);
get_samples(Vad,'60ms',PrevAB,AB) ->
	get_samples2(Vad,1920,PrevAB,AB).

get_samples2(Vad,Bytes,PrevAB,AB) when size(AB)>=Bytes ->
	{Outp,Rest} = split_binary(AB,Bytes),
	case voice_type(Vad,Outp) of
		actived ->  {{voice,Outp},Rest};
		unactive -> {{noise,Outp},Rest}
	end;
get_samples2(Vad,Bytes,PrevAB,AB) -> % size(AB)<Bytes
	{_,Patch} = split_binary(PrevAB,size(PrevAB)-(Bytes-size(AB))),
	case voice_type(Vad,<<Patch/binary,AB/binary>>) of
		actived ->  {{voice,<<Patch/binary,AB/binary>>},<<>>};
		unactive -> {{noise,<<Patch/binary,AB/binary>>},<<>>}
	end.

voice_type(Vad,PCM16) when size(PCM16)==320 ->
	case erl_vad:xprcs(Vad,PCM16,?AUDIOFS) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(Vad,PCM16) when size(PCM16)==960 ->
	case erl_vad:xprcs(Vad,PCM16,?AUDIOFS) of
		{0,0} -> unactive;
		{0,1} -> actived
	end;
voice_type(Vad,PCM16) when size(PCM16)==1920 ->
	<<D1:960/binary,D2/binary>> = PCM16,
	case erl_vad:xprcs(Vad,D1,?AUDIOFS) of
		{0,0} ->
			case erl_vad:xprcs(Vad,D2,?AUDIOFS) of
				{0,0} -> unactive;
				{0,1} -> actived
			end;
		{0,1} -> actived
	end.

% ----------------------------------
start([RTP1,RTP2]) ->
	{ok,Pid} = my_server:start({local,lr_switch},?MODULE,[[RTP1,RTP2]],[]),
	Pid.