-module(llog).
-compile(export_all).

-define(SysLog, "./wrtc.log").
-define(BakLog, "./wrtclog.bak").

-define(LOGMAXSIZE, 20000000).

init([]) ->
	{ok, Handle} = file:open(?SysLog, [append]),
	io:fwrite(Handle, ts() ++ " llog start.\n", []),
	timer:send_interval(60000,check_file),		% 1 minute
	{ok, Handle}.

handle_info({From, Format}, Handle) ->
	io:fwrite(Handle, ts() ++ " ~p : "++Format++"\n", [From]),
	{noreply, Handle};
handle_info({From, Format, Args}, Handle) ->
	io:fwrite(Handle, ts() ++ " ~p : "++Format++"\n", [From|Args]),
	{noreply, Handle};
handle_info(check_file,Handle) ->
	NewHd = chkfilesize(Handle),
	{noreply, NewHd}.

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
			if
				element(2, Finfo) > ?LOGMAXSIZE ->
					file:close(LogHd),
					file:rename(?SysLog, "wrtc-"++ts()++".log"),
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
	xt:int2(Y) ++ "-" ++ xt:int2(Mo) ++ "-" ++ xt:int2(D) ++ " " ++ xt:int2(H) ++ "-" ++ xt:int2(Mi) ++ "-" ++ xt:int2(S).

% ----------------------------------
start() ->
	{ok, L} = my_server:start({local,llog},?MODULE, [], []),
	L.

stop() ->
	my_server:cast(llog, stop).