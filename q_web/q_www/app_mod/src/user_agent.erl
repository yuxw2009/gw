-module(user_agent).
-compile(export_all).

notify(UUID, CmdList) ->
    rpc:call(ns:service_node(), lw_instance, notify, [UUID, CmdList]).

login(Account, Password) ->
    rpc:call(ns:service_node(), lw_account, login, [Account, Password]).

check_user_name(UserName) ->
    rpc:call(ns:service_node(), lw_account, check_user_name, [UserName]).

register_user(UserName, Password) ->
    rpc:call(ns:service_node(), lw_account, register_user, [UserName, Password]).
