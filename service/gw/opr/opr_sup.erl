-module(opr_sup).
-compile(export_all).
-include("db_op.hrl").
-include("opr.hrl").

-record(state,{opr_pids=#{},seats=#{}}). %oprPid=> #{seat=>s}   seat=>pid

%interface api
create_tables()->
    mnesia:create_table(oprgroup_t,[{type,ordered_set},{attributes,record_info(fields,oprgroup_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(opr,[{type,ordered_set},{attributes,record_info(fields,opr)},{disc_copies ,[node()]}]),
    ok.

add_oprgroup(GroupNo,GroupPhone)->
    Group0=#oprgroup_t{item=Item0}=#oprgroup_t{},
    Group=Group0#oprgroup_t{key=GroupNo,item=Item0#{phone=>GroupPhone}},
    ?DB_WRITE(Group).
get_oprgroup(GroupNo)->
    mnesia:dirty_read(oprgroup_t,GroupNo).

get_by_seatno(SeatNo)->
    mnesia:dirty_read(opr,SeatNo).
get_user_by_seatno(SeatNo)->    
    case get_by_seatno(SeatNo) of
    [#opr{item=#{user:=User}}]->User;
    _-> ""
    end.
add_opr(GroupNo,SeatNo,User,Pwd)->
    Opr=#opr{seat_no=SeatNo},
    ?DB_WRITE(Opr#opr{item=(Opr#opr.item)#{user:=User,group_no:=GroupNo}}),
    rpc:call(node_conf:get_voice_node(),phone,insert_user_or_password,[User,Pwd]),
    ok.
del_opr(SeatNo)->
    case get_by_seatno(SeatNo) of
    [#opr{item=#{user:=User}}]->
        ?DB_DELETE(opr,SeatNo),
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
login(Seat)->
   case whereis(opr_sup) of
    undefined-> opr_sup:start();
    _-> void
    end,
    F=fun(State=#state{opr_pids=OprPids,seats=Seats})->
            case maps:get(Seat,Seats,undefined) of
                undefined->
                   {ok,OprPid}=opr:start(Seat),
                   erlang:monitor(process,OprPid),
                   NSt=State#state{opr_pids=OprPids#{OprPid=>#{seat=>Seat}},seats=Seats#{Seat=>OprPid}},
                   {{ok,OprPid},NSt};
                OprPid->
                   {{ok,OprPid},State}
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
            {reply,err,ST}
    end;
handle_call(_Call, _From, State) ->
    {reply,unhandled,State}.

handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};    
handle_cast(_Msg, State) ->
    {noreply, State}.
    
handle_info({'DOWN', _Ref, process, OprPid, _Reason},State=#state{opr_pids=OprPids,seats=Seats})->
    case maps:get(OprPid,OprPids,undefined) of
        #{seat:=Seat}->
            NSeats=maps:remove(Seat,Seats),
            {noreply,State#state{opr_pids=maps:remove(OprPid,OprPids),seats=maps:remove(Seat,Seats)}};
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