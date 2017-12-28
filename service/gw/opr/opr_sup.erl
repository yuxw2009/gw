-module(opr_sup).
-compile(export_all).
-include("db_op.hrl").
-include("opr.hrl").

-record(state,{opr_pids=#{},seats=#{},groups=#{},oprIds=#{}}). %oprPid=> #{seat=>s,opr_id=>OprId}   seat=>pid.      groupno=>GroupPid,oprIds: #{OprId=>OprPid}

%interface api
create_tables()->
    mnesia:create_table(oprgroup_t,[{type,ordered_set},{attributes,record_info(fields,oprgroup_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(seat_t,[{type,ordered_set},{attributes,record_info(fields,seat_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(opr_t,[{type,ordered_set},{attributes,record_info(fields,opr_t)},{disc_copies ,[node()]}]),
    ok.

add_oprgroup(GroupNo,GroupPhone) when is_binary(GroupNo)-> add_oprgroup(binary_to_list(GroupNo),GroupPhone);
add_oprgroup(GroupNo,GroupPhone) when is_binary(GroupPhone)-> add_oprgroup((GroupNo),binary_to_list(GroupPhone));
add_oprgroup(GroupNo,GroupPhone)->
    Group0=#oprgroup_t{item=Item0}=#oprgroup_t{},
    Group=Group0#oprgroup_t{key=GroupNo,item=Item0#{phone=>GroupPhone}},
    ?DB_WRITE(Group),
    F=fun(State=#state{groups=Groups})->
            GroupPid0=maps:get(GroupNo,Groups,undefined),
            case is_pid(GroupPid0) andalso is_process_alive(GroupPid0) of
                true -> 
                    {GroupPid0,State};
                _->
                    {ok,GroupPid}=oprgroup:start(GroupNo),
                    {GroupPid,State#state{groups=Groups#{GroupNo=>GroupPid}}}
                end
       end,
    act(F).

incoming(Caller,Callee,SDP,From)->
    case oprgroup:get_group_pid_by_phone(Callee) of
        GroupPid when is_pid(GroupPid)->
            oprgroup:incoming(GroupPid,Caller,Callee,SDP,From),
            {ok,GroupPid};
        Other-> no_group_pid
    end.
get_oprpid_by_oprid(OprId)->
    F=fun(State=#state{oprIds=OprIds})->
            OprPid=maps:get(OprId,OprIds,undefined),
            {OprPid,State}
       end,
    act(F).
get_oprgroup(GroupNo)->
    mnesia:dirty_read(oprgroup_t,GroupNo).
get_group_pid(GroupNo)->
    F=fun(State=#state{groups=Groups})->
            GroupPid=maps:get(GroupNo,Groups,undefined),
            {GroupPid,State}
       end,
    act(F).
get_by_seatno(SeatNo)->
    mnesia:dirty_read(seat_t,SeatNo).
get_user_by_seatno(SeatNo)->    
    case get_by_seatno(SeatNo) of
    [#seat_t{item=#{user:=User}}]->User;
    _-> ""
    end.
add_opr(GroupNo,SeatNo,User,Pwd) when is_list(GroupNo) andalso is_list(SeatNo) andalso is_list(User) andalso is_list(Pwd)->
    Opr=#seat_t{seat_no=SeatNo},
    ?DB_WRITE(Opr#seat_t{item=(Opr#seat_t.item)#{user:=User,group_no:=GroupNo}}),
    rpc:call(node_conf:get_voice_node(),phone,insert_user_or_password,[User,Pwd]),
    ok;
add_opr(GroupNo,SeatNo,User,Pwd)-> add_opr(utility1:value2list(GroupNo),utility1:value2list(SeatNo),utility1:value2list(User),utility1:value2list(Pwd)).

del_opr(SeatNo)->
    case get_by_seatno(SeatNo) of
    [#seat_t{item=#{user:=User}}]->
        ?DB_DELETE(seat_t,SeatNo),
        rpc:call(node_conf:get_voice_node(),phone,delete_user,[User]);
    _->
        void
    end.
get_user(User)->
    rpc:call(node_conf:get_voice_node(),phone,get_user,[User]).

% gen_server interface api  
show()->
    F=fun(State=#state{})->
            {State,State}
       end,
    act(F).
stop()->
   case whereis(opr_sup) of
    undefined-> void;
    P-> exit(P,kill)
    end.

register_oprpid(Seat,OprPid)->
   case whereis(opr_sup) of
    undefined-> opr_sup:start();
    _-> void
    end,
    F=fun(State=#state{opr_pids=OprPids,seats=Seats})->
            case maps:get(Seat,Seats,undefined) of
                undefined->
                   utility1:log("notice! opr ~p register_oprpid!",[Seat]),
                   {ok,State#state{seats=Seats#{Seat=>OprPid},opr_pids=OprPids#{OprPid=>#{seat=>Seat}}}};
                OprPid->
                   {ok,State};
                OprPid0->
                   {{error,OprPid0},State}
            end
       end,
    act(F).
login(Seat)-> login(Seat,undefined).
login(Seat,ClientIp)-> login(Seat,ClientIp,"test_OprId").
login(Seat,ClientIp,OprId)->
   case whereis(opr_sup) of
    undefined-> opr_sup:start();
    _-> void
    end,
    GroupNo=opr:get_groupno(Seat),
    GroupPid=get_group_pid(GroupNo),
    F=fun(State=#state{opr_pids=OprPids,seats=Seats,oprIds=OprIds0})->
            case maps:get(Seat,Seats,undefined) of
                undefined->
                   {ok,OprPid}=opr:start({Seat,ClientIp}),
                   oprgroup:add_opr(GroupPid,OprPid),
                   erlang:monitor(process,OprPid),
                   NSt=State#state{opr_pids=OprPids#{OprPid=>#{seat=>Seat,opr_id=>OprId}},seats=Seats#{Seat=>OprPid},oprIds=OprIds0#{OprId=>OprPid}},
                   {{ok,OprPid},NSt};
                OprPid->
                   opr:set_client_host(OprPid,ClientIp),
                   OprPidInfo=maps:get(OprPid,OprPids,#{}),
                   {{ok,OprPid},State#state{opr_pids=OprPids#{OprPid:=OprPidInfo#{seat=>Seat,opr_id=>OprId}},seats=Seats#{Seat=>OprPid},oprIds=OprIds0#{OprId=>OprPid}}}
            end
       end,
    act(F).
logout(Seat)->
    F=fun(State=#state{opr_pids=OprPids,seats=Seats})->
        case maps:take(Seat,Seats) of
            error->{ok,State};
            {OprPid,Seats1} when is_pid(OprPid)->
                opr:stop(OprPid),
                {ok,State#state{seats=Seats1,opr_pids=maps:remove(OprPid,OprPids)}}
       end
    end,
    act(F).
    
get_opr_pid(Seat)->
    F=fun(State=#state{opr_pids=OprPids,seats=Seats})->
            {maps:get(Seat,Seats,undefined),State}
       end,
    act(F).

%% APIs
start() ->
    my_server:start({local,?MODULE},?MODULE,[],[]).
        

exec_cmd(F)-> my_server:call(?MODULE, {cmd,F}). 
    
%% callbacks
init([]) ->
    erlang:group_leader(erlang:whereis(user),self()),
    {ok,#state{}}.
        

handle_call({act,Act},_From, ST=#state{}) ->
    try Act(ST) of
    {Res,NST}-> 
        {reply,Res,NST}
    catch 
    	error:Err ->
            %io:format("opr_sup act error ~p~n",[Err]),
            {reply,{err,Err},ST}
    end;
handle_call(_Call, _From, State) ->
    {reply,unhandled,State}.

handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    
handle_cast(_Msg, State) ->
    {noreply, State}.
    
handle_info({'DOWN', _Ref, process, OprPid, _Reason},State=#state{opr_pids=OprPids,seats=Seats,oprIds=OprIds})->
    case maps:get(OprPid,OprPids,undefined) of
        #{seat:=Seat,opr_id:=OprId}->
            {noreply,State#state{opr_pids=maps:remove(OprPid,OprPids),seats=maps:remove(Seat,Seats),oprIds=maps:remove(OprId,OprIds)}};
        undefined->
            {noreply, State}
    end;        
handle_info(_Msg,State) ->
    {noreply, State}.

terminate(_Reason, _State) -> 
    ok. 

% my utility function
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).