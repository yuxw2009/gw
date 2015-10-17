% for fetion sms send

-module(fetion_send).
-compile(export_all).

-define(SIPNUMGOT,60750).
-define(SENDACK,8566).
-define(LOGINED,55847).
-define(KEEPALIVE,56103).
-define(SMSCODEACK,57383).

-record(st, {
	acc,
	pwd,
	user_id,
	sock,
	accesstoken,
	tosend=[],   %[{id,id},{phone,phone},{sms,sms}]
	wtacks=[],    %[{MsgNo,Params,wt_sip_ack,Tref}|{MsgNo,Params,wt_send_ack,Tref}]
	finished=[],
	max_count=1,
	ok_count=0,
	wait_sipnum_tr,
	uuid= getUUID(),
	starttime,
	alive_tref,
	msgno=0,
	senderr,
	waitack_num=0,
	status=init       %init/connected/logined
}).

getServerAddr(Phone)->
    inets:start(),
    Url="http://mnav.fetion.com.cn/mnav/getnetsystemconfig.aspx?loginId=f98ac7dd-9339-5d60-1bc8-d2ec3de566cd",
    {ok,{_StatusLine,_Headers,Body}}=httpc:request(post,{Url,[],"application/oct-stream","<config><client type=\"Android\" version=\"5.5.1\" platform=\"AN2.2-GEN-GENERIC\" tag=\"gwad05510413\"/><user mobile-no=\""++Phone++"\"/><servers version=\"0\"/><service-no version=\"0\"/><parameters version=\"0\"/><credential domains=\"127.0.0.1\"/><mobile-no version=\"0\"/><ims version=\"0\"/></config>"},[],[{body_format,string}]),
    R=
    case re:run(Body,"<smartphone-adapter-v5>(.*)</smartphone",[{capture,all_but_first,binary}]) of
    {match,[Server]}-> {ok,Server};
    _-> failed
    end,
    io:format("server addr:~p~n",[R]),
    R.    

unused_get_key(_Phone,_Password)->
    ssl:start(),
    Url="http://oapi.feixin.10086.cn/oms-oauth2/auth/oauth2/wap_authz",
%    Payload="client_id=2131859e-57c9-45be-9cd4-9c62a094d29c&redirect_uri=http://www.baidu.com&state=1405465292&response_type=code&state="++timestamp()++"&data1=&scope=user%3AgetUserInfo+user%3AgetFriends+share%3Afriends+&isFirstGamer=&name="++Phone++"&password="++Password,
    Payload="client_id=2131859e-57c9-45be-9cd4-9c62a094d29c&redirect_uri=http%3A%2F%2Fwww.baidu.com&response_type=code&state=1440321826985&data1=&scope=user%3AgetUserInfo+user%3AgetFriends+share%3Afriends+&isFirstGamer=&name=13527755212&password=szfzd2014&code=",
    Res={ok,{_StatusLine,_Headers,Body}}=httpc:request(post,{Url,headers(),"application/x-www-form-urlencoded; charset=UTF-8",Payload},[{ssl,[{verify,0}]}],[{body_format,string}]),
%    io:format("~p~n",[Res]),
    R=
    case re:run(Body,"code=(.*)\"",[{capture,all_but_first,binary}]) of
    {match,[Key]}-> {ok,Key};
    _-> failed
    end,
    io:format("key:~p~n",[R]),
    Res.    

md5(D)->hex:to(crypto:hash(md5,D)).
key_json_str(Key)-> rfc4627:encode(utility:pl2jso([{key,Key}])).
rsa_str(Mobe,Password,VvcCookie,Code)->
    rfc4627:encode(utility:pl2jso_br([{username,Mobe},{loginpass,md5(Password)},{code,md5(Code)},{vvccookie,VvcCookie}])).
    
    

