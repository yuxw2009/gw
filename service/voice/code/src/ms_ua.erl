-module(ms_ua).
-compile(export_all).

-behaviour(gen_server).
-include("debug.hrl").
-include("siprecords.hrl").

-record(state, {invite_cseq=0,invite_request,dialog=null, ack_request, 
                               transaction_pid, conn_name, user_info, tref, ms_actions=[]}).

-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).
%start_link(UserInfo={_Phone, _SDP, _UserActions})-> start_link(UserInfo,self()).

start_monitor(UserInfo)->
    {ok, Ms} = gen_server:start(?MODULE, {UserInfo},[]),
    monitor(process,Ms),
    Ms.
    
start(UserInfo)->
    {ok, Ms} = gen_server:start(?MODULE, {UserInfo},[]),
    Ms.

stop(Ms_ua)->
    case is_pid(Ms_ua) andalso is_process_alive(Ms_ua) of
        true->    gen_server:cast(Ms_ua, {stop});
        _-> void
    end.
    
join_conf(Ms_ua, Confname)->
    gen_server:cast(Ms_ua, {ms_act, fun(Dialog, Connname)-> join_conf_(Dialog, Confname, Connname) end}).

enable_aec(Ms_ua)->
    gen_server:cast(Ms_ua, {ms_act, fun(Dialog, Connname)-> enable_aec_(Dialog, Connname) end}).

delay(Ms_ua, T_ms)->    
    gen_server:cast(Ms_ua, {ms_act, fun(Dialog, _Connname)-> 
                                                            {Dialog, T_ms}
                                                          end}).
send_dtmf(Ms_ua, Digits)->    
    gen_server:cast(Ms_ua, {ms_act, fun(Dialog, Connname)-> 
%                                                            timer:sleep(200),
                                                            R=send_dtmf_(Dialog, Connname, Digits) ,
%                                                            timer:sleep(1000),
                                                            R
                                                          end}).
    
play_tone(Ms_ua, File)->    
    gen_server:cast(Ms_ua, {ms_act, fun(Dialog, Connname)->
%							    timer:sleep(1000),
                                                            R=play_tone_(Dialog, Connname, File),
%                                                            timer:sleep(10000),
                                                            {R, 3000}
                                                         end}).
