%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork task
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_task).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_task(OwnerID, Content, MemberIds, Attachment) ->
    Time   = erlang:localtime(),
    TaskID = do_create_task(OwnerID, Content, MemberIds, Attachment, Time),
    spawn(fun() -> lw_group:update_recent_group(OwnerID,MemberIds) end),
    spawn(fun() -> lw_indexer:index({task,TaskID},OwnerID,Content) end),
    lw_router:send(MemberIds,{task,TaskID,OwnerID}),
    lw_router:push_notification(MemberIds,OwnerID,task),
    {TaskID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

get_tasks_with_type(UUID, finished, Index, Num) ->
    TaskIDs = lw_db:act(get,finished_task_id,{UUID}) -- read_unread(UUID),
    get_task_content(TaskIDs,{finished, Index, Num});
get_tasks_with_type(UUID, {owned,unfinished}, Index, Num) ->
    TaskIDs = lw_db:act(get,assigned_unfinished_task_id,{UUID}) -- read_unread(UUID),
    TargetTaskIDs = lw_lib:get_sublist(TaskIDs,Index,Num),
    get_task_content(TargetTaskIDs,normal);
get_tasks_with_type(UUID, {assigned,unfinished}, Index, Num) ->
    TaskIDs = lw_db:act(get,relate_unfinished_task_id,{UUID}) -- read_unread(UUID),
    TargetTaskIDs = lw_lib:get_sublist(TaskIDs,Index,Num),
    get_task_content(TargetTaskIDs,normal).

%%--------------------------------------------------------------------------------------

reply_task(From, TaskId, Content) ->
    reply_task(From, TaskId, Content, -1, -1).

reply_task(From, TaskId, Content, To, Index) ->
    Time     = erlang:localtime(),
    Reply    = {From,To,Content,Time,Index},
    NewIndex = lw_db:act(add,task_reply,{TaskId,Reply}),
    Members  = 
        case To of
            -1 -> lw_db:act(get,task_members,{TaskId});
            _  -> [To]
        end,
    NewReply = erlang:append_element(Reply,NewIndex),
    lw_router:send(Members,{reply,task,{TaskId,trans_reply_format(NewReply)},From}),
    lw_router:push_notification(Members,From,{reply,task}),
    {lw_lib:trans_time_format(Time),NewIndex}.

%%--------------------------------------------------------------------------------------

trace_task(UUID, TaskID, Status) when is_integer(TaskID) ->
    trace_task(UUID, [TaskID], Status);
trace_task(UUID, TaskIDs, Status) when is_list(TaskIDs) ->
    Time = erlang:localtime(),
    lw_db:act(add,task_trace,{UUID, TaskIDs, Status, Time}),
    ok.

%%--------------------------------------------------------------------------------------

find_reply_trace(_UUID,TaskID,Index) ->
    Replies = lists:reverse(lw_db:act(get,task_replies,{TaskID})),
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

get_all_replies_of_task(_UUID, TaskId) ->
    Replies = lw_db:act(get,task_replies,{TaskId}),
    [trans_reply_format(Reply)||Reply<-Replies].

%%--------------------------------------------------------------------------------------

finish_task(UUID, TaskId) ->
    Time    = erlang:localtime(),
    Members = lw_db:act(get,task_members,{TaskId}),
    spawn(fun() -> trace_task(UUID, TaskId, {finish}) end),
    spawn(fun() -> finish_task(assign,UUID,TaskId,Time) end),
    lw_router:send(Members,{task_finished,{TaskId,lw_lib:trans_time_format(Time)},UUID}),
    lw_lib:trans_time_format(Time).

%%--------------------------------------------------------------------------------------

finish_task(relate,UUID,TaskId)         -> lw_db:act(finish,task,{relate,UUID,TaskId}).
finish_task(assign,OwnerID,TaskId,Time) -> lw_db:act(finish,task,{assign,OwnerID,TaskId,Time}).

%%--------------------------------------------------------------------------------------

invite_new_member(UUID, TaskId, NewMemberIds) ->
    OwnerID = lw_db:act(get,task_owner_id,{TaskId}),
    spawn(fun() -> lw_group:update_recent_group(UUID,NewMemberIds) end),
    spawn(fun() -> lw_db:act(add,task_members,{TaskId, NewMemberIds}) end),
    spawn(fun() -> trace_task(UUID, TaskId, {invite,NewMemberIds}) end),
    lw_router:send(NewMemberIds,{task,TaskId,OwnerID}),
    ok.

%%--------------------------------------------------------------------------------------

get_traces_of_task(_UUID, TaskId) ->
    Traces = lw_db:act(get,task_traces,{TaskId}),
    [trans_trace_format(Trace)||Trace<-Traces].

%%--------------------------------------------------------------------------------------

is_repeat(UUID,TaskID) ->
    TaskIDs = lw_db:act(get,all_task_id,{UUID}),
    lists:member(TaskID, TaskIDs).

%%--------------------------------------------------------------------------------------

recover_into_verse_table(UUID,Ownership,TaskID) -> lw_db:act(add,task,{UUID,Ownership,TaskID}).

%%--------------------------------------------------------------------------------------

remove_from_verse_table(UUID,Ownership,TaskID)  -> lw_db:act(del,task,{UUID,Ownership,TaskID}).

%%--------------------------------------------------------------------------------------

filter_related_id(UUID,TaskID) when is_integer(TaskID) ->
    filter_related_id(UUID,[TaskID]);
filter_related_id(UUID,TaskIDs) when is_list(TaskIDs) ->
    Relates = lw_db:act(get,all_task_id,{UUID}),
    [TaskID||TaskID<-TaskIDs,lists:member(TaskID,Relates)].

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

del_task_table() ->
    mnesia:clear_table(lw_task),
    mnesia:clear_table(lw_verser_task).

%%--------------------------------------------------------------------------------------

read_unread(UUID) ->
    lw_instance:read_unread(UUID,task).

%%--------------------------------------------------------------------------------------

do_create_task(OwnerID, Content, MemberIds, Attachment, Time) ->
    TaskID = lw_id_creater:generate_taskid(),
    lw_db:act(save,task,{TaskID, OwnerID, Content, MemberIds, Attachment, Time}),
    TaskID.

%%--------------------------------------------------------------------------------------

get_task_content(TaskID,Type) when is_integer(TaskID) ->
    [Task] = get_task_content([TaskID],Type),
    Task;
get_task_content(TaskIDs,Type) when is_list(TaskIDs) ->
    Tasks = lw_db:act(get,task,{TaskIDs,Type}),
    [trans_task_format(X,Type)||X<-Tasks].

%%--------------------------------------------------------------------------------------

do_add_task(UUID,TaskID) -> lw_db:act(add,task,{UUID,relate_unfinished,TaskID}).

%%--------------------------------------------------------------------------------------

trans_task_format(Task,normal) ->
    {Task#lw_task.uuid,
     Task#lw_task.owner_id,
     lw_lib:trans_time_format(Task#lw_task.time_stamp),
     Task#lw_task.contents,
     Task#lw_task.attachment,
     length(Task#lw_task.replies),
     length(Task#lw_task.trace)};
trans_task_format(Task,{finished,_,_}) ->
    {Task#lw_task.uuid,
     Task#lw_task.owner_id,
     lw_lib:trans_time_format(Task#lw_task.time_stamp),
     lw_lib:trans_time_format(Task#lw_task.finish_stamp),
     Task#lw_task.contents,
     Task#lw_task.attachment,
     length(Task#lw_task.replies),
     length(Task#lw_task.trace)};
trans_task_format(Task,focus) ->
    IsFinished = 
        case Task#lw_task.finish_stamp of
            undefined ->
                unfinished;
            _ ->
                finished
        end,
    {Task#lw_task.uuid,
     Task#lw_task.owner_id,
     lw_lib:trans_time_format(Task#lw_task.time_stamp),
     Task#lw_task.contents,
     Task#lw_task.attachment,
     length(Task#lw_task.replies),
     length(Task#lw_task.trace),
     IsFinished}.

trans_reply_format({From,To,Content,Time,TargetIndex,SelfIndex}) ->
    {From,To,Content,lw_lib:trans_time_format(Time),TargetIndex,SelfIndex}.

trans_trace_format({UUID,Status,Time}) ->
    {UUID,Status,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------