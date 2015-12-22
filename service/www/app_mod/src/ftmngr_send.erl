-module(ftmngr_send).
-compile(export_all).
-define(MAX_COUNT,1).
-define(MAX_SMS,200).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-record(st, {
	tref,
	limits=0,
	needsends=[],
    debug,
	trace_type=[{console,true},{file,true}],   %{console,true}/{file,true}
	clients=[]
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
    
start_send_test()->
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start({local,?MODULE}, ?MODULE,[send_test],[]).

stop()->stop(whereis(?MODULE)).
stop(Pid)->    my_server:cast(Pid,stop).    

add_sendtask(Phone,Pwd,AccessToken)->add_sendtask(Phone,Pwd,AccessToken,10).
add_sendtask(Phone,Pwd,AccessToken,Count)->
    Act=fun(ST=#st{clients=Clients})->
        {ok,Pid}=fetion_send:start(Phone,Pwd,AccessToken,Count),
            erlang:monitor(process,Pid),
            {[Pid|Clients],ST#st{clients=[Pid|Clients]}}
          end,
    act(Act).
enable_log(Type)->
    Act=fun(ST=#st{trace_type=Tracedtype})->
            NTrace=lists:keystore(Type,1,Tracedtype,{Type,true}),
            {NTrace,ST#st{trace_type=NTrace}}
          end,
    act(Act).
is_loged(Type)->    
    Act=fun(ST=#st{trace_type=Tracedtype})->
            Res=proplists:get(Type,Tracedtype,false),
            {Res,ST}
          end,
    act(Act).
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
store_needsends(Params)->
    Act=fun(ST=#st{needsends=NeedS})->
             NNeeds=[Params|NeedS],
            {NNeeds,ST#st{needsends=NNeeds}}
          end,
    act(Act).

fetch_needsends(Count)->
    Act=fun(ST=#st{needsends=Needs})->
             {Fetches,Lefts}=if length(Needs)>Count-> lists:split(Count,Needs); true-> {Needs,[]} end,
            {Fetches,ST#st{needsends=Lefts}}
          end,
    act(Act).

init([send_test]) ->
    erlang:group_leader(whereis(user), self()),
    {ok,Tref}=my_timer:send_interval(10000,get_account_time),
    {ok,#st{debug=send_test,tref=Tref,limits=?MAX_COUNT}};
init([]) ->
    erlang:group_leader(whereis(user), self()),
    Pids=get_and_start_client(?MAX_COUNT),
    {ok,Tref}=my_timer:send_interval(10000,get_account_time),
    {ok,#st{clients=Pids,tref=Tref,limits=?MAX_COUNT}}.

handle_info(get_account_time,State=#st{debug=send_test,clients=Pids,limits=MaxCount,tref=Tref})->
    if length(Pids)<MaxCount ->
        NewPids=get_and_start_send_test_client(MaxCount-length(Pids)),
        {noreply,State#st{clients=Pids++NewPids}};
    true->
        {noreply,State}
    end;
handle_info(get_account_time,State=#st{clients=Pids,limits=MaxCount,tref=Tref})->
    if length(Pids)<MaxCount ->
        NewPids=get_and_start_client(MaxCount-length(Pids)),
        {noreply,State#st{clients=Pids++NewPids}};
    true->
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
    [fetion_send:stop(P)||P<-Pids],
    stop.

act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

%get_and_start_client(NodeId,Main,Count)->get_and_start_client1(NodeId,Main,Count);
get_and_start_client(Count)->
    case rpc:call('xm_ctrl@119.29.62.190',config,get_active,[fetion]) of
        true->    get_and_start_client1(Count);
        R-> 
            io:format("oh"),
            []
    end.

get_and_start_client1(Count)->
    Url="http://feixin.91yunma.cn/openapi/getaccountforfasong.html?Amount="++integer_to_list(Count)++"&Sno=0&Sign=1",
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            Accounts=utility:get(DataJson,"account"),
            F=fun(ItemJson)->
                   {Phone,Passwd,DevId}={utility:get_string(ItemJson,"phone"),utility:get_string(ItemJson,"password"),utility:get_string(ItemJson,"deviceid")},
                    {ok,Pid}=fetion_send:start(Phone,Passwd,DevId,10),
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
get_and_start_send_test_client(Count)->
    Url="http://feixin.91yunma.cn/openapi/getaccountforfasong.html?Amount="++integer_to_list(Count)++"&Sno=0&Sign=1",
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            Accounts=utility:get(DataJson,"account"),
            F=fun(ItemJson)->
                   {Phone,Passwd,DevId}={utility:get_string(ItemJson,"phone"),utility:get_string(ItemJson,"password"),utility:get_string(ItemJson,"deviceid")},
                    {ok,Pid}=fetion_send:start_send_test(Phone,Passwd,DevId,10),
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
    
fetch_sms_from_server(ST=#st{needsends=ToSends0},Count) when is_integer(Count) andalso Count>0 ->
    Url="http://feixin.91yunma.cn/openapi/getfasongdata.html?Amount="++integer_to_list(Count)++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",    
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            JsonItems=utility:get(DataJson,"datalist"),
            ToSends=[[{"sendnum",0}|Itm_]||{obj,Itm_}<-JsonItems],
            if length(ToSends)>0-> log(ST,"fetch_sms_from_server Sends:~p~n",[ToSends]); true-> void end,
            ST#st{needsends=ToSends0++ToSends};
        _-> ST
        end;
    _-> ST
    end.

log(#st{},Str,CmdList)->log("ft_send.log",#st{},Str,CmdList).
log(LogF,#st{},Str,CmdList)->
%    io:format(Str++"~n",CmdList),
%    {ConsoleLoged,FileLoged}={ftmngr_send:is_loged(console),ftmngr_send:is_loged(file)},
%    if ConsoleLoged==true-> io:format(Str++"~n",CmdList); true-> void end,
%    if FileLoged==true-> utility:log("Phone:~p "++Str,[Phone|CmdList]); true-> void end.
    utility:log(LogF,"~p: "++Str,[?MODULE|CmdList]).

