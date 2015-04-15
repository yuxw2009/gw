%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/polls
%%%------------------------------------------------------------------------------------------
-module(poll_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle start a poll request
handle(Arg, 'POST', []) ->
    {UUID, Type, Members, Subject, CImage, Options} = 
        utility:decode(Arg, [{uuid, i}, {type, a}, {members, ai}, {content, b}, 
                             {image, b}, {options, ao, [{label, b}, {content, b},{image,b}]}]),

    {PollId, TimeStamp} = start_poll(UUID, {Type, Subject, CImage, Options}, Members, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, PollId}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle get all polls request
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Polls = 
        case utility:query_string(Arg, "status") of
            "unread" ->  get_unread_polls(UUID, utility:client_ip(Arg));
            "all" -> 
                PI = utility:query_integer(Arg, "page_index"), 
                PN = utility:query_integer(Arg, "page_num"),
                get_all_polls(UUID, PI, PN, utility:client_ip(Arg))
        end,

    ContentSpec = [entity_id, from, type, content, image, 
                      {options, fun(V) -> utility:a2jsos([label,content, image], V) 
                                          end},
                      {timestamp, fun erlang:list_to_binary/1},
                      traces,
                      {status, fun({voted, R}) ->
                                       utility:pl2jso([{status, voted}, {value, R}]);
                                  ({not_voted, _})  -> 
                                      utility:pl2jso([{status, not_voted}])
                               end}],
    utility:pl2jso([{status, ok}, {polls, utility:a2jsos(ContentSpec, Polls)}]);
    %%utility:pl2jso([{polls, fun(VS)-> [PollFun(V) || V<-VS] end}], 
    %%               [{status, ok}, {polls, Polls}]);

%% handle traces of a task request
handle(Arg, 'GET', [PollId, "traces"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Traces = get_traces_of_poll(UUID, list_to_integer(PollId), utility:client_ip(Arg)),
    EventFun = fun({V})     -> V;
                 ({V,IDs}) -> list_to_binary(atom_to_list(V)++","++
                                             string:join([integer_to_list(Id) || Id<-IDs],","))
              end,
    utility:pl2jso([{status, ok},
                  {traces, utility:a2jsos([from, {event, EventFun},
                                           {timestamp, fun erlang:list_to_binary/1}], 
                                           Traces)}]);

%% handle vote  request
handle(Arg, 'PUT', [PollId]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),    
    UUID = utility:get_integer(Json, "uuid"),
    Choice = utility:get_binary(Json, "choice"),
    ok = vote(UUID, list_to_integer(PollId), Choice, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle invite member  request
handle(Arg, 'POST', [PollId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    NewMemberId = utility:get_array_integer(Json, "new_members"),  
    ok = invite_new_member(UUID, list_to_integer(PollId), NewMemberId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle query poll result request
handle(Arg, 'GET', ["results"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    PollId = utility:query_integer(Arg, "entity_id"),

    Result = get_poll_result(UUID, PollId, utility:client_ip(Arg)),
    utility:pl2jso([{results, fun(V) -> utility:a2jsos([label,image, 
                                                        votes
                                                       ], V) 
                              end}
                   ], 
                   [{status, ok}, {results, Result}]).

%%% RPC calls
-include("snode.hrl").

start_poll(UUID, {Type, Subject, CImage, Options}, Members, SessionIP) ->
    io:format("start_poll ~p ~p ~p~n",[UUID, {Type, Subject, CImage, Options}, Members]),
   %% {value, {PollId, TimeStamp}} = rpc:call(snode:get_service_node(), lw_poll, create_poll, [UUID, {Type, Subject, Options}, Members]),
    {value, {PollId, TimeStamp}} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_poll, create_poll, [UUID, {Type, Subject, CImage, Options}, Members], SessionIP]),

    {PollId, TimeStamp}.
   %% {12, "2012-8-1 23:12:34"}.

get_all_polls(UUID, PI, PN, SessionIP) ->
    io:format("get_all_polls ~p ~n",[UUID]),
   %% {value, Polls} = rpc:call(snode:get_service_node(), lw_poll, get_all_polls, [UUID]),
    {value, Polls} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_poll, get_all_polls, [UUID,PI,PN], SessionIP]),

    Polls.
    %%[{12, 2,single, "poll test", [{"A", "a content"},{"B", "b content"}],
    %%    "2012-8-1 23:12:34", {voted,"B"}},
    %%    {13, 4, single, "poll test", [{"A", "a content"},{"B", "b content"}],
    %%    "2012-8-1 23:12:34", {not_voted, none} }].

get_unread_polls(UUID, SessionIP) ->
    io:format("get_unread_polls ~p ~n",[UUID]),
    %%{value, Polls} = rpc:call(snode:get_service_node(), lw_instance, load_unreads, [UUID, poll]),
    {value, Polls} = rpc:call(snode:get_service_node(), lw_instance, get_unreads, [UUID, poll, SessionIP]),
   
    Polls.
    %%[{12, 3, single, "poll test", [{"A", "a content"},{"B", "b content"}],
    %%    "2012-8-1 23:12:34", {voted,"A"} }].

vote(UUID, PollId, Choice, SessionIP) ->
    io:format("vote ~p ~p ~p~n",[UUID, PollId, Choice]),
    %%ok = rpc:call(snode:get_service_node(), lw_poll, vote, [UUID, PollId, Choice]).
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_poll, vote, [UUID, PollId, Choice], SessionIP]),
    ok.

invite_new_member(UUID, PollId, NewMemberIds, SessionIP) ->
    io:format("invite_new_member ~p ~p ~p~n",[UUID, PollId, NewMemberIds]),
    %%ok = rpc:call(snode:get_service_node(), lw_poll, invite_new_member, [UUID, PollId, NewMemberIds]).
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_poll, invite_new_member, [UUID, PollId, NewMemberIds], SessionIP]),
    ok.

get_poll_result(UUID, PollId, SessionIP) ->
    io:format("get_poll_result ~p  ~p~n",[UUID, PollId]),
    %%{value, Result} = rpc:call(snode:get_service_node(), lw_poll, get_poll_result,[UUID, PollId]),
    {value, Result} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_poll, get_poll_result, [UUID, PollId], SessionIP]),

    Result.
    %%[{"A", 10},{"B",4}].

get_traces_of_poll(UUID, PollId, SessionIP) ->
    io:format("get_traces_of_poll ~p ~p~n",[UUID, PollId]),
    %% {value, Traces} = rpc:call(snode:get_service_node(), lw_task, get_traces_of_task, [UUID, TaskId]),

    {value, Traces} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_poll, get_traces_of_poll, [UUID, PollId], SessionIP]),
   %% io:format("Traces: ~p~n", [Traces]),
    Traces.
    %%[{12, {read}, "2012-7-8 23:4:5"},
    %% {12,  {invited, [22,23]}, "2012-7-8 23:40:5"}].