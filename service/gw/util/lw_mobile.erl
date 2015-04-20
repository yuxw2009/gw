%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(lw_mobile).
-compile(export_all).

-include("yaws_arg.hrl").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,

%    io:format("out ~p ~n", [Arg]),
    JsonObj =
    case catch handle(Arg, Method, Path) of
        {'EXIT', Reason} -> 
            io:format("Error ********************* reason:~p ~n", [Reason]),
            {ok, IODev} = file:open("./server_error.log", [append]),
            io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
            file:close(IODev),
            utility:pl2jso([{status, failed}, {reason, service_not_available}]);
        Result -> 
            Result
    end,
	encode_to_json(JsonObj).

handle(Arg, 'POST', ["lwork", "mobile", "voip", "calls"]) ->
    {UserID, CallerPhone, CalleePhone, {IPs, Port, Codec}} = utility:decode(Arg, [{user_id, s}, {caller_phone, s}, {callee_phone, s},
                                       {sdp, o, [{ip, as}, {port, i}, {codec, s}]}]),
    

   {successful,SessionID,{PeerIP,PeerPort}} = avanda:processNATIVE(IPs, Port, CalleePhone),
    io:format("start receive: ~p~npeer ~p:~p~n",[{UserID, CallerPhone, CalleePhone, {IPs, Port, Codec}},PeerIP,PeerPort]),

   utility:pl2jso([{status, ok},{session_id, SessionID}, {ip, list_to_binary(PeerIP)}, {port, PeerPort}, {codec, 102}]);



handle(Arg, 'DELETE', ["lwork", "mobile", "voip", "calls"]) ->
    SessionID = utility:query_integer(Arg, "session_id"),
     io:format("stop receive: ~p~n",[SessionID]),
    ok = avanda:stopNATIVE(SessionID),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'GET', ["lwork",  "mobile", "voip", "calls"]) ->
     SessionID = utility:query_integer(Arg, "session_id"),
     io:format("get receive: ~p~n",[SessionID]),
     {ok,Status} = avanda:getNATIVE(SessionID),
   
     utility:pl2jso([{status, ok}, {peer_status, Status}]);
   
   
%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].

%% encode to json format
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

