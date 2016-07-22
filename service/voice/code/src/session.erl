-module(session).
-compile(export_all).

-record(state,{uuid,
                          group_id,
                          caller_name,
                          caller_pid,
               caller_phone,
               caller_rate,
               caller_status,
               callee_name,
               callee_pid,
               callee_phone,
               callee_rate,
               callee_status,
               session_valid = false,
               start_time,        %% calendar:local_time()
               max_talking_time,  %% seconds
               options,
               timer_ref
               }). 
               
-define(DETECTING_INTERVAL, 5000).

start_monitor(call_back, Msg)->
    spawn_monitor(fun()-> init(call_back, Msg) end).

start_monitor(UUID,{Phone1,Rate1},{Phone2,Rate2},MaxTalkingTime) when is_float(Rate1),is_float(Rate2),is_integer(MaxTalkingTime)->
    spawn_monitor(fun()-> init(UUID,{Phone1,Rate1},{Phone2,Rate2},MaxTalkingTime) end).

stop(Session) ->
    Session ! stop.
    
get_status(Session, Receiver) ->
    Session ! {get_status, Receiver}.

notify(Session,Event) ->
    Session ! Event.

init(call_back, Msg) ->
    loop(init_callback(Msg)).
    
init(UUID,{Phone1,Rate1},{Phone2,Rate2},MaxTalkingTime) ->
    {Caller,Callee} = start_uas(Phone1,Phone2,UUID),
    sipua:invite(Caller),
    loop(#state{uuid=UUID,caller_pid=Caller,caller_phone=Phone1,caller_rate=Rate1,caller_status=idle,
                          callee_pid=Callee,callee_phone=Phone2,callee_rate=Rate2,callee_status=idle,
                          max_talking_time=MaxTalkingTime}).
init_callback({UUID, Params}) when is_list(Params)->
    Msg0 = {UUID,proplists:get_value(groupid,Params),proplists:get_value(caller,Params),
                      proplists:get_value(callee,Params),proplists:get_value(max_time,Params)},
    St=init_callback(Msg0),
    St#state{options=Params};
init_callback({UUID, GroupId, {Name1, Phone1, Rate1}, {Name2, Phone2, Rate2}, MaxTalkingTime})->
    {Caller,Callee} = start_uas(Phone1,Phone2,UUID),
    sipua:invite(Caller),
    #state{uuid=UUID,group_id=GroupId, 
                        caller_name=Name1, caller_pid=Caller,caller_phone=Phone1,caller_rate=Rate1,caller_status=idle,
                    callee_name=Name2, callee_pid=Callee,callee_phone=Phone2,callee_rate=Rate2,callee_status=idle,
                          max_talking_time=MaxTalkingTime}.
