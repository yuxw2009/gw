-module(sip_tp).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").

-record(state,{peerpid,
               timer_ref,   %% for invite timeout
               role,    %% caller | callee
               from,
               to,
               dialog = null,
               sdp,
               transaction_pid,
               invite_cseq = 0,
               invite_request,
               ack_request,
               start_time,
               uuid,
               audit_info,
               phone,
               sip_phone,
               contact,
               cid,
               sip_cid,
               max_talkT,
               alertT,
               options,
               max_time}).


%% external API
invite(UA) -> invite(UA,null_rtp()).
invite(UA,SDP) -> UA ! {invite,SDP}.
invite_in_dialog(UA,SDP) -> UA ! {invite_in_dialog,SDP}.
stop(UA) -> UA ! stop.

	
start_with_sdp(Peer,Options,SDP)->
    spawn(fun() -> init(Peer,Options,SDP) end).

init(Peer,Options,SDP) ->
    invite(self(), SDP),
    init(Peer, Options).	
	
start(Owner,_From_not_used, Options) ->
    spawn(fun()-> init(Owner,Options) end).

init(Peer,Options) ->
    Phone = proplists:get_value(phone, Options),
    UUID = proplists:get_value(uuid, Options),
    Audit_info = proplists:get_value(audit_info, Options),
    Maxtime = proplists:get_value(max_time, Options),
    Cid0 = proplists:get_value(cid, Options),
%    io:format("voip_ua:options:~p~n",[Options]),
    init(Peer,caller,Cid0,Phone,UUID, Audit_info, Maxtime,Options).
    
init(Peer,Role,Cid0,Phone0,UUID, Audit_info, Maxtime, Options) ->
    Cid = session:trans_caller_phone(Phone0,Cid0),
    From=session:caller_addr(Cid ),
    Phone = session:trans_callee_phone0(Phone0,UUID),
    process_flag(trap_exit,true),
    To=session:callee_addr(Phone),
    if
        is_integer(Maxtime)-> void;
        true->
            uid_manager:start_call(Cid, [{sip_pid, self()}, {peerpid,Peer}])
    end,
    _Ref = erlang:monitor(process,Peer),
    loop(idle, #state{peerpid=Peer,role=Role,from=From,to=To, uuid=UUID, audit_info=Audit_info,phone=Phone0,sip_phone=Phone,max_time=Maxtime, cid=Cid0,
                             sip_cid=Cid,options=Options}).

