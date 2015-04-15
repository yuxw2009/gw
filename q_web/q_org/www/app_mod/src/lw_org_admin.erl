%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(lw_org_admin).
-compile(export_all).

-include("yaws_api.hrl").
-include("snode.hrl").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
    JsonObj = 
	    try
	        handle(Arg, Method, Path)
	    catch 
	    	throw:Reason ->
	    	    utility:pl2jso([{status, failed}, {reason, Reason}])
	    	%%error:Reason ->
	    	%%    io:format("Error: ~p~n", [Reason]),
	    	%%    utility:pl2jso([{status, failed}, {reason, service_not_available}])    
	    end,
	encode_to_json(JsonObj).

handle(_Arg, 'GET', ["lwork","orgs"]) ->
    AllOrgs = rpc:call(?SNODE, lw_department,  get_all_org, []),
   
    Orgs = [{OrgID,MarkName,FullName,CurCM, MaxCM,CurVR, 
            MaxVR,list_to_binary(utility:f2s(CurC*1.0)), MaxCL,MaxM}

            ||  {OrgID,MarkName,FullName,{CurCM, MaxCM},{CurVR, MaxVR},{CurC, MaxCL},MaxM}<-AllOrgs
            ],

    utility:pl2jso([{status, ok},
                    {orgs, utility:a2jsos([org_id, 
                                           {mark_name, fun erlang:list_to_binary/1},
                                           {full_name, fun erlang:list_to_binary/1},
                                            cur_conf_members,
                                            max_conf_members,
                                            cur_vconf_rooms,
                                            max_vconf_rooms,
                                            cur_cost, 
                                            max_cost,
                                            max_members
                                            ],Orgs )}]);
                                         
  
handle(_Arg, 'PUT', ["lwork",OrgId, "markname", NewMarkName]) ->
    ok = rpc:call(?SNODE, lw_department,  change_org_markname, [list_to_integer(OrgId), NewMarkName]),
    utility:pl2jso([{status, ok}]);


handle(_Arg, 'PUT', ["lwork",OrgId, "fullname", NewFullName]) ->
    ok = rpc:call(?SNODE, lw_department,  change_org_full_name, [list_to_integer(OrgId), NewFullName]),
    utility:pl2jso([{status, ok}]);

handle(_Arg, 'POST', ["lwork","orgs", FullName, MarkName]) ->
    OrgId = rpc:call(?SNODE, lw_department,  create_org, [FullName, MarkName]),
    utility:pl2jso([{status, ok}, {org_id, OrgId}]);

handle(_Arg, 'DELETE', ["lwork","orgs", OrgId]) ->
    ok = rpc:call(?SNODE, lw_department,  delete_org, [list_to_integer(OrgId)]),
    utility:pl2jso([{status, ok}]);

handle(_Arg, 'PUT', ["lwork",OrgId, "admin"]) ->
    ok = rpc:call(?SNODE, lw_department,  reset_admin_password, [list_to_integer(OrgId)]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'PUT', ["lwork",OrgId, "license"]) ->
    {MaxCM, MaxVR,MaxC, MaxM}
        = utility:decode(Arg, [{max_conf_members, i}, 
                               {max_vconf_rooms, i}, 
                               {max_cost, i}, 
                               {max_members, i}
                               ]),

    ok = rpc:call(?SNODE, local_user_info,  modify_org_res_setting, 
        [list_to_integer(OrgId), MaxCM,MaxVR,MaxC,MaxM]),
    utility:pl2jso([{status, ok}]);  

                                     
%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].

%% encode to json format
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.