loop(State) ->
    receive
        {status_change,Role,Status,SDP,_} ->
            io:format("Session receive ~p: ~p, SDP:~p~n",[Role,Status,SDP]),
            NewState = handle_status_change(Role,Status,SDP,State),
            loop(NewState);             
        {get_status, Receiver} ->
            Receiver ! {status,{State#state.caller_phone,State#state.caller_status},
            {State#state.callee_phone,State#state.callee_status}},
            loop(State);
        detecting_timer ->
            case can_continue_talking(State) of
            true  -> continue;
            false ->
            sipua:stop(State#state.caller_pid),            
            timer:cancel(State#state.timer_ref)
            end,
            loop(State);
        stop ->
            sipua:stop(State#state.caller_pid),
            loop(State);
        {'DOWN', _Ref, process, Pid, _Reason} ->
            io:format("ua over ~p.~n",[Pid]),
            %%   logger:log(debug, "UserAgent Die, reason: ~p ~n",[Reason]),
            case peer_ua_status(Pid,State) of
            {die,_}     -> 
                io:format("session over.~n"),
                generator_cdr(State),
                session_over;
            {_,PeerPid} -> 
                sipua:stop(PeerPid),
                loop(ua_die(Pid,State))
            end;
        Unexpected ->
            io:format("Session receive unexpected message: ~p~n",[Unexpected]),
            loop(State)
        end.    
    
start_uas(Phone1,Phone2,UUID) ->
    Session = self(),
    CallerCid =  trans_caller_phone(Phone1,Phone2),
    CalleeUUID={element(1,UUID),Phone2},
    {Caller,_} = sipua:start_monitor(Session,caller,caller_addr(CallerCid),callee_addr(trans_callee_phone0(Phone1,CalleeUUID))),   
    CallerUUID={element(1,UUID),Phone1},
    {Callee,_} = sipua:start_monitor(Session,callee,caller_addr(trans_caller_phone(Phone2,Phone1)),callee_addr(trans_callee_phone0(Phone2,CallerUUID))),
    
    {Caller,Callee}.
            
peer_ua_status(Pid,State) ->
    if 
        Pid == State#state.caller_pid -> {State#state.callee_status,State#state.callee_pid};
        Pid == State#state.callee_pid -> {State#state.caller_status,State#state.caller_pid}
    end.

ua_die(Pid,State) ->
    if 
        Pid == State#state.caller_pid -> State#state{caller_status=die};
        Pid == State#state.callee_pid -> State#state{callee_status=die}
    end.

handle_status_change(Role,Status,SDP,State) ->
    case {Role,Status} of
        {caller,ready} ->
            sipua:invite(State#state.callee_pid,SDP),
            State#state{caller_status=ready};        
        {callee,ring} ->
            sipua:invite_in_dialog(State#state.caller_pid,SDP),
            State#state{callee_status=ring};
        {callee,ready} ->
            {ok,TRef} = timer:send_interval(?DETECTING_INTERVAL,detecting_timer),    
            State#state{callee_status=ready,start_time=calendar:local_time(),
                session_valid=true, timer_ref=TRef};
        {caller,Status} ->
            State#state{caller_status=Status};
        {callee,Status} ->
            State#state{callee_status=Status}
    end.

generator_cdr0(State=#state{options=Options}) ->
    if
        State#state.session_valid ->
            StartTime = State#state.start_time,
            EndTime = calendar:local_time(),            
            UUID = State#state.uuid,
            CallerInfo = {State#state.caller_name,State#state.caller_phone,State#state.caller_rate},
            CalleeInfo = {State#state.callee_name,State#state.callee_phone,State#state.callee_rate},
            TimeInfo   = {StartTime,EndTime,time_diff(StartTime,EndTime)},
            cdrserver:new_cdr(callback, {UUID,State#state.group_id, {CallerInfo,CalleeInfo},TimeInfo,Options}),
            case UUID of
            {"ZTE",EID} -> 
                CallerInfo1 = {State#state.caller_phone,State#state.caller_rate},
                CalleeInfo1 = {State#state.callee_phone,State#state.callee_rate},
                rpc:call('company@10.32.3.38',zteapi,new_cdr,[{1, EID},CallerInfo1,CalleeInfo1,TimeInfo]);
            _         -> pass
            end;
        true -> 
            no_cdr_needed
    end.        

generator_cdr(St) ->
	case St#state.uuid of
	{"fzd",_}-> generate_cdr4shuobar(St);
	{_,_}-> generator_cdr0(St)
	end.

generate_cdr4shuobar(State)->
    if
        State#state.start_time =/= undefined ->
            upload_cdr(cdr_url_paras(State)),
            ok;
        true -> 
            no_cdr_needed
    end.

cdr_url_paras(State)->
    Start = voip_ua:seconds(State#state.start_time),
    End=voip_ua:seconds(calendar:local_time()),
    {_,UUID} = State#state.uuid,
    UUID_STR =
        case string:tokens(UUID,"@") of
        [O]->O;
        [O1,O2]->O1
        end,
    %            Phone = State#state.phone,
    CdrId=integer_to_list(www_xengine:bill_id(shuobar)),
    Stime=integer_to_list(Start),
    Etime=integer_to_list(End),
    MyIp=sipcfg:myip(),
    Callee = State#state.callee_phone,
    Key="lwfzdcdr",
    Type = "back",
    Sign=hex:to(erlang:md5([CdrId,UUID_STR,Stime,Etime,MyIp,Key,Type])),
    Paras=[{"cdrid", CdrId},{"uuid",UUID_STR},{"stime",Stime},{"etime",Etime},{"ip",MyIp},{"sign",Sign},{"type",Type},{"callphone",Callee}],
    ParaStrs=[K++"="++V||{K,V}<-Paras],
    string:join(ParaStrs,"&").
upload_cdr(Body) ->  upload_cdr(Body, "http://openapi.shuobar.cn/cdr/wcgreport.html").
upload_cdr(Body,URL) ->
    inets:start(),
    Result = httpc:request(get, {URL++"?"++Body,[]},[{timeout,10 * 1000}],[]),
%%    utility:log("cdr req:~p~n",[Body]),

    case Result of
        {ok, {_,_,_Ack}} -> 
        ok;
        _ -> failed
    end.
    
can_continue_talking(State) ->
    Now = calendar:local_time(),
    ElapseTime = time_diff(State#state.start_time, Now),
%    (ElapseTime + ?DETECTING_INTERVAL/1000) < State#state.max_talking_time.    
    true.
    
time_diff(T1,T2) ->
    calendar:datetime_to_gregorian_seconds(T2)-calendar:datetime_to_gregorian_seconds(T1).
    
ssip(Callee) ->  sipcfg:ssip(Callee).
myip() -> siphost:myip().    

trans_caller_phone(Callee, "+"++Caller)->trans_caller_phone(Callee, "00"++Caller);
trans_caller_phone("+"++Callee, Caller)->trans_caller_phone("00"++Callee, Caller);
trans_caller_phone(Callee, Caller)->  trans_caller_phone(Callee,Caller,sipcfg:service_id()).
trans_caller_phone(Callee,Caller,_)->  trans_caller_phone1(Callee, Caller).

% new for wangfu  charge all callers are 86+xxxxxx
trans_caller_phone1(_Callee, "+"++Caller)->trans_caller_phone1(_Callee, "00"++Caller);
trans_caller_phone1(_Callee, "00"++Caller)->filter_phone(Caller);
trans_caller_phone1(_Callee, "0"++Caller)->filter_phone("860"++Caller);
trans_caller_phone1(_Callee, Caller="86"++_)->filter_phone(Caller);
trans_caller_phone1(_Callee, Caller)->filter_phone("86"++Caller).


trans_callee_phone0(Phone,UUID)->  
    case sipcfg:service_id() of
    "fzd"-> Phone;
    _-> trans_callee_phone(Phone,UUID)
    end.
    
trans_callee_phone(Phone,{"fzd",_}=_UUID)-> Phone;
trans_callee_phone(Phone="*0086"++_,_)->  Phone;
trans_callee_phone("*"++Phone,_)->  "*000001"++filter_phone(Phone);
trans_callee_phone(Phone,{"livecom",_}=UUID) when length(Phone) =<4 ->  % livecom subphone
    trans_callee_phone("*"++Phone,UUID);
trans_callee_phone("+"++Phone,UUID)->  trans_callee_phone("00"++Phone,UUID);
trans_callee_phone(Phone="00"++_,UUID={_Group_id,_})->  group_callee_prefix(UUID)++filter_phone(Phone);
trans_callee_phone(Phone="2"++_,{"dth",_}=_UUID) when length(Phone) == 5 ->  % sip small phone????????????????
    filter_phone(Phone);
trans_callee_phone(Phone="3"++_,{"dth",_}=_UUID) when length(Phone) == 8 ->  % sip small phone????????????????
    filter_phone(Phone);
trans_callee_phone("0"++Phone,UUID={_Group_id,_})->  group_callee_prefix(UUID)++"0086"++filter_phone(Phone);
trans_callee_phone(Phone,UUID={_Group_id,_})->  group_callee_prefix(UUID)++"0086"++filter_phone(Phone);
trans_callee_phone(Phone,_)-> filter_phone(Phone).

callee_prefix()-> sipcfg:callee_prefix().
group_callee_prefix(Group_id)-> sipcfg:group_callee_prefix(Group_id).
national_call_trans_caller("008610"++Caller)->  filter_phone("010"++Caller);
national_call_trans_caller("00861"++LeftCaller)->  filter_phone("1"++LeftCaller);
national_call_trans_caller("0086"++Caller)->  filter_phone("0"++Caller);
national_call_trans_caller(Caller)->  filter_phone(Caller).
    

filter_phone(Phone)->  [I||I<-Phone, lists:member(I, "0123456789*#")].

caller_addr(Phone) ->  caller_addr(none,Phone).
callee_addr(Phone) ->callee_addr(none,Phone).

caller_addr(none,Phone) -> 
    [Addr] = contact:parse(["<sip:"++Phone++"@"++myip()++">"]),
    Addr;
caller_addr(Name,Phone) -> 
    [Addr] = contact:parse(["\""++Name++"\""++"<sip:"++Phone++"@"++myip()++">"]),
    Addr.
    
callee_addr(none,Phone) ->
    [Addr] = contact:parse(["<sip:"++Phone++"@"++ssip(Phone)++">"]),
    Addr;
callee_addr(Name,Phone) ->
    [Addr] = contact:parse(["\""++Name++"\""++"<sip:"++Phone++"@"++ssip(Phone)++">"]),
    Addr.

callee_phone_prefix("008610"++_, "0086"++_) -> "11";
callee_phone_prefix("00861"++_ , "0086"++_) -> "10";
callee_phone_prefix("0086"++_  , "0086"++_) -> "11";
callee_phone_prefix(_Caller, _Callee)       -> "".

meeting_phone_prefix(_, "0086"++_) -> "12";
meeting_phone_prefix(_Caller, _Callee) -> "".
%meeting_phone_prefix(_Caller, "*"++_) -> "";
%meeting_phone_prefix(_Caller, _Callee) -> "00099918".

