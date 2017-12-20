-module(test).
-compile(export_all).

d(FName) ->
	{ok,R16K} = file:read_file(FName),
	R8K = down2(R16K, <<>>),
	file:write_file("r8k.pcm",R8K).
	
down2(R16K, Res) when size(R16K)>640 ->
	<<F1:640/binary,Rest/binary>> = R16K,
	R8K = erl_resample:down8k(F1),
	down2(Rest, <<Res/binary,R8K/binary>>);
down2(_R16K, Res) ->
	Res.
	
u(FName) ->
	{ok,R8K} = file:read_file(FName),
	R16K = up2(R8K, list_to_binary(lists:duplicate(10,0)), <<>>),
	file:write_file("r16k.pcm",R16K).

up2(R8K, Passed, Res) when size(R8K) >320 ->
	<<F1:320/binary, Rest/binary>> = R8K,
	R16K = erl_resample:up16k(F1,Passed),
	<<_:310/binary,P2/binary>> = F1,
	up2(Rest, P2, <<Res/binary, R16K/binary>>);
up2(_, _,Res) ->
	Res.