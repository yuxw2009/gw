%#!/usr/bin/env escript
-module(amqp_send).
-compile(export_all).
%%!  -pa /home/ubuntu/rabbitmq-erlang-client/ebin -pa /home/ubuntu/rabbitmq-erlang-client/deps/*/ebin -s lager
% -pz ./amqp_client ./rabbit_common ./amqp_client/ebin ./rabbit_common/ebin

-include_lib("amqp_client/include/amqp_client.hrl").

send(Payload)->send(<<"oam_config">>,Payload,undefined,undefined).
send(Queue,Payload)->send(Queue,Payload,undefined).
send(Queue,Payload,CorrId)->send(Queue,Payload,CorrId,undefined).

send(QueueName,Payload,CorrId,ReplyTo) when is_list(Payload)->send(QueueName,list_to_binary(Payload),CorrId,ReplyTo);
send(undefined,_Payload,_CorrId,_) -> void;
send(QueueName,Payload,CorrId,ReplyTo) when is_list(QueueName)-> send(list_to_binary(QueueName),Payload,CorrId,ReplyTo);
send(QueueName,Payload,CorrId,ReplyTo) ->
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = "103.198.18.35"}),
    {ok, Channel} = amqp_connection:open_channel(Connection),

    amqp_channel:call(Channel, #'queue.declare'{queue = QueueName}),

    amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = QueueName},
                      #amqp_msg{payload = Payload,props=#'P_basic'{correlation_id=CorrId,reply_to=ReplyTo}}),
    %io:format(" [x] Sent ~p~n",[{Payload,QueueName,ReplyTo,CorrId}]),
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.

send1(QueueName,Payload) ->
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = "localhost"}),
    {ok, Channel} = amqp_connection:open_channel(Connection),

    amqp_channel:call(Channel, #'queue.declare'{queue = QueueName}),

    amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = QueueName},
                      #amqp_msg{payload = Payload,props=#'P_basic'{correlation_id=undefined,reply_to=undefined}}),
    io:format(" [x] Sent ~p~n",[Payload]),
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.

