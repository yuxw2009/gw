-module(miui_manager).
-compile(export_all).
-define(MAX_COUNT,20).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').
-define(INTERVAL,10000).
-define(INTERVAL_NUMS,1000).

-record(st, {
	java_node_id,
	main_obj,
	tref,
	limits=0,
	trace_phone,
	debug,
	sendnums=0,
	miui_clients
}).

start()->
    timer:sleep(1000),
    case rpc:call(?XMCTRLNODE,config,get_active,[xiaomi]) of
        true->    start1();
        R-> 
            io:format("oh"),
            []
    end.
        
start1()->start1(miui:java_path()).
start1(JavaPath) ->
%    detect_reboot(),
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start({local,?MODULE}, ?MODULE,[JavaPath],[]).

start_onlinecheck()-> my_server:start({local,?MODULE},?MODULE,[onlinecheck,get_accounts(),miui:java_path()],[]).

start_receivetest()->start_receivetest(get_accounts()).
start_receivetest(Ms)->
    my_server:start({local,?MODULE},?MODULE,[receive_test,Ms,miui:java_path()],[]).

start_prechecktest()->
    {ok,Pid}=my_server:start({local,?MODULE},?MODULE,[precheck_test,miui:java_path()],[]).

add_from_file(Fn)->
    add_sendtasks(get_accounts1(Fn)).

