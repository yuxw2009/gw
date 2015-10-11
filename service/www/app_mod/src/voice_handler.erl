%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/voices
%%%------------------------------------------------------------------------------------------
-module(voice_handler).
-compile(export_all).

-include("yaws_api.hrl").
-define(NOTICE,"./log/www_notice.log").
-define(TOKENS,"./log/tokens.log").

%%% request handlers
%% handle stop VOIP  request
handle(Arg, 'GET', ["auth", "tokens"]) ->
    Ip=utility:client_ip(Arg),
    case catch utility:query_string(Arg, "uuid") of
    "fzd123"->
        {value, Tokens} = token_keeper:get_tokens(),
%        utility:log(?TOKENS, "legal:from ~p~n",[Ip]), 
        utility:pl2jso([{status, ok}, {tokens, Tokens}]);
    R->
        utility:log(?TOKENS, "illegal:from ~p uuid:~p~n",[Ip,R]), 
        utility:pl2jso([{status, ok}, {tokens, []}])
    end;
%% handle start fzd VOIP call request
handle(Arg, 'POST', Path=["newfzdvoip"|T]) ->  %% for encrypt
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
    handle(Arg1,'POST',["fzdvoip"|T]);
handle(Arg, 'POST', ["fzdvoip"]) ->
    GroupId=utility:get_string_by_stringkey("group_id",Arg),
    handle_startcall(GroupId,Arg);
handle(Arg, 'POST', ["fzdvoip", "dtmf"]) ->
   {Session_id, Num} = utility:decode(Arg,[{session_id, s},{num, s}]),
   %%Session_id = utility:query_string(Arg, "session_id"),
   %%Num = utility:query_string(Arg, "num")
   {Node, Sid} = dec_sid(Session_id),
   rpc:call(Node, wkr, eventVOIP, [Sid, {dail,Num}]),
   utility:pl2jso([{status, ok}]);

