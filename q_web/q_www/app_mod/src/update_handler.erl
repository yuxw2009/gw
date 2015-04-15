%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/updates
%%%------------------------------------------------------------------------------------------
-module(update_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle interval poll request
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Updates = poll_updates(UUID, utility:client_ip(Arg)),

    utility:pl2jso([{tasks_finished, fun(V) -> 
    	                                 utility:a2jsos([entity_id, {finished_time, fun erlang:list_to_binary/1}], V) 
    	                             end}], 
    	           [{status, ok}] ++ Updates).


%%% RPC calls
-include("snode.hrl").

poll_updates(UUID, Ip) ->
    {value, Updates} = rpc:call(snode:get_service_node(), lw_instance, poll_updates, [UUID, Ip]),
%    io:format("www poll_updates result:~p Ip:~p ~n",[Updates, Ip]),
    Updates.

    %%[{onlines, [1,4]}, {offlines, [2, 5]}, {news, 5}, 
    %% {polls, 5}, {documents, 5}, {topics, [4, 5]},  {questions, [5,7]}, {tasks, [4,5]},
    %% {tasks_finished, [{34, "2012-8-34 12:34:5"}]}].
    
 


