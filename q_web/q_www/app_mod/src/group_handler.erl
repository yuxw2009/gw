%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/groups
%%%------------------------------------------------------------------------------------------
-module(group_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle get all groups request
handle(Arg, 'GET', []) ->
    {ok, OwnerId} = yaws_api:queryvar(Arg, "owner_id"),
    Groups = all_groups(OwnerId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {groups, utility:a2jsos([group_id, {name, fun erlang:list_to_binary/1},
                     	                                             {attribute, fun erlang:list_to_binary/1}], 
                     	                                   Groups)}]);
%% handle get group members request
handle(Arg, 'GET', [GroupId, "members"]) ->
    {ok, OwnerId} = yaws_api:queryvar(Arg, "owner_id"),
    Members = all_members(OwnerId, GroupId, utility:client_ip(Arg)),
    FirstElement = fun([])    -> <<"">>;
                      ([V|_]) -> list_to_binary(V) 
                   end, 
    utility:pl2jso([{status, ok}, {members, utility:a2jsos([member_id, {name, fun erlang:list_to_binary/1}, 
                                                                       {empolyee_id, fun erlang:list_to_binary/1},
                                                                       phone,	
                                                                       department_id,
                                                                       {department, fun erlang:list_to_binary/1},
                                                                       {mail, FirstElement},
                                                                       photo,
                                                                       status],	
    	                                                    Members)}]);
%% handle create new group request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    OwnerId = utility:get_value(Json, "owner_id"),
    GroupName = utility:get_value(Json, "name"),
    GroupAttr = utility:get_value(Json, "attribute"),
    GroupId = create_group(OwnerId, GroupName, GroupAttr, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {group_id, GroupId}]);
%% handle delete group request
handle(Arg, 'DELETE', []) ->
    {ok, OwnerId} = yaws_api:queryvar(Arg, "owner_id"),
    {ok, GroupId} = yaws_api:queryvar(Arg, "group_id"),
    ok = delete_group(OwnerId, GroupId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);


%% handle delete external member
handle(Arg, 'DELETE', ["external", "members"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    ExID = utility:query_integer(Arg, "external_uuid"),
    del_external(UUID, ExID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle add external members 
handle(Arg, 'POST', ["external", "members"]) ->
    {UUID, Members} = utility:decode(Arg, [{uuid, i}, 
                                           {members, ao, [{markname, s},{account, s},
                                                           {phone, b},{mail, b}]}]),
    Externals = add_externals(UUID, Members, utility:client_ip(Arg)),
     
    utility:pl2jso([{status,ok}, {external, utility:a2jsos([uuid, 
                                                        {name, fun erlang:list_to_binary/1},
                                                        {eid, fun erlang:list_to_binary/1},
                                                        {markname, fun erlang:list_to_binary/1},
                                                        phone,
                                                        mail,
                                                        status
                                                        ],
                                               Externals)
                               }]);

%% handle add new members 
handle(Arg, 'POST', [GroupId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    OwnerId = utility:get_value(Json, "owner_id"),
    MemberIds = utility:get_array(Json, "member_ids"),
    ok = add_members(OwnerId, GroupId, MemberIds, utility:client_ip(Arg)),  
    utility:pl2jso([{status,ok}]);

%% handle delete group members
handle(Arg, 'DELETE', [GroupId, "members"]) ->
    {ok, OwnerId} = yaws_api:queryvar(Arg, "owner_id"),
    {ok, MemberIds} = yaws_api:queryvar(Arg, "member_ids"),
    ok = delete_members(OwnerId, GroupId, MemberIds, utility:client_ip(Arg)),  
    utility:pl2jso([{status, ok}]);
%% handle change group name
handle(Arg, 'PUT', [GroupId]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    OwnerId = utility:get_value(Json, "owner_id"),
    NewName = utility:get_value(Json, "name"),
    ok= change_name(OwnerId, GroupId, NewName, utility:client_ip(Arg)),  
    utility:pl2jso([{status ,ok}]).

%%% RPC calls
-include("snode.hrl").

all_groups(OwnerId, SessionIP) ->
    io:format("all_groups ~p  ~n", [OwnerId]),
    %% [{1, "group1", "rr"}, {2, "group2", "rd"}],
    %%{value, Groups} = rpc:call(snode:get_service_node(), lw_group, get_all_groups, [list_to_integer(OwnerId)]),
    UUID = list_to_integer(OwnerId),
    {value, Groups} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, get_all_groups, [UUID], SessionIP]),

    lists:reverse(Groups).
  %%  throw(service_not_available).

all_members(OwnerId, GroupId, SessionIP) ->
    io:format("all_members ~p ~p  ~n", [OwnerId, GroupId]),
    %%[{1, "dhui",  "0131000020", ["00861334567890"], 123, "R&D", ["dhui@livecom.hk"], <<"photo.gif">>,online},
    %%{2, "xuxin", "0131000022", ["00861355567890"], 234, "R&D", ["xuxin@livecom.hk"], <<"photo.gif">>,offline}
    %%].
   %%{value, Members} = rpc:call(snode:get_service_node(), lw_group, get_all_members, [list_to_integer(OwnerId), list_to_integer(GroupId)]),
    UUID = list_to_integer(OwnerId),
    {value, Members} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, get_all_members, [list_to_integer(OwnerId), list_to_integer(GroupId)], SessionIP]),


    %%io:format("members: ~p~n", [Members]),
    Members.

create_group(OwnerId, GroupName, GroupAttr, SessionIP) ->
   io:format("create group ~p ~p ~p ~n", [OwnerId, GroupName, GroupAttr]),
   %%1234.
   %%{value, GroupId} = rpc:call(snode:get_service_node(), lw_group, create_group, [list_to_integer(OwnerId), 
   %%                                                             GroupName, GroupAttr]),
UUID = list_to_integer(OwnerId),
    {value, GroupId} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, create_group, [list_to_integer(OwnerId), GroupName, GroupAttr], SessionIP]),


   GroupId.

