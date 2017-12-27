-module(opr).
-compile(export_all).
-include("opr.hrl").
-define(POOLTIME, 3000).
-define(BOARDNUM,16).
-define(CientPort,"8082").
-record(state, {id,
                phone,
                oprstatus,
                sipstatus,      %% init | invite | ring | hook_on | hook_off | p2p_ring | p2p_answer
                client_host,
                ua,
                ua_ref,
                boards=[],  %#{index=>i,pid=>Pid,}
                mediaPid,
                media_ref,
                wmg_node,
                ua_node,
                tmr,
                web_hb=given
               }).
 % [oprstatus:status,                           //  ringing,hook_off,
 %  activedBoard:ab,                            //  激活的窗口
 %  boards:[{boardstatus:bs,                    //null,sidea,sideb,monitor,insert,split,
 %           detail:{a:{phone:p,                // 如果左边没有呼叫 就没有a，右边没有 就没有b；没有坐席，就没有o
 %                     talkstatus:us,
 %                     starttime:st},
 %                   b:{phone:p,
 %                     talkstatus:us,
 %                     starttime:st},
 %                   o:{phone:p,
 %                     talkstatus:us,
 %                     starttime:st}
 %                }
 %                }]]    boardstatus:   
%% extra APIs.
% incomingSipWebcall(CallID, SipSDP, PhoneNo, WMGNode, SipPid) ->
%     {ok, Pid} = my_server:start(?MODULE, [CallID], []),
%     my_server:call(Pid, {incomingSipWebcall, SipSDP, PhoneNo, WMGNode, SipPid}).
get_groupno(SeatNo)->
    [#opr{item=#{group_no:=GroupNo}}]=opr_sup:get_by_seatno(SeatNo),
    GroupNo.
get_boardn_sidea(Seat,BoardIndex)->
    board:get_sidea(opr:get_board(Seat,BoardIndex)).
show(PidOrSeat)->
    F=fun(State)->
            {State,State}
       end,
    act(PidOrSeat,F).    
get_board(PidOrSeat,Index)->
    Boards=get_boards(PidOrSeat),
    lists:nth(Index,Boards).
broadcast(PidOrSeat,QCs)->
    CallsJson=[utility1:map2json(#{"userId"=>pid_to_list(UA),"phoneNumber"=>Caller,"callTime"=>CallTime})||#{caller:=Caller,ua:=UA,callTime:=CallTime}<-QCs],
    Paras=utility1:map2jsonbin(#{msgType=><<"broadcast">>,calls=>CallsJson}),
    F=fun(State=#state{client_host=ClientHost})->
            if is_pid(ClientHost)->  % for test
                ClientHost ! {broadcast,Paras};
            true->
                case ClientHost of
                    Ip={_A,_B,_C,_D}->
                        utility1:json_http("http://"++utility1:make_ip_str(Ip)++":"++?CientPort,Paras);
                    Ip when is_list(Ip)->
                        utility1:json_http("http://"++utility1:make_ip_str(Ip)++":"++?CientPort,Paras);
                    _-> void
                end
            end,
            {ok,State}
       end,
    cast(PidOrSeat,F).    
get_ua(Pid)->
    F=fun(State=#state{ua=UA})->
            {UA,State}
       end,
    act(Pid,F).

get_seatno(Pid)->
    F=fun(State=#state{id=UA})->
            {UA,State}
       end,
    act(Pid,F).
get_mediaPid(Pid)->
    F=fun(State=#state{mediaPid=MediaPid})->
            {MediaPid,State}
       end,
    act(Pid,F).
get_boards(Pid)->
    F=fun(State=#state{boards=Boards})->
            {Boards,State}
       end,
    act(Pid,F).
get_client_host(Pid)->
    F=fun(State=#state{client_host=Host})->
            {Host,State}
       end,
    act(Pid,F).
set_client_host(Pid,Host)->
    F=fun(State=#state{})->
            {ok,State#state{client_host=Host}}
       end,
    act(Pid,F).
% call_opr(ConfID,SeatNo)->
%     case opr_sup:get_user_by_seatno(SeatNo) of
%     ""-> {failed,no_opr};
%     OprPhone->
%         WmgNode=node_conf:get_wmg_node(),
%         aconf:create_aconf(ConfID, WmgNode),
%         {ok, SID, ToSipSDP}=rpc:call(WmgNode, aconf, require_offer, [ConfID, sip, aconf:wmg_role(speaker)]),
%         %{ok,SipCallee}=sip_callee:new(self(), OprPhone),
%         %sip_callee:make_call(SipCallee, ToSipSDP),
%         UANode = node(),
%         make_sip_call(OprPhone, UANode, ToSipSDP),
%         ok
%     end.
start(Paras={_SeatNo,_ClientIp}) ->
    {ok, Pid} = my_server:start(?MODULE, [Paras], []),
    my_server:call(Pid, {make_call}),
    {ok,Pid}.

stop(Pid) ->
    my_server:call(Pid, stop),
    ok.

check(Pid) ->
    my_server:call(Pid, get_status).

rtp_stat(Pid) ->
    my_server:call(Pid, rtp_stat).

%% my_server callbacks
init([{SeatNo,ClientIp}]) ->
    process_flag(trap_exit, true),
    WmgNode=node_conf:get_wmg_node(),
    UANode = node_conf:get_voice_node(),
    [#opr{item=#{user:=OprPhone}}]=opr_sup:get_by_seatno(SeatNo),
    OprPid=self(),
    BoardPidF=fun([SeatNo_,BoardId,OprPid_])->
                 {ok,Pid}=board:start([SeatNo_,SeatNo_++"_"++integer_to_list(BoardId),OprPid_]),
                 Pid
            end,
    Boards=[BoardPidF([SeatNo,BoardId,OprPid])||BoardId<-lists:seq(1,?BOARDNUM)],
    {ok,TR} = my_timer:send_interval(?POOLTIME,check_orphan),
    {ok, #state{id=SeatNo,client_host=ClientIp, sipstatus=init,phone=OprPhone,wmg_node=WmgNode,ua_node=UANode,boards=Boards,tmr=TR}}.

handle_call(get_status, _From, #state{sipstatus=Status}=ST) ->
    {reply, Status, ST#state{web_hb=given}};

handle_call(stop, _From, ST) ->
    {stop,normal, ok, call_terminated(ST)};

handle_call(rtp_stat, _From, #state{id=ID, wmg_node=WmgNode}=ST) ->
    {reply, get_rtp_stat(ID, WmgNode), ST};

handle_call({act,Act},_From, ST=#state{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};

handle_call({make_call}, _From, #state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST) ->
    {Res,NST}=make_call(ST),
    {reply,Res,NST}.

handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    

handle_cast(stop, #state{tmr=Tmr}=ST) ->
    my_timer:cancel(Tmr),
    {stop, normal, call_terminated(ST)}.

handle_info(check_orphan, #state{id=ID, web_hb=HB} = ST) ->
    case opr_sup:register_oprpid(ID,self()) of
        ok-> {noreply, ST};
        {error,_Pid1}->
            utility1:log("error! opr seat ~p is orphan,register_oprpid failed, quit!",[{ID,self()}]),
            {stop,normal,ST}
    end;
handle_info({callee_status,_Status},ST)-> {noreply,ST};
handle_info({callee_status,UA, Status},#state{id=ID,ua=UA, wmg_node=WmgNode}=ST) ->
    if  
        Status == ring ->
            rbt(WmgNode, ID),
            {noreply, ST#state{sipstatus=Status}}; 
        true ->
            {noreply, ST#state{sipstatus=Status}}
    end;

handle_info({callee_sdp, SdpFromSS}, #state{id=ID,mediaPid=MPid}=ST) ->
    %ok = rpc:call(WmgNode, voip, answer, [ID, sip, SdpFromSS]),
    llog:log("opr ~p ss sdp: ~p",[ID,SdpFromSS]),
    case  board:get_port_from_sdp(SdpFromSS) of
    Addr={_PeerIp,_PeerPort}->
      sip_media:set_peer_addr(MPid, Addr);
    _-> void
    end,
    {noreply,ST#state{sipstatus=hook_off}};

handle_info({info_call,{dail,_Nu}},#state{id=_ID, wmg_node=_WmgNode}=ST) ->
    %ok = rpc:call(WmgNode, voip, info, [ID, telephone_event, Nu]),
    {noreply, ST};


handle_info({'DOWN', _Ref, process, UA, _Reason},#state{id=ID, ua=UA}=ST) ->
    NST=call_terminated(ST),
    io:format("seat:~p ua_crashed~n",[ID]),
    {_,NST1}=make_call(NST),
    {noreply,NST1};
handle_info({'DOWN', _Ref, process, _, _Reason},#state{id=ID}=ST) ->
    NST=call_terminated(ST),
    %voip_sup:on_call_over(ID),
    io:format("seat:~p media_crashed~n",[ID]),
    {_,NST1}=make_call(NST),
    {noreply,NST1};

handle_info(_Msg, #state{id=ID}=ST) ->
    io:format("opr[~p] received unknown message.~n",[{ID,_Msg}]),
    {noreply, ST}.

terminate(_,ST=#state{id=ID,boards=Boards}) ->
    call_terminated(ST),
    [board:stop(Board)||Board<-Boards],
    OprPid=self(),
    GroupPid=opr_sup:get_group_pid(get_groupno(ID)),
    oprgroup:remove_opr(GroupPid,OprPid),
    ok.


%% inner methods.
rbt(WmgNode, ID) ->
    rpc:call(WmgNode, voip, rbt, [ID]).

call_terminated(St=#state{wmg_node=WmgNode,ua=UA,ua_ref=UARef,mediaPid=MediaPid,media_ref=MRef}) ->
    if is_pid(UA)-> 
        erlang:demonitor(UARef),
        UA ! stop;
    true-> void
    end,
    if is_pid(MediaPid)->
        erlang:demonitor(MRef),
        rpc:call(WmgNode, sip_media, stop, [MediaPid]);
    true-> void
    end,
    St#state{ua=undefined,mediaPid=undefined,ua_ref=undefined,media_ref=undefined}.


get_rtp_stat(ID, WmgNode) ->
    case rpc:call(WmgNode, voip, rtp_stat, [ID, web], 2000) of
        {badrpc, _R} -> [];
        Rslt -> Rslt
    end.

% my utility function
act(Seat,Act) when  is_list(Seat) ->    act(opr_sup:get_opr_pid(Seat),Act);
act(Pid,Act)->    my_server:call(Pid,{act,Act}).
cast(Seat,Act) when  is_list(Seat) ->    cast(opr_sup:get_opr_pid(Seat),Act);
cast(Pid,Act)->    my_server:cast(Pid,{act,Act}).

make_call(#state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST)->
    case make_call(#{id=>ID,wmg_node=>WMGNode,ua_node=>UANode,phone=>PhoneNo}) of
        {ok,#{ua:=UA,ua_ref:=UARef,mediaPid:=MediaPid,media_ref:=MRef}}->
            {ok,ST#state{ sipstatus=invite,ua=UA,ua_ref=UARef,mediaPid=MediaPid,media_ref=MRef}};
        {failure, Reason} ->
            {{fail,Reason},ST}
    end;
make_call(#{id:=ID,wmg_node:=WMGNode,ua_node:=UANode,phone:=PhoneNo})->
    case sip_media:start(ID, self()) of
        {ok, MediaPid, ToSipSDP} ->
            CallInfo = make_info(PhoneNo),
            UA = rpc:call(UANode,voip_ua, start, [self(), PhoneNo, CallInfo]),
            UARef = erlang:monitor(process, UA),
            MRef=erlang:monitor(process, MediaPid),
            rpc:call(UANode, voip_ua, invite, [UA, ToSipSDP]),
            {ok,#{ua=>UA,ua_ref=>UARef,mediaPid=>MediaPid,media_ref=>MRef}};
        FL={failure, _Reason} ->
            FL
    end.
% make_sip_call(PhoneNo, UANode, ToSipSDP) ->
%     CallInfo = make_info(PhoneNo),
%     UA = rpc:call(UANode,voip_ua, start, [self(), "0085288888888", CallInfo]),
%     _Ref = erlang:monitor(process, UA),
%     rpc:call(UANode, voip_ua, invite, [UA, ToSipSDP]),
%     {ok, UA}.

make_info(PhNo) ->
[{phone,PhNo},
 {uuid,{"1",86}},
 {audit_info,{obj,[{"uuid",86},
                   {"company",<<231,136,177,232,191,133,232,190,190,239,188,136,230,183,177,229,156,179,239,188,137,231,167,145,230,138,128,230,156,137,233,153,144,229,133,172,229,143,184,47,230,150,176,228,184,154,229,138,161,229,188,128,229,143,145,233,131,168>>},
                   {"name",<<233,146,177,230,178,155>>},
                   {"account",<<"0131000019">>},{"orgid",1}]}},
 {cid,"0085268895100"}].
