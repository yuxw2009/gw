%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(lw_admin).
-compile(export_all).

-include("yaws_api.hrl").
-include("snode.hrl").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,


    case catch handle(Arg, Method, Path) of
      {'EXIT', Reason} -> 
          io:format("Error: ~p~n", [Reason]),
          utility:pl2jso([{status, failed}, {reason, service_not_available}]);
      JsonObj -> 
          encode_to_json(JsonObj)
    end.



handle(Arg, 'GET', ["lwork","hierarchy"]) ->
    MarkName = utility:query_string(Arg, "mark_name"),
    Hier = rpc:call(?SNODE, lw_department,  get_org_hierarchy, [MarkName]),
    SubDepFun = fun(SubDeps) ->
                    utility:a2jsos([department_id, {department_name,fun erlang:list_to_binary/1}], SubDeps)
                end,
    HierFun = fun({SN,OId, SubDeps}) ->
                utility:pl2jso([{short_name, list_to_binary(SN)}, 
                                {org_id, OId},
                               {departments, utility:a2jsos([department_id, 
                                                            {sub_departments, SubDepFun}], SubDeps)}])
            end,   
    utility:pl2jso([{hierarchy, HierFun}] ,[{status, ok}, {hierarchy,Hier}]);

handle(_Arg, 'GET', ["lwork", OrgId, DepId, "members"]) ->
    Members = rpc:call(?SNODE, lw_department, get_all_members, [list_to_integer(OrgId), list_to_integer(DepId)]),
    FirstElement = fun([])    -> <<"">>;
                      ([V|_]) -> list_to_binary(V) 
                   end, 
    PFun = fun([]) -> 
                 utility:pl2jso([{callback, disable}, {balance, 0.0}, {voip, disable},
                                     {phoneconf, disable}, {sms, disable}, {dataconf, disable}]);
              (P) ->                     
                   utility:pl2jso(P)
           end,
    utility:pl2jso([{status, ok}, {members, utility:a2jsos([member_id, {name, fun erlang:list_to_binary/1}, 
                                                                       {employee_id, fun erlang:list_to_binary/1},
                                                                       phone,	
                                                                       department_id,
                                                                       {department, fun erlang:list_to_binary/1},
                                                                       {mail, FirstElement},
                                                                       photo,
                                                                       {privilege, PFun}],	
    	                                                    Members)}]);

handle(_Arg, 'GET', ["lwork", OrgId, "navigators"]) ->
    Navs = rpc:call(?SNODE, lw_department, get_all_navigators, [list_to_integer(OrgId)]),
    utility:pl2jso([{status, ok}, {navs, utility:a2jsos([{name, fun erlang:list_to_binary/1}, 
                                                         {url,  fun erlang:list_to_binary/1}], lists:reverse(Navs))}]);

handle(Arg, 'POST', ["lwork", OrgId, "navigators"]) ->
    {Name, URL} = utility:decode(Arg, [{name, s}, {url, s}]),
    ok = rpc:call(?SNODE, lw_department, add_navigators, [list_to_integer(OrgId), [{Name, URL}]]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'POST', ["lwork", OrgId, "delete", "navigators"]) ->
    {Keys} = utility:decode(Arg, [{names, as}]),
    io:format("delete navs: ~p~n", [Keys]),
    ok = rpc:call(?SNODE, lw_department, delete_navigators, [list_to_integer(OrgId), Keys]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'POST', ["lwork", OrgId, DepId, "members"]) ->
   io:format("Arg ~p~n",[Arg]),
   {Items} = utility:decode(Arg, [{items, ao, [{name, s}, {eid, s}, 
   	                                             {phone, b},{email, s},
                                                  {password, s},
                                                  {banlance, s},
                                                  {auth,o,[{callback,a},{voip,a},
                                                            {phoneconf, a},{sms,a},{dataconf,a}]}]}]),
   io:format("Items: ~p~n", [Items]),
   Members = [{list_to_integer(OrgId), Eid, Name, list_to_integer(DepId),
                   list_to_binary(rfc4627:encode(Phone)), [Email], Password, list_to_float(Balance),
                   [{callback, CB}, {voip,VP}, {phoneconf,PC},{sms,SMS},{dataconf,DC}]
                   } || {Name, Eid, Phone, Email, Password, Balance, {CB, VP, PC,SMS, DC}} <- Items],
   Dups = rpc:call(?SNODE, lw_department, add_user, [Members]),
    io:format("Dups: ~p~n", [Dups]),
    case lists:member(employee_num_overflow, Dups) of
      false ->
           utility:pl2jso([{status, ok}, {duplicated, [list_to_binary(I) || I <- Dups]}]);
      true ->
           utility:pl2jso([{status, failed}, {reason, out_of_employee}])
    end;

