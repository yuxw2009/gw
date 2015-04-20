-module(operator).
-compile(export_all).

-include("siprecords.hrl").

start_monitor() ->
    {Pid,_} = spawn_monitor(fun()-> init() end),
	register(?MODULE, Pid),
	Pid.

syn_send(Msg)->
    ?MODULE ! {self(),Msg},
    receive
        Res -> Res 
    end.
  
call_back(Msg)-> 
    syn_send({call_back, Msg}).
    
meeting(Msg)->
    ?MODULE ! {self(),{meeting, Msg}}.

call(UUID,{Phone1,Rate1},{Phone2,Rate2},Balance) ->
    ?MODULE ! {self(),{call,UUID,{Phone1,Rate1},{Phone2,Rate2},Balance}},
    receive
        Res -> Res 
    end.

stop(UUID) ->
    ?MODULE ! {stop,UUID}.

get_call_status(UUID) ->
	?MODULE ! {self(),{get_status,UUID}},
    receive
        Res -> Res 
    end.
    
get_session_status(UUID, Phone)->
    ?MODULE ! {get_ua_status_by_phone, UUID, {self(), Phone}},
    receive
        Res -> Res 
    end.
    
init()->
    ets:new(session_tab,[named_table,protected,set,{keypos,1}]),   %%{UUID, SessionPid}
    ets:new(pid_index_tab,[named_table,protected,set,{keypos,1}]), %%{sessionPid, UUID}
    loop().

%% call: UUID,{Phone1,Rate1},{Phone2,Rate2},Balance
%% stop: UUID
%% get_status: UUID	
loop() ->
    receive
        {From,{call_back, Msg={UUID, _,_,_,_}}}->
            create_uuid_handle(UUID, From, 
                    fun()-> session:start_monitor(call_back, Msg) end),
            loop();
        {From,{call_back, Msg={UUID, _Params}}}->
            create_uuid_handle(UUID, From, 
                    fun()-> session:start_monitor(call_back, Msg) end),
            loop();
        {From,{meeting, Msg}}->
            Key = proplists:get_value(key, Msg),
            create_uuid_handle(Key, From, 
                    fun()-> meeting:start_monitor({new_meeting, From, Msg}) end),
            loop();
        {From, {call,UUID,{Phone1,Rate1},{Phone2,Rate2},Balance}} ->
            create_uuid_handle(UUID, From, 
                    fun()-> session:start_monitor(UUID,{Phone1,Rate1},{Phone2,Rate2},Balance) end),
            loop();
        {From, {start_meeting,UUID,Phones}} ->
            create_uuid_handle(UUID, From, 
                    fun()-> meeting:start_monitor({From, Phones}) end),
            loop();
        {From, {Action,UUID,Contents}} ->
            existed_uuid_handle(UUID, From, fun(SessionPid)-> SessionPid !{Action, Contents} end),
            loop();
        {stop,UUID} ->
            case ets:lookup(session_tab,UUID) of
                [] -> ok;						
                [{UUID,SessionPid}] ->
                    SessionPid  ! stop
            end,
            loop();
        {From,{get_status,UUID}} ->
            existed_uuid_handle(UUID, From, fun(SessionPid)-> SessionPid !{get_status, From} end),
            loop();
        {From, {get_active_meeting, UUID}}->
            existed_uuid_handle(UUID, From, fun(SessionPid)-> SessionPid !{get_active_meeting, From} end),
            loop();
        {'DOWN', _Ref, process, Pid, _Reason} -> 
            case ets:lookup(pid_index_tab,Pid) of
                [] -> pass;						
                [{Pid,UUID}] ->
                    ets:delete(pid_index_tab,Pid),
                    ets:delete(session_tab,UUID)
            end,
            loop();
        {act,Act}->
            Act(),
            loop();
            
        Unexpected -> 
            io:format("Operator receive unexpected Message: ~p~n",[Unexpected]),
            loop()
    end.

create_uuid_handle(UUID, From, Act)->
    case ets:lookup(session_tab,UUID) of
        [] ->
            {SessionPid,_}=Act(),
            ets:insert(session_tab,{UUID,SessionPid}),
            ets:insert(pid_index_tab,{SessionPid,UUID}),
            From ! {call_ok,UUID};						
        [{UUID,_OperatorPid}] ->
            From ! {call_failed, UUID, session_already_exist}
    end.
    
existed_uuid_handle(UUID, From, Act)->
    case ets:lookup(session_tab,UUID) of
        [] -> From ! session_not_exist;						
        [{UUID,SessionPid}] ->
            Act(SessionPid)
    end.
    
get_all()->
    Self=self(),
    Act = fun()->
                L=ets:tab2list(session_tab),
                Self ! {ok,L}
            end,
    do_act(Act).

do_act(Act)->
    operator ! {act,Act},
    receive
    {ok,R}-> R
    after 1000->
        timeout
    end.
    
test() ->
    operator ! {self(),{call,{"12345","groupid"},{"00862168897126",0.1},{"008613816461488",0.1},600}} .

conf_test() ->
    conf_test(["00862168895100","00862168897677", "008613816461488", "008618616527996", "008615300801756"]).

conf_test([]) ->
    void;
conf_test(Phones) ->
    operator ! {self(), {start_meeting, {"12345","groupid"}, Phones} }.
conf_test(UUID, Phones) ->
    operator ! {self(), {start_meeting, UUID, Phones} }.

unjoin_test(Phones) ->
    operator ! {self(), {unjoin_conf, {"12345","groupid"}, Phones} }.

join_test(Phones) ->
    operator ! {self(), {join_conf, {"12345","groupid"}, Phones} }.

get_status() ->
    operator ! {self(),{get_status,{"12345","groupid"}}}.

stop() ->
    operator ! {stop,{"12345","groupid"}}.

debug_show()->
    get_status(),
    receive
        Result-> Result
    after 1000->
        timeout
    end.
