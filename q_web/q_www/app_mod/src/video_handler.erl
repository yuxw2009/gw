%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/video
%%%------------------------------------------------------------------------------------------
-module(video_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% POST /lwork/video   : {uuid:FU, sdp:SDP, to_uuid:TU}
%% handle start P2P video
handle(Arg, 'POST', []) ->
    {FromUUID, SDP, ToUUID} 
        = utility:decode(Arg, [{uuid,i},{sdp, b}, {to_uuid, i}]),

    {value, PeerSdp} = 
        rpc:call(snode:get_service_node(), lw_instance, new_video_invite, [FromUUID, ToUUID, SDP]),
    
    utility:pl2jso([{status,ok},{peer_sdp, PeerSdp}]);


%% handle accept peer invite
handle(Arg, 'PUT', []) ->
    {UUID, SDP, FromUUID, ReceiverPid} = utility:decode(Arg, [{uuid,i},{sdp, b},{from_uuid, i}, {revc_pid, s}]),

    ok = rpc:call(snode:get_service_node(), lw_instance, accept_video_invite, 
                                             [UUID, SDP, FromUUID, ReceiverPid]),
    utility:pl2jso([{status,ok}]);

%% handle stop p2p video
handle(Arg, 'DELETE', []) ->
    UUID = utility:query_integer(Arg, "uuid"),
    PeerUUID = utility:query_integer(Arg, "peer_uuid"),
        
    ok = rpc:call(snode:get_service_node(), lw_instance, stop_video, [UUID, PeerUUID]),
    utility:pl2jso([{status,ok}]).