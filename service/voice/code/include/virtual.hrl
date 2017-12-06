-define(NORMAL,"0").
-define(VirtualNumErr,"1000").
-define(DuplicatCall,"1001").
-define(AnonymousLimited,"1002").

-record(a_x_t,  {a, x,companyid}).   %% disk copy 
-record(a_x_b_t, { x_t,a,b,mode}).            %% disc_copies,  x_t: {x,t},mode: single,dual
-record(active_trans_t, { x,transid,clientip= <<>>}).            %% ram copy,  x_t: {x,t}
-record(company_t,{id,name,passwd= <<>>,available_xs=[],used_xs=[],cdr_mode=push,cdr_pushurl= <<>>,needVoip=false,needPlaytone=false,needCompanyname=false,attrs=[]}). 
-record(sip_nic_t,{id,addr_info,das= <<>>,nodes=[],status=break,name= <<>>,node}).  %addr_info:{LocalIp,LocalPort,RemoteIp,RemotePort}
-record(sip_processor,{id,name= <<>>,nodeip,myip,myport,ssip,ssport=5060,nicnode,node}). 
-record(traffic_item,{node=node(),hktime= erlang:localtime(),caller= <<>>,callee= <<>>,newcaller= <<>>,newcallee= <<>>,status=ok,itemattrs=[],starttime,endtime}).
-define(CdrTemplate,#{companyid=><<>>,a=><<>>,x=><<>>,ver=>"1",transid=><<>>,mode=>single,clientip=><<>>,node=>node(),hktime=>integer_to_list(sip_tp:seconds(erlang:localtime())),caller=><<>>,callee=><<>>,newcaller=><<>>,newcallee=><<>>,reason=><<>>,starttime=><<>>,endtime=><<>>}).
-record(traffic_t,{key=erlang:localtime(),items=[],attrs=[]}).  
-define(DEFAULT_TRANS,<<>>).
-define(NULL_B,<<"">>).


