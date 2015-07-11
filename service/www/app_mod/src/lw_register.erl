-module(lw_register).
-compile(export_all).
-include("lwdb.hrl").
-include("db_op.hrl").

do(Pls)->
    UUID0=proplists:get_value("uuid",Pls),
    UUID=uuid_key(UUID0),
    DvID=proplists:get_value("device_id",Pls,<<"">>),
    Name=proplists:get_value("name",Pls,<<"">>),
    Pwd=proplists:get_value("pwd",Pls,<<"">>),
    Group_id=proplists:get_value("group_id",Pls),
    Status=proplists:get_value("status",Pls,actived),
    if Name =/= <<"">>  ->  bind_name_uuid(Name,UUID); true-> void end,
    LR=#lw_register{uuid=UUID,device_id=DvID,name=Name, pwd=Pwd,group_id=Group_id},
    ?DB_WRITE(LR).
    
uuid_key(UUID) -> list_to_binary(login_processor:push_trans_caller(UUID)).    
name_key(Name) when is_list(Name)-> name_key(list_to_binary(Name));
name_key(Name) when is_binary(Name)-> Name.

get_register_info_by_uuid(UUID) -> ?DB_READ(lw_register,uuid_key(UUID)).
get_name_item(Name) -> ?DB_READ(name2uuid,name_key(Name)).

