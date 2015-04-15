-module(lw_voice).
-compile(export_all).

-define(VNODE, 'voice@department3-svn').
-define(SMS,"xengine/sms").
-define(MEETING_MEMBER,"xengine/meetings/members").
-define(MEETING,"xengine/meetings").
-define(CALLBACK,"xengine/callbacks").
-define(VOIP,"xengine/voip").

-include("lw.hrl").

%%--------------------------------------------------------------------------------------

start_ct_scheduler() ->
    register(ct_service,spawn(fun() -> ct_scheduler() end)).

%%--------------------------------------------------------------------------------------

receive_result() ->
    receive
        {ct_service,Rtn} -> Rtn
    after
        5000 -> failed_overtime
    end.

%%--------------------------------------------------------------------------------------

ct_scheduler() ->
    receive
        {Act,From,Arg} ->
            case catch apply(lw_voice,Act,[Arg]) of
                {'EXIT', Reason} -> 
                    logger:log(error,"lw_instance ct_scheduler function:~p ~p ~n",[Act,Reason]),
                    From ! {ct_service,failed_exception};
                Rtn ->
                    From ! {ct_service,Rtn}
            end,
            ct_scheduler()
    end.

%%--------------------------------------------------------------------------------------

send_to_members({UUID, Members, Content}) ->
    IP    = lw_config:get_ct_server_ip(),
    SMS   = ?SMS,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,SMS,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
    Body  = rfc4627:encode(lw_lib:build_body([content,phones],[Content,Members],[b,r],{audit_info,UUID})),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p Members:~p Content:~p send_to_members_failed.reason:~p~n",[UUID,Members,Content,Reason]),
                    {sms_failed}
                end,
            element(1,lw_lib:parse_json(Json,[{fails,ab}],F))
    end.

send_to_members(UUID, Members, Content) ->
    ct_service ! {send_to_members,self(),{UUID, Members, Content}},
    receive_result().

%%--------------------------------------------------------------------------------------

start_callback({UUID,Phone1,Phone2}) ->
    IP    = lw_config:get_ct_server_ip(),
    CB    = ?CALLBACK,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,CB,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
    Body  = rfc4627:encode(lw_lib:build_body([local_phone,remote_phone],[Phone1,Phone2],[b,b],{audit_info,UUID})),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p phone1:~p phone2:~p start_callback_failed.reason:~p~n",[UUID,Phone1,Phone2,Reason]),
                    {callback_failed}
                end,
            element(1,lw_lib:parse_json(Json,[{session_id,i}],F))
    end.

start_callback(UUID, Phone1,Phone2) ->
    case local_user_info:check_user_privilege(UUID,callback) of
        ok ->
            ct_service ! {start_callback,self(),{UUID, Phone1,Phone2}},
            receive_result();
        Other ->
            Other
    end.

test_start_callback() ->
    UUID = 76,
    start_callback(UUID,"008618652938287","008615300801756").

%%--------------------------------------------------------------------------------------

