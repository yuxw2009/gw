-module(xt).
-compile(export_all).

dt2str({D, T}) ->
	d2str(D) ++ " " ++ t2str(T).

t2str({H, M, S}) ->
	int2(H) ++ ":" ++ int2(M) ++ ":" ++ int2(S).
	
d2str({Y, M, D}) ->
	int4(Y) ++ "/" ++ int2(M) ++ "/" ++ int2(D).

v32l({V1, V2, V3}) when is_integer(V1) ->
	i2l(V1) ++ "," ++ i2l(V2) ++ "," ++ i2l(V3);
v32l({V1, V2, V3}) when is_float(V1) ->
	f2l(V1) ++ "," ++ f2l(V2) ++ "," ++ f2l(V3).

v22l({V1, V2})->
	i2l(V1) ++ "," ++ i2l(V2).
	
rate({Va, Vb, Vc}, {Ia, Ib, Ic}) ->
	{rt(Va,Ia), rt(Vb,Ib), rt(Vc,Ic)}.
	
rt(_, 0) -> 0;
rt(V, I) -> round(V*10 / I).
	
int2(I) ->
	int2str(I, 2).
int3(I) ->
	int2str(I, 3).
int4(I) ->
	int2str(I, 4).

du2l({H, M}) ->
	int2(H)++":"++int2(M).

i2l(I) when is_integer(I), I >0 ->
	integer_to_list(I);
i2l(_) ->
	"0".

f2l(F) when is_float(F) ->
	[R]=io_lib:format("~.2f",[F]),
	R;
%	Is = integer_to_list(round(F * 100)),
%	L = length(Is),
%	if
%		L > 2 ->
%			{I, D} = lists:split(length(Is)-2, Is),
%			I++"."++D;
%		L == 2 ->
%			"0."++Is;
%		true ->
%			"0.0"++Is
%	end;
f2l(_) ->
	"0.0".

a2l(A) when is_atom(A) ->
	atom_to_list(A);
a2l(_) -> "xxx".

a2gif(ac_on) -> "ac_on.gif";
a2gif(ac_off) -> "ac_off.gif";
a2gif(afu_on) -> "afu_on.gif".

tid(Phno) -> [$t |lists:nthtail(6, Phno)].
rid(Phno) -> [$r |lists:nthtail(6, Phno)].

l2i(X) ->
	try list_to_integer(X) of
		N -> N
	catch
		error:_E -> 100
	end.


% ----------------------------------
divwith(N, S) ->
	{S div N, S rem N}.

int2str(I, Len) when is_integer(Len) ->
	int2str(I, Len, "");
int2str(I, L) when is_list(L) ->
	int2str(I, length(L)).
	
int2str(_, 0, R) ->
	R;
int2str(I, Len, R) ->
	{I2, I1} = divwith(10, I),
	R2 = integer_to_list(I1) ++ R,
	int2str(I2, Len-1, R2).
