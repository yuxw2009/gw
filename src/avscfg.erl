-module(avscfg).
-compile(export_all).

% modified this file as your server configuration.

%% public IP
get(host_ip) -> "14.17.107.196";
get(internal_ip) -> "14.17.107.196";  % media server ip for internal media
get(ip4sip) ->  "14.17.107.196";

get(web_socket_ip) -> "14.17.107.196";
get(sip_socket_ip) -> "14.17.107.196";


get(sip_app_node) -> {voip_ua, 'voice@58.221.60.37'};
get(max_calls) -> 600;


get(web_codec) -> ilbc; 
get(sip_codec) -> g729;

get(ss_udp_range)  ->  {15000,16000};
get(web_udp_range) ->  {55000,56000};

get(web_proto) -> udp;
get(certificate) -> {"./webRTCVoIP.pem", "./webRTCVoIP_key.pem"};


% not used yet
get(wan_ip) -> avscfg:get(host_ip);
get(wcall_cid) -> "0085268895100";
get(mhost_ip) -> "202.122.107.66";
get(mweb_udp_range) -> {55000,55009};
get(wconf_udp_range) -> {55010,55110};
get(room_udp_used) -> 7.





