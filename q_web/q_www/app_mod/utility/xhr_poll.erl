-module(xhr_poll).
-compile(export_all).
-define(FETCH_TIME_LEN, 300000).
-record(state, {queue=[], pid, fetch_tr}).

start()->
    start(?MODULE).
start(Name)->
    case whereis(Name) of
    undefined->   register(Name, spawn(fun()-> loop(#state{}) end));
    _-> void
end.
stop_clt(Room)->
    stop(room_clt(Room)).
stop_opr(Room)->
    stop(room_opr(Room)).
stop(Name) when is_atom(Name)->
    case whereis(Name) of
    undefined-> void;
    Pid-> Pid ! stop
    end.
down_clt(Room, Msg)->
    down(room_clt(Room), Msg).
down_opr(Room, Msg)->
    down(room_opr(Room), Msg).

show_all(Room)->
    Opr=show(room_opr(Room)),
    Clt=show(room_clt(Room)),
    [Opr,Clt].
show(Name)->
    case whereis(Name) of
    undefined-> void;
    Pid-> 
        Pid !{show,Name},
        receive
            M-> M
        after 1000->
            timeout
        end
    end.
    
up()-> up(?MODULE).
up(ConnId) when is_list(ConnId)-> up(list_to_atom(ConnId));
up(ConnId)->    send(ConnId, {up, {fetch_msg, self()}}).

down(Msg)->down(?MODULE, Msg).
down(ConnId, Msg) when is_list(Msg)->
%    io:format("down msg: ConnId:~p  Msg:~p~n", [ConnId, Msg]),
    send(ConnId,{down, Msg}).

send(Name, Msg={down, _})-> 
    case whereis(Name) of
        undefined-> 
            start(Name);
        _-> void
    end,
    Name ! Msg;

send(Name, Msg={up, _})-> 
    case whereis(Name) of
        undefined-> 
            start(Name);
        _-> void
    end,
    Name ! Msg.
    
loop(State=#state{fetch_tr=Tr})->
    NewState = receive
                        {down, Msg}->
                            timer:cancel(Tr),
                            on_down_msg(Msg, State);
                        {up, Msg}->
                            timer:cancel(Tr),
                            on_up_msg(Msg, State);
                        stop-> stop_chan(State);
                        {show,Name}->
                            show(Name, State);
                        timeout->
                            on_timeout(State)
                        end,
    loop(NewState).
is_alive(Pid)->  is_pid(Pid) andalso is_process_alive(Pid).
on_down_msg(Content, State=#state{queue=Queue, pid=Pid}) when is_pid(Pid)->
    case is_alive(Pid) of
        true-> 
            Pid ! Queue++[Content],
            State#state{queue=[], pid=undefined};
        _->
            State#state{queue=Queue++[Content],pid=undefined}
    end;
on_down_msg(Content, State=#state{queue=Queue})->
    State#state{queue=Queue++[Content]}.

on_up_msg({fetch_msg, From}, State=#state{queue=[]})->
    {ok, Tr} = timer:send_after(?FETCH_TIME_LEN, timeout),
    State#state{pid=From, fetch_tr=Tr};
on_up_msg({fetch_msg, From}, State=#state{queue=Queue})->
    From ! Queue,
    State#state{pid=From, queue=[]}.

on_timeout(State=#state{queue=Queue, pid=Pid}) when is_pid(Pid)->
    case is_alive(Pid) of
        true-> 
            Pid ! Queue,
            State#state{queue=[],pid=undefined};
        _->
            State#state{pid=undefined}
    end.
show(Name, State=#state{})->
    io:format("chan:~p  state:~p~n", [Name, State]),
    State.
stop_chan(#state{pid=Pid,queue=Queue})->
    case is_alive(Pid) of
        true-> 
            Pid ! Queue++[[{status,failed},{event, disconnect}]];
        _-> void
    end,
    exit(normal).
    
room_clt(Room)->
    list_to_atom(atom_to_list(Room)++"_clt").
room_opr(Room)->
    list_to_atom(atom_to_list(Room)++"_opr").
    
