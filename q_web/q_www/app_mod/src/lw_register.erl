-module(lw_register).
-compile(export_all).
-include("lwdb.hrl").
-include("login_info.hrl").
-include("db_op.hrl").

authcode_register(Json)->
    AuthCode=utility:get_string(Json, "auth_code"),
    Name=utility:get_string(Json, "acc"),
    Pwd=utility:get_string(Json, "pwd"),
    case pay:get_recharge_item(AuthCode) of
    RC=#recharge_authcode{status=unbinded,recharge=Charge,pls = Pls}->
        case get_name_item(Name) of
        {atomic,[_I]}-> [{status,failed},{reason,username_already_existed}];
        _->        
                LR=#lw_register{acc=Name, pwd=Pwd,balance=Charge,chargeids=[AuthCode]},
                ?DB_WRITE(LR),
                ?DB_WRITE(RC#recharge_authcode{status=binded,name=Name}),
                [{status,ok},{balance,Charge}]
        end;
    #recharge_authcode{status=binded,recharge=Charge,pls = Pls}->
        [{status,failed},{reason,auth_code_binded}];
    _->
        [{status,failed},{reason,invalid_auth_code}]
    end.

get_name_item(Name) -> ?DB_READ(lw_register,Name).

login({ Acc,  Pwd}) ->
    case get_name_item(Acc) of
    {atomic,[LR=#lw_register{pwd=Pwd,pls=Pls,balance=Balance,deadline=DeadLine,login_uuid=OLD_UUID}]}-> 
        UUID=pay:authcode("uuid"),
        NL=#login_itm{uuid=UUID,acc=Acc},
        ?DB_DELETE({login_itm,OLD_UUID}),
        ?DB_WRITE(NL),
        ?DB_WRITE(LR#lw_register{login_uuid=UUID}),
        [{status,ok},{uuid,UUID},{balance,Balance},{cookie,c},{deadline,utility:d2s(DeadLine)}];
    {atomic,[#lw_register{}]}-> [{status,failed},{reason,pwd_not_match}];
    _-> [{status,failed},{reason,account_not_existed}]
    end.

logout(UUID) ->
    ?DB_DELETE(login_itm,UUID).
recharge({Acc,AuthCode})->
    case {pay:get_recharge_item(AuthCode),get_name_item(Acc)} of
    {Recharge=#recharge_authcode{status=unbinded,recharge=Money}, {atomic,[LR=#lw_register{balance=Balance,chargeids=ChIds}]}}->
        ?DB_WRITE(Recharge#recharge_authcode{status=binded}),
        ?DB_WRITE(LR#lw_register{balance=Balance+Money,chargeids=[AuthCode|ChIds]}),
        [{status,ok},{balance,Balance+Money},{cookie,c},{deadline,utility:d2s(utility:date_after_n(30))}];
    _-> [{status,failed},{reason,unkown2}]
    end.
        
transform_tables()->  %% for mnesia database updating, very good 
    Transformer = fun()->
                              #lw_register{}
    				 end,
    {atomic,ok}=mnesia:transform_table(lw_register,Transformer, record_info(fields, lw_register) ).    

check(UUID)->check(UUID,0.001).
check(UUID,Fee)->
    case ?DB_READ(login_itm,UUID) of
    {atomic,[#login_itm{status=login,acc=Acc}]}->  
        case account_balance(Acc) of
        Bal when (is_float(Bal) orelse is_integer(Bal)) andalso Bal>=Fee-> ok;
        _-> no_money
        end;
    _-> no_logined
    end.

update_balance(Acc,Charge)->
    case get_name_item(Acc) of
    {atomic,[LR=#lw_register{balance=Balance}]}-> 
        NewB=if Balance>Charge-> Balance-Charge; true-> 0 end,
        ?DB_WRITE(LR#lw_register{balance=NewB}),
        NewB;
    _-> 
        io:format("update_balance exception! acc:~p~n",[Acc]),
        unexpect_exception
    end.
    
consume(UUID,Pls,Charge)->
    case {proplists:get_value(status,Pls), ?DB_READ(login_itm,UUID)} of
    {ok, {atomic,[#login_itm{acc=Acc}]}}->  
        NewB=update_balance(Acc,Charge),
        Pls++[{balance,NewB}];
    _-> Pls
    end.

get_itm_by_uuid(UUID)->
    case ?DB_READ(login_itm,UUID) of
    {atomic,[#login_itm{acc=Acc}]}->  
        get_name_item(Acc);
    _-> unlogined
    end.

account_balance(Acc)->    
    case get_name_item(Acc) of
    {atomic,[#lw_register{balance=Balance}]}->  Balance;
    _-> invalide_account
    end.

uuid_balance(UUID)->    
    case get_itm_by_uuid(UUID) of
    {atomic,[#lw_register{balance=Balance}]}->  Balance;
    _-> invalide_uuid
    end.

