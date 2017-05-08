-module(sipcfg).
-compile(export_all).

myip()->   "10.32.7.28".
ssip() -> "10.32.4.11".
get(sip_socket_ip)-> "10.32.7.28";
get(www_node)-> 'www_dth@10.32.3.52'.
service_id()-> "ml".
callee_prefix()-> "00088818".

group_callee_prefix(UUID)->  group_callee_prefix(UUID,"").

% chinese number all 00099918  
group_callee_prefix({GroupId,_Caller},[I1,I2,I3,I4|_]) when [I1,I2] =/= "00" orelse [I1,I2,I3,I4]=="0086"->  "00099918";
group_callee_prefix({"xxkj",_Caller},"0086"++_)  ->  "*003773";
group_callee_prefix({"dth",_},_)->  "00088818";
group_callee_prefix({"xh",_Caller="0"++_},_) ->  "00088839";
group_callee_prefix({"xh",_},_)->  "00088818";
group_callee_prefix({qvoice,_},_)->  "00099918";
group_callee_prefix({"qvoice",_},_)->  "00099918";

%group_callee_prefix({"livecom",Caller="1"++_},_) when length(Caller)==11 ->  "00099918";
%group_callee_prefix({"livecom",Caller="00861"++_},_) when length(Caller)==15 ->  "00099918";
%group_callee_prefix({"livecom",_Caller=[$0,Second|_]},_) when Second=/=$0 ->  "00088839";
group_callee_prefix({"livecom",_},_) ->  "00099918";
group_callee_prefix({"莱恩克",Caller="1"++_},_) when length(Caller)==11 ->  "00088818";
group_callee_prefix({"莱恩克",Caller="00861"++_},_) when length(Caller)==15 ->  "00088818";
group_callee_prefix({"莱恩克",_Caller=[$0,Second|_]},_) when Second=/=$0 ->  "00088839";
group_callee_prefix({"莱恩克",_Caller},"00357"++_) ->  "00099918";

group_callee_prefix({"xxkj",_Caller},_)  ->  "*003773";

group_callee_prefix(_,_)->  "00088818".

