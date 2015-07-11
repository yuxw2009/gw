%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(qvoice).
-compile(export_all).
-include("yaws_api.hrl").
-include("qcfg.hrl").
-define(CALL,"./log/call.log").
-define(TESTNODE, 'qtest@14.17.107.196').
-define(TESTNODE1, 'qtest1@14.17.107.196').

handle00(A,M,P)->
    Json=handle0(A,M,P),
%    Json.
    utility:pl2jso([{data_enc,lwork_app:encrypto(rfc4627:encode(Json))}]).
handle0(Arg, 'POST', ["register"]) ->handle(Arg, 'POST', ["register"]);
handle0(Arg, 'POST', ["login"]) -> handle(Arg, 'POST', ["login"]);
handle0(Arg, 'POST', ["recharge"]) -> handle(Arg, 'POST', ["recharge"]);
handle0(Arg, 'POST', ["hcyzdm"]) -> handle(Arg, 'POST', ["hcyzdm"]);
handle0(Arg, 'POST', ["get_code"]) -> handle(Arg, 'POST', ["get_code"]);

handle0(Arg, Method, Params) ->
    { UUID} = utility:decode(Arg, [{uuid, s}]),
    io:format("UUID:~p~n",[{Params,UUID}]),
    case lw_register:check(UUID) of
    {ok,_Bal}->    handle(Arg, Method, Params);
    no_money-> utility:pl2jso_br([{status,failed},{reason,no_money}]);
    failed-> utility:pl2jso_br([{status,failed},{reason,nologin}])
    end.
handle(Arg, 'POST', ["register"]) ->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res=lw_register:authcode_register(Json),
    io:format("register:req:~p ack:~p~n",[Json,Res]),
    utility:pl2jso_br(Res);
handle(Arg, 'POST', ["login"]) ->
    { Acc,  Pwd} = utility:decode(Arg, [{acc, s}, {pwd,s}]),
    utility:pl2jso_br(lw_register:login({Acc,Pwd}));
handle(Arg, 'POST', ["recharge"]) ->
    { Acc,  AuthCode} = utility:decode(Arg, [{acc, s}, {auth_code,s}]),
    utility:pl2jso_br(lw_register:recharge({Acc,AuthCode}));
handle(Arg, 'POST', ["get_code0"]) ->
    {Jpgbin,UUID,Quati} = utility:decode(Arg, [{jpgbin, b}, {uuid,s},{qua,i}]),
    io:format("get_code:~p qua:~p~n",[UUID,Quati]),
    Quatity=if Quati=/=undefined-> 2; true-> 1 end,
    case lw_register:check(UUID) of
    {ok,Bal} when Bal>0.001 ->    
        R=qclient:get_auth_code(lwork_app:decrypto(Jpgbin)),
        utility:pl2jso_br(consume(UUID,R,Quatity*authcode_fee()));
    {ok,_Bal} ->    
        utility:pl2jso_br([{status,failed},{reason,no_money}]);
    Reason-> utility:pl2jso_br([{status,failed},{reason,Reason}])
    end;
handle(Arg, 'POST', ["get_code"]) ->
    Param = yaws_api:parse_post(Arg),
    {Jpgbin,UUID,Quati} = {proplists:get_value("jpgbin",Param),proplists:get_value("uuid",Param),proplists:get_value("qua",Param)},
    io:format("get_code:~p qua:~p~n",[UUID,Quati]),
    Quatity=if Quati=/=undefined-> 2; true-> 1 end,
    case lw_register:check(UUID) of
    {ok,Bal} when Bal>0.001 ->    
        R=qclient:get_auth_code(utility:fb_decode_base64(Jpgbin)),
        utility:pl2jso_br(consume(UUID,R,Quatity*authcode_fee()));
    {ok,_Bal} ->    
        utility:pl2jso_br([{status,failed},{reason,no_money}]);
    Reason-> utility:pl2jso_br([{status,failed},{reason,Reason}])
    end;
handle(Arg, 'POST', ["hqyzdm"]) ->  %fetch yzdm
    {UUID} = utility:decode(Arg, [{uuid,s}]),
    io:format("fetch_code:~p~n",[UUID]),
    case verifycode_handler:fetch(1) of
    [[Code,Ckstr]]->
        io:format("hqyzdm ~p~n",[[Code,Ckstr]]),
        utility:pl2jso_br(consume(UUID,[{status,ok},{authcode,Code},{clidata,Ckstr}],authcode_fee()));
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg, 'POST', ["hcyzdm"]) ->  %  buffer code
    {Code,Clidata,UUID} = utility:decode(Arg, [{verify_code,s},{clidata,s},{uuid,s}]),
    io:format("hcyzdm uuid:~p~n",[UUID]),
    verifycode_handler:add([Code,Clidata]),
    utility:pl2jso_br([{status,ok}]);
