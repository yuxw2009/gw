-module(pdu).
-compile(export_all).

-define(International, 16#91).
-define(EncCmp7, <<0>>).
-define(EncUcs2, <<8>>).
-define(PDUHEADLEN, 7).	% exclude SMSC, exclude the DA field, include the UDL 1byte.

parse(Str, Snpf) ->
	Bin = list_to_binary(cryp:bcd2hex(Str)),
	parseb(Bin, Snpf).
	
parseb(<<SMCL/integer, TCenter:SMCL/binary, _U/integer, Nosz/integer, Rest1/binary>> = Bin, Snpf) ->
	Asz = sendernumlen(Snpf, Nosz),
	<<SenderNuType/integer, Sender:Asz/binary, _TP_PID/integer, Rest2/binary>> = Rest1,
	<<Encode:1/binary, YMD:3/binary, HMS:3/binary, TZ:1/binary, PldLen/integer, Pld/binary>> = Rest2,
	<<_Tsmc/integer, Center/binary>> = TCenter,
	
	_Cno = getphno(Center),
	Aphno = getphno(Sender),
	
	if
		Encode == ?EncCmp7 ->
			Date = getdate(YMD),
			{Time, TZS} = gettime(HMS,TZ),
			Txt = gettxt(PldLen, Pld),
			{Aphno, {Date, Time, TZS}, Txt};
		Encode == ?EncUcs2 ->
			Date = getdate(YMD),
			{Time, TZS} = gettime(HMS,TZ),
			Txt = getucs2(PldLen,Pld),
			{Aphno, {Date,Time,TZS}, Txt};
		true ->
			llog("cannot parse(2) ~p", [Bin]),
			unparsed
	end;
parseb(Bin, _) ->
	llog("cannot parse(1) ~p", [Bin]),
	unparsed.

gettxt(Len, PayLoad) ->
	binary_to_list(gettxt(Len, PayLoad, 8, <<>>)).
gettxt(0, _Bin, _Nbit, Rbin) ->
	Rbin;
gettxt(Len, Bin, 8, Rbin) ->
	<<_:1, Char:7, _/binary>> = Bin,
	gettxt(Len-1, Bin, 1, <<Rbin/binary, 0:1, Char:7>>);
gettxt(Len, Bin, 7, Rbin) ->
	<<Char:7, _:1, Rest/binary>> = Bin,
	gettxt(Len-1, Rest, 8, <<Rbin/binary, 0:1, Char:7>>);
gettxt(Len, Bin, N, Rbin) ->
	Lsz = 8-N,
	Hsz = 7-N,
	Rsz = N+1,
	<<Low:N, _:Lsz, Left:Rsz, High:Hsz, Rest/binary>> = Bin,
	gettxt(Len-1, <<Left:Rsz, High:Hsz, Rest/binary>>, Rsz, <<Rbin/binary, 0:1, High:Hsz, Low:N>>).	

getucs2(Len,PayLoad) ->
	binary_to_list(getucs2(Len,PayLoad,<<>>)).
getucs2(0, _, Rbin) ->
	Rbin;
getucs2(Len, <<0,N,Rest/binary>>,Rbin) ->
	getucs2(Len-2,Rest,<<Rbin/binary,N>>);
getucs2(Len, <<_,_,Rest/binary>>,Rbin) ->
	Occ= <<"~">>,
	getucs2(Len-2,Rest,<<Rbin/binary,Occ/binary>>).

getphno(Bin) ->
	getphno(Bin, "").
getphno(<<>>, Phno) ->
	lists:reverse(Phno);
getphno(<<16#F:4, B:4, _Rest/binary>>, Phno) ->
	lists:reverse([cryp:tobcd(B) |Phno]);
getphno(<<B1:4, B2:4, Rest/binary>>, Phno) ->
	getphno(Rest, [cryp:tobcd(B1), cryp:tobcd(B2)|Phno]).

parseInfo(Snpf,Str) ->
	Bin = list_to_binary(cryp:bcd2hex(Str)),
	try parseIb(Snpf,Bin) of
		R -> R
	catch
		error:_X ->
			unparsed
	end.
	
parseIb(Snpf,<<SMCL/integer, Center:SMCL/binary, _:8, Nosz:8, Rest/binary>>) ->
	Asz = sendernumlen(Snpf, Nosz),
	<<_SenderType/integer, Sender:Asz/binary, _TP_Pid/integer, _Encode:1/binary, YMD:3/binary, HMS:3/binary, TZ:1/binary,_/binary>> = Rest,
	<<_Ct:8, CenterNo/binary>> = Center,
	Cno = getphno(CenterNo),
	Aphno = getphno(Sender),
	Date = getdate(YMD),
	{Time, TZS} = gettime(HMS,TZ),
	{Cno, Aphno, {Date, Time, TZS}}.
	
sendernumlen("1", Nosz) ->
	(Nosz div 2) + (Nosz rem 2);
sendernumlen("0", Nosz) ->
	Nosz.
% ----------------------------------
encode(Cno, {Aphno,Snpf}, {Etype, _}=E) ->
	{SMCL, SMC} = smsc(Cno),
	{DAL, DA} = tp_da(Aphno, Snpf),
	Head = SMC++msgtype()++pageidx()++DA++tp_pid()++tp_dcs(Etype)++tp_vp(),
	{EnUDL, UDL} = udl(E),
	UD = ud(E),
	{xt:int3(?PDUHEADLEN+SMCL+DAL+EnUDL), Head++cryp:hex2bcd(<<UDL>>)++UD}.

smsc("none") ->
	{1, "00"};
smsc(Cno) ->
	smc_da(Cno),
	{1,"00"}.
	
msgtype() ->
	"11".
pageidx() ->
	"00".

smc_da(Cno) ->
	Len = length(Cno),
	PLen = Len div 2 + Len rem 2,
	{PLen+1,cryp:hex2bcd(<<PLen>>)++cryp:hex2bcd(<<?International>>)++swaphl_da(Cno)}.	
tp_da(Aphno, Snpf) when is_list(Aphno) ->
	Len = length(Aphno),
	PLen = Len div 2 + Len rem 2,
	if
		Snpf == "0" ->
			{PLen,cryp:hex2bcd(<<PLen>>)++cryp:hex2bcd(<<?International>>)++swaphl_da(Aphno)};
		true ->
			{PLen,cryp:hex2bcd(<<Len>>)++cryp:hex2bcd(<<?International>>)++swaphl_da(Aphno)}
	end.
	
swaphl_da([]) ->
	[];
swaphl_da([H]) ->
	[$F, H];
swaphl_da([H1, H2|T]) ->
	[H2, H1] ++ swaphl_da(T).
	
tp_pid() ->
	"00".
	
tp_dcs(default) ->
	cryp:hex2bcd(?EncCmp7);
tp_dcs(ucs2) ->
	cryp:hex2bcd(?EncUcs2).

tp_vp() ->
	"01".

udl({default, Txt}) ->
	L = length(Txt),
	{trunc(L*7 / 8 + 0.9), L};
udl({ucs2,UniTxt}) ->
	L = length(UniTxt) div 2,
	{L, L}.
	
ud({default, Txt}) ->
	cmp7(Txt);
ud({ucs2, Txt}) ->
	Txt.

cmp7(Txt) when is_list(Txt) ->
	cmp7(list_to_binary(Txt), 0, <<>>).
cmp7(<<>>, _, R) ->
	cryp:hex2bcd(list_to_binary(lists:reverse(binary_to_list(R))));
cmp7(<<0:1, V:7, Rest/binary>>, 0, R) ->
	cmp7(Rest, 7, <<0:1, V:7, R/binary>>);
cmp7(<<0:1, V:7, Rest/binary>>, 1, <<_:7, H:1,T/binary>>) ->
	cmp7(Rest, 0, <<V:7, H:1, T/binary>>);
cmp7(<<V:1/binary, Rest/binary>>, OBs, <<H:1/binary, T/binary>>) ->
	EBs = 8-OBs,
	OvBs= 7-EBs,
	NewEBs= 8-OvBs,
	<<0:1,V1:OvBs,V2:EBs>> = V,
	<<_:EBs, Occu:OBs>> =H,
	NewH = <<0:NewEBs,V1:OvBs,V2:EBs,Occu:OBs>>,
	cmp7(Rest, OvBs, <<NewH/binary, T/binary>>).

% ----------------------------------
getdate(Bin) ->
	get3(Bin).
gettime(Bin,TZB) ->
	TZ = case TZB of
			<<L:4, 0:1, H:3>> ->
				"+"++cryp:hex2bcd(<<0:1, H:3, L:4>>);
			<<L:4, 1:1, H:3>> ->
				"-"++cryp:hex2bcd(<<0:1, H:3, L:4>>)
		end,
	{get3(Bin), TZ}.
get3(Bin) ->
	[L1, L2, L3] = hlswap(Bin),
	{list_to_integer(L1), list_to_integer(L2), list_to_integer(L3)}.
	
hlswap(Bin) ->
	hlswap(Bin, []).
hlswap(<<>>, Res) ->
	lists:reverse(Res);
hlswap(<<B1:4, B2:4, Rest/binary>>, Res) ->
	hlswap(Rest, [[cryp:tobcd(B2), cryp:tobcd(B1)]|Res]).
% ----------------------------------
llog(F, M) ->
	llog ! {self(), F, M}.
llog(F) ->
	llog ! {self(), F}.

test() ->
	R1 = parse("0891683108100005F0240D91683100018050F22100406032010595231331D98C56B3DD703958503824168D476412","1"),
	R2 = parse("0891683108200105F02408A001562812000821202071601523886C148C6153F0003265E50031003765F6FF1A591A4E914E0A534A591C4EE5524D4E1C90E85730533A670996F6661F5C0F96EAFF0C4ECA534A591C5230660E591A4E91523066743002504F53170034002D0035534A591C8F6C0033002D0034660E8F6C4E1C531752304E1C98CE0033002D00347EA73002002D0031002F00355EA6FF0C6709858451B0","1"),
	R3 = parse("0891683108200105F0240D91685103801057F60000212090618423230B3059CC86C3E56AB01C0E","1"),
	R4 = parse("0891683108200105F06408A001561893000421306190849223740605040B8423F072060A03AE81EAAF828DE0B48402056A34E5858DE8B4B9E6898BE69CBAE5BDA9E99383E3808AE788B1E79A84E69785E8A18CE3808BEFBC8CE782B9E587BBE88EB7E58F960045C60C037761706D61696C2E31303038362E636E2F6C3F663D327830783138323100080183000101","1"),
	R5 = parse("0891683108200105F02408A0015688030008213061213535238C4E0A6D7779FB52A85F6994C3003367084EFD56DE998860A8FF1A56DE590D4E0B521763074EE44E0B8F7D70ED95E85F6994C38FD853E690014E009996514D8D395F6994C354E6FF0100540038723176844F9B517BFF1B005400394F60662F62117684773CFF1B0054003100305C0F5C0F65B05A1882B1FF0C53734E0B5373900154E6FF0100325143002F9996","1"),
	{R1, R2, R3, R4, R5}.

enctest() ->
%{sms, "019>00 1100 0D91 688110686930F6 000801 04 4F60597D"}
	{"019", "0011000D91688110686930F6000801044F60597D"} = encode("none",{"8618018696036","1"}, {ucs2, "4F60597D"}),
	R1 = encode("none", {"8618018696036","1"},{ucs2, "4F60597D94B16C9B"}),	% ÄãºÃÇ®Åæ
	R2 = encode("none", {"8618018696036","1"},{default, "ABCDEFGH"}),
	R3 = encode("8613802100000", {"8613801961496","0"}, {default, "ABCDEFGH"}),
	{R1, R2, R3}.