stop_callback({UUID,SessionID}) ->
    IP    = lw_config:get_ct_server_ip(),
    CB    = ?CALLBACK,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,CB,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,SessionID]),
    case lw_lib:httpc_call(delete,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p SessionID:~p stop_callback_failed.reason:~p~n",[UUID,SessionID,Reason]),
                    {callback_failed}
                end,
            element(1,lw_lib:parse_json(Json,[],F))
    end.

stop_callback(UUID,SessionID) ->
    ct_service ! {stop_callback,self(),{UUID,SessionID}},
    receive_result().

test_stop_callback() ->
    UUID = 76,
    SessionID = start_callback(UUID,"008618652938287","008615300801756"),
    ok = stop_callback(UUID,SessionID).

%%--------------------------------------------------------------------------------------

start_voip({UUID,Phone,SDP}) ->
    IP    = lw_config:get_ct_server_ip(),
    VOIP  = ?VOIP,
    SerID = lw_config:get_serid(),
    VNum  = lw_config:get_voip_call_number(),
    URL   = lw_lib:build_url(IP,VOIP,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
    Body  = rfc4627:encode(lw_lib:build_body([sdp,phone,cid],[SDP,Phone,VNum],[r,r,r],{audit_info,UUID})),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p Phone:~p SDP:~p start_voip_failed.reason:~p~n",[UUID,Phone,SDP,Reason]),
                    voip_failed
                end,
            lw_lib:parse_json(Json,[{session_id,i},{callee_sdp,b}],F)
    end.

start_voip(UUID,Phone,SDP) ->
    case local_user_info:check_user_privilege(UUID,voip) of
        ok ->
            ct_service ! {start_voip,self(),{UUID,Phone,SDP}},
            receive_result();
        Other ->
            Other
    end.

%%--------------------------------------------------------------------------------------

start_voip_sub({UUID,SubPhone,SessionID}) ->
    IP    = lw_config:get_ct_server_ip(),
    VOIP  = ?VOIP,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,VOIP,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,SessionID]),
    Body  = rfc4627:encode(lw_lib:build_body([sub_phone],[SubPhone],[r],{audit_info,UUID})),
    case lw_lib:httpc_call(put,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p SubPhone:~p start_voip_sub_failed.reason:~p~n",[UUID,SubPhone,Reason]),
                    {voip_sub_failed}
                end,
            element(1,lw_lib:parse_json(Json,[],F))
    end.

start_voip_sub(UUID,SubPhone,SessionID) ->
    case local_user_info:check_user_privilege(UUID,voip) of
        ok ->
            ct_service ! {start_voip_sub,self(),{UUID,SubPhone,SessionID}},
            receive_result();
        Other ->
            Other
    end.

%%--------------------------------------------------------------------------------------

stop_voip({UUID,SessionID}) ->
    IP    = lw_config:get_ct_server_ip(),
    VOIP  = ?VOIP,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,VOIP,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,SessionID]),
    case lw_lib:httpc_call(delete,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p SessionID:~p stop_voip_failed.reason:~p~n",[UUID,SessionID,Reason]),
                    {voip_failed}
                end,
            element(1,lw_lib:parse_json(Json,[],F))
    end.

stop_voip(UUID,SessionID) ->
    ct_service ! {stop_voip,self(),{UUID,SessionID}},
    receive_result().

%%--------------------------------------------------------------------------------------

get_voip_status({UUID,SessionID}) ->
    IP    = lw_config:get_ct_server_ip(),
    VOIP  = ?VOIP,
    SerID = lw_config:get_serid(),
    URL = lw_lib:build_url(IP,VOIP,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,SessionID]),
    case lw_lib:httpc_call(get,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"UUID:~p SessionID:~p get_voip_status_failed.reason:~p~n",[UUID,SessionID,Reason]),
                    {voip_failed}
                end,
            element(1,lw_lib:parse_json(Json,[{state,a}],F))
    end.

get_voip_status(UUID,SessionID) ->
    ct_service ! {get_voip_status,self(),{UUID,SessionID}},
    receive_result().

%%--------------------------------------------------------------------------------------

get_callback_status(UUID) ->
    Value = rpc:call(?VNODE, lw_voice, get_callback_status, [UUID]),
    Value.

save_meeting(UUID,MeetingID,Subject,Phones) ->
    Time = erlang:localtime(),
    lw_db:act(add,meeting,{UUID,MeetingID,Subject,Phones,Time}).

add_meeting_member(UUID,MeetingID,{Name,Phone,0.0}) ->
    lw_db:act(add,meeting_member,{UUID,MeetingID,{Name,Phone,0.0}}).

add_meeting(UUID,MeetingID,{Name,Phone,Rate}) ->
    lw_db:act(join,meeting,{UUID,MeetingID,{Name,Phone,Rate}}).    

get_meeting_history(UUID) ->
    AllMeeting = lw_db:act(get,all_meeting,{UUID}),
    [{Subject,lw_lib:trans_time_format(Time),Phones}||{_,Subject,Phones,Time}<-AllMeeting].

%%-------------------------------------------------------------------------------------------------

get_binary_phones(Phones) when is_list(Phones) ->
    [{Name,list_to_binary(Number)}||{Name,Number,_}<-Phones].

start_meeting(UUID,GroupId,Subject,Phones,MaxMeetingTime) ->
    lw_media_srv:start_meeting(UUID,GroupId,Subject,Phones,MaxMeetingTime).
