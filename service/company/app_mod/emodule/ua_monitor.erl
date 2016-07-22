-module(ua_monitor).
-compile(export_all).

start() ->
    register(ua_monitor,spawn(fun()->loop() end)).
	
loop() ->
    receive
	    {get_all_ua,From} ->
		    From ! {all_ua,ets:foldl(fun(Item,Acc)-> [Item|Acc] end,[],route_tab)},
		    loop();
		X ->
		    io:format("UA_MONITOR: receive unexpected message: ~p~n",[X]),
		    loop()
	end.