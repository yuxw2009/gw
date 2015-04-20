-record(lw_register,{uuid,device_id,name, pwd,group_id= <<"common">>, pls = [{gift_coins,100},{coins,0},{month_consumed,0},{month,0},{payids,[]}]}).  %group_id:common/dth/livecom/...    binary  
                                                                                                                         %pls:[{balance,B},{feerate,R}]
-record(name2uuid,{name, uuid,pls = []}).                                                                                     %binary
-record(agent_oss_item,{sipdn,authcode,status=actived,did,pls = [{service_no,"18"}]}).  %sipdn is uuid for delegate   string
-record(agent_did2sip,{did,sipdn,pls=[]}).         % string
-record(pay_record,{payid,uuid,status=to_pay,money,gen_time,paid_time,coins,pls=[]}).         % uuid:binary; payid/money/coins:integer; status:to_pay/paid
-record(id_table, {key, value}).



-define(UNACTIVED_STATUS,unactivated).
-define(ACTIVED_STATUS,actived).

