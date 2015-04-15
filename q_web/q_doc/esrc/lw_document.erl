-module(lw_document).
-compile(export_all).

-define(SFIDTIMEOUT,10000).

get_all_documents(UUID) ->
	get_documents(UUID,all).

get_documents(UUID, DocIds) ->
	get_documents(UUID,DocIds,self()),
	receive
		R -> R
	after ?SFIDTIMEOUT ->
		{value,[]}
	end.

get_documents(UUID, DocIds, RecePid) ->
	sfid ! {list_owner,RecePid,UUID,DocIds}.

share_to_others(OwnerId,DocId,UUIDs) ->
	Ref=make_ref(),
	sfid ! {share_file,Ref,self(),OwnerId,[DocId],UUIDs},
	receive
		{ok,Ref} -> ok
	after ?SFIDTIMEOUT ->
		failed
	end.
	
% ----------------------------------
send2UUs(From,TO,{doc_service,share,FIs}) ->
	io:format("~p alert share~p~nto ~p~n",[From,FIs,TO]).
%	rpc:call(Node,Module,multi_send,[TO,Msg]).