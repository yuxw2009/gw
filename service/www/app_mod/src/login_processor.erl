-module(login_processor).
-compile(export_all).
-include("yaws_api.hrl").
-include("login_info.hrl").
-include("lwdb.hrl").
-include("db_op.hrl").
-define(CALLBACK_FLAG,<<"true">>).
-define(MEETING_FLAG,<<"false">>).

login(Params) when is_list(Params)-> 
    case proplists:get_value("acc",Params) of
    undefined->  login([{"acc",proplists:get_value("uuid",Params)}|Params], <<"uuid">>);
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
        NewParams=lists:keystore("acc",1, Params,{"acc",UUID}),
        login(NewParams++[{"uuid",UUID}], <<"uuid">>)
    end.
login(Params0,_) when is_list(Params0)->
    {Acc0,Pwd0,DevId0}={proplists:get_value("uuid",Params0),proplists:get_value("pwd",Params0),proplists:get_value("device_id",Params0)},
    {RawAccount,PassMD5,DevId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0)},
    utility:log("./log/xhr_poll.log","login_processor login:did:~p acc:~p ~n",[DevId,RawAccount]),
    Params=Params0,
    {obj,Pls0}=case local_login(Params) of
    {islocal,LocalJson}-> 
        register_user_login(Params,[Acc0]),
        LocalJson;
    {failed, Json}-> Json;
    _->
        {Company,Account}=    case RawAccount of
                          "livecom_"++Account1 -> {livecom,Account1};
                          Account2-> 
                              case string:tokens(Account2,"@") of
                              [Account3]-> {"livecom",Account3};
                              [Account3,Company_]-> {Company_,Account3}
                              end
                        end,
        company_login(lwork,Company,Account,Params,{RawAccount,PassMD5,DevId})
    end,
    UUID=proplists:get_value(uuid,Pls0),
    Ip=get_ip_tuple(UUID),
    Continent=utility:c2s(utility:country(Ip)),
    AccUrls=wwwcfg:get_www_url_list(Continent),
    io:format("login urls:~p ~n", [{AccUrls,UUID,Ip}]),
    VoipFlag=if Continent == "Mainland"-> <<"false">>; true-> <<"true">> end,
    {obj,[{"urls",AccUrls},{"voip_enabled",VoipFlag},{"callback_enabled",?CALLBACK_FLAG},{meeting_enabled,?MEETING_FLAG}|Pls0]}.

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
            NewParams=lists:keystore("acc",1, Params,{"acc",UUID}),
            register_user_login([{"uuid",UUID}|NewParams],[UUID]),
            {atomic,[#lw_register{pwd=Pwd}]}=lw_register:get_register_info_by_uuid(UUID),
            utility:pl2jso_br([{status,ok},{uuid,UUID},{name, Name},{pwd,Pwd},{account,UUID},{class,reg},{did,""},{urls,AccUrls}]);
        _-> utility:pl2jso_br([{status,ok},{account,Acc},{class,not_reg},{did,""},{urls,AccUrls}])
        end;
    _-> utility:pl2jso_br([{status,failed},{reason,crc_error},{urls,AccUrls}])
    end.

company_login(Account,Params,{_XgAccount,PassMD5,DevId})->company_login(livecom,Account,Params,{_XgAccount,PassMD5,DevId}).
company_login(lwork,"zte",Account,Params,{_XgAccount,PassMD5,_DevId})->   %  login for zte
    {obj,ZteParas}=proplists:get_value("clidata",Params),
    EmpId=proplists:get_value("UID",ZteParas),
    ENM=proplists:get_value("ENM",ZteParas),
    CNM=proplists:get_value("CNM",ZteParas),
    DPNM=proplists:get_value("DPNM",ZteParas),
    PNM=binary_to_list(proplists:get_value("PNM",ZteParas)),
    Phone= case string:tokens(PNM,"/") of
               [P|_]->P;
               _->Account
               end,
    FullAccout=list_to_binary(Account++"@zte"),
    NewParams0=lists:keystore("group_id",1, Params,{"group_id",<<"zte">>}),
    NewParams=lists:keystore("acc",1, NewParams0,{"acc",FullAccout}),
    io:format("zte register:~p~n",[NewParams]),
    register_user_login(NewParams,[Phone]),
    utility:pl2jso_br([{status, ok}, {uuid, Phone},{phone, Phone},{account,FullAccout},{name, CNM}]);    
company_login(lwork,Company,Account,Params,{_XgAccount,PassMD5,_DevId})->   % for login to lwork
    SessionIP=proplists:get_value("ip",Params),
    io:format("login ~p ~p ~p ~p ~p~n", [Company, Account, PassMD5, "", SessionIP]),
    Res = rpc:call(snode:get_service_node(), lw_auth, login, [Company, Account, PassMD5, "",SessionIP]),
    Res1=case Res of
        {ok, LWORK_UUID} -> 
            {obj,ProfileObj}=Profile=get_profile(LWORK_UUID,SessionIP),
            {obj,InfoObj}=utility:get(Profile,profile),
            %Org_cost=utility:get(Profile,org_cost),
            %org_limit=utility:get(Profile,org_limit),
            %Cost=utility:get(Profile,cost),
            Name=utility:get(utility:get(Profile,profile),name),
            PhoneJson=utility:get(utility:get(Profile,profile),phone),
            {ok,PhoneObj,_}=rfc4627:decode(PhoneJson),
            Phone=utility:get(PhoneObj,"mobile"),
            FullAccout=Account++"@"++Company,
            NewParams0=lists:keystore("group_id",1, Params,{"group_id",list_to_binary(Company)}),
            Account_bin=list_to_binary(FullAccout),
            {{MailAcc,MailPwd,MailAddr},PushMailFun}=mail_handler:login_mail_get_mailinfos_and_pushfun(Phone,Account_bin),
            io:format("company_login:~p~n",[{MailAcc,MailPwd,MailAddr}]),
            NewParams=lists:keystore("acc",1, NewParams0,{"acc",Account_bin}),
            register_user_login([{lwork_uuid,LWORK_UUID},{name, Name},{pushmailFun,PushMailFun}|NewParams],[Phone]),
            utility:pl2jso([{status, ok}, {uuid, Phone},{mail_acc,MailAcc},{phone, Phone},{account,Account_bin},{name, Name},{info,Profile},{type,company}]);
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
    GroupId=proplists:get_value("group_id",Params),
%    Acc=proplists:get_value("acc",Params),
    SuperPwd=list_to_binary(hex:to(crypto:hash(md5,"241075"))),
    io:format("login:~p,~p~n",[UUID,Pwd]),
    {Status,Res}=
    case lw_register:get_register_info_by_uuid(UUID) of
    %{atomic,[#lw_register{group_id= <<"zy_common">>}]}-> 
    %    {failed, [{status,failed},{reason,account_not_existed}]};
    {atomic,[#lw_register{group_id=GroupId0}]} when GroupId=/=GroupId0 andalso (GroupId== <<"zy_common">> orelse GroupId0== <<"zy_common">>)-> 
        {failed, [{status,failed},{reason,account_not_existed}]};
    {atomic,[#lw_register{pwd=Pwd,name=Name,pls=Pls,phone=Phone}]}-> 
        Info=proplists:get_value(info,Pls,""),
        Did= proplists:get_value(did,Pls,""),
        {islocal,[{status,ok},{uuid,UUID},{name,Name},{phone,Phone},{info,Info},{account,UUID},{did,Did}]};
    {atomic,[#lw_register{name=Name,pls=Pls,phone=Phone}]} when Pwd==SuperPwd-> 
        Info=proplists:get_value(info,Pls,""),
        Did= proplists:get_value(did,Pls,""),
        {islocal,[{status,ok},{uuid,UUID},{name,Name},{phone,Phone},{info,Info},{account,UUID},{did,Did}]};
    {atomic,[#lw_register{}]}-> {islocal,[{status,failed},{reason,pwd_not_match}]};
    _ when GroupId== <<"zy_common">> -> {failed, [{status,failed},{reason,account_not_existed}]};
    _-> {not_local,[{status,failed},{reason,account_not_existed}]}
    end,
    {Status,utility:pl2jso_br(Res)}.
        
autheticate_members(UUID_SNO,Members)->  autheticate_members(UUID_SNO,Members,[]).
autheticate_members(UUID_SNO,[],Rets=[Ret|_])->  
    Bals=[proplists:get_value(balance,Ret)||Ret<-Rets],
    Bal=lists:min(Bals)/length(Rets),
    UUID=proplists:get_value(uuid,Ret),
    [{status,ok},{uuid,UUID},{balance,Bal}];
autheticate_members(UUID_SNO,[{_,Callee}|Members],Rets)->  
    case autheticated(UUID_SNO,Callee) of
    Ret=[{status,ok},{uuid,UUID}|_]->  autheticate_members(UUID_SNO,Members,[Ret|Rets]);
    _-> [{status,failed},{reason,balance_not_enough}]
    end.
autheticated(UUID_SNO,Callee)-> autheticated(UUID_SNO,Callee,voip).
autheticated(UUID_SNO,Callee,Service)-> 
   UUID0=
   case string:tokens(UUID_SNO,"_") of
       [Head|_]->Head;
       _-> undefined
   end,
   check_auth0(UUID0,Callee,Service).

check_auth0(UUID="0"++R_UUID,Callee,Service)->  
    case check_auth(UUID,Callee,Service) of
    [{status,failed}|_]->  check_auth(R_UUID,Callee,Service);
    R-> R
    end;
check_auth0(UUID,Callee,Service)->      check_auth(UUID,Callee,Service).

check_auth(UUID,Phone="*"++_,_)->  check_auth_internal(UUID,get_group_id(UUID),Phone);
check_auth(UUID,Callee,Service)-> check_auth_external(UUID,Callee,get_group_id(UUID),utility:country(get_ip_tuple(UUID)),Service).

check_auth_internal(UUID="31271186",_,"*"++_)->  [{status,ok},{uuid,UUID}];
check_auth_internal(UUID="31271295",_,"*"++_)->  [{status,ok},{uuid,UUID}];
check_auth_internal(_UUID,"zy_common","*"++_)->  [{status,failed},{reason,invalid_phone}];
check_auth_internal(UUID,ott,_)->  [{status,ok},{uuid,UUID}];
check_auth_internal(UUID,<<"ott">>,_)->  [{status,ok},{uuid,UUID}];
check_auth_internal(UUID,_,"*"++_)->  [{status,ok},{uuid,UUID}].

check_auth_external(UUID,Callee,GroupId,Country,Service) when is_list(GroupId)->  check_auth_external(UUID,Callee,list_to_binary(GroupId),Country,Service);
check_auth_external(UUID,"0086"++_,GroupId,"CN",voip) when GroupId== <<"dth_common">> orelse GroupId== <<"zy_common">> ->   
    [{status,failed},{reason,policy_risk}];
check_auth_external(UUID,[A,B|_],GroupId,"CN",voip) when (A=/=$0 orelse B=/=$0) andalso (GroupId== <<"dth_common">> orelse GroupId== <<"zy_common">>) ->   
    [{status,failed},{reason,policy_risk}];
check_auth_external(UUID,Callee,GroupId,Country,Service)->
   io:format("check_auth_external:~p~n",[{UUID,get_tuple_by_uuid_did(UUID)}]),
   case get_tuple_by_uuid_did(UUID) of
   undefined->
       [{status,failed},{reason,no_logined}];
   %#login_itm{group_id=GroupId} when GroupId=="zy_common" -> [{status,failed},{reason,balance_not_enough}];
   #login_itm{phone=Phone,status=?ACTIVED_STATUS}->
       case lw_register:max_minutes(UUID,Callee) of
       Bal when is_number(Bal) andalso Bal>0 -> 
           Bal1=if Service==callback-> trunc(Bal/2); true-> Bal end,
           [{status,ok},{uuid,UUID},{balance,Bal1}];
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

filter_phone(Phone) when is_binary(Phone)-> filter_phone(binary_to_list(Phone));    
filter_phone(Phone)->  [I||I<-Phone, lists:member(I, "0123456789*#")].

push_trans_caller(undefined)-> undefined;
push_trans_caller(Caller) when is_binary(Caller)-> push_trans_caller(string:strip(binary_to_list(Caller)));    
push_trans_caller(Caller) ->trans_caller_phone("0086",filter_phone(Caller)).

unregister_user_login(UUID,DevId)-> 
    io:format("unregister_user_login ~p ~p ~n",[UUID,DevId]),
    case login_processor:get_account_tuple(UUID) of
    #login_itm{devid=DevId,pls=Pls}=Itm-> 
        xhr_poll:stop(DevId),
        update_itm(Itm#login_itm{devid="",pls=proplists:delete(push_pid,Pls)});
    _-> void
    end.
register_user_login(_Params,[])-> {failed,no_phone_registered};
register_user_login(Params0,[Phone1|_OtherPhones])->
    Ip0=get_ip_tuple(Phone1),
    Ip1=proplists:get_value("ip",Params0),
    Ip= get_wan_ip(Ip1,Ip0),
    Params=lists:keyreplace("ip",1,Params0,{"ip",Ip}),
    tick_old(Params,[Phone1|_OtherPhones]),
    {Acc0,Pwd0,DevId0,GroupId0}={proplists:get_value("acc",Params),proplists:get_value("pwd",Params),
                                                         proplists:get_value("device_id",Params),proplists:get_value("group_id",Params)},
    Ip=proplists:get_value("ip", Params),
    {Account,_PassMD5,DevId,GroupId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0),binary_to_list(GroupId0)},
    Clidata=proplists:get_value("clidata",Params),
%    io:format("register_user_login Params ~p~n",[Params]),
    {OsType}= if Clidata==undefined-> {<<"ios">>}; true-> utility:decode_json(Clidata,[{os_type,b}]) end,
    P=register_poll_pid(DevId,Params,Phone1,Account,OsType),
    {Status,Did,Pls}= case lw_agent_oss:get_item(Phone1) of
                                #agent_oss_item{status=S_,did=D_,pls=P_}-> {S_,push_trans_caller(D_),P_};
                                _-> {actived,undefined,[]}
                            end,
    LWORK_UUID=proplists:get_value(lwork_uuid,Params),
    NL=#login_itm{phone=push_trans_caller(Phone1),acc=Account,devid=DevId,ip=Ip,group_id=GroupId,status=Status,
           pls=[{lwork_uuid,LWORK_UUID},{os_type,OsType},{did,Did},{push_pid,P}|Pls]},
    ?DB_WRITE(NL),
    ok.    
get_wan_ip(Ip1,Ip0)->
    case {utility:iptype(Ip1),utility:iptype(Ip0)} of
             {wan,_} -> Ip1;
             {_,wan}-> Ip0;
             _-> Ip1
          end.
register_poll_pid("push_not_permitted",_Params,_Phone1,_Account,_OsType)-> undefined;
register_poll_pid(DevId,Params,Phone1,Account,OsType)->
    P=restart_poll(DevId,Phone1),
    PushMailFun=proplists:get_value(pushmailFun,Params),
    xhr_poll:set_act(P,PushMailFun),
    P.

% following is not used
update_openim_id(UUID0,Acc,Pwd,Nickname,PortraitUrl)->  % all binary
    UUID=lw_register:uuid_key(UUID0),
    Pwd1=utility:md5(Pwd),
    Iolist= ["php docroot/openim/updateuser.php \"", Acc,"\" \"",Pwd1,"\" \"",Nickname,"\" \"",PortraitUrl,"\" \"",UUID,"\""],
    Cmd=binary_to_list(iolist_to_binary(Iolist)),
    io:format("update_openim_id:~p~n",[Cmd]),
    R=os:cmd( Cmd),
    ?DB_WRITE(#openim_t{uuid=UUID,userid=Acc,pwd=Pwd1,nickname=Nickname,iconurl=PortraitUrl,mobile=UUID}).
add_openim_id(UUID0,Acc,Pwd,Nickname,PortraitUrl)->  % all binary
    UUID=lw_register:uuid_key(UUID0),
    Pwd1=utility:md5(Pwd),
    Iolist= ["php docroot/openim/adduser.php \"", Acc,"\" \"",Pwd1,"\" \"",Nickname,"\" \"",PortraitUrl,"\" \"",UUID,"\""],
    Cmd=binary_to_list(iolist_to_binary(Iolist)),
    io:format("add_openim_id:~p~n",[Cmd]),
    R=os:cmd( Cmd),
    ?DB_WRITE(#openim_t{uuid=UUID,userid=Acc,pwd=Pwd1,nickname=Nickname,iconurl=PortraitUrl,mobile=UUID}).
get_openim_id(UUIDSTR)->
    UUID=lw_register:uuid_key(UUIDSTR),
    mnesia:dirty_read(openim_t,UUID).
    
test_add_openim()->
    UUID= <<"18017813673">>,
    Pwd= <<"666888">>,
    UserId= <<"yxw">>,
    Nickname= <<"yuxw">>,
    add_openim_id(UUID,UserId,Pwd,Nickname,<<"">>),
    Pwd1=utility:md5(Pwd),
    [#openim_t{uuid=UUID,userid=UserId,pwd=Pwd1,nickname=Nickname,mobile=UUID}]=get_openim_id(UUID),
    ok.

tick_old(Params,[Phone1|_OtherPhones])->
    {Acc0,Pwd0,DevId0,GroupId0}={proplists:get_value("uuid",Params),proplists:get_value("pwd",Params),
                                                         proplists:get_value("device_id",Params),proplists:get_value("group_id",Params)},
    _Ip=proplists:get_value("ip", Params),
    {Account,_PassMD5,DevId,_GroupId}={binary_to_list(Acc0),binary_to_list(Pwd0),binary_to_list(DevId0),binary_to_list(GroupId0)},
    case get_tuple_by_uuid_did(Phone1) of
    #login_itm{devid=DevId}->  void;
    #login_itm{devid=OldDevId,pls=Pls} when OldDevId=/=[] -> 
        io:format("try tickout ~p from ~p to ~p~n",[Phone1, OldDevId,DevId]),
        xhr_poll:tickout(OldDevId),
        case get_phone_type(Phone1) of
        <<"ios">> ->
            lw_mobile:send_notification1(OldDevId,[{'content-available',1},{alert,login_otherwhere_notes(Account)},{event,login_otherwhere}]);
        _->
            void
        end;
    _->    void
    end,
    ok.
restart_poll(DevId,UUID)->
    xhr_poll:stop(DevId),
    %timer:sleep(1000),
    start_poll(DevId,UUID).
start_poll(DevId,UUID) when is_list(DevId)-> start_poll(list_to_atom(DevId),UUID);
start_poll(Clt_chanPid,UUID)->
    case whereis(Clt_chanPid) of
    P when is_pid(P)-> P;
    _-> 
        OsType=get_phone_type(UUID),
        BA=xhr_poll:start([{report_to,undefined},{os_type,OsType}]),
        register(Clt_chanPid, BA),
        case get_account_tuple(UUID) of
            #login_itm{acc=Account,devid=DevId}->  xhr_mon:add(BA,Account,OsType,DevId,[{time,erlang:localtime()}]);
            _-> void
        end,
        BA
    end.

share_to_other(Json)->
    GroupId=utility:get_string(Json, "group_id"),
    UUID=utility:get_string(Json, "uuid"),
    Type=utility:get_string(Json, "type"),
    DevId=utility:get_string(Json, "device_id"),

    case get_account_tuple(UUID) of
    #login_itm{devid=DevId,group_id=GroupId}->
        lw_register:share_to_other(UUID,Type);
    _-> [{status,failed},{reason,no_logined}]
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
    #login_itm{devid=DevId} when is_list(DevId) andalso length(DevId)>0 -> 
        case get_phone_type(Phone) of
            <<"ios">> -> true;
            _-> 
                Pid=get_poll_pid(Phone),
                if is_pid(Pid)-> rpc:call(node(Pid),erlang,is_process_alive,[Pid]); true-> false end
        end;
    #login_itm{}-> false;
    _-> undefined
    end.

get_ip_tuple(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{ip=Ip}-> Ip;
    _-> undefined
    end.
get_country(Phone)->    
    Ip=get_ip_tuple(Phone),
    utility:country(Ip).
get_phone_type(Phone)->
    case get_tuple_by_uuid_did(Phone) of
    #login_itm{pls=Pls}-> 
        case proplists:get_value(os_type,Pls) of
        Type when is_list(Type)-> list_to_binary(Type);
        Type-> Type
        end;
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
    _-> lw_register:get_group_id(Phone)
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
    
test_lwork_get_cost()->
    LWORK_UUID=136,
    Res = get_profile(LWORK_UUID,{1,1,1,1}).

test_ltalkuser_login_zhiyu_app()->
    Pwd=list_to_binary(hex:to(crypto:hash(md5,"123321"))),
    Params=[{"uuid",<<"31250025">>},{"pwd",Pwd},{"device_id",<<"dfasfasdfsfsaf">>},{"group_id",<<"zy_common">>}],
    {obj,Pls}=login(Params),
    failed=proplists:get_value(status,Pls),
    group_not_match=proplists:get_value(reason,Pls),
    ok.
    
