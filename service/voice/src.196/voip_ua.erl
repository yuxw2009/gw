-module(voip_ua).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").

-record(state,{owner,
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
               contact,
               cid,
               max_talkT,
               max_time}).


%% external API
invite(UA) -> invite(UA,null_rtp()).
invite(UA,SDP) -> UA ! {invite,SDP}.
invite_in_dialog(UA,SDP) -> UA ! {invite_in_dialog,SDP}.
stop(UA) -> UA ! stop.

	
start_with_sdp(Owner,Options,SDP)->
    spawn(fun() -> init(Owner,Options,SDP) end).

init(Owner,Options,SDP) ->
    invite(self(), SDP),
    init(Owner, Options).	
	
start(Owner,_From_not_used, Options) ->
    spawn(fun()-> init(Owner,Options) end).

init(Owner,Options) ->
    Phone = proplists:get_value(phone, Options),
    UUID = proplists:get_value(uuid, Options),
    Audit_info = proplists:get_value(audit_info, Options),
    From = proplists:get_value(cid, Options),
    Maxtime = proplists:get_value(max_time, Options),
    Cid = proplists:get_value(cid, Options),
    init(Owner,caller,session:caller_addr(From),Phone,UUID, Audit_info, Maxtime, Cid).
    
init(Owner,Role,From,Phone,UUID, Audit_info, Maxtime, Cid) ->
    process_flag(trap_exit,true),
    To=session:callee_addr(Phone),
    if
        is_integer(Maxtime)-> void;
        true->
            uid_manager:start_call(Cid, [{sip_pid, self()}, {owner,Owner}])
    end,
    loop(idle, #state{owner=Owner,role=Role,from=From,to=To, uuid=UUID, audit_info=Audit_info,phone=Phone,max_time=Maxtime, cid=Cid}).

%% StateName: idle | trying | |ring | ready | cancel    
loop(StateName,State=#state{cid=CID}) ->
    receive
        Message -> 
            case (catch on_message(Message,StateName,State)) of
               {'EXIT',R}-> 
		      logger:log(debug, "UserAgent ~p exit with sip_signal_exit: ~p~n",[self(),R]),
		      terminate(State),
                   exit(sip_signal_exit);
                {NewStateName,NewState} -> 
                    loop(NewStateName,NewState);
                stop -> 
                    terminate(State),
                    stop
             end
        end.

terminate(#state{max_talkT=MaxTalkT,timer_ref=InviteT})->
	timer:cancel(MaxTalkT),
	timer:cancel(InviteT),
	stop.

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
    
%% {branch_result,Pid,Branch,BranchState,#response{}}
on_message({branch_result,_,_,_,#response{status=183,body= <<>>}=_Response},trying,State) ->
        notify_status(State, trying),
    {trying,State};

on_message({branch_result,_,_,_,#response{status=180,body= <<>>}=_Response},trying,State) ->
        notify_status(State, trying),
    {trying,State};


on_message(max_talk_timeout,ready,State=#state{from=From,to=To}) ->
    io:format("voip max_talk_timeout,from:~p to:~p~n", [From, To]),
    send_bye(State),
    stop;
on_message(trying_detecting_timeout,trying,_State) ->
    stop;

on_message({branch_result,_,_,_,#response{status=180,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
    NewState = State#state{dialog=Dialog,sdp=SDP},
    status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
     notify_status(State, ring),
    {ring,NewState};

on_message({branch_result,_,_,_,#response{status=183,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
    NewState = State#state{dialog=Dialog,sdp=SDP},
    status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
     notify_status(State, ring),
    {ring,NewState};
    
on_message({branch_result,_,_,_,#response{status=180,body=SDP}=_Response},ring,State) ->
    NewState = State#state{sdp=SDP},
    {ring,NewState};

on_message({branch_result,_,_,_,#response{status=183,body=SDP}=_Response},ring,State) ->
    NewState = State#state{sdp=SDP},
    {ring,NewState};
	

on_message({branch_result,_,_,_,#response{status=200,body=SDP}=Response},trying,State0=#state{max_time=Maxtime}) ->
    State =
    if
        is_integer(Maxtime) -> 
            {ok,TalkT}=timer:send_after(Maxtime, max_talk_timeout),
            State0#state{max_talkT=TalkT};
        true-> State0
    end,
	timer:cancel(State#state.timer_ref),
    Dialog = create_dialog(State#state.invite_request, Response),
    
    NewState = send_ack(State#state{dialog=Dialog}),
    NewState0 = case SDP of
                <<>> -> NewState;
                _->  NewState#state{sdp=SDP}
            end,
    NewState1=status_change(ready,NewState0),
    {ready,NewState1};	


on_message({branch_result,_,_,_,#response{status=200,body=SDP}},ring,State0=#state{max_time=Maxtime}) ->
    State =
    if
        is_integer(Maxtime) -> 
            {ok,TalkT}=timer:send_after(Maxtime, max_talk_timeout),
            State0#state{max_talkT=TalkT};
        true-> State0
    end,
    NewState = send_ack(State),
    NewState0 = case SDP of
                <<>> -> NewState;
                _->  NewState#state{sdp=SDP}
            end,
    NewState1=status_change(ready,NewState0),
    {ready,NewState1};

on_message({branch_result,_,_,_,#response{status=200}},ready,State) ->
    NewState = send_ack(State),
    {ready,NewState};

on_message({branch_result,_,_,_,#response{status=Status}},_,State) when Status >= 400, Status =< 699->
    send_ack(State),
    notify_status(State, busy),
    stop;

on_message({branch_result, _, _, _, {408, _Reason}}, trying, _State) ->
    stop;

on_message({branch_result, _, _, _, {408, _Reason}}, ring, _State) ->
    stop;

on_message({branch_result, _, _, _, {500, _Reason}}, trying, _State) ->
    stop;

on_message({branch_result, _, _, _, {500, _Reason}}, ring, _State) ->
    stop;

on_message({branch_result, _, _, _, {503, _Reason}}, trying, State) ->
     notify_status(State, status_503),
    stop;

on_message({branch_result, _, _, _, {503, _Reason}}, ring, State) ->
     notify_status(State, status_503),
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

on_message(Unhandeld,StateName,State=#state{role=Role}) ->
    %%io:format("UserAgent ~p receive unhandled message: ~p STATE: ~p~n",[Role,Unhandeld,StateName]),
    logger:log(debug, "UserAgent ~p receive unhandled message: ~p STATE: ~p~n",[Role,Unhandeld,StateName]),
    {StateName,State}. 


%% internal function    

notify_status(State, Status) ->
    State#state.owner ! {callee_status, Status}.

status_change(Status,State) -> 
    Role = State#state.role,
    SDP = State#state.sdp,
    case {Role,Status} of
        {caller,ready} ->
            State#state.owner ! {callee_sdp, SDP},
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
    NewRequest = Request#request{header=NewHeader},
    {ok, Pid, _Branch} = siphelper:send_request(NewRequest),
    State#state{invite_cseq=CSeq,transaction_pid=Pid,invite_request=NewRequest,contact=Contact}.

null_rtp() ->
    <<"v=0\r\no=LTALK 100 1000 IN IP4 10.32.3.41\r\ns=phone-call\r\nc=IN IP4 0.0.0.0\r\nt=0 0\r\nm=audio 10792 RTP/AVP 18 4 8 0 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20\r\n">>.

generator_cdr(State)->
    if
        State#state.start_time =/= undefined ->
            StartTime = State#state.start_time,
            EndTime = calendar:local_time(),
            TimeInfo   = {StartTime,EndTime,session:time_diff(StartTime,EndTime)},
            UUID = State#state.uuid,
            Audit_info = State#state.audit_info,
            Phone = State#state.phone,
            cdrserver:new_cdr(voip, {UUID,Audit_info, Phone,TimeInfo});
        true -> 
            no_cdr_needed
    end.
