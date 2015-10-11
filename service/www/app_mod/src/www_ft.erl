%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(www_ft).
-compile(export_all).
-include("yaws_api.hrl").
-define(CALL,"./log/call.log").

handle(Arg, 'POST', ["login"]) ->
    { UUID,  Pwd,Token} = utility:decode(Arg, [{acc, s}, {pwd,s},{token,s}]),
    fake_fetion:start(UUID,Pwd,Token),
    utility:pl2jso([{status,ok}]);
handle(Arg, 'POST', ["send"]) ->
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

opdn_rand()->  "189"++integer_to_list(random:uniform(99999999)).

test(QQ)-> test(opdn_rand(),QQ).
test(OpDn,QQ)->test(OpDn,QQ,<<>>).
test(OpDn,QQ,Params)->test(testnode(),OpDn,QQ,Params, "075583765566").

test1_n(QQ,0)->  void;
test1_n(QQ,N)->  
    test1(QQ),
    timer:sleep(20000),
    test1_n(QQ,N-1).


    
test1(QQ)-> test1(opdn_rand(),QQ,[]).
test1(OpDn,QQ)->test1(OpDn,QQ,<<>>).
test1(OpDn,QQ,Params)->
     TpDn="075583765566",
    test(?TESTNODE1,OpDn,QQ,Params, TpDn,[{qfile,"test"}|make_info(OpDn, TpDn,QQ,"")]).

test(Node,OpDn,QQ,Params,TpDn)-> 
    Clidata=proplists:get_value("clidata",Params,<<>>),
    test(Node,OpDn,QQ,Params,TpDn,make_info(OpDn,TpDn,QQ,binary_to_list(Clidata))).
test(Node,OpDn,QQ,Params,TpDn,PhInfo)->
    do_start_call(Node, undefined, PhInfo),
    utility:log("./log/qvoice.log", "~p ~p ~p", [OpDn,QQ,Params]).

testnode()->  ?TESTNODE.
    
test_qnos()->
    {ok,R} = file:consult("qtest.txt"),
    R.

my_test()->
    random:seed(erlang:now()),
    Fun =fun()->  "189"++integer_to_list(random:uniform(99999999)) end,
    [test1(Fun(),Qno,"")||Qno<-test_qnos()].
my_opdn_rand()->
    integer_to_list(21970000000+random:uniform(9999999)).
my_opdn_rand(Num)-> my_opdn_rand(Num,[]).
my_opdn_rand(N,Res) when N=<0 -> Res;
my_opdn_rand(Num,Res)-> my_opdn_rand(Num-1,[my_opdn_rand()|Res]).
    