handle(Arg, 'PUT', ["lwork", OrgId, "members"]) ->
   {EID, RPW, Balance, Auth} = utility:decode(Arg, [{employee_id, s}, {resetPW, a}, {balance, s},
   	                              {auth, o, [{callback,a}, {voip, a}, {phoneconf, a}, {sms, a}, {dataconf, a}]}]),

   Privilege = 
   lists:zip([balance, callback, voip, phoneconf, sms, dataconf], 
                 [list_to_float(Balance)] ++ tuple_to_list(Auth)),
   ok = rpc:call(?SNODE, lw_department, modify_employee_setting, 
                           [list_to_integer(OrgId), EID, RPW, Privilege]),
                                  
   io:format("~p ~n", [Privilege]),
   utility:pl2jso([{status, ok}]);

handle(Arg, 'PUT', ["lwork", OrgId, "members", "transfer"]) ->
   {SrcId, DesId, Eids} = utility:decode(Arg, [{src_id, i}, {des_id, i}, {eids, as}]), 
   io:format("~p ~p ~p ~n", [SrcId, DesId, Eids]),
   ok = rpc:call(?SNODE, lw_department, transfer_department, [list_to_integer(OrgId), SrcId, DesId, Eids]),
   utility:pl2jso([{status, ok}]);

handle(Arg, 'DELETE', ["lwork", OrgId, "members"]) ->
   Items = utility:query_string(Arg, "items"),
     io:format("Items: ~p~n", [Items]),
   Members = [{list_to_integer(OrgId), Eid} || Eid <- string:tokens(Items, ",")],
   ok = rpc:call(?SNODE, lw_department, del_user, [Members]),
   utility:pl2jso([{status, ok}]);

handle(Arg, 'DELETE', ["lwork", OrgId, "departments"]) ->
   DepId = utility:query_integer(Arg, "id"),
   ok = rpc:call(?SNODE, lw_department, delete_department, [list_to_integer(OrgId), DepId]),
   utility:pl2jso([{status, ok}]);

handle(Arg, 'POST', ["lwork", OrgId, "departments"]) ->
   {ParentID, DepName} = utility:decode(Arg, [{parent_id, s}, {name, s}]),
    
   DepId = 
	   case ParentID of
	   	    "top" ->  rpc:call(?SNODE, lw_department, create_department, [list_to_integer(OrgId), DepName]);
	        DID   -> rpc:call(?SNODE, lw_department, create_department, [list_to_integer(OrgId), DepName, list_to_integer(DID)])
	   end,
   utility:pl2jso([{status, ok}, {department_id, DepId}]);


handle(Arg, 'PUT', ["lwork", OrgId, "departments"]) ->
   {DepID, DepName} = utility:decode(Arg, [{id, i}, {name, s}]),
   ok = rpc:call(?SNODE, lw_department, change_department_name, [list_to_integer(OrgId), DepID, DepName]),
   utility:pl2jso([{status, ok}]);


handle(Arg, 'POST', ["lwork", MarkName, "auth", "login"]) ->
    {UserName, PassMD5} = utility:decode(Arg, [{user,s},{password, s}]),
    case rpc:call(?SNODE, lw_department, login, [MarkName, UserName, PassMD5]) of
       {ok, OrgId} -> utility:pl2jso([{status, ok}, {org_id, OrgId}]);
       failed -> utility:pl2jso([{status, failed}]) 
    end;
    
handle(Arg, 'POST', ["lwork", OrgId, "auth", "logout"]) ->
    {UserName} = utility:decode(Arg, [{user,s}]),
    rpc:call(?SNODE, lw_department, logout, [list_to_integer(OrgId), UserName]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'PUT', ["lwork", OrgId, "auth", "password"]) ->
    {UserName, OldPassMD5, NewPassMD5} = utility:decode(Arg, [{user,s},{old_pass, s}, {new_pass, s}]),
    Res = rpc:call(?SNODE, lw_department, modify_admin_password, [list_to_integer(OrgId), UserName,OldPassMD5, NewPassMD5]),
    utility:pl2jso([{status, Res}]);

handle(Arg, 'GET', ["lwork", OrgId, "bills"]) ->
    Year = utility:query_integer(Arg, "year"),
    Month = utility:query_integer(Arg, "month"),
    Bills = rpc:call(?SNODE, lw_audit, build_report, [list_to_integer(OrgId), Year, Month]),
    io:format("Bills: ~p~n", [Bills]),
    F = fun({{Dep, EID, Name}, Stat}) ->
            utility:pl2jso([{department, list_to_binary(Dep)}, 
                            {name, list_to_binary(Name)}, 
                            {employee_id, list_to_binary(EID)},
                            {stat, utility:a2jsos([type, quantity, {charge, fun(V)-> list_to_binary(utility:f2s(V)) end}],Stat)}])
        end,
    utility:pl2jso([{status, ok}, {bills, [F(I) || I <- Bills]}]);
   
%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].

%% encode to json format
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

