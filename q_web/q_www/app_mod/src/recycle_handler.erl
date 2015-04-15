%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/recycle
%%%------------------------------------------------------------------------------------------
-module(recycle_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle get all garbage items
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Items = get_all_garbages(UUID, utility:client_ip(Arg)),
    ItemFun = fun({Type, Timestamp, Item}) ->
                  ContentSpec =
                      case Type of
                          documents  -> [entity_id, from, content, name, file_id, file_length, {timestamp, fun erlang:list_to_binary/1}];
                          polls      -> [entity_id, from, content, {timestamp, fun erlang:list_to_binary/1}];
                          _         ->  [entity_id, from, content, {timestamp, fun erlang:list_to_binary/1}]
                      end,
                  utility:a2jso([type, 
                                {timestamp, fun erlang:list_to_binary/1},
                                {content, fun(V) -> utility:a2jso(ContentSpec, V) end}], [Type, Timestamp, Item])      
              end,
    utility:pl2jso([{status, ok}, {recycle, [ItemFun(I) || I<-Items]}]);

%% handle delete garbage items
handle(Arg, 'PUT', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Action = utility:get_atom(Json, "action"),
    ItemJSOs = utility:get(Json, "items"),
    Items = [{utility:get_atom(Obj, "type"), utility:get_atom(Obj, "ownership"), 
              utility:get_integer(Obj, "entity_id")}  || Obj <- ItemJSOs],

    ok = manipulate_entitis(UUID, Action, Items, utility:client_ip(Arg)),
     utility:pl2jso([{status, ok}]).
    
%%% RPC calls
-include("snode.hrl").

get_all_garbages(UUID, SessionIP) -> 
    io:format("get_all_garbages ~p~n",[UUID]),
    {value, Gar} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_dustbin, get_all_garbages, [UUID], SessionIP]),
   
    Gar.
    %%[{tasks, "2012-7-8 23:4:5", {123, 88, <<"task_content">>, "2012-7-8 23:4:5"}},
    %% {documents, "2012-7-8 23:4:5", {123, 88, <<"doc_description">>, "name", 1234, 444444, "2012-7-8 23:4:5"}}
    %%].

manipulate_entitis(UUID, Action, Items, SessionIP) ->
    io:format("manipulate_entitis ~p ~p ~p ~n",[UUID, Action, Items]),
    F = fun({tasks, assign, EID}) -> {tasks, assign_finished, EID};
            ({tasks, relate, EID}) -> {tasks, relate_finished, EID}; 
            (I) -> I
        end, 

     {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_dustbin, act, [UUID, Action, [F(I) || I<-Items]], SessionIP]),
    ok.
