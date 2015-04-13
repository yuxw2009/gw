-module(rtcp).
-compile(export_all).

-include("desc.hrl").
-define(FORCEZERO, 0).

parse(Bin) when is_binary(Bin) ->
	parse(Bin,[]).

parse(Bin, Res) when size(Bin)<4 ->
	lists:reverse(Res);
parse(<<2:2,0:1,_:5,_Type:8,Len:16,_/binary>> =Bin, Res) ->
	{Element1,Rest} = split_binary(Bin, (Len+1)*4),
	parse(Rest,[parse_element(Element1)|Res]);
parse(Bin,Res) ->
	rtp:llog("rtcp parser unknow ~p",[Bin]),
	lists:reverse(Res).

parse_element(<<2:2,_P:1,RRC:5,?RTCP_SR:8,_Len:16,SSRC:32,TS:8/binary,RTP:32,Packages:32,Bytes:32,Rest/binary>>) ->
	RcptRpts = parse_reception_report(Rest),
	#rtcp_sr{ssrc=SSRC,ts64=TS,rtp_ts=RTP,packages=Packages,bytes=Bytes,receptions=RcptRpts};
parse_element(<<2:2,_P:1,RRC:5,?RTCP_RR:8,_Len:16,SSRC:32,Rest/binary>>) ->
	RcptRpts = parse_reception_report(Rest),
	#rtcp_rr{ssrc=SSRC,receptions=RcptRpts};
parse_element(<<2:2,_P:1,RRC:5,?RTCP_BYE:8,_Len:16,SSRC:32,_/binary>>) ->
	#rtcp_bye{ssrc=SSRC};
parse_element(<<2:2,_P:1,1:5,?RTCP_SD:8,_Len:16,SSRC:32,?DESC_CNAME:8,CLen:8,Rest/binary>>) ->
	<<Cname:CLen/binary,_/binary>> = Rest,
	#rtcp_sd{ssrc=SSRC,cname=Cname};
parse_element(<<2:2,_P:1,?FMT_PLI:5, ?RTCP_PSFB:8, _Len:16,SSRC:32, MediaSource:32>>) ->
	#rtcp_pl{ssrc=SSRC,ms=MediaSource,pli=true};
parse_element(<<2:2,_P:1,?FMT_ALFB:5,?RTCP_PSFB:8, _Len:16,SSRC:32,?FORCEZERO:32,?REMB:32,BWInfo:4/binary,MyID:32>>) ->
	<<_Count:8,Exp:6,Mantissa:18>> = BWInfo,
	#rtcp_pl{ssrc=SSRC,ms=MyID,remb=Mantissa*trunc(math:pow(2,Exp))};
parse_element(<<2:2,_P:1,?FMT_NACK:5,?RTCP_RTPFB:8,_Len:16,SSRC:32, MediaSource:32,LostSeqTab/binary>>) ->
	Seqs = parse_lost_seqs(LostSeqTab),
	#rtcp_pl{ssrc=SSRC,ms=MediaSource,nack=Seqs};
parse_element(Bin) ->
	rtp:llog("rtcp parserr unknow ~p",[Bin]),
	{unknow,Bin}.

parse_reception_report(<<>>) ->
	[];
parse_reception_report(<<ID:32,Fraction:8,Cumulative:24,HighestSeq:32,ArriJttr:32,LastSrTs:32,Delay:32,Rest/binary>>) ->
	RcptRpt = #source_report{ssrc=ID,lost={Fraction/16#100,Cumulative},eseq=HighestSeq,jitter=ArriJttr,sr_ts=LastSrTs,sr_delay=Delay},
	[RcptRpt|parse_reception_report(Rest)].

parse_lost_seqs(<<>>) ->
	[];
parse_lost_seqs(<<Pid:16,BLP:16,Rest/binary>>) ->
	[Pid|get_lost_seqs(1,Pid+1,BLP)] ++ parse_lost_seqs(Rest).

get_lost_seqs(17,_,_) ->
	[];