headers()->
    [{"Host","oapi.feixin.10086.cn"},
{"Connection","keep-alive"},
{"Referer","https://oapi.feixin.10086.cn/oms-oauth2/auth/oauth2/wap?client_id=2131859e-57c9-45be-9cd4-9c62a094d29c&redirect_uri=http://www.baidu.com&state=1405465292"},
{"Content-Length","245"},
{"Origin","https://oapi.feixin.10086.cn"},
{"X-Requested-With","XMLHttpRequest"},
{"Content-Type","application/x-www-form-urlencoded; charset=UTF-8"},
{"Accept","text/plain, */*; q=0.01"},
{"User-Agent","Mozilla/5.0 (Linux; U; Android 4.0.3; zh-cn; GT-S7572 Build/IML74K) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"},
{"Accept-Encoding","gzip,deflate"},
{"Accept-Language","zh-CN, en-US"},
{"Accept-Charset","utf-8, iso-8859-1, utf-16, *;q=0.7"}
    ].    

timestamp() ->
    {M, S, _} = os:timestamp(),
    integer_to_list(M * 1000000 + S).
   
    
    
%% following is from scholar, ios version
bin2hex(Bin)-> list_to_binary(lists:concat([integer_to_list(I,16)||I<-binary_to_list(Bin)])).
randomkey(Num)-> randomkey(Num,<<>>).
randomkey(0,Res)-> string:to_upper(hex:to(Res));
randomkey(N,Res)->
    I=random:uniform(255),
    randomkey(N-1,<<Res/binary,I>>).
    
%fetion client    
getUUID()->
    {B1,B2,B3,B4,B5}={randomkey(4),randomkey(2),randomkey(2),randomkey(2),randomkey(6)},
    binary_to_list(iolist_to_binary([B1,"-",B2,"-",B3,"-",B4,"-",B5])).
getUserId(Phone_str,UUID)->
    inets:start(),
    Url="http://mnav.fetion.com.cn/mnav/getNetSystemconfig.aspx?loginId=" ++ UUID,
    Postdata = "<config><client type=\"Iphone\" version=\"3.6.1\" platform=\"IOS\" cfg-version=\"0\" /><user mobile-no=\""++Phone_str++"\" /><servers version=\"0\" /><parameters version=\"0\" /><ims version=\"0\" /></config>",
    {ok,{_StatusLine,_Headers,Body}}=httpc:request(post,{Url,[],"application/oct-stream",Postdata},[],[{body_format,string}]),
    R=
    case re:run(Body,"config uid=\"(.*)\"",[{capture,all_but_first,list},ungreedy]) of
    {match,[UserId_str]}-> list_to_integer(UserId_str);
    _-> undefined
    end,
%    io:format("getUserId:~p~n",[R]),
    R.    

test_loginpkg()->
    creatLoginPackage(1149923715,"sunshine89744632","201508241034149934348044590931",<<"175D1012-6278-4131-BC92-8480C965F8DB">>).
creatLoginPackage(UserId,Password,AccessToken,UUID)->creatLoginPackage(UserId,Password,AccessToken,UUID,100000000+random:uniform(999999999-100000000),xt:dt2str(erlang:localtime())).
creatLoginPackage(UserId,Password,AccessToken,UUID,Random,NowStr)->
    Temp=crypto:hash(sha,"fetion.com.cn:" ++Password),
    Temp1= <<UserId:32/little,Temp/binary>>,
    Skey= crypto:hash(sha,Temp1),
    Temp2=crypto:hash(md5,Skey),
    Ckey=crypto:hash(md5,upper_hex(Temp2)),
    ToEncryptArray=iolist_to_binary([upper_hex(Skey),"%",integer_to_list(Random),"%",NowStr]),
%    io:format("toenc:~p~nckey:~p~n",[ToEncryptArray,Ckey]),
    EncryptArray0=aes_encrypt(ToEncryptArray,Ckey),
    EncryptArray=upper_hex(EncryptArray0),
