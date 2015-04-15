%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user group
%%% @end
%%%--------------------------------------------------------------------------------------
-module(remote_user_info).
-compile(export_all).
-include("lw.hrl").

get_org_hierarchy(UserID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_org_hierarchy,[UserID]).
get_full_name(UserID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_full_name,[UserID]).
get_all_navigators(UserID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_all_navigators,[UserID]).
get_user_profile(UserID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_user_profile,[UserID]).
login(MarkName,EmployeeID,MD5) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,login,[MarkName,EmployeeID,MD5]).
modify_password(UUID,MarkName,EmployeeID,Old,New) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,modify_password,[UUID,MarkName,EmployeeID,Old,New]).

get_all_groups(UUID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_all_groups,[UUID]).
get_all_members(UUID,GroupID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_all_members,[UUID,GroupID]).
create_group(UUID,GroupName,GroupAttr) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,create_group,[UUID,GroupName,GroupAttr]).
delete_group(UUID, GroupID) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,delete_group,[UUID,GroupID]).
add_members(UUID,GroupId,MemeberIds) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,add_members,[UUID,GroupId,MemeberIds]).
delete_members(UUID,GroupId,MemeberIds) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,delete_members,[UUID,GroupId,MemeberIds]).
change_group_name(UUID, GroupId, NewName) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,change_group_name,[UUID, GroupId, NewName]).
update_recent_group(OwnerID,MemberIds) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,update_recent_group,[OwnerID,MemberIds]).

modify_user_info(UUID,Telephone,EMail) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,modify_user_info,[UUID,Telephone,EMail]).
modify_user_photo(UUID,PhotoURL) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,modify_user_photo,[UUID,PhotoURL]).

get_atom_uuids(UUIDs) when is_list(UUIDs) ->
    RemoteNode = lw_user_info:get_remote_node(),
    rpc:call(RemoteNode,local_user_info,get_atom_uuids,[UUIDs]).