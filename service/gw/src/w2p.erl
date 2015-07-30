-module(w2p).

-export([start/5, stop/1, get_call_status/1, dial/2, peek/1]).
-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).
-compile(export_all).

-include("sdp.hrl").

-define(ALIVE_TIME,30000).
-define(TALKTIMEOUT,6000000*2).
-define(P2P_OK_WAITTIME,5000).

-define(PCMU,0).
-define(PCMA,8).
-define(G729,18).
-define(CNU,13).
-define(L16,107).

-record(state, {aid,
                p2p_peer_aid,
                call_type,    % p2p_call, real_call, maybe_p2p_call,sip_call_in
                p2pok_waittimer,
                codec,
				test = fasle,
                call_info=[],
				call_stats=[],
                status,  %% idle | invite | ring ...				
                rtp_pid,
				rtp_port,
				rrp_pid,
				rrp_port,
				sip_ua,
				alive_tref,
				alive_count=0,
				pltype,
				start_time={0,0,0}
                }).

%% APIs
start(call_ios,SipPid,SipInfo)->
    {ok, Pid} = my_server:start(?MODULE,[call_ios,SipPid,SipInfo],[]),
    {value, Aid, Port} = get_aid_rrp_port(Pid),
    SDP_TO_SS = get_local_sdp(Port),
    SipPid ! {p2p_wcg_ack, Pid, SDP_TO_SS},
    {successful,Aid,{"",0},[]}.	
    
get_rtp_port(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
              {value, _Aid, Port} = get_aid_port_pair(AppPid),
              {value, Port};	
		_ ->
		    {failed, no_app_id}
	end.
sip_p2p_ring(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, sip_p2p_ring),
		    ok;
		_ ->
		    {failed, no_app_id}
	end.
sip_p2p_answer(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, sip_p2p_answer);
		_ ->
		    pass
	end.
     
p2w_ios_ring(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, p2w_ios_ring);
		_ ->
		    {failed, no_app_id}
	end.
p2w_ios_answer(AppId,WebSdp)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, {p2w_ios_answer,WebSdp});
		_ ->
		    {failed,no_appid}
	end.
     
