-module(sipcfg).
-compile(export_all).

% zte 鍏綉ss "202.122.107.42"   000888280086  000888290086(cli)
% 东方科技120.26.114.65 透传送2 隐藏送0
ssip(_) -> "202.122.107.42".%"113.105.152.156".%鐗ч洦绉戞妧閫�9 "112.124.1.103". %閫�2.%%%"120.27.36.134".%songshiwangluo. %202.122.107.42". %zte ss public    % "121.14.38.110". alpha   
myip() -> "119.29.62.190".    
get(sip_socket_ip)-> "10.251.64.90";
get(www_node)-> 'wcgwww@119.29.62.190'.
service_id()-> "".
callee_prefix()-> "9".  %"00088818".
group_callee_prefix({"fzd",_})->  "";
group_callee_prefix({"dth",_})->  "00088818";
group_callee_prefix({"xh",_})->  "00088818";
group_callee_prefix({"qvoice",_})->  "00099918";
group_callee_prefix({"livecom",Caller="1"++_}) when length(Caller)==11 ->  "00099918";
group_callee_prefix({"livecom",Caller="00861"++_}) when length(Caller)==15 ->  "00099918";
group_callee_prefix({"livecom",_Caller=[$0,Second|_]}) when Second=/=$0 ->  "00088839";
group_callee_prefix({"ZTE",Caller="1"++_}) when length(Caller)==11 ->  "00099918";
group_callee_prefix({"ZTE",Caller="00861"++_}) when length(Caller)==15 ->  "00099918";
group_callee_prefix(_)->  "00088818".