%start_meeting({UUID, Subject, Phones, _MaxMeetingTime}) ->
%    AddNum = length(Phones),
%    case local_user_info:check_org_res(UUID,phoneconf,AddNum) of
%        ok -> 
%            IP    = lw_config:get_ct_server_ip(),
%            MEET  = ?MEETING,
%            SerID = lw_config:get_serid(),
%            URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
%            [{Name,Phone}|Rest] = get_binary_phones(Phones),
%            Host    = utility:pl2jso([{name,Name},{phone,Phone}]),
%            Members = utility:a2jsos([name,phone],Rest),
%            Body = rfc4627:encode(lw_lib:build_body([host,members],[Host,Members],[r,r],{audit_info,UUID})),
%            case catch lw_lib:httpc_call(post,{URL,Body}) of
%                {'EXIT', _Reason} -> 
%                    local_user_info:release_org_res(UUID,phoneconf,AddNum),
%                    httpc_failed;
%                httpc_failed ->
%                    save_meeting(UUID,httpc_failed,Subject, Phones),
%                    local_user_info:release_org_res(UUID,phoneconf,AddNum),
%                    httpc_failed;
%                Json ->
%                    F = fun(Reason) ->
%                            logger:log(error,"UUID:~p Subject:~p Phones:~p start_meeting_failed.reason:~p~n",[UUID,Subject,Phones,Reason]),
%                            meeting_failed
%                        end,
%                    case lw_lib:parse_json(Json,[{session_id,s},{member_info,ao,[{member_id,i},{status,a},{name,b},{phone,s}]}],F) of
%                        meeting_failed ->
%                            local_user_info:release_org_res(UUID,phoneconf,AddNum),
%                            save_meeting(UUID,meeting_failed,Subject, Phones);
%                        {MeetingId,MeetingDetails} ->
%                            logger:log(error,"new meeting UUID:~p MeetingId:~p,Nums:~p~n",[UUID,MeetingId,AddNum]),
%                            local_user_info:create_org_meeting(MeetingId,AddNum),
%                            save_meeting(UUID,MeetingId,Subject,Phones),
%                            spawn(fun() -> start_meeting_monitor(UUID,MeetingId) end),
%                            {MeetingId,MeetingDetails}
%                    end
%            end;
%        out_of_res ->
%            out_of_res
%    end.

%start_meeting(UUID,_GroupId,Subject,Phones,MaxMeetingTime) ->
    %io:format("start_meeting GroupId:~p~n",[_GroupId]),
%    case local_user_info:check_user_privilege(UUID,phoneconf) of
%        ok ->
%            ct_service ! {start_meeting,self(),{UUID,Subject,Phones,MaxMeetingTime}},
%            receive_result();
%        Other ->
%            Other
%    end.

%test_start_meeting() ->
%    start_meeting(76,1,"测试",[{list_to_binary("张丛耸"),"008618652938287","0.1"},
%                               {list_to_binary("余晓文"),"008613816461488","0.1"}],1).

%%-------------------------------------------------------------------------------------------------

stop_meeting(UUID, MeetingId) ->
    lw_media_srv:stop_meeting(UUID, MeetingId).

%stop_meeting({UUID, MeetingId}) ->
%    IP    = lw_config:get_ct_server_ip(),
%    MEET  = ?MEETING,
%    SerID = lw_config:get_serid(),
%    URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
%    case lw_lib:httpc_call(delete,{URL}) of
%        httpc_failed ->
%            httpc_failed;
%        Json ->
%           F = fun(Reason) ->
%                  logger:log(error,"UUID:~p SessionID:~p stop_meeting_failed.reason:~p~n",[UUID,MeetingId,Reason]),
%                 {meeting_failed}
%                end,
%            case element(1,lw_lib:parse_json(Json,[],F)) of
%                meeting_failed ->
%                    meeting_failed;
%                Other ->
%                    Nums = local_user_info:del_org_meeting(MeetingId),
%                    local_user_info:release_org_res(UUID,phoneconf,Nums),
%                    Other
%            end
%    end.

%stop_meeting(UUID, MeetingId) ->
%    ct_service ! {stop_meeting,self(),{UUID,MeetingId}},
%    receive_result().

%test_stop_meeting() ->
%    UUID = 76,
%    {MeetingId,_} = start_meeting(UUID,1,"测试",[{list_to_binary("张丛耸"),"008618652938287","0.1"},{"余晓文","008613816461488","0.1"}],1),
%    stop_meeting(UUID, MeetingId).

%%-------------------------------------------------------------------------------------------------

get_active_meetings(UUID) ->
    lw_media_srv:get_active_meetings(UUID).

