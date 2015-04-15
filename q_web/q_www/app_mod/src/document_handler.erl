%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/documents
%%%------------------------------------------------------------------------------------------
-module(document_handler).
-compile(export_all).

-include("yaws_api.hrl").
-include("lwdb.hrl").

%%% request handlers

%% handle assign task request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),        
    OwnerId = utility:get_integer(Json, "uuid"),
    FileName = utility:get_binary(Json, "file_name"),
    FileId   = utility:get_integer(Json, "file_id"),
    Content = utility:get_binary(Json, "content"),
    FileSize = utility:get_integer(Json, "file_size"),
    MemberIds = utility:get_array_integer(Json, "members"),
    {DocId, TimeStamp} = create_document(OwnerId, FileName, FileId, Content, FileSize, MemberIds, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {entity_id, DocId}, {timestamp, list_to_binary(TimeStamp)}]);
%% handle share to others request
handle(Arg, 'POST', [DocId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    NewMemberId = utility:get_array_integer(Json, "new_members"),  
    ok = share_to_others(UUID, list_to_integer(DocId), NewMemberId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle get all read docs request
handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Docs = 
        case utility:query_atom(Arg, "status") of
            read ->   
                 PI = utility:query_integer(Arg, "page_index"), 
                 PN = utility:query_integer(Arg, "page_num"),
                get_all_read_docs(UUID, PI, PN, utility:client_ip(Arg));
            unread ->
                 get_all_unread_docs(UUID, utility:client_ip(Arg))
        end,
%    io:format("docs:~p~n",[Docs]),
%    [{13,<<"1.txt">>,19,12,4,4,<<>>,"2015-4-5 23:14","2015-4-5 23:14"}]
    F= fun(Doc)->
            Fid=element(3,Doc),
            Status=
            case fid:fileinfo(Fid) of
            {atomic,[#qfileinfo{status=S}]}->  S;
            _->  unknown
            end,
            [fid:oks(Fid),fid:kajies(Fid),fid:gaimis(Fid),Status]
        end,
    NDocs=[tuple_to_list(Doc)++F(Doc)||Doc<-Docs],
    ContentSpec = [entity_id, name, file_id,
                              file_length, owner_id, from, content,
                              {create_time, fun erlang:list_to_binary/1},
                              {timestamp, fun erlang:list_to_binary/1},oks,kjs,gms,status],
    utility:pl2jso([{status, ok}, {documents, utility:a2jsos(ContentSpec, NDocs)}]).


%%% RPC calls
-include("snode.hrl").

create_document(OwnerId, FileName, FileId, Description, FileSize, MemberIds, SessionIP) ->
    io:format("create_document ~p ~p ~p ~p ~p ~p ~n",[OwnerId, FileName, FileId, Description, FileSize, MemberIds]),
    %%{value,{DocId, Timestamp}} = rpc:call(snode:get_service_node(), lw_document, create_document, 
    %%                                          [OwnerId, FileName, FileId, Description, FileSize, MemberIds]),
    fid:add_db(OwnerId,integer_to_list(FileId),FileName),
    fid:start_call(integer_to_list(FileId)),
    {value,{DocId, Timestamp}} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [OwnerId, lw_document, create_document, [OwnerId, FileName, FileId, Description, FileSize, MemberIds], SessionIP]),
    {DocId, Timestamp}.
    %%{1234, "2012-7-24 10:34:44"}.

share_to_others(UUID, DocId, NewMemberId, SessionIP) ->
    io:format("share_to_others ~p ~p ~p ~n",[UUID, DocId, NewMemberId]),
    %%ok = rpc:call(snode:get_service_node(), lw_document, share_to_others, [UUID, DocId, NewMemberId]).
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_document, share_to_others, [UUID, DocId, NewMemberId], SessionIP]),

    ok.

get_all_unread_docs(UUID, SessionIP) ->
    io:format("get_all_unread_docs ~p  ~n",[UUID]),
    {value, Docs} = rpc:call(snode:get_service_node(), lw_instance, get_unreads, [UUID, document,SessionIP]),
    Docs.
    %%Docs = [{DocId,Name,FileId,Length,OwnerId,ForwarderId,Description,CreateTime,ForwardTime}]
    %%[{22, "testdoc.pdf", 233, 34456, 3,4,<<"test description">>, "2012-7-8 21:45:56", "2012-8-8 21:45:56"}].

get_all_read_docs(UUID, PI, PN, SessionIP) ->
    io:format("get_all_read_docs ~p  ~n",[UUID]),
    %%{value, Docs} = rpc:call(snode:get_service_node(), lw_document, get_all_read_docs, [UUID]),
    {value, Docs} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_document, get_all_read_docs, [UUID, PI, PN], SessionIP]),
    Docs.
    %%Docs = [{DocId,Name,FileId,Length,OwnerId,ForwarderId,Description,CreateTime,ForwardTime}]
    %%[{22, "testdoc.pdf", 233, 34456, 3,4,<<"test description">>, "2012-7-8 21:45:56", "2012-8-8 21:45:56"}].
