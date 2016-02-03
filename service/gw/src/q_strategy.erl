-module(q_strategy).
-compile(export_all).
-include("db_op.hrl").
-record(clidata_t,{key,value}).
-record(last_t,{key,value}).
-define(REP_NUM,2).
-define(ME_DIV_SB,2.0).
-define(SB_PERCNT,0.3).

wq_trafic_stratigy(Phinfo)->
    random:seed(os:timestamp()),
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
     SPer1 = if SPer<?ME_DIV_SB-> ?ME_DIV_SB; true-> SPer end,
    % io:format("sper:~p ",[SPer]),
     SelfCalls = app_manager:get_app_count(),
     Qtest1Calls=rpc:call('qtest1@14.17.107.196',app_manager,get_app_count,[]),
     {Qtest1Qnos,Qtest1Status}={rpc:call('qtest1@14.17.107.196',qstart,get_qnos,[]),rpc:call('qtest1@14.17.107.196',qstart,get_status,[])},
     Clidata=proplists:get_value(clidata,Phinfo),
     case {SelfCalls, Qtest1Calls,{Qtest1Qnos,Qtest1Status}} of
        {{_,Calls},{_,Calls1},{Qnos,active}} when ((Calls>50) orelse (Calls1+2<SPer1*Calls)) andalso is_list(Qnos) andalso length(Qnos)>0->
            %LastRes=last_res(),
            Qno_sb = proplists:get_value(qno,Phinfo,""),
            case is_beyond_times(Phinfo) of
            false->
                rpc:call('qtest1@14.17.107.196',qstart,add_cid,[{proplists:get_value(cid,Phinfo),{Clidata,Qno_sb,"7"}}]),
                {failure, transfer_mine};
            true-> can_call
            end;
        {_,{_,Calls1},_} when Calls1<2->
%            del_counter(Clidata),
            can_call_4sb(Phinfo);
        _->
            can_call
        end.

can_call_4sb(Phinfo)->
    case random:uniform(100) < ?SB_PERCNT*100 of
    true-> can_call;
    _-> {fake_call,[{disconnect_time,rand([21000,20000,22000,23000])}|Phinfo]}
    end;
can_call_4sb(Phinfo)->
    case proplists:get_value(clidata,Phinfo) of
    "1234"->  no_call;
    _->
        case random:uniform(100) < ?SB_PERCNT*100 of
        true-> can_call;
        _-> {fake_call,[{disconnect_time,rand([16000,17000,18000,19000])}|Phinfo]}
        end
    end.
rand(L)->
    random:seed(os:timestamp()),
    N=random:uniform(length(L)),
    lists:nth(N,L).
do_once()->
    mnesia:stop(),
    mnesia:create_schema([node()]),
    create_table().
create_table()->
    mnesia:start(),
    mnesia:create_table(last_t,[{attributes,record_info(fields,last_t)},{disc_copies,[node()]}]),
%    mnesia:create_table(clidata_t,[{attributes,record_info(fields,clidata_t)},{disc_copies,[node()]}]),
    ok.
%success_rate()-> 0.
-define(LASTNUM,100).
success_rate()-> case last_sum(last) of 
                 {S,L} when is_integer(L) andalso L>0 andalso is_integer(S) -> S/L;
                 _-> 0.0
             end.
update_last(CurFlag)-> update_key(CurFlag,last,?LASTNUM).

last_callfailed_num()->last_sum(lastcallfailed).

last_sum(Key)->last_sum1(?DB_READ(last_t,Key)).
last_sum1({atomic, [#last_t{value=L}]}) when is_list(L)-> {lists:sum(L),length(L)};
last_sum1(_)-> {0,0}.

% clidata_t must be cleared after some interval
is_beyond_times(Phinfo)->
     is_beyond_times(proplists:get_value(clidata,Phinfo),proplists:get_value(cid,Phinfo),proplists:get_value(qno,Phinfo)).

%is_beyond_times(_,_,_)->false;
%is_beyond_times(Clidata,Cid,Qno) when Clidata=="1234" orelse Cid=="18874284764" orelse Qno=="58209376"-> 
%    io:format("t~p",[{Clidata,Cid,Qno}]),
%    no_call;
is_beyond_times(_,Cid,_)->
     case add_counter(Cid) of
        Times when Times>?REP_NUM->  
            io:format(" b~pb ",[Times]),
%            if Times>=?REP_NUM-> del_counter(Clidata); true-> pass end,
%            del_counter(Clidata),
            true;
        Times-> 
%            io:format("nb~p ",[Times]),
            false
    end.
add_counter(Clidata)->
    mnesia:dirty_update_counter(clidata_t,Clidata,1).

del_counter(Clidata)-> 
    case  lists:member(clidata_t,  mnesia:system_info(tables)) of
    true-> ?DB_DELETE({clidata_t,Clidata});
    _-> pass
    end.
%update_last(_CurFlag)-> void;
update_lastcallfailed(CurFlag)-> update_key(CurFlag,lastcallfailed).

update_key(CurFlag,Key)-> update_key(CurFlag,Key,10).
update_key(CurFlag,Key,Count)->
    case ?DB_READ(last_t,Key) of
        {atomic, [Item=#last_t{value=A}]} when is_list(A) andalso length(A) >= Count->
            {NewA,_}=lists:split(Count,[CurFlag|A]),
%            io:format("newa:~p ",[NewA]),
            ?DB_WRITE(Item#last_t{value=NewA});
        {atomic, [Item=#last_t{value=A}]} when is_list(A)->?DB_WRITE(Item#last_t{value=[CurFlag|A]});
        _-> ?DB_WRITE(#last_t{key=Key,value=[CurFlag]})
    end.
    
% record last result
record_last(Res) when Res=="4" orelse Res=="0" orelse Res=="2" orelse Res=="6"-> record_last1(Res);
record_last(_)-> pass.

record_last1(Res)->  ?DB_WRITE(#last_t{key=last_res,value=Res}).
last_res()->
    case ?DB_READ(last_t,last_res) of
        {atomic, [#last_t{value=Res}]} when is_list(Res) andalso length(Res)==1 -> Res;
        _->  "7"
    end.
    
show_table(T)->
    case ?DB_QUERY(T) of
    {atomic,R}-> R;
    _-> 
        []
    end.