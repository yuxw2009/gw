-module(sipcfg).
-compile(export_all).

ssip() -> "202.122.107.42". %zte ss public    % "121.14.38.110". alpha
myip() -> "58.221.60.121".    
get(sip_socket_ip)-> "10.32.7.28";
get(www_node)-> 'www@58.221.60.121'.
service_id()-> "fzd".
callee_prefix()-> "".  %"00088818".
group_callee_prefix({"fzd",_})->  "";
group_callee_prefix({"dth",_})->  "00088818";
group_callee_prefix({"xh",_})->  "00088818";
group_callee_prefix({"livecom",Caller="1"++_}) when length(Caller)==11 ->  "00099918";
group_callee_prefix(_)->  "00088818".


