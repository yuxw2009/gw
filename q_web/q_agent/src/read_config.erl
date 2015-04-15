-module(read_config).
-compile(export_all).

start() ->
    inets:start(),
    {ok,Configs} = open_config(),
    analyse_config(Configs).

open_config() -> 
    consult("lw_config").

analyse_config([]) ->
    ok;
analyse_config([{voice_server,IP}|T]) ->
    lw_config ! {set,voice_server,IP},
    analyse_config(T);
analyse_config([{video_server,IP}|T]) ->
    lw_config ! {set,video_server,IP},
    analyse_config(T);
analyse_config([{http_proxy,IP,Port}|T]) ->
    httpc:set_options([{proxy, {{IP, Port}, ["localhost"]}}]),
    analyse_config(T).
    
consult(File) ->
    case file:open(File, read) of
    	{ok, S} ->
    	    Val = consult1(S),
    	    file:close(S),
    	    {ok, Val};
    	{error, Why} ->
    	    {error, Why}
    end.

consult1(S) ->
    case io:read(S, '') of
    	{ok, Term} -> [Term|consult1(S)];
    	eof -> [];
    	Error -> Error
    end.