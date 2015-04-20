%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(lwork_app).
-compile(export_all).

-include("yaws_api.hrl").

origin(Arg)->
    Headers=Arg#arg.headers,
    yaws_api:get_header(Headers, 'Origin').

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
    JsonObj =
    case catch handle(Arg, Method, Path) of
    	{'EXIT', Reason} -> 
%    	    io:format("Error ********************* reason:~p ~n", [Reason]),
    	    {ok, IODev} = file:open("./log/server_error.log", [append]),
    	    io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
    	    file:close(IODev),
    	    utility:pl2jso([{status, failed}, {reason, service_not_available}]);
    	Result -> 
    	    Result
    end,
    encode_to_json(JsonObj). 
	

%% handle group request
handle(Arg, Method, ["lwork","groups"|Params]) -> group_handler:handle(Arg, Method, Params);
%% handle user auth request
handle(Arg, Method, ["lwork","auth"|Params]) -> auth_handler:handle(Arg, Method, Params);
%% handle user auth request
handle(Arg, Method, ["lwork","tasks"|Params]) -> task_handler:handle(Arg, Method, Params);
%% handle poll updates request
handle(Arg, Method, ["lwork","updates"|Params]) -> update_handler:handle(Arg, Method, Params);
%% handle voice request
handle(Arg, Method, ["lwork","voices"|Params]) -> voice_handler:handle(Arg, Method, Params);
%% handle datameeting request
handle(Arg, Method, ["lwork","datameeting"|Params]) -> datameeting_handler:handle(Arg, Method, Params);
%% handle topic request
handle(Arg, Method, ["lwork","topics"|Params]) -> topic_handler:handle(Arg, Method, Params);
%% handle poll request
handle(Arg, Method, ["lwork","polls"|Params]) -> poll_handler:handle(Arg, Method, Params);
%% handle news request
handle(Arg, Method, ["lwork","news"|Params]) -> news_handler:handle(Arg, Method, Params);
%% handle question request
handle(Arg, Method, ["lwork","questions"|Params]) -> question_handler:handle(Arg, Method, Params);
%% handle document request
handle(Arg, Method, ["lwork","documents"|Params]) -> document_handler:handle(Arg, Method, Params);
%% handle setting request
handle(Arg, Method, ["lwork","settings"|Params]) -> setting_handler:handle(Arg, Method, Params);
%% handle focus request
handle(Arg, Method, ["lwork","focus"|Params]) -> focus_handler:handle(Arg, Method, Params);
%% handle recycle request
handle(Arg, Method, ["lwork","recycle"|Params]) -> recycle_handler:handle(Arg, Method, Params);
%% handle search request
handle(Arg, Method, ["lwork","search"|Params]) -> search_handler:handle(Arg, Method, Params);
%% handle search request
handle(Arg, Method, ["lwork","sms"|Params]) -> sms_handler:handle(Arg, Method, Params);
%% handle forum request
handle(Arg, Method, ["lwork","forum"|Params]) -> forum_handler:handle(Arg, Method, Params);
%% handle forum request
handle(Arg, Method, ["lwork","video"|Params]) -> video_handler:handle(Arg, Method, Params);
%% handle message request
handle(Arg, Method, ["lwork","im"|Params]) -> im_handler:handle(Arg, Method, Params);
%% handle forum request
handle(Arg, Method, ["lwork","mvideo"|Params]) -> mvideo_handler:handle(Arg, Method, Params);
%% handle voice request
handle(Arg, Method, ["aqqq","qv"|Params]) -> qvoice:handle(Arg, Method, Params);
%% handle voice request
handle(Arg, Method, ["lwork","webcall"|Params]) -> webcall_handler:handle(Arg, Method, Params);
%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].


encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

