-module(avscfg).
-compile(export_all).

% modified this file as your server configuration.

%% public IP
get(host_ip) -> "112.74.96.171";
get(internal_ip) -> "112.74.96.171";  % media server ip for internal media
get(ip4sip) ->  "112.74.96.171";

get(web_socket_ip) -> "112.74.96.171";
get(sip_socket_ip) -> "112.74.96.171";


get(sip_app_node) -> {voip_ua, 'voicezte@119.29.62.190'};%{voip_ua, 'qvoice@112.74.96.171'};%
get(max_calls) -> 10;


get(webrtc_web_codec) -> ilbc; 
get(web_codec) -> ilbc; 
get(sip_codec) -> pcmu;

get(ss_udp_range)  ->  {16000,17000};
get(web_udp_range) ->  {56000,57000};

get(web_proto) -> udp;
get(certificate) -> {"./webRTCVoIP.pem", "./webRTCVoIP_key.pem"};

%get(wcgs)-> [{gw,"/yyy/yyy/gw"}];
get(monitor)-> 'monitor@127.74.96.171';
get(codec_node)->node();
get(www)-> 'www_t@127.74.96.171';
% not used yet
get(wan_ip) -> avscfg:get(host_ip);
get(wcall_cid) -> "0085268895100";
get(mhost_ip) -> "112.74.96.171";
get(mweb_udp_range) -> {55000,57000};
get(wconf_udp_range) -> {55010,55110};
get(room_udp_used) -> 7;
get(custom) -> yj;
get(qq_interval)->"1.175";  %  1.53
get(_) -> "".

get_vcr()->no_vcr.
get_root()-> "/home/ubuntu/ttt/gw/applications/".
get_node(_)-> node().

% for qvoice
get_data_path()-> "/data/qqjf/".
get_self_percent()-> 1.0.

% for ltalk
get_mhost(_RemoteIp)->
    io:format("avscfg:get_mhost:~p~n",[_RemoteIp]),
    get_mhost1(_RemoteIp).
get_mhost1(_RemoteIp="10."++_)-> avscfg:get(internal_ip);
get_mhost1(_RemoteIp="203.222.195.122")-> avscfg:get(internal_ip);
get_mhost1(_RemoteIp)-> avscfg:get(host_ip).

get_regco()->"/home/ubuntu/ttt/gw/applications/music_back/UnixReco".
get_vcr_path()-> get_data_path()++"vcr_rec6/".
