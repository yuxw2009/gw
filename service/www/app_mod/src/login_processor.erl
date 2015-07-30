-module(login_processor).
-compile(export_all).
-include("yaws_api.hrl").
-include("login_info.hrl").
-include("lwdb.hrl").
-include("db_op.hrl").

login(Params) when is_list(Params)-> 
    case proplists:get_value("acc",Params) of
    undefined->  login(Params, <<"uuid">>);
    Acc when is_binary(Acc) ->
        UUID = case ?DB_READ(name2uuid, Acc) of
                       {atomic, [#name2uuid{uuid=U}]}->  U;
                       _-> Acc
                   end,
        login([{"uuid",UUID} | Params], <<"uuid">>)
    end.
login(Params,_) when is_list(Params)->
    {Acc0,Pwd0,DevId0}={proplists:get_value("uuid",Params),proplists:get_value("pwd",Params),proplists:get_value("device_id",Params)},
    {XgAccount,PassMD5,DevId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0)},
    utility:log("./log/xhr_poll.log","login_processor login:did:~p acc:~p ~n",[DevId,XgAccount]),
    io:format("login_processor login:did:~p acc:~p ~n",[DevId,XgAccount]),
    case local_login(Params) of
    {islocal,LocalJson}-> 
        register_user_login(Params,[Acc0]),
        LocalJson;
    _->
        Account=    case XgAccount of
                          "livecom_"++Account1 -> Account1;
                          Account2-> Account2
                        end,
        livecom_login(Account,Params,{XgAccount,PassMD5,DevId})
    end.

logout(Params) when is_list(Params)->
    {UUID,DevId0}={proplists:get_value("uuid",Params),proplists:get_value("device_id",Params)},
    {UUID_STR,DevId}={binary_to_list(UUID),binary_to_list(DevId0)},
    utility:log("./log/xhr_poll.log","login_processor logout:did:~p acc:~p ~n",[DevId,UUID_STR]),
    xhr_poll:stop(DevId),
    unregister_user_login(UUID_STR,DevId),
%    io:format("~p logouted res:~p~n",[XgAccount,R]),
    utility:pl2jso([{status,ok}]).
    

livecom_login(Account,Params,{_XgAccount,PassMD5,DevId})->
    Company = livecom,
    Type = usr,
    DeviceToken = if is_list(DevId)-> list_to_binary(DevId); true-> <<"">> end,
    HttpParas=[{company,Company}, {account,list_to_binary(Account)},{password,list_to_binary(PassMD5)},{type,Type},{deviceToken,DeviceToken}],
    case utility:httpc_call(post, "http://fc2fc.com/lwork/auth/livecom_mobile_auth", HttpParas) of
    {obj,_PList=[{"status",<<"ok">>}|AuthInfos]}->
%        ?MODULE ! {login, {Account,livecom}},
        Json=utility:httpc_call(get, "http://fc2fc.com/lwork/auth/self_profile", AuthInfos),
        {obj, ProfileList} = Json,
        {UUID,Name} =
            case proplists:get_value("info", ProfileList) of
            undefined-> {<<>>, <<>>};
            {obj, MemberInfo}->
                case proplists:get_value("phone",MemberInfo) of
                Phones=[Phone|_]->
                    NewParams=lists:keystore("group_id",1, Params,{"group_id",<<"livecom">>}),
                    register_user_login(NewParams,Phones),
                    {Phone,proplists:get_value("name",MemberInfo)};
                _-> {<<>>,<<>>}
                end
            end,
        {obj,[{"uuid",UUID},{"name", Name},{"account",list_to_binary(Account)}|ProfileList]};
    R-> R
    end.

local_login(Params)->
    UUID=proplists:get_value("uuid",Params),
    Pwd=proplists:get_value("pwd",Params),
    io:format("login:~p,~p~n",[UUID,Pwd]),
    {Status,Res}=
    case lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pwd=Pwd,name=Name,pls=Pls}]}-> 
        Info=proplists:get_value(info,Pls,""),
        Did= proplists:get_value(did,Pls,""),
        {islocal,[{status,ok},{uuid,UUID},{name,Name},{info,Info},{account,UUID},{did,Did}]};
    {atomic,[#lw_register{}]}-> {islocal,[{status,failed},{reason,pwd_not_match}]};
    _-> {not_local,[{status,failed},{reason,account_not_existed}]}
    end,
    {Status,utility:pl2jso_br(Res)}.
        
autheticated(UUID_SNO,Callee)-> 
   UUID0=
   case string:tokens(UUID_SNO,"_") of
       [Head|_]->Head;
       _-> undefined
   end,
   check_auth0(UUID0,Callee).

check_auth0(UUID="0"++R_UUID,Callee)->  
    case check_auth(UUID,Callee) of
    [{status,failed}|_]->  check_auth(R_UUID,Callee);
    R-> R
    end;
check_auth0(UUID,Callee)->      check_auth(UUID,Callee).

check_auth(UUID,"*"++_)->  [{status,ok},{uuid,UUID}];
check_auth(UUID,_)->
   case get_tuple_by_uuid_did(UUID) of
   undefined->
       [{status,failed},{reason,list_to_atom(UUID++"_no_logined")}];
   #login_itm{status=?ACTIVED_STATUS}->
       [{status,ok},{uuid,UUID}];
   #login_itm{}->
       [{status,failed},{reason,not_actived}]
   end.

start() ->
    mnesia:create_table(login_itm,[{attributes,record_info(fields,login_itm)}]).

restart()-> start().

authen(UUID,Pwd)-> 
    case sms_handler:auth_code(UUID) of
    Pwd-> ok;
    _-> false
    end.
    
trans_caller_phone("+86"++Callee,Caller)->  trans_caller_phone("0086"++Callee,Caller);
trans_caller_phone(_Callee="0086"++_, Caller)->  national_call_trans_caller(Caller);
trans_caller_phone(_Callee="00"++_,Caller)->  filter_phone(Caller);
trans_caller_phone(_Callee,Caller="0086"++_)->  national_call_trans_caller(Caller);
trans_caller_phone(_Callee,Caller)->  filter_phone(Caller).

trans_callee_phone("*"++Phone,{"ml",_}=_UUID)->  "*000001"++filter_phone(Phone);
trans_callee_phone("+"++Phone,{"ml",_}=UUID)->  trans_callee_phone("00"++Phone,UUID);
trans_callee_phone(Phone="00"++_,{"ml",_}=_UUID)->  "00088818"++filter_phone(Phone);
trans_callee_phone(Phone,{"ml",_}=_UUID)->  "000888180086"++filter_phone(Phone);
trans_callee_phone(Phone,_)-> "000888180086"++filter_phone(Phone).

national_call_trans_caller("008610"++Caller)->  filter_phone("010"++Caller);
national_call_trans_caller("00861"++LeftCaller)->  filter_phone("1"++LeftCaller);
national_call_trans_caller("0086"++Caller)->  filter_phone("0"++Caller);
national_call_trans_caller(Caller)->  filter_phone(Caller).
    
filter_phone(Phone)->  [I||I<-Phone, lists:member(I, "0123456789*#")].

push_trans_caller(undefined)-> undefined;
push_trans_caller("0086"++P)-> P;
push_trans_caller(Caller) when is_binary(Caller)-> push_trans_caller(string:strip(binary_to_list(Caller)));    
push_trans_caller(Caller) ->trans_caller_phone("0086",Caller).
    
unregister_user_login(UUID,DevId)-> 
    io:format("unregister_user_login ~p ~p ~n",[UUID,DevId]),
    case login_processor:get_account_tuple(UUID) of
    #login_itm{devid=DevId,pls=Pls}=Itm-> 
        xhr_poll:stop(DevId),
        update_itm(Itm#login_itm{devid="",pls=proplists:delete(push_pid,Pls)});
    _-> void
    end.
register_user_login(_Params,[])-> {failed,no_phone_registered};
register_user_login(Params,[Phone1|_OtherPhones])->
    tick_old(Params,[Phone1|_OtherPhones]),
    {Acc0,Pwd0,DevId0,GroupId0}={proplists:get_value("uuid",Params),proplists:get_value("pwd",Params),
                                                         proplists:get_value("device_id",Params),proplists:get_value("group_id",Params)},
    Ip=proplists:get_value("ip", Params),
    {Account,_PassMD5,DevId,GroupId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0),binary_to_list(GroupId0)},
    P=restart_poll(DevId),
    {Status,Did,Pls}= case lw_agent_oss:get_item(Phone1) of
                                #agent_oss_item{status=S,did=D,pls=P}-> {S,push_trans_caller(D),P};
                                _-> {actived,undefined,[]}
                            end,
    Clidata=proplists:get_value("clidata",Params),
    io:format("register_user_login clidata ~p~n",[Clidata]),
    {OsType}= if Clidata==undefined-> {"ios"}; true-> utility:decode_json(Clidata,[{os_type,s}]) end,
    NL=#login_itm{phone=push_trans_caller(Phone1),acc=Account,devid=DevId,ip=Ip,group_id=GroupId,status=Status,
           pls=[{os_type,OsType},{did,Did},{push_pid,P}|Pls]},
    ?DB_WRITE(NL).

tick_old(Params,[Phone1|_OtherPhones])->
    {Acc0,Pwd0,DevId0,GroupId0}={proplists:get_value("uuid",Params),proplists:get_value("pwd",Params),
                                                         proplists:get_value("device_id",Params),proplists:get_value("group_id",Params)},
    _Ip=proplists:get_value("ip", Params),
    {Account,_PassMD5,DevId,_GroupId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0),binary_to_list(GroupId0)},
    case get_tuple_by_uuid_did(Phone1) of
    #login_itm{devid=DevId}->  void;
    #login_itm{devid=OldDevId,pls=Pls}-> 
        io:format("try tickout ~p from ~p to ~p~n",[Phone1, OldDevId,DevId]),
        case proplists:get_value(os_type,Pls) of
        "ios"->
            lw_mobile:send_notification1(OldDevId,[{'content-available',1},{alert,login_otherwhere_notes(Account)},{event,login_otherwhere}]);
        _->
            xhr_poll:tickout(OldDevId)
        end;
    _->    void
    end,
    ok.
