-module(meeting_db).
-compile(export_all).

-include("meeting.hrl").
-include("db_op.hrl").

add_meeting(UUID, MeetingId, Subject, NamePhoneList)->
    Meetings = get_meetings(UUID),
    NewMeetings = [MeetingId | Meetings],
    ?DB_WRITE(#uuid_meetings{uuid=UUID, meeting_ids=NewMeetings}),
    ?DB_WRITE(#meeting_detail{meeting_id=MeetingId, 
                            subject=Subject, start_time=calendar:local_time(), status=ongoing, name_phone_list=NamePhoneList}),
    ok.

delete_meeting(UUID, MeetingId)->
    Meetings = get_meetings(UUID),
    NewMeetings = lists:delete(MeetingId, Meetings),
    ?DB_WRITE(#uuid_meetings{uuid=UUID, meeting_ids=NewMeetings}),
    ?DB_DELETE({meeting_detail, MeetingId}),
    ok.

get_meetings(UUID)->
    case ?DB_READ(uuid_meetings, UUID) of
        {atomic, [#uuid_meetings{meeting_ids=Meeting_Ids}]}-> Meeting_Ids;
        _-> []
    end.

get_meeting_detail(MeetingId)->
    case ?DB_READ(meeting_detail, MeetingId) of
        {atomic, [Meeting_Detail]}-> {ok, Meeting_Detail};
        _-> {failed, error_meeting_id}
    end.

end_meeting(MeetingId)->
    case get_meeting_detail(MeetingId) of
    {ok, Meeting_Detail=#meeting_detail{status=ongoing, name_phone_list=NamePhoneList}}->
        ?DB_WRITE(Meeting_Detail#meeting_detail{status=finished}),
        NamePhoneList;
    _-> []
    end.
    
append(MeetingId, Name, Phone)->
    {atomic, [Meeting_Detail=#meeting_detail{name_phone_list=PhoneList}]} = ?DB_READ(meeting_detail, MeetingId),
    ?DB_WRITE(Meeting_Detail#meeting_detail{meeting_id=MeetingId, name_phone_list=PhoneList++[{Name, Phone}]}),
    length(PhoneList)+1.
    
erase(MeetingId, Name, Phone)->
    {atomic, [Meeting_Detail=#meeting_detail{name_phone_list=PhoneList}]} = ?DB_READ(meeting_detail, MeetingId),
    NewPhoneList=PhoneList--[{Name, Phone}],
    ?DB_WRITE(Meeting_Detail#meeting_detail{meeting_id=MeetingId, name_phone_list=NewPhoneList}),
    length(NewPhoneList).
    
get_meeting_members(MeetingId)->
    {atomic, [#meeting_detail{name_phone_list=PhoneList}]} = ?DB_READ(meeting_detail, MeetingId),
    PhoneList.
    
get_templates(UUID)->
    case ?DB_READ(uuid_meeting_templates, UUID) of
        {atomic, [#uuid_meeting_templates{meeting_templates=Templates}]}-> Templates;
        _-> sets:new()
    end.

update_templates(_, [])->
    void;
update_templates(UUID, NamePhoneList)->
    S=get_templates(UUID),
    NewS = sets:add_element(sets:from_list(NamePhoneList), S),
    ?DB_WRITE(#uuid_meeting_templates{uuid=UUID, meeting_templates=NewS}).
