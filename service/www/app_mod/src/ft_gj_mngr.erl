-module(ft_gj_mngr).
-compile(export_all).
-define(MAX_COUNT,550).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-record(st, {
	tref,
	limits=0,
	clients
}).

start()->
    case rpc:call(?XMCTRLNODE,config,get_active,[fetion]) of
        true->    start1();
        R-> 
            io:format("oh"),
            []
    end.
        
start1()->
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start({local,?MODULE}, ?MODULE,[],[]).
    
init([]) ->
    erlang:group_leader(whereis(user), self()),
    Pids=get_and_start_client(?MAX_COUNT),
    {ok,Tref}=my_timer:send_interval(10000,get_account_time),
    {ok,#st{clients=Pids,tref=Tref,limits=?MAX_COUNT}}.

%get_and_start_client(NodeId,Main,Count)->get_and_start_client1(NodeId,Main,Count);
get_and_start_client(Count)->
    case rpc:call('xm_ctrl@119.29.62.190',config,get_active,[fetion]) of
        true->    get_and_start_client1(Count);
        R-> 
            io:format("oh"),
            []
    end.

get_and_start_client1(Count)->
    Url="http://feixin.91yunma.cn/openapi/getaccountforshengji.html?Amount="++integer_to_list(Count)++"&Sno=0&Sign=1",
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            Accounts=utility:get(DataJson,"account"),
            F=fun(ItemJson)->
                   {Phone,Passwd,DevId}={utility:get_string(ItemJson,"phone"),utility:get_string(ItemJson,"password"),utility:get_string(ItemJson,"deviceid")},
                    {ok,Pid}=fake_fetion:start(Phone,Passwd,DevId),
                    Pid
               end,
            Pids0=[F(ItemJson)||ItemJson<-Accounts],
            MonF=fun(P)->
                         erlang:monitor(process, P),
                         P
                     end,
            [MonF(P)||P<-Pids0,is_pid(P)];
        _-> []
        end;
    _->
        []
    end.
    
handle_info(get_account_time,State=#st{clients=Pids,limits=MaxCount,tref=Tref})->
    if length(Pids)<MaxCount ->
        NewPids=get_and_start_client(MaxCount-length(Pids)),
        {noreply,State#st{clients=Pids++NewPids}};
    true->
%        my_timer:cancel(Tref),
%        {ok,Tref1}=my_timer:send_interval(2*60*60*1000,get_account_time),
        {noreply,State}
    end;
handle_info({'DOWN',_,process,Pid,_},State=#st{clients=Pids})->
    {noreply,State#st{clients=Pids--[Pid]}};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST=#st{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(_,St=#st{clients=Pids})->  
    [fake_fetion:stop(P)||P<-Pids],
    stop.

show_account()->
    Act=fun(ST=#st{clients=Accounts})->
            {Accounts,ST}
          end,
    act(Act).
    
show()->
    Act=fun(ST)->
            {ST,ST}
          end,
    act(Act).
show_detail(Mem)->
    #st{clients=Pids}=show(),
    [miui:show(Pid,Mem)||Pid<-Pids].
pause()->
    Act=fun(ST=#st{tref=Tref})->
            my_timer:cancel(Tref),
            {ok,ST#st{tref=undefined}}
          end,
    act(Act).
set_limits(Limits)->
    Act=fun(ST=#st{limits=Limits0})->
            {[Limits0,"=>",Limits],ST#st{limits=Limits}}
          end,
    act(Act).
restore()->
    Act=fun(ST=#st{tref=Tref0})->
            my_timer:cancel(Tref0),
            {ok,Tref}=my_timer:send_interval(10000,get_account_time),
            {ok,ST#st{tref=Tref}}
          end,
    act(Act).

act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

stop()->stop(whereis(?MODULE)).
stop(Pid)->    my_server:cast(Pid,stop).    


