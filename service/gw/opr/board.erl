-module(board).

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

-define(DEFAULTSIDE,#{status=>null,ua=>undefined,ua_ref=>undefined,phno=>"",wmgnode=>node_conf:get_wmg_node(),mediaPid=>undefined,media_ref=>undefined,call_st=>"",lport=>undefined,rip=>"",rport=>undefined}).
-record(state, {id,
                seat,
                owner,
                mixer,
                status, % null,sidea,sideb,monitor,insert
                focused=false,
                sidea=?DEFAULTSIDE,
                sideb=?DEFAULTSIDE,
				alive_tref,
				alive_count=0,
				start_time={0,0,0}
                }).
%% APIs
start(Paras=[_Seat,_Id,_Owner]) ->
    {ok, Pid} = my_server:start(?MODULE,Paras,[]).	
	
stop(Pid) ->
        my_server:cast(Pid, stop).
init([Seat,Id,Owner]) ->
	{ok, ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
	llog("board ~p started",[{Seat,Id}]),
	{ok, #state{seat=Seat,id=Id,owner=Owner}}.
handle_call({act,Act}, _, State) ->
    {Res,State1} = Act(State),
    {reply,Res,State1};
handle_call(_Call, _From, State) ->
    {noreply,State}.

handle_cast(stop, State=#state{id=Aid}) ->
    llog("app ~p web hangup",[Aid]),
    {stop,normal,State};	
handle_cast(_Msg, State) ->
    {noreply, State}.	
handle_info({act,Act}, State) ->
    State1 = Act(State),
    {noreply,State1};
handle_info({callee_status,From, Status},State=#state{}) ->
    if 
        Status == ring -> 
            my_timer:send_after(?TALKTIMEOUT,{timeover,From});
        Status == hook_off -> 
            record_hookoff_time_and_add_mixer;
        true -> 
            ok 
    end,
    {noreply,State#state{status=Status}};
handle_info({callee_sdp,From,SDP_FROM_SS},State=#state{id=Aid,seat=Seat,sidea=#{ua:=UA,mediaPid:=MA},sideb=#{ua:=UB,mediaPid:=MB}}) ->
    #{mediaPid:=RrpPid,phno:=Phno}=get_side(From,State),
    llog("app ~p ss sdp: ~p",[{Seat,Aid,Phno},SDP_FROM_SS]),
    case  get_port_from_sdp(SDP_FROM_SS) of
    {PeerIp,PeerPort}->
	   sip_media:set_peer_addr(RrpPid, {PeerIp,PeerPort});
    _-> void
    end,
%	{noreply,State#state{status=hook_off}};	
	{noreply,State};	
handle_info({'DOWN', _Ref, process, UA, _Reason},State=#state{seat=Seat,id=Id})->
    Side=#{phno:=Phno}=get_side(UA,State),
    llog("app ~p sip hangup",[{Seat,Id,Phno}]),
    release(Side),
	{noreply,State#state{sidea=?DEFAULTSIDE}};   
handle_info(alive_timer,State=#state{id=Aid,seat=Seat, alive_count=AC}) ->
    if
	    AC  =:= 0 ->
		    llog("app ~p alive timeout.~n",[{Seat,Aid}]),
%			{stop,alive_time_out,State};
            {noreply,State};
		true ->
		    {noreply,State#state{alive_count=0}}
	end;
handle_info(Msg,State) ->
     llog("app ~p receive unexpected message ~p.",[State, Msg]),
    {noreply, State}.

terminate(_Reason, #state{sidea=SideA,sideb=SideB}) -> 
    todo,%release(SideA),
    todo,%release(SideB),
    ok.	
	
%% helpers	
get_port_from_sdp(SDP_FROM_SS) when is_binary(SDP_FROM_SS)->
    {#session_desc{connect={_Inet4,Addr}},[St2]} = sdp:decode(SDP_FROM_SS),
    {Addr,St2#media_desc.port}.

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
    todo.%make_call(#{id=>ID,wmg_node=>WMGNode,ua_node=>UANode,phone=>PhoneNo}).

call_act(AppId,Act)->
    case app_manager:lookup_app_pid(AppId) of
    {value, AppPid} ->
        my_server:call(AppPid, {act,Act});
    _ ->
        {failed,no_appid}
    end.

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

get_side(From,State=#state{sidea=SideA=#{ua:=UA,mediaPid:=MA},sideb=SideB=#{ua:=UB,mediaPid:=MB}})->
    if From==UA-> SideA; From==UB-> SideB; true-> unbelievable end.

release(#{ua:=UA,ua_ref:=UARef,mediaPid:=MediaPid,media_ref:=MRef,wmgnode:=WmgNode}) ->
    erlang:demonitor(UARef),
    erlang:demonitor(MRef),
    rpc:call(WmgNode, sip_media, stop, [MediaPid]),
    %rpc:call(UANode, voip_ua, stop, [UA]).
    UA ! stop.
