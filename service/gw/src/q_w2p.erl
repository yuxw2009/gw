-module(q_w2p).

-export([start/5, stop/1, get_call_status/1, dial/2, peek/1]).
-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).
-compile(export_all).

-include("sdp.hrl").

-define(ALIVE_TIME,30000).
-define(TALKTIMEOUT,60*1000).

-define(PCMU,0).
-define(PCMA,8).
-define(G729,18).
-define(CNU,13).
-define(TESTVCRDIR, "./firstqq_vcr/").
-define(VCRDIR, (vcr:vcr_path())).


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
start_qcall(Phinfo)-> 
    Random=random:uniform(100),
    Phinfo1=
    case {avscfg:get(custom),Random} of
    {sb,_} when Random<0-> 
        TalkT=q_strategy:rand([22000,20000,21000,23000]),
        [{disconnect_time,TalkT}|Phinfo];
    _->
        Phinfo
    end,
    start_qcall(Phinfo1,proplists:get_value(qfile,Phinfo)).
start_qcall(Phinfo,undefined)-> 
     case q_strategy:wq_trafic_stratigy(Phinfo) of
     can_call->  start_qcall1(Phinfo);
     {failure, transfer_mine}-> pass;
     {fake_call,Phinfo1}-> start_qcall1(Phinfo1);
     Other-> 
         inform_result(#state{call_info=Phinfo}, "7"),
         Other
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
                 utility:my_print("q_w2p cast dial ~p~n",[Num]),
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

start_record_rrp1(AppId,Params)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:cast(AppPid, {start_record_rrp1,Params});
		_ ->
		    no_appid
	end.
stop_record_rrp1(AppId)->
    case app_manager:lookup_app_pid(AppId) of
	    {value, AppPid} ->
		    my_server:call(AppPid, stop_record_rrp1);
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
	utility:my_print("q_w2p send DTMF ~p to rrp~n",[Nu]),
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
handle_info({callee_status, Status},State=#state{rrp_pid=RrpPid,call_info=Phinfo}) ->
    if 
%	    Status == ring -> 
%	        RrpPid ! {play,undefined},
%              Qno = proplists:get_value(qno,PhInfo,""),
%              Fn = rrp:mkvfn("qq"++Qno++"_"++proplists:get_value(cid,PhInfo,"")),
%              start_recording(State,[Fn]);
        Status == hook_off -> 
            RrpPid ! {play,undefined},
            NewState=State#state{status=Status,start_time=os:timestamp()},
            start_talk_process(NewState),
            %			rtp:info(RtpPid, {media_relay,RrpPid}),
            MaxTime=proplists:get_value(disconnect_time,Phinfo,?TALKTIMEOUT),
            my_timer:send_after(MaxTime,timeover),
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
handle_info({'DOWN', _Ref, process, UA, _Reason},State=#state{aid=Aid,sip_ua=UA,start_time=Starttime})->
%    io:format("app ~p sip hangup(~ps)~n",[Aid,duration(Starttime)]),
	{stop, normal, State};
handle_info(timeover,State=#state{aid=Aid,sip_ua=UA}) ->
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
    if ST=/=undefined-> io:format(" (~ps) ",[duration(ST)]); true-> void end,
    Qfile=proplists:get_value(qfile,CallInfo),
    if ST == undefined andalso (Qfile==undefined orelse Qfile=="") ->
%        io:format("q_w2p terminate no hookoff send 2"),
        io:format("d"),
        inform_result(St, "7");
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
	State#state{start_time=os:timestamp(),status=hook_off};
start_sip_call(State=#state{test=true, rtp_pid=RtpPid, rrp_port=RrpPort, rrp_pid=RrpPid}) ->
    PeerAddr = [{remoteip,[avscfg:get(sip_socket_ip),RrpPort]}],
	ok = rrp:set_peer_addr(RrpPid, PeerAddr),
	rtp:info(RtpPid, {media_relay,RrpPid}),
	State#state{start_time=os:timestamp(),status=hook_off};
start_sip_call(State=#state{aid=Aid, call_info=CallInfo, rtp_pid=RtpPid, rrp_port=RrpPort, rrp_pid=RrpPid}) ->
	{APPMODU,SIPNODE} = avscfg:get(sip_app_node),
	SDP_TO_SS = get_local_sdp(RrpPort),
	UA = rpc:call(SIPNODE,APPMODU,start_with_sdp,[self(),CallInfo, SDP_TO_SS]),
    _Ref = erlang:monitor(process,UA),
    llog("gw ~p port ~p call ~p sdp_to_ss ~p~n", [Aid,RrpPort,CallInfo,SDP_TO_SS]),
      Phone = proplists:get_value(cid,CallInfo),

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
    Orig = #sdp_o{username = <<"VOS2000">>,
                  sessionid = "2688",
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
    case os:timestamp() of
        {M1,S2,_} -> S2 - S1;
        {_,S2,_} -> 1000000 + S2 - S1
    end.
	
llog(F,P) ->
%    llog:log(F,P).
     {unused,F,P}.
     
deal_callinfo(State)->    
        start_sip_call(State).    

start_talk_process(State=#state{})->
	M = fun()-> start_talk_process0(State)	    end,
	spawn(M).

send_qno(State=#state{call_info=PhInfo})->
    Qno = proplists:get_value(qno,PhInfo,""),
    DelayBase=1500,
    Delay_qq = DelayBase,% + (random:uniform(3)-1)*1000,
    delay(Delay_qq),
    dial_qno(State,"22"),
    delay(Delay_qq),
    dial_qno(State,"22"),
%    delay(2000),
    delay(DelayBase),

    dial_qno(State,Qno),
    dial_qno(State,"#"),
    %because dialing too quick, avoid recording incorrect ahead tone.
%    case proplists:get_value(qfile,PhInfo,"") of
%    ""-> delay(100);
%    R->
%        my_print("qfile:~p",[R]),
%        delay(2000)    
%    end,
    ok.

async(Fun,Owner)-> 
    spawn(fun()-> Owner ! Fun() end).
a_record_first_hint(State)->
    {first_record, record_first_hint(State)}.
record_first_hint(State=#state{call_info=PhInfo,rrp_pid=RrpPid})->
    my_print("start recording first hint...",[]),
    Qno = proplists:get_value(qno,PhInfo,""),
    Rand=random:uniform(10000),
    FirstFn = rrp:mkvfn(Qno++"_"++"firstqq"++proplists:get_value(cid,PhInfo,"")++"_"++integer_to_list(Rand)),
%    Res=start_recording(State,[FirstFn]),
    Res=send2rrp(RrpPid,{start_record_rrp,[FirstFn]}),
    delay(11000),
    stop_recording(State),
    my_print("end recording first hint...",[]),
    {Res,FirstFn}.
a_record_new_authcode_hint(State,Owner)-> a_record_new_authcode_hint(State,Owner,9500).
a_record_new_authcode_hint(State,Owner,Delay_ms)->
    delay(Delay_ms),
%    delay(1000),
%     dial_qno(State,"*"),
    Owner ! {authcode_record, record_new_authcode_hint(State,Owner)}.
record_new_authcode_hint(State=#state{call_info=PhInfo,rrp_pid=RrpPid},Owner)->  
    Qno = proplists:get_value(qno,PhInfo,""),
    Rand=random:uniform(10000),
    Fn = rrp:mkvfn("code"++Qno++"_"++proplists:get_value(cid,PhInfo,"")++"_"++integer_to_list(Rand)),
    Res=send2rrp(RrpPid,{start_record_rrp1,[Fn]}),
    if Res=/=no_appid->
%        delay(6000),
%        recognize_ahead(vcr_fullname(Fn),Owner),
%        delay(2000),
%        recognize_ahead(vcr_fullname(Fn),Owner),
%        delay(3000),   % from 7s to 8s, sometimes tx delay to play tone
%        recognize_ahead(vcr_fullname(Fn),Owner),
        HeadFn=Fn++"Head",
        send2rrp(RrpPid,{start_record_rrp,[HeadFn]}),
        delay(3700),%delay(4500),
        stop_recording(State),
        recognize_authhead(vcr_fullname(HeadFn),Owner),
        delay(7300),%delay(6500),
        send2rrp(RrpPid,stop_record_rrp1);
        pass;
    true-> 
        delay(5000)
    end,
    {Res,Fn}.   

send2rrp(RrpPid,Evt)->
    case {is_pid(RrpPid),is_process_alive(RrpPid)} of
               {true,true}->    RrpPid ! Evt;
               _-> no_appid
           end.
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
    Qfile=proplists:get_value(qfile,PhInfo),
%    io:format("start_talk_process0 qfile:~p~n",[Qfile]),
    case {Qfile,avscfg:get(custom)} of
    {R,_Custom}  when R==undefined orelse R=="" -> start_talk_process_newauth(State);%start_talk_process_qtest_no_auth(State);%
    _-> start_talk_process_no_first(State)%start_talk_process_qtest1_no_auth(State) %
    end.
    
start_talk_process_for_test(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(os:timestamp()),
    send_qno(State),
    Fn=record_first_hint(State),
    file:copy("./vcr/"++Fn++".pcm","./wgkj/"++Fn++".pcm"),
    q_wkr:stopVOIP(Aid),
    void.
vcr_fullname(Fn)-> vcr_fullname(Fn,".pcm").    
vcr_fullname(Fn,Ext)-> ?VCRDIR++Fn++Ext.    
test_fullname(Fn)-> ?TESTVCRDIR++Fn++".pcm".    
delay_after_dial_auth(State=#state{call_info=PhInfo,rrp_pid=RrpPid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    Rand=random:uniform(10000),
    Fn = rrp:mkvfn("after"++Qno++"_"++proplists:get_value(cid,PhInfo,"")++"_"++integer_to_list(Rand)),
    send2rrp(RrpPid,{start_record_rrp1,[Fn]}),
    delay(3500),
%    stop_recording(State),
    {recognize_after(vcr_fullname(Fn), self()),Fn};
delay_after_dial_auth(#state{call_info=PhInfo})->
    Delay_last=
        case proplists:get_value(qfile,PhInfo,"") of
        ""-> 
            100*(10+random:uniform(5));
        _-> 100*(20+random:uniform(5))
        end,
    delay(Delay_last),
    "1".
%yxw    
start_talk_process_qtest_no_auth(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(os:timestamp()),
    send_qno(State),
    delay(10000),
    inform_result(State#state{call_info=[{recds,"start_talk_process_newauth_no_auth"}|PhInfo]},"1"),
    q_wkr:stopVOIP(Aid).
    
start_talk_process_qtest1_no_auth(State=#state{call_info=PhInfo,aid=Aid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(os:timestamp()),
    send_qno(State),
    %cut the first qq tone
%    io:format("cut firstqq tone~n"),
% for no authcode
    delay(1500),
    F=fun()-> 
           delay(500),
           dial_qno(State,integer_to_list(random:uniform(9)))
       end,
    [F()|| _<-lists:seq(1,15)],
    inform_result(State#state{call_info=[{recds,"qtest1"}|PhInfo]},"1"),
    q_wkr:stopVOIP(Aid).
    
    
start_talk_process_newauth(State=#state{call_info=PhInfo,aid=Aid,start_time=StartT})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(os:timestamp()),
    Rand=random:uniform(1000),
    send_qno(State),
    Self=self(),
    async(fun()-> a_record_new_authcode_hint(State,Self) end,Self),
    case record_first_hint(State) of
    {no_appid,FirstFn}->
%        io:format("q_w2p start_talk_process1 record_first_hint no_appid send 2"),
        io:format(" n ",[]),
        inform_result(State#state{call_info=[{recds,send_2_before}|PhInfo]},"7"),
        q_wkr:stopVOIP(Aid),
        exit(no_appid);
    {_,FirstFn}->  pass
    end,
    % recognize firstqq
%        io:format("n8888888888888888888888888888888888888888888888888888888888~n"),
    spawn(fun()-> recognize_firstqq(vcr_fullname(FirstFn), Self) end),
    FirstRecogAck=
    receive
        {ok, D3or4} when D3or4=="3" orelse D3or4=="7"-> 
              %io:format("~p",[D3or4]),
              receive
                {recognize_authhead,false}->
                    inform_result(State#state{call_info=[{recds,"recognize_authhead_false"}|PhInfo]},"0"),
                    io:format("recognize_authhead false exit~n");
              {authcode_record,{no_appid,Fn}}->
                  io:format("q_w2p start_talk_process_firstqq record_auth_code no_appid send 7~n"),
                  inform_result(State#state{call_info=[{recds,"no_appid"}|PhInfo]},"7"),
                  file:delete(vcr_fullname(FirstFn)),
                  q_wkr:stopVOIP(Aid),
                  exit(no_appid);
              {authcode_record,{_,Fn}}-> 
                   spawn(fun()-> recognize(vcr_fullname(Fn), Self) end),
                   receive
                       {ok, RecDs0=[D1,D2,D3,D4,D5,D6|_]} -> 
                           RecDs=[D1,D2,D3,D4,D5,D6],
                           dial_auth_code(State,RecDs),
                           {Res_,AfterFn}= delay_after_dial_auth(State),
                            io:format("aftercode res ~p",[Res_]),
                           delay(10000),
                           if Res_=="7"->
                                case recognize(vcr_fullname(AfterFn), Self) of
                                    {ok, NRecDs0=[ND1,ND2,ND3,ND4,ND5,ND6|_]} -> 
                                        NRecDs=[ND1,ND2,ND3,ND4,ND5,ND6],
                                        dial_auth_code(State,NRecDs),
                                        {NRes_,NAfterFn}= delay_after_dial_auth(State),
                                        io:format("again result:~p~n",[NRes_]),
                                        inform_result(State#state{call_info=[{recds,"again"++NRecDs0++"_"++NRes_}|PhInfo]},NRes_);
                                    _-> inform_result(State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_)
                                end;
                            true->
                                inform_result(State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_)
                            end;
%                           io:format("(.~p.)",[RecDs0]);
                       {ok, RecDs} when D3or4=="7"->     % tx bug
                           dial_auth_code(State,RecDs++"#"),
                           delay_after_dial_auth(State),
                           inform_result(State#state{call_info=[{recds,RecDs}|PhInfo]},"1"),
                           io:format("*~p*",[RecDs]);
                       {ok, OtherDs} ->   
                           inform_result(State#state{call_info=[{recds,OtherDs}|PhInfo]},"7"),
                           io:format("qq:~p err ds:~p~n",[Qno,OtherDs]);
                       {failed,not_matched}-> 
               %            RN = if FirstRecogAck == "5" -> "5"; true->"0" end,
               %            inform_result(State,RN),
                           inform_result(State#state{call_info=[{recds,"auth_unmatched"++"first"++D3or4}|PhInfo]},"0"),
                           wcgsmon:qcall_fail(),
                           %file:copy(vcr_fullname(Fn),"./fail_vcr/"++Fn++".pcm"),
                           io:format("g"),
                           void
                   after 10000->
               %            inform_result(State,"0"),
                           inform_result(State#state{call_info=[{recds,auth_timeout}|PhInfo]},no_report),
                           io:format("t")
                   end,
                   [file:delete(vcr_fullname(Fn)++I)||I<-["1","2","3","4","5","6"]]
              after 11000->
                  io:format("k")
              end;
%        {ok,"6"}-> "5";
        {ok, FirstRes} ->
            q_wkr:stopVOIP(Aid),
            if FirstRes=="2" orelse FirstRes=="4" orelse FirstRes=="5"->
                io:format("~p",[FirstRes]),
                Indicator = if FirstRes=="2"-> "3"; FirstRes=="4"-> "0"; FirstRes=="5"->"4"; true-> "5" end,
                inform_result(State#state{call_info=[{recds,"first"++FirstRes}|PhInfo]},Indicator);
            true->  % first is 6
                    io:format(" ~p ",[FirstRes]),
                    DiscTime=proplists:get_value(disconnect_time,PhInfo),
%                    Result6= if DiscTime=/=undefined-> io:format(" ^ "), "7"; true-> no_report end,
%                    Result6="7",
                    Result6="7",
                    delay(2000),
                    inform_result(State#state{call_info=[{recds,"first"++FirstRes}|PhInfo]},Result6),
                    ok
            end,
%            file:copy(vcr_fullname(FirstFn),"./firstqq_not7/"++FirstFn++".pcm");
            ok;
        {failed,not_matched}-> 
            io:format("f"),
            inform_result(State#state{call_info=[{recds,first_not_matched}|PhInfo]},no_report),
            failed
            %file:copy(vcr_fullname(FirstFn),"./firstqq_not7/"++FirstFn++".pcm")
    after 3000->
            q_wkr:stopVOIP(Aid),
            io:format("h"),
            inform_result(State#state{call_info=[{recds,first_timeout}|PhInfo]},no_report),
            exit(first_timeout)
    end,
    q_wkr:stopVOIP(Aid),
%    file:delete(vcr_fullname(FirstFn)),
    file:delete(vcr_fullname(FirstFn,".rec")),
   
%    send_second_cut_firstqq(State),
% record authcode result
    % recognize the code
%    stop_record_rrp0(Aid),
%   file:copy(vcr_fullname(Fn),test_fullname(Fn)),
%    file:delete(vcr_fullname(Fn)),
    EndTime = calendar:local_time(),
    Diff=calendar:datetime_to_gregorian_seconds(EndTime)-calendar:datetime_to_gregorian_seconds(StartTime),
    io:format(" ~ps ",[Diff]),
    ok.

judge_if_normal_by_rrp(State=#state{rrp_pid=RrpPid},Owner)->
    case is_pid(RrpPid) andalso is_process_alive(RrpPid) of
    true-> 
        delay(3000),
        case is_process_alive(RrpPid) of true-> ok; _-> Owner ! rrp_is_down end;    
    _-> void
    end.
%yxw
start_talk_process_no_first(State=#state{call_info=PhInfo,aid=Aid,rrp_pid=RrpPid})->
    Qno = proplists:get_value(qno,PhInfo,""),
    StartTime = calendar:local_time(),
    random:seed(os:timestamp()),
    send_qno(State),
    %cut the first qq tone
%    io:format("cut firstqq tone~n"),
    delay(3000),
    dial_qno(State,"**"),
    Self=self(),
%    case avscfg:get(custom) of sb-> void; true->  spawn(fun()-> judge_if_normal_by_rrp(State,Self) end) end,
%    spawn(fun()-> judge_if_normal_by_rrp(State,Self) end),
    async(fun()-> a_record_new_authcode_hint(State,Self,500) end,Self),
    {NewState,Res}=
    receive
    {recognize_authhead,false}->
        io:format("recognize_authhead false exit~n"),
        {State#state{call_info=[{recds,"recognize_authhead_false"}|PhInfo]},"0"};
%    rrp_is_down-> 
%        io:format("@"),
%        {State#state{call_info=[{recds,"rrp_is_down"}|PhInfo]},"1"};
    {authcode_record,{no_appid,Fn}}->
%        io:format("q_w2p start_talk_process_firstqq record_auth_code no_appid send 2~n"),
        {State#state{call_info=[{recds,"no_appid_perhaps_ok"}|PhInfo]},"7"};
    {authcode_record,{_,Fn}}-> 
        spawn(fun()-> recognize(vcr_fullname(Fn), Self) end),
        receive
           {ok, RecDs0=[D1,D2,D3,D4,D5,D6|_]} -> 
               RecDs=[D1,D2,D3,D4,D5,D6],
%	       case avscfg:get(custom) of sb-> delay(5000); true-> void end,
                dial_auth_code(State,RecDs),
                {Res_,AfterFn}= delay_after_dial_auth(State),
               ToSbRes_=case proplists:get_value(clidata,PhInfo,"")  of  {Clidata_sb,Qno_sb,"0"}-> "0"; _-> "7" end,
               if Res_=="7" andalso ToSbRes_=/="0"->
                    io:format("errcode~p again: ",[RecDs]),
                    delay(11000),
                    case recognize(vcr_fullname(AfterFn), Self) of
                        {ok, NRecDs0=[ND1,ND2,ND3,ND4,ND5,ND6|_]} -> 
                            NRecDs=[ND1,ND2,ND3,ND4,ND5,ND6],
                            dial_auth_code(State,NRecDs),
                            {NRes_,NAfterFn}= delay_after_dial_auth(State),
                            q_wkr:stopVOIP(Aid),
                            io:format("again result:~p ds:~p~n",[NRes_,NRecDs]),
%                            delay(1000),
                            {State#state{call_info=[{recds,"again"++NRecDs0++"_"++NRes_}|PhInfo]},NRes_};
                        _-> 
                            io:format("~nagainfailed~n"),
                            {State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_}
                    end;
                true->
                    send2rrp(RrpPid,stop_record_rrp1),
                    q_wkr:stopVOIP(Aid),
                    case avscfg:get(custom) of
                    sb-> 
                        Random_=random:uniform(100),
                        Delay4sb= if Random_<70-> 10; true-> 16000+Random_*100 end,
                        io:format(" ~p delay~p ",[Res_,Delay4sb]),
                        io:format(" ~p ",[Res_]),
                        delay(Delay4sb);
                    _-> io:format(" ~p ",[Res_])
                    end,
                    {State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_}
                end;
           {failed,not_matched}-> 
               io:format("g"),
               RecDs0="888888",
               delay(6000),
               dial_auth_code(State,RecDs0),
               {Res_,AfterFn}= delay_after_dial_auth(State),
               if Res_=="7"->
                    io:format("aftercode again: "),
                    delay(10000),
                    case recognize(vcr_fullname(AfterFn), Self) of
                        {ok, NRecDs0=[ND1,ND2,ND3,ND4,ND5,ND6|_]} -> 
                            NRecDs=[ND1,ND2,ND3,ND4,ND5,ND6],
                            dial_auth_code(State,NRecDs),
                            {NRes_,NAfterFn}= delay_after_dial_auth(State),
                            io:format("g_again result:~p~n",[NRes_]),
                            {State#state{call_info=[{recds,"g_again"++NRecDs0++"_"++NRes_}|PhInfo]},NRes_};
                        _-> {State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_}
                    end;
                true->
                    {State#state{call_info=[{recds,RecDs0++"_"++Res_}|PhInfo]},Res_}
                end
        after 3000->
               io:format("t"),
               {State#state{call_info=[{recds,auth_timeout}|PhInfo]},no_report}
        end
    after 15000->
      io:format("k"),
     {State#state{call_info=[{recds,auth_timeout}|PhInfo]},no_report}
    end,
%    delay(15000),
    q_wkr:stopVOIP(Aid),
    inform_result(NewState,Res),
    EndTime = calendar:local_time(),
    Diff=calendar:datetime_to_gregorian_seconds(EndTime)-calendar:datetime_to_gregorian_seconds(StartTime),
%    io:format(" ~ps ~n",[Diff]),
    ok.
    
recognize_ahead(Fn0,TalkPid)->
%    {ok,Pwd}=file:get_cwd(),
    Fn=Fn0,
    R = os:cmd("DialNumReco03/HViteComm "++Fn),
%    io:format("q_w2p recognize result:~p fn:~p~n",[R,Fn]),
    Result=
        case {re:run(R, "d([0-9])\nd([0-9])\n(multi|add)", [global,{capture,all_but_first,list}]),re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}])} of
        {{match,[[Str1,Str2,"multi"]]},_}->        {ok,integer_to_list(list_to_integer(Str1)*list_to_integer(Str2))};
        {{match,[[Str1,Str2,"add"]]},_}->        {ok,integer_to_list(list_to_integer(Str1)+list_to_integer(Str2))};
        {_,{match,Match=[_,_,_,_|_]}}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    case Result of
    {ok,AuthCode}-> 
        my_print("auth_reco_result:~p",[Result]),
        TalkPid ! {ahead_authcode,AuthCode};
    _-> void
    end.

recognize_authhead(Fn,TalkPid)->
    CmdStr= avscfg:get_regco()++"/HViteHead "++Fn,
    R = os:cmd(CmdStr),
%    io:format("q_w2p recognize_authhead result:~p fn:~p~n",[R,Fn]),
%    case re:run(R,"QING.*\n.*SHU.*\n.*RU.*\n.*YI\.*\n.*XIA.*\n.*LIU.*\n.*WEI.*\n.*YAN.*\n.*ZHENG.*\n.*MA.*\n") of
    case re:run(R,".*YI\.*\n.*XIA.*\n.*LIU.*\n") of
    {match,_}->  
        TalkPid ! {recognize_authhead,true},
        true;
    _-> 
        TalkPid ! {recognize_authhead,false},
        false
    end.
recognize_after(Fn,TalkPid)->
    CmdStr= avscfg:get_regco()++"/HViteHead "++Fn,
%    CmdStr= "/yyy/yyy/qtest2/applications/music_back/UnixReco/HViteHead "++Fn,

    R = os:cmd(CmdStr),
%    io:format("q_w2p recognize_after result:~p fn:~p~n",[R,Fn]),
%    case re:run(R,"XIAN.*\n.*YI.*\n.*WEI.*\n.*NIN.*\n.*ZHANG.*\n.*HAO.*\n") of
    case re:run(R,".*YI.*\n.*WEI.*\n.*NIN.*\n") of
    {match,_}->  "1";
    _-> "7"
    end.
% new tone    reco
recognize(Fn0,TalkPid)->
%    {ok,Pwd}=file:get_cwd(),
    Fn=Fn0,
    CmdStr= avscfg:get_regco()++"/HViteComm "++Fn,
    R = os:cmd(CmdStr),
%    io:format("q_w2p recognize result:~p fn:~p~n",[R,Fn]),
    Result=
        case re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match=[_,_,_,_,_,_|_]}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    my_print("auth_reco_result:~p",[Result]),
    TalkPid ! Result.
recognize0(Fn0,TalkPid)->
%    {ok,Pwd}=file:get_cwd(),
    Fn=Fn0,
    R = os:cmd("DialNumReco03/HViteComm "++Fn),
%    io:format("q_w2p recognize result:~p fn:~p~n",[R,Fn]),
    Result=
        case {re:run(R, "d([0-9])\nd([0-9])\n(multi|add)", [global,{capture,all_but_first,list}]),re:run(R, "d([0-9])\n", [global,{capture,all_but_first,list}])} of
        {{match,[[Str1,Str2,"multi"]]},_}->        {ok,integer_to_list(list_to_integer(Str1)*list_to_integer(Str2))};
        {{match,[[Str1,Str2,"add"]]},_}->        {ok,integer_to_list(list_to_integer(Str1)+list_to_integer(Str2))};
        {_,{match,Match=[_,_,_,_|_]}}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    my_print("auth_reco_result:~p",[Result]),
    TalkPid ! Result.
    
recognize_firstqq(Fn0,TalkPid)->
%    {ok,Pwd}=file:get_cwd(),
    Fn=Fn0,
    R = os:cmd("DialNumReco07/HViteComm "++Fn),
    Result=
        case re:run(R, "Status ([0-9])\n", [global,{capture,all_but_first,list}]) of
        {match,Match}->        {ok,lists:flatten(Match)};
        _-> {failed,not_matched}
        end,
    %io:format("recognize_firstqq:res ~p~n",[Result]),
    TalkPid ! Result.
     
    
stop_recording(#state{aid=AppId})->
%   io:format("q_w2p:stop_recording aid:~p~n",[AppId]),
    q_wkr:stop_recording(AppId).
    
start_recording(#state{aid=AppId},Params)->
    q_wkr:start_record_rrp(AppId,Params).

dial_qno(State=#state{},[])-> 
    State;
dial_qno(State=#state{call_info=PhInfo,aid=Appid},[H|Rest])-> 
    case {proplists:get_value(qfile,PhInfo,""), avscfg:get(custom)} of
    {Qfile,Custom} when Qfile=="" orelse Custom==sb->    
        Rand=random:uniform(600),
%        delay(Rand);
        delay(1000);
    _-> 
%        delay(20+random:uniform(30))
        delay(20)
    end,
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_qno(State,Rest).

dial_auth_code(State=#state{call_info=PhInfo,rrp_pid=RrpPid},[])->  
%    delay(500),
%    Qno = proplists:get_value(qno,PhInfo,""),
%    Rand=random:uniform(10000),
%    Fn = rrp:mkvfn("aftercode"++Qno++"_"++proplists:get_value(cid,PhInfo,"")++"_"++integer_to_list(Rand)),
%    Res=send2rrp(RrpPid,{start_record_rrp1,[Fn]}),
    State;
dial_auth_code(State=#state{aid=Appid,call_info=PhInfo},[H|Rest])-> 
    case proplists:get_value(qfile,PhInfo,"") of
    ""->    
        Rand=random:uniform(300),
        delay(100+Rand);  % must > 900, if 500 can't jf
    _-> delay(30)
    end,
    my_print("q_w2p dial auth:~p",[H]),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_auth_code(State,Rest).

dial_nos(Appid,[],Interval)-> void;
dial_nos(Appid,[H|T],Interval)->
    delay(Interval),  % must > 900, if 500 can't jf
%    Rand=random:uniform(10)*50,
%    delay(Rand),
    my_print("q_w2p dial auth:~p",[H]),
    q_wkr:eventVOIP(Appid, {dial,H}),
    dial_nos(Appid,T,Interval).
    
delay(T)->
    timer:sleep(T).

inform_result(State=#state{call_info=PhInfo,start_time=StartTime},Res) ->
    case {proplists:get_value(clidata,PhInfo,""),proplists:get_value(qfile,PhInfo,"")} of
        {Clidata,Qfile} when Clidata=/="" andalso Qfile=/="" -> inform_resultall(State,Res);  % my qfile send 2
        {"",_} -> inform_result_mine(State,Res);
        {_,""} -> inform_result2sb(State,Res)
    end.

inform_resultall(State=#state{call_info=PhInfo},Res)->
    inform_result_mine(State,Res),
    Clidata_0 = proplists:get_value(clidata,PhInfo,""),
    case Clidata_0 of
       {Clidata_sb,Qno_sb,ToSBRes}->
           PhInfo_sb1=lists:keystore(qno,1,PhInfo,{qno,Qno_sb}),
           PhInfo_sb2=lists:keystore(clidata,1,PhInfo_sb1,{clidata,Clidata_sb}),
           RecDs = proplists:get_value(recds,PhInfo,""),
           Res1= if Res=="7" orelse RecDs=="ok_already"-> "7"; true-> ToSBRes end,
           inform_result2sb(State#state{call_info=PhInfo_sb2},Res1);
       {Clidata_sb,Qno_sb}->
           PhInfo_sb1=lists:keystore(qno,1,PhInfo,{qno,Qno_sb}),
           PhInfo_sb2=lists:keystore(clidata,1,PhInfo_sb1,{clidata,Clidata_sb}),
%           io:format("Qno_sb:~p myqno:~p~nphinfo:~p~n",[Qno_sb,proplists:get_value(qno,PhInfo,""),PhInfo_sb2]),
%           Res1= if Res=="7"-> "7"; true-> "2" end,
           Res1="7",
           inform_result2sb(State#state{call_info=PhInfo_sb2},Res1);
       _ when is_list(Clidata_0)->  
           io:format("old sb clidata,don't send~n")
    end.
    
inform_result2sb(#state{call_info=PhInfo,start_time=StartTime},Res) when is_atom(Res)->
    Qno = proplists:get_value(qno,PhInfo,""),
    Clidata = proplists:get_value(clidata,PhInfo,""),
    RecDs = proplists:get_value(recds,PhInfo,""),
    log("~p", [{Qno,RecDs,Res,Clidata,duration(StartTime),proplists:get_value(cid,PhInfo)}]),
    void;
inform_result2sb(#state{call_info=PhInfo,start_time=StartTime},Res) ->
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
    if Res =/= "2" andalso Res =/= "7"-> q_strategy:del_counter(Clidata); true-> false end,
    case Res of
        "1"-> q_strategy:update_last10(1);
        "7"-> void;
        _-> q_strategy:update_last10(0)
    end,
    q_strategy:record_last(Res),
    io:format(" tosb~p ",[Res]),
    log("to_sb:~p", [{Qno,RecDs,Res,Clidata,duration(StartTime),proplists:get_value(cid,PhInfo)}]),
    Ret.

inform_result_mine(#state{call_info=PhInfo,start_time=StartTime},Res) ->
    Qno = proplists:get_value(qno,PhInfo),
    Clidata = proplists:get_value(clidata,PhInfo,""),
    RecDs = proplists:get_value(recds,PhInfo,""),
    Filename=proplists:get_value(qfile,PhInfo,""),
    Fn=my_result0(Qno,StartTime,RecDs,Filename,Res,[{caller,proplists:get_value(cid,PhInfo)}]),
    case proplists:get_value(wwwnode,PhInfo,"") of
    ""-> void;
    Node-> 
%        io:format("~p",[[Fn,Qno]]),
        rpc:call(Node,fid,writefile,[Fn,Qno])
    end,
    log("~p", [{Qno,RecDs,Res,Clidata,duration(StartTime),proplists:get_value(cid,PhInfo)}]),
    ok.
my_result0(Qno,StartTime,RecDs,Filename,"1",Other)->
    q_strategy:update_last(1),
    my_result(Qno,StartTime,RecDs,Filename,"1",Other);
my_result0(Qno,StartTime,RecDs,Filename,Res,Other)-> 
    q_strategy:update_last(0),
    my_result(Qno,StartTime,RecDs,Filename,Res,Other).

my_result(Qno,StartTime,RecDs,Filename,"1",_) ->
    my_print("my_result recds:~p~n",[RecDs]),
    mylog(Filename++"_ok.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,Result,_) when RecDs=="first4" orelse RecDs==no_authcode orelse Result=="0"->
    mylog(Filename++"_kajie.txt","~s",[Qno]);
my_result(Qno,_StartTime,"first5",Filename,_,_) ->
    mylog(Filename++"_gaimi.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,Res,_) when RecDs=="first1"->
    mylog(Filename++"_redial1.txt","~s",[Qno]);
my_result(Qno,_StartTime,RecDs,Filename,OtherRes,_) when RecDs=="first6"->  %maybe succeed
    mylog(Filename++"_fail.txt","~p  ~p   ~p",[Qno,OtherRes,RecDs]);
my_result(Qno,_StartTime,RecDs,Filename,Res,_)-> %when Res=="7" orelse RecDs==send_2_before orelse RecDs==first_not_matched->
    mylog(Filename++"_redial.txt","~s",[Qno]).

mylog(Fn,Fmt,Args)-> 
    case filelib:is_dir("result") of
        true-> void;
        _-> file:make_dir("result")
    end,
    utility:log1("result/"++Fn,Fmt,Args),
    Fn.

my_print(Fmt,Args)->utility:my_print(Fmt,Args).
log(Fmt,Args)-> utility:log("./log/q_w2p.log",Fmt,Args).    

test_qnos()->
    [
    ].

