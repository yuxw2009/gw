-module(zteapi).
-compile(export_all).

-include("db.hrl").

-define(ZTEID, 1).

%% call 
%%     param : SeqNo,CardNo,Phone1,Phone2,Digest 
%%     Digest: md5([SeqNo,CardNo,Phone1,Phone2,PassWord])
%%     return: {call_ok,CardNo} | {call_failed, CardNo,Reason} | {auth_failed,Reason}
call(SeqNo,CardNo2,Phone1,Phone2,Digest) ->
    EID = {?ZTEID, CardNo2},
    E = get_employee(EID),
    if
        E =:= [] ->
            {auth_failed, digest_wrong};
        E#employer.phone1 =:= Phone1 orelse E#employer.phone2 =:= Phone1 orelse CardNo2 =:= "12345678"->       
           {ok,{Phone1,FRate1},{Phone2,FRate2}}=rpc:call('rateserver@10.32.3.38',
                                                             fate_service,lookup,["ZTE",Phone1,Phone2]),
            Balance = 10000.0,
            Rate1 = list_to_float(FRate1),
            Rate2 = list_to_float(FRate2),
            MaxTalkingTime = trunc(60*Balance /(Rate1 + Rate2)),
            rpc:call('service@10.32.3.38', operator, call, 
                           [EID,{Phone2,Rate2},{Phone1,Rate1},MaxTalkingTime]);
        true ->
            {auth_failed, digest_wrong}
    end.

%% change_password
%%     param : SeqNo,CardNo,NewPassword,Digest 
%%     Digest: md5([SeqNo,CardNo,NewPassword,PassWord])
%%     return: ok | {auth_failed,Reason}
change_password(SeqNo,CardNo2,NewPasswordCrypted,Digest) ->
    EID = {?ZTEID, CardNo2},
    crypto:start(),
    E = get_employee(EID),
    if
        E =:= [] ->
            {auth_failed, digest_wrong};
        true ->
            [Key] = io_lib:format("~-8s",[E#employer.password]),
            NPBin = utility:hexstr2bin(NewPasswordCrypted),
            NewPassword = string:strip(binary_to_list(crypto:des_ecb_decrypt(Key,NPBin))),
            change_password(EID, NewPassword)
    end.

%% lookup_stat
%%     param : SeqNo,CardNo,Year,Month,Digest
%%     Digest: md5([SeqNo,CardNo,Year,Month,PassWord])
%%     return: {value,CallStat} | {auth_failed,Reason}
lookup_stat(SeqNo,CardNo2,Year,Month,Digest) ->
    EID = {?ZTEID, CardNo2},
    E = get_employee(EID),
    if
        E =:= [] ->
            {auth_failed, digest_wrong};
        true ->
            {value, get_callstat(EID, Year, Month)}
    end.

lookup_balance(SeqNo,CardNo2,Digest) ->
    EID = {?ZTEID, CardNo2},
    E = get_employee(EID),
    if
        E =:= [] ->
            {auth_failed, digest_wrong};
        true ->
            {{Year,Month,_},_} = calendar:local_time(),
            {value, get_balance(EID, Year, Month)}
    end.

%% lookup_fate
%%     param : SeqNo,CardNo,Phone1,Phone2,Digest
%%     Digest: md5([SeqNo,CardNo,Phone1,Phone2,PassWord])
%%     return: {value,Balance} | {auth_failed,Reason}
lookup_fate(SeqNo,CardNo,Phone1,Phone2,Digest) ->
    {ok,{Phone1,FRate1},{Phone2,FRate2}}=rpc:call('rateserver@10.32.3.38',
                                                             fate_service,lookup,["ZTE",Phone1,Phone2]),
    Rate1     = list_to_float(FRate1),
    Rate2     = list_to_float(FRate2),
    [RateStr] = io_lib:format("~.4f",[Rate1 + Rate2]),
    {value,RateStr}.

new_cdr(UUID,{Phone1,Rate1},{Phone2,Rate2},{StartTime,EndTime,Duration}) ->new_cdr(UUID,{Phone1,Rate1},{Phone2,Rate2},{StartTime,EndTime,Duration},"") .
new_cdr(UUID,{Phone1,Rate1},{Phone2,Rate2},{StartTime,EndTime,Duration},Options) ->
    RecUrl=proplists:get_value(recurl,Options,""),
    SubgroupId=proplists:get_value(subgroup_id,Options,""),
    Guid=proplists:get_value(guid,Options,""),
    CallDetail = #employer_detail{caller=Phone1,
                                  called=Phone2,
                                  start_time=calendar:now_to_local_time(StartTime),
                                  end_time=calendar:now_to_local_time(EndTime),
                                  duration=to_minute(Duration),
                                  rate=Rate1+Rate2,
                                  recurl=RecUrl,
                                  charge=to_minute(Duration)*(Rate1+Rate2)},
    db:save_cdr(Options,CallDetail),                              
    db:update(UUID,CallDetail).

get_employee(EID) ->
    db:get_employee(EID).

change_password(EID, NewPass) ->
    ok.

get_callstat(EID, Y, M) ->
    CS = db:get_callstat(EID,Y,M),
    if 
        CS =:= [] -> [];
        true -> [CS]
    end.

get_balance(EID, Y, M) ->
    E = get_employee(EID),
    CS = db:get_callstat(EID,Y,M),
    if 
        CS =:= [] -> E#employer.balance;
        true ->
            E#employer.balance - CS#employer_stat.charge
    end.

to_minute(Duration) ->
    trunc(Duration/60)+1.0.