start_p2p_answer(L_Options,R_Options)->
    {ok, Pid} = my_server:start(?MODULE,[{p2p_answer, L_Options,R_Options}],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
    
start_p2p_ios_answer(WebSDP,OpRtpPid)->
    {ok, Pid} = my_server:start(?MODULE,[p2p_ios_answer],[]),
    Act = fun(State=#state{aid=Aid})->
                PLType = avscfg:get(webrtc_web_codec),
                io:format("p2p_ios_answer:~p~n",[PLType]),
                {ok,RtpPid,RtpPort} = rtp:start(Aid,[{pltype,PLType},{report_to, self()}]), 
                link(RtpPid),
                {ok,Options1,Options2,AnswSDP,CandidateAddr}=wkr:decodeWebSDP(WebSDP,RtpPort,OpRtpPid),
                my_server:call(RtpPid,{options,Options1}),
                rtp:info(RtpPid,{add_stream,audio,Options2}),
                rtp:info(RtpPid,{add_candidate,CandidateAddr}),
                {{ok,Aid,AnswSDP},State#state{rtp_pid=RtpPid,rtp_port=RtpPort,pltype=PLType}}
            end,
    my_server:call(Pid, {act,Act}).
    
start(Options1, Options2, PhInfo,PLType, CandidateAddr) ->
    {ok, Pid} = my_server:start(?MODULE,[Options1, Options2, PhInfo,PLType, CandidateAddr],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
	
stop(AppId) ->
    case  app_manager:lookup_app_pid(AppId) of
    {value, AppPid}->
        my_server:cast(AppPid, stop);
    _-> void
    end.

get_call_status(AppId) ->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, get_call_status);
		_ ->
		    {value,released, []}
	end.
	
dial(AppId, Num) ->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, {dial,Num});
		_ ->
		    pass
	end.
	
peek(AppId) ->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, peek_internal);
		_ ->
		   {error, app_not_found}
	end. 
	
init([call_ios,SipPid,SipInfo]) ->
	{value, Aid}  = app_manager:register_app(self()),
	PLType = avscfg:get(webrtc_web_codec),
      Codec = acquire_codec(PLType),
      io:format("p2w sipinfo:~p~n",[SipInfo]),
      {ok,RrpPid,Port} = rrp:start(Aid,Codec,[{call_info,SipInfo}]),
      io:format("p2w sipinfo:~p~n",[{ok,RrpPid,Port}]),
      start_resource_monitor(RrpPid, Codec),
      link(RrpPid),
      SipSdp= proplists:get_value(ss_sdp,SipInfo,<<>>),
      self() ! {callee_sdp,SipSdp},
      _Ref = erlang:monitor(process,SipPid),
	{ok, #state{aid=Aid, status=idle,call_info=SipInfo,pltype=PLType,call_type=sip_call_in,sip_ua=SipPid,rrp_pid=RrpPid,rrp_port=Port}};

init([p2p_ios_answer]) ->
	{value, Aid}  = app_manager:register_app(self()),
	{ok, #state{aid=Aid, status=p2p_answer,call_type=p2p_call}};

init([{sip_call_in_ios,Options1}, Options2, SipInfo, PLType, CandidateAddr]) ->
	{value, Aid}  = app_manager:register_app(self()),
	{ok,RtpPid,RtpPort} = rtp:start_mobile(Aid,  [{report_to, self()}|Options1]), 
	link(RtpPid),
	rtp:info(RtpPid,{add_stream,audio,Options2}),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("app ~p started rtp ~p rpt_port ~p user_info ~p PlType ~p",
	                               [Aid,RtpPid, RtpPort,SipInfo, PLType]),
	UA = proplists:get_value(voip_ua,SipInfo),
	my_server:cast(self(),{stun_locked, Aid}),
	{ok, #state{aid=Aid, status=idle, alive_tref=ATef,
	            call_info=SipInfo, rtp_pid=RtpPid, rtp_port=RtpPort,pltype=PLType,call_type=sip_call_in,sip_ua=UA}};
	
init([{sip_call_in,Options1}, Options2, SipInfo, PLType, CandidateAddr]) ->
	{value, Aid}  = app_manager:register_app(self()),
	{ok,RtpPid,RtpPort} = rtp:start_mobile(Aid,  [{report_to, self()}|Options1]), 
	link(RtpPid),
	rtp:info(RtpPid,{add_stream,audio,Options2}),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("app ~p started rtp ~p rpt_port ~p user_info ~p PlType ~p",
	                               [Aid,RtpPid, RtpPort,SipInfo, PLType]),
	UA = proplists:get_value(voip_ua,SipInfo),
	my_server:cast(self(),{stun_locked, Aid}),
	{ok, #state{aid=Aid, status=idle, alive_tref=ATef,
	            call_info=SipInfo, rtp_pid=RtpPid, rtp_port=RtpPort,pltype=PLType,call_type=sip_call_in,sip_ua=UA}};
	
init([{p2p_answer,L_Options,R_Options}]) ->
	{value, Aid}  = app_manager:register_app(self()),
	PLType = proplists:get_value(pltype,L_Options),
	{ok,RtpPid,RtpPort} = rtp:start_mobile(Aid,  R_Options), 
	link(RtpPid),
	rtp:info(RtpPid,{add_stream,audio,L_Options}),
	Media = proplists:get_value(media, L_Options),
%	rtp:info(Media, {media_relay,RtpPid}),  don't media_relay this time, because rtp base_rtp is not ready,must call this when stun_locked
	CandidateAddr=proplists:get_value(addr,L_Options),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("p2p_answer: appid ~p started rpt_port ~p PlType ~p", [Aid,RtpPort, PLType]),
	{ok, #state{aid=Aid, status=p2p_answer, alive_tref=ATef, rtp_pid=RtpPid, rtp_port=RtpPort,pltype=PLType}};
init([{mobile,Options1}, Options2, PhInfo, PLType, CandidateAddr]) ->
	{value, Aid}  = app_manager:register_app(self()),
	{ok,RtpPid,RtpPort} = rtp:start_mobile(Aid,  [{phinfo,PhInfo},{pltype,PLType},{report_to, self()}|Options1]), 
	link(RtpPid),
	rtp:info(RtpPid,{add_stream,audio,Options2}),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("app ~p started rtp ~p rpt_port ~p user_info ~p PlType ~p",
	                               [Aid,RtpPid, RtpPort,PhInfo, PLType]),
	{ok, #state{aid=Aid, status=idle, alive_tref=ATef,
	            call_info=PhInfo, rtp_pid=RtpPid, rtp_port=RtpPort,pltype=PLType}};
	
init([Options1, Options2, PhInfo, PLType, CandidateAddr]) ->
	{value, Aid}  = app_manager:register_app(self()),
	{ok,RtpPid,RtpPort} = rtp:start(Aid, Options1 ++ [{report_to, self()}]), 
	link(RtpPid),
	rtp:info(RtpPid,{add_stream,audio,Options2}),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("app ~p started rtp ~p rpt_port ~p user_info ~p PlType ~p",
	                               [Aid,RtpPid, RtpPort,PhInfo, PLType]),
	{ok, #state{aid=Aid, status=idle, alive_tref=ATef,
	            call_info=PhInfo, rtp_pid=RtpPid, rtp_port=RtpPort,pltype=PLType}}.

