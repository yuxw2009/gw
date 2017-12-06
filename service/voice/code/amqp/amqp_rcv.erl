-module(amqp_rcv).
-compile(export_all).

-include_lib("amqp_client/include/amqp_client.hrl").

spawn_rcv(Callback)-> spawn_rcv(Callback,<<"oam_config">>).

spawn_rcv(Callback,QueueName)->
    spawn(fun()-> recv(Callback,QueueName) end).


wait_for_death(Pid) ->
    Ref = erlang:monitor(process, Pid),
    receive
        {'DOWN', Ref, process, Pid, _Reason} ->
            ok
    after 1000 ->
            exit({timed_out_waiting_for_process_death, Pid})
    end.

teardown_amqp(Channel,Connection)->
                               amqp_channel:close(Channel),
                               wait_for_death(Channel),
                               amqp_connection:close(Connection),
                               wait_for_death(Connection).

stop()->
    F=fun(State=[Channel,_Callback,QueueName,Connection|_T])->
           {teardown_amqp(Channel,Connection),State}
        end,
    call(F).
call(F)->
    oam_config_amqp! {act,F,self()},
    receive
        R-> R
    after 1000->
        timeout
    end.
recv(Callback,QueueName) when is_list(QueueName)-> recv(Callback,list_to_binary(QueueName) );
recv(Callback,QueueName) ->
    erlang:group_leader(whereis(user), self()),
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = "103.198.18.35"}),
    {ok, Channel} = amqp_connection:open_channel(Connection),

    amqp_channel:call(Channel, #'queue.declare'{queue = QueueName}),
    io:format(" [*] Waiting for messages. queue:~p~n",[QueueName]),
    amqp_channel:subscribe(Channel, #'basic.consume'{queue = QueueName,no_ack=true}, self()),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    loop([Channel,Callback,QueueName,Connection]).


loop(State=[Channel,Callback,QueueName|T]) ->
    receive
        {callback,CallBack1}->
        io:format("*****loop ~p~n",[CallBack1]),
        loop([Channel,CallBack1,QueueName|T]);
        {act,F,From}->
            {Res,NSt}=F(State),
            From ! Res,
            loop(NSt);
        {#'basic.deliver'{}, #amqp_msg{payload = Body,props = #'P_basic'{correlation_id=CorrId, reply_to=ReplyTo}}} ->
            io:format(" [queue:~p] Received ~p~n", [QueueName,Body]),
            SendFun= fun(Payload_Ack)->
                                %io:format(" [q:~p] sendack:~p~n", [QueueName,{Payload_Ack,ReplyTo,CorrId}]),
                                case catch amqp_send:send(ReplyTo,Payload_Ack,CorrId) of
                                   {'EXIT',Reason_}-> io:format("[q:~p]sendack exception,reason:~p~n",[QueueName,Reason_]);
                                   Other-> Other
                                end
                            end,
            case catch Callback(Body,SendFun) of
                {need_ack,Payload_Ack}->
                    SendFun(Payload_Ack);
                {'EXIT',Reason}->
                    logger:log(error,"amqp_rcv callback exception for queue:~p channel ~p reason:~p~n",[QueueName,Channel,Reason]),
                    SendFun(rfc4627:encode(utility:pl2jso_br(conf_intf:result_plist(false,[],utility:term_to_list(Reason),1,1))));
                    
                _-> void
            end,
            loop(State)
    end.