get_lost_seqs(N,Pid,BLP) ->
	if (BLP rem 2 == 1) ->
		[Pid|get_lost_seqs(N+1,Pid+1,BLP div 2)];
	true ->
		get_lost_seqs(N+1,Pid+1,BLP div 2)
	end.

put_lost_seqs([H|T]) ->
	put_lost_seqs(T,H,0,0,<<>>).

put_lost_seqs([H|T],BeginSeq,17,Tags,Res) ->
	put_lost_seqs(T,H,0,0,<<Res/binary,BeginSeq:16,Tags:16>>);
put_lost_seqs([],BeginSeq,Delta,Tags,Res) ->
	NTags = shift_tag(Delta,Tags),
	<<Res/binary,BeginSeq:16,NTags:16>>;
put_lost_seqs([H|T],BeginSeq,Delta,Tags,Res) ->
	if H==BeginSeq+Delta ->
		put_lost_seqs(T,BeginSeq,Delta+1,(Tags div 2)+16#8000,Res);
	true ->
		put_lost_seqs([H|T],BeginSeq,Delta+1,Tags div 2,Res)
	end.

shift_tag(N,Tags) when N==0;N==17 ->
	Tags;
shift_tag(N,Tags) ->
	shift_tag(N+1,Tags div 2).
% ----------------------------------
enpack(Elements) ->
	list_to_binary([enpack_element(X) || X<-Elements]).


enpack_element(Elem) when is_record(Elem,rtcp_sr) ->
	#rtcp_sr{ssrc=SSRC,ts64=TS64,rtp_ts=TS,packages=Pkgs,bytes=Byts} = Elem,
	{Count,Src1} = enpack_reception_report(Elem#rtcp_sr.receptions),
	Len = size(Src1) div 4 + 6,
	SR = <<2:2,0:1,Count:5,?RTCP_SR:8,Len:16,SSRC:32,TS64/binary,TS:32,Pkgs:32,Byts:32>>,
	<<SR/binary,Src1/binary>>;
enpack_element(Elem) when is_record(Elem,rtcp_rr) ->
	#rtcp_rr{ssrc=SSRC} = Elem,
	{Count,Src1} = enpack_reception_report(Elem#rtcp_rr.receptions),
	Len = size(Src1) div 4 + 1,
	RR = <<2:2,0:1,Count:5,?RTCP_RR:8,Len:16,SSRC:32>>,
	<<RR/binary,Src1/binary>>;
enpack_element(Elem) when is_record(Elem,rtcp_sd) ->
	#rtcp_sd{ssrc=SSRC,cname=Cname} = Elem,
	CLen = size(Cname),
	PatLen = (((2 + CLen + 3) div 4) * 4 - CLen - 2) * 8,
	Len = (2 + CLen + (PatLen div 8)) div 4 + 1,
	<<2:2,0:1,1:5,?RTCP_SD:8,Len:16,SSRC:32,?DESC_CNAME:8,CLen:8,Cname/binary,0:PatLen>>;
enpack_element(Elem) when is_record(Elem,rtcp_bye) ->
	#rtcp_bye{ssrc=SSRC} = Elem,
	<<2:2,0:1,1:5,?RTCP_BYE:8,1:16,SSRC:32>>;
enpack_element(Elem) when is_record(Elem,rtcp_pl) ->
	#rtcp_pl{ssrc=SSRC,ms=MediaSource} = Elem,
	PLI = if Elem#rtcp_pl.pli==true ->
			<<2:2,0:1,?FMT_PLI:5, ?RTCP_PSFB:8, 2:16,SSRC:32, MediaSource:32>>;
		true -> <<>> end,
	REMB = if Elem#rtcp_pl.remb=/=undefined ->
			#rtcp_pl{ms=MyID,remb=BandWidth} = Elem,
			{Exp,Mantissa} = make_remb_bw(0,BandWidth),
			<<2:2,0:1,?FMT_ALFB:5,?RTCP_PSFB:8, 5:16,SSRC:32,?FORCEZERO:32,?REMB:32,1:8,Exp:6,Mantissa:18,MyID:32>>;
		true -> <<>> end,
	NACK = if Elem#rtcp_pl.nack=/=[] ->
			#rtcp_pl{nack=Seqs} = Elem,
			LostSeqTab = put_lost_seqs(Seqs),
			Len = size(LostSeqTab) div 4 + 2,
			<<2:2,0:1,?FMT_NACK:5,?RTCP_RTPFB:8,Len:16,SSRC:32, MediaSource:32,LostSeqTab/binary>>;
		true -> <<>> end,
	list_to_binary([PLI,REMB,NACK]);
enpack_element({unknow,Bin}) ->
	Bin.
	
enpack_reception_report([]) ->
	{0,<<>>};
enpack_reception_report([#source_report{ssrc=ID,						% only one source report here
										lost={Fraction,Cumulative},
										eseq=HighestSeq,
										jitter=ArriJttr,
										sr_ts=LastSrTs,
										sr_delay=Delay}]) ->
	{1,<<ID:32,Fraction:8,Cumulative:24,HighestSeq:32,ArriJttr:32,LastSrTs:32,Delay:32>>}.

% ----------------------------------
show_rtcp(From, RTCP) ->
	Prs = parse(RTCP),
%	lists:map(fun(X) -> show_rtcp_info(X) end, Prs),
	Prs.

show_rtcp_info(Pr) when is_record(Pr,rtcp_pl) ->
	if Pr#rtcp_pl.pli==true -> io:format("pli ~n");
	true -> pass end,
	if Pr#rtcp_pl.remb=/=undefined ->
		io:format(" ( ~p )~n",[Pr#rtcp_pl.remb]);
	true -> pass end,
	if Pr#rtcp_pl.nack=/=[] -> io:format("~p ~n",[Pr#rtcp_pl.nack]);
	true -> pass end;
show_rtcp_info(_) ->
	pass.

make_remb_bw(Exp,Manti) when Manti<16#3ffff ->
	{Exp,Manti};
make_remb_bw(Exp,Manti) ->
	make_remb_bw(Exp+1,Manti div 2).

tmp_get_ssrc(Elmts) ->
	case lists:keysearch(rtcp_sr,1,Elmts) of
		{value,#rtcp_sr{ssrc=SSRC}} ->
			SSRC;
		false ->
			case lists:keysearch(rtcp_rr,1,Elmts) of
				{value,#rtcp_rr{ssrc=SSRC}} -> SSRC;
				false -> 0
			end
	end.

test(sr) ->
	Bin = r2b:do("./rtcp_vector/sr1.dat"),
	SR1 = parse_element(Bin),
	RTCP1 = enpack_element(SR1),
	RTCP1 = Bin;
test(rr_s1) ->
	Bin = r2b:do("./rtcp_vector/rr1_src1.dat"),
	RR1 = parse_element(Bin),
	RTCP1 = enpack_element(RR1),
	RTCP1 = Bin;
test(sd) ->
	Bin = r2b:do("./rtcp_vector/sd2.dat"),
	SD1 = parse_element(Bin),
	RTCP1 = enpack_element(SD1),
	RTCP1 = Bin;
test(sd2) ->
	Bin = r2b:do("./rtcp_vector/sd1.dat"),
	parse_element(Bin);
test(bye) ->
	Bin = r2b:do("./rtcp_vector/bye.dat"),
	BYE1 = parse_element(Bin),
	RTCP1 = enpack_element(BYE1),
	RTCP1 = Bin;
test(FName) when is_list(FName) ->
	Bin = r2b:do("./rtcp_vector/"++FName),
	RTCPs = parse(Bin),
	Bin2 = enpack(RTCPs),
	Bin = Bin2.

test() ->
	lists:map(fun(X) -> rtcp:test(X) end, [sr,rr_s1,sd,sd2,bye]),
	io:format("single element test ok.~n"),
	lists:map(fun(X) -> rtcp:test(X) end, ["rr_fb.dat", "rr_fb2.dat", "rr_pli.dat"]),
	io:format("multi elements test ok.~n").