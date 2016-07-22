-module(llog).
-compile(export_all).

-define(SysLog, "./data/sms.log").
-define(BakLog, "./data/smslog.bak").

init([]) ->
	{ok, Handle} = file:open(?SysLog, [append]),
	io:fwrite(Handle, ts() ++ " llog start.\n", []),
	{ok, Handle}.

handle_info({From, Format}, Handle) ->
	NewHd = chkfilesize(Handle),
	io:fwrite(NewHd, ts() ++ " ~p : "++Format++"\n", [From]),
	{noreply, NewHd};
handle_info({From, Format, Args}, Handle) ->
	io:fwrite(Handle, ts() ++ " ~p : "++Format++"\n", [From|Args]),
	{noreply, Handle}.

handle_cast(stop, Handle) ->
	io:fwrite(Handle, ts() ++ " llog stopped.\n", []),
	file:close(Handle),
	{stop, normal, []}.

terminate(normal, _) ->
	io:format("little log stopped.~n"),
	ok.

chkfilesize(LogHd) ->
	case file:read_file_info(?SysLog) of
		{ok, Finfo} ->
		io:format("file ~p~n", [Finfo]),
			if
				element(2, Finfo) > 200000 ->
					file:close(LogHd),
					file:copy(?SysLog, ?BakLog),
					file:delete(?SysLog),
					{ok, NewHd} = file:open(?SysLog, [append]),
					NewHd;
				true ->
					LogHd
			end;
		{error, _} ->
			file:delete(?SysLog),
			{ok, FH} = file:open(?SysLog, [append]),
			FH
	end.

% ----------------------------------
ts() ->
	{Y, Mo, D} = date(),
	{H, Mi, S} = time(),
	xt:int2(Y) ++ "/" ++ xt:int2(Mo) ++ "/" ++ xt:int2(D) ++ "," ++ xt:int2(H) ++ ":" ++ xt:int2(Mi) ++ ":" ++ xt:int2(S).

% ----------------------------------
start() ->
	{ok, L} = my_server:start(llog, [], []),
	register(llog, L).

stop() ->
	my_server:cast(llog, stop).
