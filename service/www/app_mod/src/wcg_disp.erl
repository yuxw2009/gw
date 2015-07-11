-module(wcg_disp).
-compile(export_all).
-include("db_op.hrl").
-define(SWITCH_LEVEL, 50).
-record(wcg_conf,  {node, total}).   %% disk copy 
-record(wcg_queue, {key=stats, head=[],tail=[]}).            %% ram copy
-record(wcg_pause,  {node, total}).   %% disk copy 

-record(m_wcg_conf,  {node, total}).   %% disk copy 
-record(m_wcg_queue, {key=mobile, list=[]}).            %% ram copy

create_tables() ->
    mnesia:create_table(m_wcg_conf,[{attributes,record_info(fields,m_wcg_conf)},{disc_copies,[node()]}]),
    mnesia:create_table(m_wcg_queue,[{attributes,record_info(fields,m_wcg_queue)}]),

    mnesia:create_table(wcg_conf,[{attributes,record_info(fields,wcg_conf)},{disc_copies,[node()]}]),
    mnesia:create_table(wcg_pause,[{attributes,record_info(fields,wcg_pause)}]),
    mnesia:create_table(wcg_queue,[{attributes,record_info(fields,wcg_queue)}]).

delete_tables() ->
    mnesia:delete_table(m_wcg_conf),
    mnesia:delete_table(m_wcg_queue),

    mnesia:delete_table(wcg_conf),
    mnesia:delete_table(wcg_pause),
    mnesia:delete_table(wcg_queue).
init_db() ->
    create_tables(),
    init_wcg_queue().

add_wcg(Node) when is_atom(Node)->
    case rpc:call(Node, avscfg, get, [max_calls]) of
    Max when is_integer(Max)->  
        remove_pause_wcg(Node),
        add_wcg(Node,Max);
    E-> E
    end.
        
    
