-record(lw_register,{acc,device_id,login_uuid, pwd,deadline=utility:date_after_n(30),balance=2.0,chargeids=[], pls = [{gift_coins,100},{coins,0},{month_consumed,0},{month,0},{payids,[]}]}).  %group_id:common/dth/livecom/...    binary  
                                                                                                                         %pls:[{balance,B},{feerate,R}]
-record(name2uuid,{name, uuid,pls = []}).                                                                                     %binary
-record(recharge_authcode,{authcode,status=unbinded,recharge=0.0,name,pls = []}).  %sipdn is uuid for delegate   string
-record(agent_did2sip,{did,sipdn,pls=[]}).         % string
-record(pay_record,{payid,uuid,status=to_pay,money,gen_time,paid_time,coins,pls=[]}).         % uuid:binary; payid/money/coins:integer; status:to_pay/paid
-record(id_table, {key, value}).
-record(qfileinfo,{fid,fn,uptime=erlang:localtime(),status=init}).
-record(qfiles, {uuid,files=[]}).


-define(UNACTIVED_STATUS,unactivated).
-define(ACTIVED_STATUS,actived).

