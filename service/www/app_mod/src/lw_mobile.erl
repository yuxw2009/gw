%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(lw_mobile).
-compile(export_all).
-include("yaws_api.hrl").
-include("lwdb.hrl").
-include("login_info.hrl").
-define(CALL,"./log/call.log").
-define(VERSION_INFO, "./docroot/version/version.info").
-define(DTH_COMMON_PACKAGE_CONFIG, "./priv/package.info").
-define(ZY_COMMON_PACKAGE_CONFIG, "/home/ubuntu/wcg/www/priv/zy_package.info").
-define(ZY_COMMON_COIN_PACKAGE_CONFIG, "/home/ubuntu/wcg/www/priv/zy_package_coin.info").
-define(ZY_TEST_PACKAGE_CONFIG, "/home/ubuntu/wcg/www/priv/zy_test_package.info").
-define(ZY_TEST_COIN_PACKAGE_CONFIG, "/home/ubuntu/wcg/www/priv/zy_test_package_coin.info").
-define(VERSION_DTH_INFO, "./docroot/version/version_dth.info").
-define(VERSION_COMMON_INFO, "./docroot/version/version_common.info").

handle(Arg,'POST', ["register"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res=
    case utility:get_string(Json, "group_id") of
    "common"->    lw_register:sms_register(Json);
    "dth"-> lw_register:delegate_register(Json)
    end,
    io:format("register:req:~p ack:~p~n",[Json,Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["bind"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res=lw_register:bind_phone(Json),
    utility:pl2jso(Res);
handle(Arg,'POST', ["share"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res=login_processor:share_to_other(Json),
    utility:pl2jso_br(Res);
handle(Arg,'POST', ["self_register"])->
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Res=
    case proplists:get_value("group_id",Params) of
    <<"dth_common">> ->    lw_register:self_noauth_register(Params);
    <<"zy_common">> ->    lw_register:self_noauth_register(Params);
    _-> utility:pl2jso([{status,failed},{reason,invalid_params}])
    end,
    io:format("self_register:req:~p ack:~p~n",[Params,Res]),
    Res;
handle(Arg,'POST', ["add_info"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res= lw_register:add_info(Json),
    utility:pl2jso(Res);
handle(Arg,'POST', ["forget_pwd"])->
    IP = utility:client_ip(Arg),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Res= lw_register:forgetpwd({obj,[{"ip",IP}|Params]}),
    Res;
handle(Arg,'POST', ["modify_pwd"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res= lw_register:modifypwd(Json),
    utility:pl2jso(Res);
handle(Arg, 'POST', ["callback"]) ->
    {UUID, Local, Remote} = utility:decode(Arg, [{uuid,s},{local,s},{remote,s}]),	
    {ok, {obj, Params}, _} = rfc4627:decode(Arg#arg.clidata),
    GroupId=proplists:get_value("groupid", Params,get_group_id(UUID,Arg)),
    Res = start_callback({GroupId, UUID}, Local, Remote,utility:client_ip(Arg)),
    io:format("start callback :~p res:~p~n", [{Local, Remote}, Res]),
    utility:pl2jso(Res);
handle(Arg, 'DELETE', ["callback"]) ->
    SIDStr = (utility:query_string(Arg, "session_id")),
    [UUID|_]=string:tokens(SIDStr,"_"),
    SID=list_to_binary(SIDStr),
    GroupId=get_group_id(UUID,Arg),    
    utility:pl2jso(stop_callback({GroupId,SID}, utility:client_ip(Arg)));    
%% handle get callback status request
handle(Arg, 'GET', ["calls", "status"]) ->
    SIDStr = (utility:query_string(Arg, "session_id")),
    [UUID|_]=string:tokens(SIDStr,"_"),
    SID=list_to_binary(SIDStr),
    GroupId=get_group_id(UUID,Arg),    
    utility:pl2jso(get_callback_status({GroupId,SID}, utility:client_ip(Arg)));    
handle(Arg,'POST', ["login"])->
    IP = utility:client_ip(Arg),
    Tuple=Arg#arg.headers,
    Names=[headers|record_info(fields,headers)],
    Headers=lists:zip(Names,tuple_to_list(Tuple)),
%    io:format("lw_mobile login headers:~n~p~n",[Headers]),
    {ok, Json={obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Res=login_processor:login([{"ip",IP}|Params]),
    GroupId=utility:get_string(Json,"group_id"),
    Result=translate_reason(undefined,GroupId,Res),
    %io:format("~p~n",[{GroupId,Res,Result}]),
    Result;
handle(Arg,'POST', ["third_reg"])->
    IP = utility:client_ip(Arg),
    Acc = utility:query_string(Arg, "acc"),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("third_register req:~p~n",[Params]),
    Res=lw_register:third_register(Acc,[{"ip",IP}|Params]),
    io:format("third_register res:~p~n",[Res]),
    Res;
handle(Arg,'POST', ["third_login"])->
    IP = utility:client_ip(Arg),
    Acc = utility:query_string(Arg, "acc"),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Res=login_processor:third_login(Acc,[{"ip",IP}|Params]),
    io:format("third_login res:~p~n",[Res]),
    Res;
handle(Arg,'POST', ["logout"])->
    IP = utility:client_ip(Arg),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    R=login_processor:logout([{"ip",IP}|Params]),
    R;
handle(Arg,'POST', ["coin_package"])->  %for international call according to phone rate zhiyu
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("coin_package:req:~p~n",[Params]),
    GroupId=proplists:get_value("group_id",Params),
    UUID=proplists:get_value("uuid",Params),
    case coin_packages_info(UUID,GroupId) of
    {ok,Info}-> utility:pl2jso([{status,ok},{package,utility:pl2jsos_br(Info)}]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg,'POST', ["ltalk_package"])->
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    io:format("ltalk_package~n:req:~p~n",[Params]),
    GroupId=proplists:get_value("group_id",Params),
    UUID=proplists:get_value("uuid",Params),
    case packages_info(UUID,GroupId) of
    {ok,Info}-> utility:pl2jso([{status,ok},{package,utility:pl2jsos_br(Info)}]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg,'POST', ["gen_zy_coin_payid"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    io:format("get_types_payid:req:~p~n",[Json]),
    Res=pay:gen_zy_coin_payid(Json),
    io:format("get_types_payid:ack:~p~n",[Res]),
    utility:pl2jso_br(Res);
handle(Arg,'POST', ["get_types_payid"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    io:format("get_types_payid:req:~p~n",[Json]),
    Res=pay:gen_types_payid(Json),
    io:format("get_types_payid:ack:~p~n",[Res]),
    utility:pl2jso_br(Res);
handle(Arg,'POST', ["get_coin"])->
    {UUID}= utility:decode(Arg, [{uuid, s}]),
    Res=lw_register:get_coin(UUID),
    io:format("get_coin:ack:~p~n",[Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["package_usage"])->
    {UUID}= utility:decode(Arg, [{uuid, s}]),
    Res=lw_register:get_pkginfo(UUID),
    %io:format("package_usage:ack:~p~n",[Res]),
    utility:pl2jso(Res);
    
handle(Arg,'POST', ["get_recharges"])->
    {UUID}= utility:decode(Arg, [{uuid, s}]),
    Res=lw_register:get_recharges(UUID),
    io:format("get_recharges:uuid:~p ack:~p~n",[UUID,Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["query_status"])->
    IP = utility:client_ip(Arg),
    {AccPhonePairs}= utility:decode(Arg, [{users, ao,[{acc,s},{phone,s}]}]),
%    io:format("query_status:~p~n",[AccPhonePairs]),
    do_query_status(AccPhonePairs);    
handle(Arg,Meth, Url=["p2p_"++_])->
    {{obj, Clidatas}}= utility:decode(Arg, [{opdata,r}]),
    Evt = proplists:get_value("event",Clidatas),
    %io:format("lw_mobile p2pmsg:~p~n",[{Meth,Url,Clidatas}]),
    handle_tp_call_msg(Arg,Meth,Url,Evt);
handle(Arg,'POST', ["login1"])->
    IP = utility:client_ip(Arg),
    {UUID,Pwd, {obj, Clidatas}}= utility:decode(Arg, [{uuid, s}, {pwd, s}, {clidata,o}]),
    R=login_processor:login(UUID,IP,Pwd,Clidatas),
    R;
handle(Arg,'POST', ["voip","rate"])->
    _IP = utility:client_ip(Arg),
    {UUID_SNO,Callee,Device_id}= utility:decode(Arg, [{user_id, s},{callee, s},{device_id,s}]),
    
    [{Callee,Rate}]=pay:get_rates("zy_common",voip, [Callee]),
    io:format("rate:~p~n",[{UUID_SNO,Callee,Rate,utility:value2binary(Rate)}]),
    utility:pl2jso([{status,ok},{rate,utility:value2binary(Rate)}]);
handle(Arg, 'POST', ["voip", "calls"]) ->
    _IP = utility:client_ip(Arg),
    {UUID_SNO,Callee,Device_id}= utility:decode(Arg, [{user_id, s},{callee_phone, s},{dev_id,s}]),
    R=login_processor:autheticated(UUID_SNO,Callee),
    io:format("call auth result:~p Device_id:~p~n",[{UUID_SNO,R},Device_id]),
    case R of
    [{status,ok},{uuid,UUID}|_]-> start_call0(login_processor:filter_phone(UUID), Arg);
    [{status,failed},{reason,Reason}]->
        utility:pl2jso(get_failed_note(UUID_SNO,Reason))
    end;
handle(Arg, 'DELETE', [ "voip", "calls"]) ->
    SessionID = utility:query_string(Arg, "session_id"),
    {Node, Sid} = voice_handler:dec_sid(SessionID),
    rpc:call(Node, avanda, stopNATIVE, [Sid]),
    io:format("lw_mobile: stop~n~p~n", [Sid]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'GET', ["version_no"]) ->
    case file:consult(?VERSION_INFO) of
    {ok,Info}-> utility:pl2jso_br([{status,ok}|Info]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg, 'GET', ["version_dth_no"]) ->
    case file:consult(?VERSION_DTH_INFO) of
    {ok,Info0}-> 
        Node=get_node_by_ip0(unused,utility:client_ip(Arg)),
        AndroidPath=proplists:get_value(list_to_atom(atom_to_list(Node)++"_android"),Info0),
        Info= if AndroidPath==undefined-> Info0; true-> lists:keystore(version_path,1, Info0,{version_path,AndroidPath}) end,
        VPath=proplists:get_value(Node,Info),
        Info1= if VPath==undefined-> Info; true-> lists:keystore(i_version_path,1, Info,{i_version_path,VPath}) end,
        utility:pl2jso_br([{status,ok}|Info1]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg, 'GET', ["version_common_no"]) ->
    case file:consult(?VERSION_COMMON_INFO) of
    {ok,Info}-> utility:pl2jso_br([{status,ok}|Info]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg, 'GET', ["voip", "calls"]) ->
     SessionID = utility:query_string(Arg, "session_id"),
     Result = case voice_handler:dec_sid(SessionID) of
                {invalid_node,0}->   [{status, failed}, {reason, invalide_sid}];
                {Node, Sid}->
                    case rpc:call(Node, wkr, getVOIP_with_stats, [Sid]) of
                         {ok, Status,Stats0}->
%                            io:format("stats:~p~n",[Stats0]),
                            Stats=proplists:delete(ip,Stats0),
                            [{status, ok}, {peer_status, Status},{state, Status},{stats,utility:pl2jso_br(Stats)}];
                         {badrpc, Reason}-> 
                             [{status, failed}, {reason, Reason}];
                        {failed, Reason}-> [{status, failed}, {reason, Reason}]
                    end
                end,
    % io:format("lw_mobile: get ~p~n~p~n", [SessionID,Result]),
    utility:pl2jso_br(Result);

handle(Arg, Method, ["paytest"|Params]) ->
    pay:handle(Arg,Method,Params);
handle(Arg, 'POST', ["voip", "dtmf"]) ->
   {Session_id, Num} = utility:decode(Arg,[{session_id, s},{num, s}]),
   %%Session_id = utility:query_string(Arg, "session_id"),
   %%Num = utility:query_string(Arg, "num")
   {Node, Sid} = voice_handler:dec_sid(Session_id),
   Res=rpc:call(Node, wkr, eventVOIP, [Sid, {dail,Num}]),
   io:format("dtmf:~p res:~p~n",[Num,Res]),
   utility:pl2jso([{status, ok}]);

%% ios
handle(Arg, 'POST', ["voip", "icalls"]) ->
    _IP = utility:client_ip(Arg),
    {UUID_SNO,Callee}= utility:decode(Arg, [{uuid, s},{phone, s}]),
    
    Node=lw_mobile:get_node_by_ip0(Callee,UUID_SNO,utility:client_ip(Arg)),
%    utility:log(?CALL, "ios:~s=>~s ~s ~s clidata:~p",[UUID_SNO,Callee,utility:make_ip_str(_IP),Node,utility:get_by_stringkey("clidata",Arg)]),
    case login_processor:autheticated(UUID_SNO,Callee) of
    [{status,ok},{uuid,UUID0}|_]-> 
        UUID=login_processor:filter_phone(UUID0),
        GroupId=get_group_id(UUID,Arg),
        login_processor:add_traffic(#traffic{uuid=UUID,caller=UUID,callee=Callee}),
        voice_handler:handle_startcall_nocheck_token(Node,GroupId,Arg);
    [{status,failed},{reason,Reason}]->
        utility:pl2jso(get_failed_note(UUID_SNO,Reason))
    end;

handle(Arg, 'DELETE', [ "voip", "icalls"]) ->
    SessionID = utility:query_string(Arg, "session_id"),
    {Node, Sid} = voice_handler:dec_sid(SessionID),
    voice_handler:fzd_stop_voip(not_used,SessionID, not_used),
%     io:format("lw_mobile: stop~n~p~n", [Sid]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'GET', ["voip", "icalls"]) ->
     voice_handler:handle(Arg, 'GET', ["fzdvoip", "status_with_qos"]);
handle(Arg, 'GET', ["voip", "incomingcalls"]) ->
     voice_handler:handle(Arg, 'GET', ["fzdvoip", "status_with_qos"]);

handle(Arg, 'GET', ["voip", "incomingcalls1"]) ->
    SessionID = utility:query_string(Arg, "session_id"),
    {Node, Sid} = voice_handler:dec_sid(SessionID),
    R=rpc:call(Node, voip_sup, get_rtp_stat, [Sid]),
    io:format("ios GET icalls status:~p res:~p~n",[Sid,R]),
    utility:pl2jso(R);

handle(Arg, 'POST', [ "call_history"]) ->
    _IP = utility:client_ip(Arg),
    {UUID,StartId,_Num}= utility:decode(Arg, [{uuid, s},{start_id, i},{num,i}]),
    LastTime=list_to_binary(utility:d2s(calendar:local_time())),
    GroupId=get_group_id(UUID,Arg),
    R=
    case rpc:call('traffic@lwork.hk',traffic,get_recent_traffic,[{GroupId,UUID},StartId]) of
    History when is_list(History)->
        [{status,ok},{history,History}];
    _->  [{status,failed},{reason,aaa}]
    end,
    utility:pl2jso(R);

handle(Arg, 'POST', [ "order_list"]) ->
    _IP = utility:client_ip(Arg),
    {ok, Json={obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    GroupId=utility:get_string(Json,"group_id"),
    {atomic,Records}=pay:get_paid_items(GroupId),
    Plss=[utility:record2pl(record_info(fields,pay_types_record),I)||I<-Records],
    utility:pl2jsos(Plss);

%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    [{status,405}].

handle_tp_call_msg(Arg,Meth, Params,<<"sip_call_in">>)->
    {Opdata={obj,_}}= utility:decode(Arg, [{opdata,r}]),
    sip_tp_call_handle(Arg,Meth,Params,Opdata);
    
handle_tp_call_msg(Arg,'POST', ["p2p_ios_ringing"],_)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("p2p_ios_ringing sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=case rpc:call(Node, avanda, processP2p_ios_ringing, [Sid]) of
    ok-> [{status,ok}];
    {failed,Reas}-> [{status,failed},{reason,Reas}]
    end,
    io:format("p2p_ios_ringing:~p res:~p~n",[Sid_str,R]),
    utility:pl2jso(R);
handle_tp_call_msg(Arg,'POST', ["p2p_ios_reject"],_)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    io:format("p2p_ios_reject sid_str:~p~n", [Sid_str]),
    rpc:call(Node, wkr, stopVOIP, [Sid]),
    utility:pl2jso([{status,ok}]);
handle_tp_call_msg(Arg,'POST', ["p2p_ios_poll"],O)-> handle_tp_call_msg(Arg,'POST', ["p2p_poll"],O);
handle_tp_call_msg(Arg,'POST', ["p2p_ios_answer"],_)->
%    {{Sid_str},Clidata,UUID,Phone,{Port}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]},{clidata,r},{caller_phone,s},{callee_phone,s},{sdp, o, [{port, i}]}]),
    {{Sid_str},SDP}= utility:decode(Arg, [{opdata, o, [{session_id,s}]},{sdp,b}]),
    IP = utility:client_ip(Arg),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    io:format("p2p_ios_answer req ~p~n",[Sid_str]),
    R=rpc:call(Node, avanda, processP2p_ios_answer, [Sid,SDP]),
    io:format("p2p_ios_answer res:~p~n",[R]),
    
    case R of
    {ok,AnsSDP,SelfSid}->
        utility:pl2jso_br([{status, ok},{session_id, voice_handler:enc_sid(Node, SelfSid)}, {sdp, AnsSDP}]);
    {ok,AnsSDP}->
        utility:pl2jso_br([{status, ok},{session_id, Sid_str}, {sdp, AnsSDP}]);
    {failed,Reason}->
        utility:pl2jso_br([{status,failed}, {reason, Reason}])
    end;
handle_tp_call_msg(Arg,'POST', ["p2p_ringing"],_)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("p2p_ringing sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=case rpc:call(Node, avanda, processP2p_ringing, [Sid]) of
    ok-> [{status,ok}];
    {failed,Reas}-> [{status,failed},{reason,Reas}]
    end,
    io:format("p2p_ringing:~p res:~p~n",[Sid_str,R]),
    utility:pl2jso(R);
handle_tp_call_msg(Arg,'POST', ["p2p_poll"],_)->
    {{SessionID}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
   % io:format("p2p_poll sid_str:~p~n", [SessionID]),
     Result = case voice_handler:dec_sid(SessionID) of
                {invalid_node,0}->   [{status, failed}, {reason, invalide_sid}];
                {Node, Sid}->
                    case rpc:call(Node, wkr, getVOIP_with_stats, [Sid]) of
                         {ok, Status,Stats0}->
                            io:format("p2p_ios_poll:Status:~p Sid:~p~n",[Status,Sid]),
                            Stats=proplists:delete(ip,Stats0),
                            [{status, ok}, {peer_status, Status},{stats,utility:pl2jso(Stats)}];
                         {badrpc, Reason}-> 
                             [{status, failed}, {reason, Reason}];
                        {failed, Reason}-> [{status, failed}, {reason, Reason}]
                    end
                end,
%     io:format("lw_mobile: get ~p~n~p~n", [SessionID,Result]),
    utility:pl2jso(Result);
handle_tp_call_msg(Arg,'POST', ["p2p_answer"],_)->
    {{Sid_str},Clidata,UUID,Phone,{Port}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]},{clidata,r},{caller_phone,s},{callee_phone,s},{sdp, o, [{port, i}]}]),
    IP = utility:client_ip(Arg),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=rpc:call(Node, avanda, processP2p_answer, [Sid,{IP, Port}]),
    io:format("p2p_answer:~s=>~s ~s ~s clidata: ~p",[UUID,Phone,utility:make_ip_str(utility:client_ip(Arg)),atom_to_list(Node),Clidata]),
    io:format("answer res:~p~n",[R]),
    case R of
    {successful,SessionID,{PeerIP,PeerPort}, Other}->
        utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, {port, PeerPort}|Other]);
    {failed,Reason}->
        utility:pl2jso([{status,failed}, {reason, Reason}])
    end;
handle_tp_call_msg(Arg,'POST', ["p2p_reject"],_)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("p2p_reject sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    rpc:call(Node, avanda, stopNATIVE, [Sid]),
    utility:pl2jso([{status, ok}]);
handle_tp_call_msg(_,_, _,_)-> utility:pl2jso([{status,ok},{reason,unhandled}]).


sip_tp_call_handle(Arg,'POST', ["p2p_ringing"],_opdata)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("sip_tp_ringing sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=
        case rpc:call(Node, avanda, processSipP2pRing, [Sid]) of
             ok->
                [{status, ok}];
             {badrpc, Reason}-> 
                 io:format("sip_tp_ringing ack:~p~n", [Reason]),
                 [{status, failed}, {reason, Reason}];
            {failed, Reason}-> 
                io:format("sip_tp_ringing ack:~p~n", [Reason]),
                [{status, failed}, {reason, Reason}]
        end,
    utility:pl2jso(R);
sip_tp_call_handle(Arg,'POST', ["p2p_poll"],_Clidata)->
    {{SessionID}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
%    io:format("p2p_poll sid_str:~p~n", [SessionID]),
     Result = case voice_handler:dec_sid(SessionID) of
                {invalid_node,0}->   [{status, failed}, {reason, invalide_sid}];
                {Node, Sid}->
                    case rpc:call(Node, wkr, getVOIP_with_stats, [Sid]) of
                         {ok, Status,Stats0}->
                            io:format("stats:~p~n",[Stats0]),
                            Stats=proplists:delete(ip,Stats0),
                            [{status, ok}, {peer_status, Status},{stats,utility:pl2jso(Stats)}];
                         {badrpc, Reason}-> 
                             [{status, failed}, {reason, Reason}];
                        {failed, Reason}-> [{status, failed}, {reason, Reason}]
                    end
                end,
%     io:format("lw_mobile: get ~p~n~p~n", [SessionID,Result]),
    utility:pl2jso(Result);
sip_tp_call_handle(Arg,'POST', ["p2p_answer"],Opdata={obj,Pls})->    
    {{SessionID}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("sip_p2p_answer sid_str:~p~n", [SessionID]),
    case voice_handler:dec_sid(SessionID) of
        {invalid_node,0}->   [{status, failed}, {reason, invalide_sid}];
        {Node, Sid}->
            case rpc:call(Node, avanda, processSipP2pAnswer, [Sid]) of
                 ok->
                    {obj,[{status,ok}|Pls]};
                 {badrpc, Reason}-> 
                     utility:pl2jso([{status, failed}, {reason, Reason}]);
                {failed, Reason}-> utility:pl2jso([{status, failed}, {reason, Reason}])
            end
        end;
sip_tp_call_handle(Arg,'POST', ["p2p_ios_poll"],_Opdata={obj,_Pls})->    
    {{SessionID}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
     Result = case voice_handler:dec_sid(SessionID) of
                {invalid_node,0}->   [{status, failed}, {reason, invalide_sid}];
                {Node, Sid}->
                    case rpc:call(Node, p2w, get_call_status, [Sid]) of
                         {value, Status, Stats0}->
                            io:format("p2p_ios_poll:Status:~p stats:~p~n",[Status,Stats0]),
                            Stats=proplists:delete(ip,Stats0),
                            [{status, ok}, {peer_status, Status},{stats,utility:pl2jso(Stats)}];
                         {badrpc, Reason}-> 
                             [{status, failed}, {reason, Reason}];
                        {failed, Reason}-> [{status, failed}, {reason, Reason}]
                    end
                end,
    utility:pl2jso(Result);
    
sip_tp_call_handle(Arg,'POST', ["p2p_ios_poll1"],_Opdata={obj,_Pls})->    
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=rpc:call(Node, voip_sup, get_rtp_stat, [Sid]),
    io:format("p2p_ios_poll1:~p res:~p~n",[Sid,R]),
    utility:pl2jso(R);
    
sip_tp_call_handle(Arg,'POST', ["p2p_ios_ringing"],_Opdata={obj,_Pls})->    
    io:format("p2p_ios_ringing sid_str:~p~n", [p2p_ios_ringing]),
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("p2p_ios_ringing sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=case rpc:call(Node, p2w, sip_p2p_ring, [Sid]) of
        ok-> [{status,ok}];
        {failure,Reas}-> [{status,failed},{reason,Reas}]
    end,
    io:format("p2p_ringing:~p res:~p~n",[Sid_str,R]),
    utility:pl2jso(R);
    
sip_tp_call_handle(Arg,'POST', ["p2p_ios_ringing1"],_Opdata={obj,_Pls})->    
    io:format("p2p_ios_ringing1 sid_str:~p~n", [p2p_ios_ringing]),
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    io:format("p2p_ios_ringing sid_str:~p~n", [Sid_str]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    R=case rpc:call(Node, voip_sup, p2p_ring, [Sid]) of
        ok-> [{status,ok}];
        {failure,Reas}-> [{status,failed},{reason,Reas}]
    end,
    io:format("p2p_ringing:~p res:~p~n",[Sid_str,R]),
    utility:pl2jso(R);
    
sip_tp_call_handle(Arg,'POST', ["p2p_ios_answer"],Opdata={obj,Pls})->    
    {SDP,{SessionID}}= utility:decode(Arg, [{sdp,b},{opdata, o, [{session_id,s}]}]),
    io:format("sip p2p_ios_answer sid_str:~p~n", [SessionID]),
    Res=
    case voice_handler:dec_sid(SessionID) of
        {invalid_node,0}->   
            [{status, failed}, {reason, invalide_sid}];
        {Node, Sid}->
            case rpc:call(Node, p2w, p2w_ios_answer, [Sid,SDP]) of
                 {ok,AnsSDP}->
                     utility:pl2jso_br([{status, ok}, {session_id, SessionID}, {sdp, AnsSDP}]);
                 {badrpc, Reason}-> 
                     utility:pl2jso([{status, failed}, {reason, Reason}]);
                {failure, Reason}-> utility:pl2jso([{status, failed}, {reason, Reason}])
            end
        end,
    io:format("ios p2p_ios_answer res:~p~n",[Res]),
    Res;
sip_tp_call_handle(Arg,'POST', ["p2p_ios_answer1"],Opdata={obj,Pls})->    
    {SDP,{SessionID}}= utility:decode(Arg, [{sdp,b},{opdata, o, [{session_id,s}]}]),
    io:format("sip p2p_ios_answer1 sid_str:~p~n", [SessionID]),
    Res=
    case voice_handler:dec_sid(SessionID) of
        {invalid_node,0}->   
            [{status, failed}, {reason, invalide_sid}];
        {Node, Sid}->
            case rpc:call(Node, voip_sup, p2p_answer, [Sid,SDP]) of
                 {ok,_Pid,AnsSDP}->
                     utility:pl2jso_br([{status, ok}, {session_id, SessionID}, {sdp, AnsSDP}]);
                 {badrpc, Reason}-> 
                     utility:pl2jso([{status, failed}, {reason, Reason}]);
                {failure, Reason}-> utility:pl2jso([{status, failed}, {reason, Reason}])
            end
        end,
    io:format("ios p2p_ios_answer res:~p~n",[Res]),
    Res;
sip_tp_call_handle(Arg,'POST', ["p2p_ios_reject"],Clidata)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    rpc:call(Node, wkr, stopVOIP, [Sid]),
    utility:pl2jso([{status,ok}]);
sip_tp_call_handle(Arg,'POST', ["p2p_reject"],Clidata)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    rpc:call(Node, avanda, stopNATIVE, [Sid]),
    utility:pl2jso([{status,ok}]);
sip_tp_call_handle(_Arg,'POST', _,_Clidata)->
    utility:pl2jso([{status,failed},{reason,sip_tp_call_unhandled}]).

push(Phone1,Content)->
    case login_processor:get_tuple_by_uuid_did(Phone1) of
    #login_itm{devid=DevId,pls=Pls} when is_list(DevId) andalso length(DevId)>0 andalso DevId=/="push_not_permitted"->
        case login_processor:get_phone_type(Phone1) of
            <<"ios">> -> push_ios(Phone1,DevId,Content);
            <<"android">> -> push_android(Phone1,Content);
            O-> 
                io:format("lw_mobile:push unknown os_type ~p~n",[O]),
                real_call
        end;
    O->
        io:format("lw_mobile:push unknown item ~p~n",[O]),
        real_call
    end.
push_ios(Phone1,DevId,Content)->
    send_notification1(DevId,Content),
    io:format("push_ios:Phone1,DevId,Content:~p~n",[{Phone1,DevId,Content}]),
    ios_webcall.
push_android(Phone1,Content)->
    Act0 = fun(PollPid, CustomContent) when is_pid(PollPid)-> 	 
                    io:format("lw_mobile:start_call0 to push ~p to :~p~n",[CustomContent,PollPid]),
                    xhr_poll:down(PollPid,CustomContent),
                    maybe_p2p_call;
                 (_,_)-> real_call
                 end,
    Act0(login_processor:get_poll_pid(Phone1), Content).             
p2p_push(CallerNode,Phone,Content)->
    case login_processor:get_ip_tuple(Phone) of
    undefined-> real_call;
    CalleeIp->
%        case get_node_by_ip0(Phone,CalleeIp) of
%        CallerNode->  push(Phone,Content);
 %       _-> real_call
%        end
        push(Phone,Content)
    end.

get_maxtalkt(_UUID,"*"++_,_Arg)-> no_limit;
get_maxtalkt(UUID,Callee,_Arg)->
   case lw_register:max_minutes(UUID,Callee) of
   Lefts when is_number(Lefts) andalso Lefts<1000 -> Lefts*60*1000;
   Lefts when is_number(Lefts) -> no_limit
   end.
%get_group_id(Arg)->   
%    case utility:get_by_stringkey("group_id",Arg) of
%    <<"">> ->binary_to_list(utility:get_by_stringkey("groupid",Arg));
%    GroupIdBin-> binary_to_list(GroupIdBin)
%    end.
get_group_id(UUID,_Arg)->     %from login_info
    login_processor:get_group_id(UUID).
charge_callback_fun(GroupId,UUID)->
    Fun= if GroupId=="dth_common" orelse  GroupId=="dth" -> consume_minutes; true-> consume_coins end,
    {node(),lw_register,Fun,UUID}.
consume_func(GroupId,UUID)->
    {node(),lw_register,zy_consume_func,UUID}.
build_call_options(UUID, Arg)->
    Ip=utility:client_ip(Arg),
    { _CallerPhone, Phone, {IPs=[SessionIP|_], Port, Codec}, Class} = utility:decode(Arg, [{caller_phone, s}, {callee_phone, s},
	                                   {sdp, o, [{ip, as}, {port, i}, {codec, s}]}, {userclass, s}]),
    {MaxtalkT0,GroupId} = {get_maxtalkt(UUID,Phone,Arg),get_group_id(UUID,Arg)},
    Node=node(),
    Cid0=lw_register:get_bind_phone(UUID),
    Cid=if Cid0==""-> trans_mobile(UUID,GroupId); true-> Cid0 end,
    Options0=[{uuid, {GroupId, UUID}}, {audit_info, [{uuid,UUID},{ip,utility:make_ip_str(Ip)}]},{cid,Cid},{userclass, Class},{codec,Codec},
                     {callback,charge_callback_fun(GroupId,UUID)},{country,utility:country(Ip)},
                     {consume_callback,consume_func(GroupId,UUID)}],
    case voice_handler:check_token(UUID, string:tokens(Phone,"@")) of
        {pass, Phone2,Others=[FeeLength]} ->
    %		         io:format("Phone:~p Others:~p~n",[Phone,Others]),
             MaxtalkT = case catch list_to_integer(FeeLength) of
                                  IFee when is_integer(IFee) andalso IFee > 0-> IFee;
                                  _-> MaxtalkT0
                              end,
    		[{phone, Phone2}, {max_time, MaxtalkT}|Options0];
        {pass, Phone2} ->
                MaxtalkT = MaxtalkT0,
    		[{phone, Phone2}, {max_time, MaxtalkT}|Options0];
    	_ ->
                MaxtalkT = MaxtalkT0,
    		[{phone, Phone}, {max_time, MaxtalkT}|Options0]
    end.

start_call0(UUID, Arg) ->
    start_call(UUID, Arg,fun p2p_push/3).	                                   

start_call(UUID,Arg)-> start_call(UUID,Arg, fun(_,_)->   void end).
start_call(UUID, Arg, XgAct) ->
	{  Phone, {IPs=[SessionIP|_], Port}} = utility:decode(Arg, [{callee_phone, s}, {sdp, o, [{ip, as}, {port, i}]}]),
	login_processor:add_traffic(#traffic{uuid=UUID,caller=UUID,callee=Phone}),
      Node =get_node_by_ip0(Phone,UUID,utility:client_ip(Arg)),
	io:format("-"),
	Ip=utility:client_ip(Arg),
	utility:log(?CALL, "~s=>~s ~s ~s clidata:~p",[UUID,Phone,utility:make_ip_str(Ip),atom_to_list(Node),utility:get_by_stringkey("clidata",Arg)]),
	Options = build_call_options(UUID,Arg),
      if length(Phone) < 3 ->  utility:pl2jso([{status, failed},{reason,phone_too_short}]);
      true->
%            io:format("start_call req:~p~noptions:~p~n",[Arg#arg.clidata, Options]),
             Res=
        	case rpc:call(Node, avanda, processNATIVE, [[utility:make_ip_str(Ip)], Port, Options]) of
        	    {successful,SessionID,{PeerIP,PeerPort}}->
        	         utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort}, {codec, 102},{payload_mode, normal},{rssrc, <<"123">>}]);
        	    {successful,SessionID,{PeerIP,PeerPort},Other}->
        	         R=utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort},{codec, 102}|Other]),
%        	         io:format("lw_mobile:~p->~p start~n~p~n", [UUID,Phone,R]),
                      %% xg transfer
                      Callee = proplists:get_value(phone,Options),
                      Cid=login_processor:trans_caller_phone(Callee,UUID),
                      CustomContent=[{alert,list_to_binary(Cid)},{badge,1},{'content-available',1},{sound,<<"lk_softcall_ringring.mp3">>},{event,<<"p2p_inform_called">>},{caller,list_to_binary(Cid)},{opdata,R}],
                      CallType= 
                          case utility:get_by_stringkey("type",Arg) of
                          <<"p2p">> -> XgAct(Node,Callee,CustomContent);
                          _-> real_call  
                          end,
%                      io:format("start_call:666666666666666666666666666666666~p",[CallType]),
                      if CallType==ios_webcall->
                          rpc:call(Node, avanda, set_call_type, [SessionID, p2p_call]),
                          rpc:call(Node, avanda, processSipP2pRing, [SessionID]);
                      true->
                          rpc:call(Node, avanda, set_call_type, [SessionID, CallType])
                      end,
%                      io:format("start_call:9999999999999999999999999999999999~p",[CallType]),
        	         utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort},{codec, 102}|Other]);
        	    {_, nodedown}-> utility:pl2jso([{status, failed},{reason,nodedown}]);
        	    {failed, Reason}-> utility:pl2jso([{status, failed},{reason,Reason}])
        	end,
%        	io:format("lw_mobile startcall res:~p~n", [Res]),
        	Res
       end.

get_wcg_node(_UUID,Ip)->
    case wcg_disp:choose_wcg() of
        N when is_atom(N)-> 
            MonNode = wwwcfg:get(monitor),
            Wcgs_status= rpc:call(MonNode, wcgsmon, get, [status]),
            Stats = rpc:call(wwwcfg:get(test_node),statistic,get,[]),
            if  (is_list(Stats) andalso Wcgs_status=={status,justdown})-> wwwcfg:get(test_node); 
                 true-> N 
            end;
        _->    wwwcfg:get(test_node)
    end.

get_node_by_ip0(Callee,UUID,Ip={10,31,203,1}) when length(Callee)=<5 -> 
    R='gw1@112.74.96.171',
    io:format("~p=>~p Ip:~p choose node:~p~n",[UUID,Callee,Ip,R]),
    R;
get_node_by_ip0(_Callee="0086"++_,UUID,Ip)-> 
    R=get_node_by_ip(UUID,Ip),
    io:format("~p=>~p Ip:~p choose node:~p~n",[UUID,_Callee,Ip,R]),
    R;
%get_node_by_ip0(_Callee="00"++_,UUID,Ip) -> 
%    R=get_internal_node_by_ip(UUID,Ip),
%    io:format("~p=>~p Ip:~p choose node:~p~n",[UUID,_Callee,Ip,R]),
%    R;
get_node_by_ip0(_Callee,UUID,Ip)->
    R=get_node_by_ip(UUID,Ip),
    io:format("~p=>~p Ip:~p choose node:~p~n",[UUID,_Callee,Ip,R]),
    R.

get_node_by_ip0(UUID,Ip)-> get_node_by_ip0(unused,UUID,Ip).
    

get_internal_node_by_ip("862180246528",_Ip)-> 'gw@10.32.2.4';
get_internal_node_by_ip(UUID,Ip)-> 
    wwwcfg:get_internal_wcgnode(utility:c2s(utility:country(Ip))).
%get_node_by_ip(_luyin_test="13788927293",_Ip)-> 'gw@119.29.62.190';
get_node_by_ip(UUID,_Ip) when UUID=="31271295" orelse UUID=="18017813673" orelse UUID=="008618017813673"-> 
    'gw1@10.31.203.1';%    'gw@119.29.62.190'; %'gw_git@202.122.107.66'; %'gw_git@202.122.107.66'; %
get_node_by_ip(UUID=_yxwfztest,_) when UUID=="31230011" orelse UUID=="31231028" -> get_internal_node_by_ip(UUID,{168,167,165,245});
%get_node_by_ip(_Fztest="00862180246198",_Ip)-> wwwcfg:get_wcgnode("Africa");
%get_node_by_ip(UUID="3"++_,Ip) when length(UUID)==8 -> get_internal_node_by_ip(UUID,Ip);
%get_node_by_ip(UUID="00862180246"++_,Ip)-> get_internal_node_by_ip(UUID,Ip);
get_node_by_ip(UUID,{203,222,195,122})-> get_internal_node_by_ip(UUID,{203,222,195,122});
get_node_by_ip(UUID,{10,31,203,1})-> wwwcfg:get_wcgnode("Mainland");

get_node_by_ip(UUID,Ip)->
    R0= wwwcfg:get_wcgnode(utility:c2s(utility:country(Ip))),
    case lists:member(R0,nodes()) of
    true-> R0;
    _-> wwwcfg:get_wcgnode(default)
    end.
    
start_callback(UUID={_,UserId}, LocalPhone, Phone, SessionIP) ->    % remove fzd
    case login_processor:autheticated(UserId,Phone,callback) of
    [{status,ok},{uuid,_}|_]-> 
%        WcgNode=get_node_by_ip(LocalPhone,SessionIP),
%        {_,SIPNODE} = rpc:call(WcgNode,avscfg,get,[sip_app_node]),
        SIPNODE=wwwcfg:get(voice_node),
        do_callback1(SIPNODE,UUID,LocalPhone,Phone,no_limit);
    R->
         R
    end.

do_callback1(SIPNODE,_UUID={Groupid,Uuid},LocalPhone,Remote_phone,MaxtalkTime)->
    {_A,B,_C}=erlang:now(),
    Session_id=list_to_binary(Uuid++"_"++integer_to_list(B)),
    Plist=[{Groupid,Session_id}, [{groupid,fake_auditinfo},{caller,{"", LocalPhone, 1}},
                 {callee,{"", Remote_phone, 1}},{max_time,MaxtalkTime},{callback,charge_callback_fun(Groupid,Uuid)},
                 {consume_callback,consume_func(Groupid,Uuid)}]],
    io:format("do_callback1,~p~n",[Plist]),
    
    case rpc:call(SIPNODE, lw_voice, start_callback, Plist) of
      ok->
          io:format("start callback! session_id:~p~n", [Session_id]),
          [{status, ok}, {session_id, Session_id}];
      {failed, session_already_exist}-> [{status, failed}, {reason,session_already_exist}]
    end.

get_callback_status(SID, _SessionIP) ->
    Node = wwwcfg:get(voice_node),
    catch case rpc:call(Node,lw_voice,get_callback_status,[SID]) of
    {status,{Caller,CallerStatus},{Callee,CalleeStatus}}->
        [{status,ok}, {local,CallerStatus},{remote,CalleeStatus}];
    Other-> 
        io:format("get_callback_status:~p~n",[Other]),
        [{status,ok},{local,released},{remote,released}]
    end.

stop_callback(SID, _SessionIP) ->
    Node = wwwcfg:get(voice_node),
    rpc:call(Node,lw_voice,stop_callback,[SID]),
    [{status,ok}].

sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid)->
    login_processor:add_traffic(#traffic{uuid=Callee,caller=Caller,callee=Callee,direction=incoming}),
    sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid,login_processor:get_phone_type(Callee)).
sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid,"ios")->
    io:format("Callee:~p~n",[{Callee,login_processor:get_ip_tuple(Callee)}]),
    case login_processor:get_tuple_by_uuid_did(Callee) of
    #login_itm{ip=Ip,phone=Phone,group_id=GroupId} ->  
        WcgNode=get_internal_node_by_ip(Callee,Ip),
        Result= rpc:call(WcgNode, p2w,start, [call_ios,SipPid,
                                 [{ss_sdp,SipSdp},{voip_ua,SipPid},{callee,Callee},{cid,Caller},{phone,Callee}]]),
        io:format("sip_p2p_tp_call Callee:~p Ip:~p choose node:~p Caller:~p~n",[Callee,Ip,WcgNode,Caller]),
        case Result of
        {successful,SessionID,{PeerIP,PeerPort},Other}->
            io:format("www sip_p2p_tp_call ios rpc ok"),
            R=utility:pl2jso([{event,<<"sip_call_in">>},{caller,list_to_binary(Caller)},{callee,list_to_binary(Callee)},{session_id, voice_handler:enc_sid(WcgNode, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort}|Other]),
            CustomContent=[{alert,Caller},{badge,1},{'content-available',1},{sound,"lk_softcall_ringring.mp3"},{event,<<"p2p_inform_called">>},{caller,list_to_binary(Caller)},{opdata,R}],
            CallType=push(Callee,CustomContent),
            if 
            CallType == real_call-> 
                {failed,send_unavailable_to_wcgnode};
            true->
                {ok,{GroupId,Phone}}
            end;
        {failed, Reason}-> {failed,Reason}
        end;
    undefined->  {failed, callee_not_exist}
    end;
%not used    
sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid,"ios1")->
    Ip = login_processor:get_ip_tuple(Callee),
    io:format("ios Callee:~p~n",[{Callee,Ip}]),
    case Ip of
    undefined->  {failed, callee_not_exist};
    _ ->  
        WcgNode='wras@10.32.3.52',
        Result=rpc:call(WcgNode, voice, incomingSipWebCall, [SipSdp,Callee,SipPid]),
        io:format("ios sip_p2p_tp_call Callee:~p Ip:~p choose node:~p Caller:~p~n",[Callee,Ip,WcgNode,Caller]),
        case Result of
        {successful,SessionID}->
            io:format("www sip_p2p_tp_call rpc ok"),
            R=utility:pl2jso([{event,<<"sip_call_in">>},{caller,list_to_binary(Caller)},{callee,list_to_binary(Callee)},
                          {session_id, voice_handler:enc_sid(WcgNode, SessionID)}]),
            CustomContent=[{event,<<"p2p_inform_called">>},{caller,list_to_binary(Caller)},{opdata,R}],
            CallType=push(Callee,CustomContent),
            %rpc:call(WcgNode, avanda, processSipP2pRing, [SessionID]);
            ok;
        {failed, Reason}-> {failed,Reason}
        end
    end;
sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid,_)->
    io:format("Callee:~p~n",[{Callee,login_processor:get_ip_tuple(Callee)}]),
    case login_processor:get_tuple_by_uuid_did(Callee) of
    #login_itm{ip=Ip,phone=Phone,group_id=GroupId} ->  
        WcgNode=get_internal_node_by_ip(Callee,Ip),
        Result= rpc:call(WcgNode, avanda, processSipP2pCall, [[{ss_sdp,SipSdp},{voip_ua,SipPid},{callee,Callee},{cid,Caller},
                                {phone,Callee}]]),
        io:format("sip_p2p_tp_call Callee:~p Ip:~p choose node:~p Caller:~p~n",[Callee,Ip,WcgNode,Caller]),
        case Result of
        {successful,SessionID,{PeerIP,PeerPort},Other}->
            io:format("www sip_p2p_tp_call rpc ok"),
            R=utility:pl2jso([{event,<<"sip_call_in">>},{caller,list_to_binary(Caller)},{callee,list_to_binary(Callee)},{session_id, voice_handler:enc_sid(WcgNode, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort}|Other]),
            CustomContent=[{event,<<"p2p_inform_called">>},{caller,list_to_binary(Caller)},{opdata,R}],
            CallType=push(Callee,CustomContent),
            if 
            CallType == real_call-> 
                {failed,send_unavailable_to_wcgnode};
            true->
                {ok,{GroupId,Phone}}
            end;
        {failed, Reason}-> {failed,Reason}
        end;
    undefined->  {failed, callee_not_exist}
    end.

send_notification1(DeviceToken0,Content) ->
    Aps0=Content,
    Aps1=[{'content-available',1}]++Content,
    Aps0_=utility:pl2jso(Aps0),
    Aps1_=utility:pl2jso(Aps1),
    Payload0=rfc4627:encode(utility:pl2jso([{aps,Aps0_}])),
    Payload1=rfc4627:encode(utility:pl2jso([{aps,Aps1_}])),
%    Payload = "{\"aps\":{\"alert\":\"" ++ Content ++ "\",\"badge\":" ++ Badge ++ ",\"sound\":\"" ++ "chime" ++ "\"}}",
    DeviceToken  = lw_mobile:str_spaceremoved(DeviceToken0),
    Cmd_appstore_d="php priv/push4appstore_d.php "++DeviceToken++" '"++Payload0++"'",
    _Result4appstore_d=os:cmd(Cmd_appstore_d),
    _Result4appstore_r=os:cmd("php priv/push4appstore_r.php "++DeviceToken++" '"++Payload0++"'"),
    Cmd_push_d="php priv/simplepush1_d.php "++DeviceToken++" '"++Payload0++"'",
    io:format("send_notification1:Cmd:~p~n",[Cmd_push_d]),
    Result=os:cmd(Cmd_push_d),
    Result_r=os:cmd("php priv/simplepush1_r.php "++DeviceToken++" '"++Payload0++"'"),
%    io:format("send_notification1 result:~p~n",[{Result,Result_r,_Result4appstore_d,_Result4appstore_r}]),
    ok.
%% send_notification not used    
send_notification(UUID,DeviceToken,Content) ->
    Aps0=Content,
    Aps=utility:pl2jso_br(Aps0),
    Payload=rfc4627:encode(utility:pl2jso([{aps,Aps}])),
%    Payload = "{\"aps\":{\"alert\":\"" ++ Content ++ "\",\"badge\":" ++ Badge ++ ",\"sound\":\"" ++ "chime" ++ "\"}}",
    DeviceTokenBin  = hexstr_to_bin(DeviceToken),
    DeviceTokenSize = erlang:size(DeviceTokenBin),
    PayLoadBin  = list_to_binary(Payload),
    PayloadSize = byte_size(PayLoadBin),
    Packet = [<<0:8, DeviceTokenSize:16/big, DeviceTokenBin/binary, PayloadSize:16/big, PayLoadBin/binary>>],
%    io:format("send_notification~p,~p,~p,~p~n",[DeviceTokenSize,DeviceTokenBin,PayloadSize,PayLoadBin]),
    send_noti(Packet),
    Packet.

send_noti(Packet)->
    Address = "gateway.sandbox.push.apple.com",
    Port    = 2195,
    Cert    = filename:absname("priv/PushChatCert.pem"),
    Key     = filename:absname("priv/PushChatKey.pem"),
    Options = [{certfile, Cert}, {keyfile, Key}, {password, "livecom2015"}, {mode, binary}],
    Timeout = 30000,
    {ok, Socket} = ssl:connect(Address, Port, Options, Timeout),
    ssl:send(Socket, Packet),
    ssl:close(Socket).

test()->
    UUID="nihao",
    DeviceToken="3408497c e46bd3f6 5e4b7446 5929218b a617cf63 b838e402 9f367cd6 8c3a9e51",
    Aps0=[{alert,UUID},{sound,"default"},{event,<<"p2p_inform_called">>},{badge,1}],
    Aps=utility:pl2jso_br(Aps0),
    Payload=rfc4627:encode(utility:pl2jso([{aps,Aps}])),
%    Payload = "{\"aps\":{\"alert\":\"" ++ Content ++ "\",\"badge\":" ++ Badge ++ ",\"sound\":\"" ++ "chime" ++ "\"}}",
    DeviceTokenBin  = hexstr_to_bin(DeviceToken),
    DeviceTokenSize = erlang:size(DeviceTokenBin),
    PayLoadBin  = list_to_binary(Payload),
    PayloadSize = byte_size(PayLoadBin),
    Packet = [<<0:8, DeviceTokenSize:16/big, DeviceTokenBin/binary, PayloadSize:16/big, PayLoadBin/binary>>],
    {ok,FH0} = file:open("msgerlang.txt", [write,raw,binary]),
    file:write(FH0,Packet),
    file:close(FH0),
    send_noti(Packet),
    Packet.

do_query_status(AccPhonePairs)->
    AccF=fun(P)->
                case login_processor:get_account_tuple(P) of
                #login_itm{acc=Acc,group_id=Groupid} when Groupid=/="dth_common" -> Acc;
                _-> lw_register:uuid_key(P)
                end end,
    StatusF=fun(P)->
                case {login_processor:is_logined(P),lw_register:get_group_id(P)} of
                {true,_}-> online;
                {false,_}-> offline;
                {_,unregistered}-> unregistered;
                _-> offline
                end end,
    Data=[utility:pl2jso_br([{acc,A},{phone,P},{state,StatusF(P)},{im_id,AccF(P)}])||{A,P}<-AccPhonePairs],
    utility:pl2jso([{status,ok},{data,Data}]).
%%---------------------------------------------------------------------------------------------
str_spaceremoved(S)->str_spaceremoved(S,[]).
str_spaceremoved([$ |T],Acc)-> str_spaceremoved(T, Acc);
str_spaceremoved([],Acc)-> lists:reverse(Acc);
str_spaceremoved([H|T],Acc)-> str_spaceremoved(T,[H|Acc]).

hexstr_to_bin(S) ->
  hexstr_to_bin(S, []).
hexstr_to_bin([], Acc) ->
  list_to_binary(lists:reverse(Acc));
hexstr_to_bin([$ |T], Acc) ->
    hexstr_to_bin(T, Acc);
hexstr_to_bin([X,Y|T], Acc) ->
  {ok, [V], []} = io_lib:fread("~16u", [X,Y]),
  hexstr_to_bin(T, [V | Acc]).

translate_reason(_UUID,Groupid,Json)->
    {obj,Pls}=Json,
    case proplists:get_value(status,Pls) of
        failed->
            Reason=proplists:get_value(reason,Pls),
            Pls1=get_failed_note(_UUID,Groupid,Reason),
            {obj,lists:ukeymerge(1,Pls,Pls1)};
        _-> Json
    end.
get_failed_note(UUID,Reason)->  get_failed_note(UUID,get_group_id(UUID,undefined),Reason).

get_failed_note(_UUID,"zy_common",policy_risk)->
    [{status,failed},{reason,policy_risk},{type,alert},{timelen,5},
      {content,<<"国内拨打国内电话禁止使用直拨,请在下面的更多->设置->通话设置中选择使用回拨功能,详细请拨打咨询热线或者与客服联系">>}];
get_failed_note(_UUID,"dth_common",policy_risk)->
    [{status,failed},{reason,policy_risk},{type,alert},{timelen,5},
      {content,<<"根据工信部最新政策,您在国内无权使用此项业务,详细请咨询*812或者*810">>}];
get_failed_note(_UUID,"zy_common",group_not_match)->
    [{status,failed},{reason,group_not_match},{type,alert},{timelen,5},
      {content,<<"账号非法">>}];
get_failed_note(_UUID,"zy_common",balance_not_enough)->
    [{status,failed},{reason,balance_not_enough},{type,alert},{timelen,5},
      {content,<<"账户余额不足,请您充值。如有疑问请咨询客服,谢谢">>}];
get_failed_note(_UUID,"zy_common",not_actived)->
    [{status,failed},{reason,not_actived},{type,alert},{timelen,5},
      {content,<<"未激活">>}];
get_failed_note(_UUID,"zy_common",no_logined)->
    [{status,failed},{reason,no_logined},{type,tips},{timelen,5},
      {content,<<"未登录">>}];
get_failed_note(_UUID,_Groupid,balance_not_enough)->
    [{status,failed},{reason,balance_not_enough},{type,alert},{timelen,5},
      {content,<<"亲爱的用户,您的账户余额不足,请充值。如有疑问请拨打*812或者*810,谢谢！">>}];
get_failed_note(_UUID,_Groupid,not_actived)->
    [{status,failed},{reason,not_actived},{type,alert},{timelen,5},
      {content,<<"呼叫失败：电话未激活，可能原因：1 当月额度用完；2 套餐到期；3 当天拨打超过限制时长;4 拨打违规 详细请与代理商或者管理员联系,请用本软件拨打*810或者*812联系。">>}];
get_failed_note(_UUID,_Groupid,no_logined)->
    [{status,failed},{reason,no_logined},{type,tips},{timelen,5},
      {content,<<"您好,为确保账户安全,麻烦您重新登录,给您带来不便,敬请谅解">>}];
get_failed_note(_UUID,_Groupid,Other)->
    [{status,failed},{reason,Other},{type,tips},{timelen,5},{content,Other}].

packages_info(GroupId)-> packages_info("",GroupId).
    
packages_info(UUID,GroupId) when is_list(GroupId)-> packages_info(UUID,list_to_binary(GroupId));
packages_info(_,<<"dth_common">>)-> packages_info();
packages_info(UUID,<<"zy_common">>)->  packages_info(UUID,<<"zy_common">>,login_processor:get_country(UUID));
packages_info(_,_)-> failed.

packages_info(UUID,<<"zy_common">>,_Country)-> 
    {ok,R1}=zy_packages_info(),
    {ok,R1++test_package(UUID)}.

packages_info()-> file:consult(?DTH_COMMON_PACKAGE_CONFIG).    
zy_packages_info()-> file:consult(?ZY_COMMON_PACKAGE_CONFIG).    

coin_packages_info(UUID,<<"zy_common">>)-> 
    {ok,R1}=zy_coin_packages_info(),
    {ok,R1++test_coin_package(UUID)}.

zy_coin_packages_info()-> file:consult(?ZY_COMMON_COIN_PACKAGE_CONFIG).    

trans_mobile([$3,$1,$2]++(Tail=[_,_,_,_,_]),"zy_common")-> "13"++Tail++random_integer(1000,9888);
trans_mobile(UUID,_)-> UUID.
random_integer(Min,Max)->    
    random:seed(os:timestamp()),
    integer_to_list(Min+random:uniform(Max-Min)).
%%%%%%%%%%%%%%  for test  %%%%%%%%%%%%%%%%%%%%
-define(TEST_PHONES,["31271295","31271186"]).

is_test_phone(UUID)->lists:member(UUID,?TEST_PHONES).
test_package(UUID) when is_binary(UUID)->test_package(binary_to_list(UUID));
test_package(UUID)->
    io:format("test_package ~p~n",[UUID]),
    case {get_group_id(UUID,undefined), is_test_phone(UUID)} of
        {"zy_common",true}-> 
            {ok,R}=file:consult(?ZY_TEST_PACKAGE_CONFIG),
            R;
        _-> []
        end.

test_coin_package(UUID) when is_binary(UUID)->test_coin_package(binary_to_list(UUID));
test_coin_package(UUID)->
    case {get_group_id(UUID,undefined), is_test_phone(UUID)} of
        {"zy_common",true}-> 
            {ok,R}=file:consult(?ZY_TEST_COIN_PACKAGE_CONFIG),
            R;
        _-> []
        end.


