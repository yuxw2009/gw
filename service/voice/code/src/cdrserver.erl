-module(cdrserver).
-compile(export_all).
-include("call.hrl").
-export([get_cdr_from/2]).

start_monitor() ->
    case whereis(?MODULE) of
        undefined-> 
            {Pid,_} = spawn_monitor(fun() -> init() end),
            register(?MODULE,Pid),
            Pid;
        P->  P
    end.

%% uuid,{Phone1,Rate1},{Phone2,Rate2},{StartTime,EndTime,Duration}
new_cdr(Type, Cdr_info) ->
    Pid= case whereis(?MODULE) of
           undefined-> 
              start_monitor();
           P->  P
           end,
     Pid ! {new_cdr,Type, Cdr_info},
     ok.

init() ->
    loop().

loop() ->
    receive
        {new_cdr,Type, Cdr_info}->
            handle_cdr_request0(Type, Cdr_info),
            loop();
    Unexpected ->
    	    io:format("Cdrserver received unexpected msg ~p ~n",[Unexpected]),
    	    loop()
    end.

%-record(cdr, {key, type, quantity, charge, audit_info, details}).
    %% key  = {bill_id, service_id}
    %% quantity: minutes or sms phones num
    %% charge: total charge not filled, remove
    %% type = call_back | phone_meeting | sms | voip | data_meeting
    %% details = case type of
    %%               call_back     -> {phone1, rate1, phone2, rate2, start_time, end_time};#call_back{phone1,rate1,phone2,rate2,start_time, end_time}
    %%               phone_meeting -> [{phone, rate, start_time, end_time}, ...]; [#phone_meeting{phone, rate, start_time,end_time}]
    %%               sms           -> {timestamp, [phone, ...]};
    %%               voip          -> {phone, rate, start_time, end_time}
handle_cdr_request0(Type, Cdr_info)->
%    io:format("****************************~n~p~n",[[Type,Cdr_info]]),
    handle_cdr_request(Type, Cdr_info).
handle_cdr_request(Type, {Service_id,Audit_info, T3,T4}) when is_list(Service_id)-> handle_cdr_request(Type, {{Service_id, ""},Audit_info, T3,T4});
handle_cdr_request(meeting, {{Service_id,_UUID},Audit_info=_GroupId, _Subject,Details})->
    % modify to rate from rate_server
    Type = phone_meeting,
    Phones = [P||#meeting_item{phone=P}<-Details],
    Quantity_items = [D||#meeting_item{duration=D}<-Details],
    Quantity = lists:sum(Quantity_items),
    Phone_rates = get_rates(Service_id, Type, Phones),
%    io:format("-------------------------------------------------handle_cdr_request Service_id:~p, phones:~p, rates~p~n",[Service_id,Phones,Phone_rates]),
    Charge = lists:sum(lists:zipwith(fun(Quan, {_Phone, Rate})-> to_minute(Quan)*Rate end, Quantity_items, Phone_rates)),
    Cdr_details0=[#phone_meeting_item{phone=Phone,start_time=S_t,end_time=E_t}||#meeting_item{start_time=S_t,end_time=E_t,phone=Phone}<-Details],
    Cdr_details1 = lists:zipwith(fun(Phone_meeting_item, {_phone, Rate})-> Phone_meeting_item#phone_meeting_item{rate=Rate} end, Cdr_details0, Phone_rates),
    CDR = #cdr{key={www_xengine:bill_id(Service_id), Service_id}, type=Type, quantity=Quantity,
                        charge=Charge, audit_info=Audit_info, details=Cdr_details1},
    callstat:save(Service_id,CDR);

handle_cdr_request(callback, {{Service_id,_UUID},Audit_info,{{_Name1,Phone1,_},{_Name2,Phone2,_}},{StartTime,EndTime,Quantity},Options})->
    % modify to rate from rate_server
    Type = callback,
    [{_, Rate1},{_, Rate2}] = get_rates(Service_id, Type, [Phone1,Phone2]),
    Charge = (Rate1+Rate2)*to_minute(Quantity),
    Cdr_details=#call_back_detail_new{phone1=Phone1, rate1=Rate1, phone2=Phone2, rate2=Rate2, start_time=StartTime, end_time=EndTime},
    CDR = #cdr{key={www_xengine:bill_id(Service_id), Service_id}, type=Type, quantity=Quantity,
                        charge=Charge, audit_info=Audit_info, details=Cdr_details},
    callstat:save(Service_id,CDR),
    case proplists:get_value(callback,Options) of
    {Node,Mod,Fun,UUID0}->    rpc:call(Node,Mod,Fun,[UUID0,Charge]);
    _-> void
    end;    

handle_cdr_request(callback, {{Service_id,_UUID},Audit_info,{{_Name1,Phone1,_},{_Name2,Phone2,_}},{StartTime,EndTime,Quantity}})->
    % modify to rate from rate_server
    Type = callback,
    [{_, Rate1},{_, Rate2}] = get_rates(Service_id, Type, [Phone1,Phone2]),
    Charge = (Rate1+Rate2)*to_minute(Quantity),
    Cdr_details=#call_back_detail_new{phone1=Phone1, rate1=Rate1, phone2=Phone2, rate2=Rate2, start_time=StartTime, end_time=EndTime},
    CDR = #cdr{key={www_xengine:bill_id(Service_id), Service_id}, type=Type, quantity=Quantity,
                        charge=Charge, audit_info=Audit_info, details=Cdr_details},
    callstat:save(Service_id,CDR);

handle_cdr_request(voip, {{Service_id="xh",_UUID},Audit_info,Phone,{StartTime,EndTime,Quantity},Options})->
    % modify to rate from rate_server
    BillId=proplists:get_value(guid,Options,www_xengine:bill_id(Service_id)),
    
    Type = voip,
    [{_, Rate}] = get_rates(Service_id, Type, [Phone]),
    Charge = Rate*to_minute(Quantity),
    Cdr_details=#voip_detail{phone=Phone,rate=Rate, start_time=StartTime, end_time=EndTime},
    Key={BillId, Service_id}, 
    CDR = #cdr{key=Key, type=Type, quantity=Quantity,
                        charge=Charge, audit_info=Audit_info, details=Cdr_details},
    callstat:save(Service_id,CDR),
    KouFei =proplists:get_value(callback,Options),
    io:format("voip koufei: ~p~n",[{_UUID,KouFei,Charge}]),
    case KouFei of
    {Node,Mod,Fun,UUID0}->
        rpc:call(Node,Mod,Fun,[UUID0,Charge]);
    _-> void
    end;
handle_cdr_request(voip, {{Service_id,_UUID},Audit_info,Phone,{StartTime,EndTime,Quantity},Options})->
    % modify to rate from rate_server
    Type = voip,
    [{_, Rate}] = get_rates(Service_id, Type, [Phone]),
    Charge = Rate*to_minute(Quantity),
    Cdr_details=#voip_detail{phone=Phone,rate=Rate, start_time=StartTime, end_time=EndTime},
    Key={www_xengine:bill_id(Service_id), Service_id}, CDR = #cdr{key=Key, type=Type, quantity=Quantity,
                        charge=Charge, audit_info=Audit_info, details=Cdr_details},
    callstat:save(Service_id,CDR),
    KouFei =proplists:get_value(callback,Options),
    io:format("voip koufei: ~p~n",[{_UUID,KouFei,Charge}]),
    case KouFei of
    {Node,Mod,Fun,UUID0}->
        rpc:call(Node,Mod,Fun,[UUID0,Charge]);
    _-> void
    end;
