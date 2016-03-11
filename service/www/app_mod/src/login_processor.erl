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
        UUID=
        case lw_register:get_register_info_by_uuid(Acc) of
        {atomic,[_]}-> Acc;
        _->
           case lw_register:get_name_item(Acc) of
               {atomic, [#name2uuid{uuid=U}]}->  U;
               _-> Acc
           end
        end,
        login(Params++[{"uuid",UUID}], <<"uuid">>)
    end.
login(Params,_) when is_list(Params)->
    {Acc0,Pwd0,DevId0}={proplists:get_value("uuid",Params),proplists:get_value("pwd",Params),proplists:get_value("device_id",Params)},
    {RawAccount,PassMD5,DevId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0)},
    utility:log("./log/xhr_poll.log","login_processor login:did:~p acc:~p ~n",[DevId,RawAccount]),
    Ip=proplists:get_value("ip",Params),
    io:format("login_processor login:did:~p acc:~p ~n",[DevId,RawAccount]),
    {obj,Pls0}=case local_login(Params) of
    {islocal,LocalJson}-> 
        register_user_login(Params,[Acc0]),
        LocalJson;
    _->
        {Company,Account}=    case RawAccount of
                          "livecom_"++Account1 -> {livecom,Account1};
                          Account2-> 
                              case string:tokens(Account2,"@") of
                              [Account3]-> {"livecom",Account3};
                              [Account3,Company_]-> {Company_,Account3}
                              end
                        end,
        io:format("login_processor login:params:~p~n",[Params]),
        io:format("login ~p ~p ~p ~n", [Company, Account, PassMD5]),
        company_login(lwork,Company,Account,Params,{RawAccount,PassMD5,DevId})
    end,
    AccUrls=wwwcfg:get_www_url_list(utility:c2s(utility:country(Ip))),
    {obj,[{"urls",AccUrls}|Pls0]}.

logout(Params) when is_list(Params)->
    {UUID,DevId0}={proplists:get_value("uuid",Params),proplists:get_value("device_id",Params)},
    {UUID_STR,DevId}={binary_to_list(UUID),binary_to_list(DevId0)},
    utility:log("./log/xhr_poll.log","login_processor logout:did:~p acc:~p ~n",[DevId,UUID_STR]),
    xhr_poll:stop(DevId),
    unregister_user_login(UUID_STR,DevId),
%    io:format("~p logouted res:~p~n",[XgAccount,R]),
    utility:pl2jso([{status,ok}]).

check_crc(Params)->
    {Acc,DevId,GroupId,Crc}={proplists:get_value("acc",Params),proplists:get_value("device_id",Params),proplists:get_value("group_id",Params),proplists:get_value("crc",Params)},
    case list_to_binary(hex:to(crypto:hash(md5,<<Acc/binary,DevId/binary,GroupId/binary>>))) of
    Crc-> true;
    _-> false
    end.
third_login(Acc="qq_"++_OpenId,Params)->third_login1(Acc,Params);
third_login(Acc="wx_"++_OpenId,Params)->third_login1(Acc,Params).
third_login1(Acc,Params)->
    io:format("third_login~n"),
    Ip=proplists:get_value("ip",Params),
    AccUrls=wwwcfg:get_www_url_list(utility:c2s(utility:country(Ip))),
    case check_crc(Params) of
    true->
        case lw_register:get_third_reg_info(Acc) of
        {atomic,[#third_reg_t{uuid=UUID,name=Name}]}->
            NewParams=lists:keystore("acc",1, Params,{"acc",Name}),
            register_user_login([{"uuid",UUID}|NewParams],[UUID]),
            {atomic,[#lw_register{pwd=Pwd}]}=lw_register:get_register_info_by_uuid(UUID),
            utility:pl2jso_br([{status,ok},{uuid,UUID},{name, Name},{pwd,Pwd},{account,Name},{class,reg},{did,""},{urls,AccUrls}]);
        _-> utility:pl2jso_br([{status,ok},{account,Acc},{class,not_reg},{did,""},{urls,AccUrls}])
        end;
    _-> utility:pl2jso_br([{status,failed},{reason,crc_error},{urls,AccUrls}])
    end.

company_login(Account,Params,{_XgAccount,PassMD5,DevId})->company_login(livecom,Account,Params,{_XgAccount,PassMD5,DevId}).
company_login(lwork,Company,Account,Params,{_XgAccount,PassMD5,_DevId})->   % for login to lwork
    SessionIP=proplists:get_value("ip",Params),
    io:format("login ~p ~p ~p ~p ~p~n", [Company, Account, PassMD5, "", SessionIP]),
    Res = rpc:call(snode:get_service_node(), lw_auth, login, [Company, Account, PassMD5, "",SessionIP]),
    Res1=case Res of
        {ok, UUID} -> 
            {obj,ProfileObj}=Profile=get_profile(UUID,SessionIP),
            {obj,InfoObj}=utility:get(Profile,profile),
            Name=utility:get(utility:get(Profile,profile),name),
            PhoneJson=utility:get(utility:get(Profile,profile),phone),
            {ok,PhoneObj,_}=rfc4627:decode(PhoneJson),
            Phone=utility:get(PhoneObj,"mobile"),
            FullAccout=Account++"@"++Company,
            NewParams0=lists:keystore("group_id",1, Params,{"group_id",list_to_binary(Company)}),
            NewParams=lists:keystore("acc",1, NewParams0,{"acc",list_to_binary(FullAccout)}),
            register_user_login(NewParams,[Phone]),
            utility:pl2jso([{status, ok}, {uuid, Phone},{account,list_to_binary(FullAccout)},{"name", Name},{info,Profile},{type,company}]);
        {failed, Reason}     -> utility:pl2jso([{status, failed}, {reason, pwd_not_match}])
    end,
    Res1.
company_login(Company,Account,Params,{_XgAccount,PassMD5,DevId})->
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

get_profile(UUID,Ip)->
    Summary = get_user_profile(UUID, Ip),
%    {ShortName, OrgId, OrgHier} = get_org_hierarchy(list_to_integer(UUID), Ip),
    HierJson = get_org_hierarchy_json(UUID, Ip),
    FirstElement = fun([])    -> <<"">>;
                      ([V|_]) -> list_to_binary(V) 
                   end, 
    SubDepFun = fun(SubDeps) ->
                    utility:a2jsos([department_id, {department_name,fun erlang:list_to_binary/1}], SubDeps)
                end,
    HierFun = fun({SN,OId, SubDeps}) ->
                    utility:pl2jso([{short_name, list_to_binary(SN)}, 
                                    {org_id, OId},
                                   {departments, utility:a2jsos([department_id, 
                                                                {sub_departments, SubDepFun}], SubDeps)}])
                end,    
    utility:pl2jso([{profile, fun(V)-> utility:a2jso([uuid, {name, fun erlang:list_to_binary/1}, 
                                                            {employee_id, fun erlang:list_to_binary/1},
                                                            phone, 
                                                            {department, fun erlang:list_to_binary/1}, 
                                                            {mail, FirstElement}, photo],
                                                 V)  
                          end},
                    {groups, fun(V)-> utility:a2jsos([group_id, {name, fun erlang:list_to_binary/1}, 
                                                                {attribute, fun erlang:list_to_binary/1},
                                                                members
                                                                ],
                                               V)
                           end},
                    {external, fun(V)-> utility:a2jsos([uuid, 
                                                        {name, fun erlang:list_to_binary/1},
                                                        {eid, fun erlang:list_to_binary/1},
                                                        {markname, fun erlang:list_to_binary/1},
                                                        phone,
                                                        mail,
                                                        status
                                                        ],
                                               V)
                               end},
%                    {hierarchy, HierFun},
                    {im_id,fun(V)-> utility:pl2jso(V) end},
                  %%  {departments, fun(V) -> [list_to_binary(I) || I<-V] end},
                    {unread_events, fun(V) -> utility:pl2jso(V) end}], Summary++[{hierarchy, HierJson}]++[{status, ok}]).

get_user_profile(UUID,SessionIP) ->
  %%  io:format("get_user_profile ~p ~p  ~n", [UUID,SessionIP]),
    %%[{profile, [1, "dhui",  "0131000020", ["00861334567890"], "R&D", ["dhui@livecom.hk"], <<"photo.gif">>]},
    %% {groups,  [{2, "all",  "rr", [2,3]}, {3, "recent", "rd", [4,5]}]},
    %% {default_group, 2},
    %% {default_view, task},
    %% {external, [{UUID, name, eid, markname, phone}]}
    %% {unread_events, [{task, 2},{poll, 3}]}
    %%].
    %%{value, Profile} = rpc:call(snode:get_service_node(), lw_instance, get_user_profile, [UUID,SessionIP]),
    {value, Profile} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_auth, get_user_profile, [UUID], SessionIP]),
    Profile.

get_org_hierarchy_json(UUID,SessionIP) ->
  %%   io:format("get_org_hierarchy ~p ~p~n", [UUID,SessionIP]),
     %%{value, Hier} = rpc:call(snode:get_service_node(), lw_instance, get_org_hierarchy, [UUID,SessionIP]),
     {value, Hier} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                          [UUID, lw_auth, get_org_hierarchy_json, [UUID], SessionIP]),
     Hier.

local_login(Params)->
    UUID=proplists:get_value("uuid",Params),
    Pwd=proplists:get_value("pwd",Params),
    Acc=proplists:get_value("acc",Params),
    io:format("login:~p,~p~n",[UUID,Pwd]),
    {Status,Res}=
    case lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[#lw_register{pwd=Pwd,name=Name,pls=Pls}]}-> 
        Info=proplists:get_value(info,Pls,""),
        Did= proplists:get_value(did,Pls,""),
        {islocal,[{status,ok},{uuid,UUID},{name,Name},{info,Info},{account,Acc},{did,Did}]};
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
       [{status,failed},{reason,no_logined}];
   #login_itm{phone=Phone,status=?ACTIVED_STATUS}->
       case lw_register:check_balance(Phone) of
       {true,Bal} when Bal==no_limit orelse Bal>0 -> [{status,ok},{uuid,UUID},{balance,Bal}];
       _-> [{status,failed},{reason,balance_not_enough}]
       end;
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
    {Acc0,Pwd0,DevId0,GroupId0}={proplists:get_value("acc",Params),proplists:get_value("pwd",Params),
                                                         proplists:get_value("device_id",Params),proplists:get_value("group_id",Params)},
    Ip=proplists:get_value("ip", Params),
    {Account,_PassMD5,DevId,GroupId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0),binary_to_list(GroupId0)},
    P=restart_poll(DevId),
    {Status,Did,Pls}= case lw_agent_oss:get_item(Phone1) of
                                #agent_oss_item{status=S_,did=D_,pls=P_}-> {S_,push_trans_caller(D_),P_};
                                _-> {actived,undefined,[]}
                            end,
    Clidata=proplists:get_value("clidata",Params),
    io:format("register_user_login Params ~p~n",[Params]),
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

del_account_tuple(Phone0)->
    Phone = push_trans_caller(Phone0),
    ?DB_DELETE({login_itm,Phone}).
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
    
get_group_id(Phone)->
    R=
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{phone=UUID,group_id=GroupId1}-> 
        case lw_register:get_group_id(UUID) of
        unregistered-> GroupId1;
        GroupId2-> GroupId2
        end;
    _-> undefined
    end,
    if is_binary(R)-> binary_to_list(R); is_atom(R)-> atom_to_list(R); true-> R end.
    
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
    
gen_uuid(Acc) when is_binary(Acc)-> gen_uuid(binary_to_list(Acc));
gen_uuid(Acc="qq"++_)-> gen_uuid(Acc,31250000);
gen_uuid(Acc="wx"++_)->gen_uuid(Acc,31260000);
gen_uuid(Acc)-> gen_uuid(Acc,31270000).
gen_uuid(_Acc,Base)->    list_to_binary(integer_to_list(Base+mnesia:dirty_update_counter(id_table, uuid, 1))).

add_traffic(Traffic=#traffic{uuid=UUID})->
    case get_tuple_by_uuid_did(UUID) of
    Item=#login_itm{pls=Pls}->  
        Traffics=proplists:get_value(traffic,Pls,[]),
        Id= case Traffics of  [#traffic{id=Id_}|_]->Id_+1; _-> 1 end,
        Npls=lists:keystore(traffics,1,Pls,{traffics,[Traffic#traffic{id=Id+1}|Traffics]}),
        ?DB_WRITE(Item#login_itm{pls=Npls}),
        {ok,Id};
    _->
        failed
    end.
    
    
    
