-module(pay).
-compile(export_all).
-include("db_op.hrl").
-include("lwdb.hrl").
-include("yaws_api.hrl").
-include("xmerl-1.3.6/include/xmerl.hrl").
-define(WXMCH_ID, "1267076901").    
-define(WXAPI_KEY,"d23c79a91ef124a600762e82ce91112d").
-define(WXAPPID, "wxd9404da72b24431f").
-define(WXSECRET, "d23c79a91ef124a600762e82ce91101c").
-define(ZFB_SECRET,("MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAJ7kvWZXShLVxxTX"
											"r8ldKrXgGHoIXKnU0niMnIluFI5NGo4gmJwOeIWvtkX6NvF1JjKBItjyG449CxLw"
											"P2Ymzkc5x1DNjbFO2nw6UW7YNMaLJrS6ImcLIT4QPQKqwTUxADWssFI6XrTij9bH"
											"TFM83ZIuKRmvDsgLrcsj/GzLTxGtAgMBAAECgYBUFCgg2nnI47R30/Yh8JnkKdPp"
											"5zjZaVOCFK3UjxpzfltZ7+exVHr0CtnBx7iBJoNy4CCHef2Y07ZjbBuwO0KVWoC9"
											"TA7lZVYOzMslGVqLNWrmvp3sMebwXN1iqDxYJRpQUiFDCqEaItXqz64uxGt68j1X"
											"plmhxM32Pttdb8gyQQJBAM3c04c0xNXhURTPFboLtmDdssjdBXX81kiQfKBd5ldS"
											"1BBkxry0ggOqrs94FKxm4NiudZWKDEr0xmQXIt+baZECQQDFl3kVVFu5jC/uX53c"
											"0za+ZYfID1EfPlQ4Gn0+eahppRLMESjS8ql8JVhaRJhPYdfgmRAhRl6WwhNtI5kT"
											"ojhdAkBZerCexjsAVC1wBAsHkOu28uYxFJC5Fir144eoFOh38FKoxYT0pOkWOuw8"
											"1Y722MjGph4J37U0J2zMOJo5401hAkBd01+b0UL9CKR5/M1pXqJQJsYjKaLLwz0a"
											"pvlyATMHd2tFm6BXCwOP/+vEcW4hw8RO0l/mbRPdYqr22ECIIi/BAkA0Rn0g0qS3"
											"qlWRKnuawY8Dc/icQFz9beAtI++Yn0QK36ZrnPlNHkfe95CtxjJzJbO8amXoy8z7"
											"B5mTa27Oyseh")).