sms_register(Json)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
    DevId=utility:get_string(Json, "device_id"),
    case {get_register_info_by_uuid(UUID),lw_agent_oss:query_did_item(UUID)} of
    {{atomic,[#lw_register{}]},_}->  [{status,failed},{reason,account_already_exist}];
    {_,DidItem} when DidItem =/=undefined->  [{status,failed},{reason,account_already_exist},{other,did_no_conflict}];
    _->
        case sms_handler:auth_code(UUID++DevId) of
        AuthCode->
            {obj,Pls}=Json,
            do(Pls),
            [{status,ok}];
        _->
            [{status,failed},{reason,invalid_auth_code}]
        end
    end.
delegate_register(Json)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
    DevId=utility:get_string(Json, "device_id"),
    io:format("delegate_register:~p~n",[Json]),
    case lw_agent_oss:authenticate(UUID,AuthCode) of
    {ok,Status}->
        Name=utility:get_string(Json, "name"),
        Pwd=utility:get_string(Json, "pwd"),
        case {get_register_info_by_uuid(UUID), get_name_item(Name)} of
        {{atomic,[_I]}, _}-> [{status,failed},{reason,uuid_already_registered}];
        {_,{atomic,[_I]}}-> [{status,failed},{reason,username_already_existed}];
        _->        
            {obj,Pls}=Json,
            do([{status,Status}|Pls]),
            [{status,ok}]
        end;
    _->
        [{status,failed},{reason,invalid_auth_code}]
    end.

add_info(Json)->
    UUID=utility:get_string(Json, "uuid"),
    Info=utility:get_binary(Json, "info"),
    case get_register_info_by_uuid(UUID) of
    {atomic,[LR=#lw_register{pls=Pls}]}-> 
        NewPls=lists:keystore(info,1,Pls,{info,Info}),
        ?DB_WRITE(LR#lw_register{pls=NewPls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,account_not_exist}]
    end.
forgetpwd(Json)-> forgetpwd(Json,utility:get_binary(Json,"group_id")).
forgetpwd(Json,<<"common">>)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
    DevId=utility:get_string(Json, "device_id"),
    Pwd=utility:get_binary(Json,"pwd"),
    case isvalid_auth_code(AuthCode,UUID,DevId) of
    true->
        case get_register_info_by_uuid(UUID) of
        {atomic,[LR=#lw_register{name=Name}]}->  
            ?DB_WRITE(LR#lw_register{pwd=Pwd}),
            [{status,ok},{name,Name}];
        _->
            [{status,failed},{reason, account_not_exist}]
        end;
    _->
        [{status,failed},{reason,invalid_auth_code}]
    end;
forgetpwd(Json,<<"dth">>)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
    Name=utility:get_binary(Json, "name"),
    Pwd=utility:get_binary(Json,"pwd"),
    io:format("forgetpwd:~p~n",[Json]),
    case lw_agent_oss:authenticate(UUID,AuthCode) of
    {ok,_}->
        case get_register_info_by_uuid(UUID) of
        {atomic,[LR=#lw_register{name=Name}]}->  
            ?DB_WRITE(LR#lw_register{pwd=Pwd}),
            [{status,ok},{name,Name}];
        {atomic,[LR=#lw_register{}]}->  
            [{status,failed},{reason, username_not_match}];
        _->
            [{status,failed},{reason, account_not_exist}]
        end;
    _->
        [{status,failed},{reason,invalid_auth_code}]
    end.
    
modifypwd(Json)->
    OldPwd=utility:get_binary(Json, "old_pwd"),
    UUID=utility:get_string(Json, "uuid"),
%    DevId=utility:get_string(Json, "device_id"),
    Pwd=utility:get_binary(Json,"pwd"),
    case get_register_info_by_uuid(UUID) of
    {atomic,[LR=#lw_register{name=Name,pwd=OldPwd}]}->  
        ?DB_WRITE(LR#lw_register{pwd=Pwd}),
        [{status,ok},{name,Name}];
    {atomic,[_LR=#lw_register{}]}->  
        [{status,failed},{reason,incorrect_old_pwd}];
    _->
        [{status,failed},{reason, account_not_exist}]
    end.
    
isvalid_auth_code(AuthCode,UUID,DevId)->
    case sms_handler:auth_code(UUID++DevId) of
    AuthCode-> true;
    _-> false
    end.

bind_name_uuid(Name,UUID)->
    ?DB_WRITE(#name2uuid{name=name_key(Name),uuid=UUID}).
    
unbind_name_uuid(Name)->
    ?DB_DELETE({name2uuid,name_key(Name)}).
    
deregister(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{name=Name}]}->  
        ?DB_DELETE({name2uuid,name_key(Name)}),
        ?DB_DELETE({lw_register, uuid_key(UUID)}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.

set_didno(UUID, Did)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Npls=lists:keystore(did,1, Pls, {did,Did}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.

add_payids(UUID, Payids)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Payids0=proplists:get_value(payids,Pls,[]),
        Npls=lists:keystore(payids,1, Pls, {payids,Payids0++Payids}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
get_payrecord(Payid)->
    ?DB_READ(pay_record,Payid).
get_recharges(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pls=Pls}]}->  
        Payids=proplists:get_value(payids,Pls,[]),
        F=fun({atomic,[#pay_record{status=paid,paid_time=Ptime,money=M,coins=C}]})->
                    [{time,list_to_binary(utility:d2s(Ptime))},{money,M},{coins,C}];
                (_)-> []
            end,
        PayRecords=[get_payrecord(Id)||Id<-Payids],
        Array=[F(Item)||Item<-PayRecords],
        Recharges=utility:pl2jsos([Item||Item<-Array,Item=/=[]]),
        [{status,ok},{recharges,Recharges}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
    
add_coins(UUID, Added)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Coins0=proplists:get_value(coins,Pls,0),
        Npls=lists:keystore(coins,1, Pls, {coins,Coins0+Added}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
%talk_over(UUID,Charges) when is_number(Charges)->  consume_coins(UUID,Charges);
%talk_over(UUID,Pls) when is_list(Pls)->
%    Charges=proplists:get_value(charges,Pls,0),
%    consume_coins(UUID,Charges),
%    Cdr=proplists:get_value(cdr,Pls,[]),
consume_coins(UUID,Charges)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        GiftCoins=proplists:get_value(gift_coins,Pls,0),
        Coins=proplists:get_value(coins,Pls,0),
        Month0=proplists:get_value(month,Pls,0),
        {_,Month,_}=date(),
        MonthConsumed= if Month0=/=Month-> Charges; true-> Charges+proplists:get_value(month_consumed,Pls,0) end,
        {NewGift,NewCoins} = if 
                                           GiftCoins >=Charges->   {GiftCoins-Charges,Coins};
                                           Coins-Charges+GiftCoins >=0 -> {0,Coins-Charges+GiftCoins};
                                           true->{0,0}
                                       end,
        Changed = [{coins,NewCoins},{gift_coins,NewGift},{month,Month},{month_consumed,MonthConsumed}],
        Npls=lists:ukeymerge(1, Changed,Pls),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
    
get_coin(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Coins=proplists:get_value(coins,Pls,0),
        GCoins=proplists:get_value(gift_coins,Pls,0),
        MConsums=proplists:get_value(month_consumed,Pls,0),
        [{status,ok},{coins,Coins},{month_consumed,MConsums},{gift_coins,GCoins}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
    
transform_tables()->  %% for mnesia database updating, very good 
    Transformer = fun({lw_register,UUID,Dvid,Name,Pwd,Pls})->
                              #lw_register{uuid=UUID,device_id=Dvid,name=Name,pwd=Pwd,pls=Pls}
    				 end,
    {atomic,ok}=mnesia:transform_table(lw_register,Transformer, record_info(fields, lw_register) ).    
    
