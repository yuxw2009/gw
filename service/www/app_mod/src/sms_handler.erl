%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/auth
%%%------------------------------------------------------------------------------------------
-module(sms_handler).
-compile(export_all).

-include("lwdb.hrl").
-include("yaws_api.hrl").

%%% request handlers

%% handle user sms request
handle(Arg, 'POST', ["auth_code"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
        io:format("888888888888888888888888~p~n",[Json]),
    UUID    = utility:get_string(Json, "uuid"),
    case {lw_register:get_register_info_by_uuid(UUID), utility:get_string(Json,"type")} of
    {{atomic,[#lw_register{}]},"register"}->  
        io:format("888888888888888888888888~n"),
        utility:pl2jso_br([{status,failed},{reason, account_already_exist}]);
    _->
        DID    = utility:get_string(Json, "device_id"),
        Code_bin=auth_code(UUID++DID),
        SerID  = wwwcfg:get_serid(),
        UUID_BIN= list_to_binary(UUID),
        Phones = [trans_phone(UUID)],
        AuditInfo = utility:pl2jso([{uuid,UUID_BIN},{company,<<"ml">>},{name,<<"ml">>},{account,UUID_BIN},{orgid,<<"ml">>}]),
        Para = [{service_id,SerID},{audit_info,AuditInfo},{content,Code_bin},{members,Phones}],
        io:format("sms handle! Para:~p~n", [Para]),
        utility:pl2jso(send_sms(Para))
    end;

handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    get_sms_history(UUID,utility:client_ip(Arg)).

%%% rpc call

send_sms(Para) ->
    Node = wwwcfg:get(voice_node),
    case rpc:call(Node, lw_sms, send_sms, [Para]) of
        {ok, Fails}-> [{status,ok}, {fails,Fails}];
        Reason->[{status,failed}, {reason,Reason}]
    end.

get_sms_history(UUID, _SessionIP) ->
    Node = www_cfg:get(voice_node),
    {ok,R} = rpc:call(Node,tele,get_sms_history,[UUID]),
    R.
    
auth_code(UUID)    ->
    R= integer_to_list(abs(erlang:crc32(UUID++"1512ml4aseh346Rsdhfk4&^*&daasdlivecom") rem 1000000)),
    if length(R)<6-> lists:duplicate(6-length(R),$0)++R;
        true-> R
    end.

trans_phone(P="0086"++_)-> P;
trans_phone(P="00"++_)-> P;
trans_phone(P)-> "0086"++P.
