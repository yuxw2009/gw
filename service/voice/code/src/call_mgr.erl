-module(call_mgr).
-compile(export_all).
-include("sipsocket.hrl").
-record(call_t,{caller,oppid,callee,tppid,calltype,starttime="not_talking",endtime,reason,op_sip_ip,tp_sip_ip,op_media_ip,tp_media_ip}).
-record(st,{callers=[]}).

start()->
    my_server:start({local,?MODULE}, ?MODULE,[],[]).
    
sip_incoming(Caller,"*0086"++Phone,Origin=#siporigin{addr="10.32.4.11"},SDP,OpPid)->
    call_tp(Caller,"000999180086"++Phone,Origin,SDP,OpPid);
sip_incoming(Caller,Callee,Origin=#siporigin{addr="10.32.4.11"},SDP,OpPid)->
    call_tp(Caller,Callee,Origin,SDP,OpPid).
    
call_tp(Caller,Callee,#siporigin{addr="10.32.4.11"},SDP,OpPid)->
    Act=fun(ST=#st{callers=Callers})->
            io:format("sip_incoming callers:~p~n",[Callers]),
            case lists:keyfind(Caller,#call_t.caller,Callers) of
            false->
                io:format("**********************************"),
                Options=[{phone,Callee},{uuid,{"sipantispy",Caller}},{cid,Caller}],
                TpPid=sip_tp:start_with_sdp(OpPid,Options,SDP),
                erlang:monitor(process,OpPid),
                {{ok,TpPid},ST#st{callers=[#call_t{caller=Caller,callee=Callee,oppid=OpPid,tppid=TpPid}|Callers]}};
            OldCall=#call_t{}->
                spy_traffic(Caller,Callee,OldCall),
                io:format("########################################"),
                {{failed,"duplicated calls"},ST}
            end
          end,
    act(Act).

enter_talking(OpPid)->
    Act=fun(ST=#st{callers=Callers})->
            case lists:keyfind(OpPid,#call_t.oppid,Callers) of
            CallItem=#call_t{}->
                NCallers=lists:keyreplace(OpPid,#call_t.oppid,Callers,CallItem#call_t{starttime=utility:ts()}),
                {ok,ST#st{callers=NCallers}};
            _->
                {no_item,ST}
            end
          end,
    act(Act).

show()->
    Act=fun(ST)-> {ST,ST} end,
    act(Act).
% callback for my_server
init([]) ->     {ok,#st{}}.

handle_info({'DOWN',_,process,Pid,_},State=#st{callers=Callers})->
    {value,CallItem,NCallers} =lists:keytake(Pid,#call_t.oppid,Callers),
    io:format("pid ~p down! ~p",[Pid,CallItem]),
    traffic(CallItem),
    {noreply,State#st{callers=NCallers}};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST=#st{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.
handle_cast({act,Act}, ST) ->
    NST=Act(ST),
    {noreply,NST};
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(_,_St=#st{})->  
    stop.

% my utility function
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

% my log function
spy_traffic(Caller,Callee,#call_t{callee=Callee0,starttime=StartTime})->
    utility:log("spy.log","~p ~p ~p ~p ~p",[utility:ts(),Caller,Callee,Callee0,StartTime]).
traffic(#call_t{caller=Caller,callee=Callee,starttime=StartTime})->
    utility:log("traffic.log","~p ~p ~p ~p",[Caller,Callee,StartTime,utility:ts()]);
traffic(_)-> void.
