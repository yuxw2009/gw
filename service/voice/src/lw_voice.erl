-module(lw_voice).

-compile(export_all).

start_callback(UUID, Audit_info, {Name1, Phone1, Rate1}, 
                                                    {Name2, Phone2, Rate2}, MaxTalkingTime)->
    case operator:call_back( {UUID, Audit_info, {Name1, Phone1, Rate1}, 
                                                    {Name2, Phone2, Rate2}, MaxTalkingTime}) of
        {call_ok,UUID}-> ok;
        {call_failed, UUID, session_already_exist}-> {failed, session_already_exist}
    end.

stop_callback(UUID)->
    operator:stop(UUID),
    ok.

get_callback_status(UUID)->
    operator:get_call_status(UUID).

lookup_callback_stat(UUID, Year, Month)->
    %% {value, {Count, Charge, Time, Details}}
	    	        %% Count 为查询月份总次数
	    	        %% Charge为查询月份总费用
	    	        %% Time  为查询月份总时间
	    	        %% Details = [{StartTime,EndTime,LocalName,LocalPhone,
	    	        %%                                     RemoteName,RemotePhone,Duration,Rate,Charge}]
    callstat:lookup_callback_stat(UUID,Year,Month).

start_meeting(Plist)->
    meeting_api:start_meeting(Plist).

stop_meeting(UUID, MeetingID)->
    meeting_api:end_meeting(UUID, MeetingID).

get_active_meeting(UUID)->
    meeting_api:get_active_meeting(UUID).
    
join_meeting_member(UUID, MeetingId, Name, Phone)->
    meeting_api:join(UUID, MeetingId, Name, Phone).

unjoin_meeting_member(UUID, MeetingId, Name, Phone)->
    meeting_api:unjoin(UUID, MeetingId, Name, Phone).

hang_up_member(UUID, MeetingId, MemberId)->
    io:format("hang_up_member: MeetingId:~p, MemberId:~p~n ", [MeetingId, MemberId]),
    Members=meeting_db:get_meeting_members(MeetingId),
    try lists:nth(MemberId, Members) of
        Member-> operator ! {self(), {unjoin_conf,UUID,[Member]}},
        ok
    catch
        _-> {failed, error_member_id}
    end.


get_active_meeting_member_status(UUID, _MeetingId)->
    %%{value, MemberStatus}
                    %% MemeberStatus = [{MemberId, Status}]
    {value, Value} = get_active_meeting(UUID),
    {value, [{MemberId,Status} || {MemberId,Status,_Name,_Phone}<-Value]}.

redial_meeting_member(UUID, MeetingId, MemberId)->
    meeting_api:redail(UUID, MeetingId, MemberId).

get_n_bills_start_with(BillId, N)->
    callstat:get_n_bills_start_with(BillId, N).

lookup_meeting_stat(UUID, Year, Month)->
    callstat:lookup_meeting_stat(UUID, Year, Month).
