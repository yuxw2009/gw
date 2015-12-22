% for fetion sms send

-module(fetion_send).
-compile(export_all).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-include("getContactInfoV5Rsp_pb.hrl").
-include("getContactInfoV5Req_pb.hrl").
-include("svcSendSms_pb.hrl").

-define(SIPNUMGOT,60750).
-define(SENDACK,8566).
-define(LOGINED,55847).
-define(KEEPALIVE,56103).
-define(SMSCODEACK,57383).

-define(SEND_TIMEOUT,10000).
-define(SEND_INTERVAL,20000).

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
	senderr=normal,
	waitack_num=0,
    debug,
	status=init       %init/connected/logined
}).

%test_start()-> start("15920857655","sam123","201508242036808155082914054919").
test_start()-> start("13424496908","123asdcvxs","201508249423724334049843333186").
start_send_test(Phone,Pwd,AccessToken,Count)-> 
    my_timer:start(),
    my_server:start(?MODULE,[send_test,Phone,Pwd,AccessToken,Count],[]).
%"13532240094","fei6543262626xin","201508241577747243242336303758"
%"13431946684", "fei6543262626xin", "201508247183256304984136608463"
%"15916288609" "fei6543262626xin"  "201508244627318549512639283635"
start(Phone,Pwd,AccessToken) ->start(Phone,Pwd,AccessToken,1).
start(Phone,Pwd,AccessToken,MaxCount) ->
    my_timer:start(),
    my_server:start(?MODULE,[Phone,Pwd,AccessToken,MaxCount],[]).

stop(Pid)->    my_server:call(Pid,stop).    


test_send(Pid)-> test_send(Pid,<<"13816461488">>).
test_send(Pid,Phone) when is_list(Phone)->  test_send(Pid,list_to_binary(Phone));
test_send(Pid,Phone)->  test_send(Pid,Phone,<<"hello1">>).
test_send(Pid,Phone,SmsBin)->
    Params=[{"id","test"},{"sendto",Phone},{"sms",SmsBin}],
    Pid ! {send_sms,Params}.
