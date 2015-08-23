-module(my_server).
-compile(export_all).

-define(CALLTIMEOUT, 5000).

start({local,Name}, Module, Arg, Options) ->
    case whereis(Name) of
    undefined->
	 {ok, Svr} = start(Module, Arg, Options),
        register(Name,Svr);
    Svr-> void
    end,
    {ok, Svr}.
	
start(Module, Arg, _Options) ->
	Svr = spawn(fun() -> 
					case Module:init(Arg) of
						{ok, State} ->
							loop(Module, State, infinity);
						{ok, State, TimeOut} ->
							loop(Module, State, TimeOut);
						ignore ->
							ignore
					end
			    end),
	{ok, Svr}.

cast(undefined, _Msg) -> void;
cast(Svr, Msg) when is_atom(Svr)-> cast(whereis(Svr),Msg);
cast(Svr, Msg) ->
	Svr ! {self(), {cast, Msg}},
	ok.

call(undefined, _Msg) -> void;
call(Svr, Msg) when is_atom(Svr)-> call(whereis(Svr),Msg);
call(Svr, Msg) when is_pid(Svr)->
    case is_process_alive(Svr) of
    true->
        Ref = make_ref(),
        Svr ! {self(), {call, Ref, Msg}},
        receive
        	{reply, Ref, Reply} ->
        		Reply
        after ?CALLTIMEOUT ->
            timeout
        end;
    false-> void
    end;
call(_Svr, _Msg) ->	void.

%% ---------------------------------------------	
loop(Module, State, TimeOut) ->
	receive
		Msg ->
			lprocess(Msg, Module, State)
	after TimeOut ->
		lprocess({my_server_timeout,TimeOut}, Module, State)
	end.

lprocess({_From, {cast, Msg}}, Module, State) ->
			case Module:handle_cast(Msg, State) of
				{noreply, NewState} ->
					loop(Module, NewState, infinity);
				{stop, Reason, NewState} ->
					Module:terminate(Reason, NewState)
			end;
lprocess({From, {call, Tag, Msg}}, Module, State) ->			
			case Module:handle_call(Msg, {From, Tag}, State) of
				{reply, Reply, NewState} ->
					reply({From, Tag}, Reply),
					loop(Module, NewState, infinity);
				{stop, Reason, Reply, NewState} ->
				    Module:terminate(Reason, NewState),
					reply({From, Tag}, Reply);
				{noreply, NewState} ->
					loop(Module, NewState, infinity)
			end;
lprocess({my_server_timeout, _T}, Module, State) ->
	case Module:handle_info(timeout, State) of
		{noreply, NewState, NewTime} ->
			loop(Module, NewState,NewTime);
		{noreply, NewState} ->
			loop(Module, NewState, infinity);
		{stop, Reason, NewState} ->
			Module:terminate(Reason, NewState)
	end;
lprocess(Msg, Module, State) ->
	case Module:handle_info(Msg, State) of
		{noreply, NewState, NewTime} ->
			loop(Module, NewState,NewTime);
		{noreply, NewState} ->
			loop(Module, NewState, infinity);
		{stop, Reason, NewState} ->
			Module:terminate(Reason, NewState)
	end.

reply({Pid, Tag}, Reply) ->
	Pid ! {reply, Tag, Reply}.
