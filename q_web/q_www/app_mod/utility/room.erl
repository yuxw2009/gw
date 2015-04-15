-module(room).
-compile(export_all).

-define(IDLE, idle).
-define(JOINING, joining).
-define(OCCUPIED, occupied).
-define(LEFT, left).
-define(DETECT_TIMER, 60*1000).

-record(state, {name, timeout_num=0, tr, relayer}).
-include("room.hrl").

login(Room, From, CmdList)->
    Sdp=proplists:get_value("sdp", CmdList),
    case whereis(Room) of
        undefined-> register(Room, spawn(fun()-> loop0(#state{name=Room}) end));
        _->      void
    end,
    Room ! {login, From, Sdp}.
logout(Room,From, _CmdList)->
    case whereis(Room) of
        undefined->void;
        _-> Room ! {logout, From}
    end,
    xhr_poll:stop_opr(Room).

on_event(Room, From, Event, Params)->
    case whereis(Room) of
        undefined->void;
        _-> Room ! {event, {Event, Params}}
    end.
    
get_opr(Room, From, _CmdList)->
    Room ! {get_opr, From},
    receive
        Result-> Result
    after 5000->
        timeout
    end.

invite(Room, From, CmdList)->
    Sdp=proplists:get_value("sdp", CmdList),
    Room ! {invite, From, Sdp}.
join(Room, From, CmdList)->
    Sdp=proplists:get_value("sdp", CmdList),
    Room ! {join, From, Sdp}.

clt_leave(Room, _, CmdList)->
    case whereis(Room) of
    undefined-> void;
    _-> Room ! {clt_leave, CmdList}
    end,
    xhr_poll:stop_clt(Room).

    
opr_leave(Room, _, CmdList)->
    case whereis(Room) of
    undefined-> void;
    _-> Room ! {opr_leave, CmdList}
    end.
    
shakehand_opr(Room,_From, CmdList)->
    case whereis(Room) of
    undefined->
        [{status,failed}, {reason, room_no_opr},{src,shakehand_opr}];
    _->
        Room !{shakehand_opr, CmdList},
        [{status,ok},{src, shakehand_opr}]
    end.
    
loop0(State)->
    {ok, Tr}= timer:send_interval(room_mgr:get_dt(),shakehand_detect),
    loop(State#state{tr=Tr}).
loop(State=#state{})->
    NewState = 
    receive
        Msg-> handle_msg(Msg, State)
    end,
    loop(NewState).
    
    
handle_msg({invite, _From, Sdp}, State=#state{name=Room})->
    Relayer=create_relayer(),
    NewSdp = update_offer(Relayer, Sdp),
    xhr_poll:down_opr(Room, [{event, invite}, {room, Room},{peer_sdp, NewSdp}]),
    State#state{relayer=Relayer};
    
handle_msg({join, _From, Sdp}, State=#state{name=Room, relayer=Relayer})->
    NewSdp = update_answer(Relayer, Sdp),
    xhr_poll:down_clt(Room, [{room,Room}, {peer_sdp, NewSdp}, {event, join}]),
    State;

handle_msg({clt_leave, _CmdList}, State=#state{name=Room, relayer=Relayer})->
    destroy_relayer(Relayer),
    xhr_poll:down_opr(Room, [{event,leave}, {room, Room}]),
    State#state{relayer=undefined};

handle_msg({event, {Event, Params}}, State=#state{name=Room})->
    AsClient = proplists:get_value("asClient", Params),
%    io:format("send evnet ~p~n", [[{event, Event}|Params]]),
    case AsClient of
    true->
        xhr_poll:down_opr(Room, [{event, Event}|Params]);
    _-> xhr_poll:down_clt(Room, [{event, Event}|Params])
    end,
    State;

handle_msg({opr_leave, _CmdList}, State=#state{name=Room, relayer=Relayer })->
    destroy_relayer(Relayer),
    xhr_poll:down_clt(Room, [{event,leave}, {room, Room}]),
    xhr_poll:stop_clt(Room),
    State#state{relayer=undefined};

    
handle_msg({get_opr, _From}, State=#state{})->
    State;
handle_msg({shakehand_opr, _CmdList}, State) ->
        State#state{timeout_num=0};

handle_msg(shakehand_detect, State=#state{timeout_num=N, name=Room}) ->
    case N>1 of
    true->
        room_mgr:empty(Room),
        io:format("shakehand_detect: timeoutnum:~p   Room:~p quited! ~n", [N, Room]),
        log("******************************shakehand_detect: timeoutnum:~p   Room:~p quited! ~n", [N, Room]),
        exit(normal);
    _->
        State#state{timeout_num=N+1}
    end;

handle_msg({login, _From, _OprSdp}, State=#state{})->
    State#state{};
handle_msg({logout, _From},_State=#state{})->
    exit(normal);
handle_msg(no_detect, State=#state{tr=Tr})->
    timer:cancel(Tr),
    State;
    
handle_msg(detect, State)->
    Tr= timer:send_interval(?DETECT_TIMER,shakehand_detect),
    State#state{tr=Tr};
    
handle_msg(_, State)->
    State.

room_atom(CmdList)->
    Bin=proplists:get_value("room", CmdList),
    list_to_atom(binary_to_list(Bin)).

no_detect(Room)->
	Room ! no_detect.
detect(Room)->
	Room ! detect.

detect_timer()-> 	?DETECT_TIMER.

rooms()->
    [R || #room_info{no=R}<-room_mgr:show(), whereis(R) =/=undefined].

log(Str, Args) -> 
    {ok, IODev} = file:open("./room.log", [append]),
    io:format(IODev, Str, Args),
    file:close(IODev).

create_relayer()  ->
    swap:create_relayer(udp).
update_offer(PID, OfferSDP) ->
  swap:update_offer(PID,OfferSDP).
update_answer(PID, AnswerSDP) -> 
    swap:update_answer(PID, AnswerSDP).
destroy_relayer(undefined)->
    void;
destroy_relayer(PID)->
    swap:destroy_relayer(PID).
