-module(my_timer).
-compile(export_all).

-define(INTERVAL,10).
-define(CHECKPOINT,20).

-record(ur,{
	type,
	ref,
	tk1,
	tk2,
	pid,
	msg
}).

-record(st,{
	start_time,
	ticks,
	users
}).

init([]) ->
	register(my_timer,self()),
	timer:send_interval(?INTERVAL,time_out),
	{ok,#st{start_time=now(),ticks=0,users=[]}}.

handle_call({register_interval,Pid,Tks,Msg},_From,#st{users=Us}=ST) ->
	Ref = make_ref(),
	{reply,{ok,Ref},ST#st{users=[#ur{type=1,ref=Ref,tk1=Tks,tk2=Tks,pid=Pid,msg=Msg}|Us]}};
handle_call({register_timer,Pid,Tks,Msg},_From,#st{users=Us}=ST) ->
	Ref = make_ref(),
	{reply,{ok,Ref},ST#st{users=[#ur{type=0,ref=Ref,tk1=Tks,tk2=Tks,pid=Pid,msg=Msg}|Us]}};
handle_call({cancel_timer,Ref},_From,#st{users=Us}=ST) ->
	{reply,{ok,cancel},ST#st{users=lists:keydelete(Ref,#ur.ref,Us)}};
handle_call(get_info,_From,#st{users=Us}=ST) ->
	{reply,Us,ST}.
	

handle_info(time_out,#st{users=Us,ticks=Tcks}=ST) ->
	Us2 = processUS(Us),
	{Tcks2,Us3} = processFlush(Tcks,Us2),
	{noreply,ST#st{users=Us3,ticks=Tcks2}};
handle_info(_Msg,ST) ->
	{noreply,ST}.

handle_cast(stop,#st{start_time=Stt}) ->
	llog("my_timer stopped after ~ps",[timer:now_diff(now(),Stt) div 1000000]),
	{stop,normal,[]}.

terminate(_,_) ->
	ok.
% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

processFlush(Tcks,Us) when Tcks>=1000 ->
	{0,flush_dead(Us)};
processFlush(Tcks,Us) ->
	{Tcks+1,Us}.

flush_dead([]) ->
	[];
flush_dead([#ur{pid=Pid}=U|T]) ->
	case is_process_alive(Pid) of
		true ->
			[U|flush_dead(T)];
		_ ->
			flush_dead(T)
	end.

processUS(Us) ->
	processUS(Us,[]).

processUS([],Us) ->
	lists:reverse(Us);
processUS([#ur{type=1,tk1=0,tk2=T2,pid=Pid,msg=Msg}=U|Us1],Us2) ->
	Pid ! Msg,
	processUS(Us1,[U#ur{tk1=T2-1}|Us2]);
processUS([#ur{type=0,tk1=0,pid=Pid,msg=Msg}|Us1],Us2) ->
	Pid ! Msg,
	processUS(Us1,Us2);
processUS([#ur{tk1=T1}=U|Us1],Us2) ->
	processUS(Us1,[U#ur{tk1=T1-1}|Us2]).

send_after(T,Msg) when T<10 ->
	timer:send_after(T,Msg);
send_after(T,Msg) ->
	my_server:call(my_timer,{register_timer,self(),T div 10,Msg}).
send_interval(T,Msg) ->
	my_server:call(my_timer,{register_interval,self(),T div 10,Msg}).
cancel(TRef) ->
	my_server:call(my_timer,{cancel_timer,TRef}).

start() ->
	{ok,Pid} = my_server:start(?MODULE,[],[]),
	Pid.

stop() ->
	my_server:cast(my_timer,stop).
	