%stop_tone(Ms_ua)->
    
    
%%   callback for gen_server
init({UserInfo=[Phone, SDP , _, Ua | _]})->
    process_flag(trap_exit, true),
    link(Ua),
    {TransPid, Cseq, NR} = create_context(meeting:main_part(Phone), SDP),
    {ok, Tr} = timer:send_after(8000, timeout),
    {ok, #state{user_info=UserInfo, invite_cseq=Cseq,invite_request=NR,transaction_pid=TransPid, tref=Tr}}.

handle_call({stop}, From, State)->
    ?PRINT_INFO("received stop from Pid ~p", [From]),
    {stop, normal, ok, State};
handle_call(_Msg, _From, State)->
    {reply, ok, State}.
    
handle_cast({ms_act, CallAction}, State=#state{dialog=null, ms_actions=Queue}) ->
    {noreply, State#state{ms_actions=Queue++[CallAction]}};
handle_cast({ms_act, CallAction}, State=#state{dialog=Dialog,conn_name=Connname}) ->
    {ok, _Pid, NewDialog} = CallAction(Dialog, Connname),
    {noreply, State#state{dialog = NewDialog}};
handle_cast({stop}, State)->
    {stop, normal, State};
handle_cast(_Msg, State)->
    {noreply, State}.
    
handle_info({branch_result,_,_,_,#response{status=200, body=SDP}=Response}, 
                              State=#state{dialog=null, user_info=[_, _, UserActions|_],tref=Tr, ms_actions=MsCalls}) ->
    timer:cancel(Tr),
    Dialog = sipua:create_dialog(State#state.invite_request, Response),
    Ack = conf_mgr:send_ack(Dialog),
    Connname=Dialog#dialog.remote_tag,
    [Action(SDP) || Action <- UserActions],
    {NewDialog, NewMsCalls} = execute_actions(Dialog, Connname, MsCalls),
    {noreply, State#state{ack_request = Ack, dialog=NewDialog, conn_name=Connname, ms_actions=NewMsCalls}};
handle_info({branch_result,_CTPid,_,_,#response{status=200}=_Response}, State=#state{}) ->
    %%  to do, according to the CTPid to deal with the response
    {noreply, State};
handle_info({continue_msactions}, State=#state{dialog=Dialog, conn_name=Connname, ms_actions=MsCalls}) ->
    {NewDialog, NewMsCalls} = execute_actions(Dialog, Connname, MsCalls),
    {noreply, State#state{dialog=NewDialog, ms_actions=NewMsCalls}};
handle_info(timeout, State=#state{dialog=null}) ->
    ?ERROR_INFO("creating context timeout"),
    {stop, {ms_ua_create_context_timeout}, State};
handle_info({new_response, #response{status=200}=Response, _YxaCtx}, State=#state{}) ->
    case siphelper:cseq(Response#response.header) of
	    {CSeqNo, "INVITE"} 
		    when CSeqNo == State#state.invite_cseq, State#state.ack_request /= undefined ->
	    %% Resend ACK
	        {ok, _SendingSocket, _Dst, _TLBranch} = 
			    siphelper:send_ack(State#state.ack_request, []);
	    _ -> pass
    end,
    {noreply, State};
handle_info({new_request, FromPid, Ref, #request{method="ACK"}, _YxaCtx},State) ->
    FromPid ! {ok, self(), Ref},
    {noreply,State};
handle_info({new_request, FromPid, Ref, NewRequest, _YxaCtx},State=#state{user_info=[_, SDP|_]}) ->
    FromPid ! {ok, self(), Ref},
    {Status, NewDialog} = handle_new_request(NewRequest, State#state.dialog, SDP),
    {Status, State#state{dialog=NewDialog}};

handle_info({clienttransaction_terminating,_CTPid,_}, State=#state{}) ->
    {noreply, State#state{}};

handle_info({dialog_expired, {CallId, LocalTag, RemoteTag}}, State) ->
    sipdialog:set_dialog_expires(CallId, LocalTag, RemoteTag, 300),
    {noreply, State};

handle_info({'EXIT',Ua,Reason},State=#state{user_info=[_,_,_,Ua |_]}) ->
    ?PRINT_INFO("sip ua exit, so conf ua is over, ua' reason of exitting is ~p~n", [Reason]),
    {stop, Reason, State};

handle_info(Info, State=#state{}) ->
    ?PRINT_INFO("ms ua recv ~p~n",[Info]),
    {noreply, State}.    
    
code_change(_Oldvsn, State, _Extra)->
    {ok, State}.

terminate(bye_received_from_ms, #state{})->
    ?PRINT_INFO("ms_ua stopped! reason is bye_received_from_ms~n"),
    ok;
terminate(Reason, #state{dialog=Dialog, transaction_pid=TID, tref=Tr})->
    conf_mgr:tear_down_ms_dialog(Dialog, TID, Tr, Reason).		    
    
%%  internal function    
create_context(Phone, SDP)->
    {ok, Request} = sipua:build_invite(conf:user_host2url(Phone, siphost:myip()), conf:ms_addr("msml"), SDP),
    conf_mgr:do_send_invite(Request,0).
    
msml2conf(SDP, Dialog)->
    {ok, Req, NewDialog, _Dst} = 
        sipdialog:generate_new_request("INFO", 
                 [{"Content-Type",[ "application/msml+xml"]}], 
                    SDP, Dialog),
    {ok, Pid, _Branch} = siphelper:send_request(Req),
    {ok, Pid, NewDialog}.

join_conf_(Dialog,Confname, Connname)->
    msml2conf(conf_msml:join_conf(Connname, Confname), Dialog).

enable_aec_(Dialog, Connname)->
    msml2conf(conf_msml:aec_conn(Connname, enable), Dialog).

send_dtmf_(Dialog,Connname, Digits)->
    msml2conf(conf_msml:send_dtmf(Connname, Digits), Dialog).
    
play_tone_(Dialog,Connname, File)->
    msml2conf(conf_msml:play("conn:"++Connname, File), Dialog).

execute_actions(Dialog, _Connname, [])->
    {Dialog, []};
execute_actions(Dialog, Connname, [MsAction | T])->
    case MsAction(Dialog, Connname) of
    {ok, _Pid, NewDialog}-> execute_actions(NewDialog, Connname, T);
    {{ok, _Pid, NewDialog}, Timeout}-> 
        timer:send_after(Timeout, {continue_msactions}),
        {NewDialog, T}
    end;
execute_actions(Dialog, _Connname, Actions)->
    io:format("receive unexpected Actions: ~p~n", [Actions]),
    {Dialog, []}.

handle_new_request(NewRequest, Dialog, SDP)->
    THandler = transactionlayer:get_handler_for_request(NewRequest),
    case sipdialog:update_dialog_recv_request(NewRequest, Dialog) of
        {ok, NewDialog}-> handle_new_request1(NewRequest, NewDialog, THandler, SDP);
        _-> {noreply, Dialog}
    end.

handle_new_request1(_NewRequest=#request{method="INVITE"}, NewDialog, THandler, SDP)->
    transactionlayer:send_response_handler(THandler, 200, "OK", [{"Content-Type", ["application/sdp"]}], SDP),
    {noreply, NewDialog};
handle_new_request1(_NewRequest=#request{method="BYE"}, NewDialog, THandler, _SDP)->
    transactionlayer:send_response_handler(THandler, 200, "Ok"),
    {stop, NewDialog};
handle_new_request1(_NewRequest=#request{method="OPTIONS"}, NewDialog, THandler, _SDP)->
    transactionlayer:send_response_handler(THandler, 200, "Ok"),
    {noreply, NewDialog};
handle_new_request1(NewRequest=#request{method="INFO",body=Body}, NewDialog, THandler, _SDP)->
    case keylist:fetch('Content-Type', NewRequest#request.header) of
        "application/msml+xml"->
            io:format("receive ms info: body:~s~n", [Body]);
        _->
            pass
    end,
    transactionlayer:send_response_handler(THandler, 200, "Ok"),
    {noreply, NewDialog};
handle_new_request1(_NewRequest=#request{method=Meth}, NewDialog, THandler, _SDP)->
    ?DEBUG_INFO("rec sip request ~p, send 501 not implemented~n", [Meth]),
    transactionlayer:send_response_handler(THandler, 501, "Not Implemented"),
    {noreply, NewDialog}.
    
    
    
