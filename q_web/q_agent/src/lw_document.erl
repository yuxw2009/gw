%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork document
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_document).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

create_document(OwnerId, FileName, FileId, Description, FileSize, MemberIds) ->
    Time  = erlang:localtime(),
    DocID = do_create_document(OwnerId, FileName, FileId, Description, FileSize, MemberIds, Time),
    spawn(fun() -> lw_group:update_recent_group(OwnerId,MemberIds) end),
    spawn(fun() -> 
            lw_indexer:index({document,DocID},OwnerId,FileName),
            lw_indexer:index({document,DocID},OwnerId,Description)
         end),
    lw_router:send(MemberIds,{document,{DocID,OwnerId,Time},OwnerId}),
    {DocID,lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

share_to_others(UUID, DocId, NewMemberIds) ->
    OwnerID = lw_db:act(get,doc_owner_id,{DocId}),
    spawn(fun() -> lw_group:update_recent_group(UUID,NewMemberIds) end),
    spawn(fun() -> lw_db:act(add,doc_members,{DocId, NewMemberIds}) end),
    spawn(fun() -> lw_db:act(add,doc_quote,{DocId}) end),
    lw_router:send(NewMemberIds,{document,{DocId,UUID,erlang:localtime()},OwnerID}),
    ok.

%%--------------------------------------------------------------------------------------

del_document(DocID) ->
    FileID = lw_db:act(get,file_id,{DocID}),
    Quote  = lw_db:act(get,file_quote,{DocID}),
    case Quote of
        1 ->
            FNode = lw_config:get_file_server_node(),
            rpc:call(FNode,fid,req_fsvcs,[{delete_file,FileID,[]}]);
        _ ->
            lw_db:act(sub,doc_quote,{DocID})
    end.

%%--------------------------------------------------------------------------------------

get_all_read_docs(UUID,Index,Num) ->
    DocAttrs = lw_db:act(get,all_doc_attr,{UUID}) -- read_unread(UUID),
    TargetDocAttrs = lw_lib:get_sublist(DocAttrs,Index,Num),
    get_doc_content(TargetDocAttrs).

%%--------------------------------------------------------------------------------------

get_doc_content(DocAttr) when is_tuple(DocAttr) ->
    [Doc] = get_doc_content([DocAttr]),
    Doc;
get_doc_content(DocAttrs) when is_list(DocAttrs) ->
    Docs = lw_db:act(get,doc,{DocAttrs}),
    [trans_document_format(Doc)||Doc<-Docs].

%%--------------------------------------------------------------------------------------

is_repeat(UUID,DocID) ->
    DocAttrs = lw_db:act(get,all_doc_attr,{UUID}),
    lists:keymember(DocID, 1, DocAttrs).

%%--------------------------------------------------------------------------------------

recover_into_verse_table(UUID,Ownership,{DocID,Content1,Content2}) ->
    lw_db:act(add,doc,{UUID,Ownership,{DocID,Content1,Content2}}).

%%--------------------------------------------------------------------------------------

remove_from_verse_table(UUID,Ownership,DocID) ->
    lw_db:act(del,doc,{UUID,Ownership,DocID}).

%%--------------------------------------------------------------------------------------

get_from_verse_table(UUID,Ownership,DocID) ->
    lw_db:act(get,doc_attr,{UUID,Ownership,DocID}).

%%--------------------------------------------------------------------------------------

filter_related_id(UUID,DocID) when is_integer(DocID) ->
    filter_related_id(UUID,[DocID]);

filter_related_id(UUID,DocIDs) when is_list(DocIDs) ->
    Relates = lw_db:act(get,all_doc_attr,{UUID}),
    F = fun(DocID,Acc) ->
            case lists:keyfind(DocID,1,Relates) of
                false -> Acc;
                Tuple -> [Tuple|Acc]
            end
        end,
    lists:reverse(lists:foldl(F,[],DocIDs)).

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

trans_document_format({Doc,From,Time}) ->
    {Doc#lw_document.uuid,
     Doc#lw_document.file_name,
     Doc#lw_document.file_id,
     Doc#lw_document.file_size,
     Doc#lw_document.owner_id,
     From,
     Doc#lw_document.discription,
     lw_lib:trans_time_format(Doc#lw_document.time_stamp),
     lw_lib:trans_time_format(Time)}.

%%--------------------------------------------------------------------------------------

do_create_document(OwnerId, FileName, FileId, Description, FileSize, MemberIds ,Time) ->
    DocId = lw_id_creater:generate_documentid(),
    lw_db:act(save,document,{DocId,OwnerId,FileName,FileId,Description,FileSize,MemberIds,Time}),
    DocId.

%%--------------------------------------------------------------------------------------

read_unread(UUID) -> lw_instance:read_unread(UUID,document).

%%--------------------------------------------------------------------------------------

do_add_doc(UUID,DocItem) -> lw_db:act(add,doc,{UUID,relate,DocItem}).

%%--------------------------------------------------------------------------------------

transform_table() ->
    F = fun({lw_document,UUID,OwnerID,FileName,FileID,FileSize,MemberIds,Time,Description,Reverse}) ->
            {lw_document,UUID,OwnerID,FileName,FileID,FileSize,MemberIds,Time,Description,1,Reverse}
        end,
    mnesia:transform_table(lw_document, F, record_info(fields, lw_document)).

%%--------------------------------------------------------------------------------------