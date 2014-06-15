-module(xt2).
-export([str2hex/1,hex2str/1]).

str2hex(Str) ->
	bcd2hex(Str, "").

bcd2hex([], Res) ->
	lists:reverse(Res);
bcd2hex([H, L|T], Res) ->
	bcd2hex(T, [tohex(H)*16 + tohex(L) | Res]).
	

hex2str(Bin) ->
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
tohex(X) when X >= $A andalso X =< $F -> X - $A + 10;
tohex(X) when X >= $a andalso X =< $f -> X - $a + 10.
