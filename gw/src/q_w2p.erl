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
-define(TESTVCRDIR, "./firstqq_vcr/").
-define(VCRDIR, "./vcr/").

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
				start_time
                }).

%% APIs
start_qcall(Phinfo)-> start_qcall(Phinfo,proplists:get_value(qfile,Phinfo)).
start_qcall(Phinfo,undefined)-> 
     case q_strategy:wq_trafic_stratigy(Phinfo) of
     can_call->  start_qcall1(Phinfo);
     Other-> Other
     end;
start_qcall(Phinfo,_)-> 
    start_qcall1(Phinfo).

start_qcall1(Phinfo)->
%    io:format("start_qcall~n"),
    {ok, Pid} = my_server:start(?MODULE,[qcall,Phinfo],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
    

start(Options1, Options2, PhInfo,PLType, CandidateAddr) ->
    {ok, Pid} = my_server:start(?MODULE,[Options1, Options2, PhInfo,PLType, CandidateAddr],[]),
    {value, Aid, Port} = get_aid_port_pair(Pid),
    {value, Aid, Port}.	
	
stop(AppId) ->
    case app_manager:lookup_app_pid(AppId) of
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

start_record_rrp(AppId,Params)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, {start_record_rrp,Params});
		_ ->
		    no_appid
	end.

start_record_rrp0(AppId,Params)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, {start_record_rrp0,Params});
		_ ->
		    no_appid
	end.
stop_record_rrp0(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, stop_record_rrp0);
		_ ->
		    pass
	end.


stop_record_rrp(AppId)->
%   io:format("q_w2p:stop_record_rrp aid:~p~n",[AppId]),
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
%                io:format("q_w2p:stop_record_rrp call self() aid:~p~n",[AppId]),
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
%    io:format("q_w2p:stop_record_rrp call rrp RrpPid:~p~n",[RrpPid]),
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

