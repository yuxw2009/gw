-module(encrypt).
-export([run/2]).
switch16(Str) ->
    Seqs = lists:seq(1,length(Str),2),
	L	 = [string:substr(Str,SeqNo,2)||SeqNo<-Seqs],
	string:join(lists:reverse(L),"").
encrypt(switch16,Str) ->
	switch16(Str).
calc_encrypt_deep(Str,Deep) ->
    Len = lists:min([length(Str),Deep]),
	(Len div 4) * 4.
run(Str,Deep) when is_list(Str) and is_integer(Deep) ->
    EncryptDeep 	= calc_encrypt_deep(Str,Deep),
	{Needs,NoNeeds}	= lists:split(EncryptDeep,Str),
	encrypt(switch16,Needs) ++ NoNeeds.
test() ->
    {ok,Binary} = file:read_file("test"),
	String      = binary_to_list(Binary),
	NewStr		= run(String,100),
	{ok,Device} = file:open("test1",write),
	io:format(Device,"~s~n",[NewStr]),
	{ok,Device1} = file:open("test2",write),
	NewStr1		= run(NewStr,100),
	io:format(Device1,"~s~n",[NewStr1]).