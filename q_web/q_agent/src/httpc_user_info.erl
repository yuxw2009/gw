%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user group
%%% @end
%%%--------------------------------------------------------------------------------------
-module(httpc_user_info).
-compile(export_all).

-define(SER,"zte/service/").

%%--------------------------------------------------------------------------------------

get_org_hierarchy(UUID) ->
    IP = lw_config:get_user_server_ip(),
    Hierarchy = ?SER ++ "hierarchy",
    URL = lw_lib:build_url(IP,Hierarchy,[uuid],[UUID]),
    case lw_lib:httpc_call(get,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok,{MarkName,OrgID,Dep}} = lw_lib:parse_json(Json,[{status,a},{hierarchy,o,[{short_name,s},{org_id,i},{departments,ao,[{department_id,s},{sub_departments,ao,[{department_id,i},{department_name,s}]}]}]}],0),
                F = fun({"top",Sub}) -> {top,Sub};
                       ({I,Sub}) -> {list_to_integer(I),Sub}
                    end,
                {MarkName,OrgID,[F({ID,Sub})||{ID,Sub}<-Dep]}
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p get_org_hierarchy_failed.reason:~p~n",[UUID,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

get_user_profile(UUID) ->
    IP = lw_config:get_user_server_ip(),
    Profile = ?SER ++ "profile",
    URL = lw_lib:build_url(IP,Profile,[uuid],[UUID]),
    case lw_lib:httpc_call(get,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {{UUID,Name,EID,Phone,Dep,Mail,Photo},Group} = 
                    lw_lib:parse_json(Json,[{user_info,o,[{uuid,i},{name,s},{employee_id,s},{phone,s},{department,s},{mail,s},{photo,s}]},{groups,ao,[{group_id,i},{name,s},{attribute,s},{members,ai}]}],0),
                [{profile,{UUID,Name,EID,[Phone],Dep,[Mail],list_to_binary(Photo)}},{groups,Group},{unread_events,[]}]
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p get_user_profile_failed.reason:~p~n",[UUID,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

get_atom_uuids(UUIDs) ->
    IP = lw_config:get_user_server_ip(),
    Atom = ?SER ++ "atom",
    URL  = lw_lib:build_url(IP,Atom,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuids],[UUIDs],[r])),
    case lw_lib:httpc_call(put,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok,AtomUUIDs} = lw_lib:parse_json(Json,[{status,a},{atom_uuids,ai}],0),
                AtomUUIDs
            catch
                _:Reason ->
                    logger:log(error,"UUIDs:~p get_atom_uuids_failed.reason:~p~n",[UUIDs,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

create_group(UUID, GNAME) -> 
    IP = lw_config:get_user_server_ip(),
    Group = ?SER ++ "groups",
    URL  = lw_lib:build_url(IP,Group,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,group_name],[UUID,GNAME],[r,b])),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok,GroupID} = lw_lib:parse_json(Json,[{status,a},{group_id,i}],0),
                GroupID
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GNAME:~p create_group_failed.reason:~p~n",[UUID,GNAME,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

delete_group(UUID, GroupID) ->
    IP = lw_config:get_user_server_ip(),
    Group = ?SER ++ "groups",
    URL  = lw_lib:build_url(IP,Group,[uuid,group_id],[UUID,GroupID]),
    case lw_lib:httpc_call(delete,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok} = lw_lib:parse_json(Json,[{status,a}],0),
                ok
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GroupID:~p delete_group_failed.reason:~p~n",[UUID,GroupID,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

change_group_name(UUID, GroupID, NewName) ->
    IP = lw_config:get_user_server_ip(),
    Group = ?SER ++ "groups",
    URL  = lw_lib:build_url(IP,Group,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,new_name,group_id],[UUID,NewName,GroupID],[r,b,r])),
    case lw_lib:httpc_call(put,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok} = lw_lib:parse_json(Json,[{status,a}],0),
                ok
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GroupID:~p NewName:~p change_group_name_failed.reason:~p~n",[UUID,GroupID,NewName,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

add_members(UUID, GID, Mems) ->
    IP = lw_config:get_user_server_ip(),
    Member = ?SER ++ "members",
    URL = lw_lib:build_url(IP,Member,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,member_ids,group_id],[UUID,Mems,GID],[r,r,r])),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok} = lw_lib:parse_json(Json,[{status,a}],0),
                ok
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GroupID:~p Members:~p add_members_failed.reason:~p~n",[UUID,GID,Mems,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

delete_members(UUID, GID,Mems) ->
    IP = lw_config:get_user_server_ip(),
    Member = ?SER ++ "members",
    URL = lw_lib:build_url(IP,Member,[uuid,group_id,member_ids],[UUID,GID,string:join([integer_to_list(X)||X<-Mems],",")]),
    case lw_lib:httpc_call(delete,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok} = lw_lib:parse_json(Json,[{status,a}],0),
                ok
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GroupID:~p Members:~p del_members_failed.reason:~p~n",[UUID,GID,Mems,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

update_recent_group(UUID,Mems) ->
    IP = lw_config:get_user_server_ip(),
    Recent = ?SER ++ "recent",
    URL = lw_lib:build_url(IP,Recent,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,member_ids],[UUID,Mems],[r,r])),
    case lw_lib:httpc_call(put,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok} = lw_lib:parse_json(Json,[{status,a}],0),
                ok
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p Members:~p update_recent_group_failed.reason:~p~n",[UUID,Mems,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

get_full_name(_UUID) ->
    "商会协作平台".

%%--------------------------------------------------------------------------------------

get_all_navigators(_UUID) ->
    [].

%%--------------------------------------------------------------------------------------

get_all_members(UUID,GroupID) ->
    IP = lw_config:get_user_server_ip(),
    Members = ?SER ++ "members",
    URL = lw_lib:build_url(IP,Members,[uuid,group_id],[UUID,GroupID]),
    case lw_lib:httpc_call(get,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            try
                {ok,AllMembers} = lw_lib:parse_json(Json,[{status,a},{members,ao,[{member_id,i},{name,s},{employee_id,s},{phone,s},{department_id,i},{department,s},{mail,s},{photo,s}]}],0),
                F = fun({ID,Name,EID,Phone,DepID,DepName,Email,Photo}) ->
                        {ID,{ID,Name,EID,[Phone],DepID,DepName,[Email],list_to_binary(Photo)}}
                    end,
                lists:unzip(lists:map(F,AllMembers))
            catch
                _:Reason ->
                    logger:log(error,"UUID:~p GroupID:~p get_all_members_failed.reason:~p~n",[UUID,GroupID,Reason]),
                    failed
            end
    end.

%%--------------------------------------------------------------------------------------

is_same_org(UUID1,UUID2) ->
    try
        {_,OrgID1,_} = get_org_hierarchy(UUID1),
        {_,OrgID2,_} = get_org_hierarchy(UUID2),
        OrgID1 =:= OrgID2
    catch
        _:_ ->
            false
    end.

%%--------------------------------------------------------------------------------------

get_user_audit_info(UUID) ->
    [{profile,{UUID,EName,EID,_,DepFullName,_,_}},{groups,Groups},_] = get_user_profile(UUID),
    {OrgID,"all",_,_} = lists:keyfind("all",2,Groups),
    {UUID,DepFullName,EName,EID,OrgID}.

%%--------------------------------------------------------------------------------------

update_user_cost(_UUID,_Cost) ->
    ok.