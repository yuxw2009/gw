-module(videobuf).
-compile(export_all).

-include("erl_debug.hrl").
-define(CN,13).
-define(PCMU,0).
-define(VP8, 100).

-define(MAXRTPLEN, 1024).

-define(VWIDTH,640).
-define(VHEIGHT,480).
-define(DWIDTH,320).
-define(DHEIGHT,240).
-define(DBITRATE,50).
-define(TIMEDIFF,7).

-include("desc.hrl").

-record(st,{
	name,
	ortp,
	st_dec,	% FrameID,WxH,TimeCode,TmpFrame,Ctx
	st_enc,	% FrameNum,Ctx,Img_ctx
	force_key,
	cdr1,
	cdr2,
	vf,
	vp,
	vbuf,	% video frame buffer
	abuf,
	vtimer,
	atimer
}).

init([Name,no_record]) ->
	{0,DCtx} =  ?APPLY(erl_vp8, idec, []) ,
	{0,ECtx,_} =  ?APPLY(erl_vp8, ienc, [?DWIDTH,?DHEIGHT,?DBITRATE]) ,
%	Cdr1 = recorder:start("rec1_"++Name),
%	Cdr2 = recorder:start("rec2_"++Name),
	{ok,#st{name=Name,vbuf=[],st_enc={0,ECtx},st_dec={0,{?VWIDTH,?VHEIGHT},0,<<>>,DCtx},force_key=false}}.  %cdr1=Cdr1,cdr2=Cdr2,

handle_info({play,RTP}, #st{vtimer=TRef}=ST) ->
	if TRef=/=undefined -> timer:cancel(TRef),timer:cancel(ST#st.atimer);
	true -> pass end,
	{noreply,ST#st{ortp=RTP,vbuf=[],vtimer=undefined,abuf=[]}};
handle_info({stun_locked,_}, #st{vbuf=[]} = ST) ->
	timer:send_after(500,{stun_locked,again}),
	{noreply,ST};
handle_info({stun_locked,_}, #st{vbuf=[{TC,Rsult,Raw}|VT],st_enc=EncST} = ST) ->
	{ok,AR} = timer:send_interval(20,play_audio),
	io:format("stun locked."),
	VP = 1,	% first frame idx
	{_Key,EncDat,NewEncST} = encVP8(false,Rsult,Raw,EncST),
	VH = packetVP8(VP,1,TC,EncDat),
	{ok,VR} = timer:send_after(3,play_video),
	{noreply,ST#st{vp=VP+1,vf=VH,vbuf=VT,vtimer=VR,atimer=AR,st_enc=NewEncST}};
handle_info({send_sr,_From,_Type}, ST) ->
	{noreply,ST};	
handle_info({send_sr,_From,pli,_Params}, ST) ->
	{noreply,ST#st{force_key=false}};
handle_info(#audio_frame{codec=Codec}=VF,#st{vbuf=VB,st_dec=STDec,cdr1=Rcrdr}=ST) when Codec==?VP8 ->
%	Rcrdr ! VF,
	{NewVB,NewSTDec} = case repackVP8(VF,STDec) of
			{null, NewCdc} -> {VB,NewCdc};
			{{Samples,Rsult,NewV}, NewCdc} ->
				{_,_,_,_,DCtx} = STDec,
				0 =  ?APPLY(erl_vp8, xdec, [DCtx,NewV]) ,
				{0,YV12} =  ?APPLY(erl_vp8, gdec, [DCtx]) ,
				if length(VB)>2 -> io:format("drop ~p ",[length(VB)-1]),{[lists:last(VB),{Samples,Rsult,YV12}], NewCdc};
				true -> {VB++[{Samples,Rsult,YV12}],NewCdc} end
		end,
	{noreply,ST#st{vbuf=NewVB,st_dec=NewSTDec}};
handle_info(#audio_frame{codec=Codec}=AF,#st{abuf=AB}=ST) when Codec==?PCMU;Codec==?CN ->
	{noreply,ST#st{abuf=AB++[AF]}};
handle_info(play_audio,#st{abuf=[]}=ST) ->
	{noreply,ST};	%% may be comfortable noise
handle_info(play_audio,#st{ortp=ORTP,abuf=[H|T]}=ST) ->
	ORTP ! H,
	{noreply,ST#st{abuf=T}};
handle_info(play_video,#st{vbuf=[]}=ST) ->
	timer:send_after(10,play_video),
	{noreply,ST};
handle_info(play_video,#st{ortp=ORTP,vp=VP,vbuf=[{TC,Rsult,Raw}|VT],st_enc=EncST,force_key=true}=ST) ->
	timer:send_after(3,play_video),
	{Key,EncDat,NewEncST} = encVP8(true,Rsult,Raw,EncST),
	VK = packetVP8(VP-1,Key,TC,EncDat),
	{noreply,ST#st{vp=VP,vf=VK,vbuf=[{TC,Raw}|VT],st_enc=NewEncST,force_key=false}};
handle_info(play_video,#st{ortp=ORTP,vp=VP,vf=VF,vbuf=[{TC,Rsult,Raw}|VT],st_enc=EncST,force_key=false,cdr2=Cdr2}=ST) ->
	timer:send_after(trunc(TC/90)-?TIMEDIFF,play_video),
	ORTP ! VF,
	{Key,EncDat,NewEncST} = encVP8(false,Rsult,Raw,EncST),
	VH = packetVP8(VP,Key,TC,EncDat),
	{noreply,ST#st{vp=VP+1,vf=VH,vbuf=VT,st_enc=NewEncST}};
handle_info(Msg, ST) ->
	io:format("unkn ~p ~p  ",[Msg,ST#st.ortp]),
	{noreply,ST}.

handle_cast(stop,#st{name=Name,vbuf=VB,st_enc={_,ECtx},st_dec={_,_,_,_,DCtx},cdr1=Cdr1,cdr2=Cdr2}=ST) ->
	io:format("video buffer stopped at: ~n~p ~p~n",[length(ST#st.vbuf),length(ST#st.abuf)]),
%	recorder:stop(Cdr1),
%	recorder:stop(Cdr2),
	0 =  ?APPLY(erl_vp8, xdtr, [ECtx,0]) ,	% 0 for enc
	0 =  ?APPLY(erl_vp8, xdtr, [DCtx,1]) ,	% 1 for dec
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------
repackVP8(#audio_frame{marker=true,body= <<16#9080:16,_/binary>> =Body,samples=Samples},{ExptID,Rsult,TC,<<>>,DCtx}) ->
	{ID,VP8} = id_body(Body),
	NewRsult = case showsize(VP8) of
			undefined -> Rsult;
			{H,V} -> {H,V}
		end,
	if ID=/=ExptID -> io:format("single frame unmatched ID.~n~p ~p~n",[ExptID,ID]);
	true -> pass end,
	{{Samples,NewRsult,VP8}, {(ID+1) rem 16#8000,NewRsult,0,<<>>,DCtx}};
repackVP8(#audio_frame{marker=false,body= <<16#9080:16,_/binary>> =Body,samples=Samples},{ExptID,Rsult,TC,<<>>,DCtx}) ->
	{ID,VP8} = id_body(Body),
	NewRsult = case showsize(VP8) of
			undefined -> Rsult;
			{H,V} -> {H,V}
		end,
	if ID=/=ExptID -> io:format("first frame unmatched ID.~n~p ~p~n",[ExptID,ID]);
	true -> pass end,
	{null,{ID,NewRsult,Samples,VP8,DCtx}};
repackVP8(#audio_frame{marker=false,body= <<16#8080:16,_/binary>> =Body,samples=0},{ExptID,Rsult,TC,TmpFrame,DCtx}) ->
	{ID,VP8} = id_body(Body),
	if ID=/=ExptID ->
		io:format("middle frame unmatched ID.~n~p ~p~n",[ExptID,ID]),
		{null,{0,Rsult,0,<<>>,DCtx}};
	true ->
		{null,{ID,Rsult,TC,<<TmpFrame/binary,VP8/binary>>,DCtx}}
	end;
repackVP8(#audio_frame{marker=true,body= <<16#8080:16,_/binary>> =Body,samples=0},{ExptID,Rsult,TC,TmpFrame,DCtx}) when TmpFrame=/= <<>> ->
	{ID,VP8} = id_body(Body),
	if ID=/=ExptID ->
		io:format("last frame unmatched ID.~n~p ~p~n",[ExptID,ID]),
		{null,{0,Rsult,0,<<>>,DCtx}};
	true ->
		{{TC,Rsult,<<TmpFrame/binary,VP8/binary>>}, {(ID+1) rem 16#8000,Rsult,0,<<>>,DCtx}}
	end.

	
id_body(<<_:16,1:1,IDX:15,VP8/binary>>) ->
	{IDX,VP8};
id_body(<<_:16,0:1,IDX:7,VP8/binary>>) ->
	{IDX,VP8}.

showsize(<<Size0:3,1:1,0:3,P:1, Size1:8,Size2:8, 16#9D012A:24, Hp0:8,Hs:2,Hp1:6,Vp0:8,Vs:2,Vp1:6,_/binary>>) ->
	H = Hp1*256 + Hp0,
	V = Vp1*256 + Vp0,
	io:format("~p x ~p @ ~p,~p~n",[H,V,Hs,Vs]),
	{H,V};
showsize(_) ->
	undefined.

encVP8(ForceKey,{OW,OH},Raw,{N,Ctx}) ->
	Flags = if ForceKey -> 1; true -> 0 end,
	YUV = yv12_resample:cut_image({OW,OH},{?DWIDTH,?DHEIGHT},Raw),

	0 =  ?APPLY(erl_vp8, xenc, [Ctx,YUV,N,1,0]) ,
	{0,Key,EncDat} =  ?APPLY(erl_vp8, genc, [Ctx]) ,
	{Key,EncDat,{N+1,Ctx}}.

packetVP8(VN,_Key,TC,<<_Size:32/little,_N:64/little,VP8/binary>>) when size(VP8) =< ?MAXRTPLEN ->
	packet_single_VP8(VN,TC,VP8);
packetVP8(VN,_Key,TC,<<_Size:32/little,_N:64/little,VP8/binary>>) ->
	{F1,Fms,Fe} = split_VP8_4_rtp(VP8),
	lists:flatten([packet_first_VP8(VN,TC,F1),
				   packet_middle_VP8(VN,Fms),
				   packet_last_VP8(VN,Fe)]).

packet_single_VP8(IDX, TC, VP8) ->
	#audio_frame{marker=true,codec=?VP8, body = <<16#9080:16,1:1,IDX:15,VP8/binary>>,samples=TC}.
packet_first_VP8(IDX, TC, F1) ->
	#audio_frame{marker=false,codec=?VP8,body = <<16#9080:16,1:1,IDX:15,F1/binary>>,samples=TC}.
packet_middle_VP8(IDX,Fm) ->
	[#audio_frame{marker=false,codec=?VP8,body= <<16#8080:16, 1:1,IDX:15,X/binary>>, samples=0}||X<-Fm].
packet_last_VP8(IDX,Fe) ->
	#audio_frame{marker=true,codec=?VP8,  body= <<16#8080:16, 1:1,IDX:15,Fe/binary>>,samples=0}.

split_VP8_4_rtp(Frame) ->
	{F1,Fr} = split_binary(Frame,?MAXRTPLEN),
	split_VP8_4_rtp(F1,Fr,[]).
split_VP8_4_rtp(F1, Fr, Res) when size(Fr) =< ?MAXRTPLEN ->
	{F1,lists:reverse(Res),Fr};
split_VP8_4_rtp(F1,VP8, Res) ->
	{H, T} = split_binary(VP8, ?MAXRTPLEN),
	split_VP8_4_rtp(F1, T,[H|Res]).

frameOf(Bin) ->
	{_,Out} = split_binary(Bin,4),
	Out.
	
% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start(?MODULE,[Name,no_record],[]),
	Pid.
	
stop(Pid) ->
	my_server:cast(Pid,stop).