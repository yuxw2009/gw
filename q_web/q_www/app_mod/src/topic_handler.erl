%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/topics
%%%------------------------------------------------------------------------------------------
-module(topic_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle create topic request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),		
    OwnerId = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),
    MemberIds = utility:get_array_integer(Json, "members"),
    Image     = utility:get_binary(Json, "image"),
    {TopicId, TimeStamp} = create_topic(OwnerId, Content, Image, MemberIds, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, TopicId}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle get all or unread topics
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Topics = 
        case utility:query_string(Arg, "status") of
            "unread" ->  get_unread_topics(UUID, utility:client_ip(Arg));
            "all" ->
                 PI = utility:query_integer(Arg, "page_index"), 
                 PN = utility:query_integer(Arg, "page_num"),
                 get_all_topics(UUID, PI, PN, utility:client_ip(Arg))
        end,

    ContentSpec = [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, content, image, replies],
    utility:pl2jso([{status, ok}, {topics, utility:a2jsos(ContentSpec, Topics)}]);
%% handle reply a topic request
handle(Arg, 'POST', [TopicId, "replies"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),
    To = utility:get_integer(Json, "to"),
    Index = utility:get_integer(Json, "index"),
    {TimeStamp, No} = reply_topic(UUID, list_to_integer(TopicId), Content, To, Index, utility:client_ip(Arg)),
   
    utility:pl2jso([{status, ok}, {timestamp, list_to_binary(TimeStamp)}, {index, No}]);
%% handle get all unread replies request
handle(Arg, 'GET', ["replies", "unread"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    UnreadReplies = get_recent_n_replies(UUID, utility:client_ip(Arg)),
    ReplyFun = fun({From, To, Content, TimeStamp, TIndex, FIndex}) ->
                   utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}], 
                                  [{from, From}, {to,To},{content, Content},
                                  {timestamp, TimeStamp}, {tindex, TIndex}, {findex, FIndex}])  
               end,
    TopicFun = fun({TopicId, From, TimeStamp, Content, Image, Replies}) ->
                   utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}], 
                                  [{entity_id, TopicId}, {from, From}, {content, Content}, {image, Image},
                                   {timestamp, TimeStamp}, {replies, Replies}])   
               end,

    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([{topic, TopicFun}, {reply, ReplyFun}],
                                                       UnreadReplies)}]);
%% handle get all replies of a topic request
handle(Arg, 'GET', ["replies"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    TopicId = utility:query_integer(Arg, "entity_id"),
    AllReplies = get_all_replies_of_topic(UUID, TopicId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, to, content, {timestamp, fun erlang:list_to_binary/1}, tindex, findex],
                                                       AllReplies)}]);
%% handle get all dialog of a topic
handle(Arg, 'GET', ["dialog"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    TopicId = utility:query_integer(Arg, "entity_id"),
    Index   = utility:query_integer(Arg, "index"),

    Dialog = get_dialog(UUID, TopicId, Index, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, to, content, {timestamp, fun erlang:list_to_binary/1}, tindex, findex],
                                                       Dialog)}]);
%% handle invite new member
handle(Arg, 'POST', [TopicId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    NewMemberId = utility:get_array_integer(Json, "new_members"),  
    ok = invite_new_member(UUID, list_to_integer(TopicId), NewMemberId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]).

%%% RPC calls
-include("snode.hrl").

create_topic(OwnerId, Content, Image, MemberIds, SessionIP) ->
   %% io:format("create_topic ~p ~p ~p ~p~n",[OwnerId, Content,Image, MemberIds]),
   %% {value,{TopicId, Timestamp}} = rpc:call(snode:get_service_node(), lw_topic, create_topic, [OwnerId, Content, MemberIds, []]),
    {value, {TopicId, Timestamp}} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [OwnerId, lw_topic, create_topic, [OwnerId, Content, MemberIds, Image], SessionIP]),
    {TopicId, Timestamp}.
    %%{1234, "2012-7-24 10:34:44"}.

