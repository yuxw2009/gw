%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/focus
%%%------------------------------------------------------------------------------------------
-module(focus_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle get all focus items
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Items = get_all_focus_items(UUID, utility:client_ip(Arg)),

    ItemFun = fun({Type, Tags, Timestamp, Item}) ->
                  ContentSpec =
                      case Type of
                          tasks  -> [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies, traces,status];
                          topics -> [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies]
                      end,
                  utility:a2jso([type, tags,
                                {timestamp, fun erlang:list_to_binary/1},
                                {content, fun(V) -> utility:a2jso(ContentSpec, V) end}], [Type, Tags, Timestamp, Item])      
              end,
    utility:pl2jso([{status, ok}, {focus, [ItemFun(I) || I<-Items]}]);
%% handle focus an item request
handle(Arg, 'POST', ["entities"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    ItemJSOs = utility:get(Json, "items"),
    Items = [{utility:get_atom(Obj, "type"), utility:get_integer(Obj, "entity_id"), 
              utility:get_binary(Obj, "tags")
             }  || Obj <- ItemJSOs],


    ok = focus_entity(UUID, Items, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle stop focus an item request
handle(Arg, 'DELETE', ["entities", Type, EntityId]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    ok = stop_focus_entity(UUID, utility:atom(Type), list_to_integer(EntityId), utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]).

%%% RPC calls
-include("snode.hrl").

get_all_focus_items(UUID,SessionIP) ->
    io:format("get_all_focus_items ~p~n",[UUID]),
    %%[{topics, [<<"aaa">>], "2012-9-08 23:4:5", {1,  88, "2012-7-8 23:4:5", <<"content1">>, 2}},
    %% {tasks,  [<<"aab">>], "2012-9-05 23:4:5", {1,  90, "2012-7-8 23:4:5", <<"content1">>, 2, 4, finished}}
    %%].
    {value, AllFocus} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_focus, get_all, [UUID], SessionIP]),
     %%io:format("AllFocus ~p~n",[AllFocus]),
    AllFocus.

  %%[{Type, Tags}]
focus_entity(UUID, Items, SessionIP) ->
    io:format("focus_entity ~p ~p ~n",[UUID, Items]),
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_focus, set, [UUID, Items], SessionIP]),
    ok.

stop_focus_entity(UUID, Type, EntityId,SessionIP) ->
    io:format("stop_focus_entity ~p ~p ~p~n",[UUID, Type, EntityId]),
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_focus, cancel, [UUID, Type, EntityId], SessionIP]),
    ok.