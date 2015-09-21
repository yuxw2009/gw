-module(avscfg).
-compile(export_all).

% modified this file as your server configuration.

%% public IP
get(host_ip) -> "202.122.107.66";
get(internal_ip) -> "10.32.3.52";  % media server ip for internal media
get(ip4sip) ->  "10.32.3.52";

get(web_socket_ip) -> "202.122.107.66";
get(sip_socket_ip) -> "10.32.3.52";


get(sip_app_node) -> {voip_ua, 'voice@10.32.7.28'};
get(max_calls) -> 600;

get(webrtc_web_codec) -> ilbc; 
get(web_codec) -> ilbc; 
get(sip_codec) -> pcmu;

get(ss_udp_range)  ->  {15000,16000};
get(web_udp_range) ->  {55000,56000};

get(web_proto) -> udp;
get(certificate) -> {"./webRTCVoIP.pem", "./webRTCVoIP_key.pem"};

%get(wcgs)-> [{gw,"/yyy/yyy/gw"}];
get(monitor)-> 'monitor@202.122.107.66';
get(codec_node)-> 'codec@202.122.107.66';%node(); %'codec@202.122.107.66';
get(www)-> 'www_t@202.122.107.66';
% not used yet
get(wan_ip) -> avscfg:get(host_ip);
get(wcall_cid) -> "0085268895100";
get(mhost_ip) -> "202.122.107.66";
get(mweb_udp_range) -> {55000,57000};
get(wconf_udp_range) -> {55010,55110};
get(room_udp_used) -> 7;
get(_)->undefined.

get_vcr()->has_vcr.
get_root()-> "./".
get_node(_)-> node().

get_mhost(_RemoteIp)->
    io:format("avscfg:get_mhost:~p~n",[_RemoteIp]),
    get_mhost1(_RemoteIp).
get_mhost1(_RemoteIp="10."++_)-> avscfg:get(internal_ip);
get_mhost1(_RemoteIp="203.222.195.122")-> avscfg:get(internal_ip);
get_mhost1(_RemoteIp)-> avscfg:get(host_ip).