get_unread_topics(UUID, SessionIP) ->
    io:format("get_unread_topics ~p~n",[UUID]),
    {value, Topics} = rpc:call(snode:get_service_node(), lw_instance, get_unreads, [UUID, topic,SessionIP]),
    Topics.
   %% io:format("~p~n", [Value]),
   %% {value, Topics} = Value,
   %% Topics.
   %% [{1,  2, "2012-7-8 23:4:5", <<"content1">>, 2},
    %%{23, 3, "2012-7-8 23:40:5", <<"content2">>, 5}
    %%].

reply_topic(UUID, TopicId, Content, To, Index, SessionIP) ->
    io:format("reply_topic ~p ~p ~p ~p ~p~n",[UUID, TopicId, Content, To, Index]),
    %%{value, Timestamp} = rpc:call(snode:get_service_node(), lw_topic, reply_topic, [UUID, TopicId, Content]),
    {value, {Timestamp, NewIndex}} = 
    case Index of
        -1 ->
             rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, reply_topic, [UUID, TopicId, Content], SessionIP]);
        _  ->
            rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, reply_topic, [UUID, TopicId, Content, To, Index], SessionIP])
    end,
    {Timestamp, NewIndex}.
    %%"2012-7-24 10:34:44".

get_all_replies_of_topic(UUID, TopicId, SessionIP) ->
    io:format("get_all_replies_of_topic ~p ~p~n",[UUID, TopicId]),
 %%   {value, Replies} = rpc:call(snode:get_service_node(), lw_topic, get_all_replies_of_topic, [UUID, TopicId]),
    {value, Replies} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, get_all_replies_of_topic, [UUID, TopicId], SessionIP]),
    Replies.
    %% [{4,  4, <<"content1">>, "2012-7-8 23:4:5", 2, 1},
    %%  {5,  4, <<"content2">>, "2012-7-8 23:40:5",4,  2}].

get_dialog(UUID, TopicId, Index, SessionIP) ->
   io:format("get_dialog ~p ~p ~p~n",[UUID, TopicId, Index]),
 %%   {value, Replies} = rpc:call(snode:get_service_node(), lw_topic, get_all_replies_of_topic, [UUID, TopicId]),
    {value, Dialog} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, find_reply_trace, [UUID, TopicId, Index], SessionIP]),
    Dialog.
    %% [{4,  4, <<"content1">>, "2012-7-8 23:4:5", 2, 1},
    %%  {5,  4, <<"content2">>, "2012-7-8 23:40:5",4,  2}].

invite_new_member(UUID, TopicId, NewMemberIds, SessionIP) ->
    io:format("invite_new_member ~p ~p ~p~n",[UUID, TopicId, NewMemberIds]),
   %% ok = rpc:call(snode:get_service_node(), lw_topic, invite_new_member, [UUID, TopicId, NewMemberIds]).
    {value, ok} =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, invite_new_member, [UUID, TopicId, NewMemberIds], SessionIP]),
    ok.

get_all_topics(UUID, PI, PN, SessionIP) ->
    io:format("get_all_topics ~p ~p ~p~n",[UUID, PI, PN]),
    %%Value = rpc:call(snode:get_service_node(), lw_topic, get_all_topics, [UUID]),
    Value =rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_topic, get_all_topics, [UUID, PI, PN], SessionIP]),
   %% io:format("~p~n", [Value]),
    {value, Topics} = Value,
    Topics.

    %%[{1,  1, "2012-7-8 23:4:5", <<"content1">>, 2, 4},
    %%{2, 2, "2012-7-8 23:40:5", <<"content2">>, 5, 4},
    %%{3,  3, "2012-7-8 23:4:5", <<"content1">>, 2, 4},
    %%{23, 4, "2012-7-8 23:40:5", <<"content2">>, 5, 4}
    %%].

get_recent_n_replies(UUID, SessionIP) ->
    io:format("get_recent_n_replies ~p~n",[UUID]),
   %% {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, load_recent_replies, [UUID, topic]),
    {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, get_recent_replies, [UUID, topic, SessionIP]),
    Replies.
    %%Replies = [{Reply, Topic}]
    %% Reply  = {From, Content, Timestamp, Index}

    %% Topic  = {TopicId, From, to  Content, Timstamp, Replies, tindex, findex}
    %%[{{2, 4, <<"reply11">>, "2012-7-8 23:4:5",4, 1}, 
    %%  {234, 4, <<"topic1">>, "2012-7-8 23:4:5", 5,4}}].


     
