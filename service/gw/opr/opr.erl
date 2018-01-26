-module(opr).
-compile(export_all).
-include("opr.hrl").
-include("db_op.hrl").
-define(POOLTIME, 3000).
-define(BOARDNUM,14).
-define(XILian_BOARDNUM,101).
-define(CientPort,"8082").
-record(state, {id,
                phone,
                oprstatus=logined,
                activedBoard=0,
                oprId,   %% 
                sipstatus=init,      %% init | invite | ring | hook_on | hook_off | p2p_ring | p2p_answer
                client_host,
                ua,
                ua_ref,
                transfer_sides=#{},
                boards=#{},  %#{BoardPid=>#{no=>No}}
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
 %                }]]   
%% extra APIs.
% incomingSipWebcall(CallID, SipSDP, PhoneNo, WMGNode, SipPid) ->
%     {ok, Pid} = my_server:start(?MODULE, [CallID], []),
%     my_server:call(Pid, {incomingSipWebcall, SipSDP, PhoneNo, WMGNode, SipPid}).
get_groupphone_by_seatno(SeatNo)->
    case mnesia:dirty_read(seat_t,SeatNo) of
        [#seat_t{item=#{group_no:=GroupNo}}]->
            case mnesia:dirty_read(oprgroup_t,GroupNo) of
                [#oprgroup_t{item=#{phone:=GroupPhone}}]-> GroupPhone;
            _-> ""
            end;
        _-> ""
    end.
do_get_all_status(State=#state{oprstatus=OprStatus,activedBoard=ActiveBoard,boards=Boards,sipstatus=CallStatus})->
    AllBoardStatus0=[board:get_all_status(Board)||Board<-maps:keys(Boards)],
    AllBoardStatus=[I_||I_<-AllBoardStatus0,is_map(I_)],
    AllStatus=#{oprstatus=>OprStatus,callstatus=>CallStatus,activedBoard=>ActiveBoard,boards=>AllBoardStatus},
    {AllStatus,State}.
get_all_status(SeatId)->
    F=fun(State)->
        do_get_all_status(State)
       end,
    act(SeatId,F).    

handshake(SeatId,ClientActiveBI)->
    focus(SeatId,ClientActiveBI).
message(OprId1,{"group",Message})->
    Seat1Id=opr_sup:get_seatno_by_oprid(OprId1),
    GroupNo=opr:get_groupno(Seat1Id),
    {atomic,Seats}=?DB_QUERY(seat_t,{item=#{group_no:=GroupNo_}},GroupNo==GroupNo_),
    SeatNos=[SeatNo_||#seat_t{seat_no=SeatNo_}<-Seats,SeatNo_=/=Seat1Id],
    [send_instant_msg(SeatNo,Message)||SeatNo<-SeatNos],
    [{status,ok},{seatId,Seat1Id}];
message(OprId1,{"all",Message})-> 
    Seat1Id=opr_sup:get_seatno_by_oprid(OprId1),
    OprPid1=opr_sup:get_opr_pid(Seat1Id),
    OprPids=opr_sup:get_all_oprpid(),
    io:format("message:~p~n",[{Seat1Id,OprPid1,OprPids}]),
    [send_instant_msg(OprPid,Message)||OprPid<-OprPids,OprPid1=/=OprPid],
    [{status,ok},{seatId,Seat1Id}];
message(OprId1,{OprId2,Message})->
    Seat1Id=opr_sup:get_seatno_by_oprid(OprId1),
    if Seat1Id =/=undefined->
        case mnesia:dirty_read(opr_t,OprId2) of
            []-> 
                Opr_t0=#opr_t{item=Item}=#opr_t{oprId=OprId2},
                ?DB_WRITE(Opr_t0#opr_t{item=Item#{msg_to_send:=[Message]}});
            [OprItem=#opr_t{item=Item=#{msg_to_send:=Msgs}}]-> 
                ?DB_WRITE(OprItem#opr_t{item=Item#{msg_to_send:=[Message|Msgs]}})
        end,
        case opr_sup:get_oprpid_by_oprid(OprId2) of
            undefined-> void;
            OprPid2 ->
                send_msg_to_send(OprPid2)
        end,
        [{status,ok},{seatId,Seat1Id}];
    true->
        [{status,failed},{reason,not_logined}]
    end.
talk_to_opr(OprId1,OprId2,MsgMap)->
    Seat1Id=opr_sup:get_seatno_by_oprid(OprId1),
    OprPid2=opr_sup:get_oprpid_by_oprid(OprId2),
    case {is_list(Seat1Id),is_pid(OprPid2)} of
    {true,true}->
        OprMedia1=opr:get_mediaPid(Seat1Id),
        OprMedia2=opr:get_mediaPid(OprPid2),
        opr_rbt:add(OprMedia1),
        Res=send_message(OprPid2,MsgMap),
        case Res of
            {ok,#{"status":=<<"ok">>,"response":=<<"accept">>}}->
                opr_rbt:sub(OprMedia1),
                sip_media:set_peer(OprMedia1,OprMedia2),
                sip_media:set_peer(OprMedia2,OprMedia1),
                todo,% unfocus
                [{status,ok},{seatId,Seat1Id}];
            {ok,#{"status":=<<"ok">>,"response":=<<"reject">>}}->
                opr_rbt:sub(OprMedia1),
                [{status,failed},{reason,reject}];
            _-> 
                opr_rbt:sub(OprMedia1),
                [{status,failed},{reason,operator2_not_response}]
        end;
    {false,_}->
        [{status,failed},{reason,operator1_not_logined}];
    {true,false}->
        [{status,failed},{reason,operator2_not_logined}]
    end.

queryhistorymsg(OprId2,Number0)->
    History=
    case mnesia:dirty_read(opr_t,OprId2) of
        []-> [];
        [OprItem=#opr_t{item=#{msg_history:=His}}]-> His
    end,
    Number=min(Number0,length(History)),
    {MsgMaps,_}=lists:split(Number,History),
    Msgs=utility1:maps2jsos(MsgMaps),
    [{status,ok},{msgs,Msgs}].

focus(PidOrSeat,BoardIndex)->
    Boards=get_boards(PidOrSeat),
    if BoardIndex>0 andalso BoardIndex=<length(Boards)->
        Board=get_board(PidOrSeat,BoardIndex),
        UnfocusedList=Boards--[Board],
        [board:unfocus(Board_)||Board_<-UnfocusedList],
        board:focus(Board),
        F=fun(State=#state{})->
                {ok,State#state{activedBoard=BoardIndex}}
           end,
        act(PidOrSeat,F),
        ok;
    true->
        {failed,boardindex_error}
    end.    
get_groupno(SeatNo)->
    [#seat_t{item=#{group_no:=GroupNo}}]=opr_sup:get_by_seatno(SeatNo),
    GroupNo.
get_boardn_sidea(Seat,BoardIndex)->
    board:get_sidea(opr:get_board(Seat,BoardIndex)).
show(PidOrSeat)->
    F=fun(State)->
            {State,State}
       end,
    act(PidOrSeat,F).    
get_free_board(PidOrSeat)->
    Boards=get_boards(PidOrSeat),
    get_free_board1(Boards).
get_free_board1([])-> undefined;
get_free_board1([Board|T])->
    case board:is_free(Board) of
        true-> Board;
        _->get_free_board1(T)
    end.
incomingCallPushInfo(#{caller:=Caller,ua:=UA,callTime:=CallTime})->
    #{"userId"=>pid_to_list(UA),"phoneNumber"=>Caller,"callTime"=>CallTime}.

send_to_client(Paras,State=#state{client_host=ClientHost})->
    MsgType= if is_map(Paras)-> maps:get("msgType",Paras); true-> maps:get("msgType",utility1:jsonbin2map(Paras)) end,
    Res=
    if is_pid(ClientHost)->  % for test
        ClientHost ! {MsgType,if is_map(Paras)->utility1:map2jsonbin(Paras); true-> Paras end,self()},
        Res_=
         % receive
         %     {ClientHost,R}-> R
         % after 30->
             {ok,#{"status"=><<"ok">>,"response"=><<"accept">>}},
         % end,
         Res_;
    true->
        case ClientHost of
            Ip={_A,_B,_C,_D}->
                utility1:json_http("http://"++utility1:make_ip_str(Ip)++":"++?CientPort,Paras);
            Ip when is_list(Ip)->
                utility1:json_http("http://"++Ip++":"++?CientPort,Paras);
            _-> {error,no_clienthost}
        end
    end,
    Res.

send_boardStateChange(PidOrSeat)->
    F=fun(State=#state{id=SeatId,activedBoard=AB})->
        {AllBoardStatus,_}=opr:do_get_all_status(State),
        Res0=[{msgType,"boardStateChange"},{seatId,SeatId},{boardIndex,AB}],
        Plist=
        if is_map(AllBoardStatus)->
            [{boardState,utility1:map2jso(AllBoardStatus)}|Res0];
        true-> Res0
        end,
        % io:format("send_boardStateChange:~p~n",[Plist]),
        Paras=rfc4627:encode(utility1:pl2jso_br(Plist)),     
        send_to_client(Paras,State),
        {ok,State}
       end,
    cast(PidOrSeat,F).    

do_send_msg_to_send(State=#state{oprId=OprId})->
    case mnesia:dirty_read(opr_t,OprId) of
    [Opr_t=#opr_t{item=Item=#{msg_to_send:=MsgToSends0,msg_history:=History0}}]->
        MsgToSends=lists:reverse(MsgToSends0),
        Res0=[{send_to_client(utility1:map2jsonbin(MsgMap),State),MsgMap}||MsgMap<-MsgToSends],
        Res1=lists:reverse(Res0),
        MsgsSended=[MsgMap_||{{ok,#{"status":=<<"ok">>}},MsgMap_}<-Res1],
        ?DB_WRITE(Opr_t#opr_t{item=Item#{msg_to_send:=MsgToSends0--MsgsSended,msg_history:=MsgsSended++History0}});
    _-> void
    end,
    {ok,State}.
send_msg_to_send(PidOrSeat)->
    cast(PidOrSeat,fun do_send_msg_to_send/1).    
send_instant_msg(PidOrSeat,MsgMap)->
    F=fun(State=#state{oprId=OprId})->
        io:format("send_instant_msg ~p~n",[{PidOrSeat,OprId}]),
        case mnesia:dirty_read(opr_t,OprId) of
        [Opr_t=#opr_t{item=Item=#{msg_history:=History0}}]->
            send_to_client(utility1:map2jsonbin(MsgMap),State),
            ?DB_WRITE(Opr_t#opr_t{item=Item#{msg_history:=[MsgMap|History0]}}),
            {ok,State};
        _-> 
            send_to_client(utility1:map2jsonbin(MsgMap),State),
            Opr_t=#opr_t{item=Item}=#opr_t{oprId=OprId},
            ?DB_WRITE(Opr_t#opr_t{item=Item#{msg_history:=[MsgMap]}}),
            {ok,State}        
        end
       end,
    cast(PidOrSeat,F).    
send_message(PidOrSeat,Paras)->
    F=fun(State)->
            {send_to_client(Paras,State),State}
       end,
    act(PidOrSeat,F).    
broadcast(PidOrSeat,QCs)->
    CallsJson=utility1:maps2jsos([incomingCallPushInfo(QC)||QC<-QCs]),
    Paras=utility1:map2jsonbin(#{msgType=><<"call_broadcast">>,calls=>CallsJson}),
    F=fun(State)->
          send_to_client(Paras,State),
          {ok,State}
       end,
    cast(PidOrSeat,F).    
send_transfer_to_client(DestOprPid,Side=#{"phone":=Phone,"FromSeatId":=FromSeatId,"ToSeatId":=ToSeatId,"userId":=UserId,"boardIndex":=BoardIndex})->
    Paras=utility1:map2jsonbin(#{msgType=><<"push_transfer_to_opr">>,"phone"=>Phone,"FromSeatId"=>FromSeatId,"ToSeatId"=>ToSeatId,"userId"=>UserId,"boardIndex"=>BoardIndex}),
    F=fun(State=#state{transfer_sides=TransferSides})->
            R=send_to_client(Paras,State),
            {R,State#state{transfer_sides=TransferSides#{UserId=>Side}}}
       end,
    cast(DestOprPid,F).   
fetch_transfer_call(SeatIdOrPid,UserId)->
    Fetch_TransferSide=fun(State=#state{transfer_sides=TransferSides})->
        case maps:take(UserId,TransferSides) of
            error-> {{failed,no_transfer_userId},State};
            {Side,NTransfer}-> 
                {{ok,Side},State#state{transfer_sides=NTransfer}}
        end
      end,
    act(SeatIdOrPid,Fetch_TransferSide).

accept_transfer_opr(SeatId,BoardIndex,UserId)->
    BoardPid=get_board(SeatId,BoardIndex),
    case fetch_transfer_call(SeatId,UserId) of
        {ok,Side}->
            board:accept_transfer_opr(BoardPid,Side),
            ok;
        _->
            void
        end,
    ok.
get_transfer_sides(DestOprPid)->    
    F=fun(State=#state{transfer_sides=TransferSides})->
            {TransferSides,State}
       end,
    act(DestOprPid,F).
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
get_board_no(Pid,BoardPid)->
    F=fun(State=#state{boards=Boards})->
        BoardIndex=
        case maps:get(BoardPid,Boards,undefined) of
            #{no:=No}->No;
            _O->
            io:foramt("get_board_no other ~p~n",[{_O,Boards}]), 
            undefined
        end,
        {BoardIndex,State}
       end,
    act(Pid,F).
get_boards(Pid)->
    F=fun(State=#state{boards=Boards})->
            Boards1=lists:sort(fun({_,#{no:=I}},{_,#{no:=J}})-> I=<J end,maps:to_list(Boards)),
            {[BP||{BP,_}<-Boards1],State}
       end,
    act(Pid,F).
get_board(Pid,BoardIndex)->
    F=fun(State=#state{boards=Boards})->
            Plist=maps:to_list(Boards),
            [BoardPid]=[BPid||{BPid,#{no:=Bi}}<-Plist,BoardIndex==Bi],
            {BoardPid,State}
       end,
    act(Pid,F).
get_client_host(Pid)->
    F=fun(State=#state{client_host=Host})->
            {Host,State}
       end,
    act(Pid,F).
relogin(Pid,Host,OprId)->
    F=fun(State=#state{})->
            State1=State#state{client_host=Host,oprId=OprId},
            do_send_msg_to_send(State1),
            {ok,State1}
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
start(Paras) ->
    {ok, Pid} = my_server:start(?MODULE, Paras, []),
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
init(Paras) ->
    {SeatNo,ClientIp,OprId}={proplists:get_value(seat,Paras),proplists:get_value(client_host,Paras),proplists:get_value(oprId,Paras)},
    process_flag(trap_exit, true),
    WmgNode=node_conf:get_wmg_node(),
    UANode = node_conf:get_voice_node(),
    [#seat_t{item=#{user:=OprPhone}}]=opr_sup:get_by_seatno(SeatNo),
    OprPid=self(),
    BoardPidF=fun([SeatNo_,BoardId,OprPid_])->
                 {ok,Pid}=board:start([SeatNo_,integer_to_list(BoardId),OprPid_]),
                 erlang:monitor(process,Pid),
                 {Pid,#{no=>BoardId}}
            end,
    BoardPairs=[BoardPidF([SeatNo,BoardId,OprPid])||BoardId<-lists:seq(1,?BOARDNUM)],
    Boards=maps:from_list(BoardPairs),
    {ok,TR} = my_timer:send_interval(?POOLTIME,check_orphan),
    State=#state{id=SeatNo,client_host=ClientIp,oprId=OprId, sipstatus=init,phone=OprPhone,wmg_node=WmgNode,ua_node=UANode,boards=Boards,tmr=TR},
    % io:format("opr:init paras:~p~n",[Paras]),
    do_send_msg_to_send(State),
    {ok, State}.

handle_call(get_status, _From, #state{sipstatus=Status}=ST) ->
    {reply, Status, ST#state{web_hb=given}};

handle_call(stop, _From, ST) ->
    {stop,normal, ok, call_terminated(ST)};

handle_call(rtp_stat, _From, #state{id=ID, wmg_node=WmgNode}=ST) ->
    {reply, get_rtp_stat(ID, WmgNode), ST};

handle_call({act,Act},_From, ST=#state{}) ->
    try Act(ST) of
    {Res,NST}->
        {reply,Res,NST}
    catch 
      Error:Reason->
          utility1:log("opr: act error:~p~n",[{erlang:get_stacktrace(),Error,Reason}]),
          {reply,Error,ST}
    end;

handle_call({make_call}, _From, #state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST) ->
    {Res,NST}=make_call(ST),
    {reply,Res,NST}.

handle_cast({act,Act}, ST) ->
    try Act(ST) of
    {_,NST}->
        {noreply,NST}
    catch
      Error:Reason->
          utility1:log("opr: cast act error:~p~n",[{erlang:get_stacktrace(),Error,Reason}]),
          {noreply,ST}
    end;

handle_cast(stop, #state{tmr=Tmr}=ST) ->
    my_timer:cancel(Tmr),
    {stop, normal, call_terminated(ST)}.

handle_info({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    

handle_info(check_orphan, #state{id=ID, web_hb=HB,oprId=OprId} = ST) ->
    case opr_sup:register_oprpid(ID,self(),OprId) of
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
handle_info({'DOWN', _Ref, process, MediaPid, _Reason},#state{id=ID,mediaPid=MediaPid}=ST) ->
    NST=call_terminated(ST),
    %voip_sup:on_call_over(ID),
    io:format("seat:~p media_crashed~n",[ID]),
    {_,NST1}=make_call(NST),
    {noreply,NST1};
handle_info({'DOWN', _Ref, process, OneBoardPid, _Reason},#state{id=ID,boards=Boards}=ST) ->
    io:format("seat:~p board down~n",[ID]),
    case maps:get(OneBoardPid,Boards,undefined) of
        undefined->
            io:format("opr: unknown process down ~p~n",[OneBoardPid]),
            {noreply,ST};
        Val=#{no:=No}->
            {ok,Pid}=board:start([ID,ID++"_"++integer_to_list(No),self()]),
            erlang:monitor(process,Pid),
            NBoards=maps:remove(OneBoardPid,Boards),
            {noreply,ST#state{boards=NBoards#{Pid=>Val}}}
    end;

handle_info(_Msg, #state{id=ID}=ST) ->
    io:format("opr[~p] received unknown message.~n",[{ID,_Msg}]),
    {noreply, ST}.

terminate(_,ST=#state{id=ID,boards=Boards}) ->
    call_terminated(ST),
    [board:stop(Board)||Board<-maps:keys(Boards)],
    OprPid=self(),
    GroupPid=oprgroup_sup:get_group_pid(get_groupno(ID)),
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
%cast(Pid,Act)->    my_server:cast(Pid,{act,Act}).
cast(Pid,Act)->    my_server:cast(Pid,{act,Act}).

make_call(#state{id=ID,wmg_node=WMGNode,ua_node=UANode,phone=PhoneNo}=ST)->
    case make_call(#{id=>ID,wmg_node=>WMGNode,ua_node=>UANode,phone=>PhoneNo}) of
        {ok,#{ua:=UA,ua_ref:=UARef,mediaPid:=MediaPid,media_ref:=MRef}}->
            {ok,ST#state{ sipstatus=invite,ua=UA,ua_ref=UARef,mediaPid=MediaPid,media_ref=MRef}};
        {failure, Reason} ->
            {{fail,Reason},ST}
    end;
make_call(M=#{id:=ID,phone:=PhoneNo})->
    case sip_media:start(ID, self()) of
        {ok, MediaPid, ToSipSDP} ->
            GroupPhone=get_groupphone_by_seatno(ID),
            CallInfo = make_info(PhoneNo,GroupPhone),
            UANode=maps:get(ua_node,M,node_conf:get_voice_node()),
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

make_info(PhNo) -> make_info(PhNo,"0085268895100").
make_info(PhNo,Caller) ->
[{phone,PhNo},
 {uuid,{"1",86}},
 {audit_info,{obj,[{"uuid",86},
                   {"company",<<231,136,177,232,191,133,232,190,190,239,188,136,230,183,177,229,156,179,239,188,137,231,167,145,230,138,128,230,156,137,233,153,144,229,133,172,229,143,184,47,230,150,176,228,184,154,229,138,161,229,188,128,229,143,145,233,131,168>>},
                   {"name",<<233,146,177,230,178,155>>},
                   {"account",<<"0131000019">>},{"orgid",1}]}},
 {cid,Caller}].