delete_group(OwnerId, GroupId, SessionIP) ->
    io:format("delete group ~p ~p  ~n", [OwnerId, GroupId]),
    %%rpc:call(snode:get_service_node(), lw_group, delete_group, [list_to_integer(OwnerId), list_to_integer(GroupId)]).
   UUID = list_to_integer(OwnerId),
   {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, delete_group, [list_to_integer(OwnerId), list_to_integer(GroupId)], SessionIP]),

    ok.

add_members(OwnerId, GroupId, MembersIds, SessionIP) ->
    io:format("add_members ~p ~p ~p ~n", [OwnerId, GroupId, MembersIds]),  
    %%rpc:call(snode:get_service_node(), lw_group, add_members, [list_to_integer(OwnerId), list_to_integer(GroupId),
    %%                                         [list_to_integer(I) || I<-MembersIds]]).
UUID = list_to_integer(OwnerId),
{value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, add_members, [list_to_integer(OwnerId), list_to_integer(GroupId),[list_to_integer(I) || I<-MembersIds]], SessionIP]),

  ok.
delete_members(OwnerId, GroupId, MembersIds, SessionIP) ->
    io:format("delete_members ~p ~p ~p ~n", [OwnerId, GroupId, MembersIds]),
%%    rpc:call(snode:get_service_node(), lw_group, delete_members, [list_to_integer(OwnerId), list_to_integer(GroupId),
%%                                                [list_to_integer(I) || I<-string:tokens(MembersIds, ",")]]).
UUID = list_to_integer(OwnerId),
{value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, delete_members, [list_to_integer(OwnerId), list_to_integer(GroupId),[list_to_integer(I) || I<-string:tokens(MembersIds, ",")]], SessionIP]),
ok.
change_name(OwnerId, GroupId, NewName, SessionIP) ->
    io:format("change_name ~p ~p ~p ~n", [OwnerId, GroupId, NewName]),
%%    rpc:call(snode:get_service_node(), lw_group, change_group_name, [list_to_integer(OwnerId), list_to_integer(GroupId), NewName]).
UUID = list_to_integer(OwnerId),
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_group, change_group_name, [list_to_integer(OwnerId), list_to_integer(GroupId), NewName], SessionIP]),
   ok.


add_externals(UUID, Members, SessionIP) ->
    io:format("add_externals ~p ~p ~n", [UUID, Members]),
    {value, Res} = rpc:call(snode:get_service_node(), lw_instance, request, 
                           [UUID, lw_group, add_external_partner, [UUID, Members], SessionIP]),
    Res.


del_external(UUID, ExID, SessionIP) -> 
   io:format("del_external ~p ~p ~n", [UUID, ExID]),
    {value, Res} = rpc:call(snode:get_service_node(), lw_instance, request, 
                           [UUID, lw_group, del_external_partner, [UUID, ExID], SessionIP]),
    Res.