restart_poll(DevId)->
    xhr_poll:stop(DevId),
    start_poll(DevId).
start_poll(DevId) when is_list(DevId)-> start_poll(list_to_atom(DevId));
start_poll(Clt_chanPid)->
    case whereis(Clt_chanPid) of
    P when is_pid(P)-> P;
    _-> 
        BA=xhr_poll:start([{report_to,undefined}]),
        register(Clt_chanPid, BA),
        BA
    end.

get_account_tuple(Phone0)->
    Phone = push_trans_caller(Phone0),
    case ?DB_READ(login_itm,Phone) of
    {atomic, [L]}->  L;
       _-> undefined
    end.

get_account_tuple_bydid(Did0)->
    Did = push_trans_caller(Did0),
    case ?DB_READ(agent_did2sip,Did) of
    {atomic,[#agent_did2sip{sipdn=Sdn}]}->
        get_account_tuple(Sdn);
    {atomic,[]}->undefined
    end.
    

get_poll_pid(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{pls=Pls}-> 
         Pid=proplists:get_value(push_pid,Pls,undefined),
         case is_pid(Pid) of
         true-> Pid; 
         _-> undefined 
         end;
    _-> undefined
    end.
    
is_logined(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{devid=DevId,pls=Pls} when is_list(DevId) andalso length(DevId)>0 -> 
        case proplists:get_value(os_type,Pls) of
            "ios"-> true;
            _-> 
                Pid=get_poll_pid(Phone),
                if is_pid(Pid)-> rpc:call(node(Pid),erlang,is_process_alive,[Pid]); true-> false end
        end;
    _-> undefined
    end.

get_ip_tuple(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{ip=Ip}-> Ip;
    _-> undefined
    end.
get_phone_type(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{pls=Pls}-> 
        proplists:get_value(os_type,Pls);
    _-> undefined
    end.
get_tuple_by_uuid_did(Phone)->
case {get_account_tuple(Phone), get_account_tuple_bydid(Phone)} of
    {Itm=#login_itm{},_}-> Itm;
    {_,Itm=#login_itm{}}-> Itm;
    _-> undefined
    end.
update_itm(Itm)->  ?DB_WRITE(Itm).
show_usertab()-> ?DB_QUERY(login_itm).
    
get_group_id(Phone) when Phone=="31230646" orelse Phone=="31230648" orelse Phone=="31230653"->  "livecom";
get_group_id(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{group_id=GroupId}-> GroupId;
    _-> undefined
    end.
    
set_status(UUID,Status)->
    case get_tuple_by_uuid_did(UUID) of
    Item=#login_itm{}->  
        ?DB_WRITE(Item#login_itm{status=Status}),
        [{status,ok}];
    _->
        [{status,failed},{reason,register_uuid_not_existed}]
    end.

login_otherwhere_notes(UUID)->
    "您的账号"++UUID++"在其他设备登录".
