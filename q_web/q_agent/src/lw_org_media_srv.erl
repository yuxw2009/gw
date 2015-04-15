-module(lw_org_media_srv).
-compile(export_all).

-define(SMS,"xengine/sms").
-define(MEETING_MEMBER,"xengine/meetings/members").
-define(MEETING,"xengine/meetings").
-define(CALLBACK,"xengine/callbacks").
-define(VOIP,"xengine/voip").

-include("lw.hrl").

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{start_meeting,{UUID,GroupId,Subject,Phones,MaxMeetingTime}}},State) ->
    AddNum = length(Phones),
    case check_privilege(UUID,phoneconf,AddNum) of
    	ok ->
            spawn(fun() -> do_start_meeting(Name,From,AddNum,UUID,GroupId,Subject,Phones,MaxMeetingTime) end),
            {no_reply,{ok,State}};
    	Other -> 
            {reply,{Other,State}}
    end;

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{stop_meeting,{UUID,MeetingId}}},State) ->
    spawn(fun() -> do_stop_meeting(Name,From,UUID,MeetingId) end),
    {no_reply,{ok,State}};

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{join_meeting_member,{UUID,MeetingId,UserName,Phone}}},State) ->
    case check_privilege(UUID,phoneconf,1) of
        ok ->
            local_user_info:add_org_meeting_num(MeetingId,1),
            spawn(fun() -> join_meeting_member(Name,From,UUID,MeetingId,UserName,Phone) end),
            {no_reply,{ok,State}};
        Other -> 
            {reply,{Other,State}}
    end;

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{hangup_meeting_member,{UUID,MeetingId,MemberId}}},State) ->
    spawn(fun() -> hangup_meeting_member(Name,From,UUID,MeetingId,MemberId) end),
    {no_reply,{ok,State}};

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{redial_meeting_member,{UUID,MeetingId,MemberId}}},State) ->
    spawn(fun() -> redial_meeting_member(Name,From,UUID,MeetingId,MemberId) end),
    {no_reply,{ok,State}};

%%-------------------------------------------------------------------------------------------------

handle(call,{Name,From,{get_active_meetings,{UUID}}},State) ->
    spawn(fun() -> get_active_meetings(Name,From,UUID) end),
    {no_reply,{ok,State}};

%%-------------------------------------------------------------------------------------------------

handle(cast,{_,{release_org_res,{UUID,Type,Num}}},State) ->
    release_org_res(UUID,Type,Num),
    {no_reply,{ok,State}};

handle(cast,{_,{release_org_res,{UUID,MeetingId,Type,Num}}},State) ->
    local_user_info:del_org_meeting_num(MeetingId,Num),
    release_org_res(UUID,Type,Num),
    {no_reply,{ok,State}};

%%-------------------------------------------------------------------------------------------------

handle(cast,{_,{release_meeting,{UUID,Type,MeetingId}}},State) ->
    Num = local_user_info:del_org_meeting(MeetingId),
    release_org_res(UUID,Type,Num),
    {no_reply,{ok,State}}.

%%-------------------------------------------------------------------------------------------------

