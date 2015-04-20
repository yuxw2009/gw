-module(stats).
-compile(export_all).

-define(SAMPLE_INTERVAL, 5000).

-define(ERROR_CALLS,10000).

-record(state, {call_stat=[], net_stat=[]}).

get_call_stats()->
    ?MODULE ! {call_stats, self()},
    receive
        {value, R}-> R
    after 5000-> timeout
    end.

get_net_stats()->
    ?MODULE ! {net_stats, self()},
    receive
        {value, R}-> R
    after 5000-> timeout
    end.

start()->
    case whereis(?MODULE) of
        undefined ->
            register(?MODULE, spawn(fun()-> init() end));
        _ -> pass
    end.


init()->
    timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    loop(#state{}).
	
loop(State)->
    receive
        Message -> 
	        loop(on_message(Message, State))
    end.

on_message({call_stats, From}, #state{call_stat=CallStats}=State)->
    From ! {value, CallStats},
    State;

on_message({net_stats, From}, #state{net_stat=NetStats}=State)->
    From ! {value, NetStats},
    State;
	
on_message({call_stats_report, CallStats}, State)->
	State#state{call_stat=CallStats};	

on_message({net_stats_report, NetStats}, State)->
    State#state{net_stat=NetStats};      
    
on_message(sample_timer, State)->
    timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    Self = self(),
    get_call_stats(Self),
    get_net_stats(Self),
    State;

on_message(_,S)-> S.    

get_call_stats(Parent) ->
    spawn(fun() ->
                Stats = [{memory,[0,10]}, {disk, [0, 10]}, {try_count, 2}],
                Nodes = rpc:call(ns:service_node(), wcg_disp, get_all_wcgs, []),
                PauseNodes = rpc:call(ns:service_node(), wcg_disp, get_pause_wcgs, []),
                F = fun({Node, Total},Error_Calls) ->
                        case rpc:call(Node, statistic, get, []) of
                        SS when is_list(SS)->
	                        {_,NCpu} = lists:keyfind(cpu_usage, 1, SS),
	                        {_,NCall} =  lists:keyfind(current_calls, 1, SS),
                            Qnos=proplists:get_value(qnos,SS),
                            Cpu_itm=if  Qnos == undefined-> list_to_binary(NCpu); true-> integer_to_binary(Qnos) end,
	                        Stats ++ [{status, up},{node, Node}, {cpu, Cpu_itm},{calls, [Total, NCall]}];
	                 _O->
	                     Stats ++ [{node,Node},{status,down},{calls, [Total, Error_Calls]},{cpu,0},{memory,[0,10]}]
	                 end
                    end,
                Parent ! {call_stats_report, [F(N,?ERROR_CALLS) || N<-Nodes]++[F(P,?ERROR_CALLS) || P<-PauseNodes]}
          end).

get_net_stats(Parent) ->
    spawn(fun() ->
            Nodes = rpc:call(ns:service_node(), wcg_disp, get_all_wcgs, []),
            F = fun({Node, _Total}) ->
                    case rpc:call(Node, net_stats, get, []) of
                    NS when is_list(NS)->  [{node, Node}, {net_stats, NS}];
                    _-> [{node, Node}, {net_stats, [<<"down   down   20131121_13:13:33\n">>]}]
                    end
                end,
            Parent ! {net_stats_report, [F(N) || N<-Nodes]}
          end).
    
    

