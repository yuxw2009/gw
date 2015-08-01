-module(llog).
-compile(export_all).

-define(SysLog, "./wrtc.log").
-define(BakLog, "./wrtclog.bak").

-define(LOGMAXSIZE, 20000000).
-define(BUFMAXSIZE, 400*1000).
-record(st,{fd,bufs= <<>>}).

init([]) ->
	{ok, Handle} = file:open(?SysLog, [append]),
	io:fwrite(Handle, ts() ++ " llog start.\n", []),
	timer:send_interval(60000,check_file),		% 1 minute
	timer:send_interval(2000,write_file_timeout),		% 10s write once
	{ok, #st{fd=Handle}}.

recre()-> ?MODULE ! recreate_file.

handle_info({From, Format}, ST=#st{fd=Handle}) ->
	io:fwrite(Handle, ts() ++ " ~p : "++Format++"\n", [From]),
	{noreply, ST};
handle_info({From, Format, Args}, ST=#st{fd=Handle,bufs=Bufs}) ->
    Bin = iolist_to_binary(io_lib:format(ts() ++ " ~p : "++Format++"\n", [From|Args])),
    NewBufs = <<Bufs/binary,Bin/binary>>,
    case size(NewBufs) > ?BUFMAXSIZE of
    true->    
        io:fwrite(Handle, NewBufs,[]),
        {noreply, ST#st{bufs= <<>>}};
    _-> 
        {noreply, ST#st{bufs=NewBufs}}
    end;
    
handle_info(write_file_timeout, ST=#st{fd=Handle,bufs=Bufs}) ->
    case size(Bufs) > 0 of
    true->    
        io:fwrite(Handle, "~s",[Bufs]),
        {noreply, ST#st{bufs= <<>>}};
    _-> 
        {noreply, ST}
    end;
    
handle_info(recreate_file,ST=#st{fd=Handle}) ->
	file:close(Handle),
	file:rename(?SysLog, "wrtc-"++ts()++".log"),
	{ok, NewHd} = file:open(?SysLog, [append]),
	{noreply, ST#st{fd=NewHd}};

handle_info(check_file,ST=#st{fd=Handle}) ->
	NewHd = chkfilesize(Handle),
	{noreply, ST#st{fd=NewHd}}.

handle_cast(stop, ST=#st{fd=Handle}) ->
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
	{_,_,MS}=erlang:now(),
	xt:int2(Y) ++ "-" ++ xt:int2(Mo) ++ "-" ++ xt:int2(D) ++ " " ++ xt:int2(H) ++ ":" ++ xt:int2(Mi) ++ ":" ++ xt:int2(S)++":"++xt:int2(MS).

% ----------------------------------
start() ->
    case whereis(llog) of
    undefined->
	{ok, L} = my_server:start({local,llog},?MODULE, [], []),
	L;
    P->P
    end.

stop() ->
	my_server:cast(llog, stop).
log(F,P) ->
	case whereis(llog) of
		undefined -> void;%io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, [utility:term_to_list(I)||I<-P]}
	end,
    void.
	
