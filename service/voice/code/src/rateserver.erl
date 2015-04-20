-module(rateserver).
-compile(export_all).

start_monitor() ->
    {Pid,_}=spawn_monitor(fun()-> init() end),
    register(?MODULE,Pid),
    Pid.

lookup(BillId,Phone1,Phone2) ->
    ?MODULE ! {self(),{lookup,BillId,Phone1,Phone2}},
    receive
        R -> R
    end.

init() ->
    loop().

loop() ->
    receive
        {From,{lookup,_BillId,Phone1,Phone2}} ->
            From ! {ok,{Phone1,0.1},{Phone2,0.1}},
            loop()
    end.