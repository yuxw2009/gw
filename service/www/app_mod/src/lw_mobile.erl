%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(lw_mobile).
-compile(export_all).
-include("yaws_api.hrl").
-include("lwdb.hrl").
-define(CALL,"./log/call.log").
-define(VERSION_INFO, "./docroot/version/version.info").
-define(VERSION_DTH_INFO, "./docroot/version/version_dth.info").
-define(VERSION_COMMON_INFO, "./docroot/version/version_common.info").

%% handle start callback call request
handle(Arg,'POST', ["register"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res=
    case utility:get_string(Json, "group_id") of
    "common"->    lw_register:sms_register(Json);
    "dth"-> lw_register:delegate_register(Json)
    end,
    io:format("register:req:~p ack:~p~n",[Json,Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["add_info"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res= lw_register:add_info(Json),
    utility:pl2jso(Res);
handle(Arg,'POST', ["forget_pwd"])->
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    Res= lw_register:forgetpwd(Json),
    utility:pl2jso(Res);
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
handle(Arg,'POST', ["login"])->
    IP = utility:client_ip(Arg),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Res=login_processor:login([{"ip",IP}|Params]),
    io:format("logined  res:~p~n",[Res]),
    Res;
handle(Arg,'POST', ["logout"])->
    IP = utility:client_ip(Arg),
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    R=login_processor:logout([{"ip",IP}|Params]),
    R;
handle(Arg,'POST', ["get_payid"])->
    utility:log("get_payid clidata:~p~n",[Arg#arg.clidata]),
    {ok, Json,_}=rfc4627:decode(Arg#arg.clidata),
    io:format("get_payid:req:~p~n",[Json]),
    Res=pay:gen_payment(Json),
    io:format("get_payid:ack:~p~n",[Res]),
    utility:pl2jso_br(Res);
handle(Arg,'POST', ["get_coin"])->
    {UUID}= utility:decode(Arg, [{uuid, s}]),
    Res=lw_register:get_coin(UUID),
    io:format("get_coin:ack:~p~n",[Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["get_recharges"])->
    {UUID}= utility:decode(Arg, [{uuid, s}]),
    Res=lw_register:get_recharges(UUID),
    io:format("get_recharges:ack:~p~n",[Res]),
    utility:pl2jso(Res);
handle(Arg,'POST', ["query_status"])->
    IP = utility:client_ip(Arg),
    {AccPhonePairs}= utility:decode(Arg, [{users, ao,[{acc,s},{phone,s}]}]),
%    io:format("query_status:~p~n",[AccPhonePairs]),
    F = fun(Phone)->
             case {login_processor:get_account_tuple(Phone),login_processor:get_poll_pid(Phone)} of
             {_,Pid2} when is_pid(Pid2)-> online;
             {undefined,_} -> unregistered;
             {_,_}-> offline
          end end,
    Data=[utility:pl2jso_br([{acc,A},{phone,P},{state,F(P)}])||{A,P}<-AccPhonePairs],
    utility:pl2jso([{status,ok},{data,Data}]);
handle(Arg,Meth, Url=["p2p_"++_])->
    {{obj, Clidatas}}= utility:decode(Arg, [{opdata,r}]),
    Evt = proplists:get_value("event",Clidatas),
    io:format("lw_mobile p2pmsg:~p~n",[Url]),
    handle_tp_call_msg(Arg,Meth,Url,Evt);
handle(Arg,'POST', ["login1"])->
    IP = utility:client_ip(Arg),
    {UUID,Pwd, {obj, Clidatas}}= utility:decode(Arg, [{uuid, s}, {pwd, s}, {clidata,o}]),
    R=login_processor:login(UUID,IP,Pwd,Clidatas),
    io:format("login:~p res:~p~n",[UUID,R]),
    R;
handle(Arg, 'POST', ["voip", "calls"]) ->
    _IP = utility:client_ip(Arg),
    {UUID_SNO,Callee}= utility:decode(Arg, [{user_id, s},{callee_phone, s}]),
    case login_processor:autheticated(UUID_SNO,Callee) of
    [{status,ok},{uuid,UUID}]-> start_call0(UUID, Arg);
    R->
         utility:pl2jso(R)
    end;
handle(Arg, 'DELETE', [ "voip", "calls"]) ->
    SessionID = utility:query_string(Arg, "session_id"),
    {Node, Sid} = voice_handler:dec_sid(SessionID),
    rpc:call(Node, avanda, stopNATIVE, [Sid]),
%     io:format("lw_mobile: stop~n~p~n", [Sid]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'GET', ["version_no"]) ->
    case file:consult(?VERSION_INFO) of
    {ok,Info}-> utility:pl2jso_br([{status,ok}|Info]);
    _-> utility:pl2jso_br([{status,failed}])
    end;
handle(Arg, 'GET', ["version_dth_no"]) ->
    case file:consult(?VERSION_DTH_INFO) of
    {ok,Info}-> utility:pl2jso_br([{status,ok}|Info]);
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
                            [{status, ok}, {peer_status, Status},{stats,utility:pl2jso_br(Stats)}];
                         {badrpc, Reason}-> 
                             [{status, failed}, {reason, Reason}];
                        {failed, Reason}-> [{status, failed}, {reason, Reason}]
                    end
                end,
%     io:format("lw_mobile: get ~p~n~p~n", [SessionID,Result]),
    utility:pl2jso_br(Result);

handle(Arg, Method, ["paytest"|Params]) ->
    pay:handle(Arg,Method,Params);
handle(Arg, 'POST', ["voip", "dtmf"]) ->
   {Session_id, Num} = utility:decode(Arg,[{session_id, s},{num, s}]),
   %%Session_id = utility:query_string(Arg, "session_id"),
   %%Num = utility:query_string(Arg, "num")
   {Node, Sid} = voice_handler:dec_sid(Session_id),
   rpc:call(Node, wkr, eventVOIP, [Sid, {dail,Num}]),
   utility:pl2jso([{status, ok}]);
   
%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    [{status,405}].

handle_tp_call_msg(Arg,Meth, Params,<<"sip_call_in">>)->
    {Opdata={obj,_}}= utility:decode(Arg, [{opdata,r}]),
    sip_tp_call_handle(Arg,Meth,Params,Opdata);
    
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
    io:format("p2p_poll sid_str:~p~n", [SessionID]),
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
handle_tp_call_msg(Arg,'POST', ["p2p_answer"],_)->
    {{Sid_str},Clidata,UUID,Phone,{Port}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]},{clidata,r},{caller_phone,s},{callee_phone,s},{sdp, o, [{port, i}]}]),
    IP = utility:client_ip(Arg),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    utility:log(?CALL, "p2p_answer:~s=>~s ~s ~s clidata: ~p",[UUID,Phone,utility:make_ip_str(utility:client_ip(Arg)),atom_to_list(Node),Clidata]),
    
    case rpc:call(Node, avanda, processP2p_answer, [Sid,{IP, Port}]) of
    {successful,SessionID,{PeerIP,PeerPort}, Other}->
        utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, {port, PeerPort}|Other]);
    {failed,Reason}->
        utility:pl2jso([{status,failed}, {reason, Reason}])
    end;
handle_tp_call_msg(Arg,'POST', ["p2p_reject"],_)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
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
sip_tp_call_handle(Arg,'POST', ["p2p_reject"],Clidata)->
    {{Sid_str}}= utility:decode(Arg, [{opdata, o, [{session_id,s}]}]),
    {Node, Sid}=voice_handler:dec_sid(Sid_str),
    rpc:call(Node, avanda, stopNATIVE, [Sid]),
    utility:pl2jso([{status,ok}]);
sip_tp_call_handle(_Arg,'POST', _,_Clidata)->
    utility:pl2jso([{status,failed},{reason,sip_tp_call_unhandled}]).

push(Phone1,Content)->
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
        case get_node_by_ip0(Phone,CalleeIp) of
        CallerNode->  push(Phone,Content);
        _-> real_call
        end
    end.

get_maxtalkt(Arg)->
   case utility:get_by_stringkey("userclass",Arg) of
   Class when Class == <<"registered">> orelse Class == <<"game">> ->  no_limit;
   _-> 75*1000
   end.
%get_group_id(Arg)->   
%    case utility:get_by_stringkey("group_id",Arg) of
%    <<"">> ->binary_to_list(utility:get_by_stringkey("groupid",Arg));
%    GroupIdBin-> binary_to_list(GroupIdBin)
%    end.
get_group_id(UUID,_Arg)->     %from login_info
    login_processor:get_group_id(UUID).
build_call_options(UUID, Arg)->
    { _CallerPhone, Phone, {IPs=[SessionIP|_], Port, Codec}, Class} = utility:decode(Arg, [{caller_phone, s}, {callee_phone, s},
	                                   {sdp, o, [{ip, as}, {port, i}, {codec, s}]}, {userclass, s}]),
    {MaxtalkT0,ServiceId} = {get_maxtalkt(Arg),get_group_id(UUID,Arg)},
    Node=node(),
    Fun = fun(Charges)->
                 io:format("sadfasfdasfdasfdasf~n"),
                 lw_register:consume_coins(UUID,Charges)
             end,
    Options0=[{uuid, {ServiceId, UUID}}, {audit_info, [{uuid,UUID},{ip,SessionIP}]},{cid,UUID},{userclass, Class},{codec,Codec},
                     {callback,{node(),lw_register,consume_coins,UUID}}],
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
      Node =get_node_by_ip0(UUID,utility:client_ip(Arg)),
	io:format("-"),
	Ip=utility:client_ip(Arg),
	utility:log(?CALL, "~s=>~s ~s ~s clidata:~p",[UUID,Phone,utility:make_ip_str(Ip),atom_to_list(Node),utility:get_by_stringkey("clidata",Arg)]),
	Options = build_call_options(UUID,Arg),
      if length(Phone) < 3 ->  utility:pl2jso([{status, failed},{reason,phone_too_short}]);
      true->
%            io:format("start_call req:~p~noptions:~p~n",[Arg#arg.clidata, Options]),
        	case rpc:call(Node, avanda, processNATIVE, [IPs, Port, Options]) of
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
                      CustomContent=[{event,<<"p2p_inform_called">>},{caller,list_to_binary(Cid)},{opdata,R}],
                      CallType= 
                          case utility:get_by_stringkey("type",Arg) of
                          <<"p2p">> -> XgAct(Node,Callee,CustomContent);
                          _-> real_call  
                          end,
        	         rpc:call(Node, avanda, set_call_type, [SessionID, CallType]),
        	         utility:pl2jso([{status, ok},{session_id, voice_handler:enc_sid(Node, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort},{codec, 102}|Other]);
        	    {_, nodedown}-> utility:pl2jso([{status, failed},{reason,nodedown}]);
        	    {failed, Reason}-> utility:pl2jso([{status, failed},{reason,Reason}])
        	end
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

get_node_by_ip0(UUID,Ip)-> 
    R=get_node_by_ip(UUID,Ip),
    io:format("uuid:~p Ip:~p choose node:~p~n",[UUID,Ip,R]),
    R.
    

get_internal_node_by_ip(UUID,Ip)-> 
    wwwcfg:get_internal_wcgnode(utility:c2s(utility:country(Ip))).
%get_node_by_ip(_luyin_test="13788927293",_Ip)-> 'gw@119.29.62.190';
%get_node_by_ip(_luyin_test="008618017813673",_Ip)-> 'gw@119.29.62.190';
get_node_by_ip(_Fztest="00862180246198",_Ip)-> wwwcfg:get_wcgnode("Africa");
get_node_by_ip(UUID="3000"++_,Ip)-> get_internal_node_by_ip(UUID,Ip);
get_node_by_ip(UUID="00862180246"++_,Ip)-> get_internal_node_by_ip(UUID,Ip);
get_node_by_ip(UUID,Ip)->
    R0= wwwcfg:get_wcgnode(utility:c2s(utility:country(Ip))),
    case lists:member(R0,nodes()) of
    true-> R0;
    _-> wwwcfg:get_wcgnode(default)
    end.
    
start_callback(UUID={_,UserId}, LocalPhone, Phone, SessionIP) ->    % remove fzd
    case login_processor:autheticated(UserId,Phone) of
    [{status,ok},{uuid,_}]-> 
        do_callback1(UUID,LocalPhone,Phone,no_limit);
    R->
         utility:pl2jso(R)
    end.

do_callback1(_UUID={Groupid,Uuid},LocalPhone,Remote_phone,MaxtalkTime)->
    {_A,B,_C}=erlang:now(),
    io:format("do_callback1,~p~n",[[{Groupid,Uuid++"@"++integer_to_list(B)}, fake_auditinfo,  {"", LocalPhone, 0.1}, {"", Remote_phone, 0.1}, MaxtalkTime]]),
    
    case rpc:call(wwwcfg:get(voice_node), lw_voice, start_callback, 
                 [{Groupid,Uuid++"@"++integer_to_list(B)}, [{groupid,fake_auditinfo},{caller,{"", LocalPhone, 0.1}},
                 {callee,{"", Remote_phone, 0.1}},{max_time,MaxtalkTime},{callback,{node(),lw_register,consume_coins,Uuid}}]]) of
      ok->
          %io:format("start callback! session_id:~p~n", [Session_id]),
          [{status, ok}, {session_id, 0}];
      {failed, session_already_exist}-> [{status, failed}, {reason,session_already_exist}]
    end.

do_callback(_UUID={Groupid,Uuid},LocalPhone,Remote_phone,MaxtalkTime)->
    {_A,B,_C}=erlang:now(),
    io:format("rpc:call(wwwcfg:get(voice_node), lw_voice, start_callback,~p~n",[[{Groupid,Uuid++"@"++integer_to_list(B)}, fake_auditinfo,  {"", LocalPhone, 0.1}, {"", Remote_phone, 0.1}, MaxtalkTime]]),
    case rpc:call(wwwcfg:get(voice_node), lw_voice, start_callback, 
                 [{Groupid,Uuid++"@"++integer_to_list(B)}, fake_auditinfo,  {"", LocalPhone, 0.1}, {"", Remote_phone, 0.1}, MaxtalkTime]) of
      ok->
          %io:format("start callback! session_id:~p~n", [Session_id]),
          [{status, ok}, {session_id, 0}];
      {failed, session_already_exist}-> [{status, failed}, {reason,session_already_exist}]
    end.

sip_p2p_tp_call(Caller,Callee,SipSdp,SipPid)->
    io:format("Callee:~p~n",[{Callee,login_processor:get_ip_tuple(Callee)}]),
    case login_processor:get_ip_tuple(Callee) of
    undefined->  {failed, callee_not_exist};
    Ip ->  
        WcgNode=get_internal_node_by_ip(Callee,Ip),
        io:format("sip_p2p_tp_call Callee:~p Ip:~p choose node:~p Caller:~p~n",[Callee,Ip,WcgNode,Caller]),
        case rpc:call(WcgNode, avanda, processSipP2pCall, [[{ss_sdp,SipSdp},{voip_ua,SipPid},{callee,Callee},{cid,Caller},{phone,Callee}]]) of
        {successful,SessionID,{PeerIP,PeerPort},Other}->
            io:format("www sip_p2p_tp_call rpc ok"),
            R=utility:pl2jso([{event,<<"sip_call_in">>},{caller,list_to_binary(Caller)},{callee,list_to_binary(Callee)},{session_id, voice_handler:enc_sid(WcgNode, SessionID)}, {ip, list_to_binary(PeerIP)}, 
        	                              {port, PeerPort}|Other]),
            CustomContent=[{event,<<"p2p_inform_called">>},{caller,list_to_binary(Caller)},{opdata,R}],
            CallType=push(Callee,CustomContent),
            if CallType == real_call-> send_unavailable_to_wcgnode;
               true-> ok
            end;
        {failed, Reason}-> {failed,Reason}
        end
    end.