%    Callback=proplists:get_value(callback,Options,fun(_)-> void end),
 %   Callback(Charge);
handle_cdr_request(sms, Plist)->
     Service_id =proplists:get_value(service_id, Plist),
     Audit_info =proplists:get_value(audit_info, Plist),
     Members =proplists:get_value(members, Plist),
     Time_stamps =proplists:get_value(time_stamps, Plist),
     Type = sms,
     Rates = get_rates(Service_id, Type, Members),
     Details = #sms_detail{timestamp=Time_stamps, phones=Members},
     CDR = #cdr{key={www_xengine:bill_id(Service_id), Service_id}, type=Type, quantity=length(Members),
                        charge=lists:sum([R ||{_, R}<-Rates]), audit_info=Audit_info, details=Details},
     callstat:save(Service_id, CDR);

handle_cdr_request(Type, _Cdr_info)-> io:format("++++++++++++++++++++++++++++++++++++unhandled cdr_info type is ~p,cdr_info:~p~n", [Type,_Cdr_info]).   

get_cdr_from(Service_id, Bill_id)-> callstat:get_cdr_from(Service_id, Bill_id).
    
to_minute(Duration) ->
    trunc(Duration/60)+1.0.

service_id({Service_id, _UUID})-> Service_id;
service_id(S)-> S.

get_rate(GroupId,Type,Phone) when is_binary(GroupId)-> get_rate(binary_to_list(GroupId),Type,Phone);
get_rate("dth_common", voip,Phone)-> {Phone,1};
get_rate("common", voip,Phone= "*"++_)-> {Phone,1};
get_rate("common", voip,Phone)-> {Phone,3};
get_rate("common", callback,Phone= "*"++_)-> {Phone,0};
get_rate("common", callback,Phone)-> {Phone,2.5};
get_rate("ml", sms,Phone)-> {Phone,0.07};
get_rate("ml", voip,Phone= "*"++_)-> {Phone,0.0};
get_rate("ml", voip,Phone)-> {Phone,0.04};
get_rate(_, _,Phone)-> {Phone,0.1}.

get_rates(Service_id,Type, Phones)-> [get_rate(Service_id, Type,P)||P<-Phones].
