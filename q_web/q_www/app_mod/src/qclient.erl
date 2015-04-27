-module(qclient).
-compile(export_all).

get_all_info(Acc)->
    Jpg=get_img(),
    case recognize_code(Jpg) of
        {ok,{_,_,Body}}->
            case rfc4627:decode(Body) of
                {ok,{obj,Params},[]}->
                    AuthCode=binary_to_list(proplists:get_value("result",Params)),
                    io:format("authcode Params:~p~n",[Params]),
                    ImgId=binary_to_list(proplists:get_value("imgId",Params)),
                    get_all_info(Acc,AuthCode,ImgId,Jpg);
                _->[{status,failed},{reason,code_unparsable},{jpg,Jpg}]
            end;
        _->  [{status,failed},{reason,code_unrecognize_code},{jpg,Jpg}]
    end.
get_all_info(Acc,AuthCode)->get_all_info(Acc,AuthCode,"","").
get_all_info(Acc,AuthCode,ImgId,Jpg)->
    case get_status(Acc,AuthCode) of
        {lock,[T,Loc,Reason,AddInfo= <<"">>]}->  
            case get_jfcode(Acc,AuthCode) of
            {ok,JFStr}->
                [{status,ok},{state,lock},{time,T},{loc,Loc},{reason,Reason},{addinfo,AddInfo},{auth_code,JFStr}];
            _-> [{status,ok},{state,lock},{time,T},{loc,Loc},{addinfo,AddInfo},{reason,Reason}]
            end;
        {lock,[T,Loc,Reason,AddInfo]}->  
            [{status,ok},{state,lock},{time,T},{loc,Loc},{addinfo,AddInfo},{reason,Reason}];
        {verify_code_err,_Bin}-> 
            JpgFile=AuthCode++"_"++ImgId++".jpg",
            file:write_file(JpgFile,Jpg),
            [{status,failed},{reason,verify_code_err},{imgid,ImgId},{authcode,AuthCode},{jpgfile,JpgFile}];
        unlock-> [{status,ok},{state,unlock}];
        {Reason,_}->  [{status,failed},{reason,Reason},{jpg,Jpg}]
    end.
get_auth_code(Jpg)->
    case recognize_code(Jpg) of
        {ok,{_,_,Body}}->
            case rfc4627:decode(Body) of
                {ok,{obj,Params},[]}->
                    {ok,Fd}=file:open("yzm1.jpg",[write]),
                    file:write(Fd,Jpg),
                    file:close(Fd),
                    io:format("get_auth_code:~p~n",[Params]),
                    [{status,ok},{authcode,proplists:get_value("result",Params)}];
                _->[{status,failed},{reason,code_unparsable}]
                end;
        _->  [{status,failed},{reason,code_unrecognize_code}]
    end.
    
get_img()->
    inets:start(),
    httpc:set_options([{cookies,enabled}]),
    {ok,{_StatusLine,Headers,Body}}=httpc:request(get,{"http://captcha.qq.com/getimage?aid=2001601&0.5957661410793789",headers()},[],[{body_format,binary}]),
    {ok,Fd}=file:open("yzm.jpg",[write]),
    file:write(Fd,Body),
    file:close(Fd),
    save_cookies(Headers),
    Body.
manual_get_jpg()->
    inets:start(),
    httpc:set_options([{cookies,enabled}]),
    {ok,{_StatusLine,Headers,Body}}=httpc:request(get,{"http://captcha.qq.com/getimage?aid=2001601&0.5957661410793789",headers()},[],[{body_format,binary}]),
    Cookiestr=proplists:get_value("set-cookie",Headers,""),
    [{status,ok},{jpg,base64:encode(Body)},{clidata,Cookiestr}].

manual_query({Qno,Code,Clidata})->
    inets:start(),
    httpc:set_options([{cookies,enabled}]),
    save_cookies([{"set-cookie",Clidata}]),
    get_all_info(Qno,Code).

recognize_code(JpgBin)->
    inets:start(),
    Url="http://api2.sz789.net:88/RecvByte.ashx?timestamp=675676575675",
    Uname="testyyy",
    Pwd="321123",
    Sid="12926",
    Img=jpg2str(JpgBin),
    Body=string:join([K++"="++V||{K,V}<-[{"username",Uname},{"password",(Pwd)},{"softId",(Sid)},{"imgdata",(Img)}]],"&"),
    httpc:request(post,{Url,[],"application/x-www-form-urlencoded",Body},[],[{body_format,string}]).    

get_status()-> get_status(test_acc()).
get_status(Acc)->get_status(Acc,test_code()).
get_status(Acc,AuthCode)->
    case catch rfc4627:decode(get_verify_code(Acc,AuthCode)) of
    {ok, {obj,[{"Err",<<"0">>}]},_}-> get_checkstate(Acc,AuthCode);
    {ok, {obj,[{"Err",Bin}]},_}-> {verify_code_err,Bin};
    R-> {get_verify_code_err,R}
    end.

