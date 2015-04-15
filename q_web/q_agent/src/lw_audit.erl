%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user audit
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_audit).
-compile(export_all).
-include("lw.hrl").

-define(CDR,"xengine/cdrs").

%%--------------------------------------------------------------------------------------

start_audit(Timeout) ->
    register(audit,spawn(fun() -> start_audit_process(Timeout) end)).

start_audit_process(Timeout) ->
    TRef = erlang:send_after(Timeout, self(), update),
    LastBillID = get_last_bill_id(),
    SerID = lw_config:get_serid(),
    loop(SerID,LastBillID,TRef,Timeout).

get_last_bill_id() ->
    case mnesia:dirty_last(lw_audit) of
        '$end_of_table' -> 1;
        Last -> Last
    end.

save_new_audit(NewAudit) ->
    mnesia:dirty_write(NewAudit),
    {_,_,_,_,OrgID} = NewAudit#lw_audit.audit_info,
    BillID = NewAudit#lw_audit.bill_id,
    Year   = NewAudit#lw_audit.year,
    Month  = NewAudit#lw_audit.month,
    GroupCode = NewAudit#lw_audit.group_code,
    Key = {GroupCode,OrgID,Year,Month},
    case mnesia:dirty_read(lw_audit_verse,Key) of
        []  -> 
            mnesia:dirty_write(#lw_audit_verse{key = Key,bill_id = [BillID]});
        [V] -> 
            Old = V#lw_audit_verse.bill_id,
            mnesia:dirty_write(V#lw_audit_verse{bill_id = [BillID|Old]})
    end,
    ok.

%%--------------------------------------------------------------------------------------

parse_single_cdr({Year,Month,SerID,BillID,Type,Quantity,Charge,AuditInfo,Detail}) ->
    FQuantity = list_to_integer(Quantity),
    FCharge   = list_to_float(Charge),
    #lw_audit{bill_id = BillID,year = Year,month = Month,group_code = SerID,type = Type,
              quantity = FQuantity,charge = FCharge,audit_info = AuditInfo,
              detail = parse_detail(Type,Detail)}.

parse_detail(phone_meeting,Detail) ->
    [utility:decode_json(I,[{phone,s},{rate,s},{start_time,s},{end_time,s}])||I<-Detail];
parse_detail(sms,Detail) ->
    utility:decode_json(Detail,[{timestamp,s},{phones,as}]);
parse_detail(voip,Detail) ->
    utility:decode_json(Detail,[{phone,s},{rate,s},{start_time,s},{end_time,s}]);
parse_detail(callback,Detail) ->
    utility:decode_json(Detail,[{phone1,s},{rate1,s},{phone2,s},{rate2,s},{start_time,s},{end_time,s}]).

get_cdr(SerID,BillID) ->
    IP  = lw_config:get_ct_server_ip(),
    CDR = ?CDR,
    URL = lw_lib:build_url(IP,CDR,[service_id,seq_no,auth_code,bill_id],[SerID,1,1,BillID]),
    case lw_lib:httpc_call(get,{URL}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            F = fun(Reason) ->
                    logger:log(error,"SerID:~p BillID:~p get_cdr_failed.reason:~p~n",[SerID,BillID,Reason]),
                    {get_cdr_failed}
                end,
            case element(1,lw_lib:parse_json(Json,[{cdrs,ao,[{year,i},{month,i},{service_id,s},{bill_id,i},{type,a},{quantity,s},{charge,s},{audit_info,o,[{uuid,i},{company,s},{name,s},{account,s},{orgid,i}]},{details,r}]}],F)) of
                get_cdr_failed ->
                    get_cdr_failed;
                AllAudit ->
                    [parse_single_cdr(Audit)||Audit<-AllAudit]
            end
    end.

update_last_bill_id(NewAudits) ->
    Last = lists:last(lists:keysort(#lw_audit.bill_id,NewAudits)),
    Last#lw_audit.bill_id + 1.

poll_cdr(SerID,BillID) ->
    case get_cdr(SerID,BillID) of
        httpc_failed ->
            BillID;
        get_cdr_failed ->
            BillID;
        [] ->
            BillID;
        NewAudits ->
            do_handle_audit(NewAudits),
            update_last_bill_id(NewAudits)
    end.

%%--------------------------------------------------------------------------------------

loop(SerID,LastBillID,TRef,Timeout) ->
    receive
    	update ->
            NextBillID = 
                try
                    poll_cdr(SerID,LastBillID)
                catch
                    _:Reason ->
                        logger:log(error,"lw_audit poll_cdr ~p ~p~n",[LastBillID, Reason]),
                        LastBillID
                end,
            NewTef= update_timer(TRef,Timeout),
            loop(SerID,NextBillID,NewTef,Timeout)
    end.

fake_api(SerID,LastBillID) ->
    L = [{lw_audit,LastBillID,SerID,phone_meeting,20.0,10.0,{76,"爱迅达/新业务开发部","张丛耸","0131000018"},detail,[]},
         {lw_audit,LastBillID + 1,SerID,sms,20.0,2.0,{86,"爱迅达/新业务开发部","邓辉","0131000020"},detail,[]},
         {lw_audit,LastBillID + 2,SerID,voip,30.0,7.0,{86,"爱迅达/新业务开发部","邓辉","0131000020"},detail,[]}],
    {L,LastBillID + 3}.

test1() ->
    act(),
    {NewAudits,NewBillID} = fake_api(1,1),
    do_handle_audit(NewAudits),
    save_new_audit(NewAudits),
    [Ins1] = mnesia:dirty_read(lw_instance,76),
    {cost,Cost1} = lists:keyfind(cost,1,Ins1#lw_instance.reverse),
    [Ins2] = mnesia:dirty_read(lw_instance,86),
    {cost,Cost2} = lists:keyfind(cost,1,Ins2#lw_instance.reverse),
    NewBillID = 4,
    Cost1 = 10.0,
    Cost2 = 9.0,
    ok.

%%--------------------------------------------------------------------------------------

update_timer(TRef,Timeout) ->
    erlang:cancel_timer(TRef),
    erlang:send_after(Timeout, self(), update).

%%--------------------------------------------------------------------------------------

update_user_cost(UUID,Cost) ->
    Module = lw_config:get_user_module(),
    Module:update_user_cost(UUID,Cost),
    Module:update_org_cost(UUID,Cost).

%%--------------------------------------------------------------------------------------

do_handle_audit(NewAudits) when is_list(NewAudits) ->
    [do_handle_audit(NewAudit)||NewAudit<-NewAudits],
    ok;
do_handle_audit(NewAudit) when is_record(NewAudit,lw_audit) ->
    case mnesia:dirty_read(lw_audit,NewAudit#lw_audit.bill_id) of
        [] ->
            try
                Cost = NewAudit#lw_audit.charge,
                {UUID,_,_,_,_} = NewAudit#lw_audit.audit_info,
                update_user_cost(UUID,Cost),
                save_new_audit(NewAudit)
            catch
                _:Reason ->
                    logger:log(error,"lw_audit do_handle_audit ~p ~p~n",[NewAudit, Reason])
            end;
        _ ->
            ok
    end.

%%--------------------------------------------------------------------------------------

act() ->
    F = fun(Key) ->
            [Ins] = mnesia:dirty_read(lw_instance,Key),
            mnesia:dirty_write(Ins#lw_instance{reverse = [{cost,0.0},{balance,200.000},{voip,enable},{phoneconf,enable},{sms,enable},{dataconf,enable}]})
        end,
    AllUUIDs = mnesia:dirty_all_keys(lw_instance),
    [F(UUID)||UUID<-AllUUIDs],
    ok.

%%--------------------------------------------------------------------------------------

load_target_bill_id(SerID,OrgID,Year,Month) ->
    case mnesia:dirty_read(lw_audit_verse,{SerID,OrgID,Year,Month}) of
        []  -> [];
        [V] -> V#lw_audit_verse.bill_id
    end.

load_audit(BillIDs) ->
    [hd(mnesia:dirty_read(lw_audit,BillID))||BillID<-BillIDs,mnesia:dirty_read(lw_audit,BillID) =/= []].

build_report(OrgID,Year,Month) ->
    SerID = lw_config:get_serid(),
    build_report(SerID,OrgID,Year,Month).

build_report(SerID,OrgID,Year,Month) ->
    BillIDs = load_target_bill_id(SerID,OrgID,Year,Month),
    Audits  = load_audit(BillIDs),
    build_report(Audits).

trans_quantity_by_unit(Quantity,Unit) ->
    case Quantity rem Unit of
        0 -> Quantity div Unit;
        _ -> (Quantity div Unit) + 1
    end.

get_type_unit(sms) -> 1;
get_type_unit(_)   -> 60.

update_user_stat(UserStat,Type,Quantity,Cost) ->
    {Type,OldQuantity,OldCost} = lists:keyfind(Type, 1, UserStat),
    lists:keyreplace(Type, 1, UserStat, {Type,OldQuantity + Quantity,OldCost + Cost}).

build_report(Audits) ->
    F = fun(Audit,Dict) ->
            {_,Company,Name,EID,_} = Audit#lw_audit.audit_info,
            Type = Audit#lw_audit.type,
            Quantity = Audit#lw_audit.quantity,
            Unit = get_type_unit(Type),
            NewQuantity = trans_quantity_by_unit(Quantity,Unit),
            Cost = Audit#lw_audit.charge,
            Key = {Company,EID,Name},
            case dict:is_key(Key, Dict) of
                false ->
                    Init = [{callback,0,0.0},{phone_meeting,0,0.0},{sms,0,0.0},{voip,0,0.0}],
                    dict:store(Key,update_user_stat(Init,Type,NewQuantity,Cost),Dict);
                true ->
                    {ok, UserStat} = dict:find(Key,Dict),
                    dict:store(Key,update_user_stat(UserStat,Type,NewQuantity,Cost),Dict)
            end
        end,
    Dict = lists:foldl(F,dict:new(),Audits),
    lists:keysort(1,dict:to_list(Dict)).

%%--------------------------------------------------------------------------------------