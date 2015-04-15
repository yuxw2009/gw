%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user group
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_group).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

get_all_groups(UUID) -> 
    Module = lw_user_info:get_module(),
    Module:get_all_groups(UUID).

get_all_members(UUID,GroupID) -> 
    Module = lw_config:get_user_module(),
    {Members,UsersInfo} = Module:get_all_members(UUID,GroupID),
    States = lw_router:get_registered_states(Members),
    lists:zipwith(fun(X,Y) -> erlang:append_element(X, Y) end, UsersInfo, States).

create_group(UUID,GroupName,GroupAttr) ->
    Module = lw_config:get_user_module(),
    Module:create_group(UUID,GroupName,GroupAttr).

delete_group(UUID, GroupID) ->
    Module = lw_config:get_user_module(),
    Module:delete_group(UUID, GroupID).

add_members(UUID,GroupId,MemeberIds) ->
    Module = lw_config:get_user_module(),
    Module:add_members(UUID,GroupId,MemeberIds).

delete_members(UUID,GroupId,MemeberIds) ->
    Module = lw_config:get_user_module(),
    Module:delete_members(UUID,GroupId,MemeberIds).

change_group_name(UUID, GroupId, NewName) -> 
    Module = lw_config:get_user_module(),
    Module:change_group_name(UUID, GroupId, NewName).

update_recent_group(OwnerID,MemberIds) ->
    Module = lw_config:get_user_module(),
    Module:update_recent_group(OwnerID,MemberIds).

add_external_partner(UUID,ExternalPartners) when is_list(ExternalPartners) ->
    Module = lw_config:get_user_module(),
    Module:add_external_partner(UUID,ExternalPartners).

del_external_partner(UUID,DeleteID) ->
    Module = lw_config:get_user_module(),
    Module:del_external_partner(UUID,DeleteID).

modify_external_partner_phone(UUID,PartnerID,NewPhone,NewEmail) ->
    Module = lw_config:get_user_module(),
    Module:modify_external_partner_phone(UUID,PartnerID,NewPhone,NewEmail). 

get_external_partner(UUID) ->
    Module = lw_config:get_user_module(),
    Module:get_external_partner(UUID).