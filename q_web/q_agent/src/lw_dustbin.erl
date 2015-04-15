%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork dustbin
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_dustbin).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

get_all_garbages(UUID) ->
    AllGarbages = lw_db:act(get,all_garbages,{UUID}),
    [trans_dustbin(Dustbin)||Dustbin<-AllGarbages].

act(UUID,Action,Items) when is_list(Items) ->
    [act(UUID,Type,Ownership,ID,Action)||{Type,Ownership,ID}<-Items],
    ok.

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

act(UUID,Type,Ownership,ID,Action) ->
    Content = 
        case Action of
            remove  -> ok;
            recover -> get_from_dustbin(UUID,{Type,ID});
            delete  -> get_from_verse_table(UUID,Type,Ownership,ID)
        end,
    do_act(Action,UUID,Type,Ownership,ID,Content).

%%--------------------------------------------------------------------------------------

do_act(delete,UUID,Type,Ownership,ID,ID) ->
    add_into_dustbin(UUID,{{Type,ID},erlang:localtime()}),
    remove_from_verse_table(UUID,Type,Ownership,ID);
do_act(delete,UUID,Type,Ownership,ID,{ID,Content}) ->
    add_into_dustbin(UUID,{{Type,ID},erlang:localtime(),Content}),
    remove_from_verse_table(UUID,Type,Ownership,ID);
do_act(delete,UUID,Type,Ownership,ID,{ID,Content1,Content2}) ->
    add_into_dustbin(UUID,{{Type,ID},erlang:localtime(),{Content1,Content2}}),
    remove_from_verse_table(UUID,Type,Ownership,ID);

%%--------------------------------------------------------------------------------------

do_act(recover,UUID,Type,Ownership,ID,Content) ->
    remove_from_dustbin(UUID,{Type,ID}),
    recover_into_verse_table(UUID,Type,Ownership,Content);

%%--------------------------------------------------------------------------------------

do_act(remove,UUID,documents,_Ownership,DocID,_Content) ->
    lw_document:del_document(DocID),
    remove_from_dustbin(UUID,{documents,DocID});
do_act(remove,UUID,Type,_Ownership,ID,_Content) ->
    remove_from_dustbin(UUID,{Type,ID}).

%%--------------------------------------------------------------------------------------

get_from_dustbin(UUID,Key) ->
    lw_db:act(get,dustbin_attr,{UUID,Key}).

%%--------------------------------------------------------------------------------------
    
add_into_dustbin(UUID,Content) ->
    lw_db:act(add,dustbin,{UUID,Content}).

%%--------------------------------------------------------------------------------------

remove_from_dustbin(UUID,Key) ->
    lw_db:act(del,dustbin,{UUID,Key}).

%%--------------------------------------------------------------------------------------

remove_from_verse_table(UUID,tasks,Ownership,ID) ->
    lw_task:remove_from_verse_table(UUID,Ownership,ID);
remove_from_verse_table(UUID,topics,Ownership,ID) ->
    lw_topic:remove_from_verse_table(UUID,Ownership,ID);
remove_from_verse_table(UUID,polls,Ownership,ID) ->
    lw_poll:remove_from_verse_table(UUID,Ownership,ID);
remove_from_verse_table(UUID,documents,Ownership,ID) ->
    lw_document:remove_from_verse_table(UUID,Ownership,ID).

%%--------------------------------------------------------------------------------------

recover_into_verse_table(UUID,tasks,Ownership,{{tasks,TaskID},_}) ->
    lw_task:recover_into_verse_table(UUID,Ownership,TaskID);
recover_into_verse_table(UUID,topics,Ownership,{{topics,TopicID},_}) ->
    lw_topic:recover_into_verse_table(UUID,Ownership,TopicID);
recover_into_verse_table(UUID,polls,Ownership,{{polls,PollID},_,Content}) ->
    lw_poll:recover_into_verse_table(UUID,Ownership,{PollID,Content});
recover_into_verse_table(UUID,documents,Ownership,{{documents,DocID},_,{Content1,Content2}}) -> 
    lw_document:recover_into_verse_table(UUID,Ownership,{DocID,Content1,Content2}).

%%--------------------------------------------------------------------------------------

get_from_verse_table(_UUID,tasks,_Ownership,ID) ->
    ID;
get_from_verse_table(_UUID,topics,_Ownership,ID) ->
    ID;
get_from_verse_table(UUID,polls,Ownership,ID) ->
    lw_poll:get_from_verse_table(UUID,Ownership,ID);
get_from_verse_table(UUID,documents,Ownership,ID) ->
    lw_document:get_from_verse_table(UUID,Ownership,ID).

%%--------------------------------------------------------------------------------------

trans_dustbin({{tasks,TaskID},Time}) ->
    [OwnerID,Content,CreateTime] = lw_db:act(get,task_in_dustbin,{TaskID}),
    {tasks,lw_lib:trans_time_format(Time),{TaskID,OwnerID,Content,lw_lib:trans_time_format(CreateTime)}};
trans_dustbin({{topics,TopicID},Time}) ->
    [OwnerID,Content,CreateTime] = lw_db:act(get,topic_in_dustbin,{TopicID}),
    {topics,lw_lib:trans_time_format(Time),{TopicID,OwnerID,Content,lw_lib:trans_time_format(CreateTime)}};
trans_dustbin({{polls,PollID},Time,_}) ->
    [OwnerID,Content,CreateTime] = lw_db:act(get,poll_in_dustbin,{PollID}),
    {polls,lw_lib:trans_time_format(Time),{PollID,OwnerID,Content,lw_lib:trans_time_format(CreateTime)}};
trans_dustbin({{documents,DocID},Time,_}) ->
    [OwnerID,FileDescript,FileName,FileID,FileSize,CreateTime] = lw_db:act(get,document_in_dustbin,{DocID}),
    {documents,lw_lib:trans_time_format(Time),{DocID,
                                              OwnerID,
                                              FileDescript,
                                              FileName,
                                              FileID,
                                              FileSize,
                                              lw_lib:trans_time_format(CreateTime)}}.

%%--------------------------------------------------------------------------------------