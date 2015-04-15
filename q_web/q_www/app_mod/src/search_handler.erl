%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/search
%%%------------------------------------------------------------------------------------------
-module(search_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle search request
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Type = utility:query_atom(Arg, "type"),
    KeyWord = utility:query_string(Arg, "keyword"),
    {Num, Results} = search_keyword(UUID, Type, list_to_binary(KeyWord), utility:client_ip(Arg)),
    ContentSpec = 
    case Type of
        topics -> [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies];
        tasks  ->  [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies, traces, status];
        news   ->  [entity_id, from, content,  attachment, attachment_name, {timestamp, fun erlang:list_to_binary/1}];
        polls  ->  [entity_id, from, type, content, image,
                      {options, fun(V) -> utility:a2jsos([label, content, image], V) 
                                          end},
                      {timestamp, fun erlang:list_to_binary/1},
                      {status, fun({voted, R}) ->
                                       utility:pl2jso([{status, voted}, {value, R}]);
                                  ({not_voted, _})  -> 
                                      utility:pl2jso([{status, not_voted}])
                               end}];
        documents ->  [entity_id, name, file_id,
                              file_length, owner_id, from, content,
                              {create_time, fun erlang:list_to_binary/1},
                              {timestamp, fun erlang:list_to_binary/1}];
        questions -> [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, title, content, replies]
    end,
    utility:pl2jso([{status, ok}, {count, Num}, {Type, utility:a2jsos(ContentSpec, Results)}]).

%%% rpc call
-include("snode.hrl").

search_keyword(UUID, Type, KeyWord, SessionIP) ->
    io:format("search_keyword ~p ~p ~p~n",[UUID, Type, KeyWord]),
    {value, Res} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_indexer, search, [UUID, Type, KeyWord], SessionIP]),
    io:format("result:  ~p ~n",[Res]),
    Res.
    %%{5, [{1,  88, "2012-7-8 23:4:5", <<"content1">>, 2},
    %%{2, 88, "2012-7-8 23:40:5", <<"content2">>, 5},
    %%{3,  88, "2012-7-8 23:4:5", <<"content1">>, 2},
    %%{23, 88, "2012-7-8 23:40:5", <<"content2">>, 5}
    %%]}.
