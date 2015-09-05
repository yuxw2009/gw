-module(miui_manager).
-compile(export_all).
-define(MAX_COUNT,1).

-record(st, {
	java_node_id,
	main_obj,
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
    
        
start()->start(miui:java_path()).
start(JavaPath) ->
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start({local,?MODULE}, ?MODULE,[JavaPath],[]).
    
init([JavaPath]) ->
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[JavaPath]}]),
    Main=java:new(NodeId,'com.miui.main.Main',[]),
    St=#st{java_node_id=NodeId,main_obj=Main},
    Pids=get_and_start_client(?MAX_COUNT),
    my_timer:send_interval(10000,get_account_time),
    {ok,St#st{miui_clients=Pids}}.

get_and_start_client(Count)->
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
                       {Sec,Token}={cowboy_http:urldecode(list_to_binary(Sec0)),cowboy_http:urldecode(list_to_binary(Token0))},
                       {ok,MiuiPid}=miui:start(Imsi,Sim_id,Phone,binary_to_list(Sec),binary_to_list(Token)),
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
    
handle_info(get_account_time,State=#st{miui_clients=Pids})->
    if length(Pids)<?MAX_COUNT ->
        NewPids=get_and_start_client(?MAX_COUNT-length(Pids)),
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
terminate(_,St)->  stop.
stop()->stop(whereis(?MODULE)).
stop(Pid)->    my_server:cast(Pid,stop).    


