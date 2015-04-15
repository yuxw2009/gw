-module(comment_server).
-compile(export_all).

start() ->
    register(?MODULE, spawn(fun() -> init() end)).

init() ->
    {ok, IODev} = file:open("./docroot/webvoip/wvoip_comments.log", [append]),
    {ok, IODev2} = file:open("./docroot/webvoip/wvoip_calls.log", [append]),
    loop(IODev, IODev2).

loop(IODev, IODev2) ->
    receive
        {comments, IP, Time, Content} ->
            io:format(IODev, "~p@~p   says: ~s~n", [IP, Time, Content]),
            file:sync(IODev),
            loop(IODev, IODev2);
        {call, IP, Time, Phone, Session} ->
            io:format(IODev2, "~p@~p call: ~s sesison: ~p~n", [IP, Time,Phone, Session]),
            file:sync(IODev2),
            loop(IODev, IODev2);

        _ ->
            loop(IODev, IODev2)
    end.

comment(IP, Time, Content) ->
    ?MODULE ! {comments, IP, Time, Content}.    

call(IP, Time, Phone, Session) ->
    ?MODULE ! {call, IP, Time, Phone, Session}. 
