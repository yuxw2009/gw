-module(listen).
-compile(export_all).

at(Port) ->
	{ok,Socket} = gen_udp:open(Port, [binary, {active, true}, {recbuf, 4096}]),
	Pid = spawn(fun() -> moni(Socket) end),
	gen_udp:controlling_process(Socket, Pid),
	Pid.

moni(Sock) ->
	receive
		stop ->
			gen_udp:close(Sock),
			io:format("udp ~p closed.~n",[Sock]),
			ok;
		{udp,Socket,Addr,Port,Bin} ->
			io:format("udp received from ~p ~p:~p~n~p~n",[Socket,Addr,Port,Bin]),
			moni(Sock);
		Msg ->
			io:format("unknow ~p~n",[Msg]),
			moni(Sock),
			ok
	end.