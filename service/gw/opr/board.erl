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
-define(OprSpeak2A_Status(Status),(Status==sidea orelse Status==inserta orelse Status==third orelse Status==splita)).
-define(OprSpeak2B_Status(Status),(Status==sideb orelse Status==insertb orelse Status==third orelse Status==splitb)).
% [callstatus:status,                           //  坐席软终端状态 ring 振铃,hook_off 通话, hook_on 释放
 %   oprstatus: os,                             //. logined,maintaining(维护),suspending(挂起)
 %  activedBoard:ab,                            //  激活的窗口
 %  boards:[{boardstatus:bs,                    // null空,sidea 前塞,sideb 后赛,monitor监听,inserta强插前塞,insertb强插后塞,third三方,splita分割前塞,splitb，分割后塞,ab:前后塞通话
 %           detail:{a:{phone:p,                // 如果左边没有呼叫 就没有a，右边没有 就没有b；没有坐席，就没有o；
 %                     talkstatus:us,           // 前塞状态：ring振铃,busy-忙,hook_off通话，tpring-呼入未接听
 %                     starttime:st},           // 通话开始时间
 %                   b:{phone:p,
 %                     talkstatus:us,
 %                     starttime:st}
 %                }
 %                }]]    boardstatus:

-define(DEFAULTSIDE,#{id=>"",status=>null,ua_node=>node_conf:get_voice_node(),ua=>undefined,ua_ref=>undefined,phone=>"",
         wmg_node=>node_conf:get_wmg_node(),mediaPid=>undefined,media_ref=>undefined,starttime=>erlang:localtime(),lport=>undefined,rip=>"",rport=>undefined}).
-record(state, {id,
                seat,
                owner,
                mixer,
                status=null, % null,sidea,sideb,monitor,insert
                focused=false,
                sidea=?DEFAULTSIDE,
                sideb=?DEFAULTSIDE,
                alive_tref,
                alive_count=0                }).

get_all_status(PidOrSeatBoardTuple)->
    F=fun(State=#state{seat=SeatNo,status=BoardStatus,sidea=SideA=#{status:=AStatus,phone:=APhone,starttime:=AStartTime},sideb=SideB=#{status:=BStatus,phone:=BPhone,starttime:=BStartTime}})->
            AllStatus=#{boardstatus=>BoardStatus,detail=>#{a=>#{phone=>APhone,talkstatus=>AStatus,starttime=>utility1:d2s(AStartTime)},
                                                           b=>#{phone=>BPhone,talkstatus=>BStatus,starttime=>utility1:d2s(BStartTime)}
                                                           }},
            {AllStatus,State}
       end,
    act(PidOrSeatBoardTuple,F).     

pickup_call(PidOrSeatBoardTuple)->
    F=fun(State=#state{seat=SeatNo,sidea=SideA=#{status:=null}})->
            GroupPid=opr_sup:get_group_pid(opr:get_groupno(SeatNo)),
            case oprgroup:pickup_call(GroupPid) of
                {ok,Call=#{ua:=UA,mediaPid:=MediaPid,caller:=Phone,toSipSdp:=ToSipSdp}}->
                    UARef = erlang:monitor(process, UA),
                    MRef=erlang:monitor(process, MediaPid),
                    CallInfoMap=opr:incomingCallPushInfo(Call),
                    {CallInfoMap,State#state{sidea=SideA#{status:=tpring,ua_node:=node(UA),ua:=UA,ua_ref:=UARef,wmg_node:=node(MediaPid),
                           mediaPid:=MediaPid,media_ref:=MRef}}};
                undefined->
                    {undefined,State}
            end
       end,
    act(PidOrSeatBoardTuple,F).     

