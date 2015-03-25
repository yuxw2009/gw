-module(avscfg).
-compile(export_all).

% modified this file as your server configuration.

%% public IP
get(host_ip) -> "119.29.62.190";
get(internal_ip) -> "119.29.62.190";  % media server ip for internal media
get(ip4sip) ->  "119.29.62.190";

get(web_socket_ip) -> "10.251.64.90";
get(sip_socket_ip) -> "10.251.64.90";


get(sip_app_node) -> {voip_ua, 'voice_ext@fc2fc.com'}; %{voip_ua, 'voice@58.221.60.121'};
get(max_calls) -> 600;


get(web_codec) -> amr; 
get(sip_codec) -> pcmu;

get(ss_udp_range)  ->  {16000,17000};
get(web_udp_range) ->  {56000,57000};

get(web_proto) -> udp;
get(certificate) -> {"./webRTCVoIP.pem", "./webRTCVoIP_key.pem"};

%get(wcgs)-> [{gw,"/yyy/yyy/gw"}];
get(monitor)-> 'monitor@119.29.62.190';
get(codec_node)->node();
get(www)-> 'www_t@119.29.62.190';
% not used yet
get(wan_ip) -> avscfg:get(host_ip);
get(wcall_cid) -> "0085268895100";
get(mhost_ip) -> "119.29.62.190";
get(mweb_udp_range) -> {55000,57000};
get(wconf_udp_range) -> {55010,55110};
get(room_udp_used) -> 7.

get_vcr()->no_vcr.
get_root()-> "/home/ubuntu/ttt/gw/applications/".
get_node(_)-> node().

get_self_percent()->  0.1.



