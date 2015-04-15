%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/forum
%%%------------------------------------------------------------------------------------------
-module(forum_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle get all categories
handle(Arg, 'GET', ["categories"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
   
    CS = rpc:call(snode:get_service_node(), lw_bbs, get_all_forum, [UUID]),
    
    utility:pl2jso([{status, ok}, {categories, 
                                   utility:a2jsos([index,{title,fun erlang:list_to_binary/1},
                                                         {label,fun erlang:list_to_binary/1}],CS)}]);
%% handle get all topics
handle(Arg, 'GET', ["topics"]) -> 
   UUID = utility:query_integer(Arg, "uuid"),
   CIndex = utility:query_integer(Arg, "cindex"),
   PI     = utility:query_integer(Arg, "page_index"),
   PN     = utility:query_integer(Arg, "page_num"),
   
   {UUID, Total, TT, TS} = rpc:call(snode:get_service_node(), lw_bbs, get_all_notes, [UUID, CIndex, PI, PN]),

   utility:pl2jso([{status, ok},{today_num, TT},{total_num, Total},
                   {topics, utility:a2jsos([id, from, {title, fun erlang:list_to_binary/1},
                                            {content, fun erlang:list_to_binary/1},
                                            type, reply_num, readers, 
                                            {timestamp, fun erlang:list_to_binary/1},
                                            repository                      
                                           ],TS)}
                  ]);
   
%% handle create a topic
handle(Arg, 'POST', ["topics"]) -> 
    {UUID, Title, Content, Repository, Index} 
        = utility:decode(Arg, [{uuid,i},{title, s}, 
                               {content, s},{repository,r},{cindex, i}]),

    {ID, TS, UUID} = 
        rpc:call(snode:get_service_node(), lw_bbs, create_note, [UUID, Title, Content, Repository, Index]),
    
    utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}],
                   [{status,ok},{topic_id, ID}, {timestamp, TS}]);


%% handle get all replies
handle(Arg, 'GET', ["replies"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    TID = utility:query_integer(Arg, "topic_id"),
    PI     = utility:query_integer(Arg, "page_index"),
    PN     = utility:query_integer(Arg, "page_num"),

    {UUID, Nums, Rs} = 
        rpc:call(snode:get_service_node(), lw_bbs, get_note_reply, [UUID, TID, PI, PN]), 
 
    utility:pl2jso([{status, ok},{uuid, UUID},{num, Nums},
                   {replies, utility:a2jsos([id, from, 
                                            {content, fun erlang:list_to_binary/1},
                                            {timestamp, fun erlang:list_to_binary/1},
                                            repository                      
                                           ],Rs)}
                  ]);

%% handle create a reply
handle(Arg, 'POST', ["replies"]) -> 
    {UUID, TID, Content, Repository} 
        = utility:decode(Arg, [{uuid,i},{topic_id, i}, 
                               {content, s},{repository,r}]),

    {RID, TS, UUID} = 
        rpc:call(snode:get_service_node(), lw_bbs, reply_note, [UUID, TID, Content, Repository]),
    
    utility:pl2jso([{timestamp, fun erlang:list_to_binary/1}],
                   [{status,ok},{reply_id, RID}, {timestamp, TS}]).