get({Seat,BId})-> opr:get_board(Seat,BId).
get_count(PidOrSeatBoardTuple)->
    F=fun(State=#state{owner=Owner,sidea=#{mediaPid:=AMedia},sideb=#{mediaPid:=BMedia}})->
            OprMedia=opr:get_mediaPid(Owner),
            {[sip_media:get_count(OprMedia),sip_media:get_count(AMedia),sip_media:get_count(BMedia)],State}
       end,
    act(PidOrSeatBoardTuple,F).   
get_mixer(PidOrSeatBoardTuple)->
    F=fun(State=#state{mixer=Mixer})->
            {Mixer,State}
       end,
    act(PidOrSeatBoardTuple,F).   
get_a_media(PidOrSeatBoardTuple)->
    F=fun(State=#state{sidea=#{mediaPid:=Media}})->
            {Media,State}
       end,
    act(PidOrSeatBoardTuple,F).   
get_a_ua(PidOrSeatBoardTuple)->
    F=fun(State=#state{sidea=#{ua:=UA}})->
            {UA,State}
       end,
    act(PidOrSeatBoardTuple,F).  
get_b_media(PidOrSeatBoardTuple)->
    F=fun(State=#state{sideb=#{mediaPid:=Media}})->
            {Media,State}
       end,
    act(PidOrSeatBoardTuple,F).  
show(PidOrSeatBoardTuple)->
    F=fun(State)->
            {State,State}
       end,
    act(PidOrSeatBoardTuple,F).   
%% APIs
start(Paras=[_Seat,_Id,_Owner]) ->
    {ok, _Pid} = my_server:start(?MODULE,Paras,[]).  
    
stop(Pid) ->
        my_server:cast(Pid, stop).
init([Seat,Id,Owner]) ->
    {ok, _ATef} = my_timer:send_interval(?ALIVE_TIME, alive_timer),
    llog("board ~p started",[{Seat,Id}]),
        {ok,Mixer}=mixer:start(),
    {ok, #state{seat=Seat,id=Id,owner=Owner,mixer=Mixer,sidea=?DEFAULTSIDE#{id:="a"++Id},sideb=?DEFAULTSIDE#{id:="b"++Id}}}.
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
handle_info({callee_status,From, Status},State=#state{sideb=SideB=#{ua:=From}}) ->
    State1=State#state{sideb=SideB#{status:=Status}},
    State2=
    if 
        Status == ring -> 
            what_to_do,
            State1;%my_timer:send_after(?TALKTIMEOUT,{timeover,From});
        Status == hook_off -> 
            sideb_hookoff(State1);
        true -> 
            State1
    end,
    {noreply,State2};
handle_info({callee_status,From, Status},State=#state{sidea=SideA=#{ua:=From}}) ->
    State1=State#state{sidea=SideA#{status:=Status}},
    State2=
    if 
        Status == ring -> 
            what_to_do,
            State1;%my_timer:send_after(?TALKTIMEOUT,{timeover,From});
        Status == hook_off -> 
            sidea_hookoff(State1);
        true -> 
            State1
    end,
    {noreply,State2};
handle_info({callee_sdp,From,SDP_FROM_SS},State=#state{id=Aid,seat=Seat,sidea=#{},sideb=#{}}) ->
    #{mediaPid:=MediaPid,phone:=Phno}=get_side(From,State),
    llog("app ~p ss sdp: ~p",[{Seat,Aid,Phno},SDP_FROM_SS]),
    case  get_port_from_sdp(SDP_FROM_SS) of
    {PeerIp,PeerPort}->
       sip_media:set_peer_addr(MediaPid, {PeerIp,PeerPort});
    _-> void
    end,
%   {noreply,State#state{status=hook_off}}; 
    {noreply,State};    
handle_info({'DOWN', _Ref, process, From, _Reason},State=#state{mixer=Mixer,owner=Owner,status=BoardStatus,seat=Seat,id=Id,sidea=SideA=#{ua:=UA,mediaPid:=MediaPid, phone:=Phno},sideb=SideB}) when From==UA; From==MediaPid->
    llog("board sidea:~p sip hangup",[{Seat,Id,Phno}]),
    OprMedia=opr:get_mediaPid(Owner),
    release_side(SideA,State),
    NST=if BoardStatus==sidea; BoardStatus==inserta; BoardStatus==splita-> 
                State#state{sidea=?DEFAULTSIDE,status=null}; 
           BoardStatus==ab; BoardStatus==monitor->
                release_side(SideB,State),
                mixer:sub(Mixer,OprMedia),
                State#state{sidea=?DEFAULTSIDE,status=null,sideb=?DEFAULTSIDE};
           BoardStatus==third; BoardStatus==insertb->
                State#state{sidea=?DEFAULTSIDE,status=sideb};
           true-> 
                State#state{sidea=?DEFAULTSIDE} 
       end,
    {noreply,NST};   
handle_info({'DOWN', _Ref, process, From, _Reason},State=#state{status=BoardStatus,seat=Seat,id=Id,sidea=SideA,sideb=Side=#{ua:=UA,mediaPid:=MediaPid, phone:=Phno}}) when From==UA; From==MediaPid->
    llog("board sideb:~p sip hangup",[{Seat,Id,Phno}]),
    release_side(Side,State),
    NST=if BoardStatus==sideb; BoardStatus==insertb-> 
                State#state{sideb=?DEFAULTSIDE,status=null}; 
           BoardStatus==ab->
                release_side(SideA,State),
                State#state{sidea=?DEFAULTSIDE,status=null,sideb=?DEFAULTSIDE};
           BoardStatus==third->
                State#state{sideb=?DEFAULTSIDE,status=sidea};
           true-> 
                State#state{sideb=?DEFAULTSIDE} 
       end,
    {noreply,NST};       
handle_info(alive_timer,State=#state{id=Aid,seat=Seat, alive_count=AC}) ->
    if
        AC  =:= 0 ->
            llog("app ~p alive timeout.~n",[{Seat,Aid}]),
%           {stop,alive_time_out,State};
            {noreply,State};
        true ->
            {noreply,State#state{alive_count=0}}
    end;
handle_info(Msg,State) ->
     llog("app ~p receive unexpected message ~p.",[State, Msg]),
    {noreply, State}.

terminate(_Reason, State=#state{sidea=SideA,sideb=SideB}) -> 
    release_side(SideA,State),
    release_side(SideB,State),
    ok. 

act(Act)->    act(whereis(?MODULE),Act).
act({Seat,BIndex},Act) ->    act(opr:get_board(Seat,BIndex),Act);
act(Pid,Act)->    my_server:call(Pid,{act,Act}).
cast({Seat,BIndex},Act)  ->    cast(opr:get_board(Seat,BIndex),Act);
cast(Pid,Act)->    my_server:cast(Pid,{act,Act}).
    
%% helpers  
get_port_from_sdp(SDP_FROM_SS) when is_binary(SDP_FROM_SS)->
    {#session_desc{connect={_Inet4,Addr}},[St2]} = sdp:decode(SDP_FROM_SS),
    {Addr,St2#media_desc.port}.

duration({M1,S1,_}) ->
    case os:timestamp() of
        {M1,S2,_} -> S2 - S1;
        {_,S2,_} -> 1000000 + S2 - S1
    end.
    
llog(F,P) ->
    llog:log(F,P).
%    io:format(F,P).
%     {unused,F,P}.
     
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

get_side(From,#state{sidea=SideA=#{ua:=UA},sideb=SideB=#{ua:=UB}})->
    if From==UA-> SideA; From==UB-> SideB; true-> unbelievable end.

release(BoardPidOrSeatBoardTuple)->
    Act=fun(State=#state{sidea=SideA,sideb=SideB})->
            release_side(SideA,State),
            release_side(SideB,State),
            {ok,State#state{status=null,sidea=?DEFAULTSIDE,sideb=?DEFAULTSIDE}}
        end,
    act(BoardPidOrSeatBoardTuple,Act).
release_side(#{ua:=UA,ua_ref:=UARef,mediaPid:=MediaPid,media_ref:=MRef,wmg_node:=WmgNode},State=#state{mixer=Mixer}) ->
    if is_pid(UA)-> 
        erlang:demonitor(UARef),
        UA ! stop;
    true-> void
    end,
    if is_pid(MediaPid)->
        erlang:demonitor(MRef),
        mixer:sub(Mixer,MediaPid),
        rpc:call(WmgNode, sip_media, stop, [MediaPid]);
    true-> void
    end.

calla(Phone,St=#state{owner=Owner,sidea=SideA,focused=Focused,sideb=SideB,mixer=Mixer})->
    NSide=SideA#{phone:=Phone,status:=calling},
    {ok,Res}=opr:make_call(NSide),
    #{mediaPid:=Media}=NSide1=maps:merge(NSide,Res),
    OprMedia=opr:get_mediaPid(Owner),
    mixer:add(Mixer,Media),
    sip_media:set_peer(Media,Mixer),
    if Focused==true->
        mixer:add(Mixer,OprMedia);
    true-> void
    end,
    case maps:get(mediaPid,SideB,undefined) of
        BMedia when is_pid(BMedia)->    
            mixer:sub(Mixer,BMedia),
            sip_media:unset_peer(BMedia,Mixer);
        _-> void
    end,
    St#state{status=sidea,sidea=NSide1};
calla(BPid,Phone)->
    F=fun(State)->
            {ok,calla(Phone,State)}
       end,
    act(BPid,F).
callb(Phone,St=#state{owner=Owner,sidea=SideA,focused=Focused,sideb=SideB,mixer=Mixer})->
    NSide=SideB#{phone:=Phone,status:=calling},
    {ok,Res}=opr:make_call(NSide),
    #{mediaPid:=Media}=NSide1=maps:merge(NSide,Res),
    OprMedia=opr:get_mediaPid(Owner),
    mixer:add(Mixer,Media),
    sip_media:set_peer(Media,Mixer),
    if Focused==true->
        mixer:add(Mixer,OprMedia);
    true-> void
    end,
    case maps:get(mediaPid,SideA,undefined) of
        AMedia when is_pid(AMedia)->    
            mixer:sub(Mixer,AMedia),
            sip_media:unset_peer(AMedia,Mixer);        
        _-> void
    end,
    St#state{status=sideb,sideb=NSide1};
callb(BPid,Phone)->
    F=fun(State)->
            {ok,callb(Phone,State)}
       end,
    act(BPid,F).    
sideb(BPid)->
    F=fun(State=#state{owner=Owner,sidea=SideA=#{mediaPid:=AMedia},focused=Focused,sideb=SideB=#{mediaPid:=BMedia,status:=BStatus},mixer=Mixer})->
            OprMedia=opr:get_mediaPid(Owner),
            if is_pid(BMedia)->
                mixer:sub(Mixer,AMedia),
                sip_media:unset_peer(AMedia,Mixer),
                mixer:add(Mixer,BMedia),
                sip_media:set_peer(BMedia,Mixer),
                case {Focused,BStatus} of
                {true,hook_off}-> 
                    mixer:add(Mixer,OprMedia),
                    sip_media:set_peer(OprMedia,Mixer);
                {true,_}->
                    sip_media:unset_peer(OprMedia,AMedia),
                    mixer:add(Mixer,OprMedia);
                _-> void
                end,
                {ok,State#state{status=sideb}};
            true-> 
                {ok,State}
            end
       end,
    act(BPid,F).  
sidea(BPid)->
    F=fun(State=#state{owner=Owner,sidea=SideA=#{mediaPid:=AMedia,status:=AStatus,ua:=AUA},focused=Focused,sideb=SideB=#{mediaPid:=BMedia,status:=BStatus},mixer=Mixer})->
            OprMedia=opr:get_mediaPid(Owner),
            if is_pid(AMedia)->
                mixer:sub(Mixer,BMedia),
                sip_media:unset_peer(BMedia,Mixer),
                mixer:add(Mixer,AMedia),
                sip_media:set_peer(AMedia,Mixer),
                State1=State#state{status=sidea},
                State2=
                case {Focused,AStatus} of
                {true,hook_off}-> 
                    mixer:add(Mixer,OprMedia),
                    sip_media:set_peer(OprMedia,Mixer),
                    State1;
                {true,tpring}-> 
                    AUA ! {p2p_answer, self()},
                    mixer:add(Mixer,OprMedia),
                    sip_media:set_peer(OprMedia,Mixer),
                    State1#state{sidea=SideA#{status:=hook_off}};
                {true,_}->
                    sip_media:unset_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),
                    State1;
                _-> State1
                end,
                {ok,State2};
            true-> 
                {ok,State}
            end
       end,
    act(BPid,F). 
ab(BPid)->     
    F=fun(State=#state{owner=Owner,sidea=SideA=#{mediaPid:=AMedia,status:=AStatus},focused=Focused,sideb=SideB=#{mediaPid:=BMedia,status:=BStatus},mixer=Mixer})->
            OprMedia=opr:get_mediaPid(Owner),
            if is_pid(AMedia) andalso is_pid(BMedia)->
                mixer:sub(Mixer,OprMedia),
                sip_media:unset_peer(OprMedia,Mixer),
                mixer:add(Mixer,AMedia),
                sip_media:set_peer(AMedia,Mixer),
                mixer:add(Mixer,BMedia),
                sip_media:set_peer(BMedia,Mixer),
                {ok,State#state{status=ab}};
            true-> 
                {ok,State}
            end
       end,
    act(BPid,F). 
get_sidea(BPid)->
    F=fun(State=#state{sidea=SideA})->
            {SideA,State}
       end,
    act(BPid,F).        
get_sideb(BPid)->
    F=fun(State=#state{sideb=Side})->
            {Side,State}
       end,
    act(BPid,F).  
get_status(BPid)->
    F=fun(State=#state{status=Status})->
            {Status,State}
       end,
    act(BPid,F).        

focus(Pid)->
    F=fun(State=#state{owner=Owner,mixer=Mixer,status=BoardStatus,sidea=#{status:=AStatus},sideb=#{status:=BStatus}})->
            OprMedia=opr:get_mediaPid(Owner),
            sip_media:set_peer(OprMedia,undefined),
            case {BoardStatus, AStatus,BStatus} of
                {_,hook_off,_} when ?OprSpeak2A_Status(BoardStatus)-> 
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia);
                {_,_,hook_off} when ?OprSpeak2B_Status(BoardStatus)-> 
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia);
                {_,_,_} when ?OprSpeak2A_Status(BoardStatus) orelse ?OprSpeak2B_Status(BoardStatus)-> 
                    mixer:add(Mixer,OprMedia);
                _-> todo
            end,
            {ok,State#state{focused=true}}
       end,
    act(Pid,F).     
unfocus(Pid)->
    F=fun(State=#state{owner=Owner,mixer=Mixer,sidea=#{},sideb=#{}})->
            OprMedia=opr:get_mediaPid(Owner),
            sip_media:unset_peer(OprMedia,Mixer),
            mixer:sub(Mixer,OprMedia),
            {ok,State#state{focused=false}}
       end,
    act(Pid,F). 
third(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),
                    sip_media:set_peer(AMedia,Mixer),
                    sip_media:set_peer(BMedia,Mixer),
                    if AStatus==hook_off-> mixer:add(Mixer,AMedia); BStatus==hook_off-> mixer:add(Mixer,BMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=third}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
monitor(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    %sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),
                    sip_media:set_peer(AMedia,Mixer),
                    sip_media:set_peer(BMedia,Mixer),
                    if AStatus==hook_off-> mixer:add(Mixer,AMedia); BStatus==hook_off-> mixer:add(Mixer,BMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=monitor}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
inserta(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),

                    sip_media:set_peer(AMedia,Mixer),

                    mixer:sub(Mixer,BMedia),
                    if AStatus==hook_off-> mixer:add(Mixer,AMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=inserta}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
insertb(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),

                    sip_media:set_peer(BMedia,Mixer),

                    mixer:sub(Mixer,AMedia),
                    if BStatus==hook_off-> mixer:add(Mixer,BMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=insertb}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
releasea(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=SideA=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                release_side(SideA,State),
                {ok,State#state{status=sideb}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
releaseb(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=SideB=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                release_side(SideB,State),
                {ok,State#state{status=sidea}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
splita(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),

                    sip_media:set_peer(AMedia,Mixer),

                    mixer:sub(Mixer,BMedia),
                    if AStatus==hook_off-> mixer:add(Mixer,AMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=splita}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
splitb(Pid)->
    F=fun(State=#state{focused=Focused, owner=Owner,mixer=Mixer,sidea=#{mediaPid:=AMedia,status:=AStatus},sideb=#{mediaPid:=BMedia,status:=BStatus}})->
            if is_pid(AMedia) andalso is_pid(BMedia)->
                if Focused==true->
                    OprMedia=opr:get_mediaPid(Owner),
                    sip_media:set_peer(OprMedia,Mixer),
                    mixer:add(Mixer,OprMedia),

                    sip_media:set_peer(BMedia,Mixer),

                    mixer:sub(Mixer,AMedia),
                    if BStatus==hook_off-> mixer:add(Mixer,BMedia); true-> void end;
                true->
                    void
                end,
                {ok,State#state{status=splitb}};
            true->
                {failed,State}
            end
       end,
    act(Pid,F). 
sidea_hookoff(State1=#state{focused=Focused,mixer=Mixer,owner=Owner,status=Status,sidea=#{}}) ->
    case {Focused,Status} of
        {true,_} when ?OprSpeak2A_Status(Status)->
            OprMedia=opr:get_mediaPid(Owner),
            sip_media:set_peer(OprMedia,Mixer);
        _-> void
    end,
    State1.
sideb_hookoff(State1=#state{focused=Focused,mixer=Mixer,owner=Owner,status=Status,sideb=#{}})->
    case {Focused,Status} of
        {true,_} when ?OprSpeak2B_Status(Status)->
            OprMedia=opr:get_mediaPid(Owner),
            sip_media:set_peer(OprMedia,Mixer);
        _-> void
    end,
    State1.
