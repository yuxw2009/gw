-module(avscfg).
-compile(export_all).

% modified this file as your server configuration.

%% public IP
get(host_ip) -> "58.221.60.37";
get(internal_ip) -> "58.221.60.37";  % media server ip for internal media
get(ip4sip) ->  "58.221.60.37";

get(web_socket_ip) -> "58.221.60.37";
get(sip_socket_ip) -> "58.221.60.37";


get(sip_app_node) -> {voip_ua, 'voice@58.221.60.37'};
get(max_calls) -> 600;


get(web_codec) -> ilbc; 
get(sip_codec) -> g729;

get(ss_udp_range)  ->  {16000,17000};
get(web_udp_range) ->  {56000,57000};

get(web_proto) -> udp;
get(certificate) -> {"./webRTCVoIP.pem", "./webRTCVoIP_key.pem"};

%get(wcgs)-> [{gw,"/yyy/yyy/gw"}];
get(monitor)-> 'monitor@58.221.60.37';
get(codec_node)->node();
get(www)-> 'www_t@58.221.60.37';
% not used yet
get(wan_ip) -> avscfg:get(host_ip);
get(wcall_cid) -> "0085268895100";
get(mhost_ip) -> "58.221.60.37";
get(mweb_udp_range) -> {55000,57000};
get(wconf_udp_range) -> {55010,55110};
get(room_udp_used) -> 7.

get_root()-> "/home/wcg/run/gw_test_copy1/applications/".
get_node(_)-> node().