%get_active_meetings({UUID}) ->
%    IP    = lw_config:get_ct_server_ip(),
%    MEET  = ?MEETING,
%    SerID = lw_config:get_serid(),
%    URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
%    case lw_lib:httpc_call(get,{URL}) of
%        httpc_failed ->
%            httpc_failed;
%        Json ->
%            F = fun(Reason) ->
%                    logger:log(error,"UUID:~p get_active_meetings_failed.reason:~p~n",[UUID,Reason]),
%                    {meeting_failed}
%                end,
%            Rtn = element(1,lw_lib:parse_json(Json,[{meetings,ao,[{session_id,s},{member_info,ao,[{member_id,i},{status,a},{name,b},{phone,s}]}]}],F)),
            %case Rtn of
            %    [] ->
            %        case mnesia:dirty_read(lw_meeting,UUID) of
            %            [] ->
            %                ok;
            %            [#lw_meeting{meeting = MeetingHistory}] ->
            %                case MeetingHistory of
            %                    [] ->
            %                        ok;
            %                    _ ->
            %                        release_all_meeting(UUID,MeetingHistory)
            %                end
            %        end;
            %    _ ->
            %        ok
            %end,
%            Rtn
%    end;

%get_active_meetings(UUID) when is_integer(UUID) ->
%    ct_service ! {get_active_meetings,self(),{UUID}},
%    receive_result().

%test_get_active_meetings() ->
%    UUID = 76,
%    {MeetingId,_} = start_meeting(UUID,1,"测试",[{list_to_binary("张丛耸"),"008618652938287","0.1"},
%                                                 {list_to_binary("余晓文"),"008613816461488","0.1"}],1),
%    io:format("~p~n",get_active_meetings(UUID)),
%    stop_meeting(UUID, MeetingId).

%%-------------------------------------------------------------------------------------------------

get_active_meeting_member_status(UUID,MeetingId) ->
    lw_media_srv:get_active_meeting_member_status(UUID,MeetingId).

%get_active_meeting_member_status({UUID, _MeetingId}) ->
%    ActiveMeetings = get_active_meetings({UUID}),
%    case ActiveMeetings of
%        [{_, AM}|_] -> [{MemberId, Status} || {MemberId, Status, _, _}<- AM];
%        [] -> [];
%        Other -> Other
%    end.

%get_active_meeting_member_status(UUID,MeetingId) ->
%    ct_service ! {get_active_meeting_member_status,self(),{UUID,MeetingId}},
%    receive_result().

%%-------------------------------------------------------------------------------------------------

join_meeting_member(UUID, MeetingId, Name, Phone) ->
    lw_media_srv:join_meeting_member(UUID, MeetingId, Name, Phone).

%join_meeting_member({UUID, MeetingId, Name, Phone}) ->
%    case local_user_info:check_org_res(UUID,phoneconf,1) of
%        ok ->
%            add_meeting_member(UUID,MeetingId,{Name,Phone,0.0}),
%            IP     = lw_config:get_ct_server_ip(),
%            Member = ?MEETING_MEMBER,
%            SerID  = lw_config:get_serid(),
%            URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
%            Body   = rfc4627:encode(lw_lib:build_body([name,phone],[Name,Phone],[r,b])),
%            case catch lw_lib:httpc_call(post,{URL,Body}) of
%                {'EXIT', _Reason} -> 
%                    local_user_info:release_org_res(UUID,phoneconf,1),
%                    httpc_failed;
%                httpc_failed ->
%                    local_user_info:release_org_res(UUID,phoneconf,1),
%                    httpc_failed;
%                Json ->
%                    F = fun(Reason) ->
%                            logger:log(error,"UUID:~p SessionID:~p Name:~p Phones:~p join_meeting_member_failed.reason:~p~n",[UUID, MeetingId, Name, Phone,Reason]),
%                            {meeting_failed}
%                        end,
%                    case element(1,lw_lib:parse_json(Json,[{member_info,o,[{member_id,i},{status,a},{name,b},{phone,s}]}],F)) of
%                        meeting_failed ->
%                            local_user_info:release_org_res(UUID,phoneconf,1),
%                            meeting_failed;
%                        Other ->
%                            logger:log(error,"new meeting UUID:~p MeetingId:~p,Nums:~p~n",[UUID,MeetingId,1]),
%                            local_user_info:add_org_meeting_num(MeetingId,1),
%                            Other
%                    end
%            end;
%        out_of_res ->
%            out_of_res
%    end.

%join_meeting_member(UUID, MeetingId, Name, Phone) ->
%    ct_service ! {join_meeting_member,self(),{UUID,MeetingId, Name, Phone}},
%    receive_result().

%test_join_meeting_member() ->
%    UUID = 76,
%    {MeetingId,_} = start_meeting(UUID,1,"测试",[{list_to_binary("张丛耸"),"008618652938287","0.1"},
%                                                 {list_to_binary("余晓文"),"008613816461488","0.1"}],1),
%    join_meeting_member(UUID, MeetingId, list_to_binary("邓辉"), "008615300801756").

%%-------------------------------------------------------------------------------------------------

hangup_meeting_member(UUID, MeetingId, MemberId) ->
    lw_media_srv:hangup_meeting_member(UUID, MeetingId, MemberId).

%hangup_meeting_member({UUID, MeetingId, MemberId}) ->
%    IP     = lw_config:get_ct_server_ip(),
%    Member = ?MEETING_MEMBER,
%    SerID  = lw_config:get_serid(),
%    URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
%    Body   = rfc4627:encode(lw_lib:build_body([member_id,status],[integer_to_list(MemberId),offline],[b,r])),
%    case lw_lib:httpc_call(put,{URL,Body}) of
%        httpc_failed ->
%            httpc_failed;
%        Json ->
%            F = fun(Reason) ->
%                    logger:log(error,"UUID:~p SessionID:~p MemberId:~p hangup_meeting_member_failed.reason:~p~n",[UUID, MeetingId, MemberId,Reason]),
%                    {meeting_failed}
%                end,
%            case element(1,lw_lib:parse_json(Json,[],F)) of
%                meeting_failed ->
%                    meeting_failed;
%                Other ->
%                    local_user_info:del_org_meeting_num(MeetingId,1),
%                    local_user_info:release_org_res(UUID,phoneconf,1),
%                    Other
%            end
%    end.

%hangup_meeting_member(UUID, MeetingId, MemberId) ->
%    ct_service ! {hangup_meeting_member,self(),{UUID,MeetingId,MemberId}},
%    receive_result().

redial_meeting_member(UUID, MeetingId, MemberId) ->
    lw_media_srv:redial_meeting_member(UUID, MeetingId, MemberId).
    
%redial_meeting_member({UUID, MeetingId, MemberId}) ->
%    IP     = lw_config:get_ct_server_ip(),
%    Member = ?MEETING_MEMBER,
%    SerID  = lw_config:get_serid(),
%    URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
%    Body   = rfc4627:encode(lw_lib:build_body([member_id,status],[integer_to_list(MemberId),online],[b,r])),
%    case lw_lib:httpc_call(put,{URL,Body}) of
%        httpc_failed ->
%            httpc_failed;
%        Json ->
%            F = fun(Reason) ->
%                    logger:log(error,"UUID:~p SessionID:~p MemberId:~p redial_meeting_member_failed.reason:~p~n",[UUID, MeetingId, MemberId,Reason]),
%                    {meeting_failed}
%                end,
%            element(1,lw_lib:parse_json(Json,[],F))
%    end.

%redial_meeting_member(UUID, MeetingId, MemberId) ->
%    ct_service ! {redial_meeting_member,self(),{UUID,MeetingId,MemberId}},
%    receive_result().

%%-------------------------------------------------------------------------------------------------

lookup_callback_stat(UUID, Year, Month) ->
	io:format("lookup_callback_stat ~p ~p ~p~n",[UUID, Year, Month]),
    %%{value, {Count, Charge, Time, Details}} = rpc:call(?VNODE, lw_voice, lookup_callback_stat, [UUID, Year, Month]),
    {123, 23.0, 33.0, [{"2012-07-22 12:34:45", "2012-07-22 12:34:50", "dhui","00861334566",
                         "zhang","008613344444", 5.0, 0.003, 0.3}]}.

lookup_meeting_stat(UUID, Year, Month) ->
    {Count, Charge, Time, Details} = 
        case rpc:call(?VNODE, lw_voice, lookup_meeting_stat, [UUID, Year, Month]) of
            {value, {Count2, Charge2, Time2, Details2}} -> {Count2, Charge2, Time2, Details2};
            {value, []} -> {0,0,0,[]}
        end,
    F = fun({_,X,Y}) ->
    	    {X, [ {d2s(X1),d2s(X2),X3,X4,X5,X6,X7} || {_,X1,X2,X3,X4,X5,X6,X7} <-Y]}
    	end,
    {Count, Time, Charge, [F(D)|| D <- Details]}.

d2s({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}}) ->    
    DateStr = string:join([integer_to_list(I) || I <- tuple_to_list(Date)], "-"),
    TimeStr = string:join([integer_to_list(I) || I <- tuple_to_list(Time)], ":"),
    DateStr ++" "++TimeStr.

%%-------------------------------------------------------------------------------------------------
