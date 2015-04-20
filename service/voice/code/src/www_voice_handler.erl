-module(www_voice_handler).

-compile(export_all).
-include("call.hrl").
-include("yaws_arg.hrl").

%% handle start meeting request
handle(Arg, 'POST', ["meetings"]) ->
     io:format("start:~p~n", [meetings]),
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
    
    {AuditInfo, _Host={HostName, HostPhone}, Members}= 
        yaws_utility:decode(Arg, 
            [   {audit_info, r}, {host, o, [{name, b}, {phone, s}]}, 
                {members, ao, [{name, b}, {phone, s}]}
            ]),
     Session_id = www_xengine:session_id(),
     io:format("session_id:~p~n", [Session_id]),
     {value,Session_id, MembersLists} = 
        rpc:call(?SNODE, lw_voice, start_meeting, [[{key, {Service_id, UUID}},{audit_info,AuditInfo},{session_id, Session_id},{members, [{HostName, HostPhone} |Members]}]]),
    [{status, ok}, 
        {session_id, list_to_binary(Session_id)},
        {member_info, yaws_utility:a2jsos([{member_id, fun(Id)-> list_to_binary(integer_to_list(Id)) end}, 
                          status, 
                          name,
                          {phone, fun erlang:list_to_binary/1}],
                         MembersLists)}];