add_wcg(Node, Total) when is_atom(Node)->
    F = fun() ->
    	    case mnesia:read(wcg_conf, Node) of
    	    	[] ->
		    	    mnesia:write(#wcg_conf{node=Node, total=Total}),
		    	    case mnesia:read(wcg_queue, stats) of
		    	    	[]   ->
		    	            mnesia:write(#wcg_queue{tail=[Node]});
		    	        [WQ] ->
		    	            mnesia:write(WQ#wcg_queue{tail=[Node| WQ#wcg_queue.tail]})
		    	    end;
	    	_  -> 
	    	    pass    
	    end
        end,
    mnesia:activity(transaction, F).    

remove_wcg(Node) when is_atom(Node) ->
    remove_pause_wcg(Node),
    F = fun() ->
    	    mnesia:delete({wcg_conf, Node}),
    	    [WQ] = mnesia:read(wcg_queue, stats),
    	    mnesia:write(WQ#wcg_queue{head=lists:delete(Node, WQ#wcg_queue.head),
    	    	                      tail=lists:delete(Node, WQ#wcg_queue.tail)})
        end,
    mnesia:activity(transaction, F).    

pause_wcg(Node) when is_atom(Node)->
    remove_wcg(Node),
    F = fun() ->
    	    case mnesia:read(wcg_pause, Node) of
    	    	[] ->
		    	    mnesia:write(#wcg_pause{node=Node, total=0});
	    	_  -> 
	    	    pass    
	    end
        end,
    mnesia:activity(transaction, F).    

remove_pause_wcg(Node) when is_atom(Node)->
    F = fun() ->
    	    mnesia:delete({wcg_pause, Node})
    	    end,
    mnesia:activity(transaction, F).    

restore_wcg(Node) when is_atom(Node)-> 
    add_wcg(Node),
    remove_pause_wcg(Node).

restore_wcg(Node,Total) when is_atom(Node)->
    add_wcg(Node,Total),
    remove_pause_wcg(Node).

choose_wcg() ->
    F = fun() ->
    	    mnesia:read(wcg_queue, stats)
    	end,
    [Que=#wcg_queue{head=H,tail=T}] = mnesia:activity(transaction, F),
    Wcgs=H++T,
    Stats=[{Wcg, rpc:call(Wcg,statistic,get,[])}||Wcg<-Wcgs],
    Choosed=do_choose0(Stats),
    case Wcgs of
          []-> void;
	    [Choosed|_]-> void;
	    [Chosed0|_]->                
              io:format("~n~p:choose ~p => ~p~nlist:~p~n",[time(),Chosed0,Choosed,Stats]),
              if is_atom(Choosed) ->   ?DB_WRITE(Que#wcg_queue{head=[Choosed],tail=Wcgs--[Choosed]});
                 true-> void
              end
    end,
    Choosed.

rechoose()->
    F = fun() ->
    	    mnesia:read(wcg_queue, stats)
    	end,
    [Que=#wcg_queue{head=H,tail=T}] = mnesia:activity(transaction, F),
    [HeadWcg0|_]=Wcgs=H++T,
    Stats0=[{Wcg, rpc:call(Wcg,statistic,get,[])}||Wcg<-Wcgs],
    Stats=[Item||Item={_,Stat}<-Stats0, is_list(Stat)],
    [{NewHeadWcg,_}|_]= Stats_sorted=sort(Stats),
    if NewHeadWcg =/= HeadWcg0 ->
        io:format("~n~p:rechoose ~p => ~p~nlist:~p~n",[time(),HeadWcg0,NewHeadWcg,Stats_sorted]),
        ?DB_WRITE(Que#wcg_queue{head=[NewHeadWcg],tail=Wcgs--[NewHeadWcg]});
    true-> void
    end,
    NewHeadWcg.

sort(Stats)->
    NewStats = [Item||Item={_,Stat}<-Stats, is_list(Stat)],
    lists:sort(fun(I={_,Stat1},J={_,Stat2})-> 
                             proplists:get_value(current_calls,Stat1,1) < proplists:get_value(current_calls,Stat2,2) 
                        end, NewStats).
do_choose0(Stats) -> do_choose0(Stats,sort(Stats)).
do_choose0(Stats,[{Node,[{current_calls,0}|_]}|_]) -> Node;
do_choose0(Stats,_) -> 
    CallList=[Calls||{_,[{current_calls,Calls}|_]}<-Stats],
    do_choose1(Stats,lists:sum(CallList)).
do_choose1([{H,[{current_calls,Calls}|_]}|_T], AllCalls) when Calls<?SWITCH_LEVEL andalso(Calls/(AllCalls+1)<0.7)-> H;
do_choose1(W_Ss,_) -> do_choose(W_Ss,[]).
do_choose([],W_Ss)->
    case sort(W_Ss) of
    [{H_wcg,H_stat}|_]->   H_wcg;
    []->{error, no_wcg_conf}
    end;
do_choose([{H,[{current_calls,Calls}|_]}|_T],_) when Calls<3 -> H;
do_choose([H={_H_W,H_S}|T],R) when not is_list(H_S)-> 
    utility:delay(2000),
    do_choose(T,R);
do_choose([S|T],R) -> do_choose(T,[S|R]).

choose_wcg1() ->
    F = fun() ->
    	    [WQ] = mnesia:read(wcg_queue, stats),
    	    do_choose_wcg(WQ)
    	end,
    mnesia:activity(transaction, F).

choose_m_wcg() ->
    F = fun() ->
    	    case mnesia:read(m_wcg_queue, mobile) of
    	    [Wq=#m_wcg_queue{list=[H|T]}]->
    	        ?DB_WRITE(Wq#m_wcg_queue{list=T++[H]}),
    	        {ok,H};
    	    _->  {error, no_wcg_conf}
    	    end
    	end,
    mnesia:activity(transaction, F).

get_all_wcgs() ->
    F = fun() ->
    	    AK = mnesia:all_keys(wcg_conf),
    	    G  = fun(K) -> 
    	    	     [#wcg_conf{node=N,total=T}] = mnesia:read(wcg_conf, K), 
                     {N,T}
    	         end,
    	    [G(K) || K <- AK]
    	end,
    mnesia:activity(transaction, F).

get_pause_wcgs() ->
    F = fun() ->
    	    AK = mnesia:all_keys(wcg_pause),
    	    G  = fun(K) -> 
    	    	     [#wcg_pause{node=N,total=T}] = mnesia:read(wcg_pause, K), 
                     {N,T}
    	         end,
    	    [G(K) || K <- AK]
    	end,
    mnesia:activity(transaction, F).

call(SDP, Options) ->call(choose_wcg(),SDP, Options).
call(WcgNode,SDP, Options) ->
    case WcgNode of
    	{error, no_wcg_conf} -> no_wcg_conf;
    	Node ->
    	    do_call(Node, SDP, Options)
    end.
    	    

do_call(Node, SDP, Options) ->
    case rpc:call(Node, wkr, processVOIP, [SDP, Options]) of
        {successful,Session_id, Callee_sdp} ->
            {successful,Node,Session_id, Callee_sdp};
        R ->            
            utility:log("./wcg_err.log","rpc:call1 Node:~p failed,reason:~p, sdp:~p~n",[Node,R,SDP]),
            try_other_nodes(SDP, Options, lists:keydelete(Node, 1, get_all_wcgs()))
    end.

try_other_nodes(_, _, []) -> 
    utility:log("./wcg_err.log","rpc:call final all_wcg_call_failed~n",[]),
    all_wcg_call_failed;
try_other_nodes(SDP, Options, [{Node, _}|T]) -> 
    case rpc:call(Node, wkr, processVOIP, [SDP, Options]) of
        {successful,Session_id, Callee_sdp}->
            {successful,Node,Session_id, Callee_sdp};
        R ->            
%            utility:log("./wcg_err.log","rpc:call again Node:~p failed,reason:~p~n",[Node,R]),
            try_other_nodes(SDP, Options, T)
    end.


init_wcg_queue() ->
    F = fun() ->
    	    AK = mnesia:all_keys(wcg_conf),
    	    mnesia:write(#wcg_queue{head=AK, tail=[]})
    	end,
    mnesia:activity(transaction, F).    

do_choose_wcg(WQ) ->
    case WQ#wcg_queue.head of
	    [] -> 
	        case WQ#wcg_queue.tail of
	            [] -> 
	                {error, no_wcg_conf};
	            T  ->
	                NewWQ = WQ#wcg_queue{head=T, tail=[]}, 
	                mnesia:write(NewWQ),
                    do_choose_wcg(NewWQ)
	        end; 
	    [H|T] ->
	        mnesia:write(WQ#wcg_queue{head=T, tail=[H|WQ#wcg_queue.tail]}),
	        H
	end.

    
