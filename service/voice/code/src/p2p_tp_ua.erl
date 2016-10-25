-module(p2p_tp_ua).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").

-record(state,{owner,
               tp_ack_timer,
               timer_ref,   %% for invite timeout
               role,    %% caller | callee
               from,
               to,
               dialog = null,
               sdp,
               sdp_to_ss= <<>>,
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
stop(UA) -> UA ! stop.

	
start(Request=#request{method="INVITE"},YxaCtx=#yxa_ctx{thandler = THandler})->
    P=spawn(fun()-> init(Request,YxaCtx) end),
    transactionlayer:change_transaction_parent(THandler,self(),P).
    

init(Request=#request{method="INVITE",body=SDP,header=Header},YxaCtx=#yxa_ctx{thandler = THandler}) ->
    %imform (Caller,Callee, SDP, self()) to www,and wait selfSDP from w2p
    {_,#sipurl{user=Caller}}=sipheader:from(Header),
    #sipurl{user=Callee}=Request#request.uri,
    io:format("p2p_tp_ua:init Caller ~p=>~p ~n",[Caller,Callee]),
    case rpc:call(sipcfg:get(www_node),lw_mobile,sip_p2p_tp_call,[Caller,Callee,SDP,self()]) of
    {failed,_Reason}-> 
        io:format("p2p_tp_ua:init rpc:call failed ~p ~n",[_Reason]),
        transactionlayer:send_response_handler(THandler, 404, "user not found"),
        stop(self());
    {ok,UUID}-> 
        io:format("p2p_tp_ua:init Caller rpc call uuid: ~p ~n",[UUID]),
        % send 180 or 183
        % create dialog and register dialog controller    Dialog = create_dialog(State#state.invite_request, Response),
        Contact=siphelper:generate_contact_str(Caller),
        {ok,ResponseToTag} = transactionlayer:get_my_to_tag(THandler),
        Dialog=create_server_dialog(Request,ResponseToTag,Contact),
        {ok,TRef} =  timer:send_after(60*1000,tp_ack_timeout),
        State = #state{dialog=Dialog,invite_request=Request,tp_ack_timer=TRef,transaction_pid=THandler,uuid=UUID,phone=Caller,cid=Callee},
        
        transactionlayer:adopt_server_transaction_handler(THandler),
        loop(tpwtring, State)
    end.
     
	
%% StateName: idle | trying | |ring | ready | cancel    
loop(StateName,State=#state{}) ->
    receive
        Message -> 
            io:format("~p rec ~p~n",[?MODULE,Message]),
            case (catch on_message(Message,StateName,State)) of
               {'EXIT',R}-> 
		      utility:log("UserAgent ~p exit with sip_signal_exit: ~p~n",[self(),R]),
		      terminate(State),
                   exit(sip_signal_exit);
                {NewStateName,NewState} -> 
                    loop(NewStateName,NewState);
                stop -> 
                    terminate(State),
                    stop
             end
        end.

terminate(State=#state{max_talkT=MaxTalkT,timer_ref=InviteT,owner=Owner})->
	timer:cancel(MaxTalkT),
	timer:cancel(InviteT),
	timer:cancel(State#state.tp_ack_timer),
	traffic(State),
	stop.

on_message({p2p_wcg_ack, Owner, <<>>},Status,State=#state{transaction_pid=THandler}) ->
    _Ref = erlang:monitor(process,Owner),
%    SDP_TO_SS1= <<"v=0\r\no=LVOS3000 1234 1 IN IP4 10.32.3.52\r\ns=phone-call\r\nc=IN IP4 10.32.3.52\r\nt=0 0\r\nm=audio 15030 RTP/AVP 0 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20">>,
    transactionlayer:send_response_handler(THandler, 180, "Session Progress", []),
    {Status,State#state{owner=Owner}};    

on_message({p2p_wcg_ack, Owner, SDP_TO_SS},Status,State=#state{transaction_pid=THandler}) ->
    _Ref = erlang:monitor(process,Owner),
    transactionlayer:send_response_handler(THandler, 180, "Session Progress", []),
    {Status,State#state{owner=Owner,sdp_to_ss=SDP_TO_SS}};    

on_message({p2p_ring_ack, Owner},tpwtring,State=#state{transaction_pid=THandler,sdp_to_ss=SDP}) ->
    _Ref = erlang:monitor(process,Owner),
    timer:cancel(State#state.tp_ack_timer),
    io:format("p2p_ring_ack before send~n"),
    transactionlayer:send_response_handler(THandler, 180, "Session Progress", [], SDP),
%    SDP_TO_SS1= <<"v=0\r\no=LVOS3000 1234 1 IN IP4 10.32.3.52\r\ns=phone-call\r\nc=IN IP4 10.32.3.52\r\nt=0 0\r\nm=audio 15030 RTP/AVP 0 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20">>,
%    transactionlayer:send_response_handler(THandler, 180, "Session Progress", [], SDP_TO_SS1),    
    io:format("p2p_ring_ack after send~n"),
    {ring,State};    

on_message({p2p_answer, Owner},ring,State=#state{owner=Owner,transaction_pid=THandler,sdp_to_ss=SDP}) ->
    _Ref = erlang:monitor(process,Owner),
    transactionlayer:send_response_handler(THandler, 200, "OK", [{"Content-Type", ["application/sdp"]}], SDP),
    {ready,State#state{start_time=calendar:local_time()}};    

on_message({p2p_answer, Owner, SDP},ring,State=#state{owner=Owner,transaction_pid=THandler}) ->
    _Ref = erlang:monitor(process,Owner),
    transactionlayer:send_response_handler(THandler, 200, "OK", [{"Content-Type", ["application/sdp"]}], SDP),
    {ready,State#state{sdp_to_ss=SDP,start_time=calendar:local_time()}};    

on_message({p2p_reject, Owner},tpwtring,State=#state{transaction_pid=THandler}) ->
    timer:cancel(State#state.tp_ack_timer),
    transactionlayer:send_response_handler(THandler, 486, "user busy"),
    stop;    

on_message(tp_ack_timeout,_,State=#state{invite_request=InviteRequest}) ->
    THandler = transactionlayer:get_handler_for_request(InviteRequest),
    transactionlayer:send_response_handler(THandler, 403, "Unavailable"),
    stop;

on_message({servertransaction_cancelled,STPid,Reason},_,State) ->
    stop;

on_message(stop,ready,State) ->
    send_bye(State),
    stop;

on_message(stop,StateName,State=#state{transaction_pid=THandler})->
    transactionlayer:send_response_handler(THandler, 403, "Unavailable"),
    stop;   
    
on_message(stop,_,_State) ->
    stop;
on_message({'DOWN', _Ref, process, Owner, _Reason},Status,State=#state{owner=Owner})->
    stop(self()),
    {Status,State};
    

on_message(max_talk_timeout,ready,State=#state{from=From,to=To}) ->
    io:format("voip max_talk_timeout,from:~p to:~p~n", [From, To]),
    send_bye(State),
    stop;
on_message(trying_detecting_timeout,trying,_State) ->
    stop;

on_message({new_request, FromPid, Ref, NewRequest, Ctx=#yxa_ctx{thandler = undefined}},StateName,State) ->
    io:format("p2p_tp_ua new_request no thandler :~p frompid:~p~n",[NewRequest,FromPid] ),
    FromPid ! {ok, self(), Ref},
    {StateName,State};
    
on_message({new_request, FromPid, Ref, NewRequest, _YxaCtx},StateName,State) ->
    io:format("p2p_tp_ua new_request ~p ctx :~p~n",[NewRequest,_YxaCtx] ),
    THandler = transactionlayer:get_handler_for_request(NewRequest),
    FromPid ! {ok, self(), Ref},

    {ok, NewDialog} = sipdialog:update_dialog_recv_request(NewRequest, State#state.dialog),
    case NewRequest#request.method of
        Meth when Meth=="BYE" orelse Meth=="CANCEL"->                        
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
    io:format("UserAgent ~p receive unhandled message: ~p STATE: ~p~n",[Role,Unhandeld,StateName]),
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

create_dialog(Request, Response) when is_record(Request, request), is_record(Response, response) ->
    {ok, Dialog} = sipdialog:create_dialog_state_uac(Request, Response),
    ok = sipdialog:register_dialog_controller(Dialog, self(), 60*60*2),
    Dialog.
    
create_server_dialog(Request, ResponseToTag,ResponseContact) when is_record(Request, request) ->
    {ok, Dialog} = sipdialog:create_dialog_state_uas(Request, ResponseToTag,ResponseContact),
    ok = sipdialog:register_dialog_controller(Dialog, self(), 60*60*2),
%    io:format("Request:~p,ResponseToTag:~p~nResponseContact:~p~nDialog:~p~n",[Request, ResponseToTag,ResponseContact,Dialog]),
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

traffic(St=#state{uuid=UUID,cid=Cid,phone=Phone,start_time=Starttime})->
    Trf=[{caller,Cid},{uuid,UUID},{callee,Phone},{talktime,Starttime},{endtime,calendar:local_time()},{caller_sip,sipcfg:myip()},
      {callee_sip,sipcfg:ssip()},{socket_ip,sipcfg:get(sip_socket_ip)},{direction,incoming}],
    rpc:call('traffic@lwork.hk',traffic,add,[Trf]).