%DELETE /xengine/meetings?service_id=SID&seq_no=SNO&auth_code=AC&session_id=SID
handle(Arg, 'DELETE', ["meetings"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
    Session_id = yaws_utility:query_string(Arg, "session_id"),
    ok = rpc:call(?SNODE, lw_voice, stop_meeting, [{Service_id, UUID}, Session_id]),
    [{status, ok}];


%% join a member
handle(Arg, 'POST', ["meetings","members"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
    Session_id = yaws_utility:query_string(Arg, "session_id"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),

%   {Name, Phone} =  yaws_utility:decode(Arg, [{name, b}, {phone, s}]),
   {Name, Phone} =  yaws_utility:decode(Arg, [{name, b}, {phone, s}]),
    %%{123, online, "dhui", "008615300801756"}.
    {value, MemberInfo}  =  rpc:call(?SNODE, lw_voice, join_meeting_member, [{Service_id, UUID}, Session_id, Name, Phone]),

    [{status, ok},
    	            {member_info, yaws_utility:a2jso([{member_id,fun itob/1}, status, 
    	            	                         name, 
    	            	                         {phone, fun erlang:list_to_binary/1}
    	            	                        ], 
    	            	                        MemberInfo)}
    	            ];

%% hangup or redial a member
handle(Arg, 'PUT', ["meetings","members"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
    Session_id = yaws_utility:query_string(Arg, "session_id"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
    io:format("put memebers handle! clidata:~p~n", [Arg#arg.clidata]),
    {Member_id, Status} = yaws_utility:decode(Arg, [{member_id, i}, {status, a}]),
    io:format("------------------------------------put memebers handle! Session_id:~n"),
    case Status of
        online-> 
            ok  = rpc:call(?SNODE, lw_voice, redial_meeting_member, [{Service_id,UUID}, Session_id, Member_id]);        
        offline-> 
            ok = rpc:call(?SNODE, lw_voice, hang_up_member, [{Service_id,UUID}, Session_id, Member_id])
    end,
    [{status, ok}];

% get active meeting status
handle(Arg, 'GET', ["meetings"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
    {value, ActiveMeetings} = rpc:call(?SNODE, lw_voice, get_active_meeting, [{Service_id, UUID}]),
    [{status, ok}, 
                {meetings, yaws_utility:a2jsos([{session_id, fun erlang:list_to_binary/1},
                                       {member_info, fun(V) ->  
                                                     yaws_utility:a2jsos([{member_id,fun itob/1}, status, 
                                                                 name,
                                                                 {phone, fun erlang:list_to_binary/1}], V) 
                                                 end}
                                      ],
                                      ActiveMeetings)}];

%% handle start callback request
handle(Arg, 'POST', ["callbacks"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
    {AuditInfo, Local_phone, Remote_phone}= 
        yaws_utility:decode(Arg, 
            [   {audit_info, r}, {local_phone, s}, {remote_phone, s}
            ]),
     Session_id = www_xengine:session_id(),
     case rpc:call(?SNODE, lw_voice, start_callback, 
                    [{Service_id, UUID}, AuditInfo,  {"", Local_phone, 0.1}, {"", Remote_phone, 0.1}, 3600]) of
         ok->
%             io:format("start callback! session_id:~p~n", [Session_id]),
            [{status, ok}, {session_id, list_to_binary(Session_id)}];
         {failed, session_already_exist}-> [{status, failed}, {reason,session_already_exist}]
     end;

handle(Arg, 'DELETE', ["callbacks"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
    _Session_id = yaws_utility:query_string(Arg, "session_id"),
    ok = rpc:call(?SNODE, lw_voice, stop_callback, [{Service_id, UUID}]),
    [{status, ok}];

handle(Arg, 'GET', ["callbacks"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
    _Session_id = yaws_utility:query_string(Arg, "session_id"),
    case rpc:call(?SNODE, lw_voice, get_callback_status, [{Service_id, UUID}]) of
        {status,{_Local_phone,Local_status}, {_,Remote_status}}->
            [{status, ok}, {local_status,Local_status}, {remote_status, Remote_status}];
        Result-> [{status, failed}, {reason, Result}]
    end;

handle(Arg, 'POST', ["voip"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    UUID = yaws_utility:query_integer(Arg, "uuid"),
    {Audit_info, SDP, Phone, Cid}= yaws_utility:decode(Arg, [{audit_info, r}, {sdp, b}, {phone, s}, {cid, s}]),

    case rpc:call(?VOIPNODE, wkr, processVOIP, 
                    [SDP, [{phone, Phone}, {uuid, {Service_id, UUID}}, {audit_info, Audit_info},{cid,Cid}]]) of
         {successful,Session_id, Callee_sdp}->
             io:format("start voip! phone:~p cid:~p~n", [Phone,Cid]),
            [{status, ok}, {session_id, Session_id}, {callee_sdp, Callee_sdp}];
        {failed, Reason}-> [{status, failed}, {reason, Reason}]
    end;

handle(Arg, 'PUT', ["voip"]) ->   % dial sub phoneno
    _Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    _UUID = yaws_utility:query_integer(Arg, "uuid"),
    Session_id=list_to_integer(yaws_utility:query_string(Arg, "session_id")),
    {_Audit_info, Sub_Phone}= yaws_utility:decode(Arg, [{audit_info, r}, {sub_phone, s}]),

    case rpc:call(?VOIPNODE, wkr, eventVOIP, [Session_id, {dail,Sub_Phone}]) of
         ok->
             io:format("voip dial sub_no:~p ~n", [Sub_Phone]),
            [{status, ok}, {session_id, Session_id}];
        Reason-> [{status, failed}, {reason, Reason}]
    end;

handle(Arg, 'DELETE', ["voip"]) ->
    _Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    _UUID = yaws_utility:query_integer(Arg, "uuid"),
    Session_id=list_to_integer(yaws_utility:query_string(Arg, "session_id")),

    case rpc:call(?VOIPNODE, wkr, stopVOIP, [Session_id]) of
         ok->
             io:format("stop voip!~n"),
            [{status, ok}];
        {failed, Reason}-> [{status, failed}, {reason, Reason}]
    end;

handle(Arg, 'GET', ["voip"]) ->
    _Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    _UUID = yaws_utility:query_integer(Arg, "uuid"),
    Session_id=list_to_integer(yaws_utility:query_string(Arg, "session_id")),

    case rpc:call(?VOIPNODE, wkr, getVOIP, [Session_id]) of
         {ok, Status}->
             io:format("get voip status!~n"),
            [{status, ok}, {state, Status}];
        {failed, Reason}-> [{status, failed}, {reason, Reason}]
    end;

handle(Arg, 'POST', ["sms"]) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    _Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
    _UUID = yaws_utility:query_integer(Arg, "uuid"),
    _Auth_code = yaws_utility:query_integer(Arg, "auth_code"),
    {Audit_info, Content, Phones_bin}= yaws_utility:decode(Arg, [{audit_info, r}, {content, s}, {phones, r}]),
    Phones = [binary_to_list(I) || I<-Phones_bin],
    Para = [{service_id,Service_id},{audit_info,Audit_info},{content,Content},{members,Phones}],
%    io:format("sms handle! Para:~p~n", [Para]),
    case rpc:call(?SNODE, lw_sms, send_sms, [Para]) of
        {ok, Fails}-> [{status,ok}, {fails,Fails}];
        Reason->[{status,failed}, {reason,Reason}]
    end;

handle(_Arg, Method,Content)->
    io:format("unhandled voice request, Method: ~p, Content:~p~n", [Method, Content]),
    [{status, unhandled}].

test()-> okkk.

itob(I)-> list_to_binary(integer_to_list(I)).
