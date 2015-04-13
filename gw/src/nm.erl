-module(nm).
-compile(export_all).

start() ->
    register(?MODULE, spawn(fun() -> init() end)).

get() ->
    ?MODULE ! {get_reasons, self()},
    receive
    	{value, Reasons} -> Reasons
    	after 5000 -> timeout
    end.

init() ->
    Pid = case whereis(net_stats) of
    	    undefined -> net_stats:start();
    	    NP        -> NP
    	  end,
    erlang:monitor(process, Pid),
    loop(Pid, []).

loop(Pid, Reasons) ->
    receive
         {'DOWN', _Ref, process, Pid, R} ->
             Pid2 = net_stats:start(),
             erlang:monitor(process, Pid2),
             loop(Pid2, [R|Reasons]);
         {get_reasons, From} ->
             From ! {value, Reasons},
             loop(Pid, Reasons);
         _   -> 
             loop(Pid, Reasons)
    end.