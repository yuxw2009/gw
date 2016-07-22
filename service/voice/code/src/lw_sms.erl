%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork task
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_sms).
-compile(export_all).

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

send_sms(Plist)->
     Service_id =proplists:get_value(service_id, Plist),
     Audit_info =proplists:get_value(audit_info, Plist),
     Members =proplists:get_value(members, Plist),
     Content =proplists:get_value(content, Plist),
     FailPhones = send_to_members(Members, Content),
     SucPhones = Members--FailPhones,
     case SucPhones of
        []-> void;
        _->
            cdrserver:new_cdr(sms, [{service_id, Service_id}, {audit_info, Audit_info}, {members, SucPhones}, {time_stamps, calendar:local_time()}])
     end,
     {ok, FailPhones}.

send_to_members2(Members,Content0) ->   % for ÷£÷›µÁ–≈
    Content = urlenc:escape_uri(Content0),
    io:format("send_to_members2:~p~p~n",[Members,Content]),
    URL="http://10.32.7.46/msg/HttpBatchSendSM?account=ltalk&pswd=livecom2016!&mobile="++
                              string:join(Members,",")++
                             "&msg="++Content0,
    R=http_send(post,{URL,[]}),
    io:format("send_to_members2 ack:~p~n",[R]),
    R.

send_to_members1(Members,Content0) ->
    Content = urlenc:escape_uri(Content0),
    io:format("send_to_members1:~p~p~n",[Members,Content]),
    Res = [{send1(Phone, Content),Phone} || Phone <- Members],
    R=[list_to_binary(P)||{Result,P}<-Res, Result=/=0],
    io:format("send_to_members1 ack:~p~n",[R]),
    R.

send1(Phone,Content)->
    URL="http://202.122.107.23/cgi-bin/SmsRcvService?name=lwork&pwd=0987&dst="++Phone++"&src=12345678900&time=20140814&msg="++Content,
    http_send(post,{URL,[]}).

http_send(Meth,{URL,Body})->
    inets:start(),
    {ok,{_,_,Ack}}=httpc:request(Meth, {URL,[],"application/json",Body},[{timeout,10 * 1000}],[]),
    case rfc4627:decode(Ack) of
    {ok,Json,_} ->    Json;
    _-> 0
    end.
    
send_to_members(Members, Content) ->
    Res = [send(Phone, Content) || Phone <- Members],
    lists:foldl(fun(ok, Acc) -> Acc;
                   ({failed, Phone}, Acc) -> [Phone|Acc] 
                end, [], Res).

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

test1()-> "‰Ω†Â•ΩÂêó".
