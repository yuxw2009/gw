-record(login_itm, {phone,acc,devid,ip,group_id,name,status,pls=[{traffics,[]}]}).  % phone is used for uuid  ,status:unactived,actived   group_id is not used,pls refer to lw_register
-record(traffic,{id,uuid,caller,callee,calltime=erlang:localtime(),dura=0,talktime,endtime,direction=outgoing,pls=[]}).


