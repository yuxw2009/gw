%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/voices
%%%------------------------------------------------------------------------------------------
-module(voice_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers
%% handle start fzd VOIP call request
handle(Arg, 'POST', ["fzdvoip"]) ->
    {UUID, SDP, Phone} = utility:decode(Arg, [{uuid,s},{sdp,b},{phone,s}]),   
    %%io:format("start voip :~p~n", [{UUID, SDP, Phone}]),
    io:format("prepare voip call: ~p~n",[Phone]),
    Res = fzd_start_voip(UUID, Phone, SDP, utility:client_ip(Arg)),
    io:format("voip call: ~p~n",[Res]),
    case Res of
        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        {SID, SDP2} -> utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}])
    end;

%% handle stop VOIP  request
handle(Arg, 'GET', ["fzdvoip", "delete"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    io:format("stop voip :~p ~p~n", [UUID, SID]),
    fzd_stop_voip(UUID, SID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle GET VOIP status request
handle(Arg, 'GET', ["fzdvoip", "status"]) ->
    UUID = utility:query_string(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    %%io:format("get voip status:~p ~p~n", [UUID, SID]),
    Res = fzd_get_voip_status(UUID, SID, utility:client_ip(Arg)),
    case Res of
        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        State -> utility:pl2jso([{status, ok}, {state, State}])
    end;

%% handle subphone  request
handle(Arg, 'POST', ["voip", "dtmf"]) ->
    {UUID, SID, [Num|_]} = utility:decode(Arg, [{uuid,i},{session_id,i},{dtmf,ab}]),    
    ok = dial_sub_num(UUID, SID, Num, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle start VOIP call request
handle(Arg, 'POST', ["voip"]) ->
    {UUID, SDP, Phone} = utility:decode(Arg, [{uuid,i},{sdp,b},{phone,b}]),   
    %%io:format("start voip :~p~n", [{UUID, SDP, Phone}]),
    Res = start_voip(UUID, Phone, SDP, utility:client_ip(Arg)),
	io:format("voip call: ~p~n",[Res]),
    case Res of
        voip_failed -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        {value, {SID, SDP2}} -> utility:pl2jso([{status, ok}, {session_id, SID}, {sdp, SDP2}]);
        {value,Reason}      -> utility:pl2jso([{status, failed},{reason,Reason}])
    end;
%% handle stop VOIP  request
handle(Arg, 'DELETE', ["voip"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    io:format("stop voip :~p ~p~n", [UUID, SID]),
    stop_voip(UUID, SID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);

%% handle GET VOIP status request
handle(Arg, 'GET', ["voip", "status"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"),
    %%io:format("get voip status:~p ~p~n", [UUID, SID]),
    Res = get_voip_status(UUID, SID, utility:client_ip(Arg)),
    case Res of
        {value, voip_failed} -> utility:pl2jso([{status, failed},{reason,voip_failed}]);
        State -> utility:pl2jso([{status, ok}, {state, State}])
    end;

%% handle start callback call request
handle(Arg, 'POST', ["callback"]) ->
    {UUID, Local, Remote} = utility:decode(Arg, [{uuid,i},{local,s},{remote,s}]),	
    io:format("start callback :~p~n", [{UUID, Local, Remote}]),
    Res = start_callback(UUID, Local, Remote,utility:client_ip(Arg)),
    case Res of
        {value, callback_failed} -> utility:pl2jso([{status, failed}]);
        {value,Reason} when is_atom(Reason) -> utility:pl2jso([{status, failed},{reason,Reason}]);
        {value, SID} ->  utility:pl2jso([{status, ok}, {session_id, SID}])
    end;
 
%% handle stop callback call request
handle(Arg, 'DELETE', ["callback"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    SID= utility:query_integer(Arg, "session_id"), 
    io:format("stop callback :~p ~p~n", [UUID,SID]),
    stop_callback(UUID, SID,utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
    
%% handle get callback status request
handle(Arg, 'GET', ["calls", "status"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    {LocalStatus, RemoteStatus} = 
	    case get_callback_status(UUID, utility:client_ip(Arg)) of
	    	session_not_exist ->
	    	    {none, none};
	    	{status,{_LocalPhone, Status1}, {_RemotePhone,Status2}} -> 
	    	    {Status1, Status2}
	    end,
    utility:pl2jso([{status, ok}, {local, LocalStatus}, {remote, RemoteStatus}]);
%% handle start meeting request
handle(Arg, 'POST', ["meetings"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),	
    %%io:format("Start meeting **********************  ~p ~n", [Json]),	
    UUID = utility:get_integer(Json, "uuid"),
    Group = utility:get_binary(Json, "group_id"),
    Subject = utility:get_binary(Json, "subject"),
    MObjs = utility:get(Json, "members"),
    Members = [{utility:get_binary(Obj, "name"), utility:get_string(Obj, "phone")}  || Obj <- MObjs],
    %%Members = [{"dhui","008615300801756"}],
    {value, RateList} = get_rate(UUID, [P || {_, P} <- Members]),
    case Group of
        <<"zteict">> ->
            rpc:call(snode:get_service_node(), lw_lib, log_in, 
                         [UUID]);
        _ -> pass
    end,
    MRes= start_meeting(UUID, Group, Subject, lists:zipwith(fun({Name, Phone}, Rate) ->
    	                                                                        {Name, Phone, Rate}
    	                                                                     end,
    	                                                                     Members, RateList),
                                        60*10000, utility:client_ip(Arg)),
    case MRes of
        {value, {MeetingId, Details}} ->
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
handle(Arg, 'DELETE', ["meetings", MeetingId]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    ok = stop_meeting(UUID, MeetingId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle get active meeting info request
handle(Arg, 'GET', ["meetings"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    active = utility:query_atom(Arg, "status"),
    ActiveMeetings = get_active_meetings(UUID, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, 
    	            {meetings, utility:a2jsos([{meeting_id, fun erlang:list_to_binary/1},
    	            	                       {details, fun(V) ->  
    	            	                                     utility:a2jsos([member_id, status, 
    	            	                                     	            name,
    	            	                                     	            {phone, fun erlang:list_to_binary/1}], V) 
    	            	                                 end}
    	            	                      ],
    	            	                      ActiveMeetings)}]);
%% handle get active meeting member status request
handle(Arg, 'GET', ["meetings", MeetingId, "status"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Status = get_active_meeting_member_status(UUID, MeetingId, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok},
    	            {members, utility:a2jsos([member_id, status], Status)}
    	            ]);
%% handle add new member request
handle(Arg, 'POST', ["meetings",MeetingId, "members"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),		
    UUID = utility:get_integer(Json, "uuid"),
    Name = utility:get_binary(Json,"name"),
    Phone = utility:get_string(Json,"phone"),
    MemberInfo = join_meeting_member(UUID, MeetingId, Name, Phone, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok},
    	            {new_member, utility:a2jso([member_id, status, 
    	            	                         name, 
    	            	                         {phone, fun erlang:list_to_binary/1}
    	            	                        ], 
    	            	                        MemberInfo)}
    	            ]);
%% handle redial or hangup a member request
handle(Arg, 'PUT', ["meetings",MeetingId, "members", MemberId]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    case utility:get_string(Json,"status") of
        "online"  ->
             ok = redial_meeting_member(UUID, MeetingId, list_to_integer(MemberId), utility:client_ip(Arg));
        "offline" ->
             ok = hangup_meeting_member(UUID, MeetingId, list_to_integer(MemberId), utility:client_ip(Arg))
    end,
   
    utility:pl2jso([{status, ok}]);

%% handle get callback details of given month request
handle(Arg, 'GET', ["calls", "cdrs"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Year = utility:query_integer(Arg, "year"),
    Month = utility:query_integer(Arg, "month"),
    {Count, Charge, Time, Details} = lookup_callback_stat(UUID, Year, Month, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}, {charge, Charge}, {count, Count}, {time, Time}, 
    	            {details, utility:a2jsos([{start_time, fun erlang:list_to_binary/1},
    	            	                      {end_time, fun erlang:list_to_binary/1},
    	            	                      {local_name, fun erlang:list_to_binary/1},
    	            	                      {local_phone, fun erlang:list_to_binary/1},
    	            	                      {remote_name, fun erlang:list_to_binary/1},
    	            	                      {remote_phone, fun erlang:list_to_binary/1},
    	            	                      duration,
    	            	                      rate,
    	            	                      charge    	            	                       	
    	            	                     ], Details)}
                   ]);	
%% handle get meeting details of given month request
handle(Arg, 'GET', ["meetings", "cdrs"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
   %% Year = utility:query_integer(Arg, "year"),
   %% Month = utility:query_integer(Arg, "month"),
    History = get_meeting_history(UUID, utility:client_ip(Arg)),
    io:format("get_meeting_history: ~p~n", [History]),
    utility:pl2jso([{status, ok}, {details, utility:a2jsos([subject,
                                                            {timestamp, fun erlang:list_to_binary/1},
                                                            {members, fun(Ms) ->
                                                                          utility:a2jsos([name,{phone, fun erlang:list_to_binary/1},
                                                                               rate], Ms)

                                                                      end
                                                            }],
                                              History)}]).
                 	
-include("snode.hrl").

get_rate(_UUID, PhoneList) ->
    {value, [0.1 || _I<-PhoneList]}.

start_callback(UUID, LocalPhone, RemotePhone, SessionIP) ->
    Res  =rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, start_callback, [UUID, LocalPhone, RemotePhone], SessionIP]),

    Res.

stop_callback(UUID, SID, SessionIP) ->
    rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, stop_callback, [UUID, SID], SessionIP]),

    ok.

get_callback_status(UUID, _SessionIP) ->
    io:format("get_callback_status ~p ~n",[UUID]),
    Value = rpc:call(?VNODE, lw_voice, get_callback_status, [UUID]),
    %%{status, {"008615300801756", ready}, {"008615300801756", ring}}.
    Value.

start_meeting(UUID, GroupId, Subject, Phones, MaxMeetingTime, SessionIP) ->
    %%format("start_meeting ~p ~p ~p ~p~n",[UUID, GroupId, Subject, Phones]),
  
    %%{222333, [{123, offline, "dhui", "008615300801756"}]}.
    Res  =rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, start_meeting, [UUID, GroupId, Subject, Phones, MaxMeetingTime], SessionIP]),
    io:format("start meeting result: ~p ~n", [Res]),
    Res.

stop_meeting(UUID, MeetingId, SessionIP) ->
   io:format("stop_meeting ~p ~p~n",[UUID, MeetingId]),

    {value, ok}  =rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, stop_meeting, [UUID, MeetingId], SessionIP]),
   ok.

get_active_meetings(UUID, SessionIP) -> 
%    io:format("get_active_meetings ~p ~n",[UUID]),
  {value, ActiveMeetings}  =rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, get_active_meetings, [UUID], SessionIP]),
    ActiveMeetings.

%% fake 
get_active_meeting_member_status(UUID, MeetingId, SessionIP) ->
%    io:format("get_active_meeting_member_status ~p ~p ~n",[UUID, MeetingId]),
    {value, ActiveMeetings}  =rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, get_active_meetings, [UUID], SessionIP]),
    
    %%[{"abc1234", [{12, online, "dhui", "008615300801756"}]}].
    case ActiveMeetings of
        [{_, AM}|_]  ->    [{MemberId, Status} || {MemberId, Status, _, _}<- AM];
        [] ->         []
    end.

join_meeting_member(UUID, MeetingId, Name, Phone, SessionIP) ->
    io:format("join_meeting_member ~p ~p ~p ~p~n",[UUID, MeetingId, Name, Phone]),
   
    %%{123, online, "dhui", "008615300801756"}.
    {value, MemberInfo}  =  rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, join_meeting_member, [UUID, MeetingId, Name, Phone], SessionIP]),
    
    MemberInfo.

redial_meeting_member(UUID, MeetingId, MemberId, SessionIP) ->
    io:format("redial_meeting_member ~p ~p ~p ~n",[UUID, MeetingId, MemberId]),
    {value, ok } = rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, redial_meeting_member, [UUID, MeetingId, MemberId], SessionIP]),
    
    ok.

hangup_meeting_member(UUID, MeetingId, MemberId, SessionIP) ->
    io:format("hangup_meeting_member ~p ~p ~p ~n",[UUID, MeetingId, MemberId]),
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, hangup_meeting_member, [UUID, MeetingId, MemberId], SessionIP]),
    
    ok.

lookup_callback_stat(UUID, Year, Month, _SessionIP) ->
	io:format("lookup_callback_stat ~p ~p ~p~n",[UUID, Year, Month]),
    %%{value, {Count, Charge, Time, Details}} = rpc:call(?VNODE, lw_voice, lookup_callback_stat, [UUID, Year, Month]),
    {123, 23.0, 33.0, [{"2012-07-22 12:34:45", "2012-07-22 12:34:50", "dhui","00861334566",
                         "zhang","008613344444", 5.0, 0.003, 0.3}]}.


lookup_meeting_stat(UUID, Year, Month, SessionIP) ->
    io:format("lookup_meeting_stat ~p ~p ~p~n",[UUID, Year, Month]),

    Stat = rpc:call(snode:get_service_node(), lw_instance, request, 
                         [UUID, lw_voice, lookup_meeting_stat, [UUID, Year, Month], SessionIP]),
    io:format("Meeting ~p~n",[Stat]),
    {Count, Charge, Time, Details} = 
        case Stat of
            {value, {Count2, Charge2, Time2, Details2}} -> {Count2, Charge2, Time2, Details2};
            {value, []} -> {0,0,0,[]}
        end,
    %%{123, 23.0, 33.0, [{"meeting1", 
    %%                       [{"2012-07-22 12:34:45", "2012-07-22 12:34:50", "dhui","00861334566",5.0, 0.003, 0.3},
    %%                        {"2012-07-22 12:44:45", "2012-07-22 12:54:50", "dhui","00861334566",5.0, 0.003, 0.3}
    %%                       ]
    %%                   }]}.
    F = fun({X,Y}) ->
    	    {X, [ {d2s(X1),d2s(X2),X3,X4,X5,X6,X7} || {X1,X2,X3,X4,X5,X6,X7} <-Y]}
    	end,
    {Count, Time, Charge, [F(D)|| D <- Details]}.
d2s(X) -> X.
d2s2({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}}) ->    
    DateStr = string:join([integer_to_list(I) || I <- tuple_to_list(Date)], "-"),
    TimeStr = string:join([integer_to_list(I) || I <- tuple_to_list(Time)], ":"),
    DateStr ++" "++TimeStr.


get_meeting_history(UUID, SessionIP) ->
    io:format("get_meeting_history ~p ~n",[UUID]),

    {value, History} = rpc:call(snode:get_service_node(), lw_instance, request, 
                         [UUID, lw_voice, get_meeting_history, [UUID], SessionIP]),

    History.

fzd_start_voip(UUID, Phone, SDP, SessionIP)->
    case rpc:call('fzdwrtc@ubuntu.livecom', wkr, processVOIP, 
                    [SDP, [{phone, Phone}, {uuid, {fzd, UUID}}, {audit_info, {}},{cid,UUID},{fzd, true}]]) of
         {successful,Session_id, Callee_sdp}->
             io:format("start voip! phone:~p cid:~p~n", [Phone,UUID]),
            {Session_id, Callee_sdp};
        {failed, Reason}-> voip_failed
    end.
    
fzd_stop_voip(UUID, Session_id, SessionIP) ->
    io:format("stop voip!~n"),
    rpc:call('fzdwrtc@ubuntu.livecom', wkr, stopVOIP, [Session_id]).

fzd_get_voip_status(UUID, Session_id, SessionIP) ->
    case rpc:call('fzdwrtc@ubuntu.livecom', wkr, getVOIP, [Session_id]) of
         {ok, Status}->
             io:format("get voip status!~n"),
             Status;
        {failed, Reason}-> [{status, failed}, {reason, Reason}]
    end.


start_voip(UUID, Phone, SDP, SessionIP) ->
     Res = rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, start_voip, [UUID, Phone, SDP], SessionIP]),

     Res.
stop_voip(UUID, SID, SessionIP) ->
    rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, stop_voip, [UUID, SID], SessionIP]),
    ok.

get_voip_status(UUID, SID, SessionIP) ->
    {value, State} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, get_voip_status, [UUID, SID], SessionIP]),

    State.

dial_sub_num(UUID, SID, Num, SessionIP) ->
    io:format("dial_sub_num ~p ~p ~p~n",[UUID, SID, Num]),
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                                 [UUID, lw_voice, start_voip_sub, [UUID, Num, SID], SessionIP]),
    
    ok.