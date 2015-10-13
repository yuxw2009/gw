-module(miui_manager).
-compile(export_all).
-define(MAX_COUNT,200).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-record(st, {
	java_node_id,
	main_obj,
	tref,
	limits=0,
	miui_clients
}).

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
    
init([JavaPath]) ->
    erlang:group_leader(whereis(user), self()),
    io:format("cookie:~p~n",[erlang:get_cookie()]),
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[JavaPath]},{enable_gc,true}]),
    io:format("88888888888888888888~p~n",[NodeId]),
    Main=java:new(NodeId,'com.miui.main.Main',[]),
    io:format("9999999999999999999999~p~n",[Main]),
    St=#st{java_node_id=NodeId,main_obj=Main},
    Pids=get_and_start_client(NodeId,Main,?MAX_COUNT),
    {ok,Tref}=my_timer:send_interval(10000,get_account_time),
    {ok,St#st{miui_clients=Pids,tref=Tref,limits=?MAX_COUNT}}.

%get_and_start_client(NodeId,Main,Count)->get_and_start_client1(NodeId,Main,Count);
get_and_start_client(NodeId,Main,Count)->
    case rpc:call('xm_ctrl@119.29.62.190',config,get_active,[xiaomi]) of
        true->    get_and_start_client2(NodeId,Main,Count);
        R-> 
            io:format("oh"),
            []
    end.

get_and_start_client1(NodeId,Main,Count)->
    Url="http://sms.91yunma.cn/openapi/getxmaccount2.html?Type=fasong&Amount="++integer_to_list(Count),
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJsons}-> 
            F=fun(ItemJson)->
                   Imsi=utility:get_string(ItemJson,"imsi"),
                   Content=utility:get_string(ItemJson,"content"),
                   case re:run(Content,"sim_user_id%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bphone%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bst%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bsec%26quot%3B%3A%26quot%3B(.*)%26quot%3B",[{capture,all_but_first,list},ungreedy]) of
                   {match,[Sim_id,Phone,Token0,Sec0]}-> 
                       {Sec,Token}={http_uri:decode(Sec0),http_uri:decode(Token0)},
                       {ok,MiuiPid}=miui:start(NodeId,Main,Imsi,Sim_id,Phone,Sec,Token),
                       MiuiPid;
                   _-> undefined
                   end
               end,
            Pids0=[F(ItemJson)||ItemJson<-DataJsons],
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
    
get_and_start_client2(NodeId,Main,Count)->
    Url="http://sms.91yunma.cn/openapi/getxmaccount2.html?Type=fasong&Amount="++integer_to_list(Count),
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJsons}-> 
            F=fun(ItemJson)->
                   Imsi=utility:get_string(ItemJson,"imsi"),
                   Content=utility:get_string(ItemJson,"content"),
                   case re:run(Content,"sim_user_id%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bphone%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bst%26quot%3B%3A%26quot%3B(.*)%26quot%3B.*26quot%3Bsec%26quot%3B%3A%26quot%3B(.*)%26quot%3B",[{capture,all_but_first,list},ungreedy]) of
                   {match,[Sim_id,Phone,Token0,Sec0]}-> 
                       {Sec,Token}={http_uri:decode(Sec0),http_uri:decode(Token0)},
%                       {ok,MiuiPid}=miui:start(NodeId,Main,Imsi,Sim_id,Phone,Sec,Token),
%                       MiuiPid;
                       [Imsi,Sim_id,Phone,Sec,Token];
                   _-> undefined
                   end
               end,
            AllCountData0=[F(ItemJson)||ItemJson<-DataJsons],
            AllCountData=[I||I<-AllCountData0,I=/=undefined],
            rpc:call(?XMCTRLNODE,config,xm_accs,[AllCountData]),
            F1=fun([Imsi,Sim_id,Phone,Sec,Token])->
                       {ok,MiuiPid}=miui:start(NodeId,Main,Imsi,Sim_id,Phone,Sec,Token),
                       MiuiPid
                 end,
            Pids0=[F1(I)||I<-AllCountData],
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
    
handle_info(get_account_time,State=#st{miui_clients=Pids,java_node_id=NodeId,main_obj=Main,limits=MaxCount})->
    io:format("."),
    if length(Pids)<MaxCount ->
        NewPids=get_and_start_client(NodeId,Main,MaxCount-length(Pids)),
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
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(_,St=#st{java_node_id=NodeId,miui_clients=Pids,tref=Tref})->  
    [miui:stop(P)||P<-Pids],
    java:terminate(NodeId),
    timer:cancel(Tref),
    stop.

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
    
