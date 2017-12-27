-module(oprgroup).
-compile(export_all).
-include("opr.hrl").
-include("db_op.hrl").
-define(POOLTIME, 3000).
-define(BOARDNUM,16).
-record(state, {id,
                mergedto=[],
                oprs=[],
                queued_calls=[],  %#{caller=>Caller,callee=>Callee,peersdp=>SDP,mediaPid=>Media,ua=>UA}
                unused
               }).
 
 get_by_phone(GroupPhone)->
    {atomic,Res}=?DB_QUERY(oprgroup_t,{item=#{phone:=Phone}},Phone==GroupPhone),
    Res. 
get_group_pid_by_phone(GroupPhone)->
    [#oprgroup_t{key=GroupNo}|_]=oprgroup:get_by_phone(GroupPhone),
    opr_sup:get_group_pid(GroupNo).

incoming(Pid,Caller,Callee,SDP,From)->                             %must cast not call
    F=fun(State=#state{queued_calls=QC,oprs=Oprs})->
            %todo if(length(Oprs)==0)-> transfer
            case [Item||Item=#{ua:=UA}<-QC,UA==From] of
                [_|_]-> 
                    {already_incoming_unbelievable,State};
                []->
                    {ok, MediaPid, ToSipSDP}=sip_media:start(Callee, self()),
                    %todo play tone to MediaPid
                    % notice cast no return value
                    From ! {p2p_wcg_ack, self(), ToSipSDP},
                    QC1=[#{caller=>Caller,callee=>Callee,peersdp=>SDP,mediaPid=>MediaPid,ua=>From,callTime=>utility1:timestamp_ms()}|QC],
                    [opr:broadcast(Opr,QC1)||Opr<-Oprs],
                    {{ok,ToSipSDP},State#state{queued_calls=QC1}}
            end
       end,
    cast(Pid,F).    
add_opr(PidOrGroup,OprPid)->
    F=fun(State=#state{oprs=Oprs0})->
        Oprs=
            case lists:member(OprPid,Oprs0) of
                true-> Oprs0;
                _-> [OprPid|Oprs0]
            end,
            {Oprs,State#state{oprs=Oprs}}
       end,
    act(PidOrGroup,F).  
remove_opr(PidOrGroup,OprPid)->
    F=fun(State=#state{oprs=Oprs0})->
         Oprs=lists:delete(OprPid,Oprs0),
         {Oprs,State#state{oprs=Oprs}}
       end,
    act(PidOrGroup,F).      
get_oprs(PidOrGroup)->
    F=fun(State=#state{oprs=QC})->
            {QC,State}
       end,
    act(PidOrGroup,F).        
get_queues(PidOrGroup)->
    F=fun(State=#state{queued_calls=QC})->
            {QC,State}
       end,
    act(PidOrGroup,F).    
show(PidOrSeat)->
    F=fun(State)->
            {State,State}
       end,
    act(PidOrSeat,F).    
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
start(GroupNo) ->
    {ok, _Pid} = my_server:start(?MODULE, [GroupNo], []).

stop(Pid) ->
    my_server:call(Pid, stop),
    ok.

%% my_server callbacks
init([SeatNo]) ->
    {ok, #state{id=SeatNo}}.


handle_call(stop, _From, ST) ->
    {stop,normal, ok, (ST)};

handle_call({act,Act},_From, ST=#state{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.

handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    

handle_cast(stop, ST) ->
    {stop, normal, (ST)}.

handle_info(check_orphan, #state{id=ID} = ST) ->
    case opr_sup:register_oprgroup(ID,self()) of
        ok-> {noreply, ST};
        {error,_Pid1}->
            utility1:log("error! opr seat ~p is orphan,register_oprpid failed, quit!",[{ID,self()}]),
            {stop,normal,ST}
    end;


handle_info(_Msg, #state{id=ID}=ST) ->
    io:format("opr[~p] received unknown message.~n",[{ID,_Msg}]),
    {noreply, ST}.

terminate(_,ST=#state{}) ->
    ok.


%% inner methods.
% my utility function
act(GroupNo,Act) when  is_list(GroupNo) ->    act(opr_sup:get_group_pid(GroupNo),Act);
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

cast(GroupNo,Act) when  is_list(GroupNo) ->    cast(opr_sup:get_group_pid(GroupNo),Act);
cast(Pid,Act)->    my_server:cast(Pid,{act,Act}).

