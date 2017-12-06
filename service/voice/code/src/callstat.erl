-module(callstat).
-compile(export_all).
-include("call.hrl").
-include("db_op.hrl").

%% new cdr query save with zhangcongcong
save(Service_id, Cdr = #cdr{type=Type, quantity=Quantity,charge=Charge})->
    {Year, Month} = get_year_month(Cdr),
    ?DB_WRITE(Cdr#cdr{year=Year, month=Month}),
    Key={Service_id, Year, Month},
    case result(?DB_READ(monthly_stat,Key)) of
        []-> ?DB_WRITE(#monthly_stat{key=Key, stats=[{Type, Quantity, Charge}]});
        [Monthly_stat=#monthly_stat{stats=Stats}]-> ?DB_WRITE(Monthly_stat#monthly_stat{stats=[{Type, Quantity, Charge}|Stats]})
    end.

get_cdr_from(Service_id0, Bill_id0)->
    do(qlc:q([X || X= #cdr{key={Bill_id, Service_id}}<- mnesia:table(cdr),
                                         Service_id=:=Service_id0, Bill_id>=Bill_id0])).
    
%%compute,query
compute(CardNo,CallDetail) when is_record(CallDetail,call_detail) ->
    ?DB_WRITE(CallDetail),
    case CallDetail#call_detail.detail of
    #call_back_detail{start_time={{Year,Month,_}, _}}->
        void;
    {meeting, _, [#meeting_item{start_time={{Year,Month,_}, _}} |_]}->
        void
    end,
    Key = {CardNo,Year,Month},
    case result(?DB_READ(call_stat,Key)) of
        [] ->
            insert_new(Key,CallDetail);
        [CallStat] ->
            update_stat(CallStat,CallDetail)
    end.

insert_new(Key,CallDetail) ->
    ?DB_WRITE(do_merge(#call_stat{key=Key},CallDetail)).

update_stat(CallStat,CallDetail) ->
    ?DB_WRITE(do_merge(CallStat,CallDetail)).

do_merge(CallStat,CallDetail) ->
    case CallDetail#call_detail.detail of
        #call_back_detail{duration=Duration,charge=Charge}-> void;
        {meeting, _,Details}->
            {Duration, Charge} = 
                lists:foldl(fun(#meeting_item{duration=D, charge=C},{D0, C0})-> {D+D0, C+C0} end, {0,0}, Details)
    end,
    NewCount   = CallStat#call_stat.count+1,
    NewTime    = CallStat#call_stat.time +Duration,
    NewCharge  = CallStat#call_stat.charge + Charge,
    NewBillIds = [CallDetail#call_detail.bill_id |CallStat#call_stat.bill_ids],
    CallStat#call_stat{count=NewCount,charge=NewCharge,time=NewTime,bill_ids=NewBillIds}.

lookup_callback_stat(UUID,Year,Month) ->
    lookup_stat(UUID, Year, Month,callback).

lookup_meeting_stat(UUID, Year, Month)->
    lookup_stat(UUID, Year, Month,meeting).
    
lookup_stat(UUID, Year, Month,Type)->
    F = fun() -> mnesia:read(call_stat,{UUID,Year,Month}) end,
    case result(mnesia:transaction(F)) of
    [#call_stat{ bill_ids=BillIds}]->
	    Details = do(qlc:q([X#call_detail.detail || Y <- BillIds,
	                                                X <- mnesia:table(call_detail),
		                                        X#call_detail.bill_id =:= Y, X#call_detail.type=:=Type])),
            {Charge, Time} = lists:foldl(fun(Detail, {D0,C0})-> 
                                {D,C}=summary_charge(Detail),
                                {D0+D, C0+C}
                           end, {0,0}, Details),
	    {value, {_Count=length(Details), Charge, Time, Details}};
    []->  {value, []}
    end.

summary_charge(#call_back_detail{duration=Dur, charge=Charge})-> {Dur, Charge};
summary_charge({_,_,MeetingItem})-> 
    lists:foldl(fun(#meeting_item{duration=Dur, charge=Charge}, {D0,C0})-> {D0+Dur, C0+Charge} end, {0,0}, MeetingItem).

result({atomic,Value}) -> Value;
result({aborted,Value}) -> Value.

do(Q) ->
    F = fun() -> qlc:e(Q) end,
    {atomic, Val} = mnesia:transaction(F),
    Val.

get_n_bills_start_with(BillId, N)->
    Details = do(qlc:q([X || X <- mnesia:table(call_detail),
                                            X#call_detail.bill_id >= BillId, X#call_detail.bill_id<BillId+N])),
    {value, Details}.

get_year_month(_Cdr)->
    {{Year,Month,_},{_,_,_}}=calendar:local_time(),
    {Year, Month}.

get_stats(ServiceId)->
     Cdrs=callstat:get_cdr_from(ServiceId, 1),
     lists:sort(Cdrs).
%     Ds=[[BillId,UUID,Phone,Starttime,Endtime,Secs]||#cdr{key={BillId,quantity=Secs,audit_info=Ad=[{uuid,UUID}|_],details=D={voip_detail,Phone,_,Starttime,Endtime}}<-Cdrs].

stats2file(Sid)->
    {ok, IODev} = file:open("./cdr.txt", [write]),
    Format = "~-6s~-15s~-15s~-25s~-25s~-6s~-20s~n",
    io:format(IODev, Format , ["ID","UUID",   "Phone","Starttime", "Endtime", "Secs","ip"]),
    F = fun(#cdr{key={BillId,_},quantity=Dur,audit_info=Audit,details=#voip_detail{phone=Phone,start_time=Starttime,end_time=Endtime}})->
            {UUID,IP} = case Audit of
                            [{uuid,U},{ip,{A,B,C,D}}|_]-> {U, string:join(io_lib:format("~p~p~p~p", [A,B,C,D]), ".")};
                            [{uuid,U}|_]-> {U, "unknown"};
                            _-> {"unknown", "unknown"}
                            end,
            {{{Year0,Mon0,Day0},{H0,Min0,Sec0}},{{Year1,Mon1,Day1},{H1,Min1,Sec1}}}={Starttime,Endtime},
            St = string:join(io_lib:format("~p~p~p~p~p~p", [Year0,Mon0,Day0,H0,Min0,Sec0]), "-"),
            Et = string:join(io_lib:format("~p~p~p~p~p~p", [Year1,Mon1,Day1,H1,Min1,Sec1]), "-"),
            Dstr = integer_to_list(Dur),
            Bidstr = integer_to_list(BillId),
            io:format(IODev,Format, [Bidstr,UUID, Phone,St,Et,Dstr,IP]);
        (_)-> void
    end,
    lists:foreach(F, get_stats(Sid)),
    file:close(IODev).

statsphone2file(Sid)->
    {ok, IODev} = file:open("./phone.txt", [write]),
    F = fun(#cdr{details=#voip_detail{phone=Phone}})->
            Phone;
        (_)-> void
    end,
    Cdrs=get_stats(Sid),
    Phones=[Phone||#cdr{details=#voip_detail{phone=Phone}}<-Cdrs],
    Phones1=lists:usort(Phones),
    io:format(IODev,"~p.",[Phones1]),
    file:close(IODev).    