%%%===========================================================
%%% @doc Yaws websocket video agent.
%%%===========================================================

-module(ws_agent).

%% Export for websocket callbacks
-export([handle_message/1, notify/2]).

%%% RPC calls
-include("snode.hrl").

handle_message({text, Data}) ->
   %% io:format("ws connected ~p~n", [Data]),
    ["connect", UUIDstr] = string:tokens(binary_to_list(Data), "="),
    im_router:im_register(list_to_integer(UUIDstr), self()),
    {reply, {text, <<"connect-ok">>}};
handle_message({close, _Status, _Reason}) ->
   %% io:format("closed ~n"),
    im_router:im_unregister(self()),
    {close, normal};
handle_message(Msg) ->
    io:format("ws rcv:~p~n",[Msg]),
    noreply.

notify(Pid, Msg) ->
    %%io:format("notify message :~p~n",[Msg]),
    yaws_api:websocket_send(Pid, {text, list_to_binary(Msg)}).