add_onlinetask([UserId,Phone,Sec,Token])->
    Act=fun(ST=#st{java_node_id=NodeId,main_obj=Main,miui_clients=Clients})->
        {ok,Pid}=miui:start_onlinecheck(NodeId,Main,"onlinecheck",UserId,Phone,Sec,Token),
        erlang:monitor(process,Pid),
        ST#st{miui_clients=[Pid|Clients]}
          end,
    cast(Act).
    
add_sendtasks(Ms)-> [add_sendtask(I)||I<-Ms].
add_sendtask([UserId,Phone,Sec,Token])->
    Act=fun(ST=#st{java_node_id=NodeId,main_obj=Main,miui_clients=Clients})->
        {ok,Pid}=miui:start_receive_test(NodeId,Main,"test",UserId,Phone,Sec,Token),
        erlang:monitor(process,Pid),
        ST#st{miui_clients=[Pid|Clients]}
          end,
    cast(Act).

announce_sendnum(AddNums)->
    Fun=fun(St=#st{sendnums=Sends0,miui_clients=Pids})->
               Sends=Sends0+AddNums,
               if (Sends div ?INTERVAL_NUMS) > (Sends0 div ?INTERVAL_NUMS)->
                   [miui:stop(P)||P<-Pids],
                   timer:sleep(2000),
                   restart_vpn(),
                   timer:sleep(10000),
                   flush_msg(get_account_time),
                   St#st{sendnums=Sends};
               true->
                   St#st{sendnums=Sends}
               end
           end,
    cast(Fun).
% *********************************************************************************
init([precheck_test,JavaPath]) -> 
    {ok,St}=init([JavaPath,fun get_and_start_precheck_client/3]),
    {ok,Tref}=my_timer:send_interval(?INTERVAL,get_account_time),
    {ok,St#st{tref=Tref,debug=precheck_test}};
init([onlinecheck,Ms,JavaPath]) -> 
    F=fun(NodeId,Main,_)->
        Rets=[miui:start_onlinecheck(NodeId,Main,"onlinecheck",UserId,Phone,Sec,Token)||[UserId,Phone,Sec,Token]<-Ms],
        Pids0=[P||{ok,P}<-Rets],
        MonF=fun(P)->
                     erlang:monitor(process, P),
                     P
                 end,
        [MonF(P)||P<-Pids0,is_pid(P)],
        Pids0
    end,
    init([JavaPath,F]);
init([receive_test,Ms,JavaPath]) -> 
    F=fun(NodeId,Main,_)->
        Rets=[miui:start_receive_test(NodeId,Main,"receive_test",UserId,Phone,Sec,Token)||[UserId,Phone,Sec,Token]<-Ms],
        Pids0=[P||{ok,P}<-Rets],
        MonF=fun(P)->
                     erlang:monitor(process, P),
                     P
                 end,
        [MonF(P)||P<-Pids0,is_pid(P)],
        Pids0
    end,
    init([JavaPath,F]);
    
init([JavaPath]) -> 
    {ok,St}=init([JavaPath,fun get_and_start_client/3]),
    {ok,Tref}=my_timer:send_interval(?INTERVAL,get_account_time),
    {ok,St#st{tref=Tref}};
init([JavaPath,Fun])->
    erlang:group_leader(whereis(user), self()),
%    io:format("cookie:~p~n",[erlang:get_cookie()]),
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[JavaPath]},{enable_gc,true}]),
%    io:format("88888888888888888888~p~n",[NodeId]),
    Main=java:new(NodeId,'com.miui.main.Main',[]),
%    io:format("9999999999999999999999~p~n",[Main]),
    St=#st{java_node_id=NodeId,main_obj=Main},
    Pids=Fun(NodeId,Main,?MAX_COUNT),
    {ok,St#st{miui_clients=Pids,limits=?MAX_COUNT}}.

handle_info(get_account_time,State=#st{miui_clients=Pids,java_node_id=NodeId,main_obj=Main,limits=MaxCount,debug=Debug})->
%    io:format("."),
    if length(Pids)<MaxCount ->
        NewPids=
            if Debug==precheck_test->
                get_and_start_precheck_client(NodeId,Main,MaxCount-length(Pids));
            true->
                get_and_start_client(NodeId,Main,MaxCount-length(Pids))
            end,
        {noreply,State#st{miui_clients=Pids++NewPids}};
    true->{noreply,State}
    end;
handle_info({'DOWN',_,process,Pid,_},State=#st{miui_clients=Pids})->
    {noreply,State#st{miui_clients=Pids--[Pid]}};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST=#st{java_node_id=NodeId}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.
handle_cast({act,Act}, ST) ->
    NST=Act(ST),
    {noreply,NST};
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(_,St=#st{java_node_id=NodeId,miui_clients=Pids,tref=Tref})->  
    [miui:stop(P)||P<-Pids],
    java:terminate(NodeId),
    timer:cancel(Tref),
    stop.

nodeid()->
    Act=fun(ST=#st{java_node_id=NodeId})->
            {NodeId,ST}
          end,
    act(Act).
show_account()->
    Act=fun(ST=#st{miui_clients=Accounts})->
            {Accounts,ST}
          end,
    act(Act).
    
show()->
    Act=fun(ST)->
            {ST,ST}
          end,
    act(Act).
show_detail(Mem)->
    #st{miui_clients=Pids}=show(),
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

cast(Act)->
    case whereis(?MODULE) of
    P when is_pid(P)->
        my_server:cast(P,{act,Act});
    _-> void
    end.

stop()->stop(whereis(?MODULE)).
stop(Pid)->    my_server:cast(Pid,stop).    


detect_reboot()->
    spawn(fun()-> detect_reboot(date()) end).
detect_reboot({_,_,Day})->
    Node=node(),
    NodeStr=atom_to_list(Node),
    [Name,Host]=string:tokens(NodeStr,"@"),
    Name1=if length(Name) == 3-> "xm11";true-> "xm1" end,
    NodeStr1=Name1++"@"++Host,
    Date={_,_,Day1}=date(),
    if Day1=/=Day-> 
        os:cmd("erl -pa ebin -name "++NodeStr1++" -setcookie HNJBZQNRSCBUBMWJKAIA -detached"),
        timer:sleep(2000),
        case net_adm:ping(list_to_atom(NodeStr1)) of
        pong->
            io:format("~p is up, me exit~n",[NodeStr1]),
            miui_manager:stop(),
            timer:sleep(2000),
            rpc:call(list_to_atom(NodeStr1),miui_manager,start,[]),
            timer:sleep(1000),
            init:stop();
        _-> io:format("~p is not up~n",[NodeStr1])
        end;
    true->
%        io:format("*"),
        timer:sleep(1000*60*10),
        detect_reboot(Date)
    end.

get_login_string(Sim_user_id,Phone,Sec0,Token0,Challenge)->
    Sec= [I||I<-Sec0,I=/=$-, I=/=$\\],
    Token= [I||I<-Token0,I=/=$-, I=/=$\\],
    Act=fun(St=#st{java_node_id=NodeId,main_obj=MainObj})->
        Sim_=java:new(NodeId,'java.lang.String',[Sim_user_id]),
        Phn_=java:new(NodeId,'java.lang.String',[Phone]),
        S_=java:new(NodeId,'java.lang.String',[Sec]),
        Token_=java:new(NodeId,'java.lang.String',[Token]),
        Challenge_=java:new(NodeId,'java.lang.String',[Challenge]),
        Login_=java:call(MainObj,login_package,[Sim_,Phn_,S_,Token_,Challenge_]),
        {LoginList=java:string_to_list(Login_),St}
    end,
    my_server:call(?MODULE,{act,Act}).

get_and_start_precheck_client(NodeId,Main,Count)->    get_and_start_client2(NodeId,Main,Count,precheck).
get_and_start_client(NodeId,Main,Count)->
    case rpc:call('xm_ctrl@119.29.62.190',config,get_active,[xiaomi]) of
        true->    get_and_start_client2(NodeId,Main,Count,undefined);
        R-> 
            io:format("oh"),
            []
    end.

get_and_start_client2(NodeId,Main,Count,Type)->
    Url= if Type==precheck->  "http://sms.91yunma.cn/openapi/getxmprecheckaccount.html?Type=precheck&Amount="++integer_to_list(Count);
             true->  "http://sms.91yunma.cn/openapi/getxmaccount2.html?Type=fasong&Amount="++integer_to_list(Count)
         end,
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJsons}-> 
            F=fun(ItemJson)->
                   Imsi=utility:get_string(ItemJson,"imsi"),
                   Content=utility:get_string(ItemJson,"content"),
                   case re:run(Content,"userID=(.*)&phone=(.*)&token=(.*)&sec=(.*)$",[{capture,all_but_first,list},ungreedy]) of
                   {match,[Sim_id,Phone,Token0,Sec0]}-> 
                       {Sec,Token}={http_uri:decode(Sec0),http_uri:decode(Token0)},
                       [Imsi,Sim_id,Phone,Sec,Token];
                   _-> undefined
                   end
               end,
            AllCountData0=[F(ItemJson)||ItemJson<-DataJsons],
            AllCountData=[I||I<-AllCountData0,I=/=undefined],
            F1=fun([Imsi,Sim_id,Phone,Sec,Token])->
                       case miui:start(Type,NodeId,Main,Imsi,Sim_id,Phone,Sec,Token) of
                       {ok,MiuiPid}->   MiuiPid;
                       _-> undefined
                       end
                 end,
            Pids00=[F1(I)||I<-AllCountData],
            Pids0=[I||I<-Pids00,I=/=undefined],
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
    
get_n_accounts(N)-> {First,_}=lists:split(N,get_accounts()), First.
get_accounts(N)->lists:nth(N,get_accounts()).
get_accounts()->get_accounts1("100miui_account.txt").
get_accounts1(Fn)->
    {_,Bin}= file:read_file(Fn),
    {_,Ms}=re:run(Bin,"userID=(.*)&phone=(.*)&token=(.*)&sec=(.*)\r?\n",[global,{capture,all_but_first,list},ungreedy]),
    [[UserId,Phone,Sec,Token]||[UserId,Phone,Token,Sec]<-Ms].

test_sends()->test_sends(<<"300285391">>).  %825704759  mf
test_sends(To)-> test_sends(To,miui_manager:show_account()).
test_sends(To,Ps)->test_sends(To,Ps,1).

test_sends(_,[],N)->N;
test_sends(To,[P|T],N)->
    miui:test_send(P,To,list_to_binary(integer_to_list(N))),
    test_sends(To,T,N+1).

log(Str,Cmds)-> 
    io:format(Str++"~n",Cmds),
    utility:log("xm.log","miui_manager: "++Str,Cmds).

restart_vpn()->
    os:cmd("service vpn restart").
flush_msg(Msg) ->
    receive Msg -> flush_msg(Msg)
     after 0 -> ok
     end.