handle(Arg, 'POST', ["restore_fee"]) ->
    { UUID,  Quatity} = utility:decode(Arg, [{uuid, s}, {qua,i}]),
    io:format("restore_fee : ~p ~p~n",[UUID,Quatity]),
    utility:pl2jso_br(consume(UUID,[{status,ok}],-1*Quatity*authcode_fee()));
    
handle(Arg, 'POST', ["report_autherr"]) ->
    { UUID,  ImgId} = utility:decode(Arg, [{uuid, s}, {imgId,s}]),
    io:format("report_autherr : ~p ~p~n",[UUID,ImgId]),
    qclient:report_authcode_error(ImgId),
    utility:pl2jso_br([{status,ok}]);
    
handle(Arg, 'POST', ["query_qno_status"]) ->
    { UUID,  QQNo} = utility:decode(Arg, [{uuid, s}, {qno,s}]),
    utility:pl2jso_br(consume(UUID,qclient:get_all_info(QQNo),authcode_fee()));
handle(Arg, 'POST', ["manual_upload"]) ->
    { UUID} = utility:decode(Arg, [{uuid, s}]),
    utility:pl2jso_br(qclient:manual_get_jpg());
handle(Arg, 'POST', ["manual_query"]) ->
    {UUID,Qno,Code,Clidata}=utility:decode(Arg, [{uuid, s},{qno,s},{verify_code,s},{clidata,s}]),
    Res=qclient:manual_query({Qno,Code,Clidata}),
    verifycode_handler:add([Code,Clidata]),
    utility:pl2jso_br(Res);
handle(Arg, 'POST', ["logout"]) ->
    { UUID} = utility:decode(Arg, [{uuid, s}]),
    lw_register:logout(UUID),
    utility:pl2jso_br([{status,ok},{uuid,UUID}]);
handle(Arg, 'POST', ["query_balance"]) ->
    UUID=utility:query_string(Arg, "uuid"),
    utility:pl2jso_br([{status,ok},{balance,lw_register:uuid_balance(UUID)}]);

handle(Arg, 'POST', ["call"]) ->
    _IP = utility:client_ip(Arg),
    start_call( Arg);
handle(Arg, 'POST', ["call1"]) ->
    Arg1= 
    case rfc4627:decode(Arg#arg.clidata) of
    {ok,{obj,[{"y",<<_:7/binary,Base64_Json_bin/binary>>}]},_}->
        Json_bin=utility:fb_decode_base64(Base64_Json_bin),
        Arg#arg{clidata=Json_bin};
    {ok,{obj,[{"data_enc",<<_:7/binary,Base64_Json_bin/binary>>}]},_}->
        Json_bin=utility:fb_decode_base64(Base64_Json_bin),
        Arg#arg{clidata=Json_bin};
    _-> Arg
    end,
    handle(Arg1,'POST',["call"]).
start_call(Arg) ->
    { UUID,  QQNo} = utility:decode(Arg, [{caller, s}, {qno,s}]),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    test(UUID,QQNo,Params),
    utility:pl2jso([{status, ok}]).

do_start_call(Node,Sdp,CallInfo)->
        rpc:call(Node, q_wkr, processVOIP, [Sdp,CallInfo]).

get_wcg_node(UUID)->
    wcg_disp:choose_wcg().

make_info(Cid,PhNo,QQNo,Clidata) ->
    [{phone,PhNo},{qcall,true},
     {uuid,{qvoice,86}},
     {audit_info,[{uuid,Cid}]},{userclass, "fzd"},
     {cid,Cid},{qno,QQNo},{clidata,Clidata}].

test(QQ)-> test(opdn_rand(),QQ,[]).
opdn_rand()->  "189"++integer_to_list(random:uniform(99999999)).
test(OpDn,QQ,Params)->
    utility:log("./log/qvoice.log", "~p ~p ~p", [OpDn,QQ,Params]),
    Clidata=proplists:get_value("clidata",Params,<<>>),
    do_start_call(testnode(), undefined, make_info(OpDn, "075583765566",QQ,binary_to_list(Clidata))).
    
test1(QQ)-> test1(opdn_rand(),QQ,[]).
test1(OpDn,QQ,Params)->
    utility:log("./log/qvoice.log", "~p ~p ~p", [OpDn,QQ,Params]),
    Clidata=proplists:get_value("clidata",Params,<<>>),
    do_start_call(?TESTNODE1, undefined, make_info(OpDn, "075583765566",QQ,binary_to_list(Clidata))).
    
testnode()->  ?TESTNODE.
    
test_qnos()->
    {ok,R} = file:consult("qtest.txt"),
    R.

my_test()->
    random:seed(erlang:now()),
    Fun =fun()->  "189"++integer_to_list(random:uniform(99999999)) end,
    [test1(Fun(),Qno,"")||Qno<-test_qnos()].


authcode_fee()->
    ?QUERY_AUTHCODE_FEE.
consume(UUID,Pls,Fee)-> lw_register:consume(UUID,Pls,Fee).
