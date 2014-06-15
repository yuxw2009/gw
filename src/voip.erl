-module(voip).
-compile(export_all).

start() ->
    io:format("start log.~n"),
    llog:start(),
    io:format("start my_timer.~n"),
    my_timer:start(),
   
   	io:format("app_manager log.~n"),
    app_manager:start(),
    rbt:start(),
    io:format("start rbt.~n"),
	
	io:format("statistic log.~n"),
    statistic:start(),

    io:format("net_stats log.~n"),
    net_stats:start(),  %% temporaty, should be merged with statistic.
	nm:start(),

    application:start(asn1),
    application:start(public_key),
    application:start(cypto),
    application:start(ssl),
    ok.
