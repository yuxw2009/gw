%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user info
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_user_info).
-compile(export_all).
-include("lw.hrl").

atom(A) ->
    case (catch list_to_existing_atom(A)) of
    	{'EXIT',_} -> list_to_atom(A);
    	S -> S
    end.

get_module() ->
    case init:get_argument(user_module) of
    	error-> local_user_info;
    	{ok,[[ModuleName]]} -> atom(ModuleName)
    end.

get_remote_node() ->
    case init:get_argument(remote_node) of
    	error-> node();
    	{ok,[[RemoteNode]]} -> atom(RemoteNode)
    end.