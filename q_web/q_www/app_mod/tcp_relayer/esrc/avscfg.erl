-module(avscfg).
-compile(export_all).

get(host_ip) -> "10.61.34.58";

get(relay_udp_range) -> {55000,55009};
get(relay_tcp_port) -> 5678;

get(relay_proto) -> udp.
