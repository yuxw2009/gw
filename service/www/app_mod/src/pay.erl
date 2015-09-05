-module(pay).
-compile(export_all).
-include("db_op.hrl").
-include("lwdb.hrl").
-include("yaws_api.hrl").


handle(Arg,'GET', [])->
%    {ok, Json={obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("GET paytest:req:~n",[]),
    {html, "success"};
handle(Arg,'POST', ["package_pay"])->
%    io:format("~p~n",[Arg]),
    Params=yaws_api:parse_post(Arg),
    io:format("post paytest:req:~p~n",[Params]),
    PayId=proplists:get_value("out_trade_no",Params),
    Status=proplists:get_value("trade_status",Params),
    case [Status, ?DB_READ(pay_types_record,PayId)] of
    ["TRADE_SUCCESS",{atomic,[Item=#pay_types_record{status=paid}]}]->
         io:format("zhifubao:repeat~n"),
        void;
    ["TRADE_SUCCESS",{atomic,[Item=#pay_types_record{uuid=UUID,pkg_info=PkgInfo}]}]->
        lw_register:add_pkg(UUID,PkgInfo),
        lw_register:add_payids(UUID, [PayId]),
        ?DB_WRITE(Item#pay_types_record{pls=Params,status=paid,paid_time=erlang:localtime()});
    ["WAIT_BUYER_PAY",{atomic,[Item=#pay_record{}]}]->
        ?DB_WRITE(Item#pay_types_record{pls=Params});
    [Other]->
         io:format("zhifubao:other:~p~n",[Other])
    end,
    {html, "success"};
handle(Arg,'POST', [])->
%    io:format("~p~n",[Arg]),
    Params=yaws_api:parse_post(Arg),
    io:format("post paytest:req:~p~n",[Params]),
    PayId=proplists:get_value("out_trade_no",Params),
    Status=proplists:get_value("trade_status",Params),
    case [Status, ?DB_READ(pay_record,PayId)] of
    ["TRADE_SUCCESS",{atomic,[Item=#pay_record{status=paid}]}]->
         io:format("zhifubao:repeat~n"),
        void;
    ["TRADE_SUCCESS",{atomic,[Item=#pay_record{uuid=UUID,coins=Coins}]}]->
        lw_register:add_coins(UUID,Coins),
        lw_register:add_payids(UUID, [PayId]),
        ?DB_WRITE(Item#pay_record{pls=Params,status=paid,paid_time=erlang:localtime()});
    ["WAIT_BUYER_PAY",{atomic,[Item=#pay_record{}]}]->
        ?DB_WRITE(Item#pay_record{pls=Params});
    [Other]->
         io:format("zhifubao:other:~p~n",[Other])
    end,
    {html, "success"}.

gen_payment(Json)->  
    [UUID, Money,Coins] =[utility:get_binary(Json,"uuid"),utility:get_integer(Json,"money"),utility:get_integer(Json,"coins")],
    case  lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[_LR]} when Money>0 ->
        Payid=payid(),
        Payment=#pay_record{payid=Payid,uuid=UUID,status=to_pay,money=Money,coins=Coins,gen_time=erlang:localtime()},
        ?DB_WRITE(Payment),
        [{status,ok},{payid,Payid},{uuid,UUID}];
    {atomic,[]}->
        [{status,failed},{reason,account_not_existed}];
    _->
        [{status,failed},{reason,error_params}]
    end.
    
gen_types_payid(Json)->  
    MoneyStr=utility:get_string(Json,"money"),
    Money=element(1,string:to_integer(MoneyStr)),
    PayTypes=utility:get_atom(Json,"pay_type"),
    [UUID, GroupId] =[utility:get_binary(Json,"uuid"),utility:get_binary(Json,"group_id")],
    Package=get_package(GroupId,PayTypes),
    Price=proplists:get_value(price,Package),
    case  lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[_LR]} when Money==trunc(Price) ->
        Payid=payid(),
        {Period,Circles,Limits}={proplists:get_value(period,Package),proplists:get_value(circles,Package),proplists:get_value(limit,Package)},
        PkgInfo=#package_info{period=Period,cur_circle=1,from_date=date(),circles=Circles,gifts=0,limits=Limits,cur_consumed=0,payid=Payid,raw_pkginfo=Package},
        Payment=#pay_types_record{payid=Payid,uuid=UUID,status=to_pay,money=Money,gen_time=erlang:localtime(),pkg_info=PkgInfo},
        ?DB_WRITE(Payment),
        [{status,ok},{payid,Payid},{uuid,UUID}];
    {atomic,[]}->
        [{status,failed},{reason,account_not_existed}];
    _->
        [{status,failed},{reason,error_params}]
    end.
    
get_package(_GroupId,PayType)->
    {ok,Ps}=lw_mobile:packages_info(),
    TS=[list_to_tuple(I)||I<-Ps],
    TItem=lists:keyfind({type,PayType},1,TS),
    tuple_to_list(TItem).
            
payid()->
    integer_to_list(mnesia:dirty_update_counter(id_table, payid, 1)).
