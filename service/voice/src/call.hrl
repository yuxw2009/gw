%-record(calldetail,{phone1,phone2,starttime,endtime,duration,rate,charge}).
%-record(callstat,{key,   %%{cardno,year,month}
%	              count   = 0,
%	              time    = 0.0, %%unit = min
%	              charge  = 0.0,
%	              details =[] %%[calldetail]
%	              }).

% ----------------------------- some record definition ------------------------
-record(call_back_detail, {start_time,end_time,local_name,local_phone,
    	                                      remote_name,remote_phone,duration,rate,charge}).
-record(meeting_item, {start_time, end_time, name, phone, duration, rate=0.1, charge}).
%-record(meeting_bill_detail, {subject, details=[]}).

%------------------------------ following is mnesia table ------------------------
-record(bill_id, {id, value=0}).
-record(call_detail,{bill_id,
	                 uuid,
	                 type,    % callback | meeting 
                     detail,  % when type = callback，
                              %     detail = {StartTime,EndTime,LocalName,LocalPhone,
	    	                  %                    RemoteName,RemotePhone,Duration,Rate,Charge}
                              % when type = meeting
	    	                  %     detail =   {meeting, Subject, [{StartTime, EndTime, Name, Phone, Duration, Rate, Charge}]}
                     group,   % company & department info
                     others
	}).

-record(call_stat,{key,      % {uuid, year, month} 
	               count=0,    % 这个月份的呼叫、会议次数
	               time=0,     % 这个月份的总时间
	               charge=0,   % 这个月份的总费用
	               bill_ids=[], % [bill_id]  % 这个月份的所有呼叫、会议标识
	               others
	}).


%---------------------------  new jf -----------------------------------------------
-record(call_back_detail_new, {phone1, rate1, phone2, rate2, start_time, end_time}).
-record(phone_meeting_item, {phone, rate, start_time, end_time}).
-record(sms_detail, {timestamp,phones}).
-record(voip_detail,{phone, rate, start_time, end_time}).

%%      following is for mnesia table
-record(id_table, {key, value}).
-record(cdr, {key, type, quantity, charge, audit_info, details, year, month}).
    %% key  = {bill_id, service_id}
    %% quantity: minutes or sms phones num
    %% charge: total charge not filled, remove
    %% type = call_back | phone_meeting | sms | voip | data_meeting
    %% details = case type of
    %%               call_back     -> {phone1, rate1, phone2, rate2, start_time, end_time};#call_back{phone1,rate1,phone2,rate2,start_time, end_time}
    %%               phone_meeting -> [{phone, rate, start_time, end_time}, ...]; [#phone_meeting{phone, rate, start_time,end_time}]
    %%               sms           -> {timestamp, [phone, ...]};
    %%               voip          -> {phone, rate, start_time, end_time}
    %%           end

-record(monthly_stat, {key, stats}). 
    %% key   = {service_id, year, month}
    %% stats = [{type, quantity, charge}]

-define(SNODE, 'voice@ubuntu.livecom').
-define(VOIPNODE,'wrtc@ubuntu.livecom').
-define(RATENODE,'fate_service@ubuntu.livecom').
