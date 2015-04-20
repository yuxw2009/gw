-module(serviceapi).
-compile(export_all).

-include("card.hrl").
-include("call.hrl").

%% call 
%%     param : SeqNo,CardNo,Phone1,Phone2,Digest 
%%     Digest: md5([SeqNo,CardNo,Phone1,Phone2,PassWord])
%%     return: {call_ok,CardNo} | {call_failed, CardNo,Reason} | {auth_failed,Reason}
call(SeqNo,CardNo,Phone1,Phone2,Digest) ->
    Action = fun(Card) ->
                case trial:check_binding(CardNo, Phone1, Phone2) of
                    check_success ->
            	         BillId = Card#card.billid,
        %%                 {ok,{Phone1,Rate1},{Phone2,Rate2}}=rateserver:lookup(BillId,Phone1,Phone2),
                         {ok,{Phone1,FRate1},{Phone2,FRate2}}=rpc:call('rateserver@ltalk.com',
                                                                     fate_service,lookup,[BillId ,Phone1,Phone2]),
                         Balance = Card#card.balance,
                         Rate1 = list_to_float(FRate1),
                         Rate2 = list_to_float(FRate2),

                         MaxTalkingTime = trunc(60*Balance /(Rate1 + Rate2)),
                         if 
                            MaxTalkingTime > 60.0 ->
                                operator:call(CardNo,{Phone2,Rate2},{Phone1,Rate1},MaxTalkingTime);
                            true ->
                                {call_failed, CardNo, balance_is_negative}
                         end;
                    check_failed ->
                        {trial, check_failed}
                end        
             end,
    authenticate(CardNo,[CardNo,Phone1,Phone2],SeqNo,Digest,Action).

%% stop
%%     param : SeqNo,CardNo,Digest 
%%     Digest: md5([SeqNo,CardNo,PassWord])
%%     return: ok | {auth_failed,Reason}
stop(SeqNo,CardNo,Digest) ->
    Action = fun(_Card) ->
                 operator:stop(CardNo)
             end,
    authenticate(CardNo,[CardNo],SeqNo,Digest,Action).

%% change_password
%%     param : SeqNo,CardNo,NewPassword,Digest 
%%     Digest: md5([SeqNo,CardNo,NewPassword,PassWord])
%%     return: ok | {auth_failed,Reason}
change_password(SeqNo,CardNo,NewPasswordCrypted,Digest) ->
    crypto:start(),
    Action = fun(Card) ->
                 [Key] = io_lib:format("~-8s",[Card#card.password]),
                 NPBin = utility:hexstr2bin(NewPasswordCrypted),
                 NewPassword = string:strip(binary_to_list(crypto:des_ecb_decrypt(Key,NPBin))),
                 card:change_password(CardNo,NewPassword)
             end,
    authenticate(CardNo,[CardNo,NewPasswordCrypted],SeqNo,Digest,Action).

%% get_call_status
%%     param : SeqNo,CardNo,Digest 
%%     Digest: md5([SeqNo,CardNo,PassWord])
%%     return: {session_status,{Phone1,Status1},{Phone2,Status2}} | session_not_exist | {auth_failed,Reason}
get_call_status(SeqNo,CardNo,Digest) ->
    Action = fun(_Card) ->
                 operator:get_call_status(CardNo)
             end,
    authenticate(CardNo,[CardNo],SeqNo,Digest,Action).

%% lookup_stat
%%     param : SeqNo,CardNo,Year,Month,Digest
%%     Digest: md5([SeqNo,CardNo,Year,Month,PassWord])
%%     return: {value,CallStat} | {auth_failed,Reason}
lookup_stat(SeqNo,CardNo,Year,Month,Digest) ->
    Action = fun(_Card) ->
                 CallStat = callstat:lookup(CardNo,Year,Month),
                 {value,CallStat}
             end,

    authenticate(CardNo,[CardNo,integer_to_list(Year),integer_to_list(Month)],SeqNo,Digest,Action).

%% lookup_balance
%%     param : SeqNo,CardNo,Year,Month,Digest
%%     Digest: md5([SeqNo,CardNo,Year,Month,PassWord])
%%     return: {value,Balance} | {auth_failed,Reason}
lookup_balance(SeqNo,CardNo,Digest) ->
    Action = fun(Card) ->
                    B = if
                            Card#card.balance < 0.0 -> 0.0;
                            true                    -> Card#card.balance
                    end,
                 {value,B}
    	     end,

    authenticate(CardNo,[CardNo],SeqNo,Digest,Action).

%% lookup_fate
%%     param : SeqNo,CardNo,Phone1,Phone2,Digest
%%     Digest: md5([SeqNo,CardNo,Phone1,Phone2,PassWord])
%%     return: {value,Balance} | {auth_failed,Reason}
lookup_fate(SeqNo,CardNo,Phone1,Phone2,Digest) ->
    Action = fun(Card) ->
                     BillId = Card#card.billid,
                 {ok,{Phone1,FRate1},{Phone2,FRate2}}=rpc:call('rateserver@ltalk.com',
                                                             fate_service,lookup,[BillId ,Phone1,Phone2]),
                 Rate1     = list_to_float(FRate1),
                 Rate2     = list_to_float(FRate2),
                 [RateStr] = io_lib:format("~.4f",[Rate1 + Rate2]),
                 {value,RateStr}
             end,
    authenticate(CardNo,[CardNo,Phone1,Phone2],SeqNo,Digest,Action).

authenticate(CardNo,OriginList,SeqNo,Digest,Action) ->
    Exist    = fun(Card) -> {Card =/= {error,card_not_exist},digest_wrong} end,
    Active   = fun(Card) -> {Card#card.status =:= active,digest_wrong} end, 
    Valid    = fun(Card) -> {Card#card.seqno < SeqNo, {seqno_wrong,Card#card.seqno+1}} end,
    Password = fun(Card) -> {calc_digest([integer_to_list(SeqNo)]++OriginList ++[Card#card.password]) =:= Digest,
                             digest_wrong} end,
    Action2 = fun(Card) -> 
                  card:update_seqno(CardNo,SeqNo),
                  Action(Card)
              end,
    do_auth(card:get(CardNo),[Exist,Active,Valid,Password],Action2).
            
    
do_auth(Card,[],Action) -> Action(Card);
do_auth(Card,[Checker|T],Action) ->
    case Checker(Card) of
        {true,_}          -> do_auth(Card,T,Action);
        {false,ErrorInfo} -> {auth_failed,ErrorInfo}
    end.

calc_digest(OriginList) ->
    hex:to(erlang:md5(OriginList)).
