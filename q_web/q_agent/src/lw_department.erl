%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork department
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_department).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------
get_atom_uuids(UUIDs) when is_list(UUIDs) -> 
    Module = lw_config:get_user_module(),
    Module:get_atom_uuids(UUIDs). 

get_all_members(OrgID,DepartmentID) ->
    {_,UsersInfo} = local_user_info:get_all_members(OrgID,DepartmentID,admin),
    UsersInfo.
create_org(FullName, MarkName) -> 
    local_user_info:create_org(FullName, MarkName).
delete_org(OrgID) -> 
    local_user_info:delete_org(OrgID).
change_org_full_name(Org,NewFullName) -> 
    local_user_info:change_org_full_name(Org,NewFullName).
create_department(OrgID, DepartmentName) -> 
    local_user_info:create_department(OrgID, DepartmentName).
create_department(OrgID,DepartmentName,UPID) -> 
    local_user_info:create_department(OrgID,DepartmentName,UPID).
delete_department(OrgID, DepartmentID) -> 
    local_user_info:delete_department(OrgID,DepartmentID).
change_department_name(OrgID, DepartmentID, NewName) -> 
    local_user_info:change_department_name(OrgID, DepartmentID, NewName).

add_user([{OrgID,_,_,_,_,_,_,_,_}|_] = UsersInfo) when is_list(UsersInfo) ->
    case local_user_info:check_usernum_over(OrgID,length(UsersInfo)) of
        true ->
            do_add_user(UsersInfo);
        false ->
            employee_num_overflow
    end;

add_user({OrgID,EID,Name,DepartmentID,Phone,Email,Pwd,Balance,Auth}) -> 
    local_user_info:add_user({OrgID,EID,Name,DepartmentID,Phone,Email,Pwd,Balance,Auth}).

do_add_user(UsersInfo) when is_list(UsersInfo) ->
    F = fun(Info,Acc) ->
            case add_user(Info) of
                ok  -> Acc;
                EID -> [EID|Acc]
            end
        end,
    lists:reverse(lists:foldl(F,[],UsersInfo)).

del_user(UsersInfo) when is_list(UsersInfo) ->
    lists:foreach(fun(Info) -> del_user(Info) end,UsersInfo);
del_user({OrgID,EmployeeID}) -> 
    local_user_info:del_user({OrgID,EmployeeID}).
transfer_department(OrgID,SrcDepartmentID, DestDepartmentID, EmployeeIDs) ->
    F1= fun(EmployeeID) ->
            [Auth] = mnesia:read(lw_auth,{OrgID,EmployeeID}),
            Auth#lw_auth.uuid
        end,
    F2= fun() -> [F1(EmployeeID)||EmployeeID<-EmployeeIDs] end,
    UUIDs = mnesia:activity(transaction,F2),
    local_user_info:modify_user_department(OrgID,SrcDepartmentID, DestDepartmentID, UUIDs),
    ok.
modify_user_department(UUIDs,DepartmentID) -> 
    local_user_info:modify_user_department(UUIDs,DepartmentID).
get_all_navigators(OrgID) -> 
    local_user_info:do_get_all_navigators(OrgID).
add_navigators(OrgID, Navigators) -> 
    local_user_info:add_navigators(OrgID, Navigators).
delete_navigators(OrgID, NavigatorKeys) -> 
    local_user_info:delete_navigators(OrgID, NavigatorKeys).
modify_navigators(OrgID, NewNavigators) -> 
    Keys = [Key||{Key,_}<-NewNavigators],
    local_user_info:delete_navigators(OrgID, Keys),
    local_user_info:add_navigators(OrgID, NewNavigators).
get_org_hierarchy(MarkName)  -> 
    local_user_info:get_org_hierarchy(MarkName).

login(MarkName,Account,Password) ->
    F = fun() ->
            case mnesia:index_read(lw_org,MarkName,#lw_org.mark_name) of
                []    -> failed;
                [Org] -> {Org#lw_org.id,Org#lw_org.admin_name,Org#lw_org.admin_pass}
            end
        end,
    case mnesia:activity(transaction,F) of
        failed -> failed;
        {OrgID,Account,Password} -> {ok,OrgID};
        _ -> failed
    end.
logout(_MarkName,_Account) ->
    ok.
modify_admin_password(OrgID,Account,OldPassword,NewPassword) ->
    F = fun() ->
            case mnesia:read(lw_org,OrgID) of
                []    -> failed;
                [Org] -> {Org#lw_org.admin_name,Org#lw_org.admin_pass}
            end
        end,
    case mnesia:activity(transaction,F) of
        failed -> 
            failed;
        {Account,OldPassword} -> 
            F1= fun() ->
                    [Org] = mnesia:read(lw_org,OrgID,write),
                    mnesia:write(Org#lw_org{admin_pass = NewPassword})
                 end,
            mnesia:activity(transaction,F1),
            ok;
        _ -> 
            failed
    end.

get_all_org() ->
    F1= fun(OrgID) ->
            [Org]  = mnesia:read(lw_org,OrgID),
            [#lw_org_attr{phone = Phone,video = Video,cost = Cost,max_employee_num = Max}] = mnesia:read(lw_org_attr,OrgID),
            {OrgID,Org#lw_org.mark_name,Org#lw_org.full_name,Phone,Video,Cost,Max}
        end,
    F2= fun() ->
            OrgIDs = mnesia:all_keys(lw_org),
            [F1(OrgID)||OrgID<-OrgIDs]
        end,
    mnesia:activity(transaction,F2).

change_org_markname(OrgID,NewMarkName) ->
   F = fun()  ->
            [OrgItem] = mnesia:read(lw_org,OrgID,write),
            mnesia:write(OrgItem#lw_org{mark_name = NewMarkName})
        end,
    mnesia:activity(transaction,F),
    ok.

reset_admin_password(OrgID) ->
   F = fun()  ->
            [OrgItem] = mnesia:read(lw_org,OrgID,write),
            mnesia:write(OrgItem#lw_org{admin_pass = hex:to(crypto:md5("888888"))})
        end,
    mnesia:activity(transaction,F),
    ok.

modify_employee_setting(OrgID,EmployeeID,RestPWFlag,Privilege) ->
    F = fun() ->
            [Auth] = mnesia:read(lw_auth,{OrgID,EmployeeID},write),
            UUID   = Auth#lw_auth.uuid,
            [Ins]  = mnesia:read(lw_instance,UUID,write),
            case RestPWFlag of
                yes ->
                    mnesia:write(Auth#lw_auth{md5 = hex:to(crypto:md5("888888"))});
                no ->
                    ok
            end,
            OldPrivilege = Ins#lw_instance.reverse,
            NewCost = 
                case lists:keyfind(cost,1,OldPrivilege) of
                    false ->
                        0;
                    {cost,Cost} ->
                        Cost
                end,
            mnesia:write(Ins#lw_instance{reverse = [{cost,NewCost}] ++ Privilege})
        end,
    mnesia:activity(transaction,F),
    ok.