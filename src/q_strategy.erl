-module(q_strategy).
-compile(export_all).

wq_trafic_stratigy(Phinfo)->
     {value, Calls} = app_manager:get_app_count(),
%     MaxCalls = avscfg:get(max_calls),
     SPer=avscfg:get_self_percent(),
     case {app_manager:get_app_count(), rpc:call('qtest1@14.17.107.196',app_manager,get_app_count,[]),
            {rpc:call('qtest1@14.17.107.196',qstart,get_qnos,[]),rpc:call('qtest1@14.17.107.196',qstart,get_status,[])},erlang:now()} of
        {{_,Calls},{_,Calls1},{Qnos,active},_} when Calls>50 andalso Calls1/Calls<SPer andalso is_list(Qnos) andalso length(Qnos)>0->
            rpc:call('qtest1@14.17.107.196',qstart,add_cid,[proplists:get_value(cid,Phinfo)]),
            {failure, over_load};
        {_,_,{Qnos,Status},{_,_,MSec}} when ((is_list(Qnos) andalso length(Qnos)==0) orelse Status=/=active) andalso (MSec rem 10) == 0->
            io:format("y"),
            {failure,over_load};
        _ ->
            can_call
        end.


