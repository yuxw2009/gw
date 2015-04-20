-module(meeting_api).
-compile(export_all).
-include("meeting.hrl").
-include("call.hrl").

get_history(UUID)->
    MeetingIds = meeting_db:get_meetings(UUID),
    Qeuries = [meeting_db:get_meeting_detail(MeetingId) || MeetingId<-MeetingIds],
    Meeting_Details = [I || {ok, I}<-Qeuries],
    Values = 
    [{MeetingId, Subject, StartTime, Status, 
      lists:zipwith(fun(I, {N,P})-> 
                                 {I,N,P};
                              (I, {N,P,_})->
                                {I,N,P} 
                          end, 
                         lists:seq(1, length(NamePhoneList)), NamePhoneList)}
            || #meeting_detail{meeting_id=MeetingId, subject=Subject, start_time=StartTime, status=Status, 
                                            name_phone_list=NamePhoneList} <-Meeting_Details],
    {value, Values}.

start_meeting(Plist)->
%    NamePhoneList = lists:map(fun({Name, Phone, _})-> {Name, Phone} end, Phones),
    Key = proplists:get_value(key, Plist),
%    Audit_info = proplists:get_value(audit_info, Plist),
    Members = proplists:get_value(members, Plist),
    Session_id = proplists:get_value(session_id, Plist),
    Subject="",

    operator:meeting(Plist),
    R = wait_ack(),
    io:format("start_meeting Result: ~p~n", [R]),    
    case R of
        {value,{{meeting_id, Confname}, {members, _Members}}}->
            meeting_db:add_meeting(Key, Confname, Subject, Members),
            F=fun(I, {Name, Phone})-> {I, connecting, Name, Phone} end,
            MembersLists = lists:zipwith(F, lists:seq(1, length(Members)), Members),
            {value,Confname, MembersLists};
         _-> {failed, R}
    end.
    
create(UUID, Subject, NamePhoneList)->
    PhoneList = [Phone || {_,Phone} <- NamePhoneList],
    operator:conf_test(UUID, PhoneList),
    R = wait_ack(),
    case R of
        {value,{{meeting_id, Confname}, {members, _Members}}}->
            meeting_db:add_meeting(UUID, Confname, Subject, NamePhoneList),
            F=fun(I, {Name, Phone})-> {I, connecting, Name, Phone} end,
            MembersLists = lists:zipwith(F, lists:seq(1, length(NamePhoneList)), NamePhoneList),
            {value,Confname, MembersLists};
         _-> {failed, R}
    end.

delete_meeting(UUID,MeetingId)->
    meeting_db:delete_meeting(UUID, MeetingId).

end_meeting(UUID, MeetingId)->
    operator:stop(UUID),
    NamePhoneList=meeting_db:end_meeting(MeetingId),
    meeting_db:update_templates(UUID, NamePhoneList),
    ok.

get_active_meeting(UUID)->
    operator ! {self(), {get_active_meeting, UUID}},
    case wait_ack() of
        {value, {MeetingId, Active_Status_MeetingItems}}-> 
            StaticMembers=meeting_db:get_meeting_members(MeetingId),
            F=fun(I, {Seq, Acc})->
                {Name,Phone,_Rate} = case I of
                                                        {N1,P1}-> {N1,P1,0.1};
                                                        _-> I
                                                   end,
                case [{Status, N, P} ||{Status,#meeting_item{name=N,phone=P}}<-Active_Status_MeetingItems, N=:=Name, P=:=Phone] of
                    [{ready,_,_}|_]->  {Seq+1, Acc++[{Seq, online, Name, Phone}]};
                    [{_,_,_}|_]->  {Seq+1, Acc++[{Seq, connecting, Name, Phone}]};
        	    _-> {Seq+1, Acc++[{Seq, offline, Name, Phone}]}
        	end 
            end,
            {_, Member_Status_List} = lists:foldl(F, {1, []}, StaticMembers),
            {value, [{MeetingId, Member_Status_List}]};
        _-> {value, []}
    end.

get_details(UUID, MeetingId)->
    operator ! {self(), {get_status, UUID}},
    Members=meeting_db:get_meeting_members(MeetingId),
    ActiveMembers = case wait_ack() of
        {value, V}-> V;
        _-> []
    end,
    F=fun({Name,Phone}, {Seq, Result})->
	case lists:keyfind(Phone, 3, ActiveMembers) of
	    {_, ready, _}-> {Seq+1, Result++[{Seq, online, Name, Phone}]};
	    _-> {Seq+1, Result++[{Seq, offline, Name, Phone}]}
	end end,
    {_, Member_Status_List} = lists:foldl(F, {1, []}, Members),

    {ok, #meeting_detail{status = MeetingStatus} } = meeting_db:get_meeting_detail(MeetingId),
    {value, MeetingStatus, Member_Status_List}.
    

redail(UUID, MeetingId, MemberId)->
    Members=meeting_db:get_meeting_members(MeetingId),
    try lists:nth(MemberId, Members) of
        Member-> operator ! {self(), {join_conf,UUID,[Member]}},
        ok
    catch
        _-> {failed, error_member_id}
    end.
    
join(UUID, MeetingId, Name, Phone)->
    operator ! {self(), {join_conf,UUID,[{Name, Phone}]}},
    Seq=meeting_db:append(MeetingId, Name, Phone),
    {value, {Seq, connecting, Name, Phone}}.
    
unjoin(UUID, MeetingId, Name, Phone)->
    operator ! {self(), {unjoin_conf,UUID,[{Name, Phone}]}},
    meeting_db:erase(MeetingId, Name, Phone),
    ok.
    
wait_ack()->
    receive
    M={value,_}->  M;
    {ack, V}->  V;
    session_not_exist-> session_not_exist;
    {call_failed, _UUID, session_already_exist}-> session_already_exist
    after 2000->
        timeout
    end.

get_template(UUID)->
    S=meeting_db:get_templates(UUID),
    [sets:to_list(I) || I<-sets:to_list(S)].
