%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user auth
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_auth).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

get_org_hierarchy(UserID) -> 
    Module = lw_config:get_user_module(),
    Module:get_org_hierarchy(UserID).
get_full_name(UserID) -> 
    Module = lw_config:get_user_module(),
    Module:get_full_name(UserID).
get_all_navigators(UserID) ->
    Module = lw_config:get_user_module(),
    Module:get_all_navigators(UserID).
get_user_profile(UserID) ->
    Module = lw_config:get_user_module(),
    Module:get_user_profile(UserID).

%%--------------------------------------------------------------------------------------
create_login_table()->
    mnesia:create_table(lw_history,[{attributes,record_info(fields,lw_history)},{disc_copies,[node()]}]).

login(MarkName,EmployeeID,MD5,DeviceToken,IP) -> 
    Func = lw_config:get_auth_func(MarkName),
    case Func(MarkName,EmployeeID,MD5) of
    	{ok,OrgID,UUID} ->
    	    case lw_router:register_ua(OrgID,UUID,IP) of
                ok ->
                    case DeviceToken of
                        "" -> ok;
                        _  -> lw_push:register_device_token(UUID,DeviceToken)
                    end,
                    {ok,UUID};
                failed ->
                    {failed,overtime}
            end;
        Other -> Other
    end.

new_login(UUID,IP) ->
    Module = lw_config:get_user_module(),
    {_,OrgID,_} = Module:get_org_hierarchy(UUID),
    case lw_router:register_ua(OrgID,UUID,IP) of
        ok ->
            {ok,UUID};
        failed ->
            {failed,overtime}
    end.

logout(UUID,IP) ->
    lw_instance:log_out(UUID,IP),
    ok.

%%--------------------------------------------------------------------------------------

modify_password(UUID,MarkName,EmployeeID,Old,New) ->
    Module = lw_config:get_user_module(),
    Module:modify_password(UUID,MarkName,EmployeeID,Old,New).

%%--------------------------------------------------------------------------------------