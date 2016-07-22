-module(sip_op).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").

-record(state,{
               peerpid,
               dialog = null,
               sdp_from_ss,
               sdp_to_ss= <<>>,
               transaction_pid,
               invite_request,
               answer_timer,
               start_time}).


%% external API
stop(UA) -> 
    UA ! stop.

	
start(Request=#request{method="INVITE"},YxaCtx=#yxa_ctx{thandler = THandler})->
    P=spawn(fun()-> init(Request,YxaCtx) end),
    transactionlayer:change_transaction_parent(THandler,self(),P).
    

init(Request=#request{method="INVITE",body=SDP,header=Header},YxaCtx=#yxa_ctx{thandler = THandler}) ->
    %imform (Caller,Callee, SDP, self()) to www,and wait selfSDP from w2p
    {ok,ResponseToTag} = transactionlayer:get_my_to_tag(THandler),
    case handle_invite(Request,YxaCtx) of
    {{ok,PeerPid},Contact}->
        Dialog=create_server_dialog(Request,ResponseToTag,Contact),
        transactionlayer:adopt_server_transaction_handler(THandler),
        _Ref = erlang:monitor(process,PeerPid),
        State=#state{dialog=Dialog,invite_request=Request,transaction_pid=THandler,peerpid=PeerPid},
        loop(tpwtring, State);
    {{failed,Reason},_}->
        transactionlayer:send_response_handler(THandler, 403, Reason)
    end.
     
	
%% StateName: idle | trying | |ring | ready | cancel    
loop(StateName,State=#state{}) ->
    receive
        Message -> 
            %io:format("~p rec ~p~n",[?MODULE,Message]),
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

terminate(State=#state{})->
	traffic(State),
	stop.

on_message({servertransaction_cancelled,STPid,Reason},_,State) ->
    stop;

on_message(stop,ready,State) ->
    send_bye(State),
    stop;

on_message(stop,StateName,State=#state{transaction_pid=THandler})->
    transactionlayer:send_response_handler(THandler, 403, "Unavailable"),
    stop;   
    
on_message(stop,_,_State) ->
    io:format("abnormal ~p state ~p~n",[stop,_State]),
    stop;
on_message({'DOWN', _Ref, process, Owner, _Reason},Status,State=#state{peerpid=Owner})->
    stop(self()),
    {Status,State};
    

on_message(max_talk_timeout,ready,State=#state{}) ->
    io:format("voip max_talk_timeout,from:~p to:~p~n", [from, to]),
    send_bye(State),
    stop;
on_message(trying_detecting_timeout,trying,_State) ->
    stop;

on_message({new_request, FromPid, Ref, NewRequest, Ctx=#yxa_ctx{thandler = undefined}},StateName,State) ->
%    io:format("sip_op new_request no thandler :~p frompid:~p~n",[NewRequest,FromPid] ),
    FromPid ! {ok, self(), Ref},
    {StateName,State};
    
on_message({new_request, FromPid, Ref, _NewRequest=#request{method="ACK"}, _YxaCtx},StateName,State) ->
    FromPid ! {ok, self(), Ref},
    {StateName,State};
on_message({new_request, FromPid, Ref, NewRequest, _YxaCtx},StateName,State) ->
%    io:format("sip_op new_request ~p ctx :~p~n",[NewRequest,_YxaCtx] ),
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
        "INVITE" ->                        
            transactionlayer:send_response_handler(THandler, 200, "Ok"),
            {StateName,State#state{dialog=NewDialog}};
        "ACK" ->                        
            io:format("ack recved~n"),
            {StateName,State#state{dialog=NewDialog}};
        _ ->
            transactionlayer:send_response_handler(THandler, 200, "OK"),
            {StateName,State#state{dialog=NewDialog}}
    end;
    
on_message({dialog_expired, {CallId, LocalTag, RemoteTag}}, StateName, State) ->
    sipdialog:set_dialog_expires(CallId, LocalTag, RemoteTag, 30),
    {StateName, State};

on_message({clienttransaction_terminating, _, _}, StateName, State) ->
   {StateName, State};
    
on_message({'EXIT', _, normal}, StateName,State) ->
   {StateName, State};
on_message({tp_status,Status,Body}, StateName,State=#state{transaction_pid=THandler}) ->
    transactionlayer:send_response_handler(THandler, Status, "OK", [{"Content-Type", ["application/sdp"]}], Body),
    NewStateName=notify_status(self(),Status,StateName),
   {NewStateName, State};
on_message(Unhandeld,StateName,State=#state{}) ->
    {StateName,State}. 

notify_status(OpPid,Status,StateName)->
    case notify_status1(OpPid,Status) of
        not_changing-> StateName;
        NewStatename-> NewStatename
    end.
notify_status1(OpPid,200)->  call_mgr:enter_talking(OpPid), ready;
notify_status1(_,180)-> ring;
notify_status1(_,183)-> ring;
notify_status1(_,_)-> not_changing.
%% internal function    

create_dialog(Request, Response) when is_record(Request, request), is_record(Response, response) ->
    {ok, Dialog} = sipdialog:create_dialog_state_uac(Request, Response),
    ok = sipdialog:register_dialog_controller(Dialog, self(), 60*60*2),
    Dialog.
    
create_server_dialog(Request, ResponseToTag,ResponseContact) when is_record(Request, request) ->
    {ok, Dialog} = sipdialog:create_dialog_state_uas(Request, ResponseToTag,ResponseContact),
    ok = sipdialog:register_dialog_controller(Dialog, self(), 60*60*2),
%    io:format("Request:~p,ResponseToTag:~p~nResponseContact:~p~nDialog:~p~n",[Request, ResponseToTag,ResponseContact,Dialog]),
    Dialog.
    
send_bye(State) ->
    Dialog = State#state.dialog,
    if 
        Dialog =/= null ->
            {ok, Bye, _Dialog, _Dst} = 
                sipdialog:generate_new_request("BYE", [{"Max-Forwards", ["9"]}], <<>>, Dialog),
                siphelper:send_request(Bye);
        true ->
            pass
    end.
    
traffic(_St=#state{})->
    todo.
copyheaders()-> Ls=[allow,'max-forwards',"diversion","to"], [keylist:normalize(I)||I<-Ls].
handle_invite(Request=#request{method="INVITE",body=SDP,header=Header},YxaCtx=#yxa_ctx{origin=Origin,thandler = THandler})->
    {CallerName,#sipurl{user=Caller}}=sipheader:from(Header),
    {CalleeName,#sipurl{user=ToCallee}}=sipheader:to(Header),
    #sipurl{user=Callee}=Request#request.uri,
    Contact=siphelper:generate_contact_str(Caller),
    CopyHeaders = keylist:copy(Header, copyheaders()),
    {handle_invite1({CallerName,Caller},{CalleeName,Callee},Origin,SDP,CopyHeaders),Contact}.


handle_invite1(Caller,Callee,Origin,SDP,CopyHeaders)->
    call_mgr:sip_incoming(Caller,Callee,Origin,SDP,self(),CopyHeaders).
    
