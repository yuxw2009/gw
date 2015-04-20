-module(sipua).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").

-record(state,{owner,
               timer_ref,
               role,    %% caller | callee
               from,
               to,
               dialog = null,
               sdp,
               transaction_pid,
	           invite_cseq = 0,
	           invite_request,
	           ack_request,
               contact}).


%% external API
invite(UA) -> invite(UA,null_rtp()).
invite(UA,SDP) -> UA ! {invite,SDP}.
invite_in_dialog(UA,SDP) -> UA ! {invite_in_dialog,SDP}.
stop(UA) -> UA ! stop.
			   
start_monitor(Owner,Role,From,To) ->
    spawn_monitor(fun()-> init(Owner,Role,From,To) end).
	
init(Owner,Role,From,To) ->
    process_flag(trap_exit,true),
    loop(idle, #state{owner=Owner,role=Role,from=From,to=To}).

%% StateName: idle | trying | |ring | ready | cancel	
loop(StateName,State) ->
    receive
        Message -> 
		    case on_message(Message,StateName,State) of
	            {NewStateName,NewState} -> 
	                loop(NewStateName,NewState);
		        stop -> 
			        stop
			end
    end.
	
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
	{trying,State};

on_message({branch_result,_,_,_,#response{status=180,body= <<>>}=_Response},trying,State) ->
	{trying,State};

on_message(trying_detecting_timeout,trying,_State) ->
    stop;

on_message({branch_result,_,_,_,#response{status=180,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
	NewState = State#state{dialog=Dialog,sdp=SDP},
    status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
	{ring,NewState};

on_message({branch_result,_,_,_,#response{status=183,body=SDP}=Response},trying,State) ->
    Dialog = create_dialog(State#state.invite_request, Response),
	NewState = State#state{dialog=Dialog,sdp=SDP},
       status_change(ring,NewState), 
    timer:cancel(State#state.timer_ref),
	{ring,NewState};
	
on_message({branch_result,_,_,_,#response{status=180}=_Response},ring,State) ->
	{ring,State};

on_message({branch_result,_,_,_,#response{status=183}=_Response},ring,State) ->
	{ring,State};

on_message({branch_result,_,_,_,#response{status=200}},ring,State) ->
    NewState = send_ack(State),
	status_change(ready,NewState),
    {ready,NewState};

on_message({branch_result,_,_,_,#response{status=200}},ready,State) ->
    NewState = send_ack(State),
    {ready,NewState};

on_message({branch_result,_,_,_,#response{status=Status}},_,State) when Status >= 400, Status =< 699->
    send_ack(State),
    stop;

on_message({branch_result, _, _, _, {408, _Reason}}, trying, _State) ->
    stop;

on_message({branch_result, _, _, _, {408, _Reason}}, ring, _State) ->
    stop;

on_message({branch_result, _, _, _, {500, _Reason}}, trying, _State) ->
    stop;

on_message({branch_result, _, _, _, {500, _Reason}}, ring, _State) ->
    stop;

on_message({branch_result, _, _, _, {503, _Reason}}, trying, _State) ->
    stop;

on_message({branch_result, _, _, _, {503, _Reason}}, ring, _State) ->
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
status_change(Status,State) -> 
    State#state.owner ! {status_change,State#state.role,Status,State#state.sdp, self()}.

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
    <<"v=0\r\no=LTALK 100 1000 IN IP4 10.32.3.41\r\ns=phone-call\r\nc=IN IP4 116.228.53.181\r\nt=0 0\r\nm=audio 10792 RTP/AVP 8 0 18 4 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20\r\n">>.

