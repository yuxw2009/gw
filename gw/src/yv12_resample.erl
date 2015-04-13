-module(yv12_resample).
-compile(export_all).

-include("erl_debug.hrl").

-define(OVW, 640).
-define(OVH, 480).

-define(BLACKUV,128).

scl_image({OW,OH},{DW,DH},YV12) when OW > DW ->
	{0,YUV} =  ?APPLY(erl_video, xscl, [YV12,OW,OH,DW,DH]) ,
	YUV;
scl_image({OW,OH},{DW,DH},YV12) when OW < DW ->
	YUV = add_kuang({OW,OH},{DW,DH},YV12),
	YUV;
scl_image(_,_,YV12) ->
	YV12.

cut_image({OW,OH}=InRsu,{DW,DH}=OutRsu,YV12) when OW > DW ->
	{YSz,USz} = yuv_size(InRsu),
	<<Y:YSz/binary,U:USz/binary,V:USz/binary>> = YV12,
	YMid = cut_img2(InRsu,OutRsu,Y),
	UMid = cut_img2({OW div 2, OH div 2},{DW div 2, DH div 2},U),
	VMid = cut_img2({OW div 2, OH div 2},{DW div 2, DH div 2},V),
	<<YMid/binary,UMid/binary,VMid/binary>>;
cut_image({OW,OH},{OW,OH},YV12) ->
	YV12.
	
cut_img2({OW,OH},{DW,DH},Y) ->
	HCutT0 = trunc((OH - DH) / 2),
	HRem0 = DH,
	HCutB0 = OH - HCutT0 - HRem0,
	HCutT = HCutT0 * OW,
	HRem = HRem0 * OW,
	HCutB = HCutB0 * OW,
	
	
	WCutL = trunc((OW - DW) / 2),
	WRem = DW,
	WCutR = OW - WCutL - WRem,
	
	
	<<_:HCutT/binary,HMid:HRem/binary,_:HCutB/binary>> = Y,
	YMid = cut_each_line(WCutL,WRem,WCutR,HMid,<<>>),
	YMid.

cut_each_line(_,_,_,<<>>,OutBin) ->
	OutBin;
cut_each_line(Left,Mid,Right,InBin,OutBin) ->
	<<_:Left/binary,Res:Mid/binary,_:Right/binary,Rest/binary>> = InBin,
	cut_each_line(Left,Mid,Right,Rest,<<OutBin/binary,Res/binary>>).

yuv_size({W,H}) ->
	B = W * H,
	0 = B rem 4,
	{B, B div 4}.

% ----------------------------------
add_kuang({OW,OH},{DW,DH},YV12) when OW < DW ->
	{YSz,USz} = yuv_size({OW,OH}),
	<<Y:YSz/binary,U:USz/binary,V:USz/binary>> = YV12,
	YMid = add_kuang2({OW,OH},{DW,DH},Y,0),
	UMid = add_kuang2({OW div 2, OH div 2},{DW div 2, DH div 2},U,128),
	VMid = add_kuang2({OW div 2, OH div 2},{DW div 2, DH div 2},V,128),
	<<YMid/binary,UMid/binary,VMid/binary>>.
	
add_kuang2({OW,OH},{DW,DH},YUV,NULL) ->
	HCutT0 = trunc((DH - OH) / 2),
	HRem0 = OH,
	HCutB0 = DH - HCutT0 - HRem0,
	HCutT = HCutT0 * DW,
	HRem = HRem0 * DW,
	HCutB = HCutB0 * DW,

	WCutL = trunc((DW - OW) / 2),
	WRem = OW,
	WCutR = DW - WCutL - WRem,

	AddNullTop = list_to_binary(lists:duplicate(HCutT,NULL)),
	AddNullBottom = list_to_binary(lists:duplicate(HCutB,NULL)),
	YMid = add_each_line(WCutL,WRem,WCutR,YUV,<<>>,NULL),
	<<AddNullTop/binary,YMid/binary,AddNullBottom/binary>>.

add_each_line(_,_,_,<<>>,OutBin,_) ->
	OutBin;
add_each_line(Left,Mid,Right,InBin,OutBin,NULL) ->
	<<Line:Mid/binary,Rest/binary>> = InBin,
	LB = list_to_binary(lists:duplicate(Left,NULL)),
	RB = list_to_binary(lists:duplicate(Right,NULL)),
	Res = <<LB/binary,Line/binary,RB/binary>>,
	add_each_line(Left,Mid,Right,Rest,<<OutBin/binary,Res/binary>>,NULL).

% ----------------------------------
bind_image('TYPE2X2',[Img1,Img2,Img3,Img4]) ->
	{YSz,USz} = yuv_size({?OVW div 2,?OVH div 2}),
	<<Y1:YSz/binary,U1:USz/binary,V1:USz/binary>> = mark_blank(Img1),
	<<Y2:YSz/binary,U2:USz/binary,V2:USz/binary>> = mark_blank(Img2),
	<<Y3:YSz/binary,U3:USz/binary,V3:USz/binary>> = mark_blank(Img3),
	<<Y4:YSz/binary,U4:USz/binary,V4:USz/binary>> = mark_blank(Img4),
	Y = bind_img2({?OVW,?OVH},Y1,Y2,Y3,Y4),
	U = bind_img2({?OVW div 2,?OVH div 2},U1,U2,U3,U4),
	V = bind_img2({?OVW div 2,?OVH div 2},V1,V2,V3,V4),
	<<Y/binary,U/binary,V/binary>>.

bind_img2({W,H},V1,V2,V3,V4) ->
	Top = bind_img3(0,{W,H div 2},V1,V2,<<>>),
	Img = bind_img3(H div 2,{W,H},V3,V4,Top),
	Img.
	
bind_img3(H,{_,H},<<>>,<<>>,Res) ->
	Res;
bind_img3(Line,{W,H},VL,VR,Res) ->
	W2 = W div 2,
	<<VL1:W2/binary,VL2/binary>> = VL,
	<<VR1:W2/binary,VR2/binary>> = VR,
	bind_img3(Line+1,{W,H},VL2,VR2,<<Res/binary,VL1/binary,VR1/binary>>).

mark_blank(null) ->
	list_to_binary(lists:duplicate(?OVH*?OVW div 4,0)++lists:duplicate(?OVH*?OVW div 8,?BLACKUV));
mark_blank(Bin) ->
	Bin.