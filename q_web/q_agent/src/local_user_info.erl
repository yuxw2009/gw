%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user group
%%% @end
%%%--------------------------------------------------------------------------------------
-module(local_user_info).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

%%%-------------------------------------------------------------------------------------
%%% Auth
%%%-------------------------------------------------------------------------------------

get_user_id(OrgID,EmployeeID) ->
    F = fun() ->
            case mnesia:read(lw_auth,{OrgID,EmployeeID}) of
                [] -> 
                    failed;
                [#lw_auth{uuid = UUID}] ->
                    UUID
            end
        end,
    mnesia:activity(transaction,F).

login(MarkName,EmployeeID,MD5) ->
    case get_org_id_by_mark_name(MarkName) of
        failed ->
            {failed,wrong_auth};
        OrgID ->
            case check({OrgID,EmployeeID},MD5) of
                false ->
                    {failed,wrong_auth};
                UUID ->
                    {ok,OrgID,UUID}
            end
    end.

%%--------------------------------------------------------------------------------------

modify_password(_UUID,MarkName,EmployeeID,Old,New) ->
    OrgID = get_org_id_by_mark_name(MarkName),
    case check({OrgID,EmployeeID},Old) of
        false ->
            failed;
        _ ->
            do_modify_password(OrgID,EmployeeID,New)
    end.

%%--------------------------------------------------------------------------------------

check({OrgID,EmployeeID},MD5) ->
    F = fun() ->
            case mnesia:read(lw_auth,{OrgID,EmployeeID}) of
                []  -> false;
                [#lw_auth{uuid = UUID,md5 = MD5}] -> UUID;
                [_] -> false
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_modify_password(OrgID,EmployeeID,New) ->
    F = fun() ->
            [Auth] = mnesia:read(lw_auth,{OrgID,EmployeeID},write),
            mnesia:write(Auth#lw_auth{md5 = New})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

save_auth(OrgID,EID,UserID,Password) ->
    F = fun()->
            mnesia:write(#lw_auth{id = {OrgID,EID},md5 = Password,uuid = UserID})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

del_auth(OrgID,EID) ->
    F = fun()->
            [Auth] = mnesia:read(lw_auth,{OrgID,EID},write),
            mnesia:delete(lw_auth,{OrgID,EID},write),
            Auth#lw_auth.uuid
        end,
    mnesia:activity(transaction,F).  

%%--------------------------------------------------------------------------------------

get_org_hierarchy(MarkName) when is_list(MarkName) ->
    OrgID = get_org_id_by_mark_name(MarkName),
    do_get_org_hierarchy(OrgID);
get_org_hierarchy(UserID) when is_integer(UserID) ->
    [OrgID] = get_user_attr(UserID,[org_id]),
    do_get_org_hierarchy(OrgID).

%%--------------------------------------------------------------------------------------

get_full_name(UserID) ->
    [OrgID] = get_user_attr(UserID,[org_id]),
    do_get_full_name(OrgID).

%%--------------------------------------------------------------------------------------

get_all_navigators(UserID) ->
    [OrgID] = get_user_attr(UserID,[org_id]),
    do_get_all_navigators(OrgID).

%%--------------------------------------------------------------------------------------

get_user_profile(UserID) ->
    {Profile,Group,DefGroup,DefView,UnRead} = do_get_user_profile(UserID),
    [{profile,Profile},
     {groups,lists:reverse(Group)},
     {default_group,DefGroup},
     {default_view,DefView},
     {unread_events,UnRead},
     {external,lists:zipwith(fun(X,Y) -> erlang:append_element(X, Y) end, 
                             get_external_partner(UserID), 
                             lw_router:get_registered_states(get_external_partnerid(UserID)))}].

%%%-------------------------------------------------------------------------------------
%%% Group
%%%-------------------------------------------------------------------------------------

get_user(UUID) when is_integer(UUID) ->
    [User] = get_user([UUID]),
    User;
get_user(UUIDs) when is_list(UUIDs) ->
    F1= fun(UUID) -> [User] = mnesia:read(lw_instance,UUID),User end,
    F2= fun() -> [F1(UUID)||UUID<-UUIDs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

do_get_all_groups(UUID) ->
    [Groups] = get_user_attr(UUID,[group]),
    Groups.

do_get_user_profile(UUID) ->
    User = get_user(UUID),
    {get_profile(User),
     get_groups_attr(User),
     User#lw_instance.default_group,
     User#lw_instance.default_view,
     []}.

get_profile(User) ->
    [User#lw_instance.uuid,
     User#lw_instance.employee_name,
     User#lw_instance.employee_id,
     User#lw_instance.phone,
     get_department_name(User#lw_instance.department_id),
     User#lw_instance.email,
     User#lw_instance.photo].

get_groups_attr(User) ->
    GroupIDs     = User#lw_instance.group,
    GroupAttrs   = get_group_attr(GroupIDs),
    GroupMembers = get_group_member(GroupIDs),
    [{User#lw_instance.org_id,"all","rr",[]}|lists:zipwith3(fun(X,{Y,Z},Member)->{X,Y,Z,Member} end,GroupIDs,GroupAttrs,GroupMembers)].

%%--------------------------------------------------------------------------------------

get_all_groups(UUID) ->
    GroupIDs   = do_get_all_groups(UUID),
    GroupsAttr = get_group_attr(GroupIDs),
    lists:zipwith(fun(X,{Y,Z}) -> {X,Y,Z} end, GroupIDs, GroupsAttr).

%%--------------------------------------------------------------------------------------

get_user_markname(UUID) ->
    F = fun() ->
            [#lw_instance{org_id = OrgID}]  = mnesia:read(lw_instance,UUID),
            [#lw_org{mark_name = MarkName}] = mnesia:read(lw_org,OrgID),
            MarkName
        end,
    mnesia:activity(transaction,F).

get_all_members(_UserID,GroupID,admin) ->
    Type    = get_group_type(GroupID),
    Members = get_all_members_by_type(GroupID,Type),
    collect_members_info(Members,admin).

get_all_members(_UserID, GroupID) ->
    Type    = get_group_type(GroupID),
    Members = get_all_members_by_type(GroupID,Type),
    collect_members_info(Members).

%%--------------------------------------------------------------------------------------

create_group(UserID, GroupName, GroupAttr) ->
    GroupID = do_create_group(UserID,GroupName, GroupAttr),
    add_user_group(UserID,GroupID),
    GroupID.

%%--------------------------------------------------------------------------------------

delete_group(UserID, GroupID) when is_integer(GroupID) ->
    delete_group(UserID,[GroupID]);
delete_group(UserID,GroupIDs) when is_list(GroupIDs) ->
    del_user_group(UserID,GroupIDs),
    do_delete_group(UserID,GroupIDs).

%%--------------------------------------------------------------------------------------

add_user_group(UserID,GroupID) ->
    F = fun() -> update_table(lw_instance,group,UserID,GroupID,fun(New,Old) -> [New|Old] end) end,
    mnesia:activity(transaction,F).

del_user_group(UserID,GroupIDs) ->
    F = fun() -> update_table(lw_instance,group,UserID,GroupIDs,fun(New,Old) -> Old -- New end) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

add_members(_UserID, GroupId, MemeberIds) ->
    F = fun() ->
            update_table(lw_group,member,GroupId,MemeberIds,fun(New,Old) -> set_add(New,Old) end)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

delete_members(_UserID, GroupId, MemeberIds) ->
    F = fun() ->
            update_table(lw_group,member,GroupId,MemeberIds,fun(New,Old) -> Old -- New end)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

change_group_name(_UserID, GroupId, NewName) ->
    F = fun() ->
            update_table(lw_group,group_name,GroupId,NewName,fun(New,_Old) -> New end)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_group_member(GroupID) when is_integer(GroupID) ->
    [Member] = get_group_member([GroupID]),
    Member;
get_group_member(GroupIDs) when is_list(GroupIDs) ->
    F1= fun(GroupID) -> [Member] = do_get_attr(GroupID,lw_group,[member]),Member end,
    F2= fun() -> [F1(GroupID)||GroupID<-GroupIDs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

get_group_attr(GroupID) when is_integer(GroupID) ->
    [GroupAttr] = get_group_attr([GroupID]),
    GroupAttr;
get_group_attr(GroupIDs) when is_list(GroupIDs) ->
    F1=fun(GroupID) ->
            [GroupName,GroupAttr] = do_get_attr(GroupID,lw_group,[group_name,attribute]),
            {GroupName,GroupAttr} 
        end,
    F2=fun()-> [F1(GroupID)||GroupID<-GroupIDs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

get_group_type(GroupID) ->
    {Type,GroupID} = get_id_type(GroupID),
    case Type of
        not_department -> group;
        _ -> Type
    end.

%%--------------------------------------------------------------------------------------

get_all_members_by_type(GroupID,group) ->
    get_group_member(GroupID);
get_all_members_by_type(GroupID,_) ->
    get_atom_uuids([GroupID]).

%%--------------------------------------------------------------------------------------

get_user_info(UUID) when is_integer(UUID) ->
    [Info] = get_user_info([UUID]),
    Info;
get_user_info(UUIDs) when is_list(UUIDs) ->
    Users = get_user(UUIDs),
    DepartmentIDs   = [User#lw_instance.department_id||User<-Users],
    DepartmentNames = get_department_name(DepartmentIDs),
    [trans_profile_format(ZipUser)||ZipUser<-lists:zip(Users,DepartmentNames)].

trans_profile_format({UserInfo,DepartmentName}) ->
    {UserInfo#lw_instance.uuid,
     UserInfo#lw_instance.employee_name,
     UserInfo#lw_instance.employee_id,
     UserInfo#lw_instance.phone,
     UserInfo#lw_instance.department_id,
     DepartmentName,
     UserInfo#lw_instance.email,
     UserInfo#lw_instance.photo}.

get_user_info(UUID,admin) when is_integer(UUID) ->
    [Info] = get_user_info([UUID],admin),
    Info;
get_user_info(UUIDs,admin) when is_list(UUIDs) ->
    Users = get_user(UUIDs),
    DepartmentIDs   = [User#lw_instance.department_id||User<-Users],
    DepartmentNames = get_department_name(DepartmentIDs),
    [trans_profile_format(ZipUser,admin)||ZipUser<-lists:zip(Users,DepartmentNames)].

trans_profile_format({UserInfo,DepartmentName},admin) ->
    {UserInfo#lw_instance.uuid,
     UserInfo#lw_instance.employee_name,
     UserInfo#lw_instance.employee_id,
     UserInfo#lw_instance.phone,
     UserInfo#lw_instance.department_id,
     DepartmentName,
     UserInfo#lw_instance.email,
     UserInfo#lw_instance.photo,
     UserInfo#lw_instance.reverse}.

%%--------------------------------------------------------------------------------------

add_external_partner(UUID,ExternalPartners) ->
    FindOrgID = fun(MarkName) ->
                    case mnesia:index_read(lw_org,MarkName,#lw_org.mark_name) of
                        [] -> not_found;
                        [#lw_org{id = OrgID}] -> OrgID
                    end
                end,
    IsSameOrg = fun(OrgID) ->
                    [#lw_instance{org_id = SelfOrgID}] = mnesia:read(lw_instance,UUID),
                    case OrgID =:= SelfOrgID of
                        true  -> same;
                        false -> not_same
                    end
                end,
    GetPartnerID  = fun(OrgID,EmployeeID) ->
                        case mnesia:read(lw_auth,{OrgID,EmployeeID}) of
                            [] -> not_found;
                            [#lw_auth{uuid = PartnerID}] -> PartnerID
                        end
                    end,
    AppendExternal= fun(PartnerID,MarkName,EmployeeID,Phone,EMail) ->
                        [#lw_instance{employee_name = Name}] = mnesia:read(lw_instance,PartnerID),
                        case mnesia:read(lw_external_partner,UUID,write) of
                            [] ->
                                mnesia:write(#lw_external_partner{uuid = UUID,partner = [{PartnerID,Name,EmployeeID,MarkName,Phone,EMail}]});
                            [#lw_external_partner{partner = Partner} = External] ->
                                mnesia:write(External#lw_external_partner{partner = lists:ukeysort(1,[{PartnerID,Name,EmployeeID,MarkName,Phone,EMail}|Partner])})
                        end,
                        {PartnerID,Name,EmployeeID,MarkName,Phone,EMail}
                    end,
    F1= fun({MarkName,EmployeeID,Phone,EMail}) ->
            case FindOrgID(MarkName) of
                not_found ->
                    not_found;
                OrgID ->
                    case IsSameOrg(OrgID) of
                        same -> 
                            not_found;
                        not_same ->
                            case GetPartnerID(OrgID,EmployeeID) of
                                not_found ->
                                    not_found;
                                PartnerID ->
                                    AppendExternal(PartnerID,MarkName,EmployeeID,Phone,EMail)
                            end
                    end
            end
        end,
    F2= fun() -> [F1(ExternalPartner)||ExternalPartner<-ExternalPartners] end,
    R = mnesia:activity(transaction,F2),
    ExtPtns = lists:usort([X||X <- R,X =/= not_found]),
    Status = lw_router:get_registered_states([element(1,ExtPtn)||ExtPtn<-ExtPtns]),
    lists:zipwith(fun(X,Y) -> erlang:append_element(X, Y) end,ExtPtns,Status).

del_external_partner(UUID,DeleteID) ->
    F = fun() ->
            [#lw_external_partner{partner = Partner} = External] = mnesia:read(lw_external_partner,UUID,write),
            mnesia:write(External#lw_external_partner{partner = lists:keydelete(DeleteID,1,Partner)})
        end,
    mnesia:activity(transaction,F),
    ok.

modify_external_partner_phone(UUID,PartnerID,NewPhone,NewEmail) ->
    F = fun() ->
            [#lw_external_partner{partner = Partners} = External] = mnesia:read(lw_external_partner,UUID,write),
            {PartnerID,Name,EmployeeID,MarkName,_,_} = lists:keyfind(PartnerID,1,Partners),
            mnesia:write(External#lw_external_partner{partner = lists:keyreplace(PartnerID,1,Partners,{PartnerID,Name,EmployeeID,MarkName,NewPhone,NewEmail})})
        end,
    mnesia:activity(transaction,F),
    ok.

get_external_partner(UUID) ->
    F = fun() ->
            case mnesia:read(lw_external_partner,UUID) of
                [] -> [];
                [#lw_external_partner{partner = Partners}] -> Partners
            end
        end,
    mnesia:activity(transaction,F).

get_external_partnerid(UUID) ->
    ExternalPartners = get_external_partner(UUID),
    [element(1,ExternalPartner)||ExternalPartner<-ExternalPartners].

%%--------------------------------------------------------------------------------------

collect_members_info(Members,admin) -> {Members,get_user_info(Members,admin)}.
collect_members_info(Members) -> {Members,get_user_info(Members)}.

%%--------------------------------------------------------------------------------------

do_create_group(UserID, GroupName, GroupAttr) ->
    GroupID = lw_id_creater:generate_uuid(),
    handle_new_group(GroupID, UserID, GroupName, GroupAttr),
    GroupID.

handle_new_group(GroupID, UserID, GroupName, GroupAttr) ->
    F = fun() ->
            mnesia:write(#lw_group{uuid=GroupID,user_id=UserID,group_name=GroupName,attribute=GroupAttr}),
            mnesia:write(#lw_verse_group{name={UserID,GroupName},uuid=GroupID})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_delete_group(UserID,GroupIDs) when is_list(GroupIDs) ->
    F1= fun(GroupID) ->
            [UserID,GroupName] = do_get_attr(GroupID,lw_group,[user_id,group_name]),
            mnesia:delete(lw_group,GroupID,write),
            mnesia:delete(lw_verse_group,{UserID,GroupName},write)
        end,
    F2= fun() -> [F1(GroupID)||GroupID<-GroupIDs],ok end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

-define(GET_ATTR(Term,Table,Tag),do_get_attr1(Term,Table,Tag) when is_atom(Tag) ->
    Term#Table.Tag).

do_get_attr(Key,Table,Tags) when is_list(Tags) ->
    case mnesia:read(Table,Key,read) of
        []     -> [];
        [Term] -> [do_get_attr1(Term,Table,Tag)||Tag<-Tags]
    end.

?GET_ATTR(Term,lw_group,user_id);
?GET_ATTR(Term,lw_group,member);
?GET_ATTR(Term,lw_group,group_name);
?GET_ATTR(Term,lw_group,attribute);
?GET_ATTR(Term,lw_verse_group,uuid);
?GET_ATTR(Term,lw_unread,unread);
?GET_ATTR(Term,lw_instance,group);
?GET_ATTR(Term,lw_instance,org_id);
?GET_ATTR(Term,lw_instance,department_id);
?GET_ATTR(Term,lw_instance,employee_name);
?GET_ATTR(Term,lw_instance,employee_id);
?GET_ATTR(Term,lw_org,full_name);
?GET_ATTR(Term,lw_org,mark_name);
?GET_ATTR(Term,lw_org,navigators);
?GET_ATTR(Term,lw_org,top_departments);
?GET_ATTR(Term,lw_department,name);
?GET_ATTR(Term,lw_department,up);
?GET_ATTR(Term,lw_department,downs);
?GET_ATTR(Term,lw_department,employees).

%%--------------------------------------------------------------------------------------

-define(UPDATE_TAB(Tab,Tag,Key,Content,Act),update_table(Tab,Tag,Key,Content,Act) ->
    [Item] = mnesia:read(Tab,Key,write),
    Old    = Item#Tab.Tag,
    New    = Act(Content,Old),
    mnesia:write(Item#Tab{Tag = New})).

?UPDATE_TAB(lw_group,member,ID,Content,Act);
?UPDATE_TAB(lw_group,group_name,ID,Content,Act);
?UPDATE_TAB(lw_unread,unread,ID,Content,Act);
?UPDATE_TAB(lw_instance,group,ID,Content,Act);
?UPDATE_TAB(lw_instance,phone,ID,Content,Act);
?UPDATE_TAB(lw_instance,email,ID,Content,Act);
?UPDATE_TAB(lw_instance,photo,ID,Content,Act);
?UPDATE_TAB(lw_instance,department_id,ID,Content,Act);
?UPDATE_TAB(lw_department,downs,ID,Content,Act);
?UPDATE_TAB(lw_department,name,ID,Content,Act);
?UPDATE_TAB(lw_department,employees,ID,Content,Act);
?UPDATE_TAB(lw_org,navigators,ID,Content,Act).

%%--------------------------------------------------------------------------------------

set_add(L1,L2) ->
    S1 = sets:from_list(L1),
    S2 = sets:from_list(L2),
    sets:to_list(sets:union(S1, S2)).

%%--------------------------------------------------------------------------------------

update_recent_group(UUID,MemeberIds) ->
    GroupID = get_uuid(UUID,"recent"),
    Filter = [ID||{Type,ID}<-get_id_type(MemeberIds),not_department =:= Type],
    F1= fun(New,Old)->lists:sublist(lists:foldl(fun(E,A)->[E|lists:delete(E,A)] end,Old,New),1,20) end,
    F2= fun() -> update_table(lw_group,member,GroupID,Filter,F1) end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

get_uuid(UserID,GroupName) ->
    F = fun() -> [GroupID] = do_get_attr({UserID,GroupName},lw_verse_group,[uuid]),GroupID end,
    mnesia:activity(transaction,F).

%%%-------------------------------------------------------------------------------------
%%% Instance
%%%-------------------------------------------------------------------------------------

get_user_attr(UserID,Types) when is_list(Types) ->
    F = fun() -> do_get_attr(UserID,lw_instance,Types) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_user_audit_info(UUID) ->
    [EID,EName,DepID,OrgID] = get_user_attr(UUID,[employee_id,employee_name,department_id,org_id]),
    DepFullName = collect_department_name(DepID),
    {UUID,DepFullName,EName,EID,OrgID}.

collect_department_name(DepID) ->
    F = fun(Department,Acc) -> [Department#lw_department.name|Acc] end,
    department_iter(DepID,F,[]).

department_iter(top,_,Acc) ->
    string:join(Acc,"/");
department_iter(DepID,Act,Acc) ->
    F   = fun() -> [Department] = mnesia:read(lw_department,DepID),Department end,
    Dep = mnesia:activity(transaction,F),
    NewAcc = Act(Dep,Acc),
    department_iter(Dep#lw_department.up,Act,NewAcc).

%%--------------------------------------------------------------------------------------

modify_user_info(UUID,Telephone,EMail) ->
    F = fun() ->
            update_table(lw_instance,phone,UUID,Telephone,fun(New,_Old) -> New end),
            update_table(lw_instance,email,UUID,EMail,fun(New,_Old) -> New end)
        end,
    mnesia:activity(transaction,F).

modify_user_photo(UUID,PhotoURL) ->
    F = fun() -> update_table(lw_instance,photo,UUID,PhotoURL,fun(New,_Old) -> New end) end,
    mnesia:activity(transaction,F).

modify_user_department(UUID,DepartmentID) when is_integer(UUID) ->
    modify_user_department([UUID],DepartmentID);
modify_user_department(UUIDs,DepartmentID) when is_list(UUIDs) ->
    F1= fun(UUID) -> update_table(lw_instance,department_id,UUID,DepartmentID,fun(New,_Old) -> New end) end,
    F2= fun() -> [F1(UUID)||UUID<-UUIDs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

update_user_cost(UUID,NewCost) ->
    F = fun() ->
            case mnesia:read(lw_instance,UUID) of
                [] -> 
                    ok;
                [Ins] ->
                    Privilege    = Ins#lw_instance.reverse,
                    NewPrivilege = 
                        case lists:keyfind(cost,1,Privilege) of
                            false ->
                                Privilege ++ [{cost,NewCost}];
                            {cost,Cost} ->
                                lists:keyreplace(cost,1,Privilege,{cost,Cost + NewCost})
                        end,
                    mnesia:write(Ins#lw_instance{reverse = NewPrivilege})
            end
        end,
    mnesia:activity(transaction,F).

get_user_cost(UUID) ->
    F = fun() ->
            [Ins] = mnesia:read(lw_instance,UUID),
            Privilege    = Ins#lw_instance.reverse,
            {cost,Cost}  = lists:keyfind(cost,1,Privilege),
            Cost
        end,
    mnesia:activity(transaction,F).

reset_user_cost(UUID) ->
    F = fun() ->
            [Ins] = mnesia:read(lw_instance,UUID,write),
            Privilege = Ins#lw_instance.reverse,
            mnesia:write(Ins#lw_instance{reverse = lists:keyreplace(cost,1,Privilege,{cost,0.0})})
        end,
    mnesia:activity(transaction,F).

reset_all_user_cost() ->
    F1= fun(UUID) ->
            [Ins] = mnesia:read(lw_instance,UUID,write),
            Privilege = Ins#lw_instance.reverse,
            mnesia:write(Ins#lw_instance{reverse = lists:keyreplace(cost,1,Privilege,{cost,0.0})})
        end,
    F = fun() ->
            AllUUIDs = mnesia:all_keys(lw_instance),
            [F1(UUID)||UUID<-AllUUIDs]
        end,
    mnesia:activity(transaction,F).

check_user_privilege(UUID,Type) ->
    F = fun() ->
            [Ins] = mnesia:read(lw_instance,UUID),
            OrgID = Ins#lw_instance.org_id,
            Privilege = Ins#lw_instance.reverse,
            [OrgRes] = mnesia:read(lw_org_attr,OrgID),
            case check_org_res_txn(OrgRes,orgcost,0) of
                false ->
                    org_out_of_money;
                true ->
                    case check_type_privilege(Type,Privilege) of
                        disable ->
                            disable;
                        enable ->
                            check_balance_privilege(Type,Privilege)
                    end
            end
        end,
    mnesia:activity(transaction,F).

check_type_privilege(Type,Privilege) ->
    case lists:keyfind(Type,1,Privilege) of
        false ->
            disable;
        {Type,Content} ->
            Content
    end.

check_balance_privilege(dataconf,_) ->
    ok;

check_balance_privilege(sms,_) ->
    ok;

check_balance_privilege(_,Privilege) ->
    case lists:keyfind(balance,1,Privilege) of
        false ->
            disable;
        {balance,Balance} ->
            case lists:keyfind(cost,1,Privilege) of
                false ->
                    out_of_money;
                {cost,Cost} ->
                    case (Balance - Cost) > 0.0 of
                        true  -> ok;
                        false -> out_of_money
                    end
            end
    end.

%%--------------------------------------------------------------------------------------

save_instance(UserID,Name,OrgID,EID,DepartmentID,Phone,Email,Balance,Auth) ->
    F = fun() ->
            Ins = #lw_instance{uuid=UserID,employee_name=Name,org_id=OrgID,employee_id=EID,department_id=DepartmentID,phone=Phone,email=Email,reverse=[{cost,0.0},{balance,Balance}] ++ Auth},
            mnesia:write(Ins)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

del_instance(UUID) ->
    F = fun() ->
            [Instance] = mnesia:read(lw_instance,UUID),
            mnesia:write(erlang:setelement(1,Instance,lw_instance_del)),
            mnesia:delete(lw_instance,UUID,write),
            Instance#lw_instance.department_id
        end,
    mnesia:activity(transaction,F).
    %do_delete_group(UUID,GroupIDs),
    %DepartmentID.

%%%-------------------------------------------------------------------------------------
%%% Department
%%%-------------------------------------------------------------------------------------

get_atom_uuids(UUIDs) when is_list(UUIDs) ->
    F = fun() ->
            Types = [do_get_id_type(UUID)||UUID<-UUIDs],
            [get_members_by_type(Type)||Type<-Types]
        end,
    lists:usort(lists:append(mnesia:activity(transaction,F))).

%%--------------------------------------------------------------------------------------
  
get_org_id_by_mark_name(MarkName) ->
    F = fun() ->
            case do_get_org_id_by_mark_name(MarkName) of
                [] -> failed;
                ID -> ID
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_id_type(ID) when is_integer(ID) ->
    [Type] = get_id_type([ID]),
    Type;
get_id_type(IDs) when is_list(IDs) ->
    F1= fun(ID) -> do_get_id_type(ID) end,
    F2= fun() -> [F1(ID)||ID<-IDs] end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

get_department_name(DepartmentID) when is_integer(DepartmentID) ->
    [Name] = get_department_name([DepartmentID]),
    Name;
get_department_name(DepartmentIDs) when is_list(DepartmentIDs) ->
    F1= fun(DepartmentID) ->
            [Name] = do_get_attr(DepartmentID,lw_department,[name]),
            Name
        end,
    F2= fun() ->
            [F1(DepartmentID)||DepartmentID<-DepartmentIDs]
        end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

create_org(FullName, MarkName) ->
    create_org(FullName, MarkName, 10, 1, 10000,1000).

create_org(FullName, MarkName, PhoneConfNum, VideoConfNum, MaxMoney,MaxNum) ->
    case is_mark_name_exist(MarkName) of
        true ->
            error;
        false ->
            OrgID = lw_id_creater:generate_uuid(),
            TopDepartmentID = create_department(OrgID, FullName, top),
            save_org(OrgID,FullName, MarkName, TopDepartmentID, PhoneConfNum, VideoConfNum, MaxMoney,MaxNum),
            Name = lw_media_srv:build_org_media_srv_name(OrgID),
            zserver:start(Name,lw_org_media_srv,[]),
            OrgID
    end.

%%--------------------------------------------------------------------------------------

match_dep_name([],_) ->
    true;
match_dep_name([DepName|T],DepID) when is_integer(DepID) ->
    [#lw_department{name = Name,up = UpID}] = mnesia:dirty_read(lw_department,DepID),
    case Name =:= DepName of
        true -> match_dep_name(T,UpID);
        false -> false
    end.

fetch_dep_id(_,[]) ->
    false;
fetch_dep_id(FullNames,[DepID|T]) ->
    case match_dep_name(FullNames,DepID) of
        true  -> DepID;
        false -> fetch_dep_id(FullNames,T)
    end.

test_search_dep_id() ->
    search_dep_id(["新业务开发部","爱讯达科技(深圳)有限公司"]).

search_dep_id(FullNames) ->
    AllID = mnesia:dirty_all_keys(lw_department),
    case fetch_dep_id(FullNames,AllID) of
        false -> no_org;
        DepID -> DepID
    end.

%%--------------------------------------------------------------------------------------

delete_org(Org) ->
    F1= fun(OrgID) when is_integer(OrgID) ->
            [TopDepartmentID] = do_get_attr(OrgID,lw_org,[top_departments]),
            [Department] = mnesia:read(lw_department,TopDepartmentID),
            case is_department_could_be_deleted(Department) of
                true ->
                    mnesia:delete(lw_org,OrgID,write),
                    mnesia:delete(lw_org_attr,OrgID,write),
                    mnesia:delete(lw_department,TopDepartmentID,write),
                    OrgID;
                false -> error
            end
        end,
    F2= fun(MarkName) when is_list(MarkName) -> F1(do_get_org_id_by_mark_name(MarkName)) end,
    F3= fun() when is_integer(Org) -> F1(Org);
           () when is_list(Org) -> F2(Org)
        end,
    case mnesia:activity(transaction,F3) of
        error ->
            ok;
        OrgID ->
            Name = lw_media_srv:build_org_media_srv_name(OrgID),
            zserver:stop(Name),
            ok
    end.

%%--------------------------------------------------------------------------------------

change_org_full_name(Org,NewFullName) ->
    F1= fun(OrgID) when is_integer(OrgID) ->
            [OrgItem] = mnesia:read(lw_org,OrgID,write),
            mnesia:write(OrgItem#lw_org{full_name = NewFullName}),
            TopDepID = OrgItem#lw_org.top_departments,
            [TopDep] = mnesia:read(lw_department,TopDepID,write),
            mnesia:write(TopDep#lw_department{name = NewFullName})
        end,
    F2= fun(MarkName) when is_list(MarkName) -> F1(do_get_org_id_by_mark_name(MarkName)) end,
    F3= fun() when is_integer(Org) -> F1(Org);
           () when is_list(Org) -> F2(Org)
        end,
    mnesia:activity(transaction,F3),
    ok.

%%--------------------------------------------------------------------------------------

create_department(OrgID, DepartmentName) -> 
    create_department(OrgID, DepartmentName, under_top).

create_department(OrgID,DepartmentName,UPID) ->
    DepartmentID = lw_id_creater:generate_uuid(),
    do_create_department(OrgID,DepartmentID,DepartmentName,UPID),
    DepartmentID.

%%--------------------------------------------------------------------------------------

delete_department(OrgID, DepartmentID) ->
    F = fun() ->
            [Department] = mnesia:read(lw_department,DepartmentID,write),
            case is_department_match_org(OrgID,Department) andalso 
                 is_department_could_be_deleted(Department) of
                true ->
                    UPID = Department#lw_department.up,
                    mnesia:delete(lw_department, DepartmentID, write),
                    update_up_department_downs(del,UPID,DepartmentID);
                false ->
                    error
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

change_department_name(OrgID, DepartmentID, NewName) ->
    F = fun() ->
            [Department] = mnesia:read(lw_department,DepartmentID,write),
            case is_department_match_org(OrgID,Department) of
                true ->
                    update_department_name(DepartmentID, NewName);
                false ->
                    error
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

add_employee(OrgID, DepartmentID, UUIDs) ->
    F = fun() -> update_relate_department_employees(add, OrgID, DepartmentID, UUIDs) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

delete_employee(OrgID, DepartmentID, UUIDs) ->
    F = fun() -> update_relate_department_employees(del, OrgID, DepartmentID, UUIDs) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

move_employees(OrgID, SrcDepartmentID, DestDepartmentID, UUIDs) ->
    F = fun() ->
            case update_relate_department_employees(del, OrgID, SrcDepartmentID, UUIDs) of
                error -> error;
                ok ->
                    case update_relate_department_employees(add, OrgID, DestDepartmentID, UUIDs) of
                        error ->
                            update_relate_department_employees(add, OrgID, SrcDepartmentID, UUIDs),
                            error;
                        ok -> ok
                    end
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

add_navigators(OrgID, Navigators) ->
    F = fun() -> update_org_navigators(add,OrgID, Navigators) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

delete_navigators(OrgID, NavigatorKeys) ->
    F = fun() -> update_org_navigators(del,OrgID, NavigatorKeys) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

check_usernum_over(OrgID) ->
    F = fun() ->
            [#lw_org{top_departments = DepID}] = mnesia:read(lw_org,OrgID),
            [#lw_department{employees = Employees}] = mnesia:read(lw_department,DepID),
            [#lw_org_attr{max_employee_num = MaxEmployeeNum}] = mnesia:read(lw_org_attr,OrgID),
            length(Employees) < MaxEmployeeNum
        end,
    mnesia:activity(transaction,F).

check_usernum_over(OrgID,AddNum) ->
    F = fun() ->
            [#lw_org{top_departments = DepID}] = mnesia:read(lw_org,OrgID),
            [#lw_department{employees = Employees}] = mnesia:read(lw_department,DepID),
            [#lw_org_attr{max_employee_num = MaxEmployeeNum}] = mnesia:read(lw_org_attr,OrgID),
            length(Employees) + AddNum =< MaxEmployeeNum
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

add_user({OrgID,EID,Name,DepartmentID,Phone,Email,Pwd,Balance,Auth}) ->
    case auth_add(OrgID,EID,Pwd) of
        failed -> 
            EID;
        UserID ->
            instance_add(UserID,Name,OrgID,EID,DepartmentID,Phone,Email,Balance,Auth),
            add_employee(OrgID, DepartmentID, [UserID]),
            ok
    end.

%%--------------------------------------------------------------------------------------

read_file(FileName) ->
    {ok, Binary} = file:read_file(FileName),
    Lines_bin = re:split(Binary, "\n",[trim]),
    [[binary_to_list(Item)||Item<-re:split(L,":")]||L<-Lines_bin].

add_user(OrgID,DepID,FileName) ->
    IOrgID = list_to_integer(OrgID),
    IDepID = list_to_integer(DepID),
    F3= fun(Item,Acc) ->
            case add_user(Item) of
                ok -> Acc;
                EID -> [list_to_binary(EID)|Acc]
            end
        end,
    F2= fun("开通") -> enable;
           ("取消") -> disable
        end,
    F1= fun(CallBack,Voip,PhoneConf,SMS,DataConf) ->
            [{callback,F2(CallBack)},{voip,F2(Voip)},{phoneconf,F2(PhoneConf)},{sms,F2(SMS)},{dataconf,F2(DataConf)}]
        end,
    F = fun([EID,Name,Balance,CallBack,Voip,PhoneConf,SMS,DataConf]) ->
                      {IOrgID,EID,Name,IDepID,<<"{\"mobile\":\"\",\"pstn\":\"\",\"extension\":\"\",\"other\":[]}">>,[],hex:to(crypto:md5("888888")),list_to_integer(Balance),F1(CallBack,Voip,PhoneConf,SMS,DataConf)};
		 ([EID,Name,Balance,CallBack,Voip,PhoneConf,SMS,DataConf,Mobile,Pstn,Mail]) ->            
		      Phone_str =rfc4627:encode(utility:pl2jso([{mobile,Mobile},{pstn,Pstn},{extension,<<>>},{other,<<>>}])),
		      {IOrgID,EID,Name,IDepID,list_to_binary(Phone_str),Mail,hex:to(crypto:md5("888888")),list_to_integer(Balance),F1(CallBack,Voip,PhoneConf,SMS,DataConf)}
        end,
    Items  = read_file(FileName),
    FItems = [F(Item)||Item<-Items],
    case lists:foldl(F3,[],FItems) of
        [] -> ok;
        L -> {repeat,L}
    end.

add_user(OrgID,FileName) ->
    IOrgID = list_to_integer(OrgID), 
    F3= fun({no_org,EID},Acc) ->
                [{<<"no_org">>,list_to_binary(EID)}|Acc];
           (Item,Acc) ->
                case add_user(Item) of
                    ok -> Acc;
                    EID -> [{<<"repeat">>,list_to_binary(EID)}|Acc]
                end
        end,
    F2= fun("开通") -> enable;
           ("取消") -> disable
        end,
    F1= fun(CallBack,Voip,PhoneConf,SMS,DataConf) ->
            [{callback,F2(CallBack)},{voip,F2(Voip)},{phoneconf,F2(PhoneConf)},{sms,F2(SMS)},{dataconf,F2(DataConf)}]
        end,
    F = fun([DepFullNames,EID,Name,Balance,CallBack,Voip,PhoneConf,SMS,DataConf]) ->
            case local_user_info:search_dep_id(string:tokens(DepFullNames,";")) of
                no_org ->
                    {no_org,EID};
                IDepID ->
                    {IOrgID,EID,Name,IDepID,<<"{\"mobile\":\"\",\"pstn\":\"\",\"extension\":\"\",\"other\":[]}">>,[],hex:to(crypto:md5("888888")),list_to_integer(Balance),F1(CallBack,Voip,PhoneConf,SMS,DataConf)}
            end;
		 ([DepFullNames,EID,Name,Balance,CallBack,Voip,PhoneConf,SMS,DataConf,Mobile,Pstn,Mail]) ->            
	            case local_user_info:search_dep_id(string:tokens(DepFullNames,";")) of
	                no_org ->
	                    {no_org,EID};
	                IDepID ->
			      Phone_str =rfc4627:encode(utility:pl2jso([{mobile,list_to_binary(Mobile)},{pstn,list_to_binary(Pstn)},{extension,<<>>},{other,<<>>}])),
			      {IOrgID,EID,Name,IDepID,list_to_binary(Phone_str),[Mail],hex:to(crypto:md5("888888")),list_to_integer(Balance),F1(CallBack,Voip,PhoneConf,SMS,DataConf)}
			   end
        end,
    Items  = read_file(FileName),
    FItems = [F(Item)||Item<-Items],
    case local_user_info:check_usernum_over(IOrgID,length(FItems)) of
        true ->
            case lists:foldl(F3,[],FItems) of
                [] -> ok;
                L -> 
                    NoOrg  = [B||{A,B}<-L,A =:= <<"no_org">>],
                    Repeat = [B||{A,B}<-L,A =:= <<"repeat">>],
                    case NoOrg of
                        [] -> {repeat,Repeat};
                        _  -> {no_org,NoOrg}
                    end
            end;
        false ->
            employee_num_overflow
    end.

%%--------------------------------------------------------------------------------------

del_user({OrgID,EmployeeID}) ->
    UUID = del_auth(OrgID,EmployeeID),
    DepartmentID = del_instance(UUID),
    delete_employee(OrgID,DepartmentID,[UUID]),
    ok.

%%--------------------------------------------------------------------------------------

modify_user_department(OrgID,SrcDepartmentID, DestDepartmentID, UUID) when is_integer(UUID) ->
    modify_user_department(OrgID,SrcDepartmentID, DestDepartmentID, [UUID]);
modify_user_department(OrgID,SrcDepartmentID, DestDepartmentID, UUIDs) when is_list(UUIDs) ->
    modify_user_department(UUIDs,DestDepartmentID),
    move_employees(OrgID, SrcDepartmentID, DestDepartmentID, UUIDs).

%% above is used by manage , below is used by user login %%
%%--------------------------------------------------------------------------------------

do_get_org_hierarchy(OrgID) ->
    F = fun() -> get_org_hierarchy_recur(OrgID,top) end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_get_full_name(OrgID) ->
    F = fun() -> [FullName] = do_get_attr(OrgID,lw_org,[full_name]) , FullName end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_get_all_navigators(OrgID) ->
    F = fun() -> [Navigators] = do_get_attr(OrgID,lw_org,[navigators]) , Navigators end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

is_mark_name_exist(MarkName) when is_list(MarkName) ->
    F = fun() -> mnesia:index_read(lw_org,MarkName,#lw_org.mark_name) end,
    case mnesia:activity(transaction,F) of
        [] -> false;
        [_] -> true
    end.

%%--------------------------------------------------------------------------------------

save_org(OrgID,FullName,MarkName,TopDepartmentID,PhoneConfNum,VideoConfNum,MaxMoney,MaxNum) ->
    F = fun() ->
            Org=#lw_org{id=OrgID,full_name=FullName,mark_name=MarkName,top_departments=TopDepartmentID,admin_pass=hex:to(crypto:md5("888888")),other_attrs = [{phoneconf,PhoneConfNum},{videoconf,VideoConfNum}]},
            mnesia:write(Org),
            mnesia:write(#lw_org_attr{orgid=OrgID,phone={0,PhoneConfNum},video={0,VideoConfNum},cost={0.0,MaxMoney},max_employee_num=MaxNum})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_create_department(OrgID,DepartmentID,DepartmentName,UPID) ->
    F1= fun(under_top) -> [TopDepartmentID]=do_get_attr(OrgID,lw_org,[top_departments]),TopDepartmentID;
           (ID) -> ID
        end,
    F2= fun() ->
            UP  = F1(UPID),
            Dep = #lw_department{id=DepartmentID,org_id=OrgID,name=DepartmentName,up=UP},
            mnesia:write(Dep),
            update_up_department_downs(add,UP,DepartmentID)
        end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------

update_up_department_downs(_,top,_) ->
    ok;
update_up_department_downs(add,UPID,DepartmentID) ->
    F = fun(New,Olds) -> Olds ++ [New] end,
    update_table(lw_department,downs,UPID,DepartmentID,F);
update_up_department_downs(del,UPID,DepartmentID) ->
    F = fun(New,Olds) -> Olds -- [New] end,
    update_table(lw_department,downs,UPID,DepartmentID,F).

%%--------------------------------------------------------------------------------------

update_department_name(DepartmentID, NewName) ->
    F = fun(New,_Old) -> New end,
    update_table(lw_department,name,DepartmentID,NewName,F).

%%--------------------------------------------------------------------------------------

update_department_employees(add, DepartmentID, UUIDs) ->
    F = fun(New,Olds) -> Olds ++ New end,
    update_table(lw_department,employees,DepartmentID,UUIDs,F);
update_department_employees(del, DepartmentID, UUIDs) ->
    F = fun(New,Olds) -> Olds -- New end,
    update_table(lw_department,employees,DepartmentID,UUIDs,F).

%%--------------------------------------------------------------------------------------

update_org_navigators(add,OrgID,Navigators) ->
    F1= fun({Key,Content},List) ->
            case lists:keyfind(Key, 1, List) of
                false ->
                    [{Key,Content}|List];
                _ ->
                    lists:keyreplace(Key,1,List,{Key,Content})
            end
        end,
    F2= fun(New,Olds) -> lists:foldl(F1,Olds,New) end,
    update_table(lw_org,navigators,OrgID,Navigators,F2);
update_org_navigators(del,OrgID,NavigatorKeys) ->
    F1= fun(DelKey,Olds) -> lists:keydelete(DelKey,1,Olds) end,
    F2= fun(New,Olds) -> lists:foldl(F1,Olds,New) end,
    update_table(lw_org,navigators,OrgID,NavigatorKeys,F2).

%%--------------------------------------------------------------------------------------

is_department_match_org(OrgID, Department) ->
    Department#lw_department.org_id =:= OrgID.

%%--------------------------------------------------------------------------------------

is_department_could_be_deleted(Department) ->
    Downs     = Department#lw_department.downs,
    Employees = Department#lw_department.employees,
    ((Downs =:= []) and (Employees =:= [])).

%%--------------------------------------------------------------------------------------

is_department_leaf(Department) ->
    Downs = Department#lw_department.downs,
    (Downs =:= []).

%%--------------------------------------------------------------------------------------

update_relate_department_employees(Act, OrgID, DepartmentID, UUIDs) ->
    [Department] = mnesia:read(lw_department,DepartmentID,write),
    case is_department_match_org(OrgID,Department) andalso
         is_department_leaf(Department) of
        true ->
            do_update_relate_department_employees(Act, DepartmentID, UUIDs);
        false ->
            error
    end.

do_update_relate_department_employees(Act, DepartmentID, UUIDs) ->
    [UPID] = do_get_attr(DepartmentID,lw_department,[up]),
    update_department_employees(Act, DepartmentID, UUIDs),
    update_up_department_employees_iter(Act, UPID, UUIDs).

update_up_department_employees_iter(_Act, top, _UUIDs) ->
    ok;
update_up_department_employees_iter(Act, UPID, UUIDs) ->
    [NewUPID] = do_get_attr(UPID,lw_department,[up]),
    update_department_employees(Act, UPID, UUIDs),
    update_up_department_employees_iter(Act, NewUPID, UUIDs).

%%--------------------------------------------------------------------------------------

get_org_hierarchy_recur(OrgID,top) ->
    [MarkName,TopDepartmentID] = do_get_attr(OrgID,lw_org,[mark_name,top_departments]),
    [Downs] = do_get_attr(TopDepartmentID,lw_department,[downs]),
    DownsName = lists:map(fun(ID) -> [Name] = do_get_attr(ID,lw_department,[name]),Name end,Downs),
    DownRecur = lists:flatten(lists:map(fun(ID) -> get_org_hierarchy_recur(ID) end,Downs)),
    {MarkName,OrgID,lists:append([{top,lists:zip(Downs,DownsName)}],DownRecur)}.

get_org_hierarchy_recur(DepartmentID) ->
    [Department] = mnesia:read(lw_department,DepartmentID),
    case is_department_leaf(Department) of
        true -> [];
        false ->
            Downs     = Department#lw_department.downs,
            DownsName = lists:map(fun(ID) -> [Name] = do_get_attr(ID,lw_department,[name]),Name end,Downs),
            DownRecur = lists:flatten(lists:map(fun(ID) -> get_org_hierarchy_recur(ID) end,Downs)),
            lists:append([{DepartmentID,lists:zip(Downs,DownsName)}],DownRecur)
    end.

%%--------------------------------------------------------------------------------------

auth_add(OrgID,EID,Password) ->
    F = fun() ->
            case mnesia:read(lw_auth,{OrgID,EID}) of
                []  -> ok;
                [_] -> failed
            end  
        end,
    case mnesia:activity(transaction,F) of
        ok -> 
            UserID = lw_id_creater:generate_uuid(),
            save_auth(OrgID,EID,UserID,Password),
            UserID;
        failed ->
            failed
    end.

%%--------------------------------------------------------------------------------------

instance_add(UserID,Name,OrgID,EID,DepartmentID,Phone,Email,Balance,Auth) ->
    save_instance(UserID,Name,OrgID,EID,DepartmentID,Phone,Email,Balance,Auth),
    recent_add(UserID).

%%--------------------------------------------------------------------------------------

recent_add(UserID) ->
    create_group(UserID,"recent","rw").

external_add(UserID) ->
    create_group(UserID,"external","rw").

%%--------------------------------------------------------------------------------------

is_id_in_table(ID,Table) ->
    case mnesia:read(Table,ID,read) of
        []  -> false;
        [_] -> true
    end.

%%--------------------------------------------------------------------------------------

do_get_org_members(OrgID) ->
    [TopDepartmentID] = do_get_attr(OrgID,lw_org,[top_departments]),
    [Employees] = do_get_attr(TopDepartmentID,lw_department,[employees]),
    Employees.

%%--------------------------------------------------------------------------------------

do_get_department_members(DepartmentID) ->
    [Employees] = do_get_attr(DepartmentID,lw_department,[employees]),
    Employees.

%%--------------------------------------------------------------------------------------

do_get_id_type(ID) ->
    case is_id_in_table(ID,lw_org) of
        true  -> {org,ID};
        false ->
            case is_id_in_table(ID,lw_department) of
                true  -> {department,ID};
                false -> {not_department,ID}
            end
    end.

do_get_org_id_by_mark_name(MarkName) when is_list(MarkName) ->
    case mnesia:index_read(lw_org,MarkName,#lw_org.mark_name) of
        []    -> [];
        [Org] -> Org#lw_org.id
    end.

%%--------------------------------------------------------------------------------------

get_members_by_type({not_department,UUID}) -> 
    case mnesia:dirty_read(lw_instance,UUID) of
        []  -> [];
        [_] -> [UUID]
    end;
get_members_by_type({department,ID}) -> do_get_department_members(ID);
get_members_by_type({org,ID}) -> do_get_org_members(ID).

%%--------------------------------------------------------------------------------------

is_same_org(UUID,OwnerID) ->
    [User1] = mnesia:dirty_read(lw_instance,UUID),
    case mnesia:dirty_read(lw_instance,OwnerID) of
        [] -> false;
        [User2] -> User1#lw_instance.org_id =:= User2#lw_instance.org_id
    end.

%%--------------------------------------------------------------------------------------

test() ->
    test1(),
    io:format("~p~n",["test1 passed!"]),
    test2(),
    io:format("~p~n",["test2 passed!"]),
    test3(),
    io:format("~p~n",["test3 passed!"]),
    test4(),
    io:format("~p~n",["test4 passed!"]),
    test5(),
    io:format("~p~n",["test5 passed!"]),
    test6(),
    io:format("~p~n",["test6 passed!"]),
    test7(),
    io:format("~p~n",["test7 passed!"]),
    test8(),
    io:format("~p~n",["test8 passed!"]),
    test9(),
    io:format("~p~n",["test9 passed!"]),
    test10(),
    io:format("~p~n",["test10 passed!"]),
    test11(),
    io:format("~p~n",["test11 passed!"]),
    test12().

%%--------------------------------------------------------------------------------------

%% test for create and delete %%
test1() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    [Org] = mnesia:dirty_read(lw_org,OrgID),
    TopDepartmentID = Org#lw_org.top_departments,
    [Top] = mnesia:dirty_read(lw_department,TopDepartmentID),
    OrgID = Top#lw_department.org_id,
    ok = delete_org(OrgID),
    [] = mnesia:dirty_read(lw_org,OrgID),
    [] = mnesia:dirty_read(lw_department,TopDepartmentID).

%%--------------------------------------------------------------------------------------

%% test for delete by mark name %%
test2() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    [Org] = mnesia:dirty_read(lw_org,OrgID),
    TopDepartmentID = Org#lw_org.top_departments,
    [Top] = mnesia:dirty_read(lw_department,TopDepartmentID),
    OrgID = Top#lw_department.org_id,
    ok = delete_org("livecom"),
    [] = mnesia:dirty_read(lw_org,OrgID),
    [] = mnesia:dirty_read(lw_department,TopDepartmentID).

%%--------------------------------------------------------------------------------------

%% test for duplicated create %%
test3() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    error = create_org("爱迅达（深圳）科技有限公司","livecom"),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for change org full name %%
test4() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    ok = change_org_full_name(OrgID,"南京"),
    [Org] = mnesia:dirty_read(lw_org,OrgID),
    "南京" = Org#lw_org.full_name,
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for change org full name by mark name %%
test5() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    ok = change_org_full_name("livecom","南京"),
    [Org] = mnesia:dirty_read(lw_org,OrgID),
    "南京" = Org#lw_org.full_name,
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for del org which have sub department %%
test6() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID = create_department(OrgID, "缺省"),
    error = delete_org(OrgID),
    ok = delete_department(OrgID,DepID),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for change department name %%
test7() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID = create_department(OrgID, "缺省"),
    ok    = change_department_name(OrgID,DepID,"南京"),
    [Dep] = mnesia:dirty_read(lw_department,DepID),
    "南京" = Dep#lw_department.name,
    ok = delete_department(OrgID,DepID),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for del department with wrong orgid %%
test8() ->
    OrgID  = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID  = create_department(OrgID, "缺省"),
    error  = delete_department(aaa,DepID),
    ok = delete_department(OrgID,DepID),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for add employees,and then del department which have employee,
%% include could not be deleted that have employees in department
test9() ->
    OrgID  = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID  = create_department(OrgID, "缺省"),
    ok     = add_employee(OrgID, DepID, [1,2,3]),
    [Org]  = mnesia:dirty_read(lw_org,OrgID),
    [Top]  = mnesia:dirty_read(lw_department,Org#lw_org.top_departments),
    [Dep]  = mnesia:dirty_read(lw_department,DepID),
    [1,2,3] = Top#lw_department.employees,
    [1,2,3] = Dep#lw_department.employees,
    error  = delete_department(OrgID,DepID),
    ok = delete_employee(OrgID,DepID,[1,2,3]),
    ok = delete_department(OrgID,DepID),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for add employees which is not leaf department
%% and test his all up department employee,and delete employees in leaf department
%% and test delete his up department
test10() ->
    OrgID  = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID1 = create_department(OrgID, "研发部"),
    DepID2 = create_department(OrgID, "算法科", DepID1),
    ok     = add_employee(OrgID, DepID2, [1,2,3]),
    [Org]  = mnesia:dirty_read(lw_org,OrgID),
    [Top]  = mnesia:dirty_read(lw_department,Org#lw_org.top_departments),
    [Dep1] = mnesia:dirty_read(lw_department,DepID1),
    [Dep2] = mnesia:dirty_read(lw_department,DepID2),
    [1,2,3] = Top#lw_department.employees,
    [1,2,3] = Dep1#lw_department.employees,
    [1,2,3] = Dep2#lw_department.employees,
    error  = add_employee(OrgID,DepID1,[4,5,6]),
    ok = delete_employee(OrgID,DepID2,[1,2,3]),
    [ATop]  = mnesia:dirty_read(lw_department,Org#lw_org.top_departments),
    [ADep1] = mnesia:dirty_read(lw_department,DepID1),
    [ADep2] = mnesia:dirty_read(lw_department,DepID2),
    [] = ATop#lw_department.employees,
    [] = ADep1#lw_department.employees,
    [] = ADep2#lw_department.employees,
    error = delete_department(OrgID,DepID1),
    ok = delete_department(OrgID,DepID2),
    ok = delete_department(OrgID,DepID1),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

%% test for move employees
test11() ->
    OrgID  = create_org("爱迅达（深圳）科技有限公司","livecom"),
    DepID1 = create_department(OrgID, "研发部"),
    DepID2 = create_department(OrgID, "算法科", DepID1),
    DepID3 = create_department(OrgID, "市场部"),
    DepID4 = create_department(OrgID, "市场一科", DepID3),
    ok     = add_employee(OrgID, DepID2, [1,2,3]),
    error  = move_employees(aaa,DepID2,DepID4,[1,2,3]),
    error  = move_employees(OrgID,DepID1,DepID4,[1,2,3]),
    ok     = move_employees(OrgID,DepID2,DepID4,[1,3]),
    [Org]  = mnesia:dirty_read(lw_org,OrgID),
    [Top]  = mnesia:dirty_read(lw_department,Org#lw_org.top_departments),
    [Dep1] = mnesia:dirty_read(lw_department,DepID1),
    [Dep2] = mnesia:dirty_read(lw_department,DepID2),
    [Dep3] = mnesia:dirty_read(lw_department,DepID3),
    [Dep4] = mnesia:dirty_read(lw_department,DepID4),
    [2]     = Dep1#lw_department.employees,
    [2]     = Dep2#lw_department.employees,
    [1,3]   = Dep3#lw_department.employees,
    [1,3]   = Dep4#lw_department.employees,
    [2,1,3] = Top#lw_department.employees,
    ok = delete_employee(OrgID,DepID2,[2]),
    ok = delete_employee(OrgID,DepID4,[1,3]),
    error = delete_department(OrgID,DepID1),
    error = delete_department(OrgID,DepID3),
    ok = delete_department(OrgID,DepID2),
    ok = delete_department(OrgID,DepID4),
    ok = delete_department(OrgID,DepID1),
    ok = delete_department(OrgID,DepID3),
    ok = delete_org(OrgID).

%%--------------------------------------------------------------------------------------

test12() ->
    OrgID   = create_org("ai_xun_da","livecom"),
    DepID1  = create_department(OrgID, "yan_fa"),
    _DepID2 = create_department(OrgID, "suan_fa", DepID1),
    DepID3  = create_department(OrgID, "market"),
    _DepID4 = create_department(OrgID, "one", DepID3),
    get_org_hierarchy(OrgID).

%%--------------------------------------------------------------------------------------

add_wk() ->
    add_user({1,"0130000010","王凯",8,[],[],"livecom"}).

add_yxw() ->
    add_user({1,"0130000051","余晓文",9,[],[],"livecom"}).

%%--------------------------------------------------------------------------------------

add_livecom_org() ->
    OrgID = create_org("爱迅达（深圳）科技有限公司","livecom"),
    case OrgID of
        error ->
            error;
        _ ->
            add_navigators(OrgID,[{"计费系统",   "http://10.60.108.131:8080/"},
                          {"话务系统",   "http://10.60.108.131:8080/dm.html"},
                          {"文档服务器", "http://10.32.3.60:8080"}]),
            Dep1  = create_department(OrgID, "缺省"),
            Dep2  = create_department(OrgID, "财务部"),
            Dep3  = create_department(OrgID, "业务一部"),
            Dep4  = create_department(OrgID, "业务二部"),
            Dep5  = create_department(OrgID, "业务三部"),
            Dep6  = create_department(OrgID, "运营及工程维护部"),
            Dep7  = create_department(OrgID, "新业务开发部"),
            AllUserInfo = 
                [{OrgID,"10000841","陈江",Dep1,["008618676699420"],[""],"livecom"},
                 {OrgID,"0130000005","孟江宁",Dep1,["008618676699420"],[""],"livecom"},
                 {OrgID,"0131000036","祝小林",Dep1,["008613322991882"],[""],"livecom"},  
                 {OrgID,"0131000002","姚丽娜",Dep1,["008613312920020"],[""],"livecom"},
                 {OrgID,"0131000040","濮云",Dep1,["008613916137842"],[""],"livecom"},
                 {OrgID,"00000008","周苏苏",Dep1,[""],[""],"livecom"},
                 {OrgID,"00138328","韩琳",Dep2,["008613713767149"],[""],"livecom"},  
                 {OrgID,"00037393","叶军",Dep2,["0085290414738"],[""],"livecom"},
                 {OrgID,"0131000015","杨芳",Dep2,["008613428734027"],[""],"livecom"},  
                 {OrgID,"0131000035","刘艾莲",Dep2,["008613428903464"],[""],"livecom"},  
                 {OrgID,"0130000004","韩光勇",Dep3,["008613501565767"],[""],"livecom"},  
                 {OrgID,"0131000003","谈云欢",Dep3,["008615012578200"],[""],"livecom"},
                 {OrgID,"0131000005","蒋经伟",Dep3,["008613534253414"],[""],"livecom"},  
                 {OrgID,"0131000016","汤婷",Dep3,["008615986650212"],[""],"livecom"},  
                 {OrgID,"10004278","赵涛",Dep4,["008613805172428"],[""],"livecom"},  
                 {OrgID,"0131000022","翁诗淋",Dep4,["008618688749479"],[""],"livecom"},  
                 {OrgID,"0131000024","景喆",Dep4,["008618616011746"],[""],"livecom"},  
                 {OrgID,"0131000025","赵文浩",Dep4,["008618601658123"],[""],"livecom"},  
                 {OrgID,"0131000026","崔武",Dep4,["008618675591731"],[""],"livecom"},
                 {OrgID,"0131000042","谭志红",Dep4,[""],[""],"livecom"},
                 {OrgID,"0130000003","朱海瑞",Dep5,["008618676688066"],[""],"livecom"},  
                 {OrgID,"0130000007","王治伍",Dep5,["008615814081962"],[""],"livecom"},  
                 {OrgID,"0130000009","羊峥嵘",Dep6,["008613905191430"],[""],"livecom"},  
                 {OrgID,"0131000008","吴青军",Dep6,["008613798450967"],[""],"livecom"},  
                 {OrgID,"0131000011","付祥运",Dep6,["008615889644370"],[""],"livecom"},  
                 {OrgID,"0131000009","李森",Dep6,["008613642354903"],[""],"livecom"},  
                 {OrgID,"0131000007","郭君博",Dep6,["008618665851865"],[""],"livecom"},  
                 {OrgID,"0131000004","徐伟",Dep6,["008613723797092"],[""],"livecom"},   
                 {OrgID,"0131000013","丁明磊",Dep6,["008613927458453"],[""],"livecom"},  
                 {OrgID,"0131000017","吴有发",Dep6,["008615625276180"],[""],"livecom"},  
                 {OrgID,"0131000033","庞春俊",Dep6,["008618677705669"],[""],"livecom"},
                 {OrgID,"0131000044","王府",Dep6,[""],[""],"livecom"},
                 {OrgID,"0130000006","雷玉新",Dep7,["008618616527996"],[""],"livecom"},  
                 {OrgID,"0131000018","张丛耸",Dep7,["008618652938287"],[""],"livecom"},  
                 {OrgID,"0131000031","罗威",Dep7,["008613815422030"],[""],"livecom"},  
                 {OrgID,"0131000014","钱良建",Dep7,["008618652935886"],[""],"livecom"},  
                 {OrgID,"0131000010","陈佳培",Dep7,["008618616820929"],[""],"livecom"},  
                 {OrgID,"0131000019","钱沛",Dep7,["008613801961496"],[""],"livecom"},  
                 {OrgID,"0131000020","邓辉",Dep7,["008615300801756"],[""],"livecom"},
                 {OrgID,"0131000032","潘刘兵",Dep7,["008613788927293"],[""],"livecom"},
                 {OrgID,"0131000043","段先德",Dep7,["008613818986921"],[""],"livecom"}],
            lists:foreach(fun(Info) -> add_user(Info) end,AllUserInfo)
    end.

%%--------------------------------------------------------------------------------------


add_mit_org() ->
    OrgID = create_org("麻省理工学院","mit"),
    case OrgID of
        error ->
            error;
        _ ->
            add_navigators(OrgID,[]),
            Dep1  = create_department(OrgID, "学院1"),
            Dep2  = create_department(OrgID, "学院2", Dep1),

            Dep3  = create_department(OrgID, "学院3"),
            Dep4  = create_department(OrgID, "学院4", Dep3),
            Dep5  = create_department(OrgID, "学院5", Dep4),

            Dep6  = create_department(OrgID, "学院6"),
            Dep7  = create_department(OrgID, "学院7", Dep6),
            Dep8  = create_department(OrgID, "学院8", Dep7),
            Dep9  = create_department(OrgID, "学院9", Dep8),

            Dep10  = create_department(OrgID, "学院10"),
            Dep11  = create_department(OrgID, "学院11", Dep10),
            Dep12  = create_department(OrgID, "学院12", Dep11),
            Dep13  = create_department(OrgID, "学院13", Dep12),
            Dep14  = create_department(OrgID, "学院14", Dep13),
            AllUserInfo = 
                [{OrgID,"10000841","陈江",Dep2,["008618676699420"],[""],"livecom"},
                 {OrgID,"0130000005","孟江宁",Dep5,["008618676699420"],[""],"livecom"},
                 {OrgID,"0131000036","祝小林",Dep9,["008613322991882"],[""],"livecom"},  
                 {OrgID,"0131000002","姚丽娜",Dep14,["008613312920020"],[""],"livecom"}],
            lists:foreach(fun(Info) -> add_user(Info) end,AllUserInfo)
    end.

%%--------------------------------------------------------------------------------------

transform_table() ->
    F = fun({lw_instance,UUID,Name,OrgID,EID,DepID,Photo,Phone,EMail,Group,DefGroup,DefView,AllID,RecentID,_Reverse}) ->
            {lw_instance,UUID,Name,OrgID,EID,DepID,Photo,Phone,EMail,Group,DefGroup,DefView,AllID,RecentID,[{cost,0.0},{balance,100},{callback,enable},{voip,enable},{phoneconf,enable},{sms,enable},{dataconf,enable}]}
        end,
    mnesia:transform_table(lw_instance, F, record_info(fields, lw_instance)).

update_org() ->
    F = fun() ->
            AllOrgID = mnesia:all_keys(lw_org),
            [mnesia:write(#lw_org_attr{orgid=OrgID,phone={0,10},video={0,0},cost={0.0,500},max_employee_num=100})||OrgID<-AllOrgID]
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

check_org_res(UUID,Type,AddNum) ->
    F = fun() ->
            [#lw_instance{org_id = OrgID}] = mnesia:read(lw_instance,UUID),
            [OrgRes] = mnesia:read(lw_org_attr,OrgID),
            case check_org_res_txn(OrgRes,Type,AddNum) of
                true ->
                    add_org_res_txn(OrgRes,Type,AddNum),
                    ok;
                false ->
                    out_of_res
            end
        end,
    mnesia:activity(transaction,F).

check_org_res_txn(OrgRes,Type,AddNum) ->
    case Type of
        phoneconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.phone,
            Cur + AddNum =< Max;
        videoconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.video,
            Cur + AddNum =< Max;
        orgcost   -> 
            {Cur,Max} = OrgRes#lw_org_attr.cost,
            Cur < Max
    end.

add_org_res_txn(OrgRes,Type,AddNum) ->
    NewOrgRes = 
        case Type of
            phoneconf -> 
                {Cur,Max} = OrgRes#lw_org_attr.phone,
                OrgRes#lw_org_attr{phone = {Cur + AddNum,Max}};
            videoconf -> 
                {Cur,Max} = OrgRes#lw_org_attr.video,
                OrgRes#lw_org_attr{video = {Cur + AddNum,Max}}
        end,
    mnesia:write(NewOrgRes).

release_org_res(UUID,Type,DelNum) ->
    F = fun() ->
            [#lw_instance{org_id = OrgID}] = mnesia:read(lw_instance,UUID),
            [OrgRes] = mnesia:read(lw_org_attr,OrgID,write),
            NewOrgRes = 
                case Type of
                    phoneconf -> 
                        {Cur,Max} = OrgRes#lw_org_attr.phone,
                        OrgRes#lw_org_attr{phone = {Cur - DelNum,Max}};
                    videoconf -> 
                        {Cur,Max} = OrgRes#lw_org_attr.video,
                        OrgRes#lw_org_attr{video = {Cur - DelNum,Max}}
                end,
            mnesia:write(NewOrgRes)
        end,
    mnesia:activity(transaction,F).

update_org_cost(UUID,NewCost) ->
    F = fun() ->
            [#lw_instance{org_id = OrgID}] = mnesia:read(lw_instance,UUID),
            [OrgRes] = mnesia:read(lw_org_attr,OrgID,write),
            {OrgCost,Max} = OrgRes#lw_org_attr.cost,
            mnesia:write(OrgRes#lw_org_attr{cost = {OrgCost + NewCost,Max}})
        end,
    mnesia:activity(transaction,F).

reset_org_cost(OrgID) ->
    F = fun() ->
            [OrgRes] = mnesia:read(lw_org_attr,OrgID,write),
            {_OrgCost,Max} = OrgRes#lw_org_attr.cost,
            mnesia:write(OrgRes#lw_org_attr{cost = {0.0,Max}})
        end,
    mnesia:activity(transaction,F).

reset_org_res(OrgID) ->
    F = fun() ->
            [OrgRes] = mnesia:read(lw_org_attr,OrgID,write),
            {_OrgCost,Max} = OrgRes#lw_org_attr.phone,
            mnesia:write(OrgRes#lw_org_attr{phone = {0,Max}})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

create_org_meeting(MeetingID,Num) ->
    mnesia:dirty_write(#lw_org_meeting{meetingid = MeetingID,nums = Num}).

add_org_meeting_num(MeetingID,AddNum) ->
    [#lw_org_meeting{nums = Num} = Meeting] = mnesia:dirty_read(lw_org_meeting,MeetingID),
    mnesia:dirty_write(Meeting#lw_org_meeting{nums = Num + AddNum}).

del_org_meeting_num(MeetingID,DelNum) ->
    [#lw_org_meeting{nums = Num} = Meeting] = mnesia:dirty_read(lw_org_meeting,MeetingID),
    mnesia:dirty_write(Meeting#lw_org_meeting{nums = Num - DelNum}).

del_org_meeting(MeetingID) ->
    case mnesia:dirty_read(lw_org_meeting,MeetingID) of
        [] -> 0;
        [#lw_org_meeting{nums = Nums}] -> mnesia:dirty_delete(lw_org_meeting,MeetingID),Nums
    end.

modify_org_res_setting(OrgID,Phone,Video,Cost,MaxEmployeeNum) ->
    F = fun() ->
            [OrgRes] = mnesia:read(lw_org_attr,OrgID,write),
            {OldPhone,_} = OrgRes#lw_org_attr.phone,
            {OldVideo,_} = OrgRes#lw_org_attr.video,
            {OldCost,_}  = OrgRes#lw_org_attr.cost,
            mnesia:write(#lw_org_attr{orgid=OrgID,phone={OldPhone,Phone},video={OldVideo,Video},cost={OldCost,Cost},max_employee_num = MaxEmployeeNum})
        end,
    mnesia:activity(transaction,F).
