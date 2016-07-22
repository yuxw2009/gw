-record(lw_register,{uuid,name="",phone="", device_id,pwd,group_id= <<"common">>, 
             pls = [{pkgs,[]},{payids,[]}]}).  %group_id:common/dth/livecom/...    binary   %pls:[{balance,B},{feerate,R}]
             
 % account:0131000051@livecom for company employee  or 31250025 for public mail_infos:{mail_acc,mail_pwd,addr}
-record(mail_t0,{account,mail_infos=[],uuid,max_oa_uid=1,max_mail_uid=1,pls=[]}).
-record(mail_t,{account,mail_infos=[],uuid,max_oa_uid=1,max_mail_uid=1,pls=[]}).
-record(devid_reg_t,{devid,pls}).                                                                                     %binary
-record(third_reg_t,{acc,name, uuid,pls = []}).                                                                                     %binary
-record(name2uuid,{name, uuid,pls = []}).                                                                                     %binary
-record(agent_oss_item,{sipdn,authcode,status=actived,did,pls = [{service_no,"18"}]}).  %sipdn is uuid for delegate   string
-record(agent_did2sip,{did,sipdn,pls=[]}).         % string
-record(pay_record,{payid,uuid,status=to_pay,money,gen_time,paid_time,coins,pls=[]}).         % uuid:binary; payid/money/coins:integer; status:to_pay/paid
-record(pay_types_record,{payid,uuid,status=to_pay,money,gen_time,paid_time,pay_org,order_id,pls=[],pkg_info}).         % uuid:binary; payid/money:integer; status:to_pay/paid;package:proplists(user taocan)

-record(package_info,{period=month,cur_circle=0,from_date,circles=0,gifts=0,limits=0,cur_consumed=0,payid,raw_pkginfo}).
-record(id_table, {key, value}).

-record(openim_t,{uuid,userid= <<"">>,pwd= <<"">>,nickname= <<"">>,iconurl= <<"">>,mobile= <<"">>,pls=[]}).

-define(UNACTIVED_STATUS,unactivated).
-define(ACTIVED_STATUS,actived).

