%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork news
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_news).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_news(OwnerId, Content, Attachment, AttachmentName) ->
    Time   = erlang:localtime(),
    NewsID = do_create_news(OwnerId, Content, Time, Attachment, AttachmentName),
    spawn(fun() -> 
              lw_indexer:index({news,NewsID},OwnerId,Content),
              lw_indexer:index({news,NewsID},OwnerId,AttachmentName)
          end),
    {NewsID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

reply_news(UUID, NewsID, Content) ->
    Time = erlang:localtime(),
    spawn(fun() -> lw_db:act(add,news_reply,{NewsID,UUID,Content,Time}) end),
    lw_lib:trans_time_format(Time).

%%--------------------------------------------------------------------------------------

get_all_replies_of_news(_UUID, NewsID) ->
    AllReplies = lw_db:act(get,news_reply,{NewsID}),
    [trans_reply_format(Reply)||Reply<-AllReplies].

%%--------------------------------------------------------------------------------------

get_all_news(_UUID) ->
    AllNews = lw_db:act(get,all_news,{}),
    [trans_news_format(News)||News<-AllNews].

%%--------------------------------------------------------------------------------------

get_news_content(NewsID) when is_integer(NewsID) ->
    get_news_content([NewsID]);

get_news_content(NewsIDs) when is_list(NewsIDs) ->
    AllNews = lw_db:act(get,news,{NewsIDs}),
    [trans_news_format(News)||News<-AllNews].

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

trans_news_format(News) ->
    {News#lw_news.uuid,
     News#lw_news.owner_id,
     News#lw_news.contents,
     News#lw_news.attachment,
     News#lw_news.attachment_name,
     lw_lib:trans_time_format(News#lw_news.time_stamp),
     length(News#lw_news.replies)}.

trans_reply_format({UUID,Content,Time}) ->
    {UUID,Content,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

do_create_news(OwnerId, Content, Time, Attachment, AttachmentName) ->
    NewsID = lw_id_creater:generate_newsid(),
    lw_db:act(save,news,{NewsID, OwnerId, Content, Time, Attachment, AttachmentName}),
    NewsID.

%%--------------------------------------------------------------------------------------