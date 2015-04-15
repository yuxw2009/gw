%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/news
%%%------------------------------------------------------------------------------------------
-module(news_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle issue news request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),        
    OwnerId = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),
    Image = utility:get_binary(Json, "image"),
    %%AttachName = utility:get_binary(Json, "attachment_name"),

    {NewsId, TimeStamp} = create_news(OwnerId, Content,Image, <<>>, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, NewsId}, {timestamp, list_to_binary(TimeStamp)}]);

%% handle reply a news request
handle(Arg, 'POST', [NewsId, "replies"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Content = utility:get_binary(Json, "content"),   
    TimeStamp = reply_news(UUID, list_to_integer(NewsId), Content, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {timestamp, list_to_binary(TimeStamp)}]);

%% handle get all replies of a news request
handle(Arg, 'GET', ["replies"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    NewsId = utility:query_integer(Arg, "entity_id"),
    AllReplies = get_all_replies_of_news(UUID, NewsId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {replies, utility:a2jsos([from, content, {timestamp, fun erlang:list_to_binary/1}],
                                                       AllReplies)}]);

%% handle get all news
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    News = get_all_news(UUID, utility:client_ip(Arg)),
    ContentSpec = [entity_id, from, content, image, attachment_name,{timestamp, fun erlang:list_to_binary/1}, replies],
    utility:pl2jso([{status, ok}, {news, utility:a2jsos(ContentSpec, News)}]).

%%% RPC calls
-include("snode.hrl").

create_news(OwnerId, Content, Attach, AttachName,SessionIP) ->
    io:format("create_news ~p ~p ~p ~p~n",[OwnerId, Content, Attach, AttachName]),
    %%{value,{NewsId, Timestamp}} = rpc:call(snode:get_service_node(), lw_news, create_news, [OwnerId, Content]),
    {value, {NewsId, Timestamp}} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [OwnerId, lw_news, create_news, [OwnerId, Content, Attach, AttachName], SessionIP]),

    {NewsId, Timestamp}.
    %%{1234, "2012-7-24 10:34:44"}.

get_all_news(UUID, SessionIP) ->
    io:format("get_all_news ~p ~n",[UUID]),
    %%{value,News} = rpc:call(snode:get_service_node(), lw_news, get_all_news, [UUID]),
      {value, News} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_news, get_all_news, [UUID], SessionIP]),

     News.
    %%[{1,  2, <<"content1">>,"2012-7-8 23:4:5"},
    %% {23, 4, <<"content2">>, "2012-7-8 23:40:5"}
    %%].

reply_news(UUID, NewsId, Content, SessionIP) ->
    io:format("reply_news ~p ~p ~p~n",[UUID, NewsId, Content]),
    %%{value, Timestamp} = rpc:call(snode:get_service_node(), lw_question, reply_question, [UUID, QuestionId, Content]),
    {value, Timestamp} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_news, reply_news, [UUID, NewsId, Content], SessionIP]),

    Timestamp.
    %%"2012-7-24 10:34:44".

get_all_replies_of_news(UUID, NewsId, SessionIP) ->
    io:format("get_all_replies_of_news ~p ~p~n",[UUID, NewsId]),
   %% {value, Replies} = rpc:call(snode:get_service_node(), lw_question, get_all_replies_of_question, [UUID, QuestionId]),
   {value, Replies} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                [UUID, lw_news, get_all_replies_of_news, [UUID, NewsId], SessionIP]),

    Replies.
