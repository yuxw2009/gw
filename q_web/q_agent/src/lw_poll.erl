%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user polls
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_poll).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_poll(OwnerID, {Type, Content, Attachment, Options}, MemberIds) ->
    Time   = erlang:localtime(),
    PollID = do_create_polls(OwnerID, {Type, Content, Attachment, Options}, MemberIds, Time),
    spawn(fun() -> lw_group:update_recent_group(OwnerID,MemberIds) end),
    spawn(fun() -> lw_indexer:index({poll,PollID},OwnerID,Content) end),
    lw_router:send(MemberIds,{poll,PollID,OwnerID}),
    {PollID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

trace_poll(UUID, PollID, Status) when is_integer(PollID) ->
    trace_poll(UUID, [PollID], Status);
trace_poll(UUID, PollIDs, Status) when is_list(PollIDs) ->
    Time = erlang:localtime(),
    lw_db:act(add,poll_trace,{UUID, PollIDs, Status, Time}),
    ok.

%%--------------------------------------------------------------------------------------

get_traces_of_poll(_UUID, PollID) ->
    Traces = lw_db:act(get,poll_traces,{PollID}),
    [trans_trace_format(Trace)||Trace<-Traces].

%%--------------------------------------------------------------------------------------

reply_poll(From, PollID, Content) ->
    reply_poll(From, PollID, Content, -1, -1).

reply_poll(From, PollID, Content, To, Index) ->
    Time     = erlang:localtime(),
    Reply    = {From,To,Content,Time,Index},
    NewIndex = lw_db:act(add,poll_reply,{PollID,Reply}),
    Members  = 
        case To of
            -1 -> lw_db:act(get,poll_members,{PollID});
            _  -> To
        end,
    NewReply = erlang:append_element(Reply,NewIndex),
    lw_router:send(Members,{reply,poll,{PollID,trans_reply_format(NewReply)},From}),
    {lw_lib:trans_time_format(Time),NewIndex}.

%%--------------------------------------------------------------------------------------

find_reply_trace(_UUID,PollID,Index) ->
    Replies = lists:reverse(lw_db:act(get,poll_replies,{PollID})),
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

get_all_replies_of_poll(_UUID, PollID) ->
    Replies = lw_db:act(get,poll_replies,{PollID}),
    [trans_reply_format(Reply)||Reply<-Replies].

%%--------------------------------------------------------------------------------------

vote(UUID, PollId, Choice) -> 
    spawn(fun() -> trace_poll(UUID, PollId, {voted}) end),
    spawn(fun() -> lw_db:act(vote,poll,{UUID, PollId, Choice}) end),
    ok.


%%--------------------------------------------------------------------------------------

invite_new_member(UUID, PollId, NewMemberIds) ->
    OwnerID = lw_db:act(get,poll_owner_id,{PollId}),
    spawn(fun() -> trace_poll(UUID, PollId, {invited,NewMemberIds}) end),
    spawn(fun() -> lw_group:update_recent_group(UUID,NewMemberIds) end),
    spawn(fun() -> lw_db:act(add,poll_members,{PollId, NewMemberIds}) end),
    lw_router:send(NewMemberIds,{poll,PollId,OwnerID}),
    ok.

%%--------------------------------------------------------------------------------------

get_all_polls(UUID,Index,Num) ->
    PollIDs = lw_db:act(get,all_poll_id,{UUID}) -- read_unread(UUID),
    TargetPollIDs = lw_lib:get_sublist(PollIDs,Index,Num),
    get_poll_content(UUID,TargetPollIDs).

%%--------------------------------------------------------------------------------------

get_poll_content(UUID,PollID) when is_tuple(PollID) ->
    [Poll] = get_poll_content(UUID,[PollID]),
    Poll;
get_poll_content(UUID,PollIDs) when is_list(PollIDs) ->
    Polls  = [trans_poll_format(Poll)||Poll <- lw_db:act(get,poll,{PollIDs})],
    States = get_state(UUID,PollIDs),
    lists:zipwith(fun(A,B) -> erlang:append_element(A, B) end,Polls,States).

%%--------------------------------------------------------------------------------------

get_poll_result(_UUID, PollId) -> lw_db:act(get,poll_result,{PollId}).

%%--------------------------------------------------------------------------------------

is_repeat(UUID,PollID) ->
    PollIDs = lw_db:act(get,all_poll_id,{UUID}),
    lists:member(PollID, PollIDs).

%%--------------------------------------------------------------------------------------

recover_into_verse_table(UUID,Ownership,{PollID,Content}) -> 
    lw_db:act(add,poll,{UUID,Ownership,{PollID,Content}}).

%%--------------------------------------------------------------------------------------

remove_from_verse_table(UUID,Ownership,PollID) ->
    lw_db:act(del,poll,{UUID,Ownership,PollID}).

%%--------------------------------------------------------------------------------------

get_from_verse_table(UUID,Ownership,PollID) ->
    lw_db:act(get,poll_attr,{UUID,Ownership,PollID}).

%%--------------------------------------------------------------------------------------

filter_related_id(UUID,PollID) when is_integer(PollID) ->
    filter_related_id(UUID,[PollID]);

filter_related_id(UUID,PollIDs) when is_list(PollIDs) ->
    Relates = lw_db:act(get,all_poll_id,{UUID}),
    [PollID||PollID<-PollIDs,lists:member(PollID,Relates)].

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

read_unread(UUID) ->
    lw_instance:read_unread(UUID,poll).

%%--------------------------------------------------------------------------------------

trans_poll_format(Poll) ->
    {Poll#lw_polls.uuid,
     Poll#lw_polls.owner_id,
     Poll#lw_polls.type,
     Poll#lw_polls.contents,
     Poll#lw_polls.attachment,
     [{S,C,P}||{S,C,P,_N}<-Poll#lw_polls.options],
     lw_lib:trans_time_format(Poll#lw_polls.time_stamp),
     length(Poll#lw_polls.trace)}.

%%--------------------------------------------------------------------------------------

do_create_polls(OwnerID, {Type, Content, Attachment, Options}, MemberIds, Time) ->
    PollID = lw_id_creater:generate_pollid(),
    lw_db:act(save,poll,{PollID, OwnerID, {Type, Content, Attachment, Options}, MemberIds, Time}),
    PollID.

%%--------------------------------------------------------------------------------------

do_add_poll(UUID,{PollID,Content}) -> lw_db:act(add,poll,{UUID,relate,{PollID,Content}}).

%%--------------------------------------------------------------------------------------

get_state(UUID,PollID) when is_integer(PollID) ->
    [Poll] = get_state(UUID,[PollID]),
    Poll;
get_state(UUID,PollIDs) when is_list(PollIDs) ->
    lw_db:act(get,poll_state,{UUID,PollIDs}).

%%--------------------------------------------------------------------------------------

trans_reply_format({From,To,Content,Time,TargetIndex,SelfIndex}) ->
    {From,To,Content,lw_lib:trans_time_format(Time),TargetIndex,SelfIndex}.

%%--------------------------------------------------------------------------------------

trans_trace_format({UUID,Status,Time}) ->
    {UUID,Status,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

transform_table() ->
    F = fun({lw_polls,UUID,OwnerID,Type,MemberIds,Contents,Options,Time,Attachment,Reverse}) ->
            {lw_polls,UUID,OwnerID,Type,MemberIds,[],[],Contents,Options,Time,Attachment,Reverse}
        end,
    mnesia:transform_table(lw_polls, F, record_info(fields, lw_polls)).

%%--------------------------------------------------------------------------------------