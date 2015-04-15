%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user datebase
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_db).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

act(save,task,{TaskID, OwnerID, Content, MemberIds, Attachment, Time}) ->
    F = fun() ->
            Task=#lw_task{uuid=TaskID,owner_id=OwnerID,contents=Content,members_id=MemberIds,attachment=Attachment,time_stamp=Time},
            mnesia:write(Task),
            update_table(lw_verse_task,assign_unfinished,OwnerID,TaskID,fun build_verse/4,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(save,topic,{TopicID, OwnerID, Content, MemberIds, Attachment, Time}) ->
    F = fun() ->
            Topic=#lw_topic{uuid=TopicID,owner_id=OwnerID,contents=Content,members_id=MemberIds,attachment=Attachment,time_stamp=Time},
            mnesia:write(Topic),
            update_table(lw_verse_topic,assign,OwnerID,TopicID,fun build_verse/4,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(save,document,{DocId,OwnerId,FileName,FileId,Description,FileSize,MemberIds,Time}) ->
    F = fun() ->
            Doc=#lw_document{uuid=DocId,owner_id=OwnerId,file_name=FileName,file_id=FileId,file_size=FileSize,members_id=MemberIds,time_stamp=Time,discription=Description},
            mnesia:write(Doc),
            update_table(lw_verse_document,assign,OwnerId,{DocId,OwnerId,Time},fun build_verse/4,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(save,poll,{PollID, OwnerID, {Type, Content, Attachment, Options}, MemberIds, Time}) ->
    F = fun() ->
            Poll=#lw_polls{uuid=PollID,owner_id=OwnerID,type=Type,members_id=MemberIds,contents=Content,options=[{X,Y,P,0}||{X,Y,P}<-Options],time_stamp=Time,attachment=Attachment},
            mnesia:write(Poll),
            update_table(lw_verse_polls,assign,OwnerID,{PollID,{not_voted,none}},fun build_verse/4,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(save,news,{NewsID, OwnerId, Content, Time, Attachment, AttachmentName}) ->
    F = fun() ->
            News = #lw_news{uuid=NewsID,owner_id=OwnerId,contents=Content,time_stamp=Time,attachment=Attachment,attachment_name=AttachmentName},
            mnesia:write(News)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(save,question,{QusID, OwnerId, Title, Content, Tags, Time}) ->
    F = fun() ->
            Qus=#lw_question{uuid=QusID,owner_id=OwnerId,title=Title,contents=Content,tags=Tags,time_stamp=Time},
            mnesia:write(Qus)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(set,focus,{UUID,Items}) ->
    F1= fun({EntityType, EntityID, Tags}) ->
            NewSet = {{EntityType, EntityID}, Tags, erlang:localtime()},
            case mnesia:read(lw_focus,UUID,write) of
                [] -> mnesia:write(#lw_focus{uuid = UUID,focus = [NewSet]});
                [Focus] ->
                    OldSets = Focus#lw_focus.focus,
                    case lists:keyfind({EntityType, EntityID}, 1, OldSets) of
                        false ->
                            mnesia:write(Focus#lw_focus{focus = [NewSet|OldSets]});
                        _ ->
                            Replace = lists:keyreplace({EntityType, EntityID},1,OldSets,NewSet),
                            mnesia:write(Focus#lw_focus{focus = Replace})
                    end
            end
        end,
    F2= fun() -> [F1(Item)||Item<-Items] , ok end,
    mnesia:activity(transaction,F2);

%%--------------------------------------------------------------------------------------

act(vote,poll,{UUID, PollId, Choice}) ->
    F = fun() ->
            case is_user_could_vote(UUID, PollId) of
                true  ->
                    Type = check_poll_type(UUID, PollId),
                    update_vote(PollId,Choice),
                    update_verse_vote(UUID, PollId, Choice, Type);
                false -> ok
            end
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(add,poll_reply,{PollID,Reply})   -> add_reply(lw_polls,PollID,Reply);
act(add,task_reply,{TaskId,Reply})   -> add_reply(lw_task,TaskId,Reply);
act(add,topic_reply,{TopicId,Reply}) -> add_reply(lw_topic,TopicId,Reply);
act(add,question_reply,{QuestionId,UUID,Content,Time}) ->
    F = fun() ->
            update_table(lw_question,replies,QuestionId,{UUID,Content,Time},fun empty/0,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);
act(add,news_reply,{NewsID,UUID,Content,Time}) ->
    F = fun() ->
            update_table(lw_news,replies,NewsID,{UUID,Content,Time},fun empty/0,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(add,task_trace,{UUID, TaskIDs, Status, Time}) ->
    F1 = fun(TaskID) ->
            update_table(lw_task,trace,TaskID,{UUID,Status,Time},fun empty/0,fun insert_list/2)
         end,
    F2 = fun() -> [F1(TaskID)||TaskID<-TaskIDs] end,
    mnesia:activity(transaction,F2);

act(add,poll_trace,{UUID, PollIDs, Status, Time}) ->
    F1 = fun(PollID) ->
            update_table(lw_polls,trace,PollID,{UUID,Status,Time},fun empty/0,fun insert_list/2)
         end,
    F2 = fun() -> [F1(PollID)||PollID<-PollIDs] end,
    mnesia:activity(transaction,F2);

%%--------------------------------------------------------------------------------------

act(add,task_members,{TaskId, NewMemberIds})   -> add_members(lw_task,TaskId,NewMemberIds);
act(add,topic_members,{TopicId, NewMemberIds}) -> add_members(lw_topic,TopicId,NewMemberIds);
act(add,doc_members,{DocId, NewMemberIds})     -> add_members(lw_document,DocId,NewMemberIds);
act(add,poll_members,{PollId, NewMemberIds})   -> add_members(lw_polls,PollId,NewMemberIds);
%%--------------------------------------------------------------------------------------

act(add,doc_quote,{DocId}) ->
    F = fun() ->
            [#lw_document{quote = Quote} = Doc] = mnesia:read(lw_document,DocId,write),
            mnesia:write(Doc#lw_document{quote = Quote + 1})
        end,
    mnesia:activity(transaction,F);

act(sub,doc_quote,{DocId}) ->
    F = fun() ->
            [#lw_document{quote = Quote} = Doc] = mnesia:read(lw_document,DocId,write),
            mnesia:write(Doc#lw_document{quote = Quote - 1})
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(add,task,{UUID,Ownership,TaskID}) ->
    modify_content(lw_verse_task,Ownership,UUID,TaskID,fun build_verse/4,fun sort_insert_list/2);
act(add,topic,{UUID,Ownership,TopicID}) ->
    modify_content(lw_verse_topic,Ownership,UUID,TopicID,fun build_verse/4,fun sort_insert_list/2);
act(add,doc,{UUID,Ownership,{DocID,Content1,Content2}}) ->
    modify_content(lw_verse_document,Ownership,UUID,{DocID,Content1,Content2},fun build_verse/4,fun keysort_insert_list/2);
act(add,poll,{UUID,Ownership,{PollID,Content}}) ->
    modify_content(lw_verse_polls,Ownership,UUID,{PollID,Content},fun build_verse/4,fun keysort_insert_list/2);
act(add,dustbin,{UUID,Content}) ->
    modify_content(lw_dustbin,dustbin,UUID,Content,fun build_verse/4,fun insert_list/2);
act(add,meeting,{UUID,MeetingID,Subject,Phones,Time}) ->
    modify_content(lw_meeting,meeting,UUID,{MeetingID,Subject,Phones,Time},fun build_verse/4,fun insert_list/2);
act(add,sms,{UUID,Members,Content,Time}) ->
    modify_content(lw_sms,sms,UUID,{Members,Content,Time},fun build_verse/4,fun insert_list/2);

act(add,meeting_member,{UUID,MeetingID,{Name,Phone,0.0}}) ->
    F = fun() ->
            [#lw_meeting{meeting = Meets} = Meetings] = mnesia:read(lw_meeting,UUID,write),
            {MeetingID,Subject,Phones,Time} = lists:keyfind(MeetingID,1,Meets),
            [{ChairmanName,ChairmanPhone,ChairmanRate}|Members] = Phones,
            case ChairmanPhone of
                Phone -> 
                    ok;
                _ ->
                    NewMembers = lists:ukeysort(2,Members ++ [{Name,Phone,0.0}]),
                    NewMeets   = lists:keyreplace(MeetingID,1,Meets,{MeetingID,Subject,[{ChairmanName,ChairmanPhone,ChairmanRate}|NewMembers],Time}),
                    mnesia:write(Meetings#lw_meeting{meeting = NewMeets})
            end
        end,
    mnesia:activity(transaction,F);

act(join,meeting,{UUID,MeetingID,Phone}) ->
    F = fun() ->
            [Meetings] = mnesia:read(lw_meeting,UUID,write),
            Meets = Meetings#lw_meeting.meeting,
            {MeetingID,Subject,Phones,Time} = lists:keyfind(MeetingID,1,Meets),
            NewMeets = lists:keyreplace(MeetingID,1,Meets,{MeetingID,Subject,Phones ++ [Phone],Time}),
            mnesia:write(Meetings#lw_meeting{meeting = NewMeets})
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(del,task,{UUID,Ownership,TaskID}) ->
    modify_content(lw_verse_task,Ownership,UUID,TaskID,fun empty/0,fun delete_list/2);
act(del,topic,{UUID,Ownership,TopicID}) ->
    modify_content(lw_verse_topic,Ownership,UUID,TopicID,fun empty/0,fun delete_list/2);
act(del,doc,{UUID,Ownership,DocID}) ->
    modify_content(lw_verse_document,Ownership,UUID,DocID,fun empty/0,fun keydelete_list/2);
act(del,poll,{UUID,Ownership,PollID}) ->
    modify_content(lw_verse_polls,Ownership,UUID,PollID,fun empty/0,fun keydelete_list/2);
act(del,focus,{UUID,EntityType,EntityID}) ->
    modify_content(lw_focus,focus,UUID,{EntityType, EntityID},fun empty/0,fun keydelete_list/2);
act(del,dustbin,{UUID,Key}) ->
    modify_content(lw_dustbin,dustbin,UUID,Key,fun empty/0,fun keydelete_list/2);

%%--------------------------------------------------------------------------------------

act(finish,task,{assign,OwnerID,TaskId,Time}) ->
    F = fun() ->
            update_table(lw_task,finish_stamp,TaskId,Time,fun empty/0,fun replace_value/2),
            update_table(lw_verse_task,assign_unfinished,OwnerID,TaskId,fun empty/0,fun delete_list/2),
            update_table(lw_verse_task,assign_finished,OwnerID,TaskId,fun empty/0,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(finish,task,{relate,UUID,TaskId}) ->
    F = fun() ->
            update_table(lw_verse_task,relate_unfinished,UUID,TaskId,fun empty/0,fun delete_list/2),
            update_table(lw_verse_task,relate_finished,UUID,TaskId,fun empty/0,fun insert_list/2)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(get,finished_task_id,{UUID}) -> 
    IDs = get_attr(lw_verse_task,[assign_finished,relate_finished],UUID),
    lists:reverse(lists:usort(IDs));
act(get,assigned_unfinished_task_id,{UUID}) -> 
    IDs = get_attr(lw_verse_task,[assign_unfinished],UUID),
    lists:reverse(lists:usort(IDs));
act(get,relate_unfinished_task_id,{UUID}) -> 
    IDs = get_attr(lw_verse_task,[relate_unfinished],UUID),
    lists:reverse(lists:usort(IDs));
act(get,all_task_id,{UUID}) -> 
    IDs = get_attr(lw_verse_task,[relate_unfinished,assign_unfinished,relate_finished,assign_finished],UUID),
    lists:reverse(lists:usort(IDs));

%%--------------------------------------------------------------------------------------

act(get,all_topic_id,{UUID}) -> 
    IDs = get_attr(lw_verse_topic,[assign,relate],UUID),
    lists:reverse(lists:usort(IDs));

%%--------------------------------------------------------------------------------------

act(get,all_sms,{UUID}) ->
    F = fun() ->
            case mnesia:read(lw_sms,UUID) of
                []    -> [];
                [SMS] -> SMS#lw_sms.sms
            end
        end,
    lists:sublist(mnesia:activity(transaction,F),1,50);

%%--------------------------------------------------------------------------------------

act(get,doc_attr,{UUID,Ownership,DocID}) ->
    Attrs = get_attr(lw_verse_document,[Ownership],UUID),
    lists:keyfind(DocID,1,Attrs);
act(get,all_doc_attr,{UUID}) -> 
    Attrs = get_attr(lw_verse_document,[assign,relate],UUID),
    lists:reverse(lists:ukeysort(1,Attrs));
act(get,file_id,{DocID}) ->
    F = fun() -> [FileID] = do_get_attr(DocID,lw_document,[file_id]),FileID end,
    mnesia:activity(transaction,F);
act(get,file_quote,{DocID}) ->
    F = fun() -> [Quote] = do_get_attr(DocID,lw_document,[quote]),Quote end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(get,poll_attr,{UUID,Ownership,PollID}) ->
    Attrs = get_attr(lw_verse_polls,[Ownership],UUID),
    lists:keyfind(PollID,1,Attrs);
act(get,all_poll_id,{UUID}) ->
    Attrs = get_attr(lw_verse_polls,[assign,relate],UUID),
    lists:reverse(lists:usort([ID||{ID,_}<-Attrs]));

%%--------------------------------------------------------------------------------------

act(get,all_news,{}) ->
    F = fun() ->
            AllKeys = lists:reverse(lists:sort(mnesia:all_keys(lw_news))),
            lists:map(fun(Key) -> [News] = mnesia:read(lw_news,Key),News end,AllKeys)
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(get,all_question,{UUID}) ->
    Module = lw_config:get_user_module(),
    F = fun() ->
            AllKeys     = lists:reverse(lists:sort(mnesia:all_keys(lw_question))),
            AllQuestion = lists:map(fun(Key) -> [Qus] = mnesia:read(lw_question,Key),Qus end,AllKeys),
            [Question||Question<-AllQuestion,Module:is_same_org(UUID,Question#lw_question.owner_id)]
        end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(get,all_focus,{UUID}) ->
    get_attr(lw_focus,[focus],UUID);

%%--------------------------------------------------------------------------------------

act(get,dustbin_attr,{UUID,Key}) ->
    Attrs = get_attr(lw_dustbin,[dustbin],UUID),
    lists:keyfind(Key,1,Attrs);

act(get,all_garbages,{UUID}) ->
    get_attr(lw_dustbin,[dustbin],UUID);

%%--------------------------------------------------------------------------------------

act(get,all_meeting,{UUID}) ->
    lists:sublist(get_attr(lw_meeting,[meeting],UUID),1,50);

%%--------------------------------------------------------------------------------------

act(get,task,{TaskIDs,{finished, Index, Num}}) when is_list(TaskIDs) ->
    Tasks  = get_content(lw_task,TaskIDs,fun extract_task_key/1,fun combine_task_item/2),
    lw_lib:get_sublist(lists:reverse(lists:keysort(#lw_task.finish_stamp,Tasks)),Index,Num);
act(get,task,{TaskIDs,_}) when is_list(TaskIDs) -> 
    get_content(lw_task,TaskIDs,fun extract_task_key/1,fun combine_task_item/2);
act(get,topic,{TopicIDs}) when is_list(TopicIDs) -> 
    get_content(lw_topic,TopicIDs,fun extract_topic_key/1,fun combine_topic_item/2);
act(get,doc,{DocAttrs}) when is_list(DocAttrs) -> 
    get_content(lw_document,DocAttrs,fun extract_doc_key/1,fun combine_doc_item/2);
act(get,poll,{PollIDs}) when is_list(PollIDs) -> 
    get_content(lw_polls,PollIDs,fun extract_poll_key/1,fun combine_poll_item/2);
act(get,news,{NewsIDs}) when is_list(NewsIDs) ->
    get_content(lw_news,NewsIDs,fun extract_news_key/1,fun combine_news_item/2);
act(get,question,{QusIDs}) when is_list(QusIDs) ->
    get_content(lw_question,QusIDs,fun extract_question_key/1,fun combine_question_item/2);

%%--------------------------------------------------------------------------------------

act(get,task_in_dustbin,{TaskID}) ->
    F = fun() -> do_get_attr(TaskID,lw_task,[owner_id,contents,time_stamp]) end,
    mnesia:activity(transaction,F);
act(get,topic_in_dustbin,{TopicID}) ->
    F = fun() -> do_get_attr(TopicID,lw_topic,[owner_id,contents,time_stamp]) end,
    mnesia:activity(transaction,F);
act(get,poll_in_dustbin,{PollID}) ->
    F = fun() -> do_get_attr(PollID,lw_polls,[owner_id,contents,time_stamp]) end,
    mnesia:activity(transaction,F);
act(get,document_in_dustbin,{DocID}) ->
    F = fun() -> do_get_attr(DocID,lw_document,[owner_id,discription,file_name,file_id,file_size,time_stamp]) end,
    mnesia:activity(transaction,F);

%%--------------------------------------------------------------------------------------

act(get,poll_traces,{PollID}) ->
    F = fun() -> [Trace] = do_get_attr(PollID,lw_polls,[trace]) , Trace end,
    mnesia:activity(transaction,F);

act(get,poll_result,{PollId}) ->
    F = fun() -> 
            [Options] = do_get_attr(PollId,lw_polls,[options]),
            Options 
        end,
    [{S,P,N}||{S,_C,P,N}<-mnesia:activity(transaction,F)];

act(get,poll_state,{UUID,PollIDs}) ->
    F1= fun(PollID) ->
            [Assign,Relate] = do_get_attr(UUID,lw_verse_polls,[assign,relate]),
            case lists:keyfind(PollID,1,Assign) of
                {PollID,State} -> State;
                false -> {PollID,State} = lists:keyfind(PollID,1,Relate), State
            end
        end,
    F2= fun() -> [F1(PollID)||PollID<-PollIDs] end,
    mnesia:activity(transaction,F2);

%%--------------------------------------------------------------------------------------

act(get,poll_replies,{PollID})       -> get_replies(lw_polls,PollID);
act(get,task_replies,{TaskId})       -> get_replies(lw_task,TaskId);
act(get,topic_replies,{TopicID})     -> get_replies(lw_topic,TopicID);
act(get,question_reply,{QuestionId}) -> get_replies(lw_question,QuestionId);
act(get,news_reply,{NewsID})         -> get_replies(lw_news,NewsID);

%%--------------------------------------------------------------------------------------

act(get,task_members,{TaskId})   -> get_members(lw_task,TaskId);
act(get,topic_members,{TopicId}) -> get_members(lw_topic,TopicId);
act(get,poll_members,{PollID})   -> get_members(lw_polls,PollID);

%%--------------------------------------------------------------------------------------

act(get,task_owner_id,{TaskId})   -> get_owner_id(lw_task,TaskId);
act(get,topic_owner_id,{TopicId}) -> get_owner_id(lw_topic,TopicId);
act(get,doc_owner_id,{DocId})     -> get_owner_id(lw_document,DocId);
act(get,poll_owner_id,{PollId})   -> get_owner_id(lw_polls,PollId);

%%--------------------------------------------------------------------------------------

act(get,task_traces,{TaskId}) ->
    F = fun() -> [Trace] = do_get_attr(TaskId,lw_task,[trace]) , Trace end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

recent_insert_list(Ele,List)  -> lists:sublist([Ele|List],500).
insert_list(Ele,List)         -> [Ele|List].

recent_sort_insert_list(Ele,List) -> lists:reverse(lists:sublist(lists:sort([Ele|List]),500)).
sort_insert_list(Ele,List)        -> lists:reverse(lists:sort([Ele|List])).
keysort_insert_list(Ele,List)     -> lists:reverse(lists:keysort(1,[Ele|List])).

append_list(List1,List2)          -> List2 ++ List1.

delete_list(Ele,List)             -> List -- [Ele].
keydelete_list(Ele,List)          -> lists:keydelete(Ele,1,List).

replace_value(New,_)              -> New.

%%--------------------------------------------------------------------------------------

extract_task_key(ID) -> ID.
combine_task_item(Task,_) -> Task.

extract_topic_key(ID) -> ID.
combine_topic_item(Topic,_) -> Topic.

extract_doc_key({ID,_,_})  -> ID.
combine_doc_item(Doc,{_,From,Time}) -> {Doc,From,Time}.

extract_poll_key(ID)  -> ID.
combine_poll_item(Poll,_) -> Poll.

extract_news_key(ID)  -> ID.
combine_news_item(News,_) -> News.

extract_question_key(ID)  -> ID.
combine_question_item(News,_) -> News.

%%--------------------------------------------------------------------------------------

-define(BUILD_VERSE(Table,Tag,Key,Value),build_verse(Table,Tag,Key,Value) ->
    #Table{uuid = Key,Tag = [Value]}).

?BUILD_VERSE(lw_verse_task,assign_unfinished,UUID,TaskID);
?BUILD_VERSE(lw_verse_task,relate_unfinished,UUID,TaskID);
?BUILD_VERSE(lw_verse_topic,assign,UUID,TopicID);
?BUILD_VERSE(lw_verse_topic,relate,UUID,TopicID);
?BUILD_VERSE(lw_verse_document,assign,UUID,Doc);
?BUILD_VERSE(lw_verse_document,relate,UUID,Doc);
?BUILD_VERSE(lw_verse_polls,assign,UUID,Poll);
?BUILD_VERSE(lw_verse_polls,relate,UUID,Poll);
?BUILD_VERSE(lw_dustbin,dustbin,UUID,Dustbin);
?BUILD_VERSE(lw_meeting,meeting,UUID,Meeting);
?BUILD_VERSE(lw_sms,sms,UUID,SMS).

%%--------------------------------------------------------------------------------------

empty() -> ok.

%%--------------------------------------------------------------------------------------

add_reply(Table,ID,Reply) ->
    F = fun() -> 
            [Members] = do_get_attr(ID,Table,[replies]),
            Len = length(Members),
            update_table(Table,replies,ID,erlang:append_element(Reply,Len+1),fun empty/0,fun insert_list/2),
            Len + 1
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

add_members(Table,ID,NewMemberIds) ->
    F = fun() ->
            update_table(Table,members_id,ID,NewMemberIds,fun empty/0,fun append_list/2)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

modify_content(Table,Ownership,UUID,Content,Build,Act) ->
    F = fun() -> 
            update_table(Table,Ownership,UUID,Content,Build,Act) 
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_members(Table,ID) ->
    F = fun() -> 
            [OwnedID,Members] = do_get_attr(ID,Table,[owner_id,members_id]), 
            [OwnedID|Members] 
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_replies(Table,ID) ->
    F = fun() -> 
            [Replies] = do_get_attr(ID,Table,[replies]),
            Replies 
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_owner_id(Table,ID) ->
    F = fun() -> 
            [OwnerID] = do_get_attr(ID,Table,[owner_id]), 
            OwnerID 
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_attr(Table,Tags,UUID) when is_list(Tags) ->
    F = fun() ->
            case mnesia:read(Table,UUID) of
                []  -> [];
                [_] -> do_get_attr(UUID,Table,Tags)
            end
        end,
    lists:append(mnesia:activity(transaction,F)).

%%--------------------------------------------------------------------------------------

get_content(Table,Attrs,GetKey,Combine)  when is_list(Attrs) ->
    F1 = fun(Attr) ->
             [Content] = mnesia:read(Table,GetKey(Attr)),
             Combine(Content,Attr) 
         end,
    F2 = fun() -> [F1(Attr)||Attr<-Attrs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

is_user_could_vote(UUID, PollId) ->
    Type    = check_poll_type(UUID, PollId),
    [Items] = do_get_attr(UUID,lw_verse_polls,[Type]),
    {PollId,State} = lists:keyfind(PollId,1,Items),
    State =:= {not_voted,none}.

%%--------------------------------------------------------------------------------------

check_poll_type(UUID, PollId) ->
    [OwnerID] = do_get_attr(PollId,lw_polls,[owner_id]),
    case OwnerID =:= UUID of
        true  -> assign;
        false -> relate
    end.

%%--------------------------------------------------------------------------------------

update_vote(PollId,Choice) ->
    [Options]  = do_get_attr(PollId,lw_polls,[options]),
    {S,C,P,N}  = lists:keyfind(Choice,1,Options),
    NewOptions = lists:keyreplace(Choice,1,Options,{S,C,P,N + 1}),
    update_table(lw_polls,options,PollId,NewOptions,fun empty/0,fun replace_value/2).

update_verse_vote(UUID, PollId, Choice, Type) ->
    [Items] = do_get_attr(UUID,lw_verse_polls,[Type]),
    {PollId,_} = lists:keyfind(PollId,1,Items),
    NewItems = lists:keyreplace(PollId,1,Items,{PollId,{voted,Choice}}),
    update_table(lw_verse_polls,Type,UUID,NewItems,fun empty/0,fun replace_value/2).

%%--------------------------------------------------------------------------------------

-define(GET_ATTR(Term,Table,Tag),do_get_attr1(Term,Table,Tag) when is_atom(Tag) ->
    Term#Table.Tag).

do_get_attr(Key,Table,Tags) when is_list(Tags) ->
    case mnesia:read(Table,Key,read) of
        []     -> [];
        [Term] -> [do_get_attr1(Term,Table,Tag)||Tag<-Tags]
    end.

?GET_ATTR(Term,lw_verse_task,assign_unfinished);
?GET_ATTR(Term,lw_verse_task,relate_unfinished);
?GET_ATTR(Term,lw_verse_task,assign_finished);
?GET_ATTR(Term,lw_verse_task,relate_finished);
?GET_ATTR(Term,lw_task,owner_id);
?GET_ATTR(Term,lw_task,members_id);
?GET_ATTR(Term,lw_task,replies);
?GET_ATTR(Term,lw_task,trace);
?GET_ATTR(Term,lw_task,contents);
?GET_ATTR(Term,lw_task,time_stamp);

?GET_ATTR(Term,lw_topic,members_id);
?GET_ATTR(Term,lw_topic,replies);
?GET_ATTR(Term,lw_topic,owner_id);
?GET_ATTR(Term,lw_topic,contents);
?GET_ATTR(Term,lw_topic,time_stamp);
?GET_ATTR(Term,lw_verse_topic,assign);
?GET_ATTR(Term,lw_verse_topic,relate);

?GET_ATTR(Term,lw_document,owner_id);
?GET_ATTR(Term,lw_document,discription);
?GET_ATTR(Term,lw_document,file_name);
?GET_ATTR(Term,lw_document,file_id);
?GET_ATTR(Term,lw_document,file_size);
?GET_ATTR(Term,lw_document,time_stamp);
?GET_ATTR(Term,lw_document,quote);
?GET_ATTR(Term,lw_verse_document,assign);
?GET_ATTR(Term,lw_verse_document,relate);

?GET_ATTR(Term,lw_polls,members_id);
?GET_ATTR(Term,lw_polls,owner_id);
?GET_ATTR(Term,lw_polls,options);
?GET_ATTR(Term,lw_polls,contents);
?GET_ATTR(Term,lw_polls,time_stamp);
?GET_ATTR(Term,lw_polls,replies);
?GET_ATTR(Term,lw_polls,trace);
?GET_ATTR(Term,lw_verse_polls,assign);
?GET_ATTR(Term,lw_verse_polls,relate);

?GET_ATTR(Term,lw_question,replies);
?GET_ATTR(Term,lw_news,replies);

?GET_ATTR(Term,lw_focus,focus);

?GET_ATTR(Term,lw_dustbin,dustbin);

?GET_ATTR(Term,lw_meeting,meeting).

%%--------------------------------------------------------------------------------------

-define(UPDATE_TAB(Tab,Tag,Key,Date,Build,Act),update_table(Tab,Tag,Key,Date,Build,Act) ->
    case mnesia:read(Tab,Key,write) of
    	[]     -> mnesia:write(Build(Tab,Tag,Key,Date));
    	[Item] -> 
    	    Old    = Item#Tab.Tag,
    	    New    = Act(Content,Old),
    	    mnesia:write(Item#Tab{Tag = New})
    end).

?UPDATE_TAB(lw_verse_task,assign_unfinished,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_task,relate_unfinished,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_task,assign_finished,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_task,relate_finished,ID,Content,Build,Act);
?UPDATE_TAB(lw_task,replies,ID,Content,Build,Act);
?UPDATE_TAB(lw_task,trace,ID,Content,Build,Act);
?UPDATE_TAB(lw_task,finish_stamp,ID,Content,Build,Act);
?UPDATE_TAB(lw_task,members_id,ID,Content,Build,Act);

?UPDATE_TAB(lw_verse_topic,assign,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_topic,relate,ID,Content,Build,Act);
?UPDATE_TAB(lw_topic,members_id,ID,Content,Build,Act);
?UPDATE_TAB(lw_topic,replies,ID,Content,Build,Act);

?UPDATE_TAB(lw_verse_document,assign,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_document,relate,ID,Content,Build,Act);
?UPDATE_TAB(lw_document,members_id,ID,Content,Build,Act);

?UPDATE_TAB(lw_verse_polls,assign,ID,Content,Build,Act);
?UPDATE_TAB(lw_verse_polls,relate,ID,Content,Build,Act);
?UPDATE_TAB(lw_polls,options,ID,Content,Build,Act);
?UPDATE_TAB(lw_polls,members_id,ID,Content,Build,Act);
?UPDATE_TAB(lw_polls,replies,ID,Content,Build,Act);
?UPDATE_TAB(lw_polls,trace,ID,Content,Build,Act);

?UPDATE_TAB(lw_question,replies,ID,Content,Build,Act);
?UPDATE_TAB(lw_news,replies,ID,Content,Build,Act);

?UPDATE_TAB(lw_focus,focus,ID,Content,Build,Act);

?UPDATE_TAB(lw_dustbin,dustbin,ID,Content,Build,Act);

?UPDATE_TAB(lw_meeting,meeting,ID,Content,Build,Act);

?UPDATE_TAB(lw_sms,sms,ID,Content,Build,Act).

%%--------------------------------------------------------------------------------------