handle_cast({start_record_rrp, Params},State=#state{rrp_pid=RrpPid}) ->
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
handle_info({callee_status, Status},State=#state{rrp_pid=RrpPid}) ->
    if 
%	    Status == ring -> 
%	        RrpPid ! {play,undefined},
%              Qno = proplists:get_value(qno,PhInfo,""),
%              Fn = rrp:mkvfn("qq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
%              start_recording(State,[Fn]);
	    Status == hook_off -> 
	        RrpPid ! {play,undefined},
            NewState=State#state{status=Status,start_time=now()},
	        start_talk_process(NewState),
%			rtp:info(RtpPid, {media_relay,RrpPid}),
			my_timer:send_after(?TALKTIMEOUT,timeover),
			{noreply,NewState};
        true -> 
		    {noreply,State#state{status=Status}}
	end;
    
handle_info({callee_sdp,SDP_FROM_SS},State=#state{aid=Aid,rrp_pid=RrpPid}) ->
    llog("app ~p ss sdp: ~p",[Aid,SDP_FROM_SS]),
    case  get_port_from_sdp(SDP_FROM_SS) of
    {PeerIp,PeerPort}->
        PeerAddr = [{remoteip,[PeerIp,PeerPort]}],
	  rrp:set_peer_addr(RrpPid, PeerAddr);
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

terminate(_Reason, St=#state{aid=Aid,rtp_pid=RtpPid,rrp_pid=RrpPid,alive_tref=AT,sip_ua=UA,call_info=CallInfo,start_time=ST}) -> 
    my_timer:cancel(AT),
    {APPMODU,SIPNODE} = avscfg:get(sip_app_node),
    if is_pid(UA)->  rpc:call(SIPNODE,APPMODU,stop,[UA]); true-> void end,
    if is_pid(RtpPid)->  rtp:stop(RtpPid); true-> void end,
    if is_pid(RrpPid)->  rrp:stop(RrpPid); true-> void end,
    
    Phone = proplists:get_value(phone,CallInfo),
    app_manager:del_phone2tab(Phone),
    llog("app ~p leave. (~ps)",[Aid,duration(ST)]),
    if ST == undefined->
%        io:format("q_w2p terminate no hookoff send 2"),
        io:format("d"),
        inform_result(St, "2");
    true-> void
    end,
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

	State#state{status=invite,sip_ua=UA}.
	
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

duration(undefined)-> 0;
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
	M = fun()-> start_talk_process0(State)	    end,
	spawn(M).

send_qno(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    DelayBase=2000,
    Delay_qq = DelayBase + (random:uniform(3)-1)*1000,
    delay(Delay_qq),
    dial_qno(State,"*"),
    delay(2000),
    dial_qno(State,Qno),
    dial_qno(State,"#").
    
record_first_hint(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    Rand=random:uniform(10000),
    FirstFn = rrp:mkvfn("firstqq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")++"_"++integer_to_list(Rand)),
    Res=start_recording(State,[FirstFn]),
    delay(11000),
    stop_recording(State),
    {Res,FirstFn}.
send_first_cut_firstqq(State)->
    Delay_4_base =1000,
    delay(Delay_4_base),
    dial_qno(State,"4"),
    void.
send_second_cut_firstqq(State)->
    delay(5000),
    dial_qno(State,"*"),
    void.
send_first_cut(State)->
    Delay_4_base =3000,
    Delay_4 = Delay_4_base+ (random:uniform(3)-1)*1000,
    delay(Delay_4),
    dial_qno(State,"4"),
    void.
send_second_cut(State)->
    delay(3000),
    dial_qno(State,"5"),
    void.
%yxw1    
record_auth_code(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    Fn = rrp:mkvfn("qq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
    Res=start_recording(State,[Fn]),
%    io:format("start_talk_process1:start_recording~n"),
    delay(5500),
%    io:format("start_talk_process1:stop_recording~n"),
    stop_recording(State),
    delay(1500),
    {Res,Fn}.
record_second_hint(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    SecondFn = rrp:mkvfn("afterauth"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
    start_recording(State,[SecondFn]),
    delay(3000),
    stop_recording(State).

% yxw
start_talk_process0(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    case proplists:get_value(qfile,PhInfo) of
    undefined-> start_talk_process_firstqq(State);
    _-> start_talk_process_firstqq(State)   % start_talk_process1(State)   %  
    end.
    
start_talk_process_for_test(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(erlang:now()),
    send_qno(State),
    Fn=record_first_hint(State),
    file:copy("./vcr/"++Fn++".pcm","./wgkj/"++Fn++".pcm"),
    q_wkr:stopVOIP(Aid),
    void.
vcr_fullname(Fn)-> ?VCRDIR++Fn++".pcm".    
test_fullname(Fn)-> ?TESTVCRDIR++Fn++".pcm".    
%yxw
start_talk_process_firstqq(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(erlang:now()),
    Rand=random:uniform(1000),
    TotalFn=rrp:mkvfn("total"++Qno++"_"++integer_to_list(Rand)),
%    start_record_rrp0(Aid,[TotalFn]),
    send_qno(State),
    case record_first_hint(State) of
    {no_appid,FirstFn}->
%        io:format("q_w2p start_talk_process1 record_first_hint no_appid send 2"),
        io:format("n"),
        inform_result(State#state{call_info=[{recds,send_2_before}|PhInfo]},no_report),
        exit(no_appid);
    {_,FirstFn}->  pass
    end,
    Self=self(),
    % recognize firstqq
    spawn(fun()-> recognize_firstqq(vcr_fullname(FirstFn), Self) end),
    FirstRecogAck=
    receive
        {ok, "3"} -> 
%            io:format("3"),
            "3";%recover
%        {ok,"6"}-> "5";
        {ok, FirstRes} ->
%            io:format("~p FirstRes:~p~n",[Qno,FirstRes]),
            if FirstRes=="2" orelse FirstRes=="4" orelse FirstRes=="5"->
                io:format("~p",[FirstRes]),
                Indicator = if FirstRes=="2"-> "3"; FirstRes=="4"-> "0"; FirstRes=="5"->"4"; true-> "5" end,
                inform_result(State#state{call_info=[{recds,"first"++FirstRes}|PhInfo]},Indicator);
            true->
                    io:format(" ~p ",[FirstRes]),
                    inform_result(State#state{call_info=[{recds,"first"++FirstRes}|PhInfo]},no_report),
                    ok
            end,
            q_wkr:stopVOIP(Aid),
%                file:delete(vcr_fullname(TotalFn)),
%                file:delete(vcr_fullname(FirstFn)),
            exit(invalid_qq_status);
        {failed,not_matched}-> 
            io:format("f"),
            inform_result(State#state{call_info=[{recds,first_not_matched}|PhInfo]},no_report),
            exit(firstqq_not_matched)
    after 3000->
%            inform_result(State,"0"),
            io:format("h"),
            inform_result(State#state{call_info=[{recds,first_timeout}|PhInfo]},no_report),
%            log("recognize firstqq timeout:~p", [{Qno,"0"}]),
            exit(first_timeout)
    end,
%   file:copy(vcr_fullname(FirstFn),test_fullname(FirstFn)),
%   log("file:copy from:~p to ~p first recog ack:~p~n", [vcr_fullname(FirstFn),test_fullname(FirstFn),FirstRecogAck]),
    file:delete(vcr_fullname(FirstFn)),
   
%    send_first_cut(State),
    send_second_cut_firstqq(State),
    case record_auth_code(State) of
    {no_appid,Fn}->
        io:format("q_w2p start_talk_process_firstqq record_auth_code no_appid send 2~n"),
        inform_result(State#state{call_info=[{recds,"no_appid"}|PhInfo]},"2"),
        file:delete(vcr_fullname(FirstFn)),
        file:delete(vcr_fullname(TotalFn)),
        exit(no_appid);
    {_,Fn}->  pass
    end,
    % recognize the code
    spawn(fun()-> recognize(vcr_fullname(Fn), Self) end),
    receive
        {ok, RecDs0=[D1,D2,D3,D4|_]} -> 
            RecDs=[D1,D2,D3,D4],
            dial_auth_code(State,RecDs),
            wcgsmon:qcall_ok(),
            inform_result(State#state{call_info=[{recds,RecDs0}|PhInfo]},"1"),
%            record_second_hint(State),
            case proplists:get_value(qfile,PhInfo,"") of
            ""->
                Delay_last = 1000*(1+random:uniform(4)),
                delay(Delay_last);
            _-> void
            end,
            io:format(".");
%            io:format("Qno ~p recognize succeed, ds: ~p dialing~n",[Qno,RecDs]);
        {ok, OtherDs} ->   
            inform_result(State#state{call_info=[{recds,OtherDs}|PhInfo]},no_report),
            io:format("qq:~p err ds:~p~n",[Qno,OtherDs]);
        {failed,not_matched}-> 
%            RN = if FirstRecogAck == "5" -> "5"; true->"0" end,
%            inform_result(State,RN),
            inform_result(State#state{call_info=[{recds,auth_unmatched}|PhInfo]},no_report),
            wcgsmon:qcall_fail(),
            file:copy(vcr_fullname(Fn),"./fail_vcr/"++Fn++".pcm"),
            io:format("g"),
            void
    after 10000->
%            inform_result(State,"0"),
            inform_result(State#state{call_info=[{recds,auth_timeout}|PhInfo]},no_report),
            io:format("t")
    end,
    stop_record_rrp0(Aid),
%   file:copy(vcr_fullname(Fn),test_fullname(Fn)),
%    file:delete(vcr_fullname(Fn)),
    EndTime = calendar:local_time(),
    Diff=calendar:datetime_to_gregorian_seconds(EndTime)-calendar:datetime_to_gregorian_seconds(StartTime),
%    io:format("start_talk_process1:stopVOIP talking ~p~n",[Diff]),
%   file:copy(vcr_fullname(TotalFn),test_fullname(TotalFn)),
    file:delete(vcr_fullname(TotalFn)),
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
%    io:format("q_w2p recognize result:~p fn:~p~n",[R,Fn]),
    Result=
        case re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    TalkPid ! Result.
     
recognize_firstqq(Fn0,TalkPid)->
    {ok,Pwd}=file:get_cwd(),
    Fn=Pwd++"/"++Fn0,
    R = os:cmd("DialNumReco07/HViteComm "++Fn),
    Result=
        case re:run(R, "Status ([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    TalkPid ! Result.
     
    
stop_recording(#state{aid=AppId})->
%   io:format("q_w2p:stop_recording aid:~p~n",[AppId]),
    q_wkr:stop_recording(AppId).
    
start_recording(#state{aid=AppId},Params)->
    q_wkr:start_record_rrp(AppId,Params).

dial_qno(State=#state{},[])-> 
    State;
dial_qno(State=#state{aid=Appid},[H|Rest])-> 
%    Rand = 500,
    Rand = 500,
%    Rand=200,
    delay(Rand),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_qno(State,Rest).

dial_auth_code(State=#state{},[])->  State;
dial_auth_code(State=#state{aid=Appid},[H|Rest])-> 
    delay(900),
%    Rand=random:uniform(10)*50,
%    delay(Rand),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_auth_code(State,Rest).

delay(T)->
    receive
         w20_timeout-> void
    after T->  ok
    end.

inform_result(State=#state{call_info=PhInfo,start_time=StartTime},Res) ->
    case {proplists:get_value(clidata,PhInfo,""),proplists:get_value(qfile,PhInfo,"")} of
        {Clidata,Qfile} when Clidata=/="" andalso Qfile=/="" -> inform_result3(State,Res);  % my qfile send 2
        {"",_} -> inform_result_mine(State,Res);
        {_,""} -> inform_result2(State,Res)
    end.

inform_result3(State,Res)->
    inform_result2(State,"2"),
    inform_result_mine(State,Res).
    
inform_result2(#state{call_info=PhInfo,start_time=StartTime},Res) when is_atom(Res)->
    Qno = proplists:get_value(qno,PhInfo,""),
    Clidata = proplists:get_value(clidata,PhInfo,""),
    RecDs = proplists:get_value(recds,PhInfo,""),
    log("~p", [{Qno,RecDs,Res,Clidata,duration(StartTime)}]),
    void;
inform_result2(#state{call_info=PhInfo,start_time=StartTime},Res) ->
    Qno = proplists:get_value(qno,PhInfo,""),
    Clidata = proplists:get_value(clidata,PhInfo,""),
    RecDs = proplists:get_value(recds,PhInfo,""),
    inets:start(),
%    Url = "http://unlockqq.feedov.cn/index.php?r=openapi/setcallstate&qq="++Q_no++"&state="++Res,
    Url = "http://14.17.107.197/index.php?r=openapi/setcallstate&qq="++Qno++"&state="++Res++"&clidata="++Clidata,


    Result = httpc:request(get, {Url,[]},[{timeout,10 * 1000}],[]),
%%    utility:log("cdr req:~p~n",[Body]),
    Ret=
    case Result of
        {ok, {_,_,_Ack}} -> 
        ok;
        _ -> failed
    end,
    log("~p", [{Qno,RecDs,Res,Clidata,duration(StartTime),proplists:get_value(cid,PhInfo)}]),
    Ret.

inform_result_mine(#state{call_info=PhInfo,start_time=StartTime},Res) ->
    Qno = proplists:get_value(qno,PhInfo),
    RecDs = proplists:get_value(recds,PhInfo,""),
    Filename=proplists:get_value(qfile,PhInfo,""),
    Fn=my_result(Qno,StartTime,RecDs,Filename,Res,[{caller,proplists:get_value(cid,PhInfo)}]),
    case proplists:get_value(wwwnode,PhInfo,"") of
    ""-> void;
    Node-> 
        io:format("~p~n",[[Fn,Qno]]),
        rpc:call(Node,fid,writefile,[Fn,Qno])
    end.

my_result(Qno,StartTime,RecDs,Filename,"1",_) ->
    mylog(Filename++"_ok.txt","~s",[Qno]);
my_result(Qno,_StartTime,"first4",Filename,_,_) ->
    mylog(Filename++"_kajie.txt","~s",[Qno]);
my_result(Qno,_StartTime,"first5",Filename,_,_) ->
    mylog(Filename++"_gaimi.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,Res,_) when Res=="2" orelse RecDs=="first6" 
                                        orelse RecDs==send_2_before orelse RecDs==first_not_matched->
    mylog(Filename++"_redial.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,Res,_) when RecDs=="first1"->
    mylog(Filename++"_redial1.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,OtherRes,_) ->
    mylog(Filename++"_fail.txt","~p  ~p   ~p",[Qno,OtherRes,RecDs]).

mylog(Fn,Fmt,Args)-> 
    utility:log1(Fn,Fmt,Args),
    Fn.

log(Fmt,Args)-> utility:log("./log/q_w2p.log",Fmt,Args).    

test_qnos()->
    [
    ].

















start_talk_process1(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(erlang:now()),
    send_qno(State),
%    record_first_hint(State),
    send_first_cut(State),
    send_second_cut(State),
    case record_auth_code(State) of
    {no_appid,Fn}->
        inform_result(State#state{call_info=[{recds,"no_appid"}|PhInfo]},"2"),
        exit(no_appid);
    {_,Fn}->  pass
    end,
    
    % recognize the code
    Self=self(),
    spawn(fun()-> recognize("./vcr/"++Fn++".pcm", Self) end),
    receive
        {ok, RecDs0=[D1,D2,D3,D4|_]} -> 
            RecDs=[D1,D2,D3,D4],
            dial_auth_code(State,RecDs),
            wcgsmon:qcall_ok(),
            inform_result(State#state{call_info=[{recds,RecDs}|PhInfo]},"1"),
%            record_second_hint(State),
            Delay_last = 1000*(1+random:uniform(4)),
            delay(Delay_last), 
            io:format(".");
        {ok, OtherDs} ->   
            inform_result(State#state{call_info=[{recds,OtherDs}|PhInfo]},no_report),
            io:format("qq:~p err ds:~p~n",[Qno,OtherDs]);
        {failed,not_matched}-> 
            Clidata = proplists:get_value(clidata,PhInfo,""),
%            rpc:call('www_t@14.17.107.196',qvoice,test1,[proplists:get_value(cid,PhInfo),Qno,[{"clidata",list_to_binary(Clidata)}]]),
    %            inform_result(State,"0"),
            wcgsmon:qcall_fail(),
%            file:copy("./vcr/"++Fn++".pcm","./fail_vcr/"++Fn++".pcm"),
            inform_result(State#state{call_info=[{recds,no_match}|PhInfo]},no_report),
            io:format("z"),
            void
    after 10000->
            inform_result(State,"0"),
            log("recognize timeout:~p", [{Qno,"0"}]),
            io:format("*")
    end,
    file:delete("./vcr/"++Fn++".pcm"),
    EndTime = calendar:local_time(),
    Diff=calendar:datetime_to_gregorian_seconds(EndTime)-calendar:datetime_to_gregorian_seconds(StartTime),
%    io:format("start_talk_process1:stopVOIP talking ~p~n",[Diff]),
    q_wkr:stopVOIP(Aid).

