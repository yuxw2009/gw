%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/auth
%%%------------------------------------------------------------------------------------------
-module(auth_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle user login request
handle(Arg, 'POST', ["login"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    Company = utility:get_value(Json, "company"),
    Account = utility:get_value(Json, "account"),
    PassMD5 = utility:get_value(Json, "password"),
    DeviceToken = utility:get_value(Json, "deviceToken"),
    
    PassMD5 = utility:get_value(Json, "password"),
    
    Res = login(Company, Account, PassMD5, DeviceToken, utility:client_ip(Arg)),
    case Res of
        {ok, UUID} -> utility:pl2jso([{status, ok}, {uuid, UUID}]);
        {failed, Reason}     -> utility:pl2jso([{status, failed}, {reason, Reason}])
    end;  

handle(Arg, 'POST', ["enter"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Res = enter(UUID, utility:client_ip(Arg)),
    case Res of
        {ok, UUID} -> utility:pl2jso([{status, ok}, {uuid, UUID}]);
        {failed, Reason}     -> utility:pl2jso([{status, failed}, {reason, Reason}])
    end;  

%% handle lookup uses name by uuids
handle(Arg, 'GET', ["names"]) ->
    UUIDStrs = utility:query_string(Arg, "uuids"),
    UUIDs = [list_to_integer(I)|| I<-string:tokens(UUIDStrs, ",")],
    Res = lookup_names(UUIDs),
    utility:pl2jso([{status, ok}, 
                    {results, utility:a2jsos([uuid, {eid, fun erlang:list_to_binary/1}, 
                                                    {name, fun erlang:list_to_binary/1},
                                                    {markname, fun erlang:list_to_binary/1}    
                                                        ], Res)}]);
    

%% handle get user profile request
handle(Arg, 'GET', ["profile"]) ->
    {ok, UUID} = yaws_api:queryvar(Arg, "uuid"),
    
    Summary = get_user_profile(list_to_integer(UUID), utility:client_ip(Arg)),
    {ShortName, OrgId, OrgHier} = get_org_hierarchy(list_to_integer(UUID), utility:client_ip(Arg)),

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
                    {hierarchy, HierFun},
                  %%  {departments, fun(V) -> [list_to_binary(I) || I<-V] end},
                    {unread_events, fun(V) -> utility:pl2jso(V) end}], Summary++[{hierarchy, {ShortName, OrgId, OrgHier}}]++[{status, ok}]);
%% handle get user profile request
handle(Arg, 'GET', ["hierarchy"]) ->
    {ok, UUID} = yaws_api:queryvar(Arg, "uuid"),
    {ShortName,OrgHier} = get_org_hierarchy(list_to_integer(UUID), utility:client_ip(Arg)),

    SubDepFun = fun(SubDeps) ->
                    utility:a2jsos([department_id, {department_name,fun erlang:list_to_binary/1}], SubDeps)
                end,

    utility:pl2jso([{status, ok},
                    {short_name, list_to_binary(ShortName)}, 
                    {hierarchy, utility:a2jsos([department_id, {sub_departments, SubDepFun}], OrgHier)}]);
%% handle user logout request
handle(Arg, 'DELETE', ["logout"]) ->
    {ok, UUID} = yaws_api:queryvar(Arg, "uuid"),
    logout(list_to_integer(UUID), utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]).


%%% rpc call
-include("snode.hrl").

login(Company, Account, PassMD5,DeviceToken, SessionIP) ->
    io:format("login ~p ~p ~p ~p ~p~n", [Company, Account, PassMD5, DeviceToken, SessionIP]),
    rpc:call(snode:get_service_node(), lw_auth, login, [Company, Account, PassMD5, DeviceToken,SessionIP]).

enter(UUID,SessionIP) ->
    io:format("new login ~p ~p~n", [UUID, SessionIP]),
    rpc:call(snode:get_service_node(), lw_auth, new_login, [UUID, SessionIP]).

logout(UUID,SessionIP) ->
    io:format("logout ~p ~p ~n", [UUID,SessionIP]),
    rpc:call(snode:get_service_node(), lw_auth, logout, [UUID,SessionIP]).

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

get_com_full_name(UUID,SessionIP) ->
   %% io:format("get_com_full_name ~p  ~p~n", [UUID,SessionIP]),
    %%{value, FName} = rpc:call(snode:get_service_node(), lw_instance, get_full_name, [UUID,SessionIP]),
    {value, FName} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                          [UUID, lw_auth, get_full_name, [UUID], SessionIP]),
    FName.
    %%"爱讯达科技（深圳）有限公司".

get_com_navigators(UUID,SessionIP) ->
  %%  io:format("get_com_navigators ~p  ~p~n", [UUID,SessionIP]),
    %%{value, Navs} = rpc:call(snode:get_service_node(), lw_instance, get_all_navigators, [UUID,SessionIP]),
    {value, Navs} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                          [UUID, lw_auth, get_all_navigators, [UUID], SessionIP]),
    Navs.
    %%[{"计费系统", "http://10.60.108.131:8080/"},
    %%          {"话务系统", "http://10.60.108.131:8080/dm.html"},
    %%           {"文档服务器", "http://10.32.3.60:8080"}].

get_org_hierarchy(UUID,SessionIP) ->
  %%   io:format("get_org_hierarchy ~p ~p~n", [UUID,SessionIP]),
     %%{value, Hier} = rpc:call(snode:get_service_node(), lw_instance, get_org_hierarchy, [UUID,SessionIP]),
     {value, Hier} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                          [UUID, lw_auth, get_org_hierarchy, [UUID], SessionIP]),
     Hier.

    %%{"LiveCom", 99, [{top, [{100, "缺省"},{101, "财务部"}, {102, "业务一部"}, 
    %%                        {103, "业务二部"}, {104, "业务三部"}, {105, "运营及工程维护部"}, {106, "新业务开发部"}]},
    %% {100, [{200, "sec_dep1"}, {201, "sec_dep2"}]},
    %% {101, [{300, "sec_dep3"}, {301, "sec_dep4"}]},
    %% {301, [{400, "thi_dep5"}, {401, "thi_dep6"}]}
    %%]}.

lookup_names(UUIDs) ->
    Res = rpc:call(snode:get_service_node(), lw_instance, lookup_user_name, [UUIDs]),
    Res.