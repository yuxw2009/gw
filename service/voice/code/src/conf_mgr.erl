-module(conf_mgr).
-compile(export_all).

-behaviour(gen_server).
-include("debug.hrl").
-include("siprecords.hrl").

-record(state, {confname_list=[], invite_cseq=0,transaction_pid,invite_request,dialog=null,
                            ack_request, trans_conf_dict, tref}).

-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).

start()-> start(self()).

start(From)->
    {ok, Pid} = gen_server:start({local, ?MODULE}, ?MODULE, {From},[]),
    Pid.

stop()->
     case whereis(?MODULE) of
        undefined-> 
            ?PRINT_INFO("*********************************************************~n"
                                 "conf_mgr is already stopped~n");
        _->
         gen_server:call(?MODULE, {stop})
    end.

create_conf(ConfInfos)->
    call_on_conf_mgr({create_conf, ConfInfos}).

get_confs()->
    call_on_conf_mgr(get_confs).

reset_ms()->
    call_on_conf_mgr({reset_ms}).

callid_modify_func(CallId)->
    fun(State=#state{dialog=Dialog})-> State#state{dialog=Dialog#dialog{callid=CallId}} end.

modify_state(Fun)->
    call_on_conf_mgr({modify_state, Fun}).

destroy_conf(Confname)->
    call_on_conf_mgr({destroy_conf, Confname}).

%%   callback for gen_server
init({_From})->
    {TransPid, Cseq, NR} = create_channel(),
    {ok, Tr} = timer:send_after(8000, timeout),
    {ok, #state{invite_cseq=Cseq,transaction_pid=TransPid,invite_request=NR, trans_conf_dict=dict:new(), tref=Tr}}.
handle_call({stop}, From, State)->
    ?PRINT_INFO("received stop from Pid ~p", [From]),
    {stop, {stop_from, From}, State};
handle_call(_, _From, State=#state{dialog=null})->
    {reply, {fail, conf_channel_not_created}, State};
handle_call(get_confs, _From, State=#state{confname_list=ConfList})->
    {reply, ConfList, State};
handle_call({reset_ms}, _From, State=#state{dialog=Dialog, trans_conf_dict=Dict})->
    {ok,  CTPid, NewDialog} = reset_msml(Dialog),
    {reply, ok, State#state{trans_conf_dict=dict:store(CTPid, null, Dict),  dialog=NewDialog}};
handle_call({create_conf, _ConfInfos = [_Confname | _]}, _From, State=#state{dialog=null})->
    {reply, {error, conf_mgr_context_not_create}, State};
handle_call({create_conf, ConfInfos = [Confname | _]}, _From, State=#state{dialog=Dialog, trans_conf_dict=Dict, confname_list=List})->
    ConfPid = case conf:conf_pid(Confname) of
                        undefined->  conf:start(self(), ConfInfos);
                        Pid-> Pid
                    end,
    {ok,  CTPid, NewDialog} = create_conf(Dialog,Confname),
    {reply, {ok, ConfPid}, State#state{confname_list=[Confname|List], trans_conf_dict=dict:store(CTPid, ConfPid, Dict),  dialog=NewDialog}};

handle_call({modify_state, Fun}, _From, State)->
    NewState = Fun(State),
    {reply, {ok, NewState}, NewState};
    
handle_call({destroy_conf, Confname}, _From, 
                            State=#state{dialog=Dialog, trans_conf_dict=Dict, confname_list=List})->
    {ok,  CTPid, NewDialog} = destroy_conf(Dialog,Confname),
    ?PRINT_INFO("destroy CONF:~p~n", [Confname]),
    {reply, ok, State#state{confname_list=lists:delete(Confname, List),trans_conf_dict=dict:store(CTPid, null, Dict),  dialog=NewDialog}};
handle_call(_Msg, _From, State)->
    {reply, ok, State}.
handle_cast(_Msg, State)->
    {noreply, State}.
    
handle_info({branch_result,_,_,_,#response{status=200}=Response}, State=#state{dialog=null, tref=Tr}) ->
    timer:cancel(Tr),
    Dialog = sipua:create_dialog(State#state.invite_request, Response),
    Ack = send_ack(Dialog),
    {noreply, State#state{ack_request = Ack, dialog=Dialog}};
handle_info(Msg={branch_result,CTPid,_,_,#response{status=200}=Response}, State=#state{trans_conf_dict=Dict}) ->
    case dict:find(CTPid, Dict) of
        {ok, null} -> null;
        {ok, Conf}-> Conf ! Msg;
        error->  ?PRINT_INFO("conf_mgr recv unexpected response: ~p~n",[Response])
    end,
    {noreply, State};
handle_info({branch_result,_,_,_,#response{status=481}=_Response}, State=#state{tref=Tr}) ->
    timer:cancel(Tr),
    {stop, conf_mgr_rec_481, State};
handle_info(timeout, State=#state{dialog=null}) ->
    ?ERROR_INFO("creating channel timeout"),
    {stop, create_channel_timeout, State};
handle_info({new_response, #response{status=200}=Response, _YxaCtx}, State=#state{}) ->
    case siphelper:cseq(Response#response.header) of
	    {CSeqNo, "INVITE"} 
		    when CSeqNo == State#state.invite_cseq, State#state.ack_request /= undefined ->
	    %% Resend ACK
	        {ok, _SendingSocket, _Dst, _TLBranch} = 
			    siphelper:send_ack(State#state.ack_request, []);
	    _ ->
	        pass
    end,
    {noreply, State};
handle_info({new_request, FromPid, Ref, #request{method="ACK"}, _YxaCtx},State) ->
    FromPid ! {ok, self(), Ref},
    {noreply,State};
    
handle_info({new_request, FromPid, Ref, NewRequest, _YxaCtx},State) ->
    FromPid ! {ok, self(), Ref},
    {_, NewDialog} = ms_ua:handle_new_request(NewRequest, State#state.dialog, null_rtp()),
    {noreply, State#state{dialog=NewDialog}};
    
handle_info({clienttransaction_terminating,CTPid,_}, State=#state{trans_conf_dict=D}) ->
    {noreply, State#state{trans_conf_dict=dict:erase(CTPid, D)}};

handle_info({dialog_expired, {CallId, LocalTag, RemoteTag}}, State) ->
    sipdialog:set_dialog_expires(CallId, LocalTag, RemoteTag, 300),
    {noreply, State};

handle_info(Info, State=#state{}) ->
    ?PRINT_INFO("conf_mgr recv ~p~n",[Info]),
    {noreply, State}.    
    
code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(Reason, #state{dialog=Dialog, transaction_pid=TID, tref=Tr})->
    ?PRINT_INFO("*******************************************************************~n" 
                         "conf channel terminated - should restart! "
		       "reason is ~p~n", [Reason]),
    tear_down_ms_dialog(Dialog, TID, Tr, Reason).		

tear_down_ms_dialog(Dialog, TID, Tr, Reason)->
    timer:cancel(Tr),	   
    case Dialog of
        null -> gen_server:cast(TID,{cancel, "hangup", []});
        _-> send_bye(Dialog)
    end,
    Reason.		
    
%%  internal function    
create_channel()->
    {ok, Request} = sipua:build_invite(conf:user_host2url("msml", siphost:myip()), conf:ms_addr("msml"), null_rtp()),
    do_send_invite(Request,0).
    
null_rtp() ->
    <<"v=0\r\no=LTALK 100 1000 IN IP4 10.60.162.14\r\ns=phone-call\r\nc=IN IP4 10.60.162.14\r\nt=0 0\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20\r\n">>.
%<<"v=0\r\no=LTALK 100 1000 IN IP4 10.60.162.13\r\ns=phone-call\r\nc=IN IP4 0.0.0.0\r\nt=0 0\r\nm=audio 10792 RTP/AVP 18 4 8 0 101\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=ptime:20\r\n">>.

do_send_invite(Request,CurCseq) ->
    Header = Request#request.header,
    CSeq = CurCseq + 1,
    NewHeader = keylist:set("CSeq", [lists:concat([CSeq, " ", Request#request.method])], Header),
    NewRequest = Request#request{header=NewHeader},
    {ok, Pid, _Branch} = siphelper:send_request(NewRequest),
    {Pid, CSeq, NewRequest}.

msml2conf(SDP, Dialog)->
    {ok, Req, NewDialog, _Dst} = 
        sipdialog:generate_new_request("INFO", 
                 [{"Content-Type",[ "application/msml+xml"]}], 
                    SDP, Dialog),
    {ok, Pid, _Branch} = siphelper:send_request(Req),
    {ok, Pid, NewDialog}.

create_conf(Dialog,Name)->
    msml2conf(conf_msml:build_conf(Name), Dialog).

destroy_conf(Dialog,Name)->
    msml2conf(conf_msml:destroy_conf(Name), Dialog).

reset_msml(Dialog)->
    msml2conf(conf_msml:reset(), Dialog).
    
send_bye(Dialog) ->
	if 
	    Dialog =/= null ->
            {ok, Bye, _Dialog, _Dst} = 
	            sipdialog:generate_new_request("BYE", [], <<>>, Dialog),
                siphelper:send_request(Bye);
		true ->
		    pass
	end.

call_on_conf_mgr(Action)->
    case whereis(?MODULE) of
        undefined-> 
            start(),
            {error, conf_mgr_process_not_alive};
        _-> gen_server:call(?MODULE, Action)
    end.
    
send_ack(Dialog)->
    CSeq = integer_to_list(Dialog#dialog.local_cseq),
    {ok, Ack, _Dialog, _Dst} = 
        sipdialog:generate_new_request("ACK", [{"CSeq", [CSeq++ " ACK"]}], <<>>, Dialog),
    siphelper:send_ack(Ack, []),
    Ack.

