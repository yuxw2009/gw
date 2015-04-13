-module(r2b).
-compile(export_all).

do(FileName) ->
	{ok,Bin} = file:read_file(FileName),
	Ls = string:tokens(binary_to_list(Bin),"\r\n"),
	Bs = lists:map(fun(X) -> doline(X) end, Ls),
	list_to_binary(Bs).

doline(L) ->
	Bs = lists:map(fun(X) -> xt:str2hex(X) end, tl(string:tokens(L, " "))),
	list_to_binary(lists:append(Bs)).