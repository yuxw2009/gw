%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(qvoice).
-compile(export_all).
-include("yaws_api.hrl").
-define(CALL,"./log/call.log").
-define(TESTNODE, 'qtest@14.17.107.196').
-define(TESTNODE1, 'qtest1@14.17.107.196').

handle(Arg, 'POST', ["login"]) ->
    { UUID,  Pwd} = utility:decode(Arg, [{acc, s}, {pwd,s}]),
    utility:pl2jso([{status,ok},{uuid,<<"123">>}]);
handle(Arg, 'POST', ["query_qno_status"]) ->
    { UUID,  QQNo} = utility:decode(Arg, [{uuid, s}, {qno,s}]),
    utility:pl2jso([{status,ok},{state,<<"test_ok">>}]);
handle(Arg, 'POST', ["logout"]) ->
    { UUID} = utility:decode(Arg, [{uuid, s}]),
    utility:pl2jso([{status,ok},{uuid,<<"123">>}]);
handle(Arg, 'POST', ["query_balance"]) ->
    utility:pl2jso([{status,ok},{balance,100.000}]);

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
    Clidata=proplists:get_value("clidata",Params,<<>>),
    do_start_call(testnode(), undefined, make_info(OpDn, "075583765566",QQ,binary_to_list(Clidata))),
    utility:log("./log/qvoice.log", "~p ~p ~p", [OpDn,QQ,Params]).
    
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