%    io:format("enc:~p~n",[EncryptArray]),
    Unknown1=str2hex("DA 27 00 00 0F 00 19 00 00 0F 00 03 00 00 00 00 00 00 10 00 18 00 22"),
    EncLen=length(EncryptArray),
    Bin1=iolist_to_binary([<<UserId:32/little>>,Unknown1,<<EncLen:8>>,16#1,list_to_binary(EncryptArray),str2hex("30 90 03 38 00 "),str2hex("42 06 "),"Iphone",
         str2hex("4A 05"),"3.6.1",str2hex("52 1E "),AccessToken,str2hex("5A 08"),"3B408417b",16#09,"A8B7FC000",
         str2hex("6A 01 "),16#66,str2hex("72 10 "),"gw.ios.0361.0512",str2hex("7A 28"),"imsi:;apn:;imei:;sdk:;Phone Model:iPhone",16#82,16#01,
         16#88,16#01,"m161.com.cn;fetion.com.cn;turn.fetion.com.cn;epay.feixin.10086.cn;shequ.10086.cn;www.ikuwa.cn;caiyun.10086.cn;127.0.0.1;cf.fetion.com.cn",
         16#92,16#01,16#24,UUID,16#98, 16#01,16#00]),
     Length=size(Bin1)+3,
     <<16#1e,Length:16/big,Bin1/binary>>.

sms_bin(SipNum,Sms,UserId,MsgNo) when is_binary(SipNum), is_binary(Sms)->
    MessageBody= <<"<Font FaceEx=\"mrfont\">",Sms/binary, "</Font>">>,
    IoList=[str2hex("00 1e"),<<UserId:32/little>>,str2hex("21 76 00 00"), MsgNo, str2hex("00 19 00 00 0f 00 03 00 00 00 00 00 00 0a"),size(SipNum),
       SipNum,str2hex("12 0a"),"text/plain",str2hex("1a 24"),getUUID(),str2hex("22"),size(MessageBody),MessageBody],
    Bin=iolist_to_binary(IoList),
    MsgLen=size(Bin)+1,
    <<MsgLen,Bin/binary>>;
sms_bin(SipNum,Sms,UserId,MsgNo)-> sms_bin(iolist_to_binary(SipNum),iolist_to_binary(Sms),UserId,MsgNo).

keepalive_bin(UserId)->
    IoList=[str2hex("00 1e"),<<UserId:32/little>>,str2hex("db 27 00 00 18 00 19 00 00 0f 00 03 00 00 00 00 00 00 08 01 12 88 01"),
        "m161.com.cn;fetion.com.cn;turn.fetion.com.cn;epay.feixin.10086.cn;shequ.10086.cn;www.ikuwa.cn;caiyun.10086.cn;127.0.0.1;cf.fetion.com.cn"
        ],
    Bin=iolist_to_binary(IoList),
    Size=size(Bin)+1,
    <<Size,Bin/binary>>.

get_sip_req(Phonenum,UserId,MsgNo)->
    Content= [str2hex("00 1e"),<<UserId:32/little>>,str2hex("ed 4e 00 00"),MsgNo,str2hex("00 19 00 00 0f 00 03 00 00 00 00 00 00 1a 0f 74 65 6c 3a"),Phonenum],
    ConBin=iolist_to_binary(Content),
    Len=size(ConBin)+1,
    <<Len,ConBin/binary>>.
    
aes_encrypt(ToEncryptArray,Key)->
    Len = size(ToEncryptArray),
    Rem=Len rem 16,
    Puddings=binary:copy(<<16#20>>,if Rem==0-> 0; true-> 16-Rem end),
    Puddings2=binary:copy(<<16>>,16),
    ToEncryptArray1 = <<ToEncryptArray/binary, Puddings/binary, Puddings2/binary>>,
    aes_encrypt1(ToEncryptArray1,Key,<<>>).
aes_encrypt1(<<>>,_Key,Res)-> Res;
aes_encrypt1(<<ToEnc:16/binary,Tail/binary>>,Key,Res)-> 
    Result=crypto:block_encrypt(aes_ecb,Key,ToEnc),
    aes_encrypt1(Tail,Key,<<Res/binary,Result/binary>>).

str2hex(Str)-> list_to_binary([list_to_integer(I,16)||I<-string:tokens(Str," ")]).    

%test_start()-> start("15920857655","sam123","201508242036808155082914054919").
test_start()-> start("13431946684", "fei6543262626xin", "201508247183256304984136608463").
%"13532240094","fei6543262626xin","201508241577747243242336303758"
%"13431946684", "fei6543262626xin", "201508247183256304984136608463"
%"15916288609" "fei6543262626xin"  "201508244627318549512639283635"

test_send(Pid)-> test_send(Pid,<<"18017813673">>).
test_send(Pid,Phone) when is_list(Phone)->  test_send(Pid,list_to_binary(Phone));
test_send(Pid,Phone)->
    Params=[{"id","test"},{"sendto",Phone},{"sms",<<"hello1">>}],
    Pid ! {send_sms,Params}.
send(Pid,Id,Phone,Sms)->
    Params=[{"id",Id},{"sendto",Phone},{"sms",Sms}],
    Pid ! {send_sms,Params}.
tcp_arrived(_Msg= <<_:7/binary,?LOGINED:16,_:16,_:32,0:8,_:6/binary,Error:8,_/binary>>,ST=#st{acc=_Phone})-> 
    if Error == 16#91-> io:format("invalid password~n");
       Error == 16#90-> io:format("invalid deviceid~n");
       true-> io:format("unknown error~n")
    end,
    log(ST,"login error:~p~n",[Error]),
    {stop,hex:to(<<Error>>),ST};
tcp_arrived(_Msg= <<_:7/binary,?LOGINED:16,_:16,_:32,1:8,_/binary>>,ST=#st{status=connected})-> 
%    io:format("logined,msglen:~p:pid:~p~n",[size(Msg),self()]),
    my_timer:send_interval(120*1000,keepalive),
    my_timer:send_interval(1000,time_to_send),
    log(ST,"logined ok~n",[]),
    {noreply,ST#st{status=logined}};
tcp_arrived(_Msg= <<_:7/binary,?KEEPALIVE:16,_/binary>>,ST=#st{status=logined})-> 
%    io:format("keepaive recved~n"),
    {noreply,ST};
tcp_arrived(_Msg= <<_:7/binary,?SMSCODEACK:16,Tail/binary>>,ST)-> 
    Len=size(Tail)-2,
    <<_:Len/binary,Status:16>> = Tail,
    if Status == 40194-> io:format("send smscode success!");
       true-> io:format("send smscode error!")
    end,
    {noreply,ST};
tcp_arrived(Msg= <<_:7/binary,?SIPNUMGOT:16,_:16,MsgNo,_:19/binary,Len:8,Sip:Len/binary,_/binary>>,ST=#st{user_id=UserId,sock=Sock,wtacks=Sended})-> 
    log(ST,"sipnum msg rec:~n~p",[hex:to(Msg)]),
    case proplists:get_value(MsgNo,Sended) of
    [wt_sip_ack,Params,Tr|Other]->
        my_timer:cancel(Tr),
        SipNum=binary_to_list(Sip),
    %    io:format("SipNum:~p Other:~p Byte22~p~n",[SipNum,Other,Byte22]),
        Sms=proplists:get_value("sms",Params),
        Bin=sms_bin(SipNum,Sms,UserId,MsgNo),
        log(ST,"getsipnum ok:~p MsgNo:~p~n",[SipNum,MsgNo]),
        gen_tcp:send(Sock,Bin),
        {ok,NTr}=my_timer:send_after(5000,{send_timeout,MsgNo}),
        NSended=lists:keystore(MsgNo,1,Sended,{MsgNo,[wt_send_ack,Params,NTr|Other]}),
        {noreply,ST#st{wtacks=NSended}};
    R->
        log(ST,"impossible! SIPNUMGOT not related msgno(~p):value:~p~n",[MsgNo,R]),
        {noreply,ST}
    end;
tcp_arrived(<<_:7/binary,?SENDACK:16,_:16,MsgNo,_:13/binary,Len:8,Error:Len/binary,_/binary>>,ST=#st{ok_count=Oks,wtacks=Sended,finished=Finished})-> 
    case proplists:get_value(MsgNo,Sended) of
    [wt_send_ack,Params,Tr|_]->
        my_timer:cancel(Tr),
        NSended=lists:keydelete(MsgNo,1,Sended),
        Id=proplists:get_value("id",Params,""),
        if Len==0->
            notify_sendres(ST,Id,"100"),
            log(ST,"send ok MsgNo:~p~n",[MsgNo]),
            {noreply,ST#st{ok_count=Oks+1,wtacks=NSended,finished=[{sendok,Params}|Finished]}};
        true->
            %ftmngr_send:% resend tosend and wtacks untill 3 times  with other accounts
            SendNum=proplists:get_value("sendnum",Params,0)+1,
            if SendNum>=3-> notify_sendres(ST,Id,"200"); 
            true-> 
                NParams=lists:keystore("sendnum",1,Params,{"sendnum",SendNum}),
                switch_other_acount_send(NParams) 
            end,
            SendError=binary_to_list(Error),
            log(ST,"send error:~p~n",[SendError]),
            {noreply,ST#st{wtacks=NSended,senderr=SendError,finished=[{senderr,Params}|Finished]}}
        end;
    R->
        log(ST,"impossible! sendack not related msgno(~p):value:~p~n",[MsgNo,R]),
        {noreply,ST}
    end;
    
tcp_arrived(<<_:7/binary,Type:16,_:16,MsgNo,_/binary>> = Bin,ST)    ->
    log(ST,"tcp_arrived unknown type:~p msgno:~p~n~p",[Type,MsgNo,hex:to(Bin)]),
    {noreply,ST};
tcp_arrived(Bin,ST)    ->
    log(ST,"tcp_arrived unknown bin:~p~n",[Bin]),
    {noreply,ST}.

client(PortNo,Message) ->
    {ok,Sock} = gen_tcp:connect("localhost",PortNo,[{active,false},
                                                    {packet,2}]),
    gen_tcp:send(Sock,Message),
    A = gen_tcp:recv(Sock,0),
    gen_tcp:close(Sock),
    A.    

send_timeout(MsgNo,St=#st{wtacks=Sended,finished=Finished})->
    case proplists:get_value(MsgNo,Sended) of
    Value=[wt_sip_ack,Params|_]->
        Id=proplists:get_value("id",Params),
        notify_sendres(St,Id,"300"),
        log(St,"send_timeout 300 msgno:~p~nvalue:~p~n",[MsgNo,Value]),
        NSended=lists:keydelete(MsgNo,1,Sended),
        St#st{wtacks=NSended,finished=[{wt_sip_timeout,Params}|Finished]};
    Value=[wt_send_ack,Params|_]->
        Id=proplists:get_value("id",Params),
        notify_sendres(St,Id,"400"),
        log(St,"send_timeout 400 msgno:~p~nvalue:~p~n",[MsgNo,Value]),
        NSended=lists:keydelete(MsgNo,1,Sended),
        St#st{wtacks=NSended,finished=[{wt_sendout_timeout,Params}|Finished]};
    R->
        log(St,"impossible send_timeout: item: ~p~n",[R]),
        St
    end.

%1 all send out and acked, has error, exit
time_to_send(St=#st{tosend=[],wtacks=[],senderr=SendErr}) when SendErr=/=undefined->  St#st{status=stop};
%2 all send out and acked, no error
time_to_send(St=#st{tosend=[],ok_count=Oks,wtacks=[],max_count=Max})-> 
    if Max>Oks->
        Count=Max-Oks,
        case ftmngr_send:fetch_needsends(Count) of
        NeedSends when is_list(NeedSends) andalso length(NeedSends)>0-> 
            St#st{tosend=NeedSends};
        _-> 
            fetch_sms_from_server(St,Count)
        end;
    true-> St#st{status=stop}
    end;
%3 all send out, but has noack,just waiting. but avoid waiting forever because of some problems, add count
time_to_send(St=#st{tosend=[],waitack_num=WtNum}) when WtNum<10-> St;
%4 all send out, but has noack,just waiting. but avoid waiting forever because of some problems, add count, if exceed 10 times,must have problems.
% must stopped and resend wtacks in terminate
time_to_send(St=#st{tosend=[]})-> St#st{status=stop};
%5 send it    
time_to_send(St=#st{sock=Sock,tosend=[Params|Lefts],user_id=User_id,msgno=MsgNo,wtacks=Sended})->
    {Phone}={proplists:get_value("sendto",Params)},
    SipReqBin=get_sip_req(Phone,User_id,MsgNo),
    log(St,"time_to_send phone:~p user_id:~p~n SipReqBin:~p~n",[Phone,User_id,SipReqBin]),
    gen_tcp:send(Sock,SipReqBin),
    {ok,Tr}=my_timer:send_after(5000,{send_timeout,MsgNo}),
    time_to_send(St#st{msgno=msgno_inc(MsgNo),tosend=Lefts,wtacks=[{MsgNo,[wt_sip_ack,Params,Tr]}|Sended]}).

msgno_inc(MsgNo)-> (MsgNo+1) rem 256.
start(Phone,Pwd,AccessToken) ->start(Phone,Pwd,AccessToken,1).
start(Phone,Pwd,AccessToken,MaxCount) ->
    my_timer:start(),
    my_server:start(?MODULE,[Phone,Pwd,AccessToken,MaxCount],[]).

log(#st{acc=Phone},Str,CmdList)->
    io:format(Str++"~n",CmdList),
    utility:log("Phone:~p "++Str,[Phone|CmdList]).
    
init([Phone,Pwd,AccessToken,MaxCount]) ->
    ST0=#st{acc=Phone,pwd=Pwd,accesstoken=AccessToken,starttime=os:timestamp(),max_count=MaxCount},
    case getUserId(Phone,ST0#st.uuid) of
    undefined->
        io:format("failed to getuserid, my_server exit~n"),
        notify_error(Phone,"userid_unavailable"),
        log(ST0,"getUserId error,exit",[]),
        ignore;
    UserId->
        my_timer:send_after(500, time_to_login),
        ST=ST0#st{status=connected,user_id=UserId},
        {ok,ST}
    end.

handle_info({send_sms,Params},State=#st{tosend=ToSend}) ->
    {noreply,State#st{tosend=ToSend++[Params]}};
handle_info({send_timeout,MsgNo},State) ->
    NSt=send_timeout(MsgNo,State), % Not implemented in this example
    {noreply,NSt};
handle_info(keepalive,State=#st{user_id=UserId,sock=Sock}) ->
%    io:format("time_to_send:~p~n",[self()]),
    Bin=keepalive_bin(UserId),
%    io:format(" ~p ",[UserId]),
    gen_tcp:send(Sock,Bin),
    {noreply,State};
handle_info(time_to_send,State=#st{max_count=Max,ok_count=Oks}) when Oks>=Max andalso Oks>0 ->
    {stop,normal,State};
handle_info(time_to_send,State=#st{status=stop}) ->
    {stop,normal,State};
handle_info(time_to_send,State) ->
%    io:format("time_to_send:~p~n",[self()]),
    NSt=time_to_send(State), % Not implemented in this example
    {noreply,NSt};
handle_info(time_to_login,#st{pwd=Password,user_id=UserId,accesstoken=AccessToken,uuid=UUID} = State)  ->    
    {ok,Sock} =gen_tcp:connect("221.176.31.144",8023,[{active,true},{send_timeout, 5000},{packet,0},binary]),
    log(State,"connected and tologin ~p~n",[{UserId,Password,AccessToken}]),
    LoginPkg=creatLoginPackage(UserId,Password,AccessToken,UUID),
    gen_tcp:send(Sock,LoginPkg),
    {noreply,State#st{sock=Sock}};
handle_info({tcp,_Sock,Data = <<_:7/binary,_Event:16,_Msgno,_/binary>>},State) ->
%    io:format("fetion recv tcp: event:~p  msgno:~p~n",[Event,Msgno]),
%    io:format("tcp recved:event:~p~ndata:~p~n",[Event,string:to_upper(hex:to(Data))]),
    tcp_arrived(Data,State);
handle_info({tcp_closed,S},State) ->
    log(State,"Socket ~w closed [~w]~n",[S,self()]),
    {stop,normal,State};
handle_info(stop,State) ->
    io:format("recv stop~n"),
    {stop,normal,State};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};
handle_call(stop,_Frome, ST) ->
    {stop,normal,ok,ST}.
terminate(Reason,St=#st{acc=Phone,pwd=Pwd,accesstoken=Token,starttime=StartTime,sock=Sock,status=Status,ok_count=Oks})->  
    Time=os:timestamp(),
    Diff=timer:now_diff(Time,StartTime) div 1000000,
    NotifyResult=
    if Status==connected->     
        notify_error(Phone,Reason);
    true-> 
        rpc:call('xm_ctrl@119.29.62.190',config,fetion_acc,[Phone,Pwd,Token]),
        F=fun()->
            Url="http://feixin.91yunma.cn/openapi/getaccountforfasong.html?Phone="++Phone++"&Sendcount="++integer_to_list(Oks)++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",
            miui:httpc_call(get,{Url})
        end,
        repeat_notify(F)
    end,
    log(St,"terminate status:~p oks:~p diff:~p Reason:~p~n notifyResult:~p",[Status,Oks,Diff,Reason,NotifyResult]),
    if Sock=/=undefined-> gen_tcp:close(Sock); true-> void end,
    stop.
stop(Pid)->    my_server:call(Pid,stop).    


repeat_notify(F)->repeat_notify(F,3).
repeat_notify(F,1)-> F();
repeat_notify(F,N)->
    case F() of
    httpc_failed-> repeat_notify(F,N-1);
    R->R
    end.

notify_sendres(ST,Id,Res) when is_binary(Id)->notify_sendres(ST,binary_to_list(Id),Res);
notify_sendres(ST,Id,Res)->
    F=fun()-> notify_sendres1(ST,Id,Res) end,
    repeat_notify(F).
notify_sendres1(_ST,Id,Res)->
    Url="http://feixin.91yunma.cn/openapi/setfasongresult.html?SetData="++Id++"_"++Res++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",
    miui:httpc_call(get,{Url}).

notify_error(Phone,Error)->notify_error(Phone,Error,"unknown").
notify_error(Phone,Error,Reason)->
    F=fun()-> notify_error1(Phone,Error,Reason) end,
    repeat_notify(F).
notify_error1(Phone,Error,Reason)->
    ReasonStr = if is_list(Error)-> Error; is_atom(Error)-> atom_to_list(Error); true-> "abnormal" end,
    Url0="http://feixin.91yunma.cn/openapi/getaccountforfasong.html?Phone="++Phone++"&Error="++ReasonStr,
    Url=Url0++"&Reason="++Reason++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",
    miui:httpc_call(get,{Url}).

upper_hex(B)-> string:to_upper(hex:to(B)).

uri_encode(Uri)-> http_uri:encode(Uri).
show(Pid)->
    Act=fun(St)->
        {St,St}
    end,
    my_server:call(Pid,{act,Act}).


start_bystr(Str)->
    [Acc,Pwd,Token]=string:tokens(Str," "),
    start(Acc,Pwd,Token).

switch_other_acount_send(Params) -> ftmngr_send:store_needsends(Params).
fetch_sms_from_server(St=#st{tosend=ToSends0},Count) when is_integer(Count) andalso Count>0 ->
    Url="http://feixin.91yunma.cn/openapi/getfasongdata.html?Amount="++integer_to_list(Count)++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",    
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            JsonItems=utility:get(DataJson,"datalist"),
            ToSends=[[{"sendnum",0}|Itm_]||{obj,Itm_}<-JsonItems],
            if length(ToSends)>0-> log(St,"fetch_sms_from_server Sends:~p~n",[ToSends]); true-> void end,
            St#st{tosend=ToSends0++ToSends};
        _-> St
        end;
    _-> St
    end;
fetch_sms_from_server(St,_)-> St.