get_verify_code()-> get_verify_code(test_acc()).
get_verify_code(Acc)-> get_verify_code(Acc,test_code()).
get_verify_code(Acc,Code)->
    Url=host()++"/cn2/ajax/check_verifycode?verify_code="++Code++"&account="++Acc++"&session_type=on_rand",
    {ok,{StatusLine,Headers,Body}}=httpc:request(get,{Url,headers()},[],[{body_format,string}]),
    io:format("get_verify_code:headers:~p~nbody:~p~n",[Headers,Body]),
    save_cookies(Headers),
    Body.

get_checkstate()-> get_checkstate(test_acc()).
get_checkstate(Acc)-> get_checkstate(Acc,test_code()).
get_checkstate(Acc,Code)->
    Url=host()++"/cn2/login_limit/checkstate?from=1&account="++Acc++"&verifycode="++Code++"&_=1428751303426",
    {ok,{StatusLine,Headers,Body}}=httpc:request(get,{Url,headers()},[],[{body_format,string}]),
    io:format("get_checkstate:headers:~p~nbody:~p~n",[Headers,Body]),
    save_cookies(Headers),
    case catch rfc4627:decode(Body) of
        {ok,{obj,[{"if_lock",1}]},_}->
            case catch get_lock_detail(get_limit_detail(Acc,Code)) of
                {match,[Time,Location,Reason,AddInfo]}->  {lock, [Time,Location,Reason,AddInfo]};
                R->  {get_lock_detail_err, R}
            end;
        {ok,{obj,[{"if_lock",0}]},_}-> unlock;
        {ok,{obj,[{"if_lock",2}]},_}-> {checkstate_timeout,if_lock_2};
        R-> {get_checkstate_err,R}
    end.

get_limit_detail()-> get_limit_detail(test_acc()).
get_limit_detail(Acc)-> get_limit_detail(Acc,test_code()).
get_limit_detail(Acc,Code)->
    Url=host()++"/cn2/login_limit/limit_detail_v2?account="++Acc++"&verifycode="++Code++"&_=1428751303429",
    {ok,{StatusLine,Headers,Body}}=httpc:request(get,{Url,headers()},[],[{body_format,string}]),
%    io:format("get_limit_detail:headers:~p~nbody:~p~n",[Headers,Body]),
    save_cookies(Headers),
    Body.

get_clickcount()-> get_clickcount(test_acc()).
get_clickcount(Acc)-> get_clickcount(Acc,test_code()).
get_clickcount(Acc,Code)->
    Url=host()++"/cn2/login_limit/clickcount?_=1428822247186&type=1",
    {ok,{StatusLine,Headers,Body}}=httpc:request(get,{Url,headers()},[],[{body_format,string}]),
    io:format("get_clickcount:headers:~p~nbody:~p~n",[Headers,Body]),
    save_cookies(Headers),
    Body.

get_jfcode()-> get_jfcode(test_acc()).
get_jfcode(Acc)-> get_jfcode(Acc,test_code()).
get_jfcode(Acc,Code)->
    case rfc4627:decode(getsms(Acc,Code)) of
        {ok, {obj,[{"sms",JFCode}]},_} when size(JFCode)==6 ->
            {ok,binary_to_list(JFCode)};
        O->  {failed,O}
    end.

getsms()-> getsms(test_acc()).
getsms(Acc)-> getsms(Acc,test_code()).
getsms(Acc,Code)->
    Url=host()++"/cn2/login_limit/getsms",
    {ok,{StatusLine,Headers,Body}}=httpc:request(post,{Url,headers(),"application/x-www-form-urlencoded","verifycode="++Code},[],[{body_format,string}]),
    io:format("getsms:headers:~p~nbody:~p~n",[Headers,Body]),
    save_cookies(Headers),
    Body.

get_lock_detail(Body)->
    AddInfo=
    case re:run(Body,"(已被冻结|改密立即恢复登录|申诉成功立即恢复登录)",[{capture,all_but_first,binary}]) of
    {match,[R]}-> R;
    _-> <<"">>
    end,
    case re:run(Body,"<td>(.*)</td>\n.*<td>(.*)</td>\n.*<td>(.*)</td>\n.*</tr>[\t\n]+.*</tbody>",[{capture,all_but_first,binary}]) of
    {match,[Time,Location,Reason]}-> {match,[Time,Location,Reason,AddInfo]};
    _-> {match,["","","",AddInfo]}
    end.

test_acc()->"1160987120".
test_code()-> get(verify_code).
save_code(C)->put(verify_code,C).

save_cookies(Headers)->
    Cookiestr=proplists:get_value("set-cookie",Headers,""),
    Cookies= string:tokens(Cookiestr,";"),
    [httpc:store_cookies([{"set-cookie",I}],"http://aq.qq.com")||I<-Cookies,lists:member($=,I)].

host()-> "http://aq.qq.com".
headers()->
    [{"Referer","http://aq.qq.com/cn2/login_limit/login_limit_index"},{"Content-Type","application/x-www-form-urlencoded"},{"User-Agent","Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727)"}].    

jpg2str(Bin)->
    L=binary_to_list(Bin),
    lists:flatten([byte2char(I)||I<-L]).

byte2char(Byte)->
    Pre=integer_to_list(Byte,16),
    R=if length(Pre) == 1-> "0"++Pre; true-> Pre end,
    R.%lists:reverse(R).
