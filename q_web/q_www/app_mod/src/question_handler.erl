%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/questions
%%%------------------------------------------------------------------------------------------
-module(question_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle issue news request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),        
    OwnerId = utility:get_integer(Json, "uuid"),
    Title = utility:get_binary(Json, "title"),
    Content = utility:get_binary(Json, "content"),
    Tags = utility:get_binary(Json, "tags"),
    {QuestionId, TimeStamp} = create_question(OwnerId, Title, Content, Tags, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, QuestionId}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle reply a question request
handle(Arg, 'POST', [QuestionId, "replies"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),   
    TimeStamp = reply_question(UUID, list_to_integer(QuestionId), Content, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle get all questions
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    PI = utility:query_integer(Arg, "page_index"), 
    PN = utility:query_integer(Arg, "page_num"),
    Questions = get_all_questions(UUID, PI, PN, utility:client_ip(Arg)),
    ContentSpec = [entity_id, from, {timestamp, fun erlang:list_to_binary/1}, title, content, replies],
    utility:pl2jso([{status, ok}, {questions, utility:a2jsos(ContentSpec, Questions)}]);
%% handle get all replies of a task request
handle(Arg, 'GET', ["replies"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    QuestionId = utility:query_integer(Arg, "entity_id"),
    AllReplies = get_all_replies_of_question(UUID, QuestionId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, content, {timestamp, fun erlang:list_to_binary/1}],
                                                       AllReplies)}]).

%%% RPC calls
-include("snode.hrl").

create_question(OwnerId, Title, Content, Tags, SessionIP) ->
    io:format("create_question ~p ~p ~p ~p ~n",[OwnerId, Title, Content, Tags]),
    %{value,{QuestionId, Timestamp}} = rpc:call(snode:get_service_node(), lw_question, create_question, [OwnerId, Title, Content, Tags]),
    {value, {QuestionId, Timestamp}} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [OwnerId, lw_question, create_question, [OwnerId, Title, Content, Tags], SessionIP]),

    {QuestionId, Timestamp}.
    %%{1234, "2012-7-24 10:34:44"}.

reply_question(UUID, QuestionId, Content, SessionIP) ->
    io:format("reply_question ~p ~p ~p~n",[UUID, QuestionId, Content]),
    %%{value, Timestamp} = rpc:call(snode:get_service_node(), lw_question, reply_question, [UUID, QuestionId, Content]),
    {value, Timestamp} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_question, reply_question, [UUID, QuestionId, Content], SessionIP]),

    Timestamp.
    %%"2012-7-24 10:34:44".

get_all_questions(UUID, PI,PN,SessionIP) ->
    io:format("get_all_questions ~p ~n",[UUID]),
    %%{value,News} = rpc:call(snode:get_service_node(), lw_question, get_all_questions, [UUID]),
    {value, Questions} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_question, get_all_questions, [UUID,PI,PN], SessionIP]),

    Questions.
    %%[{1,  2, "2012-7-8 23:4:5", <<"title1">>, <<"content1">>, 3},
    %% {23, 3, "2012-7-8 23:40:5", <<"title2">>, <<"content2">>, 4}
    %%].

get_all_replies_of_question(UUID, QuestionId, SessionIP) ->
    io:format("get_all_replies_of_question ~p ~p~n",[UUID, QuestionId]),
   %% {value, Replies} = rpc:call(snode:get_service_node(), lw_question, get_all_replies_of_question, [UUID, QuestionId]),
   {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_question, get_all_replies_of_question, [UUID, QuestionId], SessionIP]),

    Replies.
    %%[{234,  <<"content1">>, "2012-7-8 23:4:5"},
    %%  {234,  <<"content2">>, "2012-7-8 23:40:5"}].