%% StateName: idle | trying | |ring | ready | cancel    
loop(StateName,State=#state{cid=_CID}) ->
    receive
        Message -> 
%%            utility:log("voip_ua: ~p received Message:~n~p~n",[self(),Message]),
            case (catch on_message(Message,StateName,State)) of
               {'EXIT',_R}-> 
%%	            utility:log("voip_ua: ~p 'EXIT'~nreason:~p~n",[self(),R]),
		      terminate(State),
                   exit(sip_signal_exit);
                {NewStateName,NewState} -> 
                    loop(NewStateName,NewState);
                stop -> 
%%    	              utility:log("voip_ua: ~p stop~n",[self()]),
                    terminate(State),
                    stop
             end
        end.

terminate(St=#state{max_talkT=MaxTalkT,timer_ref=InviteT,alertT=AlertT})->
	timer:cancel(MaxTalkT),
	timer:cancel(InviteT),
	timer:cancel(AlertT),
	case St#state.uuid of
	{"qvoice",_}-> void;
	{GroupId,_} when GroupId==fzd orelse GroupId=="fzd" -> generate_cdr4shuobar(St);
	{_,_}-> generate_cdr(St);
    _-> void
	end,
	traffic(St),
	stop.

on_message({'DOWN', _Ref, process, Owner, _Reason},Status,State=#state{peerpid=Owner})->
    stop(self()),
    {Status,State};
    
on_message(stop,ready,State) ->
    send_bye(State),
    stop;

on_message(stop,StateName,State) when StateName==trying;StateName==ring->
    TID = State#state.transaction_pid,
    gen_server:cast(TID,{cancel, "hangup", []}),
    stop;   
    
on_message(stop,_,_State) ->
    stop;

on_message({invite, Body},idle,State) ->
    {ok, Request} = build_invite(State#state.from, State#state.to, Body),
    status_change(trying,State),
    {ok,TRef} =  timer:send_after(6000*10,trying_detecting_timeout),
    State2 = State#state{timer_ref=TRef},
    {trying,do_send_invite(Request,State2)};

on_message({invite_in_dialog, SDP},ready,State) ->
    {ok, Invite, NewDialog,_}=
        sipdialog:generate_new_request("INVITE", 
                                       [{"Content-Type", ["application/sdp"]}], 
                                       SDP, State#state.dialog),
    
    {ok, Pid, _Branch} = siphelper:send_request(Invite),
    {ready,State#state{invite_request=Invite,dialog=NewDialog,transaction_pid=Pid,sdp=SDP}};    
    
on_message(max_talk_timeout,ready,State=#state{from=From,to=To}) ->
    io:format("voip max_talk_timeout,from:~p to:~p~n", [From, To]),
    send_bye(State),
    stop;
on_message(alert_timeout,Status,State=#state{peerpid=Owner}) ->
%    io:format("alert_timeout sent to~p~n",[Owner]),
    Owner !{alert,self()},
    {Status,State};
on_message(trying_detecting_timeout,trying,_State) ->
    stop;

on_message({new_response, #response{status=200}=Response, _YxaCtx}, StateName,State) ->
    case siphelper:cseq(Response#response.header) of
        {CSeqNo, "INVITE"} 
            when CSeqNo == State#state.invite_cseq, State#state.ack_request /= undefined ->
        %% Resend ACK
            {ok, _SendingSocket, _Dst, _TLBranch} = 
                siphelper:send_ack(State#state.ack_request, []);
        _ ->
            pass
    end,
    {StateName, State};
    
on_message({new_request, FromPid, Ref, NewRequest, _YxaCtx},StateName,State) ->
    THandler = transactionlayer:get_handler_for_request(NewRequest),
    FromPid ! {ok, self(), Ref},

    {ok, NewDialog} = sipdialog:update_dialog_recv_request(NewRequest, State#state.dialog),
    case NewRequest#request.method of
        "BYE" ->                        
            transactionlayer:send_response_handler(THandler, 200, "Ok"),
            stop;
        "OPTIONS" ->                        
            transactionlayer:send_response_handler(THandler, 200, "Ok"),
            {StateName,State#state{dialog=NewDialog}};
        _ ->
            transactionlayer:send_response_handler(THandler, 501, "Not Implemented"),
            {StateName,State#state{dialog=NewDialog}}
    end;
    
on_message({dialog_expired, {CallId, LocalTag, RemoteTag}}, StateName, State) ->
    sipdialog:set_dialog_expires(CallId, LocalTag, RemoteTag, 30),
    {StateName, State};

on_message({clienttransaction_terminating, _, _}, StateName, State) ->
   {StateName, State};
    
on_message({'EXIT', _, normal}, StateName,State) ->
   {StateName, State};

on_message(Branch={branch_result,_,_,_,#response{status=SipStatus,body=Body}},Status,State) ->
    State#state.peerpid ! {tp_status,SipStatus,Body},
    on_branch_result(Branch,Status,State);

on_message(Unhandeld,StateName,State=#state{role=Role}) ->
    %%io:format("UserAgent ~p receive unhandled message: ~p STATE: ~p~n",[Role,Unhandeld,StateName]),
    logger:log(debug, "UserAgent ~p receive unhandled message: ~p STATE: ~p~n",[Role,Unhandeld,StateName]),
    {StateName,State}. 

%% {branch_result,Pid,Branch,BranchState,#response{}}
on_branch_result({branch_result,_,_,_,#response{status=183,body= <<>>}=_Response},trying,State) ->
        notify_status(State, prering),
    {trying,State};

on_branch_result({branch_result,_,_,_,#response{status=180,body= <<>>}=_Response},trying,State) ->
        notify_status(State, prering),
    {trying,State};

on_branch_result({branch_result,_,_,_,#response{status=180,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
    NewState = State#state{dialog=Dialog,sdp=SDP},
    status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
    {ring,NewState};

on_branch_result({branch_result,_,_,_,#response{status=183,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
    NewState = State#state{dialog=Dialog,sdp=SDP},
    status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
    {ring,NewState};
    
on_branch_result({branch_result,_,_,_,#response{status=180,body=SDP}=_Response},ring,State) ->
    NewState = State#state{sdp=SDP},
    {ring,NewState};

on_branch_result({branch_result,_,_,_,#response{status=183,body=SDP}=_Response},ring,State) ->
    NewState = State#state{sdp=SDP},
    {ring,NewState};
	

on_branch_result({branch_result,_,_,_,#response{status=200,body=SDP}=Response},trying,State0=#state{}) ->
    State =maxtalk_judge(State0),
	timer:cancel(State#state.timer_ref),
    Dialog = create_dialog(State#state.invite_request, Response),
    
    NewState = send_ack(State#state{dialog=Dialog}),
    NewState0 = case SDP of
                <<>> -> NewState;
                _->  NewState#state{sdp=SDP}
            end,
    notify_status(NewState0, ring),
    NewState1=status_change(ready,NewState0),
    {ready,NewState1};	


on_branch_result({branch_result,_,_,_,#response{status=200,body=SDP}},ring,State0=#state{}) ->
    State =maxtalk_judge(State0),
    NewState = send_ack(State),
    NewState0 = case SDP of
                <<>> -> NewState;
                _->  NewState#state{sdp=SDP}
            end,
    NewState1=status_change(ready,NewState0),
    {ready,NewState1};

on_branch_result({branch_result,_,_,_,#response{status=200}},ready,State) ->
    NewState = send_ack(State),
    {ready,NewState};

on_branch_result({branch_result,_,_,_,#response{status=Status}},_,State) when Status >= 400, Status =< 699->
    send_ack(State),
    notify_status(State, busy),
    stop;

on_branch_result({branch_result, _, _, _, {408, _Reason}}, trying, _State) ->
    stop;

on_branch_result({branch_result, _, _, _, {408, _Reason}}, ring, _State) ->
    stop;

on_branch_result({branch_result, _, _, _, {500, _Reason}}, trying, _State) ->
    stop;

on_branch_result({branch_result, _, _, _, {500, _Reason}}, ring, _State) ->
    stop;

on_branch_result({branch_result, _, _, _, {503, _Reason}}, trying, State) ->
     notify_status(State, status_503),
    stop;

on_branch_result({branch_result, _, _, _, {503, _Reason}}, ring, State) ->
     notify_status(State, status_503),
    stop;
on_branch_result(Br, Status, State) ->
    io:format("unhandled branch_result:~p status:~p~n",[Br,Status]),
    {Status,State}.

%% internal function    

notify_status(State, Status) ->
    State#state.peerpid ! {callee_status, Status}.

status_change(Status,State) -> 
    Role = State#state.role,
    SDP = State#state.sdp,
    case {Role,Status} of
        {caller,ring} ->
            notify_status(State, ring),
            State#state.peerpid ! {callee_sdp, SDP},
            State;      
        {caller,ready} ->
            notify_status(State, hook_off),
            State#state.peerpid ! {callee_sdp, SDP},
            State#state{start_time=calendar:local_time()};      
        _ ->
            State
    end.

create_dialog(Request, Response) when is_record(Request, request),
                      is_record(Response, response) ->
    {ok, Dialog} = sipdialog:create_dialog_state_uac(Request, Response),
    ok = sipdialog:register_dialog_controller(Dialog, self(), 60*60*2),
    Dialog.
    
send_ack(State) ->
    Dialog = State#state.dialog,
    if
        Dialog =/= null ->
            CSeq = integer_to_list(State#state.dialog#dialog.local_cseq),
            {ok, Ack, _Dialog, _Dst} = 
            sipdialog:generate_new_request("ACK", [{"CSeq", [CSeq++ " ACK"]}], <<>>, State#state.dialog),
            siphelper:send_ack(Ack, []),
        State#state{ack_request = Ack};
       true ->
            State
    end.

send_bye(State) ->
    Dialog = State#state.dialog,
    if 
        Dialog =/= null ->
            {ok, Bye, _Dialog, _Dst} = 
                sipdialog:generate_new_request("BYE", [], <<>>, Dialog),
                siphelper:send_request(Bye);
        true ->
            pass
    end.
    
register_ip()-> "197.158.11.242".
register_self_ip()-> "58.221.60.121".
register_from(User)-> [From]=contact:parse([User++" <sip:"++User++"@"++register_self_ip()++">"]), From.
register_to(Phone)-> [To]=contact:parse([Phone++" <sip:"++Phone++"@"++register_ip()++">"]), To.

build_register(User,Passwd)  ->
    {ok, Request, _CallId, _FromTag, _CSeqNo} =
	siphelper:start_generate_request_1("REGISTER",register_from(User),register_to(User),[{"Expires", ["7200"]}], <<>>, [{user,User},{pass,Passwd}]),
    {ok, Request}.
build_invite(From, To, Body) when is_record(From, contact),is_record(To, contact),is_binary(Body) ->
    {ok, Request, _CallId, _FromTag, _CSeqNo} =
    siphelper:start_generate_request("INVITE",From,To,
                                     [{"Content-Type", ["application/sdp"]}],
                                     Body),
    {ok, Request}.
    
do_send_invite(Request,State) ->
    [Contact] = keylist:fetch('contact', Request#request.header),
    Header = Request#request.header,
    CSeq = State#state.invite_cseq + 1,
    NewHeader = keylist:set("CSeq", [lists:concat([CSeq, " ", Request#request.method])], Header),
%    NewHeader = keylist:set("Max-Forwards", ["70"], NewHeader0),
    NewRequest = Request#request{header=NewHeader},
    {ok, Pid, _Branch} = siphelper:send_request(NewRequest),
    State#state{invite_cseq=CSeq,transaction_pid=Pid,invite_request=NewRequest,contact=Contact}.

null_rtp() ->
    <<"v=0\r\no=LTALK 100 1000 IN IP4 10.32.3.41\r\ns=phone-call\r\nc=IN IP4 0.0.0.0\r\nt=0 0\r\nm=audio 10792 RTP/AVP 18 4 8 0 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20\r\n">>.

generate_cdr(State)->
    if
        State#state.start_time =/= undefined ->
            StartTime = State#state.start_time,
            EndTime = calendar:local_time(),
            TimeInfo   = {StartTime,EndTime,session:time_diff(StartTime,EndTime)},
            UUID = State#state.uuid,
            Audit_info = State#state.audit_info,
            Phone = State#state.phone,
            Options=State#state.options,
            cdrserver:new_cdr(voip, {UUID,Audit_info, Phone,TimeInfo,Options});
        true -> 
            no_cdr_needed
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
    Start = seconds(State#state.start_time),
    End=seconds(calendar:local_time()),
    {_,UUID_STR} = State#state.uuid,
    %            Phone = State#state.phone,
    CdrId=integer_to_list(www_xengine:bill_id(shuobar)),
    Stime=integer_to_list(Start),
    Etime=integer_to_list(End),
    Callee = State#state.phone,
    MyIp=sipcfg:myip(),
    Key="lwfzdcdr",
    Type = "direct",
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

seconds(Localtime)->    
    UnixEpoch={{1970,1,1},{0,0,0}},
    calendar:datetime_to_gregorian_seconds(Localtime)-calendar:datetime_to_gregorian_seconds(UnixEpoch).

maxtalk_judge(State0=#state{max_time=Maxtime})->
%            io:format("maxtalk_judge Maxtime:~p~n",[Maxtime]),
    if
        is_integer(Maxtime) -> 
            AlertTime = if Maxtime > 60*1000 -> Maxtime-60*1000; true-> 1 end,
%            io:format("alerttime setted:~p~n",[AlertTime]),
            {ok,AlertT}=timer:send_after(AlertTime, alert_timeout),
            {ok,TalkT}=timer:send_after(Maxtime, max_talk_timeout),
            State0#state{max_talkT=TalkT,alertT=AlertT};
        true-> State0
    end.

traffic(_St=#state{uuid=UUID,cid=Cid,sip_cid=SipCid,sip_phone=SipPhone,phone=Phone,start_time=Starttime})->
    Trf=[{caller,Cid},{uuid,UUID},{callee,Phone},{talktime,Starttime},{endtime,calendar:local_time()},{caller_sip,sipcfg:myip()},
      {callee_sip,sipcfg:ssip()},{socket_ip,sipcfg:get(sip_socket_ip)},{sip_caller,SipCid},{sip_callee,SipPhone}],
    rpc:call('traffic@lwork.hk',traffic,add,[Trf]).
    
    
%%%%%%%%%%%%%%%%%%%%%%%%  for test
start_alarmpro()->
    register(alarmpro, spawn(fun detect_alarm/0)).
detect_alarm()->detect_alarm(0).
detect_alarm(N)->
    case {net_adm:ping('qtest1@14.17.107.196'),net_adm:ping('qtest@14.17.107.196'),net_adm:ping('www@14.17.107.196')} of
    {pong,pong,pong}->
        io:format(" ~p ",[N]),
        timer:sleep(60000),
        detect_alarm(0);
    _-> 
        io:format(" ~p ",[N]),
        if N>2-> alarm();         true-> void        end,
        timer:sleep(60000),
        detect_alarm(N+1)
    end.
alarm()->
    [fake_call(P)||P<-alarm_phone()].
fake_call(Phone)->
    Info=make_info("008618038668866",Phone,"888888888",""),
    Pid=start(self(),a, Info),
    invite(Pid).
make_info(Cid,PhNo,QQNo,Clidata) ->
    [{phone,PhNo},{qcall,true},
     {uuid,{qvoice,86}},
     {audit_info,[{uuid,Cid}]},{userclass, "fzd"},
     {cid,Cid},{qno,QQNo},{clidata,Clidata}].
alarm_phone()-> ["008618017813673"].%["008618017813673","008618151927225"].
