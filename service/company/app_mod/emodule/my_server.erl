-module(my_server).
-compile(export_all).

start(Module, Arg, _Options) ->
	Svr = spawn(fun() -> 
					case Module:init(Arg) of
						{ok, State} ->
							loop(Module, State);
						{ok, State, TimeOut} ->
							timer:send_after(TimeOut, {my_server_timeout, TimeOut}),
							loop(Module, State)
					end
			    end),
	{ok, Svr}.

cast(Svr, Msg) ->
	Svr ! {self(), {cast, Msg}},
	ok.

call(Svr, Msg) ->
	Ref = make_ref(),
	Svr ! {self(), {call, Ref, Msg}},
	receive
		{reply, Ref, Reply} ->
			Reply
%	after 20000 ->
%	    timeout
	end.

%% ---------------------------------------------	

loop(Module, State) ->
	receive
		Msg ->
			lprocess(Msg, Module, State)
	end.

lprocess({_From, {cast, Msg}}, Module, State) ->
			case Module:handle_cast(Msg, State) of
				{noreply, NewState} ->
					loop(Module, NewState);
				{noreply, NewState, Timeout} ->
					timer:send_after(Timeout, {my_server_timeout, Timeout}),
					loop(Module, NewState);
				{stop, Reason, NewState} ->
					Module:terminate(Reason, NewState)
			end;
lprocess({From, {call, Tag, Msg}}, Module, State) ->			
			case Module:handle_call(Msg, {From, Tag}, State) of
				{reply, Reply, NewState} ->
					reply({From, Tag}, Reply),
					loop(Module, NewState);
				{noreply, NewState} ->
					loop(Module, NewState)
			end;
lprocess({my_server_timeout, _T}, Module, State) ->
	case Module:handle_info(timeout, State) of
		{noreply, NewState, NewTime} ->
			timer:send_after(NewTime, {my_server_timeout, NewTime}),
			loop(Module, NewState);
		{noreply, NewState} ->
			loop(Module, NewState);
		{stop, Reason, NewState} ->
			Module:terminate(Reason, NewState)
	end;
lprocess(Msg, Module, State) ->
	case Module:handle_info(Msg, State) of
		{noreply, NewState} ->
			loop(Module, NewState);
		{stop, Reason, NewState} ->
			Module:terminate(Reason, NewState)
	end.

reply({Pid, Tag}, Reply) ->
	Pid ! {reply, Tag, Reply}.