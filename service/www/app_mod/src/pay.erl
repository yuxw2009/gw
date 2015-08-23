-module(pay).
-compile(export_all).
-include("db_op.hrl").
-include("lwdb.hrl").
-include("yaws_api.hrl").


handle(Arg,'GET', [])->
%    {ok, Json={obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("GET paytest:req:~n",[]),
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
    [UUID, Money,PayTypes,GroupId] =[utility:get_binary(Json,"uuid"),utility:get_integer(Json,"money"),utility:get_integer(Json,"pay_type"),utility:get_integer(Json,"group_id")],
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
    
        
            
payid()->
    integer_to_list(mnesia:dirty_update_counter(id_table, payid, 1)).
