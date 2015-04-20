-module(auth_handler).
-compile(export_all).
-define(TOKENS,"./log/tokens.log").

%%% request handlers
%% handle stop VOIP  request
handle(Arg, 'GET', ["get_tokens"]) ->
    Ip=utility:client_ip(Arg),
    case catch utility:query_string(Arg, "uuid") of
    "lwk321"->
        {value, Tokens} = token_keeper:get_tokens(),
%        utility:log(?TOKENS, "legal:from ~p~n",[Ip]), 
        utility:pl2jso([{status, ok}, {tokens, Tokens}]);
    R->
        utility:log(?TOKENS, "illegal:from ~p uuid:~p~n",[Ip,R]), 
        utility:pl2jso([{status, ok}, {tokens, []}])
    end.

