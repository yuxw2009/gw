%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork config
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_config).
-compile(export_all).

get_user_module() ->
    lw_config ! {get,self(),module},
    receive
        {lw_config,ok,{module,Value}} -> Value
    end.

get_remote_node() ->
    ok.

get_user_server_ip() ->
    "http://icover.china-tpa.com/".

get_split_server_ip() ->
    lw_config ! {get,self(),split_server},
    receive
        {lw_config,ok,{split_server,Value}} -> Value
    end.

get_file_server_node() ->
    lw_config ! {get,self(),file_server},
    receive
        {lw_config,ok,{file_server,Value}} -> Value
    end.

get_serid() ->
    lw_config ! {get,self(),serid},
    receive
        {lw_config,ok,{serid,Value}} -> Value
    end.

get_voip_call_number() ->   
    lw_config ! {get,self(),voip_call_number},
    receive
        {lw_config,ok,{voip_call_number,Value}} -> Value
    end.

get_ct_server_ip() ->
    lw_config ! {get,self(),voice_server},
    receive
        {lw_config,ok,{voice_server,Value}} -> Value
    end.

get_video_server_ip() ->
    lw_config ! {get,self(),video_server},
    receive
        {lw_config,ok,{video_server,Value}} -> Value
    end.

set_inets() ->
    inets:start().
%%    httpc:set_options([{proxy, {{"10.32.3.66", 808}, ["localhost"]}}]).

start() ->
    Data = [{module,local_user_info},
            {split_server,["http://10.32.3.52:9000/"]},
            {file_server,'wftp@ubuntu.livecom'},
            {serid,"1"},
            {voip_call_number,<<"0085268895100">>}],
    register(lw_config,spawn(fun() -> loop(Data) end)),
    ok.

loop(Data) ->
    receive
        {set,Name,Value} ->
            loop([{Name,Value}|Data]);
        {get,From,Name} ->
            From ! {lw_config,ok,lists:keyfind(Name,1,Data)},
            loop(Data);
        _Other ->
            loop(Data)
    end.

get_auth_func("fjec") ->
    fun(MN,EmployeeID,MD5) -> 
        case do_auth(MD5) of
            auth_ok ->
                case local_user_info:get_org_id_by_mark_name(MN) of
                    failed ->
                        {failed,auth_failed};
                    OrgID ->
                        case local_user_info:get_user_id(OrgID,EmployeeID) of
                            failed ->
                                {failed,auth_failed};
                            UUID ->
                                {ok,OrgID,UUID}
                        end
                end;
            auth_failed ->
                {failed,auth_failed}
        end
    end;
get_auth_func(_MarkName) ->
    fun(MN,EmployeeID,MD5) -> local_user_info:login(MN,EmployeeID,MD5) end.


do_auth(Token) ->
    try
        AuthURL = "http://www.fjec.org.cn/services/AppService?wsdl",
        Result = httpc:request(post, {AuthURL, [{"SOAPAction", ""}], "application/x-www-form-urlencoded", xml(Token)}, 
                                [], [{body_format, binary}]),
        {ok, {_,_,Body}} = Result,
        case result_code(Body) of
            "1" -> auth_ok;
            "2" -> auth_failed
        end
    catch
        _:_ -> auth_failed
    end.


result_code(B) -> scan(B).
scan(<<"RESULT", Rest/binary>>) ->
    scan_result_code(Rest);
scan(<<_A, Rest/binary>>) -> scan(Rest).
scan_result_code(<<C, Rest/binary>>) when C >= $0, C =< $9->
    gather_result_code(Rest, [C]);
scan_result_code(<<_C, Rest/binary>>) -> scan_result_code(Rest).
gather_result_code(<<C, Rest/binary>>, Acc) when C >= $0,C =<$9->
    gather_result_code(Rest, Acc ++ [C]);
gather_result_code(_Rest, Acc) -> Acc. 

xml(Token) ->   
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>"++"<SOAP-ENV:Envelope " ++
    "SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" "++
    "xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">" 
    ++"<SOAP-ENV:Body>"
    ++ "<getAppUserVerifyResult2><token>"++Token++"</token></getAppUserVerifyResult2> </SOAP-ENV:Body> </SOAP-ENV:Envelope>".
