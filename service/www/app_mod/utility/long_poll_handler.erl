-module(long_poll_handler).

-compile(export_all).
-include("yaws_api.hrl").

%% yaws callback entry
out(Arg0) ->
    Uri = yaws_api:request_url(Arg0),
    [_|Path] = string:tokens(Uri#url.path, "/"), 
    Method = (Arg0#arg.req)#http_request.method,
    Arg= 
    case catch rfc4627:decode(Arg0#arg.clidata) of
    {ok,{obj,[{"data_enc",<<_:7/binary,Base64_Json_bin/binary>>}]},_}->
        Json_bin=utility:fb_decode_base64(Base64_Json_bin),
        Arg0#arg{clidata=Json_bin};
    _-> Arg0
    end,

    JsonObj =
    case catch handle(Arg, Method, Path) of
    	{'EXIT', Reason} -> 
    	    room:log("~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
    	    utility:pl2jso([{status, failed}, {reason, service_not_available}]);
    	Result -> 
    	    Result
    end,
    encode_to_json(JsonObj, Arg). 
	
handle(Arg, 'POST', ["push_service"|Params]) -> 
    push_service:handle(Arg,Params);
handle(Arg, 'POST', ["fetch"]) -> 
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    case proplists:get_value("connectionid", Params) of
    undefined->utility:pl2jso([{status,failed}]);
    ConnId->
	    case whereis(list_to_atom(ConnId)) of
	    undefined-> utility:pl2jso([{status,ok},{msgs,utility:pl2jsos([[{event, server_disc}, {reason, server_no_session}]])}]);
	    Pid->
	        xhr_poll:up(Pid),
	        receive
	            Msgs->
	                utility:pl2jso([{status,ok}, {msgs, utility:pl2jsos(Msgs)}])
	        after 600000->
	            utility:pl2jso([{status,failed}])
	        end
	    end
    end;

handle(Arg, 'GET', ["fetch"]) -> 
    ConnId = utility:query_string(Arg, "connectionid"),
    case whereis(list_to_atom(ConnId)) of
    undefined-> utility:pl2jso([{status,ok},{msgs,utility:pl2jsos([[{event, server_disc}, {reason, server_no_session}]])}]);
    Pid->
        xhr_poll:up(Pid),
        receive
            Msgs->
                utility:pl2jso([{status,ok}, {msgs, utility:pl2jsos(Msgs)}])
        after 600000->
            utility:pl2jso([{status,failed}])
        end
    end;

handle(Arg, 'POST', ["del_channel"]) -> 
    ConnId = utility:query_string(Arg, "connectionid"),
    xhr_poll:stop(ConnId),
    utility:pl2jso([{status,ok}]);

handle(Arg, 'POST', ["room"|_]) ->
    Ip=utility:client_ip(Arg),
    {Event, {obj, Params}} = utility:decode(Arg, [{event, b},{params, r}]),%rfc4627:decode(Arg#arg.clidata),
    Pls = [{"event", Event},{from_ip, Ip}| Params],
%    log(Event, Params, Ip),
    room_handler:handle_room(Event, Pls);


handle(_Arg, _, Path) ->
    utility:pl2jso([{status,unhandled}, {path, string:join(Path,"/")}]).


origin(Arg)->
    Headers=Arg#arg.headers,
    yaws_api:get_header(Headers, 'Origin').
    
%% encode to json format
encode_to_json(JsonObj,_Arg) ->
    [{header, "Access-Control-Allow-Origin: *"}, {content, "application/json", rfc4627:encode(JsonObj)}].


