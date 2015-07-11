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
    RC=#recharge_authcode{status=unbinded,recharge=Charge}->
        case get_name_item(Name) of
        {atomic,[_I]}-> [{status,failed},{reason,username_already_existed}];
        _->        
            Balance = if is_number(Charge)->  Charge; true-> 0.0 end,
            Deadline= if Charge == month-> utility:date_after_n(30);
                             true-> date() 
                             end,            				
            ?DB_WRITE(#lw_register{acc=Name, pwd=Pwd,balance=Balance,deadline=Deadline,chargeids=[AuthCode]}),
            ?DB_WRITE(RC#recharge_authcode{status=binded,name=Name}),
            [{status,ok},{balance,Balance}]
        end;
    #recharge_authcode{status=binded}->
        [{status,failed},{reason,auth_code_binded}];
    _->
        [{status,failed},{reason,invalid_auth_code}]
    end.

get_name_item(Name) -> ?DB_READ(lw_register,Name).

login({ Acc,  Pwd}) ->
    Today=date(),
    case get_name_item(Acc) of
    {atomic,[_LR=#lw_register{pwd=Pwd,balance=Balance,deadline=DeadLine}]} when DeadLine<Today andalso Balance=<0.0-> 
        [{status,failed},{reason,no_money}];
    {atomic,[LR=#lw_register{pwd=Pwd,balance=Balance,deadline=DeadLine,login_uuid=OLD_UUID}]}-> 
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
    {Recharge=#recharge_authcode{status=unbinded,recharge=month}, {atomic,[LR=#lw_register{balance=Balance,chargeids=ChIds,deadline=Deadline0}]}}->
        ?DB_WRITE(Recharge#recharge_authcode{status=binded}),
        NewDeadline=utility:date_after_n(Deadline0,30),
        ?DB_WRITE(LR#lw_register{chargeids=[AuthCode|ChIds],deadline=NewDeadline}),
        [{status,ok},{balance,Balance},{cookie,month},{deadline,utility:d2s(NewDeadline)}];
    {Recharge=#recharge_authcode{status=unbinded,recharge=Money}, 
    		{atomic,[LR=#lw_register{balance=Balance,chargeids=ChIds,deadline=Deadline}]}} when is_number(Money)->
        ?DB_WRITE(Recharge#recharge_authcode{status=binded}),
        NewBal = if is_number(Balance)->Balance+Money;  true-> Money  end,
        ?DB_WRITE(LR#lw_register{balance=NewBal,chargeids=[AuthCode|ChIds]}),
        [{status,ok},{balance,NewBal},{cookie,money},{deadline,utility:d2s(Deadline)}];
    _-> [{status,failed},{reason,unkown2}]
    end.
        
transform_tables()->  %% for mnesia database updating, very good 
    Transformer = fun()->
                              #lw_register{}
    				 end,
    {atomic,ok}=mnesia:transform_table(lw_register,Transformer, record_info(fields, lw_register) ).    

check(UUID)->check(UUID,0.0).
check(UUID,Fee)->
    case ?DB_READ(login_itm,UUID) of
    {atomic,[#login_itm{status=login,acc=Acc}]}->  
        Today = date(),
        case get_name_item(Acc) of
        {atomic,[#lw_register{balance=Bal,deadline=Deadline}]} when ((is_float(Bal) orelse is_integer(Bal)) andalso Bal>=Fee) orelse Deadline>=Today-> 
            io:format("~p check ok,balance:~p, deadline:~p,uuid:~p~n",[Acc,Bal,Deadline,UUID]),
            {ok,Bal};
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

reset_pwd(Name,Pwd)->
    case get_name_item(Name) of
    {atomic,[Item=#lw_register{}]}->
        ?DB_WRITE(Item#lw_register{pwd= hex:to(crypto:md5(Pwd))});
    _-> no_item
    end.
