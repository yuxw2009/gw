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
-define(INTERVAL,3000).
-record(trace_item,{id,tracedip,signals=[],filter_func,sendfunc}).
-record(state, {
               trace_items=[],
		traced_ip=""
	       }).

start()->
    case whereis(?MODULE) of
    undefined->    
        {ok,Pid}=my_server:start({local,?MODULE}, ?MODULE,[],[]),
        Pid;
    P-> P
    end.
stop()-> exit(whereis(?MODULE),kill).
show()->
    F = fun(State)-> 
             {State, State} 
         end,
    my_server:call(?MODULE, {command, F}).

add_traced_func(Ip,{Id,Func,SendFunc})->
    F = fun(State=#state{trace_items = Items})-> 
             io:format("add_traced_func9999999999999999999999999~n"),
             if Items==[]-> sipsocket_udp:add_trace_pid(self()); true-> void end,
             {ok, State#state{trace_items=lists:keystore(Id,#trace_item.id,Items,#trace_item{id=Id,tracedip=Ip,filter_func=Func,sendfunc=SendFunc})}} 
         end,
    NicNode=list_to_atom("nic@"++binary_to_list(Ip)),
    {signal_trace,NicNode} ! {command, F}.
add_traced_func({Id,Func,SendFunc})->
    F = fun(State=#state{trace_items = Items})-> 
             if Items==[]-> sipsocket_udp:add_trace_pid(self()); true-> void end,
             {ok, State#state{trace_items=lists:keystore(Id,#trace_item.id,Items,#trace_item{id=Id,filter_func=Func,sendfunc=SendFunc})}} 
         end,
    my_server:call(?MODULE, {command, F}).
    
delete_traced_func(Ip,Id)->
    F = fun(State=#state{trace_items = Items})-> 
             NItems=lists:keydelete(Id,#trace_item.id,State#state.trace_items),
             if NItems==[]-> sipsocket_udp:delete_trace_pid(self()); true-> void end,
             {ok, State#state{trace_items=NItems}} 
         end,
    NicNode=list_to_atom("nic@"++binary_to_list(Ip)),
    {signal_trace,NicNode} ! {command, F}.

delete_traced_func(Id)->
    F = fun(State=#state{trace_items = Items})-> 
             NItems=lists:keydelete(Id,#trace_item.id,State#state.trace_items),
             if NItems==[]-> sipsocket_udp:delete_trace_pid(self()); true-> void end,
             {ok, State#state{trace_items=NItems}} 
         end,
    my_server:call(?MODULE, {command, F}).

init([]) ->
    my_timer:send_interval(?INTERVAL, trace_time),
    {ok,#state{}}.

handle_call({command, F}, _From, State) ->
    {Result, NewState} = F(State),
    {reply, Result,NewState};
handle_call(_, _From,  State) ->
    {reply, ok, State}.
handle_cast(Unknown, State) ->
    {noreply, State}.
handle_info({command, F}, State) ->
             io:format("signal_trace:handle_info{command, F}~n"),
    {_, NewState} = F(State),
    {noreply,NewState};
handle_info(trace_time,State=#state{trace_items=Items})->
    Fun=fun(Item=#trace_item{id=Id,tracedip=Ip,signals=Signals,sendfunc=SendFunc})-> 
                if length(Signals)>0-> SendFunc(rfc4627:encode(utility:pl2jso_br([{id,Id},{ip,Ip},{signals,lists:reverse(Signals)}]))); 
                    true-> void 
                end,
                Item#trace_item{signals=[]} 
           end,
    Nitems=[Fun(Item)||Item=#trace_item{}<-Items],
    {noreply,State#state{trace_items=Nitems}};
handle_info({udp, _Socket, IPtuple, InPortNo, Packet}, State=#state{}) when is_integer(InPortNo) ->
    NState=trace(recv, siphost:makeip(IPtuple), InPortNo, Packet, State),
    {noreply, NState};
handle_info({send,udp,_SipSocket, IPStr, InPortNo, Message}, State=#state{}) when is_integer(InPortNo) ->
    NState=trace(send, IPStr, InPortNo, Message, State),
    {noreply, NState};
handle_info(Unhandled, State=#state{}) ->
    io:format("signal_trace:handle_info ~p not handled~n",[Unhandled]),
    {noreply, State}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
terminate(Reason, _State) ->
    ok.


need_traced(Ip,_Mess, Ip)-> true;
need_traced(_Ip,_Mess, <<>>)-> true;
need_traced(_Ip,_Mess, Traced) when not is_binary(Traced)-> false;
need_traced(_Ip,_Mess, <<"255.255.255.255">>)-> true;
need_traced(_Ip,Mess, TracedStr)->
   not (re:run(Mess,TracedStr) == nomatch).

trace(Direction, Host, Port, Message,State=#state{trace_items=Items})->
    {ok,Lport}=yxa_config:get_env(listenport),
    LIpPort=sipcfg:myip()++":"++integer_to_list(Lport),
    SsIpPort=Host++":"++integer_to_list(Port),

    Fun=fun(Item=#trace_item{signals=Signals,filter_func=FilterFun})->
                FilterRes=FilterFun({LIpPort,SsIpPort,Message,Direction}),
            %io:format("signaltrace:trace~p~n",[FilterRes]),
                if FilterRes=/=not_need -> Item#trace_item{signals=[FilterRes|Signals]}; 
                true-> Item 
                end
            end,
    NewItems=[Fun(Item)||Item=#trace_item{}<-Items],
    State#state{trace_items=NewItems}.
    
