-module(long_poll_handler).

-compile(export_all).
-include("yaws_api.hrl").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    [_|Path] = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,

    JsonObj =
    case catch handle(Arg, Method, Path) of
    	{'EXIT', Reason} -> 
    	    io:format("Error ********************* reason:~p ~n", [Reason]),
    	    {ok, IODev} = file:open("./log/server_error.log", [append]),
    	    io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
    	    file:close(IODev),
    	    utility:pl2jso([{status, failed}, {reason, service_not_available}]);
    	Result -> 
    	    Result
    end,
    encode_to_json(JsonObj, Arg). 
	
handle(Arg, 'GET', ["fetch"]) -> 
    ConnId = utility:query_string(Arg, "connectionid"),
    xhr_poll:up(list_to_atom(ConnId)),
    receive
        Msgs->
            utility:pl2jso([{status,ok}, {msgs, utility:pl2jsos(Msgs)}])
    after 600000->
        utility:pl2jso([{status,failed}])
    end;

handle(Arg, 'POST', ["del_channel"]) -> 
    ConnId = utility:query_string(Arg, "connectionid"),
    xhr_poll:stop(ConnId),
    utility:pl2jso([{status,ok}]);

handle(Arg, 'POST', ["room"|_]) ->
    {Event, {obj, Params}} = utility:decode(Arg, [{event, b},{params, r}]),%rfc4627:decode(Arg#arg.clidata),
    Pls = [{"event", Event}| Params],
%    io:format("up post msg:~p~n", [Pls]),
    Ip=utility:client_ip(Arg),
    log(Event, Params, Ip),
    room_handler:handle_room(Event, Pls);

%% not used now.    
handle(_Arg, 'GET', ["connection"|_]) -> 
    {A,B,C} = now(),
    random:seed(A,B,C),
    ConId = list_to_atom(integer_to_list(random:uniform(10000000000000))),
    io:format("up connection id:~p~n", [ConId]),
    xhr_poll:start(ConId),
    xhr_poll:down(ConId,[{event,<<"connect">>}]),
    utility:pl2jso([{status, ok}, {connectionid,ConId}]);

handle(_Arg, _, Path) ->
    utility:pl2jso([{status,unhandled}, {path, string:join(Path,"/")}]).


origin(Arg)->
    Headers=Arg#arg.headers,
    yaws_api:get_header(Headers, 'Origin').
    
%% encode to json format
encode_to_json(JsonObj,_Arg) ->
    [{header, "Access-Control-Allow-Origin: *"}, {content, "application/json", rfc4627:encode(JsonObj)}].

log(Event, CmdList, Ip) -> 
    {ok, IODev} = file:open("./room.log", [append]),
    io:format(IODev, "Event: ~p ~p ~nCmdList: ~p~nFrom: ~p~n~n~n", [Event, erlang:localtime(), CmdList, Ip]),
    file:close(IODev).
    

