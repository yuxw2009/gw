-module(meeting).
-compile(export_all).

-include("debug.hrl").
-include("call.hrl").
-record(state,{
                           key,
                           audit_info,
                           subject,
                           conf_name,
                           session_id,
                           conf_pid,
			   ua_list,
			   max_meeting_time,
			   has_been_ready = false,  %% judge if some ua has been ready before, true or false
			   charge_list=[]
			   }). 
			   
-behaviour(gen_server).
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).
-define(SUBCOMMA, "pP*").

-define(DETECTING_INTERVAL, 5000).

start_monitor(Info) ->
    {ok, MeetingPid} = gen_server:start(?MODULE, Info, []),
    {MeetingPid, monitor(process, MeetingPid)}.


join_conf(SessionPid, Phones)->
    SessionPid ! {join_conf, Phones}.
    
unjoin_conf(SessionPid, Phones)->
    SessionPid ! {unjoin_conf, Phones}.
    
stop(Session) ->
    Session ! stop.

get_status(Session, Receiver) ->
    Session ! {get_status, Receiver}.

notify(Session,Event) ->
    Session ! {Event,self()}.

init({new_meeting, From, Plist})->
    Key = proplists:get_value(key, Plist),
    AuditInfo = proplists:get_value(audit_info, Plist),
    Members0=[{_Name, Phone1}|_] = proplists:get_value(members, Plist),
    Session_id = proplists:get_value(session_id, Plist),
    Subject="",
    Phones = [{N,P,0.1}||{N,P}<-Members0],
    MaxMeetingTime = 6000,

    Confname = conf_name(Phone1),
    {ok, ConfPid} = conf:create([Confname,self()]),
    monitor(process, ConfPid),
    Uas = [Caller| _] = start_uas(lists:map(fun({_, Phone, _})-> Phone end, Phones)),
    sipua:invite(Caller),
    Members = lists:zipwith(fun(Seq, Phone)-> {Seq, connecting, Phone} end, lists:seq(1, length(Phones)), Phones),
    From ! {value,{{meeting_id, Session_id}, {members, Members}}},
    {ok, #state{key=Key, audit_info=AuditInfo, conf_name=Confname,conf_pid=ConfPid, session_id=Session_id,
        max_meeting_time=MaxMeetingTime,  subject=Subject,
        ua_list=lists:zipwith(fun(Ua, {Name, Phone, Rate})-> {Ua,#meeting_item{name=Name, phone=Phone,rate=Rate}, idle} end, Uas, Phones)}}.
    
handle_cast(_Msg, State)->
    {noreply, State}.

handle_call(_Msg, _From, State)->
    {reply, ok, State}.

code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(Reason, State=#state{ua_list=Uas, conf_name=Confname, session_id=Session_id,charge_list=ChargeList})->
    AddedChargeList = [Item#meeting_item{end_time=calendar:local_time()}||{_,Item, ready}<-Uas],
    [sipua:stop(Ua)||{Ua,_, _}<-Uas],
    conf:destroy(Confname),
    meeting_db:end_meeting(Session_id), 
    generate_cdr(State#state{charge_list=ChargeList++AddedChargeList}),
    Reason.

handle_info({status_change,_Role,Status,SDP, From},State=#state{}) ->
    {noreply, handle_status_change(Status,SDP,From,State)}; 			

handle_info({get_status, Receiver},State=#state{ua_list=UAS}) ->
    Result = lists:zipwith(fun(I, {_, #meeting_item{phone=Phone}, Status})-> {I, Status, Phone} end, lists:seq(1, length(UAS)), UAS),
    Receiver ! {value, Result},
    {noreply, State}; 			

handle_info({get_ua_status_by_phone, {Receiver, []}}, State=#state{ua_list=Ua_list})->
     Items = [{P, Ua, erlang:is_process_alive(Ua), Status} || {Ua, #meeting_item{phone=P}, Status}<-Ua_list],
     print_meeting_status(Items),
     Receiver ! Items,
    {noreply, State};

handle_info({get_ua_status_by_phone, {Receiver, Phone}}, State=#state{ua_list=Ua_list})->
    Items = [{Ua, erlang:is_process_alive(Ua), Status} || {Ua, #meeting_item{phone=P}, Status}<-Ua_list, P=:=Phone],
     print_meeting_status(Items),
     Receiver ! Items,
    {noreply, State};

handle_info({get_active_meeting, Receiver},State=#state{ua_list=UAS, session_id=Session_id}) ->
    ActiveMembers=[{Status, MeetingItem} || {_, MeetingItem, Status}<-UAS],
    Receiver ! {value, {Session_id, ActiveMembers}},
    {noreply, State}; 			

handle_info({join_conf, NamePhones},State=#state{ua_list=Ua_list=[{_,#meeting_item{phone=CallerPhone},_}|_], has_been_ready=Been_ready}) ->
    F = fun({N,P})->
            [Ua] = start_callee_uas(CallerPhone, [P]),
            {Ua,#meeting_item{phone=P,name=N}, idle};
        ({N,P,Rate})->
            [Ua] = start_callee_uas(CallerPhone, [P]),
            {Ua,#meeting_item{phone=P,name=N,rate=Rate}, idle}
    end,
    NewUa_list = [F(I)||I<-NamePhones],
%
%    Phones=[P || {_N, P}<-NamePhones],
%    NewUas = start_callee_uas(CallerPhone, Phones),
%    NewUa_list=lists:zipwith(fun(Ua, {N,P})-> {Ua,#meeting_item{phone=P,name=N}, idle} end, NewUas, NamePhones),
%    
    case Been_ready of
        true-> [sipua:invite(Pid,sipua:null_rtp()) || {Pid,_,_} <- NewUa_list];
        _-> void
    end,
    {noreply, State#state{ua_list=Ua_list++NewUa_list}}; 			

handle_info({unjoin_conf, Phones},State=#state{ua_list=Ua_list}) ->
    Unjoin_list = [Item || Item={_, #meeting_item{phone=P},_}<-Ua_list, {_Name, Phone}<-Phones, P==Phone],
    [sipua:stop(Ua) || {Ua,_,_} <- Unjoin_list],
    {noreply, State}; 			

handle_info(stop,State=#state{ua_list=UaList}) ->
    [sipua:stop(Ua) || {Ua,_,_}<-UaList],
    {noreply, State};

handle_info({'DOWN', _Ref, process, ConfPid, _Reason},State=#state{conf_pid=ConfPid}) ->
    {stop, normal, State}; 			

handle_info({'DOWN', _Ref, process, Pid, _Reason},State=#state{ua_list=[{Pid,_CallerPhone,_} | _], has_been_ready=false}) ->
%    io:format("meeting: caller ~p not ready when it's over.~n",[CallerPhone]),
    {stop, normal, State#state{ua_list=[]}}; 			

handle_info({'DOWN', _Ref, process, Pid, _Reason},State=#state{ua_list=Uas,charge_list=ChargeList}) ->
    NewChargeList= case lists:keysearch(Pid, 1, Uas) of
                                {value, {Pid, Item, ready}}-> 
                                    NewItem = Item#meeting_item{end_time=calendar:local_time()},
                                    ChargeList++[NewItem];
                                _-> ChargeList
                            end,
    NewState = State#state{charge_list=NewChargeList},        
    case lists:keydelete(Pid, 1 , Uas) of
        []->
            {stop, normal, NewState#state{ua_list=[]}};
        UA_List-> {noreply, NewState#state{ua_list=UA_List}}
    end;

handle_info(Unexpected,State=#state{}) ->
    io:format("meeting receive unexpected message: ~p~n",[Unexpected]),
    {noreply, State}.

start_uas([Header | Tail]) ->
    Session = self(),

     Prefix = session:meeting_phone_prefix("00857556510021", main_part(Header)),

    {Caller,_} = sipua:start_monitor(Session,caller,
                                     session:caller_addr("00857556510021"),
                                     session:callee_addr(Prefix ++ main_part(Header))),

    [Caller | start_callee_uas(main_part(Header), Tail)].


start_callee_uas(CallerPhone,  CalleePhones) ->
    Session = self(),
    
    Pre = fun(CallerP,CaleeP) ->
               session:meeting_phone_prefix(CallerP, CaleeP)
          end,
 
    Result = [sipua:start_monitor(Session,callee,
                                  session:caller_addr(main_part(CallerPhone)),
                                  session:callee_addr(Pre(CallerPhone, Phone) ++ main_part(Phone))) || Phone<-CalleePhones ],
    [ Call || {Call, _}<-Result].

main_part(Phone)->
    [Main|_] = string:tokens(Phone, ?SUBCOMMA),
    Main.
    
handle_status_change(Status,SDP,From,State=#state{ua_list=UaList}) ->
    case lists:keyfind(From, 1, UaList) of 
    {From, Item, _OldStatus}->
        case Status of
            ready-> 
                NewUaList = lists:keyreplace(From, 1, UaList, {From, Item#meeting_item{start_time=calendar:local_time()}, Status}),
                handle_ready(SDP, From, State#state{ua_list=NewUaList}, Item);
            _-> 
                NewUaList = lists:keyreplace(From, 1, UaList, {From, Item, Status}),
                State#state{ua_list=NewUaList}
        end;
    _->
        ?PRINT_INFO("impossible"),
        State
    end.

judge_need_play_joinconf_tone(#state{ua_list=UaList}, MsUa)->
    if 
        length(UaList) > 2 ->
            ms_ua:play_tone(MsUa, "file://provisioned/2.wav");
        true->
            notPlayToneIfLessThan2
    end.
    

handle_ready(SDP, From, State=#state{conf_name=Confname}, #meeting_item{phone=Phone})->
    UserInfo = [Phone, SDP, [fun(S)-> sipua:invite_in_dialog(From, S) end], From],
    MsUa = ms_ua:start(UserInfo),                                          
    case string:tokens(Phone, ?SUBCOMMA) of
        [_Main, Sub]-> ms_ua:send_dtmf(MsUa, Sub);
        _-> void
    end,
    judge_need_play_joinconf_tone(State, MsUa),
    conf:join_conf(Confname, MsUa),
    handle_ready1(SDP, From, State).
    
handle_ready1(SDP, Caller, State=#state{ua_list=[{Caller,_,_} | Callees], has_been_ready=false, max_meeting_time=MaxMeetingTime})->
    [sipua:invite(Pid,SDP) || {Pid,_,_} <- Callees],
    case MaxMeetingTime of
        infinity-> void;
        _-> to_do
    end,
    State#state{has_been_ready=true};
handle_ready1(_, _,State)->
    State.
    

conf_name()->
    {_, _, Ms} = now(),
    conf_name(integer_to_list(Ms)).
conf_name(Suffix)->
    string:join(string:tokens(siphost:myip(), ".")++string:tokens(lists:flatten(io_lib:format("~p", [calendar:local_time()])), "{},")++[Suffix], "a").

is_all_down(Uas)->
    [I || I={_Ua, _, Status}<-Uas, Status=/=idle] ==[].

generate_cdr(#state{key=Key, charge_list=ChargeList, audit_info=Audit_info, subject=Subject})->
    F=fun(Item=#meeting_item{start_time=StartTime, end_time=EndTime,rate=Rate})->
              Duration = session:time_diff(StartTime, EndTime),
              Charge=cdrserver:to_minute(Duration)*Rate,
              Item#meeting_item{duration=Duration, charge=Charge}
        end,
    NewItems = [F(I) || I=#meeting_item{start_time=StartTime} <- ChargeList, StartTime =/= undefined],
    if
        NewItems =/= []->
            cdrserver:new_cdr(meeting, {Key,Audit_info,Subject,NewItems});
        true->  no_cdr_needed
    end.
    
test_subphone(Digits)->
    [Main, Sub] = string:tokens(Digits, ?SUBCOMMA),
    {UA,_} = sipua:start_monitor(self(),caller,session:caller_addr("00852755651002"),session:callee_addr(Main)),
    sipua:invite(UA),
    receive
    {status_change,_Role,ready,SDP, From}->
        io:format("phone ~p hookoff from ~p   UA:~p~n", [Main, From, UA]),
        Ms_ua = ms_ua:start_monitor([Digits, SDP, [fun(S)-> sipua:invite_in_dialog(From, S) end], From]),
        io:format("let ms_ua send digits ~p ~n", [Sub]),
        ms_ua:send_dtmf(Ms_ua, Sub)
    after 30000->
        timeout
    end.

print_meeting_status(Items)->
    io:format("~n Phone      SessionPid      is_process_alive      status~n"),
    FormatFun = fun({P, Ua, ProcessStatus, Status})->
                            io:format("~p       ~p       ~p        ~p~n", [P, Ua, ProcessStatus, Status])
                        end,
     [FormatFun(Item) || Item<-Items].