init([send_test,Phone,Pwd,AccessToken,MaxCount]) ->
    {ok,ST}=init([Phone,Pwd,AccessToken,MaxCount]),
    {ok,ST#st{debug=send_test}};
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

handle_info({send_sms,Params},ST=#st{tosend=ToSend}) ->
    {noreply,ST#st{tosend=ToSend++[Params]}};
handle_info({send_timeout,MsgNo},ST) ->
    NSt=send_timeout(MsgNo,ST), % Not implemented in this example
    {noreply,NSt};
handle_info(keepalive,ST=#st{user_id=UserId,sock=Sock}) ->
%    io:format("time_to_send:~p~n",[self()]),
    Bin=keepalive_bin(UserId),
%    io:format(" ~p ",[UserId]),
    tcp_send(ST,Sock,Bin),
    {noreply,ST};
handle_info(time_to_send,ST=#st{max_count=Max,ok_count=Oks}) when Oks>=Max andalso Oks>0 ->
    {stop,normal,ST};
handle_info(time_to_send,ST=#st{status=stop,senderr=SendErr}) ->
    {stop,SendErr,ST};
handle_info(time_to_send,ST) ->
%    io:format("time_to_send:~p~n",[self()]),
    NSt=time_to_send(ST), % Not implemented in this example
    {noreply,NSt};
handle_info(time_to_login,#st{pwd=Password,user_id=UserId,accesstoken=AccessToken,uuid=UUID} = ST)  ->    
    {ok,Sock} =gen_tcp:connect("221.176.31.144",8023,[{active,true},{send_timeout, 5000},{packet,0},binary]),
    log(ST,"connected and tologin ~p~n",[{UserId,Password,AccessToken}]),
    LoginPkg=creatLoginPackage(UserId,Password,AccessToken,UUID),
    tcp_send(ST,Sock,LoginPkg),
    {noreply,ST#st{sock=Sock}};
handle_info({tcp,_Sock,Data = <<_:7/binary,_Event:16,_Msgno,_/binary>>},ST) ->
%    io:format("fetion recv tcp: event:~p  msgno:~p~n",[Event,Msgno]),
%    io:format("tcp recved:event:~p~ndata:~p~n",[Event,string:to_upper(hex:to(Data))]),
%    log(ST,"===> ~p",[Data]),
    tcp_arrived(Data,ST);
handle_info({tcp_closed,S},ST) ->
    log(ST,"Socket ~w closed [~w]~n",[S,self()]),
    {stop,normal,ST};
handle_info(stop,ST) ->
    io:format("recv stop~n"),
    {stop,normal,ST};
handle_info(Msg,ST)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,ST}.
handle_call({act,Act},_Frome, ST) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};
handle_call(stop,_Frome, ST) ->
    {stop,normal,ok,ST}.
terminate(Reason,ST=#st{acc=Phone,pwd=Pwd,accesstoken=Token,starttime=StartTime,sock=Sock,status=Status,ok_count=Oks})->  
    Time=os:timestamp(),
%    Diff=timer:now_diff(Time,StartTime) div 1000000,
    NotifyResult=
    if Status==connected->     
        notify_error(Phone,Reason);
    true-> 
        rpc:call('xm_ctrl@119.29.62.190',config,fetion_acc,[Phone,Pwd,Token]),
        F=fun()->
            Url0="http://feixin.91yunma.cn/openapi/getaccountforfasong.html?Phone="++Phone++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",
            ErrStr=if Reason==normal-> ""; is_list(Reason)-> "&Error=S0001&Reason="++Reason; is_atom(Reason)-> "&Error=S0001&Reason="++atom_to_list(Reason); true-> "" end,
            Url=if ErrStr=/=""-> Url0++ErrStr; true-> Url0++"&Sendcount="++integer_to_list(Oks) end,
            miui:httpc_call(get,{Url})
        end,
        repeat_notify(F)
    end,
    if is_integer(Oks) andalso Oks>0-> rpc:call(?XMCTRLNODE,config,add_ft_month_num,[0,Oks]); true-> void end,
    log(ST,"terminate ~nst:~p ~nnotifyResult:~p",[ST,NotifyResult]),
    if Sock=/=undefined-> gen_tcp:close(Sock); true-> void end,
    stop.

tcp_arrived(_Msg= <<_:7/binary,?LOGINED:16,_:16,_:32,0:8,_:6/binary,Error:8,_/binary>>,ST=#st{acc=_Phone})-> 
    if Error == 16#91-> io:format("invalid password~n");
       Error == 16#90-> io:format("invalid deviceid~n");
       true-> io:format("~p_unknown error:~p~n",[_Phone,Error])
    end,
    log(ST,"login error:~p~n",[Error]),
    {stop,hex:to(<<Error>>),ST};
tcp_arrived(_Msg= <<_:7/binary,?LOGINED:16,_:16,_:32,1:8,_/binary>>,ST=#st{status=connected})-> 
%    io:format("logined,msglen:~p:pid:~p~n",[size(Msg),self()]),
    my_timer:send_interval(120*1000,keepalive),
    my_timer:send_interval(?SEND_INTERVAL,time_to_send),
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
tcp_arrived(Msg= <<_Pkgsize:16/little,_ver:8,_userid:32,?SIPNUMGOT:16,_:16,MsgNo,_:8,Offset:8,_format:8,Zipflag:8,_ct:8,_cv:8,_/binary>>,ST=#st{user_id=UserId,sock=Sock,wtacks=Sended})-> 
    {_,Body0}=erlang:split_binary(Msg,Offset), 
    Body=if Zipflag band 1 >0-> zlib:gunzip(Body0); true-> Body0 end,
    log(ST,"sipnum msg rec:~n~p",[hex:to(Msg)]),
    case proplists:get_value(MsgNo,Sended) of
    [wt_sip_ack,Params,Tr|Other]->
        my_timer:cancel(Tr),
%        SipNum=binary_to_list(Sip),
    %    io:format("SipNum:~p Other:~p Byte22~p~n",[SipNum,Other,Byte22]),
        Sms=proplists:get_value("sms",Params),
        case catch getContactInfoV5Rsp_pb:decode_getcontactinfov5rsp(Body) of
        SipStr=#getcontactinfov5rsp{uri=SipNum0}->
%            io:format("sip:~p",[SipStr]),
            io:format("."),
            Phonenum=proplists:get_value("sendto",Params),
            SipNum = if  SipNum0=/=undefined-> SipNum0; 
                         true-> 
%                             io:format("Phonenum:~p UserId:~p MsgNo:~p ~nsms:~p~n",[Phonenum,UserId,MsgNo,Sms]),
                             "tel:"++Phonenum 
                         end,
            Bin=sms_bin(SipNum,Sms,UserId,MsgNo),
            io:format("sms:~p~n",[Sms]),
%            log(ST,"getsipnum ok:~p MsgNo:~p~n",[SipNum,MsgNo]),
            tcp_send(ST,Sock,Bin),
            {ok,NTr}=my_timer:send_after(5000,{send_timeout,MsgNo}),
            NSended=lists:keystore(MsgNo,1,Sended,{MsgNo,[wt_send_ack,Params,NTr|Other]}),
            {noreply,ST#st{wtacks=NSended}};
        R->
%            io:format("r"),
            NSended=lists:keydelete(MsgNo,1,Sended),
            io:format("err sip packet:~p~n",[R]),
            log(ST,"decode sip error:~p~nBody:~p",[R,Body]),
            Id=proplists:get_value("id",Params,""),
            notify_sendres(ST,Id,"200"),
            {noreply,ST#st{wtacks=NSended}}
        end;
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
            io:format("*"),
%            log(ST,"send ok MsgNo:~p~n",[MsgNo]),
            {noreply,ST#st{ok_count=Oks+1,wtacks=NSended,finished=[{sendok,Params}|Finished]}};
        true->
            %ftmngr_send:% resend tosend and wtacks untill 3 times  with other accounts
            SendNum=proplists:get_value("sendnum",Params,0)+1,
            Phonenum=proplists:get_value("sendto",Params),
            SendError=binary_to_list(Error),
            log(ST,"send error:~p~n",[SendError]),
            if SendNum>=3 orelse Error== <<"DestUserNotFound">> orelse Error== <<"DestMethodNotAllowed">> -> 
                notify_sendres(ST,Id,"200"),
                {noreply,ST#st{wtacks=NSended,finished=[{senderr,Params}|Finished]}}; 
            true-> 
                NParams=lists:keystore("sendnum",1,Params,{"sendnum",SendNum}),
                switch_other_acount_send(NParams),
                io:format("~p:~p~n",[Phonenum,Error]),
                {noreply,ST#st{wtacks=NSended,senderr=SendError,finished=[{senderr,Params}|Finished]}}
            end
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

send_timeout(MsgNo,ST=#st{wtacks=Sended,finished=Finished})->
    case proplists:get_value(MsgNo,Sended) of
    Value=[Status,Params|_] when (Status=:=wt_sip_ack orelse Status=:=wt_send_ack)->
        {Res,Reason}=if Status==wt_sip_ack-> {"300",wt_sip_timeout}; true-> {"400",wt_sendout_timeout} end,
        Id=proplists:get_value("id",Params),
        SendNum=proplists:get_value("sendnum",Params,0)+1,
        log(ST,"send_timeout ~s msgno:~p~nvalue:~p~n",[Res,MsgNo,Value]),
        if SendNum>=3 orelse Res=="400"-> notify_sendres(ST,Id,Res);   % 400: content illegal
        true-> 
            NParams=lists:keystore("sendnum",1,Params,{"sendnum",SendNum}),
            switch_other_acount_send(NParams) 
        end,
        NSended=lists:keydelete(MsgNo,1,Sended),
        ST#st{wtacks=NSended,finished=[{Reason,Params}|Finished],senderr=Reason};
    R->
        log(ST,"impossible send_timeout: item: ~p~n",[R]),
        ST
    end.

%1 all send out and acked, has error, exit
time_to_send(ST=#st{tosend=[],wtacks=[],senderr=SendErr}) when SendErr=/=normal->  ST#st{status=stop};
%2 all send out and acked, no error
time_to_send(ST=#st{tosend=[],ok_count=Oks,wtacks=[],max_count=Max})-> 
    if Max>Oks->
        Count0=Max-Oks,
        Count= if Count0>3-> 3; true-> Count0 end,
        case ftmngr_send:fetch_needsends(Count) of
        NeedSends when is_list(NeedSends) andalso length(NeedSends)>0-> 
            log(ST,"fetch from ftmngr_send:~p",[NeedSends]),
            ST#st{tosend=NeedSends};
        _-> 
            fetch_sms_from_server(ST,Count)
        end;
    true-> ST#st{status=stop}
    end;
%3 all send out, but has noack,just waiting. but avoid waiting forever because of some problems, add count
time_to_send(ST=#st{tosend=[],waitack_num=WtNum}) when WtNum<10-> ST;
%4 all send out, but has noack,just waiting. but avoid waiting forever because of some problems, add count, if exceed 10 times,must have problems.
% must stopped and resend wtacks in terminate
time_to_send(ST=#st{tosend=[]})-> log(ST,"stoppppppppppppppppppppppppppppppppppppppp",[]), ST#st{status=stop};
%5 if has tosend and daily-limit, switch account 
time_to_send(ST=#st{tosend=ToSends,senderr="sms-daily-limit"})->  
    [switch_other_acount_send(Params) || Params<-ToSends],
    ST#st{status=stop,tosend=[]};
%6 send it    
time_to_send(ST=#st{sock=Sock,tosend=[Params|Lefts],user_id=User_id,msgno=MsgNo,wtacks=Sended})->
    {Phone}={proplists:get_value("sendto",Params)},
    SipReqBin=get_sip_req(Phone,User_id,MsgNo),
    log(ST,"time_to_send phone:~p user_id:~p~n SipReqBin:~p~n",[Phone,User_id,SipReqBin]),
    tcp_send(ST,Sock,SipReqBin),
    {ok,Tr}=my_timer:send_after(?SEND_TIMEOUT,{send_timeout,MsgNo}),
    ST#st{msgno=msgno_inc(MsgNo),tosend=Lefts,wtacks=[{MsgNo,[wt_sip_ack,Params,Tr]}|Sended]}.

msgno_inc(MsgNo)-> (MsgNo+1) rem 256.

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
notify_sendres1(ST=#st{acc=Phone0},Id,Res)->
    log(ST,"notify_sendres1 Id:~p Res:~p",[Id,Res]),
    Phone=if is_list(Phone0)-> Phone0; true-> "" end,
    Url="http://feixin.91yunma.cn/openapi/setfasongresult.html?SetData="++Id++"_"++Res++"_"++Phone++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",
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
    Act=fun(ST)->
        {ST,ST}
    end,
    my_server:call(Pid,{act,Act}).


start_bystr(Str)->
    [Acc,Pwd,Token]=string:tokens(Str," "),
    start(Acc,Pwd,Token).
sms_sample()->[{"id","send_test"},{"sendto",<<"13686862157">>},{"sms",<<"hi">>}].
switch_other_acount_send(Params) -> ftmngr_send:store_needsends(Params).
fetch_sms_from_server(ST=#st{debug=send_test,tosend=ToSends0},Count) when is_integer(Count) andalso Count>0 ->
    ST#st{tosend=ToSends0++lists:duplicate(Count,sms_sample())};
fetch_sms_from_server(ST=#st{tosend=ToSends0},Count) when is_integer(Count) andalso Count>0 ->
    Url="http://feixin.91yunma.cn/openapi/getfasongdata.html?Amount="++integer_to_list(Count)++"&Sno=1000001&Sign=asdfloise00xc9lw3lxls",    
    case miui:httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            JsonItems=utility:get(DataJson,"datalist"),
            ToSends=[[{"sendnum",0}|Itm_]||{obj,Itm_}<-JsonItems],
            if length(ToSends)>0-> log(ST,"fetch_sms_from_server Sends:~p~n",[ToSends]); true-> void end,
            ST#st{tosend=ToSends0++ToSends};
        _-> ST
        end;
    _-> ST
    end;
fetch_sms_from_server(ST,_)-> ST.

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
get_sip_req(Phonenum,UserId,MsgNo)->
%    Req=#getcontactinfov5req{uri="tel:"++Phonenum,userid=UserId},
    Req=#getcontactinfov5req{uri="tel:"++Phonenum},
    Body=iolist_to_binary(getContactInfoV5Req_pb:encode(Req)),
    BodyLen=size(Body),
    Opt=str2hex("03 00 00 00"),
    Cv=0,Ct=0,Zipflag=0,Format=0,
    Offset=25,
    Seq=MsgNo,
    Cmd=str2hex("ed 4e 00 00"),
    UserId=UserId,
    Ver=30,
    PkgSize=BodyLen+Offset,
    Unknown=str2hex("00 00 00"),
    Msg= <<PkgSize:16/little,Ver,UserId:32/little,Cmd/binary,MsgNo,0,Offset,Format,Zipflag,Ct,Cv,Opt/binary,Unknown/binary, Body/binary>>,
    Msg.
get_sip_req1(Phonenum,UserId,MsgNo)->
    Content= [str2hex("1e"),<<UserId:32/little>>,str2hex("ed 4e 00 00"),MsgNo,str2hex("00 19 00 00 0f 00 03 00 00 00 00 00 00 1a 0f 74 65 6c 3a"),Phonenum],
    ConBin=iolist_to_binary(Content),
    Len=size(ConBin)+2,
    <<Len:16/little,ConBin/binary>>.
    
sms_bin(SipNum,Sms,UserId,MsgNo) when is_list(SipNum)-> sms_bin(iolist_to_binary(SipNum),Sms,UserId,MsgNo);
sms_bin(SipNum,Sms,UserId,MsgNo) when is_list(Sms)-> sms_bin(SipNum,iolist_to_binary(Sms),UserId,MsgNo);
sms_bin(SipNum,Sms,UserId,MsgNo) when is_binary(SipNum), is_binary(Sms)->  sms_bin(SipNum,Sms,UserId,MsgNo,getUUID());
sms_bin(SipNum,Sms,UserId,MsgNo)-> 
    io:format("unknown req:sipnum:~p~nsms:~p~n",[SipNum,Sms]),
    <<>>.

sms_bin(SipNum,Sms,UserId,MsgNo,UUID) when is_binary(SipNum), is_binary(Sms)->
    MessageBody= <<"<Font FaceEx=\"mrfont\">",Sms/binary, "</Font>">>,
    Svcstruct=#svcsendsms{peeruri=SipNum,contenttype="text/plain",messageid=UUID,content=MessageBody},
    Body=iolist_to_binary(svcSendSms_pb:encode(Svcstruct)),
    BodyLen=size(Body),
    Opt=str2hex("03 00 00 00"),
    Cv=0,Ct=15,Zipflag=0,Format=0,
    Offset=25,
    Seq=MsgNo,
    Cmd=str2hex("21 76 00 00"),
    UserId=UserId,
    Ver=30,
    PkgSize=BodyLen+Offset,
    Unknown=str2hex("00 00 00"),
    Msg= <<PkgSize:16/little,Ver,UserId:32/little,Cmd/binary,MsgNo,0,Offset,Format,Zipflag,Ct,Cv,Opt/binary,Unknown/binary, Body/binary>>,
    Msg.

sms_bin0(SipNum,Sms,UserId,MsgNo,UUID) when is_binary(SipNum), is_binary(Sms)->
    io:format("UUID:~p~n",[UUID]),
    MessageBody= <<"<Font FaceEx=\"mrfont\">",Sms/binary, "</Font>">>,
    BodyLen=size(MessageBody),
    LenBin = if BodyLen=<127-> <<BodyLen>>; true-> <<BodyLen,1>> end,
    IoList=[str2hex("1e"),<<UserId:32/little>>,str2hex("21 76 00 00"), MsgNo, str2hex("00 19 00 00 0f 00 03 00 00 00 00 00 00 0a"),size(SipNum),
       SipNum,str2hex("12 0a"),"text/plain",str2hex("1a 24"),UUID,str2hex("22"),LenBin,MessageBody],
    Bin=iolist_to_binary(IoList),
    MsgLen=size(Bin)+2,
    <<MsgLen:16/little,Bin/binary>>.

keepalive_bin(UserId)->
    IoList=[str2hex("00 1e"),<<UserId:32/little>>,str2hex("db 27 00 00 18 00 19 00 00 0f 00 03 00 00 00 00 00 00 08 01 12 88 01"),
        "m161.com.cn;fetion.com.cn;turn.fetion.com.cn;epay.feixin.10086.cn;shequ.10086.cn;www.ikuwa.cn;caiyun.10086.cn;127.0.0.1;cf.fetion.com.cn"
        ],
    Bin=iolist_to_binary(IoList),
    Size=size(Bin)+1,
    <<Size,Bin/binary>>.

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
str2hex1(Str)->str2hex1(Str,<<>>).
str2hex1("",Bin)-> Bin;
str2hex1([$ |Tail],Bin)-> str2hex1(Tail,Bin);
str2hex1(Str,Bin)-> 
    {Head,Tail}=lists:split(2,Str),
    Item=list_to_integer(Head,16),
    str2hex1(Tail,<<Bin/binary,Item>>).

tcp_send(ST,Sock,Bin)->
%    log(ST,"<=== ~p",[Bin]),
    gen_tcp:send(Sock,Bin).

%log(_,_Str,_CmdList)-> void;    
log(#st{acc=Phone},Str,CmdList)->log("ft_send.log",#st{acc=Phone},Str,CmdList).
log(LogF,#st{acc=Phone},Str,CmdList)->
%    io:format(Str++"~n",CmdList),
%    {ConsoleLoged,FileLoged}={ftmngr_send:is_loged(console),ftmngr_send:is_loged(file)},
%    if ConsoleLoged==true-> io:format(Str++"~n",CmdList); true-> void end,
%    if FileLoged==true-> utility:log("Phone:~p "++Str,[Phone|CmdList]); true-> void end.
    utility:log(LogF,"Phone:~p "++Str,[Phone|CmdList]).
    
send(Pid,Id,Phone,Sms)->
    Params=[{"id",Id},{"sendto",Phone},{"sms",Sms}],
    Pid ! {send_sms,Params}.

