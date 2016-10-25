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
    ?DB_WRITE(LR#lw_register{pls=[{auth_code,AuthCode}|RegPls]}),
    ?DB_WRITE(#devid_reg_t{devid=DvID,pls=Pls}),
    add_openim_id(UUID),
    pay:gift_for_reg(UUID).
    
uuid_key(UUID) -> list_to_binary(login_processor:push_trans_caller(UUID)).    
name_key(Name) when is_list(Name)-> name_key(list_to_binary(Name));
name_key(Name) when is_binary(Name)-> Name.

get_register_info_by_uuid(UUID) -> ?DB_READ(lw_register,uuid_key(UUID)).
get_name_item(Name) -> ?DB_READ(name2uuid,name_key(Name)).

get_third_reg_info(Acc) when is_list(Acc)->    get_third_reg_info(list_to_binary(Acc));
get_third_reg_info(Acc)->    ?DB_READ(third_reg_t,Acc).

delete_third_reg_t(Acc) when is_list(Acc)-> 
    io:format("delete_third_reg_t"),
    delete_third_reg_t(list_to_binary(Acc));
delete_third_reg_t(Acc)-> ?DB_DELETE(third_reg_t,Acc).
add_third_reg(Params)-> 
    {Acc,Name,UUID}={proplists:get_value("acc",Params),proplists:get_value("name",Params),proplists:get_value("uuid",Params)},
    ?DB_WRITE(#third_reg_t{acc=Acc,name=Name,uuid=uuid_key(UUID),pls=[]}).
third_register(Acc="wx_"++_OpenId,Params)->third_register1(Acc,Params);
third_register(Acc="qq_"++_OpenId,Params)->third_register1(Acc,Params).
third_register1(Acc,Params)->
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
third_deregister1(Acc)->
    case get_third_reg_info(Acc) of
    {atomic,[#third_reg_t{uuid=UUID}]}-> 
        delete_third_reg_t(Acc),
        deregister(UUID);
    _->
        void
    end.
delete_devid_reg_t(DvID)->
    ?DB_DELETE({devid_reg_t,DvID}).
%self_noauth_register(Params)-> self_noauth_register1(Params); % temporary don't limit user login for account num consideration
self_noauth_register(Params)->  % acc and name is same
%    io:format("self_noauth_register:~p~n",[Params]),
    DvID=proplists:get_value("device_id",Params),
    case ?DB_READ(devid_reg_t,DvID) of
    {atomic,[_I=#devid_reg_t{pls=Pls}]}-> 
        Name=proplists:get_value("name",Pls),
        UUID=proplists:get_value("uuid",Pls),
        utility:pl2jso_br([{status,failed},{reason,device_registered},{name,Name},{uuid,UUID}]);
    _-> self_noauth_register1(Params)
    end.
self_noauth_register1(Params)->  % acc and name is same
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

get_register_info_by_phone("")-> [];
get_register_info_by_phone(Phone) -> mnesia:dirty_index_read(lw_register,uuid_key(Phone),phone).
    
bind_phone(Json)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
    Phone=utility:get_string(Json, "phone"),
    DevId=utility:get_string(Json, "device_id"),
    case {lw_register:get_register_info_by_uuid(UUID), lw_register:get_register_info_by_phone(Phone)} of
    {{atomic,[_]},[_|_]} when Phone=/="13788927293",Phone=/="18296131759"->  
        utility:pl2jso_br([{status,failed},{reason, phone_already_bind}]);
    {{atomic,[RegItem=#lw_register{}]},_} ->  
        case sms_handler:auth_code(UUID++DevId) of
        AuthCode->
            mnesia:dirty_write(RegItem#lw_register{phone=uuid_key(Phone)}),
            [{status,ok}];
        _->
            [{status,failed},{reason,invalid_auth_code}]
        end;    
    _->
        [{status,failed},{reason,account_not_exist}]
    end.
delegate_register(Json)->
    AuthCode=utility:get_string(Json, "auth_code"),
    UUID=utility:get_string(Json, "uuid"),
%    io:format("delegate_register:~p~n",[Json]),
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
    UUID=
    case get_name_item(Name) of
    {atomic,[#name2uuid{uuid=UUID_}]}->  UUID_;
    _->
        Name
    end,
    case check_authcode(AuthCode,UUID,<<"dth_common">>) of
    {ok,LR}->  
        ?DB_WRITE(LR#lw_register{pwd=Pwd}),
        NewParams=[{"uuid",UUID}|Params],
        login_processor:login(NewParams,<<"uuid">>);
    {failed,Reason}->
        utility:pl2jso_br([{status,failed},{reason, Reason}])
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
    {atomic,[#lw_register{name=Name,device_id=DvID}]}->  
        ?DB_DELETE({name2uuid,name_key(Name)}),
        ?DB_DELETE({lw_register, uuid_key(UUID)}),
        delete_devid_reg_t(DvID),
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
get_payrecord(G,Payid) when is_binary(G)->get_payrecord(binary_to_list(G),Payid);
get_payrecord(GroupId,Payid) when GroupId=="dth_common" orelse GroupId=="zy_common"->
    ?DB_READ(pay_types_record,Payid);
get_payrecord(_,Payid)->
    ?DB_READ(pay_record,Payid).
get_recharges(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pls=Pls,group_id=GrpId}]}->  
        Payids=proplists:get_value(payids,Pls,[]),
        F=fun({atomic,[#pay_record{status=paid,paid_time=Ptime,money=M,coins=C}]})->
                    [{time,list_to_binary(utility:d2s(Ptime))},{money,M},{coins,C}];
                ({atomic,[#pay_types_record{status=paid,paid_time=Ptime,money=M,pkg_info=#package_info{raw_pkginfo=RawPkg}}]})->
                    Append=[{time,list_to_binary(utility:d2s(Ptime))},{money,M}],
                    if is_list(RawPkg)-> RawPkg++Append; true-> Append end;
                (_)-> []
            end,
        PayRecords=[get_payrecord(GrpId,Id)||Id<-Payids],
        Array=[F(Item)||Item<-PayRecords],
        Recharges=utility:pl2jsos_br([Item||Item<-Array,Item=/=[]]),
        [{status,ok},{recharges,Recharges}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.

get_pkgs(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pls=Pls}]}->  
        proplists:get_value(pkgs,Pls,[]);
    _-> []
    end.

add_pkg(UUID, #package_info{period=zy_coins,raw_pkginfo=RawInfo})->
    Added=proplists:get_value(quatity,RawInfo,0.0),
    add_coins(UUID,Added);
add_pkg(UUID, Pkg)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Pkgs0=proplists:get_value(pkgs,Pls,[]),
        Npls=lists:keystore(pkgs,1, Pls, {pkgs,Pkgs0++[Pkg]}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
del_pkg(UUID, PayId)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Pkgs0=proplists:get_value(pkgs,Pls,[]),
        Pkgs=[I||I=#package_info{payid=PayId_}<-Pkgs0,PayId=/=PayId_],
        Npls=lists:keystore(pkgs,1, Pls, {pkgs,Pkgs}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
get_coins(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[_Item=#lw_register{pls=Pls}]}->  
        proplists:get_value(qu_coin,Pls,0);
    _->
        0
    end.
add_coins(UUID, Added)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls}]}->  
        Coins0=proplists:get_value(qu_coin,Pls,0),
        NewCoins=trunc((Coins0+Added)*100)/100,
        Npls=lists:keystore(qu_coin,1, Pls, {qu_coin,NewCoins}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
del_coins(UUID, Added)->
    add_coins(UUID,-Added).
circles(Type,FromDate)-> circles(Type,FromDate,date()).
circles(month,FromDate,ToDate)->
    {Y0,M0,D0}=FromDate,
    {Y,M,D}=ToDate,
    (Y-Y0)*12+M-M0+ if D>=D0-> 1; true-> 0 end.
package_consume([],_)-> [];
package_consume([[]|T],Mins)-> package_consume(T,Mins);
package_consume([_H=#package_info{circles=Circles0}|T], Mins) when (Circles0==undefined)->
    package_consume(T,Mins);
package_consume([H=#package_info{period=Period,cur_circle=CurCircle0,from_date=FromDate,circles=Circles0,limits=Limits,cur_consumed=Consumed0}|T],
                                Mins) when is_integer(Circles0)->
    CurCircle=circles(Period,FromDate),
    if  CurCircle> Circles0 orelse (CurCircle==Circles0 andalso Consumed0+Mins>=Limits)-> package_consume(T,Mins);
        CurCircle>CurCircle0-> [H#package_info{cur_circle=CurCircle,cur_consumed=Mins}|T];
        Consumed0+Mins>=Limits-> [package_consume(T,Consumed0+Mins-Limits)]++[H#package_info{cur_consumed=Limits}];
        true-> [H#package_info{cur_consumed=Consumed0+Mins}|T]
    end.
consume_minutes(UUID,Minutes)->
    io:format("consume_minutes called:~p~n",[{UUID,Minutes}]),
    case get_register_info_by_uuid(UUID) of
    {atomic,[Item=#lw_register{pls=Pls,group_id=GroupId}]}->  
        Pkgs=proplists:get_value(pkgs,Pls,[]),
        NewPkgs=package_consume(Pkgs,Minutes),
        Npls=lists:keystore(pkgs,1,Pls,{pkgs,NewPkgs}),
        ?DB_WRITE(Item#lw_register{pls=Npls}),
        [{status,ok},{pkg_consume,Minutes}];
    _->
        [{status,failed},{reason,register_uuid_not_existed},{pkg_consume,Minutes}]
    end.
zy_consume_func(UUID,PhoneMinutes)->  zy_consume_func(UUID,PhoneMinutes,[]).
zy_consume_func(_UUID,[],Res)->  
    {PkgMinuteList,CoinList}=lists:unzip(Res),
    [{pkg_consume,lists:sum(PkgMinuteList)},{coins,lists:sum(CoinList)}];
zy_consume_func(UUID,[H|T],Res)->  
    Pls=zy_consume_func1(UUID,[H]),
    Item={_PkgMins,_Coins}={proplists:get_value(pkg_consume,Pls,0),proplists:get_value(coins,Pls,0)},
    zy_consume_func(UUID,T,[Item|Res]).

zy_consume_func1(UUID,[{Callee,Minutes}])->
    case get_group_id(UUID) of
    <<"zy_common">> ->
        zy_consume_voip(UUID,Minutes,voice_handler:formal_callee(Callee));
    _->
        consume_minutes(UUID,Minutes)
    end.	       
zy_consume_voip(UUID,Minutes,Callee)->
    io:format("zy_consume_voip called:~p called:~p~n",[{UUID,Minutes},Callee]),
    zy_consume_voip1(UUID,Minutes,Callee).
zy_consume_voip1(UUID,Minutes,Callee="0086"++_)->
    case check_balance(UUID) of
    {true,no_limit}-> 
        [{pkg_consume,Minutes},{coins,0}];
    {false, _}->  
        Coins=zy_consume_coins(UUID,Minutes,Callee),
        [{pkg_consume,0},{coins,Coins}];
    {true,Bal} when is_integer(Bal) andalso Bal > Minutes->  
        consume_minutes(UUID,Minutes),
        [{pkg_consume,Minutes},{coins,0}];
    {true,Bal} when is_integer(Bal)->  
        consume_minutes(UUID,Bal),
        Coins=zy_consume_coins(UUID,Minutes-Bal,Callee),
        [{pkg_consume,Bal},{coins,Coins}]
    end;
zy_consume_voip1(UUID,Minutes,Callee)->
    Coins=zy_consume_coins(UUID,Minutes,Callee),
    [{pkg_consume,0},{coins,Coins}].
    
zy_consume_coins(UUID,Minutes,Callee)-> 
    [{Callee,Rate}]=pay:get_rates(get_group_id(Callee),voip,[Callee]),
    Trans=fun(Coins)->
                 if Coins*100>trunc(Coins*100)-> trunc(Minutes*Rate*100+1)/100;
                 true-> trunc(Coins*100)/100
                 end end,
    Coins=Trans(Minutes*Rate),
    del_coins(UUID,Coins),
    Coins.
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
        [{pkg_consume,Minutes},{coins,0}];
    _->
        []
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
    
get_pkginfo(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pls=Pls}]}->  
        Coins=utility:value2binary(get_coins(UUID)),
        case package_consume(proplists:get_value(pkgs,Pls,[]),0) of
        [#package_info{cur_consumed=Consumed,gifts=Gifts,limits=Limits,from_date=From,circles=Circles}|_] 
                    when Limits>0->
            {Year,Mon,Day}=From,
            LeftMonths= Mon+Circles,
            NYear=Year+(LeftMonths div 13),
            NMon=(LeftMonths div 13)+(LeftMonths rem 13),
            Expire=integer_to_list(NYear)++"/"++integer_to_list(NMon)++"/"++integer_to_list(Day),
            Lefts=if is_number(Limits)-> round(Limits-Consumed); Limits==unlimit-> 99999999; true-> Limits end,
            [{status,ok},{lefts,Lefts},{cur_consumed,round(Consumed)},{gifts,Gifts},{expir_date,list_to_binary(Expire)},{coins,Coins}];
        []-> [{status,ok},{lefts,0},{coins,Coins}]
        end;
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.
max_minutes(UUID,Callee)->max_minutes2(UUID,voice_handler:formal_callee(Callee)).
max_minutes2(UUID,Callee)-> max_minutes2(UUID,Callee,lw_register:get_group_id(UUID)).
max_minutes2(UUID,Callee= [A,B,C,D|_],<<"zy_common">>) when [A,B,C,D]=/="0086"->   %international for zhiyu
    GroupId=lw_register:get_group_id(UUID),
    [{Callee,Rate}]=pay:get_rates(GroupId,voip,[Callee]),
    Coins0= get_coins(UUID),
    trunc(Coins0/Rate);
max_minutes2(UUID,Callee,<<"zy_common">>)->     %national
    GroupId=lw_register:get_group_id(UUID),
    Lefts0=
        case check_balance(UUID) of
        {false,_}-> 0;
        {true,Val} when is_integer(Val) orelse is_float(Val)->  Val;
        {true,no_limit}->   999999
        end,
    [{Callee,Rate}]=pay:get_rates(GroupId,voip,[Callee]),
    Coins0= get_coins(UUID),
    Lefts0+trunc(Coins0/Rate);
max_minutes2(UUID,Callee,_)->     %dth/dth_common user
    case check_balance(UUID) of
    {false,_}-> 0;
    {true,Val} when is_integer(Val) orelse is_float(Val)->  Val;
    {true,no_limit}->   999999
    end.

max_minutes1(UUID,Callee="0086"++_)->     %national
    GroupId=lw_register:get_group_id(UUID),
    Lefts0=
        case check_balance(UUID) of
        {false,_}-> 0;
        {true,Val} when is_integer(Val) orelse is_float(Val)->  Val;
        {true,no_limit}->   999999
        end,
    [{Callee,Rate}]=pay:get_rates(GroupId,voip,[Callee]),
    Coins0= get_coins(UUID),
    Lefts0+trunc(Coins0/Rate);
max_minutes1(UUID,Callee="00"++_)->    %internatinal
    GroupId=lw_register:get_group_id(UUID),
    [{Callee,Rate}]=pay:get_rates(GroupId,voip,[Callee]),
    Coins0= get_coins(UUID),
    trunc(Coins0/Rate).    
check_balance(UUID)-> check_balance1(UUID,"0086").
check_balance1(UUID,Callee="0086"++_)-> check_balance(UUID,Callee,national);
check_balance1(UUID,Callee="00"++_)->check_balance(UUID,Callee,international).
check_balance(UUID,_Callee,Type)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{group_id=GroupId,pls=Pls}]}  when GroupId =/= <<"dth">> ->   % unit is minutes
        PkgInfos=get_pkginfo(UUID),
        case proplists:get_value(status,PkgInfos) of
        ok->
            [Gifts,Lefts]=[proplists:get_value(gifts,PkgInfos,0),proplists:get_value(lefts,PkgInfos,0)],
            {Gifts>=0 orelse Lefts>=0,Gifts+Lefts};
        _-> {false, balance_not_enough}
        end;
    _->
        {true,no_limit}
    end.

get_group_id(UUID)->
    case get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{group_id=GroupId}]} ->   GroupId;
    _-> unregistered
    end.

add_openim_id(UserId,Nickname,PortraitUrl)->
    F=fun()->
        Pwd= hex:to(crypto:md5(<<"888888">>)),
        Iolist= ["php /home/ubuntu/wcg/www/docroot/openim/adduser.php \"", UserId,"\" \"",Pwd,"\" \"",Nickname,"\" \"",PortraitUrl,"\" \"",<<>>,"\""," \" \""],
        Cmd=binary_to_list(iolist_to_binary(Iolist)),
        io:format("add_openim_id:~s~n",[Cmd]),
        os:cmd( Cmd)
    end,
    timer:sleep(1000),
    spawn(F).
add_openim_id(UUID)->
    [#lw_register{name=Nickname}] = mnesia:dirty_read(lw_register,UUID),
    add_openim_id(UUID,Nickname,<<>>).
add_openim_id()->
      [add_openim_id(I)||I<-mnesia:dirty_all_keys(lw_register)].

transform_table()->
    F=fun({lw_register,Uuid,Device_id,Name, Pwd,Group_id,  Pls})-> 
                 #lw_register{uuid=Uuid,device_id=Device_id,name=Name,pwd=Pwd,group_id=Group_id,pls=Pls}
            end,
    mnesia:transform_table(lw_register,F,record_info(fields,lw_register)).
%---------------------------------------- test -------------------------------------------------------------
test_get_pay_usage()->
    UUID=unittest:test_uuid(),
%    {true,}= check_balance(UUID),
    ok.
%------------------------------test for zhiyu  --------------------------------------------------
test_zhiyu_register_normal_process()->
    Acc= <<"yxw">>,
    DevId= <<"test_devid_for_zhiyu">>,
    GroupId = <<"zy_common">>,
    Name= Acc,
    Auth_code = <<"18017813673">>,
    Pwd= <<"888888">>,
    Crc=list_to_binary(hex:to(crypto:hash(md5,<<Acc/binary,DevId/binary,GroupId/binary>>))),
    Params=[{"group_id",GroupId},{"device_id",DevId},{"acc",Acc},{"crc",Crc},{"name",Name},{"auth_code",Auth_code},{"pwd",Pwd}],
    {obj, Pls}=lw_register:self_noauth_register(Params),
    UUID=proplists:get_value(uuid,Pls),
    io:format("test:~p~n",[Pls]),
    {atomic,[Reg_info]}= lw_register:get_register_info_by_uuid(UUID),
    RegPls=utility:record2pl(record_info(fields,lw_register),Reg_info),

    ok=proplists:get_value(status,Pls),

    GroupId=proplists:get_value(group_id,RegPls),
    DevId=proplists:get_value(device_id,RegPls),
    lw_register:deregister(UUID),
    {atomic,[]}= lw_register:get_register_info_by_uuid(UUID),
    ok.

test_max_time()->
    UUID= <<"31271186">>,
    MT=max_minutes(UUID,"0086180188888"),
    true=(MT>0),
    ok.
    
