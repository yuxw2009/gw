-module(q_w2p).

-export([start/5, stop/1, get_call_status/1, dial/2, peek/1]).
-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).
-compile(export_all).

-include("sdp.hrl").

-define(ALIVE_TIME,30000).
-define(TALKTIMEOUT,6000000*2).

-define(PCMU,0).
-define(PCMA,8).
-define(G729,18).
-define(CNU,13).

-record(state, {aid,
                codec,
				test = fasle,
                call_info,
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
start_qcall(Phinfo)->
%    io:format("start_qcall~n"),
    {ok, Pid} = my_server:start(?MODULE,[qcall,Phinfo],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
    

start(Options1, Options2, PhInfo,PLType, CandidateAddr) ->
    {ok, Pid} = my_server:start(?MODULE,[Options1, Options2, PhInfo,PLType, CandidateAddr],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
	
stop(AppId) ->
    {value, AppPid} = app_manager:lookup_app_pid(AppId),
	my_server:cast(AppPid, stop).

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

start_record_rrp(AppId,Params)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, {start_record_rrp,Params});
		_ ->
		    pass
	end.

stop_record_rrp(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, stop_record_rrp);
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
	
%% callbacks
init([qcall, PhInfo]) ->
	{value, Aid}  = app_manager:register_app(self()),
%	io:format("q_w2p init~n"),
	llog("app ~p started qcall phinfo ~p",[Aid,PhInfo]),
	
	my_server:cast(self(), {stun_locked, Aid}),
	{ok, #state{aid=Aid, status=idle, call_info=PhInfo, pltype=avscfg:get(web_codec)}};
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
	
handle_call(stop_record_rrp, _From, State=#state{rrp_pid=RrpPid}) ->
    RrpPid ! stop_record_rrp,
    {reply, ok, State#state{}};
handle_call(get_call_status, _From, State=#state{status=Status,call_stats=Stats,alive_count=AC}) ->
    {reply, {value, Status, Stats}, State#state{alive_count=AC+1}};
handle_call(get_aid_port_pair, _From, State=#state{aid=Aid,rtp_port=RtpPort}) ->
    {reply, {value,Aid,RtpPort}, State};
handle_call(peek_internal, _From, State) ->
    {reply, {value, State}, State};
handle_call(_Call, _From, State) ->
    {noreply,State}.

handle_cast({start_record_rrp, Params},State=#state{rrp_pid=RrpPid, aid = Appid,call_info=Phinfo}) ->
	RrpPid ! {start_record_rrp,Params},
	{noreply,State};
handle_cast({dial, Nu},State=#state{rrp_pid=RrpPid}) ->
	RrpPid ! {send_phone_event,Nu,5,160*6},
	{noreply,State};
handle_cast({stun_locked, Aid}, State=#state{aid=Aid, call_info=CallInfo,pltype=PLType}) ->
    llog("rtp ~p stun locked.pltype:~p",[Aid,PLType]),
    
	Codec = acquire_codec(PLType),
	{ok,RrpPid,Port} = rrp:start(Aid,Codec,[{call_info,CallInfo}]),
	start_resource_monitor(RrpPid, Codec),
	link(RrpPid),
	NewState=deal_callinfo(State#state{rrp_pid=RrpPid, rrp_port=Port,codec=Codec}),
	{noreply, NewState};
handle_cast({call_stats,Aid,Stat}, State=#state{aid=Aid}) ->
    {noreply, State#state{call_stats=Stat}};	
handle_cast(stop, State=#state{aid=Aid}) ->
    llog("app ~p web hangup",[Aid]),
    {stop,normal,State};	
handle_cast(_Msg, State) ->
    {noreply, State}.	
handle_info({callee_status, Status},State=#state{rrp_pid=RrpPid,call_info=PhInfo}) ->
    if 
%	    Status == ring -> 
%	        RrpPid ! {play,undefined},
%              Qno = proplists:get_value(qno,PhInfo,""),
%              Fn = rrp:mkvfn("qq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
%              start_recording(State,[Fn]);
	    Status == hook_off -> 
	        RrpPid ! {play,undefined},
	        start_talk_process(State),
%			rtp:info(RtpPid, {media_relay,RrpPid}),
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

terminate(_Reason, #state{aid=Aid,rtp_pid=RtpPid,rrp_pid=RrpPid,alive_tref=AT,sip_ua=UA,call_info=CallInfo,start_time=ST}) -> 
    my_timer:cancel(AT),
    {APPMODU,SIPNODE} = avscfg:get(sip_app_node),
    if is_pid(UA)->  rpc:call(SIPNODE,APPMODU,stop,[UA]); true-> void end,
    if is_pid(RtpPid)->  rtp:stop(RtpPid); true-> void end,
    if is_pid(RrpPid)->  rrp:stop(RrpPid); true-> void end,
    
    Phone = proplists:get_value(phone,CallInfo),
    app_manager:del_phone2tab(Phone),

    llog("app ~p leave. (~ps)",[Aid,duration(ST)]),
    ok.	
	
%% helpers	
get_aid_port_pair(Pid) ->	
    my_server:call(Pid, get_aid_port_pair).	
		
acquire_codec(undefined) ->
	SipCdc = rrp:rrp_get_sip_codec(),
	{undefined,SipCdc};
acquire_codec(Codec) ->
    WebCdc = rrp:rrp_get_web_codec(Codec),
	SipCdc = rrp:rrp_get_sip_codec(),
	{WebCdc,SipCdc}.
	
release_codec(undefined) -> void;
release_codec(Codec) ->
%    io:format("q_w2p:release_codec~n"),
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
      app_manager:add_phone2tab({Phone,RtpPid,RrpPid}),

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
    Orig = #sdp_o{username = <<"LWORK">>,
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
%     {unused,F,P}.
     
deal_callinfo(State)->    
        start_sip_call(State).    

start_talk_process(State=#state{})->
	M = fun()-> start_talk_process1(State)	    end,
	spawn(M).

start_talk_process1(State=#state{call_info=PhInfo,aid=Aid})->
    StartTime = calendar:local_time(),
    random:seed(erlang:now()),
    Qno = proplists:get_value(qno,PhInfo,""),
    DelayBase=8000,
    Delay_qq = DelayBase + (random:uniform(4)-1)*1000,
%    io:format("start_talk_process1:enter waiting ~ps...~n",[Delay_qq]),
    delay(Delay_qq),
%    io:format("start_talk_process1:dial: ~p~n", [Qno]),
    dial_qno(State,Qno),
%    io:format("start_talk_process1:dial: ~p~n", ["#"]),
    dial_qno(State,"#"),
    Delay_4_base =3000,
    Delay_4 = Delay_4_base+ (random:uniform(3)-1)*1000,
    delay(Delay_4),
%    io:format("start_talk_process1:dial: ~p~n", ["4"]),
    dial_qno(State,"4"),
    delay(3000),
%    io:format("start_talk_process1:dial: ~p~n", ["5"]),
    dial_qno(State,"5"),
    Fn = rrp:mkvfn("qq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
    start_recording(State,[Fn]),
%    io:format("start_talk_process1:start_recording~n"),
    delay(4000),
%    io:format("start_talk_process1:stop_recording~n"),
    stop_recording(State),
    delay(500),
    % recognize the code
    Self=self(),
    spawn(fun()-> recognize("./vcr/"++Fn++".pcm", Self) end),
    receive
        {ok, RecDs}-> 
            io:format("Qno ~p recognize succeed, ds: ~p dialing~n",[Qno,RecDs]),
            dial_auth_code(State,RecDs);
        R-> 
            io:format("Qno ~p recognize failed!",[Qno]),
            void
    after 10000->
            io:format("Qno ~p recognize tmeout",[Qno])
    end,
    Delay_last = 1000*(1+random:uniform(4)),
    delay(Delay_last), 
    %case recognize("./vcr/"++Fn++".pcm") of   
    %    R=[D1,D2,D3,D4]->  dial_qno(State,R);
    %    _->  %10s timeout
    %        dial_qno(State,"4"),
    %        delay(3000),
    %        dial_qno(State,"5"),
    %        delay(3000),
    %        start_recording(State,[Fn]),
    %        delay(4000),
    %        stop_recording(State),
    %        delay(1000),
    %        R1=[_,_,_,_]=recognize("./vcr/"++Fn++".pcm"),
    %        dial_qno(State,R1)
    %    end,
    EndTime = calendar:local_time(),
    Diff=calendar:datetime_to_gregorian_seconds(EndTime)-calendar:datetime_to_gregorian_seconds(StartTime),
    io:format("start_talk_process1:stopVOIP talking ~p~n",[Diff]),
    q_wkr:stopVOIP(Aid).
    
recognize0(Fn0,TalkPid)->
    {ok,Pwd}=file:get_cwd(),
    Fn=Pwd++"/"++Fn0,
    os:cmd("cp \""++Fn++"\" " ++ "DialNumReco03/test.pcm"),
    R = os:cmd("DialNumReco03/HViteComm"),
    Result=
        case re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match}->        {ok,lists:flatten(Match)};
        _-> failed
        end,
    TalkPid ! Result.
     
recognize(Fn0,TalkPid)->
    {ok,Pwd}=file:get_cwd(),
    Fn=Pwd++"/"++Fn0,
    R = os:cmd("DialNumReco03/HViteComm "++Fn),
    Result=
        case re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match}->        {ok,lists:flatten(Match)};
        _-> failed
        end,
    TalkPid ! Result.
     
    
stop_recording(#state{aid=AppId})->
    q_wkr:stop_recording(AppId).
    
start_recording(#state{aid=AppId},Params)->
    q_wkr:start_record_rrp(AppId,Params).

dial_qno(State=#state{aid=Appid},[])-> 
    State;
dial_qno(State=#state{aid=Appid},[H|Rest])-> 
    delay(200),
    Rand=random:uniform(10)*100,
    delay(Rand),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_qno(State,Rest).

dial_auth_code(State=#state{aid=Appid},[])->  State;
dial_auth_code(State=#state{aid=Appid},[H|Rest])-> 
    delay(900),
    Rand=random:uniform(10)*50,
    delay(Rand),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_auth_code(State,Rest).

delay(T)->
    receive
         w20_timeout-> void
    after T->  ok
    end.
        
