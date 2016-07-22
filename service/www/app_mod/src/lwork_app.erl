%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(lwork_app).
-compile(export_all).

-include("yaws_api.hrl").
-define(SEP_POS,7).
-define(MOBILE_SEP_POS,3).
-define(KEY,"95438987654").
-define(MOBILE_KEY,"8743995438987654").

%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),	
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
    utility:log("clidata0:~p~n",[Arg#arg.clidata]),
    Arg1= 
    case catch rfc4627:decode(Arg#arg.clidata) of
    {ok,{obj,[{"data_enc",<<_:7/binary,Base64_Json_bin/binary>>}]},_}->
        Json_bin=utility:fb_decode_base64(Base64_Json_bin),
        Arg#arg{clidata=Json_bin};
    _-> Arg
    end,
    process_request(Path, Method, Arg1).

%process_request(["lwork", "mobile","paytest"|Params], Method, Arg) -> 
%    [{header, "Access-Control-Allow-Origin: *"},pay:handle(Arg,Method,Params)];
process_request(["lwork", "voices", "auth", "tokens"]=Path, Method, Arg) -> 
    nocheck_orgin_request(Path,Method,Arg);
process_request(Path, 'GET', Arg) -> 
    case origin(Arg) of
    undefined->  nocheck_orgin_request(Path,'GET',Arg);
    _-> check_orgin_request(Path,'GET',Arg)
    end;
process_request(Path, Method, Arg) -> 
    check_orgin_request(Path,Method,Arg).
    
    
check_orgin_request(Path,Method,Arg)->	
    Origin=origin(Arg),
 %   io:format("origin:~p~n",[{Origin,Path,Method}]),
	case access_auth:check_origin(Origin) of
        true-> 
            JsonObj = do_request(Arg, Method, Path),
			[{header, "Access-Control-Allow-Origin: *"}, encode_to_json(JsonObj)];
        _->
            {content, "application/json", enc_json([{status, failed}, {reason, cross_authen_failed},{o, Origin}])}
    end.

nocheck_orgin_request(Path,Method,Arg)->	
    JsonObj = do_request(Arg, Method, Path),
	encode_to_json(JsonObj).
	
do_request(Arg, Method, Path) ->
	case catch handle(Arg, Method, Path) of
		{'EXIT', Reason} ->  
		      err_log(Arg,Reason),
			utility:pl2jso([{status, failed}, {reason, service_not_available}]);
		Result -> 
			Result
	end.
			
%% handle voice request
handle(Arg,Method, ["qvoice"|Params]) -> 
    qvoice:handle(Arg, Method, Params);
handle(Arg,Method, ["ft"|Params]) -> 
    www_ft:handle(Arg, Method, Params);
handle(Arg, 'POST', ["lwork","media"| Params]) -> 
    Ip=utility:client_ip(Arg),
    io:format("media params:~p~n",[Params]),
    Obj=media:handle(Arg,'POST',Params),
    io:format("ack:~p~n",[Obj]),
    utility:pl2jso_br(Obj);
handle(Arg, 'POST', ["lwork","voices", ["fzdvoip"]]) -> 
    Ip=utility:client_ip(Arg),
    utility:pl2jso([{status,failed},{reason,overtime_cmd}]);
handle(Arg, Method, ["lwork","voices","auth", "tokens"]) -> 
    voice_handler:handle(Arg, Method, ["auth", "tokens"]);
handle(Arg, Method, ["lwork","auth", "get_tokens"]) -> 
    auth_handler:handle(Arg, Method, ["get_tokens"]);

handle(Arg, Method, ["lwork","voices0"|Params]) ->   %% remove old inteface
    Obj=voice_handler:handle(Arg, Method, Params),
    Json_str=rfc4627:encode(Obj),
    Sep=[$a+random:uniform(9),$a+random:uniform(20)],
    Sep_bin = list_to_binary(Sep),
    <<Bin1:3/binary,Bin2/binary>>=base64:encode(Json_str),
    Enc_bin= <<Bin1/binary,Sep_bin/binary,Bin2/binary>>,
    utility:pl2jso([{data_enc,Enc_bin}]);

handle(Arg, Method, ["lwork","voices1"|Params]) -> 
%    io:format("lwork_app:voices1:path:~p~nclidata:~p~n",[Params,Arg#arg.clidata]),
    Obj=voice_handler:handle(Arg, Method, Params),
%    io:format("lwork_app:ack:~p~n",[Obj]),
    Obj;
%    Json_str=rfc4627:encode(Obj),
%    Sep=[$a+random:uniform(9),$a+random:uniform(20)],
%    Sep_bin = list_to_binary(Sep),
%    <<Bin1:?SEP_POS/binary,Bin2/binary>>=base64:encode(Json_str),
%    Enc_bin= <<Bin1/binary,Sep_bin/binary,Bin2/binary>>,
%    [A,B|T] = ?KEY,
%    OffStr = [A,B]++integer_to_list(?SEP_POS)++T,
%    utility:pl2jso([{x,Enc_bin},{y,list_to_binary(OffStr)}]);

handle(Arg, Method, ["lwork", "mobile1","paytest","package_pay"|Ps]) -> 
    lw_mobile:handle(Arg, Method, ["paytest","package_pay"|Ps]);
handle(Arg, Method, ["lwork", "mobile1"|Ps]) -> 
    Obj=lw_mobile:handle(Arg, Method, Ps),
    io:format("lwork_app:handle mobile1 res:~p~n",[Obj]),
    Json_str=rfc4627:encode(Obj),
    Sep=[$a+random:uniform(9),$a+random:uniform(20)],
    Sep_bin = list_to_binary(Sep),
    <<Bin1:?MOBILE_SEP_POS/binary,Bin2/binary>>=base64:encode(Json_str),
    Enc_bin= <<Bin1/binary,Sep_bin/binary,Bin2/binary>>,
    utility:pl2jso([{data_enc,Enc_bin}]);
handle(Arg, Method, ["lwork", "mobile"|Ps]) -> 
%    io:format("lwork_app handle mobile,  Ps:~p~n", [Ps]),
    R=lw_mobile:handle(Arg, Method, Ps),
%    io:format("ack:~p~n", [R]),
    R;
handle(Arg, Method, ["lwork","sms"|Params])    -> sms_handler:handle(Arg, Method, Params);
handle(Arg, Method, ["lwork","mail"|Params])    -> mail_handler:handle(Arg, Method, Params);

%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    utility:pl2jso([{status,405}]).

origin(Arg)->
    Headers=Arg#arg.headers,
    yaws_api:get_header(Headers, 'Origin').
    
%% encode to json format
encode_to_json([{status,405}]) -> [{status,405}];
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.
  
enc_json(Result)-> rfc4627:encode(utility:pl2jso_r(utility:v2b_r(Result))).   

err_log(Arg,Reason)->
	{ok, IODev} = file:open("./log/server_error.log", [append]),
	io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
	file:close(IODev).


