-module(q_strategy).
-compile(export_all).

wq_trafic_stratigy(Phinfo)->
    case rpc:call('sb_control@119.29.62.190',config,active,[]) of
        true->    wq_trafic_stratigy1(Phinfo);
        R-> io:format("don'tcall reason:~p~n",[R])
    end.
wq_trafic_stratigy1(Phinfo)->
     {value, Calls} = app_manager:get_app_count(),
%     MaxCalls = avscfg:get(max_calls),
     SPer=avscfg:get_self_percent(),
     SelfCalls = app_manager:get_app_count(),
     Qtest1Calls=rpc:call('qtest1@14.17.107.196',app_manager,get_app_count,[]),
     {Qtest1Qnos,Qtest1Status}={rpc:call('qtest1@14.17.107.196',qstart,get_qnos,[]),rpc:call('qtest1@14.17.107.196',qstart,get_status,[])},
     case {SelfCalls, Qtest1Calls,{Qtest1Qnos,Qtest1Status},erlang:now()} of
        {{_,Calls},{_,Calls1},{Qnos,active},_} when Calls1<SPer*Calls andalso is_list(Qnos) andalso length(Qnos)>0->
            rpc:call('qtest1@14.17.107.196',qstart,add_cid,[{proplists:get_value(cid,Phinfo),proplists:get_value(clidata,Phinfo)}]),
            {failure, over_load};
        {{_,Calls},{_,Calls1},{Qnos,active},_} when Calls1==0 andalso Calls>1 andalso is_list(Qnos) andalso length(Qnos)>0->
%            rpc:call('qtest1@14.17.107.196',qstart,add_cid,[{proplists:get_value(cid,Phinfo),proplists:get_value(clidata,Phinfo)}]),
            {failure, over_load};
        {_,_,{Qnos,Status},{_,_,MSec}} when ((is_list(Qnos) andalso length(Qnos)==0) orelse Status=/=active) andalso (MSec rem 10) == 0->
            io:format("y"),
            {failure,over_load};
        _ ->
            can_call
        end.