release_org_res(UUID,Type,Num) ->
    [#lw_instance{org_id = OrgID}] = mnesia:dirty_read(lw_instance,UUID),
    [OrgRes] = mnesia:dirty_read(lw_org_attr,OrgID),
    NewOrgRes = updateRes(del,Num,Type,OrgRes),
    mnesia:dirty_write(NewOrgRes).

%%-------------------------------------------------------------------------------------------------

check_privilege(UUID,Type,AddNum) ->
    Proc = get_check_proc(Type),
    apply(lw_lib:eval(Proc),[{UUID,Type,AddNum}]).

%%-------------------------------------------------------------------------------------------------

do_start_meeting(Name,From,Num,UUID,GroupId,Subject,Phones,MaxMeetingTime) ->
    case catch do_start_meeting(UUID,GroupId,Subject,Phones,MaxMeetingTime) of
        {'EXIT', _Reason} -> 
            lw_voice:save_meeting(UUID,meeting_failed,Subject,Phones),
            zserver:cast(Name,{release_org_res,{UUID,phoneconf,Num}}),
            From ! {Name,failed};
        {MeetingId,MeetingDetails} ->
            lw_voice:save_meeting(UUID,MeetingId,Subject,Phones),
            local_user_info:create_org_meeting(MeetingId,Num),
            try From ! {Name,{MeetingId,MeetingDetails}}
            catch _:_ -> ok end,
            start_meeting_monitor(Name,UUID,MeetingId)
    end.

do_start_meeting(UUID,_GroupId,_Subject,Phones,_MaxMeetingTime) ->
    IP    = lw_config:get_ct_server_ip(),
    MEET  = ?MEETING,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
    [{Name,Phone}|Rest] = lw_voice:get_binary_phones(Phones),
    Host    = utility:pl2jso([{name,Name},{phone,Phone}]),
    Members = utility:a2jsos([name,phone],Rest),
    Body = rfc4627:encode(lw_lib:build_body([host,members],[Host,Members],[r,r],{audit_info,UUID})),
    Json = lw_lib:httpc_call(post,{URL,Body}),
    utility:decode_json(Json,[{session_id,s},{member_info,ao,[{member_id,i},{status,a},{name,b},{phone,s}]}]).

%%-------------------------------------------------------------------------------------------------

do_stop_meeting(Name,From,UUID,MeetingId) ->
    case catch do_stop_meeting(UUID,MeetingId) of
        {'EXIT', _Reason} ->
            From ! {Name,failed};
        ok ->
            zserver:cast(Name,{release_meeting,{UUID,phoneconf,MeetingId}}),
            From ! {Name,ok}
    end.

do_stop_meeting(UUID,MeetingId) ->
    IP    = lw_config:get_ct_server_ip(),
    MEET  = ?MEETING,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
    Json  = lw_lib:httpc_call(delete,{URL}),
    "ok"  = utility:get_string(Json,"status"),
    ok.

%%-------------------------------------------------------------------------------------------------

hangup_meeting_member(Name,From,UUID,MeetingId,MemberId) ->
    case catch hangup_meeting_member(UUID,MeetingId,MemberId) of
        {'EXIT', _Reason} ->
            From ! {Name,failed};
        ok ->
            From ! {Name,ok}
    end.

hangup_meeting_member(UUID,MeetingId,MemberId) ->
    IP     = lw_config:get_ct_server_ip(),
    Member = ?MEETING_MEMBER,
    SerID  = lw_config:get_serid(),
    URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
    Body   = rfc4627:encode(lw_lib:build_body([member_id,status],[integer_to_list(MemberId),offline],[b,r])),
    Json   = lw_lib:httpc_call(put,{URL,Body}),
    "ok"   = utility:get_string(Json,"status"),
    ok.

%%-------------------------------------------------------------------------------------------------

redial_meeting_member(Name,From,UUID,MeetingId,MemberId) ->
    case catch redial_meeting_member(UUID,MeetingId,MemberId) of
        {'EXIT', _Reason} ->
            From ! {Name,failed};
        ok ->
            From ! {Name,ok}
    end.

redial_meeting_member(UUID,MeetingId,MemberId) ->
    IP     = lw_config:get_ct_server_ip(),
    Member = ?MEETING_MEMBER,
    SerID  = lw_config:get_serid(),
    URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
    Body   = rfc4627:encode(lw_lib:build_body([member_id,status],[integer_to_list(MemberId),online],[b,r])),
    Json   = lw_lib:httpc_call(put,{URL,Body}),
    "ok"   = utility:get_string(Json,"status"),
    ok.

%%-------------------------------------------------------------------------------------------------

join_meeting_member(Name,From,UUID,MeetingId,UserName,Phone) ->
    case catch join_meeting_member(UUID,MeetingId,UserName,Phone) of
        {'EXIT', _Reason} -> 
            zserver:cast(Name,{release_org_res,{UUID,MeetingId,phoneconf,1}}),
            From ! {Name,failed};
        Other ->
            From ! {Name,Other}
    end.

join_meeting_member(UUID,MeetingId,Name,Phone) ->
    lw_voice:add_meeting_member(UUID,MeetingId,{Name,Phone,0.0}),
    IP     = lw_config:get_ct_server_ip(),
    Member = ?MEETING_MEMBER,
    SerID  = lw_config:get_serid(),
    URL    = lw_lib:build_url(IP,Member,[service_id,seq_no,auth_code,uuid,session_id],[SerID,1,1,UUID,MeetingId]),
    Body   = rfc4627:encode(lw_lib:build_body([name,phone],[Name,Phone],[r,b])),
    Json   = lw_lib:httpc_call(post,{URL,Body}),
    {Rtn}  = utility:decode_json(Json,[{member_info,o,[{member_id,i},{status,a},{name,b},{phone,s}]}]),
    Rtn.

%%-------------------------------------------------------------------------------------------------

get_active_meetings(Name,From,UUID) ->
    case catch get_active_meetings(UUID) of
        {'EXIT', _Reason} -> 
            From ! {Name,failed};
        Other ->
            From ! {Name,Other}
    end.

get_active_meetings(UUID) ->
    IP    = lw_config:get_ct_server_ip(),
    MEET  = ?MEETING,
    SerID = lw_config:get_serid(),
    URL   = lw_lib:build_url(IP,MEET,[service_id,seq_no,auth_code,uuid],[SerID,1,1,UUID]),
    Json  = lw_lib:httpc_call(get,{URL}),
    {Rtn} = utility:decode_json(Json,[{meetings,ao,[{session_id,s},{member_info,ao,[{member_id,i},{status,a},{name,b},{phone,s}]}]}]),
    Rtn.

%%-------------------------------------------------------------------------------------------------

get_check_proc(phoneconf) ->
    [{fun get_user_ins/1,disable},
     {fun check_org_banalce/1,org_out_of_money},
     {fun check_user_priv/1,disable},
     {fun check_user_balance/1,out_of_money},
     {fun query_media_res/1,out_of_res},
     {fun add_media_res/1,never_happen}].

%%-------------------------------------------------------------------------------------------------

get_user_ins({UUID,Type,AddNum}) ->  
    Val = mnesia:dirty_read(lw_instance,UUID),
    {[] =/= Val,{Val,Type,AddNum}}.

%%-------------------------------------------------------------------------------------------------

check_org_banalce({[#lw_instance{org_id = OrgID,reverse = Priv}],Type,Num}) ->
    [#lw_org_attr{cost = {Cur,Max}}] = mnesia:dirty_read(lw_org_attr,OrgID),
    {Cur < Max,{Type,OrgID,Priv,Num}}.

%%-------------------------------------------------------------------------------------------------

check_user_priv({Type,OrgID,Priv,Num}) ->
    {lists:keymember(Type,1,Priv),{Type,OrgID,Priv,Num}}.

%%-------------------------------------------------------------------------------------------------

check_user_balance({Type,OrgID,Priv,Num}) ->
    {balance,Balance} = lists:keyfind(balance,1,Priv),
    {cost,Cost} = lists:keyfind(cost,1,Priv),
    {Cost < Balance,{Type,OrgID,Priv,Num}}.

%%-------------------------------------------------------------------------------------------------

query_media_res({Type,OrgID,Priv,Num}) ->
    [OrgRes] = mnesia:dirty_read(lw_org_attr,OrgID),
    case Type of
        phoneconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.phone,
            {Cur + Num =< Max,{Type,OrgID,Priv,Num,OrgRes}};
        videoconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.video,
            {Cur + Num =< Max,{Type,OrgID,Priv,Num,OrgRes}}
    end.

%%-------------------------------------------------------------------------------------------------

add_media_res({Type,_,_,Num,OrgRes}) ->
    NewOrgRes = updateRes(add,Num,Type,OrgRes),
    mnesia:dirty_write(NewOrgRes),
    {true,ok}.

%%-------------------------------------------------------------------------------------------------

updateRes(add,Num,Type,OrgRes) ->
    case Type of
        phoneconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.phone,
            OrgRes#lw_org_attr{phone = {Cur + Num,Max}};
        videoconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.video,
            OrgRes#lw_org_attr{video = {Cur + Num,Max}}
    end;

updateRes(del,Num,Type,OrgRes) ->
    case Type of
        phoneconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.phone,
            OrgRes#lw_org_attr{phone = {Cur - Num,Max}};
        videoconf -> 
            {Cur,Max} = OrgRes#lw_org_attr.video,
            OrgRes#lw_org_attr{video = {Cur - Num,Max}}
    end.

%%-------------------------------------------------------------------------------------------------

start_meeting_monitor(Name,UUID,MeetingID) ->
    TRef = erlang:send_after(10 * 1000, self(), monitor),
    meeting_monitor_loop(Name,UUID,MeetingID,TRef).

meeting_monitor_loop(Name,UUID,MeetingID,TRef) ->
    receive
        monitor ->
            erlang:cancel_timer(TRef),
            case zserver:call(Name,{get_active_meetings,{UUID}},5000) of
                [] ->
                    zserver:cast(Name,{release_meeting,{UUID,phoneconf,MeetingID}});
                _ ->
                    NewTRef = erlang:send_after(10 * 1000, self(), monitor),
                    meeting_monitor_loop(Name,UUID,MeetingID,NewTRef)
            end
    end.

%%-------------------------------------------------------------------------------------------------