handle_call(p2w_ios_ring,_,State=#state{status=idle,sip_ua=UA,rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
    UA ! {p2p_ring_ack,self()},
%    if is_pid(RrpPid)-> RrpPid ! {play,RtpPid}; true-> void end,
    % play ring back tone to sip(rrp)
    {ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
    if is_pid(RrpPid)-> RrpPid ! {play,undefined}; true-> void end,
    play_rbt(RrpPid,?L16),
    {reply,ok,State#state{status=ring,alive_tref=ATef}};
handle_call(p2w_ios_ring,_,State=#state{status=_Not_idle,sip_ua=UA,rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
    {reply,{failed,not_idle},State#state{status=ring}};
handle_call({p2w_ios_answer,SDP},_,State=#state{aid=Aid,sip_ua=UA,rrp_pid=RrpPid,pltype=Pltype}) ->
	if is_pid(UA)-> UA ! {p2p_answer,self()}; true-> void end,
	stop_rbt(RrpPid),
	%% todo
	{ok,RtpPid,RtpPort} = rtp:start(Aid,[{pltype,Pltype},{report_to, self()}]), 
	link(RtpPid),
	{ok,Options1,Options2,AnswSDP,CandidateAddr}=wkr:decodeWebSDP(SDP,RtpPort),
	my_server:call(RtpPid,{options,Options1}),
	rtp:info(RtpPid,{add_stream,audio,Options2}),
	rtp:info(RtpPid,{add_candidate,CandidateAddr}),
	io:format("p2w: ~p started rtp ~p rpt_port ~p PlType ~p",[Aid,RtpPid, RtpPort, Pltype]),
      if is_pid(RtpPid)-> rtp:info(RtpPid,{media_relay,RrpPid}); true-> void end,
	{reply,{ok,AnswSDP},
	            State#state{status=p2p_answer,rtp_pid=RtpPid,rtp_port=RtpPort}};
handle_call({act,Act}, _, State) ->
    {Res,State1} = Act(State),
    {reply,Res,State1};
handle_call(get_call_status, _From, State=#state{status=Status,call_stats=Stats,alive_count=AC}) ->
    {reply, {value, Status, Stats}, State#state{alive_count=AC+1}};
handle_call(get_aid_port_pair, _From, State=#state{aid=Aid,rtp_port=RtpPort}) ->
    {reply, {value,Aid,RtpPort}, State};
handle_call(peek_internal, _From, State) ->
    {reply, {value, State}, State};
handle_call(_Call, _From, State) ->
    {noreply,State}.

handle_cast(sip_p2p_ring,State=#state{call_type=sip_call_in,sip_ua=UA,rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
    UA ! {p2p_ring_ack,self()},
%    if is_pid(RrpPid)-> RrpPid ! {play,RtpPid}; true-> void end,
    % play ring back tone to sip(rrp)
    if is_pid(RrpPid)-> RrpPid ! {play,undefined}; true-> void end,
    play_rbt(RrpPid,?L16),
    {noreply,State#state{status=ring}};
handle_cast(sip_p2p_answer,State=#state{call_type=sip_call_in,sip_ua=UA,rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
	UA ! {p2p_answer,self()},
	stop_rbt(RrpPid),
      if is_pid(RtpPid)-> rtp:info(RtpPid,{media_relay,RrpPid}); true-> void end,
	{noreply,State#state{status=p2p_answer}};
handle_cast({dial, Nu},State=#state{rrp_pid=RrpPid}) ->
	if is_pid(RrpPid)-> RrpPid ! {send_phone_event,Nu,9,160*7}; true-> void end,
	{noreply,State};
handle_cast({stun_locked, Aid}, State0=#state{status=Status}) when Status==p2p_answer orelse Status==ring orelse Status==p2p_answer ->
    {noreply, State0};
handle_cast({stun_locked, Aid}, State0=#state{aid=Aid0, call_info=CallInfo,pltype=PLType0,call_type=CallType}) ->
    llog("rtp ~p stun locked.pltype:~p call_type:~p",[Aid0,PLType0, CallType]),
    Act = fun(State)->    
                #state{aid=Aid, call_info=CallInfo,pltype=PLType}=State,
                Codec = acquire_codec(PLType),
                {ok,RrpPid,Port} = rrp:start(Aid,Codec,[{call_info,CallInfo}]),
                start_resource_monitor(RrpPid, Codec),
                link(RrpPid),
                NewState=deal_callinfo(State#state{rrp_pid=RrpPid, rrp_port=Port,codec=Codec}),
                NewState
            end,
    NewState = 
        if CallType == p2p_call->
            no_sipcall,
            State0;
        CallType == maybe_p2p_call ->
            {ok,P2pOk_waitT}=my_timer:send_after(?P2P_OK_WAITTIME, {act,Act}),
            llog("stun_locked p2p_call: ~p", [P2pOk_waitT]),
            State0#state{p2pok_waittimer=P2pOk_waitT};
        true->  Act(State0)
        end,
    {noreply, NewState};
handle_cast({call_stats,Aid,Stat}, State=#state{aid=Aid}) ->
    {noreply, State#state{call_stats=Stat}};	
handle_cast(stop, State=#state{aid=Aid}) ->
    llog("app ~p web hangup",[Aid]),
    {stop,normal,State};	
handle_cast(_Msg, State) ->
    {noreply, State}.	
handle_info({act,Act}, State) ->
    State1 = Act(State),
    {noreply,State1};
handle_info({callee_status, Status},State=#state{rtp_pid=RtpPid,rrp_pid=RrpPid}) ->
    if 
	    Status == ring -> 
			rtp:info(RtpPid, {media_relay,RrpPid}),
			my_timer:send_after(?TALKTIMEOUT,timeover);
        true -> 
		    ok 
	end,
    {noreply,State#state{status=Status}};
handle_info({callee_sdp,SDP_FROM_SS},State=#state{aid=Aid,rrp_pid=RrpPid}) ->
    llog("app ~p ss sdp: ~p",[Aid,SDP_FROM_SS]),
    case  get_port_from_sdp(SDP_FROM_SS) of
    {PeerIp,PeerPort}->
        PeerAddr = [{remoteip,[PeerIp,PeerPort]}],
	  ok = rrp:set_peer_addr(RrpPid, PeerAddr);
    _-> void
    end,
%	{noreply,State#state{status=hook_off}};	
	{noreply,State};	
handle_info({alert,_From},State=#state{rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
            io:format("w2p alert RrpPid:~p RtpPid:~p new_rbt:~p~n",[RrpPid,RtpPid,whereis(new_rbt)]),
    if is_pid(RrpPid)-> RrpPid ! {pause,RtpPid}; true-> void end,
    case whereis(new_rbt) of
    Rbt when is_pid(Rbt)-> Rbt ! {add,RtpPid,self(), 20,ilbc,false}; 
    _-> void 
    end,
    {noreply,State};	
	
handle_info({alert_over, _From},State=#state{rrp_pid=RrpPid,rtp_pid=RtpPid}) ->
            io:format("w2p alert_over RrpPid:~p RtpPid:~p new_rbt:~p~n",[RrpPid,RtpPid,whereis(new_rbt)]),
%    if is_pid(RrpPid)-> RrpPid ! {play,RtpPid}; true-> void end,
    if is_pid(RtpPid)-> 	rtp:info(RtpPid, {media_relay,RrpPid}); true-> void end,
    {noreply,State};	
	
handle_info({'DOWN', _Ref, process, UA, _Reason},State=#state{aid=Aid,sip_ua=UA})->
    llog("app ~p sip hangup",[Aid]),
	{stop, normal, State};
handle_info(timeover,State=#state{aid=Aid,sip_ua=UA}) ->
    llog("app ~p max talk timeout.",[Aid]),
    {APPMODU,SIPNODE} = avscfg:get(sip_app_node),
    rpc:call(SIPNODE,APPMODU,stop,[UA]),
    {stop,normal,State};
handle_info(alive_timer,State=#state{aid=Aid, alive_count=AC}) ->
    if
	    AC  =:= 0 ->
		    llog("app ~p alive timeout.~n",[Aid]),
			{stop,alive_time_out,State};
		true ->
		    {noreply,State#state{alive_count=0}}
	end;
handle_info(Msg,State) ->
     llog("app ~p receive unexpected message ~p.",[State, Msg]),
    {noreply, State}.

terminate(_Reason, #state{aid=Aid,rtp_pid=RtpPid,rrp_pid=RrpPid,alive_tref=AT,sip_ua=UA,call_info=CallInfo,start_time=ST,p2p_peer_aid=PeerAid}) -> 
    my_timer:cancel(AT),
    {APPMODU,SIPNODE} = avscfg:get(sip_app_node),
    if is_pid(UA)->  rpc:call(SIPNODE,APPMODU,stop,[UA]); true-> void end,
    if is_pid(RtpPid)->  rtp:stop(RtpPid); true-> void end,
    if is_pid(RrpPid)->  rrp:stop(RrpPid); true-> void end,
    
    Phone = proplists:get_value(phone,CallInfo),
    if is_integer(PeerAid)-> avanda:stopNATIVE(PeerAid); true-> void end,

    llog("app ~p leave. (~ps)",[Aid,duration(ST)]),
    ok.	
	
%% helpers	
get_aid_port_pair(Pid) ->	
    my_server:call(Pid, get_aid_port_pair).	
		
acquire_codec(Codec) ->
    WebCdc = rrp:rrp_get_web_codec(Codec),
	SipCdc = rrp:rrp_get_sip_codec(),
	{WebCdc,SipCdc}.
	
release_codec(undefined) -> void;
release_codec(Codec) ->
    llog("codec released ~p~n",[Codec]),
    rrp:rrp_release_codec(Codec).
	
start_resource_monitor(RrpPid, Codec) ->
	M = fun() ->
	        erlang:monitor(process, RrpPid),
	        receive
			    {'DOWN', _Ref, process, RrpPid, _Reason} ->
				    release_codec(Codec)
			end
	    end,
	spawn(M).
	
start_sip_call(State=#state{call_type=sip_call_in,call_info=CallInfos, rrp_port=RrpPort,rrp_pid=RrpPid}) ->
    SDP_FROM_SS=proplists:get_value(ss_sdp,CallInfos),
    {PeerIp,PeerPort} = get_port_from_sdp(SDP_FROM_SS),
    PeerAddr = [{remoteip,[PeerIp,PeerPort]}],
	ok = rrp:set_peer_addr(RrpPid, PeerAddr),
    UA=proplists:get_value(voip_ua,CallInfos),
    
    SDP_TO_SS = get_local_sdp(RrpPort),
    _Ref = erlang:monitor(process,UA),
    
    UA ! {p2p_wcg_ack, self(), SDP_TO_SS},
    io:format("start_sip_call sip_call_in:   UA ~p~n", [UA]),
    State#state{start_time=now(),status=ring,sip_ua=UA};
start_sip_call(State=#state{test=rtp_loop, rtp_pid=RtpPid, rrp_port=RrpPort, rrp_pid=RrpPid}) ->
	rtp:info(RtpPid, {media_relay,RtpPid}),
	State#state{start_time=now(),status=hook_off};
start_sip_call(State=#state{test=true, rtp_pid=RtpPid, rrp_port=RrpPort, rrp_pid=RrpPid}) ->
    PeerAddr = [{remoteip,[avscfg:get(sip_socket_ip),RrpPort]}],
	ok = rrp:set_peer_addr(RrpPid, PeerAddr),
	rtp:info(RtpPid, {media_relay,RrpPid}),
	State#state{start_time=now(),status=hook_off};
start_sip_call(State=#state{aid=Aid, call_info=CallInfo, rtp_pid=RtpPid, rrp_port=RrpPort, rrp_pid=RrpPid}) ->
	{APPMODU,SIPNODE} = avscfg:get(sip_app_node),
	SDP_TO_SS = get_local_sdp(RrpPort),
	UA = rpc:call(SIPNODE,APPMODU,start_with_sdp,[self(),CallInfo, SDP_TO_SS]),
    _Ref = erlang:monitor(process,UA),
    llog("gw ~p port ~p call ~p sdp_to_ss ~p~n", [Aid,RrpPort,CallInfo,SDP_TO_SS]),
      Phone = proplists:get_value(cid,CallInfo),

	State#state{start_time=now(),status=invite,sip_ua=UA}.
	
get_port_from_sdp(SDP_FROM_SS) when is_binary(SDP_FROM_SS)->
    {#session_desc{connect={_Inet4,Addr}},[St2]} = sdp:decode(SDP_FROM_SS),
    {Addr,St2#media_desc.port};
get_port_from_sdp(_)->  undefined.

get_local_sdp(LPort) ->
    {Se1,St1} = 'SAMPLE'(LPort),
    sdp:encode(Se1,[St1]).
    
'SAMPLE'(Port) -> 
	HOST = avscfg:get(ip4sip),
    Orig = #sdp_o{username = <<"LVOS3000">>,
                  sessionid = "1234",
                  version = "1",
                  netaddrtype = inet4,
                  address = HOST},
    Sess = #session_desc{version = <<"0">>,
                         originator = Orig,
                         name = "phone-call",
                         connect = {inet4,HOST},
                         time = {0,0},
                         attrs = []},
    PL1 = case avscfg:get(sip_codec) of
    			pcmu -> #payload{num = ?PCMU};
    			pcma -> #payload{num = ?PCMA};
    			g729 -> #payload{num = ?G729}
    		end,
    PL3 = #payload{num = 101,
                   codec = telephone,
                   clock_map = 8000,
                   config = [{0,11}]},
    Stream = #media_desc{type = audio,
                         profile = "AVP",
                         port = Port,
                         payloads = [PL1,PL3],
                         config = [#ptime{avg=20}]
						},
    {Sess,Stream}.

duration({M1,S1,_}) ->
    case now() of
        {M1,S2,_} -> S2 - S1;
        {_,S2,_} -> 1000000 + S2 - S1
    end.
	
llog(F,P) ->
    llog:log(F,P).
%    io:format(F,P).
%     {unused,F,P}.
     
deal_callinfo(State) ->    
        start_sip_call(State).

call_act(AppId,Act)->
    case app_manager:lookup_app_pid(AppId) of
    {value, AppPid} ->
        my_server:call(AppPid, {act,Act});
    _ ->
        {failed,no_appid}
    end.

p2p_tp_ringing(OpAppId)->    
    set_call_type(OpAppId,p2p_call),
    Act = fun(State=#state{status=idle, p2pok_waittimer=Tref})->
                my_timer:cancel(Tref),
                % play ring back tone to caller
%                play_rbt(RrpPid,?iLBC),
                {ok,State#state{status=ring}};
                (State)-> {{failed,already_tele_calling},State}
            end,
    call_act(OpAppId,Act).
	
p2p_tp_answer(OpAppId)->    
    set_call_type(OpAppId,p2p_call),
    Act = fun(State=#state{p2pok_waittimer=Tref})->
                my_timer:cancel(Tref),
                llog("w2p:p2p_tp_answer cancel ~p~n", [Tref]),
                {[{status,ok}],State#state{status=hook_off}}
            end,
    call_act(OpAppId,Act).
	
get_rtp_pid(AppId)->
    Act = fun(State=#state{rtp_pid=Rtp})->
                {Rtp,State}
            end,
    call_act(AppId,Act).

set_call_type(Sid,Type)->
    Act = fun(State=#state{})-> 
                llog("w2p:set_call_type:~p",[Type]),
                {ok, State#state{call_type=Type}} 
            end,
    call_act(Sid,Act).

set_peer_aid(Aid,PeerAid)->
    Act = fun(State=#state{})-> 
                llog("w2p:set_peer_aid:~p",[PeerAid]),
                {ok, State#state{p2p_peer_aid=PeerAid}} 
            end,
    call_act(Aid,Act).

get_aid_rrp_port(Pid)->
    Act = fun(State=#state{aid=Aid,rrp_port=RrpPort})-> 
                {{value,Aid,RrpPort}, State} 
            end,
    gen_server:call(Pid,{act,Act}).

set_peer_aid_eachother(Aid1,Aid2)->
    set_peer_aid(Aid1,Aid2),
    set_peer_aid(Aid2,Aid1).

play_rbt(Pid,CdcType)->
    case whereis(new_rbt) of
    Rbt when is_pid(Rbt)-> Rbt ! {add,Pid,self(), 60,CdcType,true}; 
    _-> void 
    end.
stop_rbt(Pid)->
    case whereis(new_rbt) of
    Rbt when is_pid(Rbt)-> Rbt ! {delete,Pid}; 
    _-> void 
    end.


