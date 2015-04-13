-module(t729).
-compile(export_all).

-define(MAXSAMPLE,300).

go() ->
	{ok,Tone} = file:read_file("rbt.pcmu"),
	{_,Ctx} = erl_g729:icdc(),
	{G729,_} = lists:foldr(fun(X,Acc) -> pcmu2g729(Ctx,X,Acc) end, {<<>>,Tone},lists:seq(0,299)),
	erl_g729:xdtr(Ctx),
	G729.

pcmu2g729(Ctx,N,{G729,PcmU}) ->
	BodyU = rbt:get_tone(N,PcmU),
	BodyL = erl_isac_nb:udec(BodyU),
	{0,2,BodyG} = erl_g729:xenc(Ctx,BodyL),
	{<<G729/binary,20:16,BodyG/binary>>,PcmU}.