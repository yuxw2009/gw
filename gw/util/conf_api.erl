%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(conf_api).
-compile(export_all).

-include("yaws_arg.hrl").

-define(WRTC,'wconf_manager@d620').

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,

    JsonObj =
    case catch handle(Arg, Method, Path) of
        {'EXIT', Reason} -> 
            {ok, IODev} = file:open("./conf_error.log", [append]),
            io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
            file:close(IODev),
            utility:pl2jso([{status, failed}, {reason, service_not_available}]);
        Result -> 
            Result
    end,
    encode_to_json(JsonObj). 

%% handle start multi-video
handle(Arg, 'POST', ["conf"]) ->
    {UUID, Members} = utility:decode(Arg, [{uuid,i},{members, ao, [{uuid, i},{position, i}]}]),
    {ok,RoomNo}   = rpc:call(?WRTC, rooms,start_conf, [UUID,Members]),

    utility:pl2jso([{room, fun erlang:list_to_binary/1}],[{status,ok},{room, RoomNo}]);


%% handle enter multi-video room
handle(Arg, 'PUT', ["conf", RoomNo]) ->
    {UUID, Position, SDP} = utility:decode(Arg, [{uuid,i},{position, i},{sdp, b}]),
    {ok, RoomSDP} = rpc:call(?WRTC, rooms, enter_room, [RoomNo,UUID,Position,SDP]),

    utility:pl2jso([{status,ok}, {sdp, RoomSDP}]);

%% handle invite to multi-video room
handle(Arg, 'PUT', ["conf", RoomNo, "members"]) ->
    {UUID, Position} = utility:decode(Arg, [{uuid,i},{position, i}]),
    ok = rpc:call(?WRTC, rooms, invite_to_room, [RoomNo,UUID,Position]),

    utility:pl2jso([{status,ok}]);    

%% handle leave multi-video room
handle(Arg, 'DELETE', ["conf", RoomNo]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    ok =  rpc:call(?WRTC,rooms,leave_room,[RoomNo, UUID]),

    utility:pl2jso([{status,ok}]);


%% handle get multi-video room status
handle(Arg, 'GET', ["conf", "status"]) ->   
    UUID = utility:query_integer(Arg, "uuid"),
    Room = utility:query_string(Arg, "room"),

    {ok, RoomStatus} = rpc:call(?WRTC,rooms,get_room_status,[UUID,Room]),

    utility:pl2jso([{status,ok}, {room_status, 
                           utility:a2jsos([uuid, position, status],RoomStatus)
                   }]);

%% handle get multi-video ongoing room
handle(Arg, 'GET', ["conf", "ongoing"]) ->   
    UUID = utility:query_integer(Arg, "uuid"),

    case rpc:call(?WRTC,rooms, query_ongoing_room,[UUID]) of
        room_not_exist ->
            utility:pl2jso([{status,ok}, {room, <<"">>}]);
        {ok, RoomNo, Chairman, Position} ->
            utility:pl2jso([{status,ok}, 
                            {chairman,Chairman}, 
                            {room,list_to_binary(RoomNo)},
                            {position,Position}])
    end;

%% handle stop multi-video room
handle(Arg, 'DELETE', ["conf"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Room = utility:query_string(Arg, "room"),

    ok =rpc:call(?WRTC,rooms,stop_conf,[UUID,Room]),
    utility:pl2jso([{status,ok}]);


%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].

%% encode to json format
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

