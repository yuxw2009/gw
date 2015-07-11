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
            
payid()->
    integer_to_list(mnesia:dirty_update_counter(id_table, payid, 1)).
    
% for recharge authcode
get_recharge_item(AuthCode)->
    case ?DB_READ(recharge_authcode,AuthCode) of
    {atomic,[I]}-> I;
    _-> undefined
    end.
create_recharge_authcodes(Charge,Count)->    create_recharge_authcodes(Charge,Count,[]).
create_recharge_authcodes(Charge,Count,Codes) when Count>0  -> 
    create_recharge_authcodes(Charge,Count-1,[create_recharge_authcode(Charge)|Codes]);
create_recharge_authcodes(_,_,Codes)-> Codes.


create_recharge_authcode(Charge)->   % Charge: month/ float/ int
    Auth=authcode(Charge),
    ?DB_WRITE(#recharge_authcode{authcode=Auth,recharge=Charge}),
    Auth.

authcode(Charge)->
    Chg=utility:term_to_list(Charge),
    {A,B,C}=erlang:now(),
    random:seed({A,B,C}),
    Rand=integer_to_list(random:uniform(100000)),
    Chg++integer_to_list(A)++integer_to_list(B)++integer_to_list(C)++Rand.
