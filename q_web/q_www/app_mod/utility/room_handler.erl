-module(room_handler).
-compile(export_all).

handle_room(<<"get_opr">>, Params)->
    MediaType =proplists:get_value("media_type", Params),
    io:format("room_handler  get_opr  params:~p~n", [Params]),
    Result=
    case room_mgr:get_opr(MediaType, Params) of
    {ok, Room}->
        Clt_chanPid = list_to_atom(atom_to_list(Room)++"_clt"),
        xhr_poll:start(Clt_chanPid),
        [{status,ok}, {room,Room}];
    _->
        [{status,failed}, {reason, 'sorry, no free operator'}]
    end,
    utility:pl2jso(Result);

%in: {"event":"login",params:{"room":"a","sdp":"v:0\r\no..."}}
%output: [{status,ok}, {peer_sdp, Sdp}]
handle_room(<<"login">>, Params)->
    case room_mgr:login_room(self(), Params) of
    {ok, No}-> 
        ChanPid = list_to_atom(atom_to_list(No)++"_opr"),
        xhr_poll:start(ChanPid),
        utility:pl2jso([{status,ok}, {room, No}]);
    Reason->   utility:pl2jso([{status, failed}, {reason, Reason}])
    end;

handle_room(Event, Params)->
    Result=room_mgr:up_request({Event, Params}),
    utility:pl2jso(Result).

    
