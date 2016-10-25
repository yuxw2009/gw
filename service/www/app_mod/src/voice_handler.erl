%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/voices
%%%------------------------------------------------------------------------------------------
-module(voice_handler).
-compile(export_all).

-include("yaws_api.hrl").
-define(NOTICE,"./log/www_notice.log").
-define(TOKENS,"./log/tokens.log").
-define(WWW_VOICE,'www_voice@10.32.3.52').

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

%% handle start meeting request
handle(Arg, 'POST', ["meetings"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),	
    UUID = utility:get_string(Json, "uuid"),
%    Group = utility:get_binary(Json, "group_id"),
    Group = login_processor:get_group_id(UUID),
    io:format("meeting UUID ~p Group: ~p~n",[UUID,Group]),
    Subject = utility:get_binary(Json, "subject"),
    MObjs = utility:get(Json, "members"),
    Members = [{utility:get_binary(Obj, "name"), utility:get_string(Obj, "phone")}  || Obj <- MObjs],
    %%Members = [{"dhui","008615300801756"}],
    case start_meeting(Group,UUID,Members) of
        {value,MeetingId, Details} ->
%           io:format("voice_handler meetings details:~p~n",[Details]),
           utility:pl2jso([{status, ok}, 
    	            {meeting_id, list_to_binary(MeetingId)},
    	            {details, utility:a2jsos([member_id, 
    	            	                      status, 
    	            	                      name, 
    	            	                      {phone, fun erlang:list_to_binary/1}],
    	            	                     Details)}]);
        {value,Reason}      -> utility:pl2jso([{status, failed},{reason,Reason}])
    end;
%% handle stop meeting request
handle(Arg, 'GET', ["meetings", MeetingId,"delete"]) -> handle(Arg, 'DELETE', ["meetings", MeetingId]);
handle(Arg, 'DELETE', ["meetings", MeetingId]) ->
    UUID = utility:query_string(Arg, "uuid"),
    Group = login_processor:get_group_id(UUID),
    ok = rpc:call(?WWW_VOICE, www_voice_handler, stop_meeting, [Group,UUID,MeetingId]),
    utility:pl2jso([{status, ok}]);
%% handle get active meeting info request
handle(Arg, 'GET', ["meetings"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    Group = login_processor:get_group_id(UUID),
    {value, ActiveMeetings} = rpc:call(?WWW_VOICE, www_voice_handler, get_meeting, [Group,UUID,undefined]),
    utility:pl2jso([{status, ok}, 
    	            {meetings, utility:a2jsos([{meeting_id, fun erlang:list_to_binary/1},
    	            	                       {details, fun(V) ->  
    	            	                                     utility:a2jsos([member_id, status, 
    	            	                                     	            name,
    	            	                                     	            {phone, fun erlang:list_to_binary/1}], V) 
    	            	                                 end},
    	            	                        meeting_status
    	            	                      ],
    	            	                      ActiveMeetings)}]);
%% handle get active meeting member status request
handle(Arg, 'GET', ["meetings", MeetingId, "status"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    Group = login_processor:get_group_id(UUID),
    Members=
    case rpc:call(?WWW_VOICE, www_voice_handler, get_meeting, [Group,UUID,MeetingId]) of
        {value,[{_MeetingId, AM,ongoing}|_]}  ->    [{MemberId, Status} || {MemberId, Status, _, _}<- AM];
        Other ->         
            io:format("meeting other:~p ~n", [Other]),
            []
    end,
    utility:pl2jso([{status, ok},
    	            {members, utility:a2jsos([member_id, status], Members)}
    	            ]);
%% handle add new member request
handle(Arg, 'POST', ["meetings",MeetingId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),		
    UUID = utility:get_string(Json, "uuid"),
    Group = login_processor:get_group_id(UUID),
    Name = utility:get_binary(Json,"name"),
    Phone = utility:get_string(Json,"phone"),
    {value,MemberInfo} = rpc:call(?WWW_VOICE, www_voice_handler, join_meeing_member, [Group, UUID,MeetingId,Name,Phone ]),
    io:format("post members:~p~n",[MemberInfo]),
    utility:pl2jso([{status, ok},
    	            {new_member, utility:a2jso([member_id, status, 
    	            	                         name, 
    	            	                         {phone, fun erlang:list_to_binary/1}
    	            	                        ], 
    	            	                        MemberInfo)}
    	            ]);
%% handle redial or hangup a member request
handle(Arg, 'POST', ["meetings",MeetingId, "members", MemberId0]) ->
    MemberId=list_to_integer(MemberId0),
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_string(Json, "uuid"),
    Status= utility:get_atom(Json,"status"),
    Group = login_processor:get_group_id(UUID),
    rpc:call(?WWW_VOICE, www_voice_handler, modify_meeting_members, [Group, UUID,MeetingId,MemberId,Status ]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'GET', ["meetings", "cdrs"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    Group = login_processor:get_group_id(UUID),
    Year = utility:query_integer(Arg, "year"),
    Month = utility:query_integer(Arg, "month"),
    {value,History} = rpc:call(?WWW_VOICE, www_voice_handler, get_meeting_history, [Group,UUID,Year,Month]),
    
%    io:format("get_meeting_history: ~p~n", [History]),
    R=utility:pl2jso([{status, ok}, {details, utility:a2jsos([meeting_id,subject,
                                                            {timestamp, fun(Date)->list_to_binary(utility:d2s(Date)) end},status,
                                                            {members, fun(Ms) ->
                                                                          utility:a2jsos([seq,name,{phone, fun erlang:list_to_binary/1}], Ms)

                                                                      end
                                                            }],
                                              History)}]),
    %io:format("voice_handler:meetings cdrs:~p~n",[R]),
    R;

handle(Arg, M, Ps) ->
    utility:pl2jso([{status,failed},{reason,und}]).

handle_startcall(GroupId,Arg)-> 
    {UUID}=utility:decode(Arg, [{uuid,s}]),
    handle_startcall(lw_mobile:get_node_by_ip0(UUID,utility:client_ip(Arg)),GroupId,Arg).
handle_startcall_nocheck_token(Node,GroupId,Arg)->
    case catch utility:decode(Arg, [{uuid,s},{sdp,b},{phone,s},{userclass,s}]) of
    {UUID0, SDP, Phone,Class}->
        UUID=login_processor:filter_phone(UUID0),
        Res = start_voip(Node,GroupId,UUID, Class, Phone, SDP, no_limit,Arg),
        case Res of
            {SID, SDP2} -> 
                handleP2pCall(UUID,Phone,Node,SID,SDP2,Arg),
                utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
            Err -> utility:pl2jso([{status, failed},{reason,a}])
        end;
     Excep->
        io:format("post illegal!from ip:~p original:~p~nExcp:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg),Arg#arg.clidata]),
        utility:pl2jso([{status, failed},{reason,c}])
    end.
handle_startcall(Node,GroupId,Arg)->
    case catch utility:decode(Arg, [{uuid,s},{sdp,b},{phone,s},{userclass,s}]) of
    {UUID0, SDP, Phone,Class}->
        UUID=login_processor:filter_phone(UUID0),
        AuthCode=utility:get_string_by_stringkey("auth_code",Arg),
         io:format("uuid:~pGroupId:~p AuthCode:~p Phone:~p~n",[UUID,GroupId,AuthCode,Phone]),
        case check_token(UUID, [Phone,GroupId,AuthCode]) of
            {pass, Phone2} ->
                Res = start_voip(Node,GroupId,UUID, Class, Phone2, SDP, no_limit,Arg),
                case Res of
                    {SID, SDP2} -> 
                        handleP2pCall(UUID,Phone,Node,SID,SDP2,Arg),
                        utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
                    Err -> utility:pl2jso([{status, failed},{reason,a}])
                end;
            _ ->
        %               utility:log(?NOTICE,"post token illegal!from ip:~p original:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg)]),
                utility:pl2jso([{status, failed},{reason,what_do_you_want}])
        end;
     Excep->
        io:format("post illegal!from ip:~p original:~p~nExcp:~p~n",[utility:client_ip(Arg),lwork_app:origin(Arg),Arg#arg.clidata]),
        utility:pl2jso([{status, failed},{reason,c}])
    end.

%check_token(_UUID, [Phone, _GroupId, _AuthCode])-> {pass,Phone};    
%check_token(UUID, [Phone, GroupId, AuthCode]) when is_binary(GroupId)-> check_token(UUID, [Phone, binary_to_list(GroupId), AuthCode]);
%check_token(_UUID, [Phone, GroupId, _])  when GroupId=="dth_common" orelse GroupId=="common"-> {pass,Phone};
%check_token(_UUID, [Phone, "dth", _]) -> {pass,Phone};
%check_token(_UUID, [Phone, "livecom", _]) -> {pass,Phone};
check_token(_UUID, [Phone, "xh", "xhlivecom"]) -> {pass,Phone};
%check_token(_UUID, [Phone, "my_token", "my_finger"]) -> {pass,Phone,["0"]};
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

start_voip(WcgNode,ServiceId,UUID, Class, Phone, SDP, MaxtalkT, Arg)->
%    BA=xhr_poll:start([]),
    SessionIP=utility:client_ip(Arg),
    {Subgroup_id,Guid} = utility:decode(Arg,[{subgroup_id,s},{guid,s}]),
    {IsRecord,RecordFile}= if ServiceId=="xh"->  {true,ServiceId++"_"++Subgroup_id++"_"++Guid}; true-> {false,""} end,
    Options = [{phone, Phone}, {uuid, {ServiceId, UUID}}, {audit_info, [{uuid,UUID},{ip,SessionIP}]},{cid,UUID},{userclass, Class},
                                   {max_time, MaxtalkT},{callback,lw_mobile:charge_callback_fun(ServiceId,UUID)},
                                   {subgroup_id,Subgroup_id},{guid,Guid},{isrecord,IsRecord},{recordfile,RecordFile},
                                   {country,utility:country(SessionIP)},{gw,WcgNode},{consume_callback,lw_mobile:consume_func(ServiceId,UUID)}],

    case start_call1(WcgNode,SDP, Options) of
          {successful,Node,Session_id, Callee_sdp}->
              {enc_sid(Node, Session_id), Callee_sdp};
          Reason -> 
              Reason
   end.
    
fzd_stop_voip(_UUID, Session_id, _SessionIP) ->
    io:format("fzd_stop_voip:Session_id:~p~n",[Session_id]),
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
        CustomContent=[{alert,list_to_binary(UUID)},{badge,1},{'content-available',1},{sound,<<"lk_softcall_ringring.mp3">>},{event,<<"p2p_inform_called">>},
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
        
start_meeting(GroupId,UUID,Members)->
    Options=[{key, {GroupId, UUID}},{audit_info,""},{members, Members},{callback,lw_mobile:charge_callback_fun(GroupId,UUID)},
    {consume_callback,lw_mobile:consume_func(GroupId,UUID)}],
    io:format("voice_handler:start_meeting ~p~n",[Options]),
    rpc:call(?WWW_VOICE, www_voice_handler, start_meeting, [Options]).
formal_callee(Callee) when is_binary(Callee)-> formal_callee(binary_to_list(Callee));
formal_callee("+"++Callee)-> formal_callee("00"++Callee);
formal_callee(Callee="00"++_)-> Callee;
formal_callee(Callee="*812"++_) when is_list(Callee)-> "0086"++Callee;
formal_callee(Callee="*"++_) when is_list(Callee)-> Callee;
formal_callee(Callee) when is_list(Callee)-> "0086"++Callee.
    
