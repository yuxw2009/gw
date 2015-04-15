%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/tasks
%%%------------------------------------------------------------------------------------------
-module(task_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle assign task request
handle(Arg, 'POST', []) ->
  %%  {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),		
  %%  OwnerId = utility:get_integer(Json, "uuid"),
  %%  Content = utility:get_binary(Json, "content"),
  %%  Image   = utility:get_binary(Json, "image"),
  %%  MemberIds = utility:get_array_integer(Json, "members"),
    {OwnerId, Content, Image, MemberIds} = 
        utility:decode(Arg, [{uuid, i}, {content,b}, {image, b}, {members, ai}]),


    {TaskId, TimeStamp} = create_task(OwnerId, Content, Image, MemberIds, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, TaskId}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle get specified type tasks request:  unread | finished | unfinished | owned |assigned
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Status = utility:query_atom(Arg, "status"),
    {Type, PI, PN} = 
    	case Status of
    		unread -> {unread, 0, 0};
    		finished -> 
                P0 = utility:query_integer(Arg, "page_index"), 
                P1 = utility:query_integer(Arg, "page_num"),
                {finished, P0, P1};
    		_      -> 
                P0 = utility:query_integer(Arg, "page_index"), 
                P1 = utility:query_integer(Arg, "page_num"),
                {{utility:query_atom(Arg, "type"), Status}, P0, P1}
    	end,
    Tasks = get_tasks_with_type(UUID,  {Type, PI, PN}, utility:client_ip(Arg)),

    ContentSpec = case Type of
                      finished ->
                          [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, 
                                            {finished_time, fun erlang:list_to_binary/1}, 
                                            content, image, replies, traces];
                      _ ->
                          [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies, traces]
                  end,
	utility:pl2jso([{status, ok}, {tasks, utility:a2jsos(ContentSpec, Tasks)}]);
%% handle traces of a task request
handle(Arg, 'GET', [TaskId, "traces"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Traces = get_traces_of_task(UUID, list_to_integer(TaskId), utility:client_ip(Arg)),
    EventFun = fun({V})     -> V;
     	           ({V,IDs}) -> list_to_binary(atom_to_list(V)++","++
     	           	                           string:join([integer_to_list(Id) || Id<-IDs],","))
     	        end,
    utility:pl2jso([{status, ok},
    	            {traces, utility:a2jsos([from, {event, EventFun},
    	                                     {timestamp, fun erlang:list_to_binary/1}], 
    	                                     Traces)}]);
%% handle reply a task request
handle(Arg, 'POST', [TaskId, "replies"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),   
    To = utility:get_integer(Json, "to"),
    Index = utility:get_integer(Json, "index"),
    {TimeStamp, No} = reply_task(UUID, list_to_integer(TaskId), Content, To, Index, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {timestamp, list_to_binary(TimeStamp)}, {index, No}]);
%% handle get all replies of a task request
handle(Arg, 'GET', ["replies"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    TaskId = utility:query_integer(Arg, "entity_id"),
    AllReplies = get_all_replies_of_task(UUID, TaskId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, to, content, {timestamp, fun erlang:list_to_binary/1}, tindex, findex],
 	                                                   AllReplies)}]);
%% handle get all dialog of a task
handle(Arg, 'GET', ["dialog"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    TaskId = utility:query_integer(Arg, "entity_id"),
    Index   = utility:query_integer(Arg, "index"),

    Dialog = get_dialog(UUID, TaskId, Index, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, to, content, {timestamp, fun erlang:list_to_binary/1}, tindex, findex],
                                                       Dialog)}]);
%% handle get all unread replies request
handle(Arg, 'GET', ["replies", "unread"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    UnreadReplies = get_recent_n_replies(UUID, utility:client_ip(Arg)),
    ReplyFun = fun({From, To, Content, TimeStamp, TIndex, FIndex}) ->
                   utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}], 
                                  [{from, From}, {to,To}, {content, Content}, {timestamp, TimeStamp},
                                   {tindex, TIndex}, {findex, FIndex}])  
               end,
    TopicFun = fun({TopicId, From, TimeStamp, Content, Image, Replies, Traces}) ->
                   utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}], 
                                  [{entity_id, TopicId}, {from, From}, {content, Content}, {image, Image},
                                   {timestamp, TimeStamp}, {replies, Replies}, {traces, Traces}])   
               end,

    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([{topic, TopicFun}, {reply, ReplyFun}],
                                                       UnreadReplies)}]);
