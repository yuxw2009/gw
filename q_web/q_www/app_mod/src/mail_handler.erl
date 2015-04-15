-module(mail_handler).
-define(MAIL_SERVER,"http://10.32.3.52").
-define(MAIL_SERVER_URL, "http://10.32.3.52:8088").
-define(TIMEOUT, 5*60*1000).
-compile(export_all).

-include("yaws_api.hrl").

log(Str, Params)->
    {ok, IODev} = file:open("./log/server_error.log", [append]),
    io:format(IODev,Str,Params),
    file:close(IODev).

mail_server_url()->     ?MAIL_SERVER_URL.

out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,

    case catch handle(Arg, Method, Path) of
    	{'EXIT', Reason} -> 
    	    log("~p:  Arg: ~p~n Reason: ~n~p~n", [erlang:localtime(), Arg, Reason]),
    	    encode_to_json(utility:pl2jso([{status, failed}, {reason, Reason}]));
    	Result -> 
    	    Result
    end.

get_header_list(Arg)->
    Headers=Arg#arg.headers,
    NewHeader = yaws_api:set_header(Headers, 'Host', ?MAIL_SERVER),
    FormatFun = fun(K,V)->
        [K1]=io_lib:format("~s", [K]),
        [V1]=io_lib:format("~s", [V]),
        {K1,V1} end,
    yaws_api:reformat_header(NewHeader, FormatFun).

transfer_mail_server(Meth, Request)->
	case httpc:request(Meth, Request, [{timeout,?TIMEOUT}], []) of
		{ok, {_Satus_line, Res_Headers, Body}}->
			ResContentType=proplists:get_value("content-type",Res_Headers),
			{content, ResContentType, Body};
		{ok, {Status_code, Body}}->
		    BodyBin = if
		                    is_list(Body)-> list_to_binary(Body);
		                    true-> Body
		                 end,
		    Codestr = "code: "++integer_to_list(Status_code),
		    exit(<<Codestr, BodyBin/binary>>);
		{error, Reason}->    exit(Reason)
	end.

handle(Arg, Method, _Params)->
    inets:start(),
    {_, AbsPath} = (Arg#arg.req)#http_request.path,
    Clidata = Arg#arg.clidata,
    Content_type=(Arg#arg.headers)#headers.content_type,
    Meth=list_to_atom(string:to_lower(atom_to_list(Method))),
    Header_pl=get_header_list(Arg),
    Request=if
    			(Meth =/= get) and (Meth =/=delete)->
    				{?MAIL_SERVER_URL++AbsPath, Header_pl, Content_type, Clidata};
    			true-> {?MAIL_SERVER_URL++AbsPath, Header_pl}
    		end,
     transfer_mail_server(Meth, Request).

encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

test_big_file(File)->
    {ok, Body} = file:read_file(File),
    Content=rfc4627:encode(utility:pl2jso([{body,Body}])),
    Request={?MAIL_SERVER_URL++"/test_big_file" ,[],"application/json",Content},
    transfer_mail_server(post, Request).
