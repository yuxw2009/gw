%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork task
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_sms).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

send_sms(UUID, Members, Content, Sign) ->
    case local_user_info:check_user_privilege(UUID,sms) of
        ok ->
            Time  = erlang:localtime(),
            Fails = 
                case lw_voice:send_to_members(UUID,[Phone||{_,Phone}<-Members],Content ++ "  " ++ Sign) of
                    httpc_failed -> Members;
                    sms_failed   -> Members;
                    Others -> [list_to_binary(Other)||Other<-Others]
                end,
            lw_db:act(add,sms,{UUID,Members,Content,Time}),
            {lw_lib:trans_time_format(Time),Fails};
        Other ->
            Other
    end.

get_all_sms(UUID,Index,Num) ->
    SMS = lw_db:act(get,all_sms,{UUID}),
    TargetSMS = lw_lib:get_sublist(SMS,Index,Num),
    get_sms_content(TargetSMS).

get_sms_content(AllSMS) when is_list(AllSMS) ->
    [trans_sms_format(SMS)||SMS<-AllSMS].

trans_sms_format({Members,Content,Time}) ->
    {Members,Content,lw_lib:trans_time_format(Time)}.

body(Phone,Content) ->
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<soapenv:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:smc=\"http://smc.service.push.oap.zte\">
<soapenv:Header/>
<soapenv:Body>
<smc:receiveSmcMsg soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">
<xmlStream xsi:type=\"soapenc:string\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">
<![CDATA[<service>
<arguments operate=\"SendPushSMS\" entityName=\"PushSMS\">
<param name=\"records\" type=\"Dictionary\">
<param name=\"record\" type=\"Dictionary\">
<param name=\"SmcServiceID\" type=\"String\">S0001-LWORK</param>
<param name=\"UserID\" type=\"String\">11881445000127</param>
<param name=\"StaffMoblie\" type=\"String\">" ++ Phone ++ "</param>
<param name=\"PrioRityLevel\" type=\"String\">0</param>
<param name=\"AppointmentTime\" type=\"String\"></param>
<param name=\"SmsBody\" type=\"String\">" ++ Content ++ "</param>
<param name=\"BizCode\" type=\"String\">123456789012345</param>
<param name=\"SendSum\" type=\"String\">0</param>
<param name=\"ExInfo\" type=\"String\">msgid25134006830002|11881445000127</param>
</param>
</param>
</arguments>
</service>]]>
</xmlStream>
</smc:receiveSmcMsg>
</soapenv:Body>
</soapenv:Envelope>".

send_to_members(Members, Content) ->
    Res = [send(Phone, Content) || {_, Phone} <- Members],
    lists:foldl(fun(ok, Acc) -> Acc;
                   ({failed, Phone}, Acc) -> [Phone|Acc] 
                end, [], Res).

send(Phone, Content) ->
    inets:start(),
    SMSURl = "http://10.30.1.179:6060/Push/services/SmsRcvService",
    Result = httpc:request(post, {SMSURl, [{"SOAPAction", ""}], "application/x-www-form-urlencoded", body(Phone, Content)}, 
       [], [{body_format, binary}]),
    case Result of
        {ok, {_,_,Body}} -> 
            case result_code(Body) of
                "0" -> ok;
                _   -> {failed, Phone}
            end;
        _                -> {failed, Phone}
    end.


result_code(B) -> scan(B).

scan(<<"resultcode", Rest/binary>>) ->
    scan_result_code(Rest);
scan(<<_A, Rest/binary>>) -> scan(Rest).

scan_result_code(<<C, Rest/binary>>) when C >= $0, C =< $9->
    gather_result_code(Rest, [C]);
scan_result_code(<<_C, Rest/binary>>) -> scan_result_code(Rest).

gather_result_code(<<C, Rest/binary>>, Acc) when C >= $0,C =<$9->
    gather_result_code(Rest, Acc ++ [C]);

gather_result_code(_Rest, Acc) -> Acc. 