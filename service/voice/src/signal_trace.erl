-module(signal_trace).
-compile(export_all).
-define(ALL_IP, "255.255.255.255").

-behaviour(gen_server).

%% Internal exports - gen_server callbacks
%%--------------------------------------------------------------------
-export([
	 init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).

-record(state, {inet_socketlist  = [],	%% list() of {Socket, SipSocket}
		inet6_socketlist = [],	%% list() of {Socket, SipSocket}
		socketlist,
		fd,
		traced_ip=""
	       }).

start()->
	start(?ALL_IP).

start(Ip)->
	sipsocket_udp:config_traced_ip(Ip).

stop()->
	sipsocket_udp:config_traced_ip(null).

show()->
	sipsocket_udp:show_traced_ip().
	
init([]) ->
    {ok,#state{}}.

handle_call(_, _From,  State) ->
    {reply, ok, State}.
handle_cast(Unknown, State) ->
    {noreply, State}.
handle_info({udp, Socket, IPtuple, InPortNo, Packet}, State=#state{}) when is_integer(InPortNo) ->
    trace(recv, siphost:makeip(IPtuple), InPortNo, Packet, State),
    {noreply, State}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
terminate(Reason, _State) ->
    ok.


need_traced(Ip,_Mess, Ip)-> true;
need_traced(_Ip,_Mess, "")-> false;
need_traced(_Ip,_Mess, Traced) when not is_list(Traced)-> false;
need_traced(_Ip,_Mess, "255.255.255.255")-> true;
need_traced(_Ip,Mess, TracedStr)->
   not (re:run(Mess,TracedStr) == nomatch).

trace(send, Host, Port, Message, State)->
    trace("<=== ", Host, Port, Message, State);
trace(recv, Host, Port, Message, State)->
    trace("===> ", Host, Port, Message, State);
trace(Prefix, Host, Port, Message, _State=#state{traced_ip=TraceIp, fd=Fd})->
    case need_traced(Host,Message, TraceIp) of
    true->  io:format(Fd, "~p ~p ~p:~p:~n~s~n",[Prefix, calendar:local_time(), Host, Port, Message]);
    _ -> void
    end.
    
    
