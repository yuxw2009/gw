-module(opr).
-compile(export_all).
-include("opr.hrl").
-define(POOLTIME, 30000).
-define(BOARDNUM,16).
-record(state, {id,
                phone,
                oprstatus,
                sipstatus,      %% init | invite | ring | hook_on | hook_off | p2p_ring | p2p_answer
                client_url,
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

%% extra APIs.
% incomingSipWebcall(CallID, SipSDP, PhoneNo, WMGNode, SipPid) ->
%     {ok, Pid} = my_server:start(?MODULE, [CallID], []),
%     my_server:call(Pid, {incomingSipWebcall, SipSDP, PhoneNo, WMGNode, SipPid}).
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
start(SeatNo) ->
    {ok, Pid} = my_server:start(?MODULE, [SeatNo], []),
    my_server:call(Pid, {make_call}).

stop(Pid) ->
    my_server:cast(Pid, stop),
    ok.

check(Pid) ->
    my_server:call(Pid, get_status).

rtp_stat(Pid) ->
    my_server:call(Pid, rtp_stat).

%% my_server callbacks
init([SeatNo]) ->
    process_flag(trap_exit, true),
    WmgNode=node_conf:get_wmg_node(),
    UANode = node_conf:get_voice_node(),
    [#opr{item=#{user:=OprPhone}}]=opr_sup:get_by_seatno(SeatNo),
    OprPid=self(),
    BoardPidF=fun([SeatNo,BoardId,OprPid])->
                 {ok,Pid}=board:start([SeatNo,SeatNo++"_"++integer_to_list(BoardId),OprPid]),
                 Pid
            end,
    Boards=[BoardPidF([SeatNo,BoardId,OprPid])||BoardId<-lists:seq(1,?BOARDNUM)],
    {ok, #state{id=SeatNo, sipstatus=init,phone=OprPhone,wmg_node=WmgNode,ua_node=UANode,boards=Boards}}.

handle_call(get_status, _From, #state{sipstatus=Status}=ST) ->
    {reply, Status, ST#state{web_hb=given}};

handle_call(rtp_stat, _From, #state{id=ID, wmg_node=WmgNode}=ST) ->
    {reply, get_rtp_stat(ID, WmgNode), ST};

handle_call({act,Act},_From, ST=#state{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};

handle_call({make_call}, _From, #state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST) ->
    make_call(ST).

handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    

handle_cast(stop, #state{tmr=Tmr}=ST) ->
    my_timer:cancel(Tmr),
    call_terminated(ST),
    {stop, normal, ST}.

handle_info(check_web_member_timer, #state{id=ID, web_hb=HB} = ST) ->
    if
        HB == token ->
            call_terminated(ST),
            %voip_sup:on_call_over(ID),
            {stop, normal, ST}; 
        true ->
            {noreply, ST#state{web_hb=token}}
    end; 

handle_info({callee_status, Status},#state{id=ID, wmg_node=WmgNode}=ST) ->
    if  
        Status == hook_on; Status == released; Status == invalid ->
            call_terminated(ST),
            voip_sup:on_call_over(ID),
            {stop, normal, ST};
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
    call_terminated(ST),
    io:format("seat:~p ua_crashed~n",[ID]),
    make_call(ST),
    {noreply, ST};
handle_info({'DOWN', _Ref, process, _, _Reason},#state{id=ID}=ST) ->
    call_terminated(ST),
    %voip_sup:on_call_over(ID),
    io:format("seat:~p media_crashed~n",[ID]),
    make_call(ST),
    {noreply, ST};


handle_info(_Msg, #state{id=ID}=ST) ->
    io:format("voip[~p] received unknown message.~n",[ID]),
    {noreply, ST}.

terminate(_,_) ->
    ok.


%% inner methods.
rbt(WmgNode, ID) ->
    rpc:call(WmgNode, voip, rbt, [ID]).

call_terminated(#state{wmg_node=WmgNode,ua=UA,ua_ref=UARef,mediaPid=MediaPid,media_ref=MRef}) ->
    erlang:demonitor(UARef),
    erlang:demonitor(MRef),
    rpc:call(WmgNode, sip_media, stop, [MediaPid]),
    %rpc:call(UANode, voip_ua, stop, [UA]).
    UA ! stop.


get_rtp_stat(ID, WmgNode) ->
    case rpc:call(WmgNode, voip, rtp_stat, [ID, web], 2000) of
        {badrpc, _R} -> [];
        Rslt -> Rslt
    end.

% my utility function
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

make_call(#state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST)->
    case make_call(#{id=>ID,wmg_node=>WMGNode,ua_node=>UANode,phone=>PhoneNo}) of
        {ok,#{ua:=UA,ua_ref:=UARef,mediaPid:=MediaPid,media_ref:=MRef}}->
            {reply, {ok, self()}, ST#state{ sipstatus=invite,
                                   ua=UA,ua_ref=UARef,mediaPid=MediaPid,media_ref=MRef}};
        {failure, Reason} ->
            {stop, normal, {failure, Reason}, ST}
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
