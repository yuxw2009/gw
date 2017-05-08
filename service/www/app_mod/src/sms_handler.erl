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
    Phone    = utility:get_string(Json, "phone"),
    case {lw_register:get_register_info_by_uuid(UUID), lw_register:get_register_info_by_phone(Phone)}  of
    {{atomic,[_]},[_|_]} when Phone=/="13788927293",Phone=/="18017813673"->  
        io:format("888888888888888888888888~n"),
        utility:pl2jso_br([{status,failed},{reason, phone_already_bind}]);
    {{atomic,[#lw_register{name=Name,group_id=GroupId}]},PhoneRegInfo} when PhoneRegInfo==[] orelse Phone=="13788927293" orelse 
               Phone=="18017813673"->
        DID    = utility:get_string(Json, "device_id"),
        Code_bin=auth_code(UUID++DID),
        SerID  = wwwcfg:get_serid(),
        UUID_BIN= list_to_binary(UUID),
        Phones = [trans_phone(Phone)],
        AuditInfo = utility:pl2jso([{uuid,UUID_BIN},{company,GroupId},{name,Name},{account,UUID_BIN},{orgid,<<"ml">>}]),
        Para = [{service_id,SerID},{audit_info,AuditInfo},{content,Code_bin},{members,Phones}],
        io:format("sms handle! Para:~p~n", [Para]),
        R=case lw_register:is_zy_group({groupid,GroupId}) of
            true-> send_sms(Para);
            _-> send_sms1(Para)
            end,
        utility:pl2jso_br(R);
     {_,_}-> utility:pl2jso_br([{status,failed},{reason, account_not_exist}])
    end;

handle(Arg, 'GET', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    get_sms_history(UUID,utility:client_ip(Arg)).

%%% rpc call

send_sms(Para) ->
    [Phone]=proplists:get_value(members,Para),
    Content=proplists:get_value(content,Para),
    R=os:cmd("python test.py "++Phone++" "++Content),
    case re:run(R,"'success': True") of
    {match,[{100,15}]}->
        [{status,ok},{phone,Phone}];
    _-> 
        case re:run(R,"errorcode=(\\d*) .*",[{capture, all_but_first, list}]) of
        {match,[ErrCode]}->        [{status,failed},{reason,ErrCode}];
        _-> [{status,failed},{reason,unknown}]
        end
    end.

send_sms1(Para) ->
    Node = wwwcfg:get(voice_node),
    case rpc:call(Node, lw_sms, send_sms, [Para]) of
        {ok, Fails}-> [{status,ok}, {fails,Fails}];
        Reason->[{status,failed}, {reason,Reason}]
    end.

get_sms_history(UUID, _SessionIP) ->
    Node = www_cfg:get(sms_node),
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
