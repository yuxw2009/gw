-module(fsguard).
-compile(export_all).

on_exit(Pid, Fun) ->
    spawn(fun() ->
                        process_flag(trap_exit, true),
                        link(Pid),
                        receive
                            {'EXIT', Pid, Why} ->
                                {ok, S} = file:open("errlog.data", [append]),
                                io:format(S, "~p  ~p~n~p~n" ,[date(), time(), Why]), 
                                file:close(S),
                                Fun(Why)
                        end
                end).

start() ->
	{ok,Pid} = my_server:start(fid,[],[]),
    register(sfid, Pid),
    on_exit(Pid, fun(_Why) -> start() end).
