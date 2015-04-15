%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/mvideo
%%%------------------------------------------------------------------------------------------
-module(mvideo_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle start multi-video
handle(Arg, 'POST', []) ->
    {UUID, SDP, Members} 
        = utility:decode(Arg, [{uuid,i},{sdp, b}, 
                               {members, ao, [{uuid,i},{position, i}]}]),

    {value, RoomNo, RoomSDP} = 
        rpc:call(snode:get_service_node(), lw_mvideo, start_conf, [UUID, SDP, Members]),
    
    utility:pl2jso([{status,ok},{room, RoomNo}, {sdp, RoomSDP}]);

%% handle invite to a multi-video room
handle(Arg, 'PUT', ["members"]) ->
    {UUID, Position, Guest, Room} = utility:decode(Arg, [{uuid,i},{position, i},{guest, i}, {room, s}]),

    ok = rpc:call(snode:get_service_node(), lw_mvideo, invite_member, [UUID, Room, Guest, Position]),

    utility:pl2jso([{status,ok}]);

%% handle enter multi-video room
handle(Arg, 'PUT', [RoomNo]) ->
    {UUID, Position, SDP} = utility:decode(Arg, [{uuid,i},{position, i},{sdp, b}]),

    {value, RoomSDP} = rpc:call(snode:get_service_node(), lw_mvideo, enter_room, [RoomNo, UUID, Position, SDP]),

    utility:pl2jso([{status,ok}, {sdp, RoomSDP}]);

%% handle leave multi-video room
handle(Arg, 'DELETE', [RoomNo]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    
    ok = rpc:call(snode:get_service_node(), lw_mvideo, leave_room, [RoomNo, UUID]),
    utility:pl2jso([{status,ok}]);


%% handle stop multi-video room
handle(Arg, 'DELETE', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Room = utility:query_string(Arg, "room"),

    ok = rpc:call(snode:get_service_node(), lw_mvideo, stop_conf, [UUID, Room]),
    utility:pl2jso([{status,ok}]);

%% handle get multi-video room status
handle(Arg, 'GET', ["status"]) ->  
    UUID = utility:query_integer(Arg, "uuid"),
    Room = utility:query_string(Arg, "room"),

    {value, RoomStatus} = rpc:call(snode:get_service_node(), lw_mvideo, get_room_status, [UUID, Room]),
    utility:pl2jso([{status,ok},{room_info, 
                           utility:a2jsos([uuid, position, status],RoomStatus)
                   }]);

%% handle get multi-video ongoing room 
handle(Arg, 'GET', ["ongoing"]) ->   
    UUID = utility:query_integer(Arg, "uuid"),
    case rpc:call(snode:get_service_node(), lw_mvideo, query_ongoing_room, [UUID]) of
        room_not_exist ->
            utility:pl2jso([{status,ok}, {room, <<"">>}]);
        {ok, RoomNo, Chairman, Position} ->
            utility:pl2jso([{status,ok}, 
                            {chairman,Chairman}, 
                            {room,RoomNo},
                            {position,Position}])
    end.