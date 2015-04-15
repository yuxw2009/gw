%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork mvideo
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_mvideo).
-compile(export_all).
-include("lw.hrl").

make_failed_fun(Label,Rtn) ->
    fun(Reason) ->
        logger:log(error,"Label:~p Reason:~p~n",[Label,Reason]),
        Rtn
    end.

start_conf(UUID, SDP, Members) ->
    case local_user_info:check_org_res(UUID,videoconf,1) of
        ok ->
            case local_user_info:check_user_privilege(UUID,dataconf) of
                ok ->
                    IP   = lw_config:get_video_server_ip(),
                    Conf = "conf",
                    URL  = lw_lib:build_url(IP,Conf,[],[]),
                    NewMembers = utility:a2jsos([uuid,position],Members),
                    Body = rfc4627:encode(lw_lib:build_body([uuid,members],[UUID,NewMembers],[r,r])),
                    Json = lw_lib:httpc_call(post,{URL,Body}),
                    case lw_lib:parse_json(Json,[{room,b}],make_failed_fun({start_conf,UUID,SDP,Members},failed)) of
                        failed ->
                            local_user_info:release_org_res(UUID,videoconf,1),
                            failed;
                        {Room} ->
                            {UUID,Position}  = lists:keyfind(UUID,1,Members),
                            {value, RoomSDP} = enter_room(binary_to_list(Room), UUID, Position, SDP),
                            [invite_member(UUID, binary_to_list(Room), U, I)||{U,I}<-Members,U =/= UUID],
                            {value, Room, RoomSDP}
                    end;
                Other ->
                    Other
            end;
        out_of_res ->
            out_of_res
    end.

enter_room(RoomNo, UUID, Position, SDP) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf/" ++ RoomNo,
    URL  = lw_lib:build_url(IP,Conf,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,position,sdp],[UUID,Position,SDP],[r,r,r])),
    Json = lw_lib:httpc_call(put,{URL,Body}),
    case lw_lib:parse_json(Json,[{sdp,b}],make_failed_fun({enter_room,RoomNo,UUID,Position,SDP},failed)) of
        failed ->
            failed;
        {RoomSdp} ->
            {value, RoomSdp}
    end.

leave_room(RoomNo, UUID) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf/" ++ RoomNo,
    URL  = lw_lib:build_url(IP,Conf,[uuid],[UUID]),
    Json = lw_lib:httpc_call(delete,{URL}),
    case lw_lib:parse_json(Json,[{status,a}],make_failed_fun({leave_room,RoomNo,UUID},failed)) of
        failed ->
            failed;
        {ok} ->
            ok
    end.

invite_member(UUID, Room, Guest, Position) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf/" ++ Room ++ "/members",
    URL  = lw_lib:build_url(IP,Conf,[],[]),
    Body = rfc4627:encode(lw_lib:build_body([uuid,position],[Guest,Position],[r,r])),
    Json = lw_lib:httpc_call(put,{URL,Body}),
    case lw_lib:parse_json(Json,[{status,a}],make_failed_fun({invite_member,UUID, Room, Guest, Position},failed)) of
        failed ->
            failed;
        {ok} ->
            lw_instance:new_mvideo_invite(UUID,Guest,list_to_binary(Room),Position),
            ok
    end.

query_ongoing_room(UUID) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf/ongoing",
    URL  = lw_lib:build_url(IP,Conf,[uuid],[UUID]),
    Json = lw_lib:httpc_call(get,{URL}),
    case lw_lib:parse_json(Json,[{room,b}],make_failed_fun({query_ongoing_room,UUID},failed)) of
        failed ->
            failed;
        {<<"">>} ->
            room_not_exist;
        {RoomNo} ->
            {Chairman,Position} = lw_lib:parse_json(Json,[{chairman,i},{position,i}],0),
            {ok, RoomNo, Chairman, Position}
    end.

stop_conf(UUID, Room) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf",
    URL  = lw_lib:build_url(IP,Conf,[uuid,room],[UUID,Room]),
    Json = lw_lib:httpc_call(delete,{URL}),
    case lw_lib:parse_json(Json,[{status,a}],make_failed_fun({stop_conf,UUID,Room},failed)) of
        failed ->
            failed;
        {ok} ->
            local_user_info:release_org_res(UUID,videoconf,1),
            ok
    end.

get_room_status(UUID, Room) ->
    IP   = lw_config:get_video_server_ip(),
    Conf = "conf/status",
    URL  = lw_lib:build_url(IP,Conf,[uuid,room],[UUID,Room]),
    Json = lw_lib:httpc_call(get,{URL}),
    case lw_lib:parse_json(Json,[{room_status,ao,[{uuid,i},{position,i},{status,a}]}],make_failed_fun({get_room_status,UUID,Room},failed)) of
        failed ->
            failed;
        {Status} ->
            {value,Status}
    end.