get_pairs(XmlStr)->
    {#xmlElement{content=Contents},_}=xmerl_scan:string(XmlStr),
    [{Name,Value}||#xmlElement{name=Name,content=[#xmlText{value=Value}]}<-Contents].
handle(Arg,'GET', [])->
%    {ok, Json={obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("GET paytest:req:~n",[]),
    {html, "success"};
handle(Arg,'POST', ["package_pay","wx"])->
    io:format("~p~n",[Arg#arg.clidata]),
    Pairs=get_pairs(binary_to_list(Arg#arg.clidata)),
    ReturnCode=proplists:get_value(return_code,Pairs),
    Sign0=proplists:get_value(sign,Pairs),
    PayId=proplists:get_value(out_trade_no,Pairs),
    case {ReturnCode,wx_sign(Pairs),?DB_READ(pay_types_record,PayId)} of
    {"SUCCESS",Sign0,{atomic,[Item=#pay_types_record{status=paid}]}}->
        io:format("pay:wx notify repeated~n"),
        void;
    {"SUCCESS",Sign0,{atomic,[Item=#pay_types_record{uuid=UUID,pkg_info=PkgInfo}]}}->
        lw_register:add_pkg(UUID,PkgInfo),
        lw_register:add_payids(UUID, [PayId]),
        ?DB_WRITE(Item#pay_types_record{pls=Pairs,status=paid,paid_time=erlang:localtime()});
    _Other->    
         io:format("pay wx:other:~p~n",[_Other])
    end,
    Ret="<xml>   <return_code><![CDATA[SUCCESS]]></return_code>   <return_msg><![CDATA[OK]]></return_msg> </xml>",
    {html,Ret};
handle(Arg,'POST', ["package_pay"])->
%    io:format("~p~n",[Arg]),
    Params=yaws_api:parse_post(Arg),
    io:format("post paytest:req:~p~n",[Params]),
    PayId=proplists:get_value("out_trade_no",Params),
    Status=proplists:get_value("trade_status",Params),
    case [Status, ?DB_READ(pay_types_record,PayId)] of
    ["TRADE_SUCCESS",{atomic,[Item=#pay_types_record{status=paid}]}]->
         io:format("zhifubao:repeat~n"),
        void;
    ["TRADE_SUCCESS",{atomic,[Item=#pay_types_record{uuid=UUID,pkg_info=PkgInfo}]}]->
        lw_register:add_pkg(UUID,PkgInfo),
        lw_register:add_payids(UUID, [PayId]),
        ?DB_WRITE(Item#pay_types_record{pls=Params,status=paid,paid_time=erlang:localtime()});
    ["WAIT_BUYER_PAY",{atomic,[Item=#pay_record{}]}]->
        ?DB_WRITE(Item#pay_types_record{pls=Params});
    [Other]->
         io:format("zhifubao:other:~p~n",[Other])
    end,
    {html, "success"};
handle(Arg,'POST', [])->
%    io:format("~p~n",[Arg]),
    Params=yaws_api:parse_post(Arg),
    io:format("post paytest:req:~p~n",[Params]),
    PayId=proplists:get_value("out_trade_no",Params),
    Status=proplists:get_value("trade_status",Params),
    case [Status, ?DB_READ(pay_record,PayId)] of
    ["TRADE_SUCCESS",{atomic,[Item=#pay_record{status=paid}]}]->
         io:format("zhifubao:repeat~n"),
        void;
    ["TRADE_SUCCESS",{atomic,[Item=#pay_record{uuid=UUID,coins=Coins}]}]->
        lw_register:add_coins(UUID,Coins),
        lw_register:add_payids(UUID, [PayId]),
        ?DB_WRITE(Item#pay_record{pls=Params,status=paid,paid_time=erlang:localtime()});
    ["WAIT_BUYER_PAY",{atomic,[Item=#pay_record{}]}]->
        ?DB_WRITE(Item#pay_record{pls=Params});
    [Other]->
         io:format("zhifubao:other:~p~n",[Other])
    end,
    {html, "success"}.

gen_payment(Json)->  
    [UUID, Money,Coins] =[utility:get_binary(Json,"uuid"),utility:get_integer(Json,"money"),utility:get_integer(Json,"coins")],
    case  lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[_LR]} when Money>0 ->
        Payid=payid(),
        Payment=#pay_record{payid=Payid,uuid=UUID,status=to_pay,money=Money,coins=Coins,gen_time=erlang:localtime()},
        ?DB_WRITE(Payment),
        [{status,ok},{payid,Payid},{uuid,UUID},{wakey,?WXAPI_KEY},{ws,?WXSECRET},{zs,?ZFB_SECRET}];
    {atomic,[]}->
        [{status,failed},{reason,account_not_existed}];
    _->
        [{status,failed},{reason,error_params}]
    end.
    
gen_types_payid(Json)->  
    MoneyStr=utility:get_string(Json,"money"),
    Money=element(1,string:to_integer(MoneyStr)),
    PayTypes=utility:get_atom(Json,"pay_type"),
    [UUID, GroupId] =[utility:get_binary(Json,"uuid"),utility:get_binary(Json,"group_id")],
    Package=get_package(GroupId,PayTypes),
    Price=proplists:get_value(price,Package),
    case  lw_register:get_register_info_by_uuid(UUID) of
    {atomic,[_LR]} when Money==trunc(Price) ->
        Payid=payid(),
        PkgInfo=gen_pkg_info(GroupId,PayTypes,Payid),
        Payment=#pay_types_record{payid=Payid,uuid=UUID,status=to_pay,money=Money,gen_time=erlang:localtime(),pkg_info=PkgInfo},
        ?DB_WRITE(Payment),
        [{status,ok},{payid,Payid},{uuid,UUID},{wakey,?WXAPI_KEY},{ws,?WXSECRET},{zs,?ZFB_SECRET}];
    {atomic,[]}->
        [{status,failed},{reason,account_not_existed}];
    _->
        [{status,failed},{reason,error_params}]
    end.

gift_for_reg(UUID)->
    case lw_register:get_group_id(UUID) of
    <<"dth_common">> ->
        PkgInfo=gen_pkg_info("dth_common",dth_basic1,"gift"),
        lw_register:add_pkg(UUID,PkgInfo);
    _-> void
    end.

gen_pkg_info(GroupId,PayType)->  gen_pkg_info(GroupId,PayType,payid()).
gen_pkg_info(GroupId,PayType,Payid) when is_list(GroupId)-> gen_pkg_info(list_to_binary(GroupId),PayType,Payid);
gen_pkg_info(GroupId,PayType,Payid)->
    Package=get_package(GroupId,PayType),
    {Period,Circles,Limits}={proplists:get_value(period,Package),proplists:get_value(circles,Package,0),proplists:get_value(limit,Package,0)},
    #package_info{period=Period,cur_circle=1,from_date=date(),circles=Circles,gifts=0,limits=Limits,cur_consumed=0,payid=Payid,raw_pkginfo=Package}.

get_package(_GroupId,PayType)->
    {ok,Ps}=lw_mobile:packages_info(),
    TS=[list_to_tuple(I)||I<-Ps],
    TItem=lists:keyfind({type,PayType},1,TS),
    tuple_to_list(TItem).
            
payid()->
    random:seed(erlang:now()),
    Base=random:uniform(10000),
    integer_to_list(Base*1000000+mnesia:dirty_update_counter(id_table, payid, 1)).

test_pay()->
    wx_pay_reqs("DeviceId","Abstract","Detail","45354545888","1","10.32.3.52","ocYhrwcNCtXq38EkcMHmUz4mpjaU").
wx_pay_reqs(DeviceId,Abstract,Detail,PayId,Cents,UserIp,OpenId)->
    DevInfo0=if length(DeviceId)>32-> {H,_}=lists:split(32,DeviceId), H; true-> DeviceId end,
    DevInfo=if DevInfo0==[]-> "empty"; true-> DevInfo0 end,
    Elapse=calendar:datetime_to_gregorian_seconds(calendar:local_time()),
    NonceStr=integer_to_list(Elapse),
%    StartTime=utility:d2s(calendar:local_time(),"","",""),
%    Pls0=[{appid,?WXAPPID},{moch_id,?WXMCH_ID},{device_info,DevInfo},{nonce_str,NonceStr},{body,Abstract},{detail,Detail},{attach,"not_used"},
%      {out_trade_no,PayId},{total_fee,Cents},{spbill_create_ip,UserIp},{notify_url,"https://lwork.hk/lwork/mobile/paytest"},{trade_type,"APP"},
%      {openid,OpenId}],
    Pls0=[{appid,?WXAPPID},{moch_id,?WXMCH_ID},{nonce_str,NonceStr},{notify_url,"https://lwork.hk/lwork/mobile/paytest"},
      {out_trade_no,PayId},{spbill_create_ip,UserIp},{total_fee,Cents},{trade_type,"APP"},
      {openid,OpenId}],
    Sign=wx_sign(Pls0),
    Pls1=Pls0++[{sign,Sign}],
    Pls2=[{atom_to_list(K),V}||{K,V}<-Pls1],
    Pls3=["<"++K++">"++V++"</"++K++">"||{K,V}<-Pls2],
    "<xml>"++string:join(Pls3,"")++"</xml>".
get_wx_pay_reqs(DeviceId,Abstract,Detail,PayId,Cents,UserIp,OpenId)->
    XmlStr=wx_pay_reqs(DeviceId,Abstract,Detail,PayId,Cents,UserIp,OpenId),
    get_wx_pay_reqs(XmlStr).
get_wx_pay_reqs(XmlStr)->
    URL="https://api.mch.weixin.qq.com/pay/unifiedorder",
    {ok,{_,_,Ack}}=utility:send_httpc(post,{URL,XmlStr},"application/json"),
    {#xmlElement{content=Content},_}=xmerl_scan:string(Ack),
    Content.
    
wx_sign(Pls0)->    
    Pls1=[I||I={K,V}<-Pls0,V=/="", K=/=sign],
    Pls=lists:sort(Pls1),
    KVs=[atom_to_list(K)++"="++V||{K,V}<-Pls,V=/=""],
    KVStr=string:join(KVs,"&"),
    StringSignTemp=KVStr++"&key="++?WXAPI_KEY,
    string:to_upper(hex:to(crypto:hash(md5,StringSignTemp))).
    