%% handle task traces request
handle(Arg, 'PUT', [TaskId, "traces"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Status = utility:get_string(Json, "value"),  
    ok = report_task_trace(UUID, list_to_integer(TaskId), Status, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle finish task
handle(Arg, 'PUT', [TaskId, "status"]) ->
	{ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    "finished" = utility:get_string(Json, "value"),  
    Timstamp = finish_task(UUID, list_to_integer(TaskId), utility:client_ip(Arg)),
    utility:pl2jso([{finished_time, fun erlang:list_to_binary/1}], [{status, ok}, {finished_time, Timstamp}]);
%% handle invite new member
handle(Arg, 'POST', [TaskId, "members"]) ->
	{ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    NewMemberId = utility:get_array_integer(Json, "new_members"),  
    ok = invite_new_member(UUID, list_to_integer(TaskId), NewMemberId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]).


%%% RPC calls
-include("snode.hrl").

create_task(OwnerId, Content, Image, MemberIds, SessionIP) ->
    io:format("assign_task ~p ~p ~p ~p~n",[OwnerId, Content, Image, MemberIds]),
    %%{value,{TaskId, Timestamp}} = rpc:call(snode:get_service_node(), lw_task, create_task, [OwnerId, Content, MemberIds, []]),
    
    {value, {TaskId, Timestamp}} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [OwnerId, lw_task, create_task, [OwnerId, Content, MemberIds, Image], SessionIP]),
    {TaskId, Timestamp}.
    %%{1234, "2012-7-24 10:34:44"}.

%% Type = unread | finished | {assigned, unfinished}
%% Type = unread | finished | {assigned, unfinished}
get_tasks_with_type(UUID, {unread, _, _}, SessionIP) ->
    io:format("get_tasks_with_type unread ~p~n",[UUID]),
    {value, Tasks} = rpc:call(snode:get_service_node(), lw_instance, get_unreads, [UUID, task, SessionIP]),
    Tasks;    
get_tasks_with_type(UUID, {Type, PI, PN},SessionIP) ->
    io:format("get_tasks_with_type ~p ~p~n",[UUID, Type]),
    %%Value = rpc:call(snode:get_service_node(), lw_task, get_tasks_with_type, [UUID, Type]),
    Value = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, get_tasks_with_type, [UUID, Type, PI, PN], SessionIP]),
    %%io:format("~p~n", [Value]),
    {value, Tasks} = Value,
    Tasks.

    %%[{1,  234, "2012-7-8 23:4:5", <<"content1">>, 2, 4},
    %% {23, 234, "2012-7-8 23:40:5", <<"content2">>, 5, 4}
    %%].

get_traces_of_task(UUID, TaskId, SessionIP) ->
    io:format("get_traces_of_task ~p ~p~n",[UUID, TaskId]),
    %% {value, Traces} = rpc:call(snode:get_service_node(), lw_task, get_traces_of_task, [UUID, TaskId]),

    {value, Traces} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, get_traces_of_task, [UUID, TaskId], SessionIP]),
   %% io:format("Traces: ~p~n", [Traces]),
    Traces.
    %%[{12, {read}, "2012-7-8 23:4:5"},
    %% {12,  {invited, [22,23]}, "2012-7-8 23:40:5"}].

reply_task(UUID, TaskId, Content, To, Index, SessionIP) ->
	io:format("reply_task ~p ~p ~p ~p ~p~n",[UUID, TaskId, Content, To, Index]),
	%%{value, Timestamp} = rpc:call(snode:get_service_node(), lw_task, reply_task, [UUID, TaskId, Content]),

    {value, {Timestamp, NewIndex}} =
    case Index of
        -1 ->
            rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, reply_task, [UUID, TaskId, Content], SessionIP]);
        _ -> rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, reply_task, [UUID, TaskId, Content, To, Index], SessionIP])
    end,
    {Timestamp, NewIndex}.
    %%"2012-7-24 10:34:44".

get_all_replies_of_task(UUID, TaskId, SessionIP) ->
    io:format("get_all_replies_of_task ~p ~p~n",[UUID, TaskId]),
    %%{value, Replies} = rpc:call(snode:get_service_node(), lw_task, get_all_replies_of_task, [UUID, TaskId]),
    {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, get_all_replies_of_task, [UUID, TaskId], SessionIP]),
    Replies.
    %% [{234,  5, <<"content1">>, "2012-7-8 23:4:5", 5, 6},
    %%  {234,  <<"content2">>, "2012-7-8 23:40:5"}
    %5].
get_dialog(UUID, TaskId, Index, SessionIP) ->
   io:format("get_dialog ~p ~p ~p~n",[UUID, TaskId, Index]),
 %%   {value, Replies} = rpc:call(snode:get_service_node(), lw_topic, get_all_replies_of_topic, [UUID, TopicId]),
    {value, Dialog} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, find_reply_trace, [UUID, TaskId, Index], SessionIP]),
    Dialog.
    %% [{4,  4, <<"content1">>, "2012-7-8 23:4:5", 2, 1},
    %%  {5,  4, <<"content2">>, "2012-7-8 23:40:5",4,  2}].
report_task_trace(UUID, TaskId, Status, SessionIP) -> 
     io:format("trace_task ~p ~p ~p~n",[UUID, TaskId, Status]),
     %%ok = rpc:call(snode:get_service_node(), lw_task, report_task_trace, [UUID, TaskId, Status]).
     {value, ok } =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, trace_task, [UUID, TaskId, Status], SessionIP]),
     ok.

finish_task(UUID, TaskId, SessionIP) ->
    io:format("finish_task ~p ~p~n",[UUID, TaskId]),
    %%{value, TimeStamp} = rpc:call(snode:get_service_node(), lw_task, finish_task, [UUID, TaskId]),
    {value, TimeStamp} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, finish_task, [UUID, TaskId], SessionIP]),
    TimeStamp.
    %%ok.

invite_new_member(UUID, TaskId, NewMemberIds, SessionIP) ->
    io:format("invite_new_member ~p ~p ~p~n",[UUID, TaskId, NewMemberIds]),
    %%rpc:call(snode:get_service_node(), lw_task, invite_new_member, [UUID, TaskId, NewMemberIds]).
    {value, ok} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_task, invite_new_member, [UUID, TaskId, NewMemberIds], SessionIP]),
    ok.
get_recent_n_replies(UUID, SessionIP) ->
    io:format("get_recent_n_replies ~p~n",[UUID]),
    {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, get_recent_replies, [UUID, task, SessionIP]),
     %%  io:format("get_recent_n_replies result: ~p~n", [Replies]),
    Replies.
    %%Replies = [{Reply, Topic}]
    %% Reply  = {From, Content, Timestamp}

    %% Topic  = {TopicId, From, Content, Timstamp, Replies, Traces}
    %%[{{2, <<"reply11">>, "2012-7-8 23:4:5"}, 
    %%  {234, 1, <<"topic1">>, "2012-7-8 23:4:5", 4}}].