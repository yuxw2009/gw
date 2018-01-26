-module(opr_sup).
-compile(export_all).
-include("db_op.hrl").
-include("opr.hrl").

-record(state,{opr_pids=#{},seats=#{},oprIds=#{}}). %oprPid=> #{seat=>s,opr_id=>OprId}   seat=>pid.      groupno=>GroupPid,oprIds: #{OprId=>OprPid}

%interface api
create_tables()->
    mnesia:create_table(oprgroup_t,[{type,ordered_set},{attributes,record_info(fields,oprgroup_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(seat_t,[{type,ordered_set},{attributes,record_info(fields,seat_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(opr_t,[{type,ordered_set},{attributes,record_info(fields,opr_t)},{disc_copies ,[node()]}]),
    ok.

incoming(Caller,Callee,SDP,From)->oprgroup_sup:incoming(Caller,Callee,SDP,From).
get_oprpid_by_oprid(OprId)->
    F=fun(State=#state{oprIds=OprIds})->
            OprPid=maps:get(OprId,OprIds,undefined),
            {OprPid,State}
       end,
    act(F).
get_seatno_by_oprid(OprId)->
    F=fun(State=#state{oprIds=OprIds,opr_pids=OprPids})->
            SeatNo=
            case maps:get(OprId,OprIds,undefined) of
                OprPid when is_pid(OprPid)->
                    case maps:get(OprPid,OprPids,undefined) of
                        #{seat:=SeatNo_}-> SeatNo_;
                        _-> undefined
                    end;
                _-> undefined
            end,
            {SeatNo,State}
       end,
    act(F).
get_all_oprpid()->    
    F=fun(State=#state{opr_pids=OprPids})->
            {maps:keys(OprPids),State}
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

register_oprpid(Seat,OprPid,OprId)->
   case whereis(opr_sup) of
    undefined-> opr_sup:start();
    _-> void
    end,
    F=fun(State=#state{opr_pids=OprPids,seats=Seats})->
            case maps:get(Seat,Seats,undefined) of
                undefined->
                   utility1:log("notice! opr ~p register_oprpid!",[Seat]),
                   {ok,State#state{seats=Seats#{Seat=>OprPid},opr_pids=OprPids#{OprPid=>#{seat=>Seat,opr_id=>OprId}}}};
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
    GroupPid=oprgroup_sup:get_group_pid(GroupNo),
    F=fun(State=#state{opr_pids=OprPids,seats=Seats,oprIds=OprIds0})->
            case maps:get(Seat,Seats,undefined) of
                undefined->
                   {ok,OprPid}=opr:start([{seat,Seat},{client_host,ClientIp},{oprId,OprId}]),
                   oprgroup:add_opr(GroupPid,OprPid),
                   erlang:monitor(process,OprPid),
                   NSt=State#state{opr_pids=OprPids#{OprPid=>#{seat=>Seat,opr_id=>OprId}},seats=Seats#{Seat=>OprPid},oprIds=OprIds0#{OprId=>OprPid}},
                   {{ok,OprPid},NSt};
                OprPid->
                   opr:relogin(OprPid,ClientIp,OprId),
                   OprPidInfo=maps:get(OprPid,OprPids,#{}),
                   {{ok,OprPid},State#state{opr_pids=OprPids#{OprPid:=OprPidInfo#{seat=>Seat,opr_id=>OprId}},seats=Seats#{Seat=>OprPid},oprIds=OprIds0#{OprId=>OprPid}}}
            end
       end,
    act(F).
logout(Seat)->
    F=fun(State=#state{opr_pids=OprPids,seats=Seats,oprIds=OprIds})->
        case maps:take(Seat,Seats) of
            error->{ok,State};
            {OprPid,Seats1} when is_pid(OprPid)->
                opr:stop(OprPid),
                OprIds1=maps:filter(fun(_,OprPid_) when OprPid_==OprPid-> false;(_,_)-> true end,OprIds),
                {ok,State#state{seats=Seats1,opr_pids=maps:remove(OprPid,OprPids),oprIds=OprIds1}}
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
        Err:Reason ->
            utility1:log("opr_sup: act error:~p~n",[{Err,Reason}]),
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


