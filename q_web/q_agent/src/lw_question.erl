%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user question
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_question).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_question(OwnerId, Title, Content, Tags) ->
    Time  = erlang:localtime(),
    QusID = do_create_question(OwnerId, Title, Content, Tags, Time),
    spawn(fun() -> 
              lw_indexer:index({question,QusID},OwnerId,Title),
              lw_indexer:index({question,QusID},OwnerId,Content),
              lw_indexer:index({question,QusID},OwnerId,Tags)
          end),
    {QusID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

reply_question(UUID, QuestionId, Content) ->
    Time    = erlang:localtime(),
    spawn(fun() -> lw_db:act(add,question_reply,{QuestionId,UUID,Content,Time}) end),
    lw_lib:trans_time_format(Time).

%%--------------------------------------------------------------------------------------

get_all_questions(UUID,Index,Num) ->
    AllQues = lw_db:act(get,all_question,{UUID}),
    TargetQuestions = lw_lib:get_sublist(AllQues,Index,Num),
    [trans_question_format(Qus)||Qus<-TargetQuestions].

%%--------------------------------------------------------------------------------------

get_all_replies_of_question(_UUID, QuestionId) ->
    AllReplies = lw_db:act(get,question_reply,{QuestionId}),
    [trans_reply_format(Reply)||Reply<-AllReplies].

%%--------------------------------------------------------------------------------------

get_qus_content(QusID) when is_integer(QusID) ->
    get_qus_content([QusID]);

get_qus_content(QusIDs) when is_list(QusIDs) ->
    Questions = lw_db:act(get,question,{QusIDs}),
    [trans_question_format(Qus)||Qus<-Questions].

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

trans_question_format(Question) ->
    {Question#lw_question.uuid,
     Question#lw_question.owner_id,
     lw_lib:trans_time_format(Question#lw_question.time_stamp),
     Question#lw_question.title,
     Question#lw_question.contents,
     length(Question#lw_question.replies)}.

trans_reply_format({UUID,Content,Time}) ->
    {UUID,Content,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

do_create_question(OwnerId, Title, Content, Tags, Time) ->
    QusID = lw_id_creater:generate_questionsid(),
    lw_db:act(save,question,{QusID, OwnerId, Title, Content, Tags, Time}),
    QusID.

%%--------------------------------------------------------------------------------------