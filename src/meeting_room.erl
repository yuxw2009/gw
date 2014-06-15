-module(meeting_room).
-compile(export_all).

-define(CN,13).
-define(PCMU,0).
-define(VP8, 100).

-define(MAXRTPLEN, 1024).
-define(MAXIMGINBUF,5).

-define(MAXCHAIRS,4).
-define(VWIDTH,640).
-define(VHEIGHT,480).
-define(DWIDTH,320).
-define(DHEIGHT,240).
-define(DBITRATE,360).
-define(REMBW,256000).

-include("desc.hrl").

-record(strm,{
	ortp,
	ref,
	pli,	% browser pli
	locked,	% stun locked
	vdec,	% vdst record
	new_image,
	vbuf,	% video frame buffer
	abuf
}).

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

-record(st,{
	name,
	chairs,
	venc,	% FrameNum,Ctx
	force_key,
	vf,		% {no,<<vp8>>}
	noise,
	img_lock,
	has_vcr,
	vcr,
	atimer,
	usr		% in streams list
}).

init([Name,HasVCR]) ->
	{ok,Noise} = file:read_file("cn.pcm"),
	{ok,#st{name=Name,chairs=[],usr=[],noise=Noise,has_vcr=HasVCR,vcr=undefined}}.

handle_info({play,RTP}, #st{usr=Usr}=ST) ->
	{0,DCtx} = erl_vp8:idec(),
	llog("~p@~p get decoder ~p.",[RTP,ST#st.name,DCtx]),
	Ref = erlang:monitor(process,RTP),
	Vdec = #vd_st{locked=false,expid=0,w_h={?VWIDTH,?VHEIGHT},samples=0,tmpframe= <<>>,ctx=DCtx},
	NewUsr1 = #strm{ortp=RTP,ref=Ref,pli=true,locked=false,new_image=0,vbuf=[],abuf=[],vdec=Vdec},
	if Usr==[] -> self() ! init_vp8_encode;
	true -> pass end,
	{noreply,ST#st{usr=[NewUsr1|Usr]}};
handle_info({deplay,RTP},#st{usr=Usr}=ST) ->
	llog("user ~p@~p out.",[RTP,ST#st.name]),
	NewUsr = rm_user_vp8dec(RTP,Usr),
	if NewUsr==[] -> self() ! stop_vp8_encode;
	true -> pass end,
	{noreply,ST#st{usr=NewUsr}};
handle_info({'DOWN',_Ref,process,RTP,Reason},#st{usr=Usr}=ST) ->
	NewUsr = case lists:keysearch(RTP,#strm.ortp,Usr) of
			{value,_Usr1} ->
				llog("user ~p@~p down ~p.",[RTP,ST#st.name,Reason]),
				NU = rm_user_vp8dec(RTP,Usr),
				if NU==[] -> self() ! stop_vp8_encode;
				true -> pass end,
				NU;
			false ->
				Usr
		end,
	{noreply,ST#st{usr=NewUsr}};
handle_info({stun_locked,RTP}, #st{usr=Usr,chairs=Chairs}=ST) ->
	{value,Usr1} = lists:keysearch(RTP,#strm.ortp,Usr),
	RTP ! {send_remb,self(),?REMBW},
	llog("user ~p@~p actived.",[RTP,ST#st.name]),
	NewUsr = lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{locked=true}),
	case is_chairman(RTP,Chairs) of
		true -> {noreply,ST#st{img_lock=RTP,usr=NewUsr,vf={1,null}}};	% out stream begin after chairman rtp locked.
		false -> {noreply,ST#st{usr=NewUsr}}
	end;
handle_info({video_pli,RTP}, #st{usr=Usr}=ST) ->
	io:format("~p pli ",[RTP]),
	{value,Usr1} = lists:keysearch(RTP,#strm.ortp,Usr),
	{noreply,ST#st{usr=lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{pli=true})}};
handle_info(init_vp8_encode, #st{name=Name,has_vcr=HasVCR}=ST) ->
	{ok,AR} = my_timer:send_interval(20,play_audio),
	{0,ECtx,Flags,_} = erl_vp8:ienc(?VWIDTH,?VHEIGHT,?DBITRATE),
	{Mega,Sec,Micro} = now(),
	BaseTC = {Mega,Sec,0},
	LastTC = {Mega,Sec,minisec(Micro)},
	VEnc = #ve_st{n=0,ctx=ECtx,flags=Flags,base_tc=BaseTC,last_tc=LastTC,last_ts=0},
	llog("meeting room ~p get vp8 ~p.",[Name,ECtx]),
	VCR = if HasVCR==has_vcr -> vcr:start(mkvfn(Name)); true->undefined end,
	{noreply,ST#st{venc=VEnc,force_key=false,img_lock=undefined,atimer=AR,vcr=VCR}};
handle_info(stop_vp8_encode, #st{venc=#ve_st{ctx=ECtx,last_ts=PTS},atimer=AT}=ST) ->
	my_timer:cancel(AT),
	0 = erl_vp8:xenc(ECtx,<<>>,PTS,33,0),
	0 = erl_vp8:xdtr(ECtx,0),	% 0 for enc
	llog("meeting room ~p release vp8 ~p.",[ST#st.name,ECtx]),
	if is_pid(ST#st.vcr) -> vcr:stop(ST#st.vcr);
	true -> pass end,
	{noreply,ST#st{vcr=undefined,venc=undefined,atimer=undefined}};
%
handle_info({enter_meeting,{Chair,RTP}},#st{chairs=Chairs}=ST) ->
	NewChairs = lists:keysort(1,lists:keystore(Chair,1,Chairs,{Chair,RTP})),
	{noreply,ST#st{chairs=NewChairs}};
handle_info({leave_meeting,{all,_RTP}},ST) ->
	{noreply,ST#st{chairs=[]}};
handle_info({leave_meeting,{Chair,_RTP}},#st{chairs=Chairs}=ST) ->
	{noreply,ST#st{chairs=lists:keydelete(Chair,1,Chairs)}};
%
handle_info({send_sr,_From,_Type}, ST) ->
	{noreply,ST};	
handle_info({send_sr,_From,pli,_Params}, ST) ->
	{noreply,ST#st{force_key=false}};
%
handle_info(#audio_frame{codec=?VP8,owner=RTP}=VF,#st{img_lock=Imglock,usr=Usr}=ST) ->
	{value,Usr1} = lists:keysearch(RTP,#strm.ortp,Usr),
	VB = Usr1#strm.vbuf,
	VDec = Usr1#strm.vdec,
	DCtx = VDec#vd_st.ctx,
	{Imglock2,NewUsr} = case repackVP8(VF,VDec) of
			{null, NewCdc} ->
				{Imglock,lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{vdec=NewCdc})};
			{drop,_} ->
				RTP ! {send_pli,self(),video},
				ImgL2 = if RTP==Imglock -> find_imglock_but(RTP,Usr);
						true -> Imglock end,
				{ImgL2,Usr};
			{{Samples,Rsult,NewV}, NewCdc} ->
				Len = length(VB),
				YV12 = safe_vp8dec(DCtx,NewV,Rsult),
				if RTP==Imglock orelse Len>?MAXIMGINBUF ->
					self() ! {out_new_image,RTP},
					Usr2 = lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{new_image=1,
																		 vbuf=[{Samples,{?DWIDTH,?DHEIGHT},YV12}],
																		 vdec=NewCdc}),
					if RTP=/=Imglock -> llog("img lock change ~p to ~p~n",[Imglock,RTP]);
					true -> pass end,
					{RTP,dele_history_img(Usr2)};
				true ->
					NVB = if Len==1 andalso Usr1#strm.new_image==0 -> [];
						  true -> VB end,
					Usr2 = lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{new_image=1,
																		 vbuf=NVB++[{Samples,{?DWIDTH,?DHEIGHT},YV12}],
																		 vdec=NewCdc}),
					{Imglock,Usr2}
				end
			end,
	{noreply,ST#st{img_lock=Imglock2,usr=NewUsr}};
handle_info(#audio_frame{codec=Codec,owner=RTP}=AF,#st{usr=Usr}=ST) when Codec==?PCMU;Codec==?CN ->
	{value,Usr1} = lists:keysearch(RTP,#strm.ortp,Usr),
	SavedAudio = Usr1#strm.abuf,
	NewUsr = lists:keyreplace(RTP,#strm.ortp,Usr,Usr1#strm{abuf=SavedAudio++[AF]}),
	{noreply,ST#st{usr=NewUsr}};
%
%
handle_info({out_new_image,_},#st{vf=undefined}=ST) ->  % meeting cleared
	{noreply,ST};
handle_info({out_new_image,_},#st{img_lock=RTP,chairs=Chairs,vf={VP,_VH0},venc=VEnc,usr=Usr}=ST) ->
	case make_image_from_usr_ts(RTP,Chairs,Usr) of
		{0,_,_,_} ->
			{noreply,ST};
		{N,Ts,Bound,NewUsr} when N>0 ->
			{Key,Level,_TC,EncDat,NewVEnc} = encVP8(false,{?VWIDTH,?VHEIGHT},Ts,Bound,VEnc),
			VH = {leVeled_vp8,Key,Level,EncDat},
			send4vcr(ST#st.vcr,VH),
			NewUsr2 = send_users_video(NewUsr, VH),
			{noreply,ST#st{vf={VP+1,null},venc=NewVEnc,usr=NewUsr2}}
	end;
%
%
handle_info(play_audio,#st{usr=Usr,noise=Noise}=ST) ->
	{{All,AFs},NewUsr} = make_audio_from_usr(Usr,Noise),
	send_users_audio(Usr,AFs),
	send4vcr(ST#st.vcr,All),
	{noreply,ST#st{usr=NewUsr}};
handle_info(Msg, ST) ->
	io:format("conference unkn: ~p.~n",[Msg]),
	{noreply,ST}.

handle_call(get_info,_,ST) ->
	Us = [{RTP,Locked,Nimg,Vdec}||#strm{ortp=RTP,locked=Locked,new_image=Nimg,vdec=Vdec}<-ST#st.usr],
	{reply,{ST#st.vcr,Us,ST#st.chairs},ST}.

handle_cast(stop,#st{name=Name,venc=#ve_st{ctx=ECtx,last_ts=PTS},usr=Usr,atimer=AT}=ST) ->
	my_timer:cancel(AT),
	llog("video conference ~p stopped at: ~p users.",[Name,length(ST#st.usr)]),
	0 = erl_vp8:xenc(ECtx,<<>>,PTS,33,0),
	0 = erl_vp8:xdtr(ECtx,0),	% 0 for enc
	0 = destory_dec(0,Usr),
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

rm_user_vp8dec(RTP,Usr) ->
	{value,Usr1} = lists:keysearch(RTP,#strm.ortp,Usr),
	DCtx = (Usr1#strm.vdec)#vd_st.ctx,
	0 = erl_vp8:xdtr(DCtx,1),
	lists:keydelete(RTP,#strm.ortp,Usr).

safe_vp8dec(DCtx,NewV,Rsult) ->
	safe_vp8dec(DCtx,NewV,Rsult,{?DWIDTH,?DHEIGHT}).

safe_vp8dec(DCtx,NewV,Rsult,{DestW,DestH}) ->
	case erl_vp8:xdec(DCtx,NewV) of
		0 ->	% erl_vp8 return 0 for successful
			{0,Dat} = erl_vp8:gdec(DCtx),
			yv12_resample:scl_image(Rsult,{DestW,DestH},Dat);
		_ ->	% vp8 decode failure
			llog("vp8 decoder ~p error,empty frame created.",[DCtx]),
			RawSz = DestW * DestH * 3 div 2,
			list_to_binary(lists:duplicate(RawSz,0))
	end.

%
% ------------ package VP8 from rtp fragments -------
%
repackVP8(#audio_frame{marker=Marker,body=Body,samples=Samples},#vd_st{locked=false}=VDec) ->
	case {is_key_frame(Body),Marker} of
		{{ok,ID,Rsult,VP8},true} ->
			{{Samples,Rsult,VP8}, VDec#vd_st{locked=true,expid=(ID+1) rem 16#8000,w_h=Rsult,samples=0}};
		{{ok,ID,Rsult,VP8},false} ->	
			{null,VDec#vd_st{locked=true,expid=ID,w_h=Rsult,samples=Samples,tmpframe=VP8}};
		{no_key,_} ->
			{drop,VDec}
	end;
repackVP8(#audio_frame{marker=true,body= <<16#9080:16,_/binary>> =Body,samples=Samples},
		  #vd_st{expid=ExptID,w_h=Rsult,tmpframe= <<>>}=VDec) ->
	{ID,VP8} = id_body(Body),
	NewRsult = case showsize(VDec#vd_st.ctx,VP8) of
			undefined -> Rsult;
			{H,V} -> {H,V}
		end,
	{{Samples,NewRsult,VP8}, VDec#vd_st{expid=(ID+1) rem 16#8000,w_h=NewRsult,samples=0}};
repackVP8(#audio_frame{marker=false,body= <<16#9080:16,_/binary>> =Body,samples=Samples},
		  #vd_st{expid=ExptID,w_h=Rsult,tmpframe= <<>>}=VDec) ->
	{ID,VP8} = id_body(Body),
	NewRsult = case showsize(VDec#vd_st.ctx,VP8) of
			undefined -> Rsult;
			{H,V} -> {H,V}
		end,
	{null,VDec#vd_st{expid=ID,w_h=NewRsult,samples=Samples,tmpframe=VP8}};
repackVP8(#audio_frame{marker=false,body= <<16#8080:16,_/binary>> =Body,samples=0},
		  #vd_st{expid=ExptID,tmpframe=TmpFrame}=VDec) when TmpFrame=/= <<>> ->
	{ID,VP8} = id_body(Body),
	if ID=/=ExptID ->
		{null,VDec#vd_st{expid=0,samples=0,tmpframe= <<>>}};
	true ->
		{null,VDec#vd_st{tmpframe= <<TmpFrame/binary,VP8/binary>>}}
	end;
repackVP8(#audio_frame{marker=true,body= <<16#8080:16,_/binary>> =Body,samples=0},
		  #vd_st{expid=ExptID,w_h=Rsult,samples=TC,tmpframe=TmpFrame}=VDec) when TmpFrame=/= <<>> ->
	{ID,VP8} = id_body(Body),
	if ID=/=ExptID ->
		{null,VDec#vd_st{expid=0,samples=0,tmpframe= <<>>}};
	true ->
		{{TC,Rsult,<<TmpFrame/binary,VP8/binary>>},VDec#vd_st{expid=(ID+1) rem 16#8000,samples=0,tmpframe= <<>>}}
	end;
%
% error frame come in
repackVP8(#audio_frame{body= <<16#9080:16,_/binary>> =Body,samples=_Samples}=VF,
		  #vd_st{expid=ExptID,tmpframe=Remain}=VDec) when Remain=/= <<>> ->
	{ID,_} = id_body(Body),
	repackVP8(VF, VDec#vd_st{locked=false,tmpframe= <<>>});
repackVP8(#audio_frame{marker=_Mbit,body= <<16#8080:16,_/binary>> =Body,samples=Samples},VDec) when Samples =/= 0 ->
	{ID,_} = id_body(Body),
	{null, VDec#vd_st{locked=false,expid=0,samples=0,tmpframe= <<>>}};
repackVP8(#audio_frame{body= <<16#8080:16,_/binary>> =Body, samples=0},#vd_st{expid=ExptID,tmpframe= <<>>}=VDec)  ->
	{ID,_} = id_body(Body),
	{null,VDec#vd_st{locked=false,expid=0,samples=0,tmpframe= <<>>}};
repackVP8(#audio_frame{content=lost_vp8}, VDec) ->
	{null,VDec#vd_st{locked=false,expid=0,samples=0,tmpframe= <<>>}};
repackVP8(#audio_frame{body= <<Head:16,_/binary>>}=VF, VDec) when Head=/=16#9080 andalso Head=/=16#8080 ->
	llog("unknow vp8 frame ~p @ ~n~p",[VF,VDec]),
	{null,VDec}.

is_key_frame(<<16#9080:16,_/binary>> =Body) ->
	{ID,VP8} = id_body(Body),
	case showsize(ID,VP8) of
		undefined -> no_key;
		Rsult -> {ok,ID,Rsult,VP8}
	end;
is_key_frame(_) ->
	no_key.

id_body(<<_:16,1:1,IDX:15,VP8/binary>>) ->
	{IDX,VP8};
id_body(<<_:16,0:1,IDX:7,VP8/binary>>) ->
	{IDX,VP8}.

showsize(Ctx,<<_Size0:3,1:1,0:3,P:1, _Size1:8,_Size2:8, 16#9D012A:24, Hp0:8,Hs:2,Hp1:6,Vp0:8,Vs:2,Vp1:6,_/binary>>) ->
	H = Hp1*256 + Hp0,
	V = Vp1*256 + Vp0,
	io:format("(~p ~p) ~p x ~p @ ~p,~p~n",[Ctx,P,H,V,Hs,Vs]),
	{H,V};
showsize(_,_) ->
	undefined.

send4vcr(VCR,VF) when is_pid(VCR) ->
	VCR ! VF;
send4vcr(_,_) ->
	ok.

send_users_video(Usrs, null) ->
	Usrs;
send_users_video([], _) ->
	[];
send_users_video([#strm{locked=false}=U1|UT], AF) ->
	[U1|send_users_video(UT,AF)];
send_users_video([#strm{locked=true,pli=false,ortp=ORTP}=U1|UT],AF) ->
	ORTP ! AF,
	[U1|send_users_video(UT,AF)];
send_users_video([#strm{locked=true,pli=true,ortp=ORTP}=U1|UT],{leVeled_vp8,1,_,_}=AF) ->
	ORTP ! AF,
	[U1#strm{pli=false}|send_users_video(UT,AF)];
send_users_video([#strm{locked=true,pli=true}=U1|UT],{leVeled_vp8,0,_,_}=AF) ->
	[U1|send_users_video(UT,AF)].

send_users_audio([],[]) ->
	ok;
send_users_audio([#strm{ortp=ORTP}|Usr],[AF|AFs]) ->
	ORTP ! AF,
	send_users_audio(Usr,AFs).

make_audio_from_usr([],_) ->
	{{#audio_frame{codec=?PCMU,body= <<>>,samples=0},[]},[]};
make_audio_from_usr(Usr,CN) ->
	R = [get_last_audio(U1)||U1<-Usr],
	{mix_audio(CN,[AF||{AF,_}<-R]),[UST||{_,UST}<-R]}.

mix_audio(Noise,AFs) ->
	Raws = [get_pcm(Noise,AF)||AF<-AFs],
	{All,Mixs} = mix_pcmu2(Raws),
	{#audio_frame{codec=?PCMU,body=All,samples=160},pcm2mix(AFs,Mixs)}.

mix_pcmu2(PCMs) ->
	{_,Blk} = erl_amix:x(PCMs),
	[Sum|Mixs] = split_audio_blk(Blk),
	{Sum,Mixs}.

mix_pcmu(PCMs) ->
	{_,Blk} = u_mix:x(PCMs),
	Mixs = split_audio_blk(Blk),
	Mixs.

split_audio_blk(<<>>) ->
	[];
split_audio_blk(<<O:160/binary,R/binary>>) ->
	[O|split_audio_blk(R)].

pcm2mix([],[]) ->
	[];
pcm2mix([H1|T1],[H2|T2]) ->
	[H1#audio_frame{codec=?PCMU,body=H2,samples=160}|pcm2mix(T1,T2)].

get_pcm(Noise,#audio_frame{codec=?CN}) ->
	get_random_160s(Noise);
get_pcm(_,#audio_frame{codec=?PCMU,body=PCM}) ->
	PCM.

get_random_160s(Noise) ->
	Rndm = random:uniform(8000 - 160),
	<<_:Rndm/binary,O160:160/binary,_/binary>> = Noise,
	O160.

get_last_audio(U1) ->
	case U1 of
		#strm{abuf=[AFH|AFT]} ->
			{AFH, U1#strm{abuf=AFT}};
		#strm{abuf=[]} ->
			{#audio_frame{codec=?CN}, U1}
	end.

% ----------------------------------
is_chairman(RTP,Chairs) ->
	case lists:keysearch(RTP,2,Chairs) of
		{value,{0,_}} -> true;
		{value,{_Pos,_}} -> false;
		false -> false
	end.

mkvfn(Name) ->
	{_,Mo,D} = date(),
	{H,M,S} = time(),
	Name++"_"++xt:int2(Mo)
			 ++xt:int2(D)
			 ++"_"
			 ++xt:int2(H)
			 ++xt:int2(M)
			 ++xt:int2(S).

find_imglock_but(RTP,Usr) ->
	case [ORTP||#strm{ortp=ORTP,locked=Lkd}<-Usr,ORTP=/=RTP,Lkd==true] of
		[] -> RTP;
		NE -> hd(NE)
	end.

dele_history_img([]) -> [];
dele_history_img([#strm{vbuf=VB}=U1|T]) ->
	case length(VB) of
		L when L<2 -> [U1|dele_history_img(T)];
		_ -> [U1#strm{vbuf=[lists:last(VB)]}|dele_history_img(T)]
	end.

make_all_images(Imgs) ->
	YUV = yv12_resample:bind_image('TYPE2X2',Imgs),
	YUV.

make_image_from_usr_ts(RTP,Chairs,Usr) ->
	{NN,Ts,Imgs,NewUsr} = get_last_images(0,RTP,Chairs,Usr,0,33*90,[],[]),
	{NN,Ts,make_all_images(Imgs),NewUsr}.

get_last_images(?MAXCHAIRS,_,_,Usr,New,Ts,Imgs,NUsr) ->
	{New,Ts,lists:reverse(Imgs),lists:reverse(NUsr)++clear_video_buf(Usr)};
get_last_images(N,Traced,Chairs,Usr,New,Ts,Imgs,NUsr) ->
	case lists:keysearch(N,1,Chairs) of
		false ->
			get_last_images(N+1,Traced,Chairs,Usr,New,Ts,[null|Imgs],NUsr);
		{value,{_,RTP}} ->
			case lists:keysearch(RTP,#strm.ortp,Usr) of
				false ->
					get_last_images(N+1,Traced,Chairs,Usr,New,Ts,[null|Imgs],NUsr);
				{value,#strm{locked=false}=U1} ->
					get_last_images(N+1,Traced,Chairs,lists:keydelete(RTP,#strm.ortp,Usr),New,Ts,[null|Imgs],[U1|NUsr]);
				{value,#strm{locked=true,vbuf=[]}=U1} ->
					get_last_images(N+1,Traced,Chairs,lists:keydelete(RTP,#strm.ortp,Usr),New,Ts,[null|Imgs],[U1|NUsr]);
				{value,#strm{locked=true,new_image=NN,vbuf=[{Ts1,_,YUV}|VFT]=VB}=U1} ->
					{NewI,NVF} = if length(VB) == 1 -> {0,VB};
	  					true -> {1,VFT} end,
	  				Ts2 = if RTP==Traced andalso Ts1>0 ->Ts1; true->Ts end,
					get_last_images(N+1,Traced,Chairs,lists:keydelete(RTP,#strm.ortp,Usr),New+NN,Ts2,[YUV|Imgs],[U1#strm{vbuf=NVF,new_image=NewI}|NUsr])
			end
	end.

clear_video_buf([]) -> [];
clear_video_buf([U1|T]) ->
	[U1#strm{vbuf=[]}|clear_video_buf(T)].

minisec(Micro) ->
	(Micro div 1000)*1000.

compute_td(undefined,LastTC) ->
	{Mega,Sec,Micro} = now(),
	ThisTC = {Mega,Sec,minisec(Micro)},
	TD = timer:now_diff(ThisTC, LastTC) div 1000,
	{TD,ThisTC};
compute_td(TD,_) when is_integer(TD) ->
	{Mega,Sec,Micro} = now(),
	ThisTC = {Mega,Sec,minisec(Micro)},
	{TD div 90,ThisTC}.

encVP8(ForceKey,_,Td,YUV,#ve_st{n=N,flags=TemporalFlags,level=TemporalLevels,ctx=Ctx,last_tc=LastTC,last_ts=PTS}=VEnc) ->
	EFlags = lists:nth(N rem 8 + 1,TemporalFlags),
	Level = element(N rem 4 + 1, TemporalLevels),
	EFlags2 = if (N rem 32)==0 -> EFlags; true -> EFlags band 16#fffffffe end,
	Flags = EFlags2 bor if ForceKey -> 1; true -> 0 end,
	{TD,ThisTC} = compute_td(Td,LastTC),
	0 = erl_vp8:xenc(Ctx,YUV,PTS,TD,Flags),
	{0,Key,EncDat} = erl_vp8:genc(Ctx),
	{Key,Level,TD*90,EncDat,VEnc#ve_st{n=N+1,last_tc=ThisTC,last_ts=PTS+TD}}.

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
	Fsz = size(Frame),
	Len = (Fsz + ?MAXRTPLEN - 1) div ?MAXRTPLEN,
	Psz = Fsz div Len,
	{F1,Fr} = split_binary(Frame,Psz),
	split_VP8_4_rtp(F1,Psz+1,Fr,[]).
split_VP8_4_rtp(F1, Psz, Fr, Res) when size(Fr) =< Psz ->
	{F1,lists:reverse(Res),Fr};
split_VP8_4_rtp(F1,Psz,VP8, Res) ->
	{H, T} = split_binary(VP8, Psz),
	split_VP8_4_rtp(F1, Psz,T,[H|Res]).

frameOf(Bin) ->
	{_,Out} = split_binary(Bin,4),
	Out.

destory_dec(R,[]) ->
	R;
destory_dec(R,[#strm{vdec=VDec}|UT]) ->
	R1 = erl_vp8:xdtr(VDec#vd_st.ctx,1),	% 1 for dec
	destory_dec(R+R1,UT).
% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start({local,list_to_atom(Name)},?MODULE,[Name,has_vcr],[]),
	{Name,Pid}.

leave(Pid,{Chair,RTP}) ->
	Pid ! {leave_meeting, {Chair,RTP}}.

enter(Pid,{Chair,RTP}) ->
	Pid ! {enter_meeting, {Chair,RTP}}.

stop(Pid) ->
	my_server:cast(Pid,stop).