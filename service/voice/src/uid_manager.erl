-module(uid_manager).
-compile(export_all).
-record(state, {tid}).

can_call(Uid)->
    do_cmd({can_call, Uid}).
start_call(Uid, Options)->
    do_cmd({start_call, {Uid, Options}}).
stop_call(Uid)->
    do_cmd({stop_call, Uid}).

loop(State)->
    receive
        E-> loop(on_message(E, State))
    end.

on_message({{can_call, Uid}, From}, State=#state{tid=Tid})->
    case ets:lookup(Tid, Uid) of
    []->
        From ! {?MODULE, ok};
    [{Uid, SipPid}]->
        case is_process_alive(SipPid) of
        true->
            exit(SipPid,kill);
        false->
            From ! {?MODULE, ok}
        end
    end,
    State;
on_message({{start_call, {Uid, Options}}, From}, State=#state{tid=Tid})->
    case ets:lookup(Tid, Uid) of
    [{Uid, SipPid}]->
        case is_process_alive(SipPid) of
        true->
            voip_ua:stop(SipPid);
        false->
            void
        end,
        ets:delete(Tid, Uid);
    []->
        void
    end,
    NewSipPid = proplists:get_value(sip_pid, Options),
    ets:insert(Tid, {Uid,NewSipPid}),
    State;
on_message({{stop_call, Uid},From}, State=#state{tid=Tid})->
    ets:delete(Tid, Uid),
    From ! {?MODULE,ok},
    State;
on_message(_, S)->
    S.
    
start()->
    F= fun()->
    	   TID = ets:new(?MODULE,[named_table,set,public,{keypos,1}]),
    	   loop(#state{tid=TID})
    end,
    register(?MODULE, spawn(fun()-> F() end)).

do_cmd(Cmd)->
    case whereis(?MODULE) of
    undefined->    start();
    _-> ok
    end,
    ?MODULE ! {Cmd, self()},
    receive
    {?MODULE, Result}-> Result
    after 1000->
        timeout
    end.
        
