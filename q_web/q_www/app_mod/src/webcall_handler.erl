%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/webcall
%%%------------------------------------------------------------------------------------------
-module(webcall_handler).
-compile(export_all).

-include("yaws_api.hrl").

-define(WVOIP_NODE, 'wvoip@ltalk.com').
-define(WVIDEO_NODE, 'manager@ltalk.com').


%%% request handlers
%% handle subphone  request
handle(Arg, 'POST', ["voip", "dtmf"]) ->
    {_UUID, SID, [Num|_]} = utility:decode(Arg, [{uuid,i},{session_id,i},{dtmf,ab}]),    
    ok = rpc:call(?WVOIP_NODE, wkr, eventVOIP, [SID, {dail, binary_to_list(Num)}]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'POST', ["voip", "comments"]) ->
    {_UUID, Comments} = utility:decode(Arg, [{uuid,i},{comments,b}]),    
    case size(Comments) > 1500 of
        false -> comment_server:comment(utility:client_ip(Arg), erlang:localtime(), Comments);
        true ->
            <<T:1500/binary, _/binary>> = Comments, 
            comment_server:comment(utility:client_ip(Arg), erlang:localtime(), T)
    end,
    utility:pl2jso([{status, ok}]);    

%% handle start VOIP call request
handle(Arg, 'POST', ["voip"]) ->
    {_UUID, SDP, Phone} = utility:decode(Arg, [{uuid,i},{sdp,b},{phone,s}]),   
    %%io:format("start voip :~p~n", [{UUID, SDP, Phone}]),
    NPhone = string:strip(Phone),
    case length(NPhone) >= 11 andalso check_country_no(NPhone) of
        true ->
            case rpc:call(?WVOIP_NODE, wkr, processVOIP, [SDP, NPhone]) of
                {successful, SID, SDP2} ->
                    comment_server:call(utility:client_ip(Arg), erlang:localtime(), NPhone, {start,SID}),
                    utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
                {failure, Reason} ->
                    comment_server:call(utility:client_ip(Arg), erlang:localtime(), NPhone, failure),
                    utility:pl2jso([{status, failed},{reason,Reason}])
            end;
        false ->
            utility:pl2jso([{status, failed},{reason,voip_failed}])
    end;

%% handle stop VOIP  request
handle(Arg, 'DELETE', ["voip"]) ->
    _UUID = utility:query_integer(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    %%io:format("stop voip :~p ~p~n", [UUID, SID]),
    comment_server:call(utility:client_ip(Arg), erlang:localtime(), "********", {stop,SID}),
    ok = rpc:call(?WVOIP_NODE, wkr, stopVOIP, [SID]),
    utility:pl2jso([{status, ok}]);

%% handle GET VOIP status request
handle(Arg, 'GET', ["voip", "status"]) ->
    _UUID = utility:query_integer(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    %%io:format("get voip status:~p ~p~n", [UUID, SID]),

    {ok, State} = rpc:call(?WVOIP_NODE, wkr, getVOIP, [SID]),
    utility:pl2jso([{status, ok}, {state, State}]);


handle(Arg, 'GET', ["video", "room"]) ->
    case rpc:call(?WVIDEO_NODE, demo_rooms,get_free_rooms, []) of
        {ok,RoomNo} ->
            comment_server:call(utility:client_ip(Arg), erlang:localtime(), success, {get_room,RoomNo}),
            utility:pl2jso([{status, ok}, {room_id, RoomNo}]);
        _ ->
            comment_server:call(utility:client_ip(Arg), erlang:localtime(), failed, get_room),
            utility:pl2jso([{status, failed}, {reason, no_free_room}])
    end;

handle(Arg, 'POST', ["video"]) ->
    try
        RoomNo = utility:query_integer(Arg, "room"),
        {BSDP} = utility:decode(Arg, [{sdp,b}]),  
        
        case rpc:call(?WVIDEO_NODE,demo_rooms,enter_room, [RoomNo,BSDP]) of
            {ok,RoomSDP} ->
                comment_server:call(utility:client_ip(Arg), erlang:localtime(), success, {enter_room, RoomNo}),
                utility:pl2jso([{status, ok}, {sdp, RoomSDP}]);
            _R ->            
                io:format("enter room failed: ~p~n", [_R]),
                comment_server:call(utility:client_ip(Arg), erlang:localtime(), failed, {enter_room, RoomNo}),
                utility:pl2jso([{status, failed}, {reason, room_full}])
        end
    catch
        _:_ -> 
            comment_server:call(utility:client_ip(Arg), erlang:localtime(), failed, {enter_room, invalid_room_no}),
            utility:pl2jso([{status, failed}, {reason, invalid_room_no}])
    end;

%% handle GET VOIP status request
handle(Arg, 'GET', ["video", "status"]) ->
    RoomNo = utility:query_integer(Arg, "room"),
    RoomStatus = rpc:call(?WVIDEO_NODE, demo_rooms,get_status, [RoomNo]),
    utility:pl2jso([{status, ok}, {room_info, RoomStatus}]);


%% handle stop VOIP  request
handle(Arg, 'DELETE', ["video"]) ->
    RoomNo = utility:query_integer(Arg, "room"),
    
    rpc:call(?WVIDEO_NODE,demo_rooms,release_room,[RoomNo]),
    comment_server:call(utility:client_ip(Arg), erlang:localtime(), success, {release_room, RoomNo}),
    utility:pl2jso([{status, ok}]).             	



check_country_no(CN) ->
    Allows = ["0054","0061", "0055", "001", "0086","0033",
              "0049","00852","0091","0081","0082","0052",
              "0079","0065","0046","00886","0066","0044"],
    check_country_no(Allows, CN).

check_country_no([], _CN) -> false;
check_country_no([H|T], CN) ->
    case string:str(CN,H) of
        1 -> true;
        _ -> check_country_no(T,CN)
    end.



 

