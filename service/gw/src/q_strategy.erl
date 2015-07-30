-module(q_strategy).
-compile(export_all).
-include("db_op.hrl").
-record(clidata_t,{key,value}).
-record(last10_t,{key,value}).
-define(REP_NUM,5).

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
     SucRate=success_rate(),
     SPer=(avscfg:get_self_percent())*(1-SucRate),
     io:format("sper:~p ",[SPer]),
     SelfCalls = app_manager:get_app_count(),
     Qtest1Calls=rpc:call('qtest1@14.17.107.196',app_manager,get_app_count,[]),
     {Qtest1Qnos,Qtest1Status}={rpc:call('qtest1@14.17.107.196',qstart,get_qnos,[]),rpc:call('qtest1@14.17.107.196',qstart,get_status,[])},
     Clidata=proplists:get_value(clidata,Phinfo),
     case {SelfCalls, Qtest1Calls,{Qtest1Qnos,Qtest1Status},erlang:now()} of
        {{_,Calls},{_,Calls1},{Qnos,active},_} when (Calls1+1<SPer*Calls) andalso is_list(Qnos) andalso length(Qnos)>0->
            case is_beyond_times(Phinfo) of
                false->
                    Qno_sb = proplists:get_value(qno,Phinfo,""),
                    %ToSBRes=if SucRate>0.4-> "7"; true-> "2" end,
                    ToSBRes="7",
                    rpc:call('qtest1@14.17.107.196',qstart,add_cid,[{proplists:get_value(cid,Phinfo),{Clidata,Qno_sb,ToSBRes}}]),
                    {failure, transfer_mine};
                true-> can_call
            end;
%        {_,_,{Qnos,Status},{_,_,MSec}} when ((is_list(Qnos) andalso length(Qnos)==0) orelse Status=/=active) ->
%            io:format("y"),
%            del_counter(Clidata),
%            {failure,over_load};
        _ ->
%            del_counter(Clidata),
            can_call
        end.


do_once()->
    mnesia:stop(),
    mnesia:create_schema([node()]),
    create_table().
create_table()->
    mnesia:start(),
    mnesia:create_table(last10_t,[{attributes,record_info(fields,last10_t)},{ram_copies,[node()]}]),
    mnesia:create_table(clidata_t,[{attributes,record_info(fields,clidata_t)},{ram_copies,[node()]}]),
    ok.
%success_rate()-> 0.
success_rate()->success_rate(?DB_READ(last10_t,last10)).
success_rate({atomic, [#last10_t{value=L}]}) when is_list(L)-> lists:sum(L)/10;
success_rate(_)-> 0.

is_beyond_times(Phinfo)->
     is_beyond_times(proplists:get_value(clidata,Phinfo),proplists:get_value(cid,Phinfo),proplists:get_value(qno,Phinfo)).
is_beyond_times(Clidata,Cid,Qno) when Clidata=="1234" orelse Cid=="18874284764" orelse Qno=="58209376"-> 
    io:format("t~p",[{Clidata,Cid,Qno}]),
    true;
is_beyond_times(Clidata,_,_)->
     case add_counter(Clidata) of
        Times when Times>?REP_NUM->  
            io:format("b~p ",[Times]),
            if Times>?REP_NUM-> del_counter(Clidata); true-> pass end,
%            del_counter(Clidata),
            true;
        Times-> 
            io:format("nb~p ",[Times]),
            false
    end.
add_counter(Clidata)->
    mnesia:dirty_update_counter(clidata_t,Clidata,1).

del_counter(Clidata)-> 
    case  lists:member(clidata_t,  mnesia:system_info(tables)) of
    true-> ?DB_DELETE({clidata_t,Clidata});
    _-> pass
    end.
%update_last10(_CurFlag)-> void;
update_last10(CurFlag)->
    case ?DB_READ(last10_t,last10) of
        {atomic, [Item=#last10_t{value=A}]} when is_list(A) andalso length(A) >= 10->
            {NewA,_}=lists:split(10,[CurFlag|A]),
%            io:format("newa:~p ",[NewA]),
            ?DB_WRITE(Item#last10_t{value=NewA});
        {atomic, [Item=#last10_t{value=A}]} when is_list(A)->?DB_WRITE(Item#last10_t{value=[CurFlag|A]});
        _-> ?DB_WRITE(#last10_t{key=last10,value=[CurFlag]})
    end.
