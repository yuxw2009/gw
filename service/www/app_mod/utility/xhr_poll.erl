-module(xhr_poll).
-compile(export_all).
-define(SHAKE_TIME_LEN, 60*1000).
-define(DETECT_NUM, 10).
-define(DISCONNECT_NUM,10).
-define(ANDROID, <<"android">>).
-define(IS_ANDROID(OsType),  (OsType == ?ANDROID)).
-record(state, {report_to, queue=[], pid, shake_timer,timeout_num=0, attrs=[],status=unpushable,act,os_type= ?ANDROID}).

start(Options)->
    spawn(fun()-> loop0(Options) end).
stop_clt(Room)->
    stop(room_clt(Room)).
stop_opr(Room)->
    stop(room_opr(Room)).
stop(undefined)-> void;
stop(Name) when is_list(Name)-> stop(list_to_atom(Name));
stop(Name) when is_atom(Name)-> stop(whereis(Name));
stop(Pid)-> 
    Self=self(),   
    Act=fun(#state{pid=PushPid})->
            Self ! {ack,ok},
            exit(normal)
        end,
    exe_cmd(Pid,Act),
    exit(Pid,kill).  %make sure xhr_poll is killed
tickout(undefined)-> void;
tickout(Name) when is_list(Name)-> tickout(list_to_atom(Name));
tickout(Name) when is_atom(Name)-> tickout(whereis(Name));
tickout(Pid)->    Pid ! tickout.
set_act(Pid,undefined)->    void;
set_act(Pid,Fun)->    
    io:format("xhr_poll:set_act:~p~n",[{Pid,Fun}]),
    Pid ! {set_act,Fun}.
down_clt(Room, Msg)->
    down(room_clt(Room), Msg).
down_opr(Room, Msg)->
    down(room_opr(Room), Msg).

show_all(Room)->
    Opr=show(room_opr(Room)),
    Clt=show(room_clt(Room)),
    [Opr,Clt].
show(Pid) when is_pid(Pid)->
    case is_process_alive(Pid) of
    true->    
        Pid !{show,self()},
        receive
            M-> M
        after 1000->
            timeout
        end;
     _-> not_aliveed
     end;
show(Name)->
    case whereis(Name) of
    undefined-> void;
    Pid-> 
        show(Pid)
    end.

exe_cmd(Pid,Act)->
    case is_process_alive(Pid) of
    true->     
	    Pid !{act,Act,self()},
	    receive
	    {ack,Res}->
	        io:format("xhr_poll:exe_cmd res get~n"),
	        Res
	    after 2000->
	        io:format("xhr_poll:exe_cmd timeout~n"),
	        timeout
	    end;
    _-> void
    end.
up()-> up(?MODULE).
up(ConnId) when is_list(ConnId)-> up(list_to_atom(ConnId));
up(undefined)-> void;
up(ConnId) when is_atom(ConnId)-> up(whereis(ConnId));
up({Pid,Msg})->    send(Pid, {up, {fetch_msg, self()},Msg});
up(Pid)->    send(Pid, {up, {fetch_msg, self()}}).

down(Msg)->down(?MODULE, Msg).
down(ConnId, Msg) when is_list(ConnId)-> down(list_to_atom(ConnId), Msg);
down(undefined,_)-> void;
down(ConnId, Msg) when is_atom(Msg)-> down(whereis(ConnId), Msg);
down(Pid, Msg) when is_list(Msg)->
    send(Pid,{down, Msg}).

attrs(Ba, Attrs)->
    Ba ! {attrs, Attrs}.
attrs(Ba)->
    Ba ! {get_attrs,self()},
    receive
    {get_attrs, R}-> R
    after 1000-> []
    end.
        
send(P, Msg)-> 
    P ! Msg.

loop0(Options)->
    Report_to = proplists:get_value(report_to, Options),
    timer:send_interval(?SHAKE_TIME_LEN, shake_time),
    loop(#state{report_to=Report_to,os_type=proplists:get_value(os_type,Options)}).
loop(State=#state{shake_timer=Tr,attrs=Attrs})->
    NewState = receive
                        {down, Msg}->
                            timer:cancel(Tr),
                            on_down_msg(Msg, State);
                        {attrs, NewAttrs}->
                            State#state{attrs=NewAttrs};
                        {set_act,Fun}->  
                             Fun(),
                             State#state{act=Fun};
                        {act,Act,From} ->
                            {R,NS}=Act(State),
                            From ! {ack,R},
                            NS;
                        {get_attrs,From}->
                            From ! {get_attrs, Attrs},
                            State;
                        {up, Msg}->
                            timer:cancel(Tr),
                            on_up_msg(Msg, State);
                        tickout-> dotickout(State);
                        stop-> stop_chan(State);
                        {show,From}->
                            show(From, State);
                        shake_time->
                            on_shake_time(State);
                        Evt->
                            on_evt(Evt, State)
                        end,
    loop(NewState).
is_alive(Pid)->  is_pid(Pid) andalso is_process_alive(Pid).
on_down_msg(Content, State=#state{queue=Queue, pid=Pid}) when is_pid(Pid)->
    case is_alive(Pid) of
        true-> 
            log("xhr_poll:on_down_msg1:~p~n",[Content]),
            Pid ! Queue++[Content],
            State#state{queue=[], pid=undefined};
        _->
            log("xhr_poll:on_down_msg2:~p~n",[Pid]),
            State#state{queue=Queue++[Content],pid=undefined}
    end;
on_down_msg(Content, State=#state{queue=Queue})->
    log("xhr_poll:on_down_msg3:~p~n",[Content]),
    State#state{queue=Queue++[Content]}.

on_up_msg(M, State=#state{timeout_num=TN}) when TN>0 ->
    log("~p on_up_msg rec ~p~n",[calendar:local_time(),M]),
    on_up_msg(M, State#state{timeout_num=0,status=pushable});

on_up_msg({fetch_msg, From}, State=#state{pid=From0,attrs=Attrs}) when is_pid(From0)->
    log("xhr_poll:fetch_msg:send overtime to ~p  new from:~p~n",[From0,From]),
    From0 ! {failed,overtime},
    on_up_msg({fetch_msg, From}, State#state{pid=undefined});
on_up_msg({fetch_msg, From}, State=#state{queue=[],attrs=Attrs})->
    log("xhr_poll:fetch_msg:~p attrs:~p~n",[From,Attrs]),
    State#state{pid=From};
on_up_msg({fetch_msg, From}, State=#state{queue=Queue})->
    From ! Queue,
    log("xhr_poll:fetch_msg:~p and send:~p~n",[From,Queue]),
    State#state{pid=undefined, queue=[]}.
on_shake_time(State=#state{timeout_num=TN,act=Act,os_type=OsType}) when TN<?DETECT_NUM orelse not ?IS_ANDROID(OsType)->
    if Act =/=undefined-> Act(); true-> void end,
    State#state{timeout_num=TN+1};
on_shake_time(#state{attrs=Attrs,pid=Pid,report_to=Report_to}) ->
%    room:log("xhr_poll:on_shake_time out, attrs:~p~n",[Attrs]),
    log("xhr_poll:on_shake_time out, attrs:~p~n",[Attrs]),
    if is_pid(Report_to)-> Report_to !{xhr_poll_shake_timeout, Attrs}; true-> void end,
    if is_pid(Pid)-> Pid ! [{event, server_disc},{reason, shake_hand_timeout}]; true-> void end,
    exit(shake_timeout).

show(From, State=#state{})->
    From ! State,
    State.
stop_chan(#state{pid=Pid,queue=Queue,attrs=_Attrs})->
    case is_alive(Pid) of
        true-> 
            Pid ! {failed,overtime};
        _-> void
    end,
    exit(normal).
    
dotickout(#state{pid=Pid,queue=_Queue,attrs=_Attrs})->
    case is_alive(Pid) of
        true-> 
%            Pid ! Queue++[[{reason,xhr_poll_stop_chan},{event, server_disc},{status,failed}]];
            io:format("dotickout~n"),
            Pid ! [[{event,login_otherwhere}]];
        _-> void
    end,
    exit(normal).
    
room_clt(Room)->
    list_to_atom(atom_to_list(Room)++"_clt").
room_opr(Room)->
    list_to_atom(atom_to_list(Room)++"_opr").

on_evt(Evt, State=#state{queue=Queue, pid=Pid})->
    Item=handle_evt(Evt),
%    room:log("~p handle_evt: ~p", [erlang:localtime(), Item]),
    case is_alive(Pid) of
    true->    
        Pid ! Queue++[Item],
        State#state{queue=[], pid=undefined};
    _->
        State#state{queue=Queue++[Item], pid=undefined}
    end.
    
handle_evt({Class, Cmd, {RID, PtId, PcId}}) when is_list(RID)->
    handle_evt({Class, Cmd, {list_to_atom(RID),list_to_atom(PtId), list_to_atom(PcId)}});
handle_evt({Class, Cmd, {RID, PtId, PcId, Data}}) when is_list(RID)->
    handle_evt({Class, Cmd, {list_to_atom(RID),list_to_atom(PtId), list_to_atom(PcId), Data}});
handle_evt({Class, Cmd, {RID, PtId, PcId, Data1,Data2}}) when is_list(RID)->
    handle_evt({Class, Cmd, {list_to_atom(RID),list_to_atom(PtId), list_to_atom(PcId), Data1,Data2}});
handle_evt({require, offer, {RID, PtId, PcId, Tracks,PeerPt}})->
    PeerAttrs = attrs(PeerPt),
    PeerUUID = proplists:get_value(uuid, PeerAttrs),
    IsCreator = proplists:get_value(is_creator, PeerAttrs),
    [{event,require_offer}, {room, RID}, {ptId, PtId}, {pcId, PcId},{from_uuid, PeerUUID},{is_creator, IsCreator} | Tracks];
handle_evt({require, answer, {RID, PtId, PcId, {Tracks, SDP}, PeerPt}})->
    PeerAttrs = attrs(PeerPt),
    PeerUUID = proplists:get_value(uuid, PeerAttrs),
    IsCreator = proplists:get_value(is_creator, PeerAttrs),
    [{event,require_answer}, {room, RID}, {ptId, PtId}, {pcId, PcId},{data,SDP},{from_uuid, PeerUUID},{is_creator, IsCreator}| Tracks];
handle_evt({require, close, {RID, PtId, PcId}})->
    [{event,require_close}, {room, RID}, {ptId, PtId}, {pcId, PcId}];
handle_evt({notify, candidate, {RID, PtId, PcId, Cdds}})->
    Label=proplists:get_value("label", Cdds),
    Cdd = proplists:get_value("candidate", Cdds),
    [{event,notify_candidate}, {room, RID}, {ptId, PtId}, {pcId, PcId}, {label, Label}, {candidate,Cdd}];
handle_evt({notify, state, {RID, PtId, PcId, Data}})->
    [{event,notify_state}, {room, RID}, {ptId, PtId}, {pcId, PcId},{data,Data}];
handle_evt({notify, answer, {RID, PtId, PcId, Sdp}})->
    [{event,notify_answer}, {room, RID}, {ptId, PtId}, {pcId, PcId},{data,Sdp}];


    
handle_evt(_E)->
    [].

log(Str)->log(Str,[]).
log( Str, CmdList) ->
    %io:format("~s: "++Str++"~n",[utility:d2s(erlang:localtime())|CmdList]).
    utility:log("./log/xhr_poll.log",Str,CmdList),
    ok.

test_push_mail()->
    to_do.
test_act()->
    P=start([{report_to,undefined}]),
    F=fun()-> io:format("~p test_act execute act~n",[self()]),put(test_act,ok) end,
    set_act(P,F),
    ok=get(test_act),
    show(P).

test_stop_pid()->
    P=start([{report_to,undefined}]),
    true=is_process_alive(P),
    stop(P),
    false=is_process_alive(P),
    ok.