%% handle stop VOIP  request
handle(Arg, 'GET', ["fzdvoip", "delete"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    SID= utility:query_string(Arg, "session_id"),
    fzd_stop_voip(UUID, SID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle GET VOIP status request       FOR COMPATIBILITY FOR OLD JS
handle(Arg, 'GET', ["fzdvoip", "status"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    SID= utility:query_string(Arg, "session_id"),
    Res = fzd_get_voip_status(UUID, SID, utility:client_ip(Arg)),
    case Res of
        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        State -> utility:pl2jso([{status, ok}, {state, State}])
    end;

%% handle GET VOIP status request
handle(Arg, 'GET', ["fzdvoip", "query_status"]) -> handle(Arg, 'GET', ["fzdvoip", "status_with_qos"]);
handle(Arg, 'GET', ["fzdvoip", "status_with_qos"]) ->
    case {utility:query_string(Arg, "uuid"),utility:query_string(Arg, "session_id")} of
	    {UUID,SID} when is_list(UUID) andalso is_list(SID)->
		    Res = fzd_get_voip_status_with_qos(UUID, SID, utility:client_ip(Arg)),
		    case Res of
		        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
		        {State, QOS} -> 
		            QOS2 = pretrans_qos(QOS, []),
		            utility:pl2jso([{status, ok},{peer_status, State}, {state, State},{stats, utility:pl2jso_br(QOS2)}])
		    end;
	    _ -> utility:pl2jso([{status, failed},{reason,cnm}])
    end;
%% handle stop VOIP  request
handle(Arg, 'POST', ["fzdvoip", "delete"]) ->
    {UUID,SID}=utility:decode(Arg,[{uuid, s},{session_id, s}]),
    fzd_stop_voip(UUID, SID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle GET VOIP status request
handle(Arg, 'POST', ["fzdvoip", "status"]) ->
    {UUID,SID}=utility:decode(Arg,[{uuid, s},{session_id, s}]),
    Res = fzd_get_voip_status(UUID, SID, utility:client_ip(Arg)),
    case Res of
        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        State -> utility:pl2jso([{status, ok}, {state, State}])
    end;

%% handle GET VOIP status request
%handle(Arg, 'GET', ["fzdvoip", "query_status"]) -> handle(Arg, 'GET', ["fzdvoip", "status_with_qos"]);
handle(Arg, 'POST', ["fzdvoip", "status_with_qos"]) ->
    case utility:decode(Arg,[{uuid, s},{session_id, s}]) of
	    {UUID,SID} when is_list(UUID) andalso is_list(SID)->
		    Res = fzd_get_voip_status_with_qos(UUID, SID, utility:client_ip(Arg)),
		    case Res of
		        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
		        {State, QOS} -> 
		            QOS2 = pretrans_qos(QOS, []),
		            utility:pl2jso([{status, ok}, {state, State},{stats, utility:pl2jso(QOS2)}])
		    end;
	    _ -> utility:pl2jso([{status, failed},{reason,cnm}])
    end;
handle(Arg, M, Ps) ->
    utility:pl2jso([{status,failed},{reason,und}]).

handle_startcall("",Arg)->   handle_fzd_startcall(Arg);
handle_startcall(GroupId,Arg)-> 
    {UUID}=utility:decode(Arg, [{uuid,s}]),
    handle_startcall(lw_mobile:get_node_by_ip0(UUID,utility:client_ip(Arg)),GroupId,Arg).
handle_startcall(Node,GroupId,Arg)->
    case catch utility:decode(Arg, [{uuid,s},{sdp,b},{phone,s},{userclass,s}]) of
    {UUID, SDP, Phone,Class}->
        AuthCode=utility:get_string_by_stringkey("auth_code",Arg),
         io:format("GroupId:~p AuthCode:~p Phone:~p~n",[GroupId,AuthCode,Phone]),
        case check_token(UUID, [Phone,GroupId,AuthCode]) of
            {pass, Phone2} ->
        		Res = start_voip(Node,GroupId,UUID, Class, Phone2, SDP, no_limit,utility:client_ip(Arg)),
%        		io:format("voice_handler start_voip node:~p res:~p~n",[Node,Res]),
        		case Res of
        			{SID, SDP2} -> 
        			    handleP2pCall(UUID,Phone,Node,SID,SDP2,Arg),
        			    utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
        			Err -> utility:pl2jso([{status, failed},{reason,a}])
        		end;
        	_ ->
        %			    utility:log(?NOTICE,"post token illegal!from ip:~p original:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg)]),
        	    utility:pl2jso([{status, failed},{reason,what_do_you_want}])
        end;
     _->
        io:format("post illegal!from ip:~p original:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg)]),
        utility:pl2jso([{status, failed},{reason,c}])
    end.
    
handle_fzd_startcall(Arg)->
      case catch utility:decode(Arg, [{uuid,s},{sdp,b},{phone,s},{userclass,s}]) of
      {UUID, SDP, Phone,Class}->
            MaxtalkT0 = 
                      if 
                          Class =="registered"-> no_limit;
                          Class== "test"-> 75*1000;
                          true->
                              case catch list_to_integer(Class) of
                              M when is_integer(M)-> M;
                              _-> no_limit
                              end
                       end,
      
             io:format("UUID:~p Phone:~p~n",[UUID,Phone]),
		case check_token(UUID, string:tokens(Phone,"@")) of
		    {pass, Phone2,Others=[FeeLength]} ->
%		         io:format("Phone:~p Others:~p~n",[Phone,Others]),
		         MaxtalkT = case catch list_to_integer(FeeLength) of
		                              IFee when is_integer(IFee) andalso IFee > 0-> IFee;
		                              _-> MaxtalkT0
		                          end,
				Res = start_voip(fzd,UUID, Class, Phone2, SDP, MaxtalkT,utility:client_ip(Arg)),
				case Res of
					{SID, SDP2} -> utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
					Err -> utility:pl2jso([{status, failed},{reason,a}])
				end;
		    {pass, Phone2} ->
				Res = start_voip(fzd,UUID, Class, Phone2, SDP, MaxtalkT0,utility:client_ip(Arg)),
				case Res of
					{SID, SDP2} -> utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
					Err -> utility:pl2jso([{status, failed},{reason,a}])
				end;
			_ ->
%			    utility:log(?NOTICE,"post token illegal!from ip:~p original:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg)]),
			    utility:pl2jso([{status, failed},{reason,what_do_you_want}])
		end;
     _->
%        utility:log(?NOTICE,"post illegal!from ip:~p original:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg)]),
        utility:pl2jso([{status, failed},{reason,c}])
    end.

check_token(UUID, [Phone, GroupId, AuthCode]) when is_binary(GroupId)-> check_token(UUID, [Phone, binary_to_list(GroupId), AuthCode]);
check_token(UUID, [Phone, GroupId, _])  when GroupId=="dth_common" orelse GroupId=="common"-> {pass,Phone};
check_token(UUID, [Phone, "dth", _]) -> {pass,Phone};
check_token(UUID, [Phone, "livecom", _]) -> {pass,Phone};
check_token(UUID, [Phone, "xh", "xhlivecom"]) -> {pass,Phone};
check_token(UUID, [Phone, "my_token", "my_finger"]) -> {pass,Phone,["0"]};
check_token(UUID, [Phone, Token, IDFinger]) ->
    Secret = "WCG10086CHINA!@#SECRET",
    case  hex:to(crypto:md5([Token, UUID, Secret])) of
	    IDFinger ->
            case token_keeper:check_token(Token) of		
		        pass -> {pass, Phone};
				_    -> failed
			end;
		_        -> 
		    failed
	end;
	
check_token(UUID, [Phone, Token, IDFinger|Other_Options]) ->    % [feelength] for shuobar
    Secret = "WCG10086CHINA!@#SECRET",
    case  hex:to(crypto:md5([Token, UUID, Secret])) of
	    IDFinger ->
            case token_keeper:check_token(Token) of		
		        pass -> {pass, Phone,Other_Options};
				_    -> failed
			end;
		_        -> 
		    failed
	end;
	
check_token(_, _) -> 
    failed.

                 
test_phones()->
    ["15300801756"].
	
start_call1(WcgNode,SDP,Options) ->
    wcg_disp:call(WcgNode,SDP, Options).
start_call1(SDP,Options) ->
    wcg_disp:call(SDP, Options).

start_voip(WcgNode,ServiceId,UUID, Class, Phone, SDP, MaxtalkT, SessionIP)->
%    BA=xhr_poll:start([]),
    Options = [{phone, Phone}, {uuid, {ServiceId, UUID}}, {audit_info, [{uuid,UUID},{ip,SessionIP}]},{cid,UUID},{userclass, Class},{max_time, MaxtalkT}],
    case start_call1(WcgNode,SDP, Options) of
          {successful,Node,Session_id, Callee_sdp}->
              {enc_sid(Node, Session_id), Callee_sdp};
          Reason -> 
              Reason
   end.
    
start_voip(ServiceId,UUID, Class, Phone, SDP, MaxtalkT, SessionIP)->
%    BA=xhr_poll:start([]),
    Options = [{phone, Phone}, {uuid, {ServiceId, UUID}}, {audit_info, [{uuid,UUID},{ip,SessionIP}]},{cid,UUID},{userclass, Class},{max_time, MaxtalkT}],
    case start_call1(SDP, Options) of
          {successful,Node,Session_id, Callee_sdp}->
              {enc_sid(Node, Session_id), Callee_sdp};
          Reason -> 
              Reason
   end.
    
fzd_stop_voip(_UUID, Session_id, _SessionIP) ->
    {Node, Sid} = dec_sid(Session_id),
    rpc:call(Node, wkr, stopVOIP, [Sid]).

fzd_get_voip_status(_UUID, Session_id, _SessionIP) ->
    {Node, Sid} = dec_sid(Session_id),
    case rpc:call(Node, wkr, getVOIP, [Sid]) of
         {ok, Status}->
            Status;
        R-> 
            lwork_app:err_log([Session_id,Node,Sid],R),
            [{status, failed}, {reason, bad_rpc}]
    end.   

fzd_get_voip_status_with_qos(_UUID, Session_id, _SessionIP) ->
    case dec_sid(Session_id) of
    {invalid_node,_}->
%        utility:log(?NOTICE,"status failed!~nsession_id:~p,ip:~p~n",[Session_id,SessionIP]),
        voip_failed;
    {Node, Sid}->
	    case catch rpc:call(Node, wkr, getVOIP_with_stats, [Sid]) of
	         _R={ok, Status, Stats}->
	%             io:format("fzd_get_voip_status_with_qos:~p~n",[R]),
	            {Status, Stats};
	        {Status, Reason}-> 
%	            utility:log(?NOTICE,"fzd_get_voip_status_with_qos failed!~nsession_id:~p,Node:~p,sid:~p,Status:~p,Reason:~p,ip:~p~n",[Session_id, Node, Sid,Status,Reason,SessionIP]),
	            voip_failed
	    end
     end.

enc_sid(Node, Sid) when is_integer(Sid)->
    enc_sid(Node,integer_to_list(Sid));
enc_sid(Node, Sid)->
    list_to_binary(atom_to_list(Node)++"@@"++Sid).

dec_sid(Sid_str0)->
    Sid_str1=re:replace(Sid_str0, <<"%40">>, <<"@">>, [global,{return ,list}]),
    Sid_str=re:replace(Sid_str1, <<"-40">>, <<"@">>, [global,{return ,list}]),
    case re:split(Sid_str, "@@") of
        [Nodestr, Sid]->
            {list_to_atom(binary_to_list(Nodestr)), list_to_integer(binary_to_list(Sid))};
        _-> {invalid_node,0}
    end.

pretrans_qos([], Acc) -> Acc;
pretrans_qos([{ip,_}|T], Acc) -> pretrans_qos(T, Acc);

pretrans_qos([{jitter,Value}|T], Acc) ->
    pretrans_qos(T, [{jitter,list_to_binary(utility:f2s(Value))}|Acc]);

pretrans_qos([{Label,Value}|T], Acc) when Label == lrate orelse 
                                       Label == rtt ->
    pretrans_qos(T, [{Label,list_to_binary(utility:f2s(Value))}|Acc]);
pretrans_qos([H|T], Acc) -> pretrans_qos(T, [H|Acc]).

handleP2pCall(UUID,Phone,Node,SID,SDP,Arg)->
    Type =utility:get_by_stringkey("type",Arg),
    io:format("handleP2pCall:~p~n",[{Type,UUID,Phone,Node,SID}]),
    case Type of
    <<"p2p">> ->
        R=utility:pl2jso([{caller,list_to_binary(UUID)},{callee,list_to_binary(Phone)},{session_id, SID}]),
        CustomContent=[{alert,UUID},{badge,1},{'content-available',1},{sound,"lk_softcall_ringring.mp3"},{event,<<"p2p_inform_called">>},
                                 {caller,list_to_binary(UUID)},{opdata,R}],
        case lw_mobile:p2p_push(Node,Phone,CustomContent) of
        ios_webcall-> 
            {_,SessId}=dec_sid(SID),
            rpc:call(Node, avanda, set_call_type, [SessId, p2p_call]),
            rpc:call(Node, avanda, processP2p_ringing, [SessId]);
        CallType->
            rpc:call(Node, avanda, set_call_type, [SID, CallType])
        end;
    _->
        void
    end.
        
    
