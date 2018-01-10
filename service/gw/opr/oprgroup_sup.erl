-module(oprgroup_sup).
-compile(export_all).
-include("db_op.hrl").
-include("opr.hrl").

-record(state,{groups=#{},pids=#{}}). %groupno=>GroupPid,pids: #{GroupPid=>#{groupno=>GroupNo}}

del_oprgroup(GroupNo)->
    GroupPid=get_group_pid(GroupNo),
    case is_pid(GroupPid) andalso is_process_alive(GroupPid) of
        true-> oprgroup:stop(GroupPid);
        _->  void
    end,
    ?DB_DELETE(oprgroup_t,GroupNo),
    ok.

create_oprgroup_pid(GroupNo,State=#state{groups=Groups,pids=Pids})->
    GroupPid0=maps:get(GroupNo,Groups,undefined),
    case is_pid(GroupPid0) andalso is_process_alive(GroupPid0) of
        true -> 
            {GroupPid0,State};
        _->
            {ok,GroupPid}=oprgroup:start(GroupNo),
            erlang:monitor(process,GroupPid),
            {GroupPid,State#state{groups=Groups#{GroupNo=>GroupPid},pids=maps:remove(GroupPid0,Pids#{GroupPid=>#{groupno=>GroupNo}})}}
    end.
       
add_oprgroup(GroupNo,GroupPhone) when is_binary(GroupNo)-> add_oprgroup(binary_to_list(GroupNo),GroupPhone);
add_oprgroup(GroupNo,GroupPhone) when is_binary(GroupPhone)-> add_oprgroup((GroupNo),binary_to_list(GroupPhone));
add_oprgroup(GroupNo,GroupPhone)->
    Group0=#oprgroup_t{item=Item0}=#oprgroup_t{},
    Group=Group0#oprgroup_t{key=GroupNo,item=Item0#{phone=>GroupPhone}},
    ?DB_WRITE(Group),
    F=fun(State)->
            create_oprgroup_pid(GroupNo,State)
       end,
    act(F).

incoming(Caller,Callee,SDP,From)->
    case oprgroup:get_group_pid_by_phone(Callee) of
        GroupPid when is_pid(GroupPid)->
            oprgroup:incoming(GroupPid,Caller,Callee,SDP,From),
            {ok,GroupPid};
        Other-> no_group_pid
    end.
get_oprgroup(GroupNo)->
    mnesia:dirty_read(oprgroup_t,GroupNo).
get_group_pid(GroupNo)->
    F=fun(State=#state{groups=Groups})->
            GroupPid=maps:get(GroupNo,Groups,undefined),
            {GroupPid,State}
       end,
    act(F).
% gen_server interface api  
show()->
    F=fun(State=#state{})->
            {State,State}
       end,
    act(F).
stop()->
   case whereis(?MODULE) of
    undefined-> void;
    P-> exit(P,kill)
    end.

%% APIs
start() ->
    my_server:start({local,?MODULE},?MODULE,[],[]).
        

%% callbacks
init([]) ->
    erlang:group_leader(erlang:whereis(user),self()),
    {atomic,OprGroups}=?DB_QUERY(oprgroup_t),
    State1=lists:foldl(fun(#oprgroup_t{key=GroupNo}, State0)-> 
                        {_,State}=create_oprgroup_pid(GroupNo,State0),
                        State
                    end, #state{}, OprGroups),
    {ok,State1}.
        

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
    
handle_info({'DOWN', _Ref, process, GroupPid, _Reason},State=#state{groups=Groups,pids=GroupPids})->
    case maps:get(GroupPid,GroupPids,undefined) of
        #{groupno:=GroupNo}->
            {noreply,State#state{groups=maps:remove(GroupNo,Groups),pids=maps:remove(GroupPid,GroupPids)}};
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


