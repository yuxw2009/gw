-module(mockobj).
-compile(export_all).

start() -> 
    spawn(fun() -> mockobj_loop([]) end).

stop(Pid) ->
    Pid ! stop.

last_call(Pid) ->
    case process_info(Pid) of
    	undefined ->
    	    none;
    	_ ->
    	    Pid ! {last_call, self()},
		    receive
		        {last_call, A} ->
		            A
		    end
    end.

check_equal(Mod, Ln, Expected, Actual) ->
    if 
        Expected == Actual ->
           io:format('.');
        true ->
           io:format("Module[~p] Line[~p] failed:: Expected:~p, Actual:~p, ~n", [Mod, Ln, Expected, Actual])
    end.

%%%
mockobj_loop(L) ->
    receive
        {call_api, D} ->
            %io:format("call_api:~p ~n", [D]),
            mockobj_loop([D|L]);
        {last_call, Pid} ->
            %io:format("current L:~p ~n", [L]),
            case L of
                [] ->
                    Pid ! {last_call, none},
                    mockobj_loop([]);
                [L1|T] ->
                    %io:format("returned:~p ~n", [L1]),
                    Pid ! {last_call, L1},
                    mockobj_loop(T)
            end;
        stop ->
            ok;
        Anyother ->
            mockobj_loop([Anyother|L])
    end.