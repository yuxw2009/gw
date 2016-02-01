-module(www_xengine).
-compile(export_all).

-include("yaws_api.hrl").
-include("call.hrl").

session_id()-> integer_to_list(mnesia:dirty_update_counter(id_table, session_id, 1)).
bill_id(Service_id)-> mnesia:dirty_update_counter(id_table, Service_id, 1).

start()-> mnesia:start().

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
%    io:format("request received! path:~p, Method:~p~n", [Path, Method]),
    R = 
    try
        handle(Arg, Method, Path)
    catch 
    throw:Reason ->
        [{status, failed}, {reason, Reason}];
    error:Reason ->
       io:format("Error: ~p~n", [Reason]),
        [{status, failed}, {reason, Reason}]
    end,
    JsonObj = yaws_utility:pl2jso(R),
%    io:format("response sended! return value: ~p,  method:~p~n Path:~p~nuri:~p~n", [JsonObj, Method,Path,Uri]),
    encode_to_json(JsonObj).

%% handle group request
handle(Arg, Method, ["xengine","meetings"|Params]) -> www_voice_handler:handle(Arg, Method, ["meetings"|Params]);
handle(Arg, Method, ["xengine","callbacks"|Params]) -> www_voice_handler:handle(Arg, Method, ["callbacks"|Params]);
handle(Arg, Method, ["xengine","cdrs"|Params]) -> www_stats:handle(Arg, Method, Params);
handle(Arg, Method, ["xengine","voip"|Params]) -> www_voice_handler:handle(Arg, Method, ["voip"|Params]);
handle(Arg, Method, ["xengine","sms"|Params]) -> www_voice_handler:handle(Arg, Method, ["sms"|Params]);
handle(_Arg, Method, Url)->  io:format("unhandled http request, Method:~p,  Url: ~p~n", [Method, Url]).

encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

