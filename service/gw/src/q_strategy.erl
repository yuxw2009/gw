-module(q_strategy).
-compile(export_all).
-include("db_op.hrl").
-record(clidata_t,{key,value}).

wq_trafic_stratigy(Phinfo)->
    case rpc:call('sb_control@119.29.62.190',config,active,[]) of
        true->    wq_trafic_stratigy1(Phinfo);
        R-> 
            Qno = proplists:get_value(qno,Phinfo,""),
            io:format("don'tcall reason:~p,q:~p~n",[R,Qno]),
            R
    end.
wq_trafic_stratigy1(Phinfo)->
     {value, Calls} = app_manager:get_app_count(),
%     MaxCalls = avscfg:get(max_calls),
     SPer=avscfg:get_self_percent(),
     SelfCalls = app_manager:get_app_count(),
     Qtest1Calls=rpc:call('qtest1@14.17.107.196',app_manager,get_app_count,[]),
     {Qtest1Qnos,Qtest1Status}={rpc:call('qtest1@14.17.107.196',qstart,get_qnos,[]),rpc:call('qtest1@14.17.107.196',qstart,get_status,[])},
     Clidata=proplists:get_value(clidata,Phinfo),
     case {SelfCalls, Qtest1Calls,{Qtest1Qnos,Qtest1Status},erlang:now()} of
        {{_,Calls},{_,Calls1},{Qnos,active},_} when (Calls1+1<SPer*Calls) andalso is_list(Qnos) andalso length(Qnos)>0->
            case is_beyond_times(Clidata) of
                false->
                    Qno_sb = proplists:get_value(qno,Phinfo,""),
                    rpc:call('qtest1@14.17.107.196',qstart,add_cid,[{proplists:get_value(cid,Phinfo),{Clidata,Qno_sb}}]),
                    {failure, transfer_mine};
                true-> can_call
            end;
        {_,_,{Qnos,Status},{_,_,MSec}} when ((is_list(Qnos) andalso length(Qnos)==0) orelse Status=/=active) 
            andalso (MSec rem round(1/(SPer+0.01))) == 0->
            io:format("y"),
            del_counter(Clidata),
            {failure,over_load};
        _ ->
            del_counter(Clidata),
            can_call
        end.


do_once()->
    mnesia:stop(),
    mnesia:create_schema([node()]),
    create_table().
create_table()->
    mnesia:start(),
    mnesia:create_table(clidata_t,[{attributes,record_info(fields,clidata_t)},{ram_copies,[node()]}]),
    ok.

is_beyond_times("1234")-> 
    io:format("t"),
    true;
is_beyond_times(Clidata)->
     case add_counter(Clidata) of
        Times when Times>2->  
            io:format("b"),
            del_counter(Clidata),
            true;
        _-> false
    end.
add_counter(Clidata)->
    mnesia:dirty_update_counter(clidata_t,Clidata,1).

del_counter(Clidata)-> ?DB_DELETE({clidata_t,Clidata}).
