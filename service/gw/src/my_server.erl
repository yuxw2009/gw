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
	Ref = make_ref(),
	Svr ! {self(), {call, Ref, Msg}},
	receive
		{reply, Ref, Reply} ->
			Reply
	after ?CALLTIMEOUT ->
	    timeout
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
			case catch Module:handle_cast(Msg, State) of
				{noreply, NewState} ->
					loop(Module, NewState, infinity);
                         {stop, Reason, NewState} -> Module:terminate(Reason, NewState);
                          R-> 
                              utility:log("log/server_error.log","~p myserver excpt:~p",[Module,R]),
                              Module:terminate(myserver_exception, State)
			end;
lprocess({From, {call, Tag, Msg}}, Module, State) ->			
			case  catch Module:handle_call(Msg, {From, Tag}, State) of
				{reply, Reply, NewState} ->
					reply({From, Tag}, Reply),
					loop(Module, NewState, infinity);
%			      {'EXIT',Reason}-> Module:terminate(Reason, State);
				{noreply, NewState} ->
					loop(Module, NewState, infinity);
				{stop, Reason, Reply, NewState} ->
					reply({From, Tag}, Reply),
				    Module:terminate(Reason, NewState);
                           R-> 
                              utility:log("server_error.log","~p myserver excpt:~p",[Module,R]),
                               Module:terminate(myserver_exception, State)
			end;
lprocess({my_server_timeout, _T}, Module, State) ->
	case  catch Module:handle_info(timeout, State) of
		{noreply, NewState, NewTime} ->
			loop(Module, NewState,NewTime);
		{noreply, NewState} ->
			loop(Module, NewState, infinity);
		{stop, Reason, NewState} -> Module:terminate(Reason, NewState);
	      R-> 
                              utility:log("server_error.log","~p myserver excpt:~p",[Module,R]),
	          Module:terminate(myserver_exception, State)
	end;
lprocess(Msg, Module, State) ->
	case  catch Module:handle_info(Msg, State) of
		{noreply, NewState, NewTime} ->
			loop(Module, NewState,NewTime);
		{noreply, NewState} ->
			loop(Module, NewState, infinity);
		{stop, Reason, NewState} -> Module:terminate(Reason, NewState);
	      R-> 
                              utility:log("server_error.log","~p myserver excpt:~p~nmsg:~p",[Module,R,Msg]),
	          Module:terminate(myserver_exception, State)
	end.

reply({Pid, Tag}, Reply) ->
	Pid ! {reply, Tag, Reply}.

