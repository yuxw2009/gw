%-record(traffic,{id,uuid,caller,callee,calltime,talktime,endtime,socket_ip="",caller_sip,
%	callee_sip,o_mip="",t_mip="",o_sipnode="",t_sipnode="",o_remote_mip="",t_remote_ip="",
%	reason="",o_codec="",t_codec=""}).
-record(traffic,{id,uuid,caller,callee,calltime,talktime,endtime,socket_ip="",caller_sip,
	callee_sip,o_mip="",t_mip="",o_sipnode="",t_sipnode="",o_remote_mip="",t_remote_ip="",
	reason="",o_codec="",t_codec=""}).
-record(traffic1,{id,uuid,caller,callee,calltime,talktime,endtime,socket_ip="",caller_sip,
	callee_sip,o_mip="",t_mip="",o_sipnode="",t_sipnode="",o_remote_mip="",t_remote_ip="",
	reason="",o_codec="",t_codec="",direction=outgoing,pls=[]}).
-record(id_table, {key, value}).
-record(uuid2ids,{uuid,ids=[]}).