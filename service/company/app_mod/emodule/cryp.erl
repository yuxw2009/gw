-module(cryp).
-compile(export_all).

-define(DESKEY, <<"68895098">>).
-define(PATCHSTR, ",$$$$$$$").

enc(Company, Str) ->
	EnCode = des_encryp(Company, Str),
	{ok, Company, hex2bcd(EnCode)}.

dec(Company, BStr) ->
	Str = bcd2hex(BStr),
	Bin = decrypt(?DESKEY, list_to_binary(shape8(Company)), list_to_binary(Str)),
	Txt = binary_to_list(Bin),
	removetail(Txt).

des_encryp(IVec, Str) ->
	encrypt(?DESKEY, list_to_binary(shape8(IVec)), shape8(Str)).

% ----------------------------------
encrypt(Key, IVec, Txt) ->
	CKey = segment_bxor(Key, IVec),
	shift_bxor(CKey, list_to_binary(Txt)).

decrypt(Key, IVec, Cipher) ->
	CKey = segment_bxor(Key, IVec),
	shift_bxor(CKey, Cipher).

segment_bxor(<<A1:32, A2:32>>, <<B1:32, B2:32>>) ->
	<<(A1 bxor B1):32, (A2 bxor B2):32>>.
	
shift_bxor(Key, Txt) -> shift_bxor(Key, Txt, <<>>).

shift_bxor(_, <<>>, Bin) ->
	Bin;
shift_bxor(<<K1:32, K2:32>> = K, <<T1:32, T2:32, Rest/binary>>, Bin) ->
	shift_bxor(K, Rest, <<Bin/binary, (K1 bxor T1):32, (K2 bxor T2):32>>).

% ----------------------------------
shape8(Str) ->
	Len = length(Str),
	IL = Len div 8,
	case lists:split(IL * 8, Str) of
		{S1, []} ->
			S1;
		{S1, S2} ->
			DL = length(S2),
			{S3, _} = lists:split(8-DL, ?PATCHSTR),
			S1++S2++S3
	end.

removetail(Li) ->
	rmvtl(lists:reverse(Li)).
	
rmvtl([$\$, $, |T]) ->
	lists:reverse(T);
rmvtl([$, |T]) ->
	lists:reverse(T);
rmvtl([$\$ |T]) ->
	rmvtl(T);
rmvtl(Others) ->
	lists:reverse(Others).

bcd2hex(Str) ->
	bcd2hex(Str, "").

bcd2hex([], Res) ->
	lists:reverse(Res);
bcd2hex([H, L|T], Res) ->
	bcd2hex(T, [tohex(H)*16 + tohex(L) | Res]).
	

hex2bcd(Bin) ->
	hex2bcd(Bin, "").
	
hex2bcd(<<>>, Res) ->
	Res;
hex2bcd(<<Int:8, Rest/binary>>, Res) ->
	hex2bcd(Rest, Res++int2bcd(Int)).
	
int2bcd(Int) ->
	R = Int rem 16,
	D = Int div 16,
	[tobcd(D),tobcd(R)].
	
tobcd(X) when X >= 0 andalso X =< 9 -> X + $0;
tobcd(X) -> X - 10 + $A.

tohex(X) when X >= $0 andalso X =< $9 -> X - $0;
tohex(X) -> X - $A + 10.