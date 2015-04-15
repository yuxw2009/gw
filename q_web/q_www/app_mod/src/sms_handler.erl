%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/auth
%%%------------------------------------------------------------------------------------------
-module(sms_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle user sms request
handle(Arg, 'POST', []) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Content = utility:get_string(Json, "content"),
    Sig     = utility:get_string(Json, "signature"),
    MObjs = utility:get(Json, "members"),
    Members = [{utility:get_binary(Obj, "name"), utility:get_binary(Obj, "phone")}  || Obj <- MObjs],

    {TS, Fails} = send_sms(UUID, Members, Content, Sig, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {timestamp, list_to_binary(TS)}, {fails, Fails}]);

handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    %%[{Members, Content, Ts}]
    %%PI = utility:query_integer(Arg, "page_index"), 
    %%PN = utility:query_integer(Arg, "page_num"),
    History = get_sms_history(UUID, utility:client_ip(Arg)),
    MemberFun = fun(Ms) ->
                    utility:a2jsos([name, phone],Ms)
                end,

    utility:pl2jso([{status, ok}, {history, utility:a2jsos([{members, MemberFun}, 
                                                            {content, fun erlang:list_to_binary/1},
                                                            {timestamp, fun erlang:list_to_binary/1}],History)}]).    


%%% rpc call
-include("snode.hrl").

send_sms(UUID, Members, Content, Sig, SessionIP) ->
    io:format("send_sms ~p ~p ~p~n",[UUID, Members, Sig]), 
    {value, Fails} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_sms, send_sms, [UUID, Members, Content, Sig], SessionIP]),
    Fails.

get_sms_history(UUID, SessionIP) ->
    io:format("get_sms_history ~p ~n",[UUID]),
    {value, History} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                            [UUID, lw_sms, get_all_sms, [UUID, 1, 500], SessionIP]),
    History.