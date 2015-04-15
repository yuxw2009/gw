-module(lw_media_srv).
-compile(export_all).

-include("lw.hrl").

%%-------------------------------------------------------------------------------------------------

start() ->
    AllOrgID = mnesia:dirty_all_keys(lw_org_attr),
    AllOrgMediaSrvName = [build_org_media_srv_name(OrgID)||OrgID<-AllOrgID],
    [zserver:start(OrgMediaSrvName,lw_org_media_srv,[])||OrgMediaSrvName<-AllOrgMediaSrvName],
    zserver:start(?MODULE,?MODULE,[]).

%%-------------------------------------------------------------------------------------------------

stop() ->
    zserver:stop(?MODULE).

%%-------------------------------------------------------------------------------------------------

start_meeting(UUID,GroupId,Subject,Phones,MaxMeetingTime) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
    	failed ->
    	    failed;
    	Server ->
    	    zserver:call(Server,{start_meeting,{UUID,GroupId,Subject,Phones,MaxMeetingTime}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

stop_meeting(UUID, MeetingId) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
    	failed ->
    	    failed;
    	Server ->
    	    zserver:call(Server,{stop_meeting,{UUID,MeetingId}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

get_active_meetings(UUID) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
        failed ->
            failed;
        Server ->
            zserver:call(Server,{get_active_meetings,{UUID}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

get_active_meeting_member_status(UUID,_MeetingId) ->
    case get_active_meetings(UUID) of
    	failed -> 
    	    failed;
    	ActiveMeetings ->
		    case ActiveMeetings of
		        [{_, AM}|_] -> [{MemberId, Status} || {MemberId, Status, _, _}<- AM];
		        [] -> [];
		        Other -> Other
		    end
	end.

%%-------------------------------------------------------------------------------------------------

join_meeting_member(UUID, MeetingId, Name, Phone) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
        failed ->
            failed;
        Server ->
            zserver:call(Server,{join_meeting_member,{UUID, MeetingId, Name, Phone}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

hangup_meeting_member(UUID, MeetingId, MemberId) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
        failed ->
            failed;
        Server ->
            zserver:call(Server,{hangup_meeting_member,{UUID, MeetingId, MemberId}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

redial_meeting_member(UUID, MeetingId, MemberId) ->
    case zserver:call(?MODULE,{choose_org_mtg_srv,UUID},5000) of
        failed ->
            failed;
        Server ->
            zserver:call(Server,{redial_meeting_member,{UUID, MeetingId, MemberId}},5000)
    end.

%%-------------------------------------------------------------------------------------------------

handle(call,{_,_,{choose_org_mtg_srv,UUID}},State) ->
    Proc = [{fun get_user_ins/1,{reply,{failed,State}}},
            {fun get_org_media_srv_name/1,{reply,{failed,State}}},
            {fun check_srv_alive/1,{reply,{failed,State}}}],
    apply(lw_lib:eval(Proc),[{UUID,State}]).

%%-------------------------------------------------------------------------------------------------

get_user_ins({UUID,State}) ->
    Val = mnesia:dirty_read(lw_instance,UUID),
    {[] =/= Val,{Val,State}}.

get_org_media_srv_name({[#lw_instance{org_id = OrgID}],State}) ->
    Val = get_org_media_srv_name(OrgID),
    {undefined =/= Val,{Val,State}};

get_org_media_srv_name(OrgID) when is_integer(OrgID) ->
    try list_to_existing_atom("org_media_srv" ++ integer_to_list(OrgID))
    catch
        _:_ -> undefined
    end.

check_srv_alive({SrvName,State}) ->
    Val = whereis(SrvName),
    {undefined =/= Val,{reply,{SrvName,State}}}.

%%-------------------------------------------------------------------------------------------------

build_org_media_srv_name(OrgID) ->
    list_to_atom("org_media_srv" ++ integer_to_list(OrgID)).

%%-------------------------------------------------------------------------------------------------