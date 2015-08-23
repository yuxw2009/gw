-module(lw_register).
-compile(export_all).
-include("lwdb.hrl").
-include("db_op.hrl").

do(Pls)-> do(Pls,undefined).
do(Pls,undefined)->
    UUID0=proplists:get_value("uuid",Pls),
    UUID=uuid_key(UUID0),
    DvID=proplists:get_value("device_id",Pls,<<"">>),
    Name=proplists:get_value("name",Pls,<<"">>),
    Pwd=proplists:get_value("pwd",Pls,<<"">>),
    Group_id=proplists:get_value("group_id",Pls),
    AuthCode=proplists:get_value("auth_code",Pls),
    if Name =/= <<"">>  ->  bind_name_uuid(Name,UUID); true-> void end,
    LR=#lw_register{uuid=UUID,device_id=DvID,name=Name, pwd=Pwd,group_id=Group_id},
    RegPls=LR#lw_register.pls,
    ?DB_WRITE(LR#lw_register{pls=[{auth_code,AuthCode}|RegPls]}).
    
uuid_key(UUID) -> list_to_binary(login_processor:push_trans_caller(UUID)).    
name_key(Name) when is_list(Name)-> name_key(list_to_binary(Name));
name_key(Name) when is_binary(Name)-> Name.

get_register_info_by_uuid(UUID) -> ?DB_READ(lw_register,uuid_key(UUID)).
get_name_item(Name) -> ?DB_READ(name2uuid,name_key(Name)).

get_third_reg_info(Acc) when is_list(Acc)->    get_third_reg_info(list_to_binary(Acc));
get_third_reg_info(Acc)->    ?DB_READ(third_reg_t,Acc).

delete_third_reg_t(Acc)-> ?DB_DELETE(third_reg_t,Acc).
add_third_reg(Params)-> 
    {Acc,Name,UUID}={proplists:get_value("acc",Params),proplists:get_value("name",Params),proplists:get_value("uuid",Params)},
    ?DB_WRITE(#third_reg_t{acc=Acc,name=Name,uuid=uuid_key(UUID),pls=[]}).
third_register(Acc="qq_"++_OpenId,Params)->
    io:format("third_register"),
    case login_processor:check_crc(Params) of
    true->
        Name=proplists:get_value("name",Params),
        case {get_third_reg_info(Acc),get_name_item(Name)} of
        {{atomic,[_I]}, _}-> utility:pl2jso_br([{status,failed},{reason,account_already_registered}]);
        {_,{atomic,[_I]}}-> utility:pl2jso_br([{status,failed},{reason,username_already_existed}]);
        _->    
            UUID=login_processor:gen_uuid(Acc),
            NewParams=[{"uuid",UUID}|Params],
            do(NewParams),
            add_third_reg(NewParams),
            login_processor:third_login(Acc,Params)
        end;
    _->  utility:pl2jso_br([{status,failed},{reason,crc_error}])
    end.
third_deregister(Acc="qq_"++_)->
    case get_third_reg_info(Acc) of
    {atomic,[#third_reg_t{uuid=UUID}]}-> 
        delete_third_reg_t(Acc),
        deregister(UUID);
    _->
        void
    end.
self_noauth_register(Params)->  % acc and name is same
    io:format("self_noauth_register:~p~n",[Params]),
    case login_processor:check_crc(Params) of
    true->
        Acc=proplists:get_value("acc",Params),
        case get_name_item(Acc) of
        {atomic,[_I]}-> utility:pl2jso_br([{status,failed},{reason,username_already_existed}]);
        _->    
            UUID=login_processor:gen_uuid(Acc),
            NewParams=[{"uuid",UUID}|Params],
            do(NewParams),
            login_processor:login(NewParams,<<"uuid">>)
        end;
    _->  utility:pl2jso_br([{status,failed},{reason,crc_error}])
    end.
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
    io:format("delegate_register:~p~n",[Json]),
    case lw_agent_oss:authenticate(UUID,AuthCode) of
    {ok,Status}->
        Name=utility:get_string(Json, "name"),
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
check_authcode(AuthCode,UUID,_)->
    case get_register_info_by_uuid(UUID) of
        {atomic,[LR=#lw_register{pls=Pls}]}->  
            case proplists:get_value(auth_code,Pls) of
            AuthCode-> {ok,LR};
            _-> {failed,invalid_auth_code}
            end;
        _->
            {failed,account_not_exist}
        end.
forgetpwd(Json)-> forgetpwd(Json,utility:get_binary(Json,"group_id")).
forgetpwd(Json={obj,Params},<<"dth_common">>)->
    io:format("forgetpwd:~p~n",[Params]),
    AuthCode=proplists:get_value( "auth_code",Params),
    Name=utility:get_string(Json, "name"),
    Pwd=utility:get_binary(Json,"pwd"),
    case get_name_item(Name) of
    {atomic,[#name2uuid{uuid=UUID}]}->  
        case check_authcode(AuthCode,UUID,<<"dth_common">>) of
        {ok,LR}->  
            ?DB_WRITE(LR#lw_register{pwd=Pwd}),
            NewParams=[{"uuid",UUID}|Params],
            login_processor:login(NewParams,<<"uuid">>);
        {failed,Reason}->
            utility:pl2jso_br([{status,failed},{reason, Reason}])
        end;
    _->
        utility:pl2jso_br([{status,failed},{reason, username_not_exist}])
    end;
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
            utility:pl2jso_br([{status,ok},{name,Name}]);
        _->
            utility:pl2jso_br([{status,failed},{reason, account_not_exist}])
        end;
    _->
        utility:pl2jso_br([{status,failed},{reason,invalid_auth_code}])
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
            utility:pl2jso_br([{status,ok},{name,Name}]);
        {atomic,[#lw_register{}]}->  
            utility:pl2jso_br([{status,failed},{reason, username_not_match}]);
        _->
            utility:pl2jso_br([{status,failed},{reason, account_not_exist}])
        end;
    _->
        utility:pl2jso_br([{status,failed},{reason,invalid_auth_code}])
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
        login_processor:del_account_tuple(uuid_key(UUID)),
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
consume_coins(UUID,Minutes)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls,group_id=GroupId}]}->  
        Charges=if GroupId== <<"common">> -> Minutes*3; true-> Minutes end,
        GiftCoins=proplists:get_value(gifts,Pls,0),
        Coins=proplists:get_value(lefts,Pls,0),
        Month0=proplists:get_value(month,Pls,0),
        {_,Month,_}=date(),
        MonthConsumed= if Month0=/=Month-> Charges; true-> Charges+proplists:get_value(month_consumed,Pls,0) end,
        {NewGift,NewCoins} = if 
                                           GiftCoins >=Charges->   {GiftCoins-Charges,Coins};
                                           Coins-Charges+GiftCoins >=0 -> {0,Coins-Charges+GiftCoins};
                                           true->{0,0}
                                       end,
        Changed = [{lefts,NewCoins},{gifts,NewGift},{month,Month},{month_consumed,MonthConsumed}],
        Npls=lists:ukeymerge(1, Changed,Pls),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
    
get_coin(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pls=Pls}]}->  
        Coins=proplists:get_value(lefts,Pls,0),
        GCoins=proplists:get_value(gifts,Pls,0),
        MConsums=proplists:get_value(month_consumed,Pls,0),
        [{status,ok},{lefts,Coins},{month_consumed,MConsums},{gifts,GCoins}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
    
transform_tables()->  %% for mnesia database updating, very good 
    Transformer = fun({lw_register,UUID,Dvid,Name,Pwd,Pls})->
                              #lw_register{uuid=UUID,device_id=Dvid,name=Name,pwd=Pwd,pls=Pls}
    				 end,
    {atomic,ok}=mnesia:transform_table(lw_register,Transformer, record_info(fields, lw_register) ).    

check_balance(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{group_id=GroupId,pls=Pls}]} when GroupId== <<"dth_common">> orelse GroupId== <<"common">> ->   % unit is minutes
        {Gifts,Lefts}={proplists:get_value(gifts,Pls),proplists:get_value(lefts,Pls)},
        {Gifts>=0 orelse Lefts>=0,Gifts+Lefts};
    _->
        {true,no_limit}
    end.

get_group_id(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{group_id=GroupId}]} ->   GroupId;
    _-> unregistered
    end.
    
