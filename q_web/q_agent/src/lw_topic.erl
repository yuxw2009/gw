%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork topic
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_topic).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_topic(OwnerID, Content, MemberIds, Attachment) ->
    Time    = erlang:localtime(),
    TopicID = do_create_topic(OwnerID, Content, MemberIds, Attachment, Time),
    spawn(fun() -> lw_group:update_recent_group(OwnerID,MemberIds) end),
    spawn(fun() -> lw_indexer:index({topic,TopicID},OwnerID,Content) end),
    lw_router:send(MemberIds,{topic,TopicID,OwnerID}),
    lw_router:push_notification(MemberIds,OwnerID,topic),
    {TopicID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

reply_topic(From, TopicId, Content) ->
    reply_topic(From, TopicId, Content, -1, -1).

reply_topic(From, TopicId, Content, To, Index) ->
    Time     = erlang:localtime(),
    Reply    = {From,To,Content,Time,Index},
    NewIndex = lw_db:act(add,topic_reply,{TopicId,Reply}),
    Members  = 
        case To of
            -1 -> lw_db:act(get,topic_members,{TopicId});
            _  -> [To]
        end,
    NewReply = erlang:append_element(Reply,NewIndex),
    lw_router:send(Members,{reply,topic,{TopicId,trans_reply_format(NewReply)},From}),
    lw_router:push_notification(Members,From,{reply,topic}),
    {lw_lib:trans_time_format(Time),NewIndex}.

%%--------------------------------------------------------------------------------------

find_reply_trace(_UUID,TopicID,Index) ->
    Replies = lists:reverse(lw_db:act(get,topic_replies,{TopicID})),
    RepliesArray = array:from_list(Replies),
    Reply = array:get(Index - 1,RepliesArray),
    {From,To,_,_,TargetIndex,_} = Reply,
    [trans_reply_format(TraceReply)||TraceReply<-ahead_trace_reply(RepliesArray,From,To,TargetIndex - 1,[Reply])].

%%--------------------------------------------------------------------------------------

ahead_trace_reply(RepliesArray,From,To,ArrayIndex,Acc) ->
    Reply = array:get(ArrayIndex,RepliesArray),
    {_,NewTo,_,_,TargetIndex,_} = Reply,
    case NewTo of
        From -> ahead_trace_reply(RepliesArray,To,From,TargetIndex - 1,[Reply|Acc]);
        _    -> [Reply|Acc]
    end.

%%--------------------------------------------------------------------------------------

get_all_replies_of_topic(_UUID, TopicId) ->
    Replies = lw_db:act(get,topic_replies,{TopicId}),
    [trans_reply_format(Reply)||Reply<-Replies].

%%--------------------------------------------------------------------------------------

invite_new_member(UUID, TopicId, NewMemberIds) ->
    OwnerID = lw_db:act(get,topic_owner_id,{TopicId}),
    spawn(fun() -> lw_group:update_recent_group(UUID,NewMemberIds) end),
    spawn(fun() -> lw_db:act(add,topic_members,{TopicId, NewMemberIds}) end),
    lw_router:send(NewMemberIds,{topic,TopicId,OwnerID}),
    ok.

%%--------------------------------------------------------------------------------------

get_all_topics(UUID,Index,Num) ->
    TopicIDs = lw_db:act(get,all_topic_id,{UUID}) -- read_unread(UUID),
    TargetTopicIDs = lw_lib:get_sublist(TopicIDs,Index,Num),
    get_topic_content(TargetTopicIDs).

%%--------------------------------------------------------------------------------------

get_topic_content(TopicID) when is_integer(TopicID) ->
    [Content] = get_topic_content([TopicID]),
    Content;
get_topic_content(TopicIDs) when is_list(TopicIDs) ->
    Topics = lw_db:act(get,topic,{TopicIDs}),
    [trans_topic_format(Topic)||Topic<-Topics].

%%--------------------------------------------------------------------------------------

is_repeat(UUID,TopicID) ->
    TopicIDs = lw_db:act(get,all_topic_id,{UUID}),
    lists:member(TopicID, TopicIDs).

%%--------------------------------------------------------------------------------------

filter_related_id(UUID,TopicID) when is_integer(TopicID) ->
    filter_related_id(UUID,[TopicID]);
filter_related_id(UUID,TopicIDs) when is_list(TopicIDs) ->
    Relates = lw_db:act(get,all_topic_id,{UUID}),
    [TopicID||TopicID<-TopicIDs,lists:member(TopicID,Relates)].

%%--------------------------------------------------------------------------------------

recover_into_verse_table(UUID,Ownership,TopicID) -> lw_db:act(add,topic,{UUID,Ownership,TopicID}).

%%--------------------------------------------------------------------------------------

remove_from_verse_table(UUID,Ownership,TopicID)  -> lw_db:act(del,topic,{UUID,Ownership,TopicID}).

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

trans_reply_format({From,To,Content,Time,TargetIndex,SelfIndex}) ->
    {From,To,Content,lw_lib:trans_time_format(Time),TargetIndex,SelfIndex}.

trans_topic_format(Topic) ->
    {Topic#lw_topic.uuid,
     Topic#lw_topic.owner_id,
     lw_lib:trans_time_format(Topic#lw_topic.time_stamp),
     Topic#lw_topic.contents,
     Topic#lw_topic.attachment,
     length(Topic#lw_topic.replies)}.

%%--------------------------------------------------------------------------------------

read_unread(UUID) ->
    lw_instance:read_unread(UUID,topic).

%%--------------------------------------------------------------------------------------

do_create_topic(OwnerID, Content, MemberIds, Attachment, Time) ->
    TopicID = lw_id_creater:generate_topicid(),
    lw_db:act(save,topic,{TopicID, OwnerID, Content, MemberIds, Attachment, Time}),
    TopicID.

%%--------------------------------------------------------------------------------------

do_add_topic(UUID,TopicID) -> lw_db:act(add,topic,{UUID,relate,TopicID}).

%%--------------------------------------------------------------------------------------

transform_table() ->
    F = fun({lw_topic,UUID,OwnerID,Contents,Members_id,Replies,Attachment,Trace,_,Time,Reverse}) ->
            {lw_topic,UUID,OwnerID,Contents,Members_id,Replies,Attachment,Trace,Time,Reverse}
        end,
    mnesia:transform_table(lw_topic, F, record_info(fields, lw_topic)).

%%--------------------------------------------------------------------------------------