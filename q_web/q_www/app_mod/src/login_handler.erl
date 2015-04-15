%%%------------------------------------------------------------------------------------------
%%% @doc Yaws  AppMod for path: /login
%%%------------------------------------------------------------------------------------------

-module(login_handler).
-compile(export_all).

-include("yaws_api.hrl").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,

   
    JsonObj =
    case catch handle(Arg, Method, Path) of
    	{'EXIT', Reason} -> 
    	    io:format("Error ********************* reason:~p ~n", [Reason]),
    	    utility:pl2jso([{status, failed}, {reason, service_not_available}]);
    	Result -> 
    	    Result
    end,
   {content, "application/json", rfc4627:encode(JsonObj)}.
	
%% handle group request
handle(Arg, 'POST', ["login","check_user_name"]) ->
    {UserName} =  utility:decode(Arg, [{user_name, b}]),
    case user_agent:check_user_name(UserName) of
        ok -> utility:pl2jso([{status, ok}]); 
        dup_name -> utility:pl2jso([{status, failed}, {reason, dup_name}])  
    end;

handle(Arg, 'POST', ["login","register_user"]) ->
    {UserName, Password} =  utility:decode(Arg, [{user_name, b},{password, b}]),
    case user_agent:register_user(UserName, Password) of
        ok -> utility:pl2jso([{status, ok}]); 
        dup_name -> utility:pl2jso([{status, failed}, {reason, dup_name}]);
        user_full -> utility:pl2jso([{status, failed}, {reason, user_full}])
    end;

handle(Arg, 'POST', ["login"]) -> 
    {Account, Password} = utility:decode(Arg, [{account, b}, {password, b}]),
    case user_agent:login(Account, Password) of
        {ok, {UUID, Attr, Labels, Friends, Sessions, Unreads}} ->
            utility:pl2jso([{status, ok}, {uuid, UUID}, 
                            {attributes, utility:pl2jso(Attr)},
                            {labels, Labels},
                            {friends, utility:pl2jsos([{attributes, fun(As)-> utility:pl2jso(As) end}], Friends)},
                            {sessions,utility:pl2jsos(Sessions)},
                            {unread_messages, utility:pl2jsos(Unreads)}]);
        failed ->
            utility:pl2jso([{status, failed}, {reason, auth_wrong}])  
    end.


