-module(miui).
-compile(export_all).
-define(JAVAPATH,"./miui_sb7.jar").
-define(HTTP_TIMEOUT,60000).
-define(MAX_COUNT,1).

-define(CHALLENGE,"challenge=").
-define(LOGINACK,"<bind").
-define(AVAILABLE,"type=\"available\"").
-define(COMING_MSG,"s=\"1\"><s>").
-define(PEER_RECEIVED,"<received").
-define(UNAVAILABLE,"type=\"unavailable\"").
-define(HEARTBEATACK,"<iq chid='0' id='0' type='result'/>").
-define(KICKED,"<kick").
-define(SENDACK_ACK,"chid=\"3\" type=\"ack\"").

-define(ALLMSGTYPE,(string:join([?CHALLENGE,?LOGINACK, ?AVAILABLE,?COMING_MSG,?PEER_RECEIVED,?UNAVAILABLE,
                                                ?HEARTBEATACK,?KICKED,?SENDACK_ACK],"|"))).

-define(DAY_INTERVAL,10000).
-define(NIGHT_INTERVAL,60*10*1000).
-define(WAIT_RECV_TIME,20*1000).
-define(WAIT_PRESENCE_TIME,1500).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-define(SEND_INTERVAL, 2000).
-record(st, {
      java_node_id,
      main_obj,
	imsi="",
	sim_user_id,
	user_id,
	phone,
	sec,
	token,
	challenge,
	sock,
	tosend=[],
	sended=[],
	wtacks=[],  %{msgid,Params} %[{MsgId,[wait_presence,Params,Tr]}|{MsgId,[wait_sendack,Params,Tr]}]
	send_count=0,
	ack_count=0,
	raw_count=0,
	max_send_count=10,
	recv_count=0,
      debug,
      times=300,
      timout_300_num=0,
      msgid={createID(),0},
      error,
	status=init
}).

start_receive_test(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->    start(receive_test,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0).
start_onlinecheck(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->    start(onlinecheck,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0).
start(Debug,Imsi,Sim_id,Phone,Sec0,Token0) ->    % java node created each miui client
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[?JAVAPATH]},{enable_gc,true}]),
    Main=java:new(NodeId,'com.miui.main.Main',[]),
    start(Debug,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0).
start(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) -> start(undefined,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0).
start(Debug,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->
    Paras=prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0),
    my_server:start(?MODULE,[{debug,Debug}|Paras],[]).
    
start_sayhi(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->    start(recsms_sayhi,NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0).

test_start(Phone)->  %13697414600
    case rpc:call(?XMCTRLNODE,config,get_xm_params_by_phone,[Phone]) of
    {ok,Params}->
        {ok,Pid}=apply(?MODULE,start,[test|Params]),
        Pid;
    _-> undefined
    end.
test_sayhi()->
    Sec=http_uri:decode("GKNvxsO%2BcdEhxrm4dUy1sw%3D%3D"),
    Token=http_uri:decode("2.0%26amp%3BV1_mixin%26amp%3B1%3A1Frq_qaXkRY2maai7xnFbQ%3ASWF5CFmpF618g%2BCWtlIs4r4tx7gfP%2FFp68HvRLRvnzq6X7LN63yiZhUqrEGmsyaF%2B2xPjy5bNV45jFQ3LWT%2FAfrHqwXT2p07xnITk5PTFKGQwC8bbTCQo8fgv4XF1cui5ja0thejYBlQtN%2BEHdesAHKKptJLqgMPabpkKaf7f%2B8Wm2mLHmuWdx4QRNaMUa9HYw0CW076bUoa9WD6wN5%2BbA%3D%3D%26amp%3B1vEnLqHjrA%2FgKvzsWb77Ag%3D%3D"),
    test_sayhi(["884995420","13697414600",Token,Sec]).
test_sayhi([UserId,Phone,Token,Sec])->  {ok,P}=start(recsms_sayhi,"imsi_test_sayhi",UserId,Phone,Sec,Token), P;
test_sayhi(Phone)->
    case rpc:call(?XMCTRLNODE,config,get_xm_params_by_phone,[Phone]) of
    {ok,Params}->
        {ok,Pid}=apply(?MODULE,start,[recsms_sayhi|Params]),
        Pid;
    _-> undefined
    end.

test_send(Pid)->test_send(Pid,<<"884995420">>).
test_send(Pid,To) when is_list(To)-> test_send(Pid,list_to_binary(To));
test_send(Pid,ToUserIdBin)->test_send(Pid,ToUserIdBin,list_to_binary(show(Pid,phone)++"_"++pid_to_list(Pid))).
test_send(Pid,To,Content) when is_list(Content)->test_send(Pid,To,list_to_binary(Content));
test_send(Pid,DestUserId,Content)->
    Params=[{"id",<<DestUserId/binary,"_",Content/binary>>},{"xmid",DestUserId},{"sms",Content}],
    Pid ! {send_sms,Params},
    Pid ! time_to_send.
    

stop(Pid)->    my_server:call(Pid,stop).    

show(Pid)->
    Act=fun(St)->
        {St,St}
    end,
    my_server:call(Pid,{act,Act}).

show(Pid,Mem)->
    Keys=record_info(fields,st),
    ST=show(Pid),
    [_|Vals]=tuple_to_list(ST),
    Pls=lists:zip(Keys,Vals),
    proplists:get_value(Mem,Pls).

%*********************************************************************** myservercallback    
init([{debug,Debug},NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]) ->
    {_,St}=init([NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]),
    {ok,St#st{java_node_id=NodeId,main_obj=Main,debug=Debug}};
init([NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]) ->
%    io:format("miui:init:~p~n",[{Imsi,Sim_id,Phone,Sec,Token}]),
    random:seed(os:timestamp()),
    {ok,Sock} =gen_tcp:connect(getServerIp(),getServerPort(),[{active,true},{send_timeout, 5000},{packet,0},binary]),
    URL="111.13.142.2",
   Msg="<stream:stream xmlns=\"xm\" xmlns:stream=\"xm\" to=\"xiaomi.com\" version=\"105\" model=\"T275s\" os=\"180667.1\" connpt=\"wifi\" host=\""++URL++"\">",
   gen_tcp:send(Sock,Msg),
    my_timer:send_interval(5000*60,heartbeat),
%    io:format("miui:init ok~n"),
    {ok,#st{java_node_id=NodeId,main_obj=Main,imsi=Imsi,sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,sock=Sock}}.

handle_info({send_sms,Params},State=#st{tosend=ToSend}) ->
    {noreply,State#st{tosend=[Params|ToSend]}};
handle_info(heartbeat,State=#st{}) ->
    NSt=send_heartbeat(State),
    {noreply,NSt};
handle_info({send_timeout,MsgId},State) ->
    NSt=send_timeout(MsgId,State), % Not implemented in this example
    {noreply,NSt};
handle_info(time_to_send,State=#st{status=stop}) ->
    {stop,time_to_send_stop,State};
handle_info(time_to_send,State) ->
%    io:format("time_to_send:~p~n",[self()]),
    NSt=time_to_send(State), % Not implemented in this example
    {noreply,NSt};
handle_info(fetch_sms_timer,State) ->
    NSt=fetch_sms(State), % Not implemented in this example
    {noreply,NSt};
handle_info({tcp,_Sock,Data},State) ->
    NSt=tcp_arrived(Data,State), 
    {noreply,NSt};
handle_info(stop,State) ->
    io:format("recv stop~n"),
    {stop,info_stop,State};
handle_info({stop,Reason},State) ->
    {stop,Reason,State};
handle_info(send_over,State) ->
    {stop,send_over,State};
handle_info({tcp_closed,S},State=#st{phone=Phone}) ->
    io:format("Socket ~w closed [~p]~n",[S,Phone]),
    {stop,tcp_closed,State};
handle_info(Msg,State)-> 
    log(State,"unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};
handle_call(stop,_Frome, ST) ->
    {stop,call_stop,ok,ST}.
    
terminate(Reason,St=#st{imsi=Imsi,main_obj=MainObj,java_node_id=NodeId,debug=Debug,tosend=ToSend,sended=Sended,wtacks=ToAcks,
             ack_count=AckNums,send_count=SendNums,sim_user_id=UserId,status=Status,recv_count=RecCount,
             phone=Phone,sec=Sec,token=Token})->  
%    if MainObj=/=undefined-> java:free(MainObj); true-> void end,
    NotSend=[binary_to_list(proplists:get_value("id",Params))++"_400"||Params<-ToSend],
    NotAck=[binary_to_list(proplists:get_value("id",Params))++"_200"||{_MsgId,[_,Params,undefined]}<-ToAcks],
    All=NotSend++Sended++NotAck,
    Other=    if length(All)>0->        "&SetData="++string:join(All,",");    true->  ""        end,
    ParamStr= "Type=fasong&Imsi="++Imsi++Other,
    Url=seturl_by_type(Debug),

    send_result(Url,ParamStr,St),
    if Debug=/=precheck andalso Debug=/=onlinecheck andalso (SendNums>0 orelse Status==logined)->  rpc:call(?XMCTRLNODE,config,xm_month_num,[SendNums,AckNums]);
    true-> void 
    end,
    %miui_manager:announce_sendnum(AckNums),
    if Debug==test andalso is_integer(NodeId)-> java:terminate(NodeId); true-> void end,
    log(St,"exit! userid:~p sends:~p acks:~p recvs:~p~n reason:~p sendedres:~n~p", [UserId,SendNums,AckNums,RecCount,Reason,Sended]),
    if (Debug==receive_test orelse Debug==onlinecheck) andalso Reason==tcp_closed-> miui_manager:add_onlinetask([UserId,Phone,Sec,Token]); true-> void end,
    stop.
%  ********************************************************** internal
tcp_arrived(Msg, St)-> 
%    io:format("==>~p~n",[Msg]),
%  case re:run(Msg,"(challenge=|type=\"result\"|type=\"available\"|type=\"unavailable\"|s=\"1\"><s>|<received)",[{capture,all_but_first,binary},ungreedy]) of
    case re:run(Msg,"("++all_msg_type()++")",[{capture,all_but_first,list},ungreedy]) of
    {match, [Event]}->    
%        io:format("receive event:~p~n",[Event]),
        handle_match_msg(Event,Msg,St);
    _-> 
        log(St,"tcp_arrived unhandled:~p~n",[Msg]),
        St
    end.

handle_match_msg(?CHALLENGE,Msg,St)-> tologin(Msg,St);
handle_match_msg(?LOGINACK,Msg,St)-> loginack(Msg,St);
handle_match_msg(?AVAILABLE,Msg,St)-> peer_available(Msg,St);
handle_match_msg(?COMING_MSG,Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sec=Sec,sock=Sock,send_count=Oks,
                         wtacks=Msgs,phone=Phone,debug=Debug,recv_count=RecCount})-> 
    NSt0=send_ack(Msg,St),
    NSt=NSt0#st{recv_count=RecCount+1},
    if Debug==recsms_sayhi->
        {match, [Server_To]}=re:run(Msg,"to=\"(.*)\"",[{capture,all_but_first,list},ungreedy]),
        {match, [To]}=re:run(Msg,"from=\"(.*)\"",[{capture,all_but_first,list},ungreedy]),
        Sms1="hi",
        Fun=fun(I) when I>127-> I-256;    (I)-> I end,
        Sms=[Fun(I)||I<-Sms1],

        Me_=java:new(NodeId,'java.lang.String',[Server_To]),
        To_=java:new(NodeId,'java.lang.String',[To]),
        Sms_=java:new(NodeId,'java.lang.String',[Sms]),
    %    Me_=Server_To, To_=To, Sms_=Sms,
        ToSend_=java:call(MainObj,set_sms_package,[Me_,To_,Sms_,Sec]),
        ToSend=java:string_to_list(ToSend_),
        MsgId=msgid(ToSend),   %binary
        gen_tcp:send(Sock,list_to_binary(ToSend)),
        log(NSt,"sayhi to:~p msgid:~p",[To,MsgId]),
        io:format("*"),
        Params=[{"id",list_to_binary(Phone++"_"++To++"_sayhi")},{"xmid",list_to_binary(To)},{"sms",<<"hi">>}],
        NSt#st{status=logined,send_count=Oks+1,wtacks=[{MsgId,[wait_sendack,Params,undefined]}|Msgs]};
    true->   NSt
    end;
handle_match_msg(?PEER_RECEIVED,Msg,St=#st{sended=Sended,wtacks=ToAcks,ack_count=AckNums,phone=Phone})-> 
%    my_timer:cancel(Tr),
    MsgId=recv_id(Msg),
    log(St,"==>peer_received:recv_id:~p ~p",[MsgId,Msg]),
    NSt=sendack_ack(Msg,St),
    case proplists:get_value(MsgId,ToAcks) of
    undefined->  
        log(St,"peer_recved impossible:~p~n",[MsgId]),
        NSt;
    [wait_sendack,Params,Tr|_] when is_list(Params)->
        my_timer:cancel(Tr),
        Id=binary_to_list(proplists:get_value("id",Params)),
        ToAcks1=proplists:delete(MsgId,ToAcks),
        NSt#st{sended=[Id++"_100"|Sended],wtacks=ToAcks1,ack_count=AckNums+1}
    end;
handle_match_msg(?UNAVAILABLE,Msg,St=#st{sock=Sock,sended=Sended,wtacks=WtAcks})-> 
    MsgNo=presence_id(Msg),
%    io:format("unavailable:~p~n",[MsgNo]),
    case proplists:get_value(MsgNo,WtAcks) of
    [wait_presence,Params,Tr|Other]->
%        io:format("wait_presence unavailable:~p~n",[MsgNo]),
        my_timer:cancel(Tr),
        Id=binary_to_list(proplists:get_value("id",Params)),
        ResId=Id++"_300",
        NWtacks=lists:keydelete(MsgNo,1,WtAcks),
        St#st{sended=[ResId|Sended],wtacks=NWtacks,timout_300_num=0};
    _->
        St#st{timout_300_num=0}
    end;
handle_match_msg(?HEARTBEATACK,_,St)->     St;
handle_match_msg(?KICKED,Msg,St)->     
    case re:run(Msg,"type=\"(.*)\" reason=\"(.*)\" detail=\"(.*)\"/>",[{capture,all_but_first,list},ungreedy]) of
    {match, [Type,Reason,Detail]}->    
        log(St,"kicked,type:~p reason:~p detail:~p",[Type,Reason,Detail]);    
    _-> 
        log(St,"unknown kicked",[])
    end,
    St;
handle_match_msg(Event,Msg,St)-> 
    log(St,"unhandled event:~p~n msg:~p~n",[Event,Msg]),
    St.
    
send_httpc(get,{URL},HttpOptions) ->
    httpc:request(get,{URL,[]},[{timeout,?HTTP_TIMEOUT}|HttpOptions],[]).
send_httpc(get,{URL}) ->
    httpc:request(get,{URL,[]},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(post,{URL,Body}) ->
    httpc:request(post, {URL,[],"application/json",Body},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(put,{URL,Body}) ->
    httpc:request(put, {URL,[],"application/json",Body},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(delete,{URL}) ->
    httpc:request(delete,{URL,[]},[{timeout,?HTTP_TIMEOUT}],[]).

httpc_call(Type,Arg) ->
    inets:start(),
    ssl:start(),
    case send_httpc(Type,Arg) of
        {ok,{_,_,Ack}} ->
            case rfc4627:decode(Ack) of
            {ok,Json,_}->            
%                io:format("httpc_call(~p,~p)~n Res:~p~n", [Type,Arg,Json]),
                {ok,Json};
            R-> 
                io:format("lw_lib httpc_call(~p,~p) Res:~p~n", [Type,Arg,R]),
                no_json
            end;
        Other ->
            io:format("httpc_call_failed Reason:~p,Arg:~p~n",[Other,Arg]),
            httpc_failed
    end.

test()-> "你好测试".
test1()->list_to_binary(test()).

msgid(Msg)->
    case re:run(Msg,"<message id=\"(.*)\" to=\"",[{capture,all_but_first,binary},ungreedy]) of
    {match, [MsgId]}->    MsgId;
    _-> impossible
    end.
recv_id(Msg)->
    case re:run(Msg,"<received id=\"(.*)\"/>",[{capture,all_but_first,binary},ungreedy]) of
    {match, [MsgId]}->    MsgId;
    _-> impossible
    end.

send_result(Url,ParamStr,St=#st{imsi=Imsi,max_send_count=MaxCount,raw_count=RawCount,send_count=Oks,tosend=ToSends}) ->    
    NotifyRes=
    case httpc_call(post,{Url,ParamStr}) of
    httpc_failed-> 
        httpc_call(post,{Url,ParamStr});
    _-> ok
    end,
    log(St,"send_result:max_count:~p,Oks:~p,tosends:~p,Imsi:~p,notifyres:~p~n",[MaxCount,Oks,length(ToSends),Imsi,NotifyRes]),
    St#st{sended=[]}.
    
notify_timeout10(Imsi)->
    Url="http://sms.91yunma.cn/openapi/getxmaccount2.html?Type=fasong&Imsi="++Imsi++"&Error=T0001&Reason=timeout10",
    httpc_call(get,{Url}).
    
time_to_send(St=#st{imsi=Imsi,debug=onlinecheck,tosend=[],wtacks=[],sended=Results}) when length(Results)>0 ->  
    PrmStr= "Imsi="++Imsi++"&SetData="++string:join(Results,","),
    Url=seturl_by_type(onlinecheck),
    send_result(Url,PrmStr,St),
    io:format(" sendonlinecheck~p ",[length(Results)]),
    my_timer:send_after(10000,fetch_sms_timer),
    St#st{sended=[]};
time_to_send(St=#st{debug=precheck,send_count=Oks,max_send_count=MaxCount}) when Oks>=MaxCount,Oks>0 ->  
    my_timer:send_after(60*1000,send_over),
    St;
time_to_send(St=#st{debug=undefined,send_count=Oks,max_send_count=MaxCount}) when Oks>=MaxCount,Oks>0 ->  
    my_timer:send_after(60*1000,send_over),
    St;
time_to_send(St=#st{tosend=[],sended=_Sended,debug=Debug}) when Debug==precheck orelse Debug==undefined->    
%    my_timer:send_after(60*1000,send_over),
    St;
time_to_send(St=#st{status=logined,java_node_id=NodeId,main_obj=Main,sock=Sock,tosend=[Params|Lefts],user_id=User_id,msgid={Head,Id},wtacks=Sended})->
    {UserId}={binary_to_list(proplists:get_value("xmid",Params))},
%    UserId="300285391",
    To=UserId++"@xiaomi.com",
%    Query_=java:call(Main,set_query_peer_package,[To,User_id]),
    MsgId=Head++integer_to_list(Id),
    Query=query_peer_package1(MsgId,To,User_id),
%    log(St,"<==~p~n",[Query]),
    gen_tcp:send(Sock,list_to_binary(Query)),
    {ok,Tr}=my_timer:send_after(?WAIT_PRESENCE_TIME,{send_timeout,MsgId}),
    St#st{msgid={Head,Id+2},tosend=Lefts,wtacks=[{MsgId,[wait_presence,Params,Tr]}|Sended]};
time_to_send(St)-> 
    St.
query_peer_package1(MsgId,To,User_id)->
	"<presence id=\""++MsgId++"\" to=\""++To++"\" from=\""++User_id++"\" chid=\"3\" type=\"probe\"></presence>".
createID()-> 
    Str="0123456789abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    Is=[random:uniform(72),random:uniform(72),random:uniform(72),random:uniform(72),random:uniform(72)],
    L1=[lists:nth(I,Str)||I<-Is],
    L1++"-".
presence_id(Msg)->
%<presence chid="3" id="2K722-2" from="825739025@xiaomi.com/OsSTC9us" to="880166043@xiaomi.com/LcJ2F3sD" type="available"><client_attrs>cap:sms#mms#mx2image#mx2audio</client_attrs></presence>
    case re:run(Msg,"<presence .* id=\"(.*)\"",[{capture,all_but_first,list},ungreedy]) of
    {match, [PresId]}->    PresId;
    _-> undefined
    end.
peer_available(Msg,St=#st{debug=onlinecheck,sock=Sock,sended=Sended,wtacks=Wtacks,ack_count=AckNums})->
    PresenceNo=presence_id(Msg),
    case proplists:get_value(PresenceNo,Wtacks) of
    [wait_presence,Params,Tr|Other]->
        my_timer:cancel(Tr),
        Id=binary_to_list(proplists:get_value("id",Params)),
        ResId=Id++"_100",
        io:format("1"),
        NWtacks=lists:keydelete(PresenceNo,1,Wtacks),
        St#st{status=logined,wtacks=NWtacks,sended=[ResId|Sended],ack_count=AckNums+1};
    R->
        log(St,"peer_available invalid status:~p~n",[R]),
        St
    end;
peer_available(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sec=Sec,sock=Sock,send_count=Oks,wtacks=Wtacks})->
    PresenceNo=presence_id(Msg),
    case proplists:get_value(PresenceNo,Wtacks) of
    [wait_presence,Params,Tr|Other]->
        my_timer:cancel(Tr),
        {match, [Server_To]}=re:run(Msg,"to=\"(.*)\"",[{capture,all_but_first,list},ungreedy]),
        UserId=binary_to_list(proplists:get_value("xmid",Params)),  %    UserId="300285391", yxw
        To=UserId++"@xiaomi.com",
        Sms1=binary_to_list(proplists:get_value("sms",Params)),
        Fun=fun(I) when I>127-> I-256;    (I)-> I end,
        Sms=[Fun(I)||I<-Sms1],
        Me_=java:new(NodeId,'java.lang.String',[Server_To]),
        To_=java:new(NodeId,'java.lang.String',[To]),
        Sms_=java:new(NodeId,'java.lang.String',[Sms]),
    %    Me_=Server_To, To_=To, Sms_=Sms,
        ToSend_=java:call(MainObj,set_sms_package,[Me_,To_,Sms_,Sec]),
        ToSend=java:string_to_list(ToSend_),
        MsgId=msgid(ToSend),   %binary
        gen_tcp:send(Sock,list_to_binary(ToSend)),
    %    log(St,"sendsms:msgid:~p to:~p",[MsgId,UserId]),
        NWtacks=lists:keydelete(PresenceNo,1,Wtacks),
        {ok,NTr}=my_timer:send_after(?WAIT_RECV_TIME,{send_timeout,MsgId}),
        St#st{status=logined,send_count=Oks+1,wtacks=[{MsgId,[wait_sendack,Params,NTr]}|NWtacks]};
    R->
        log(St,"peer_available invalid status:~p~n",[R]),
        St
    end.
send_timeout(MsgNo,St=#st{imsi=Imsi,sended=Results,wtacks=Sended,timout_300_num=T300Nums,ack_count=Acks})->
    case proplists:get_value(MsgNo,Sended) of
    [Status,Params|_] ->
        Id=binary_to_list(proplists:get_value("id",Params)),
%        io:format("wait_presence send_timeout:~p~n",[MsgNo]),
        NSended=lists:keydelete(MsgNo,1,Sended),
        ResId=if Status==wait_presence-> Id++"_300"; true-> Id++"_200" end,
        if T300Nums>=15 andalso Status==wait_presence andalso length(Acks)==0-> 
            io:format("phone:~p sipnum timeout 15 times,exceed and exit~n",[St#st.phone]),
            notify_timeout10(Imsi),
%            my_timer:send_after(60*1000,send_over),
            self() ! {stop,timeout300},
            St#st{sended=[ResId|Results],timout_300_num=0,wtacks=NSended};
        true-> 
            St#st{wtacks=NSended,timout_300_num=T300Nums+1} 
        end;
    _->
        St
    end.

    
str2hex(Str)-> list_to_binary([list_to_integer(I,16)||I<-string:tokens(Str," ")]).    

token_trim(Token0)->[I||I<-Token0, I=/=$\\].
sec_trim(Sec0)->[I||I<-Sec0, I=/=$\\].
prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0)->
    Sec= sec_trim(http_uri:decode(Sec0)),
    Token= token_trim(http_uri:decode(Token0)),
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    [NodeId,Main,Imsi,Sim_id,Phone,Sec,Token].

get_login_string(Sim_user_id,Phone,Sec,Token,Challenge,NodeId,MainObj)->
%        Sim_=java:new(NodeId,'java.lang.String',[Sim_user_id]),
%        Phn_=java:new(NodeId,'java.lang.String',[Phone]),
%        S_=java:new(NodeId,'java.lang.String',[Sec]),
%        Token_=java:new(NodeId,'java.lang.String',[Token]),
%        Challenge_=java:new(NodeId,'java.lang.String',[Challenge]),
        [Sim_,Phn_,S_,Token_,Challenge_]=[Sim_user_id,Phone,Sec,Token,Challenge],
        Login_=java:call(MainObj,login_package,[Sim_,Phn_,S_,Token_,Challenge_]),
        {ok,java:string_to_list(Login_)}.

send_heartbeat(St=#st{java_node_id=NodeId,main_obj=MainObj,times=Times,sock=Sock})-> 
    JTimes=java:new(NodeId,'java.lang.Integer',[Times]),
%    Msg_=binary_to_list(Msg),
    MsgAck_=java:call(MainObj,heartbeat,[JTimes]),
    MsgAck=java:string_to_list(MsgAck_),
%    io:format("<==send_heartbeat: ~p~n",[MsgAck]),
    gen_tcp:send(Sock,list_to_binary(MsgAck)),
%    St#st{times=Times+1};
    St;
send_heartbeat(Sock)->
    gen_tcp:send(Sock,<<"<iq to='xiaomi.com' id='0' chid='0' type='get'><ping xmlns='urn:xmpp:ping'></ping></iq>">>).
tologin(Msg,St=#st{sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,sock=Sock,status=init,java_node_id=NodeId,main_obj=MainObj})->
%    User_id=java:call(MainObj,getUser_ID,[Sim_id]),
    User_id=get_full_user_id(St),
    {ok,LoginStr}=get_login_string(User_id,Phone,Sec,Token,binary_to_list(Msg),NodeId,MainObj),
    gen_tcp:send(Sock,list_to_binary(LoginStr)),
    send_heartbeat(Sock),
    St#st{status=tologin,java_node_id=NodeId,main_obj=MainObj,user_id=(User_id)};
tologin(_Msg,St)-> 
    io:format("error status rec tologin~n"),
    St.
    
loginack(Msg,St)->
    case re:run(Msg,"(type=\"result\"|type='result')",[{capture,all_but_first,binary},ungreedy]) of
    {match, [_]}->    logined(Msg,St);
    _-> 
        log(St,"login error:~p~n",[Msg]),
        self() ! {stop,login_error},
        St
    end.

logined(_Msg,St=#st{debug=test})-> St#st{status=logined};
logined(_Msg,St=#st{debug=receive_test})-> St#st{status=logined};
logined(_Msg,St=#st{debug=recsms_sayhi})-> St#st{status=logined};
logined(_Msg,St=#st{status=tologin,imsi=Imsi})-> 
    fetch_sms(St#st{status=logined});
logined(_Msg,St)-> 
    io:format("error status rec logined~n"),
    St.

fetch_sms(St=#st{debug=Debug,status=logined,imsi=Imsi})-> 
    case fetch_sms_(Imsi,Debug) of
    {ok,Smss,MaxSend}->    
%        io:format("~p fetch_sms:~p~n",[self(),Smss]),
        my_timer:send_interval(?SEND_INTERVAL,time_to_send),
%        rpc:call(?XMCTRLNODE,config,xmphones,[Smss]),
        io:format(".~p.",[length(Smss)]),
        St#st{tosend=Smss,max_send_count=MaxSend,send_count=0,raw_count=length(Smss)};
    R-> 
        io:format("fetch_sms:~p~n",[R]),
        my_timer:send_after(10000,fetch_sms_timer),
        St
    end.

get_full_user_id(St=#st{imsi=Imsi,sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,main_obj=MainObj})->
    F=fun()->
        FullUserId0=java:call(MainObj,getUser_ID,[Sim_id]),
        FullUserId=java:string_to_list(FullUserId0),
        rpc:call(?XMCTRLNODE,config,xm_accs,[[[Imsi,FullUserId,Phone,Sec,Token]]]),
        FullUserId
        end,
    case rpc:call(?XMCTRLNODE,config,get_xm_userid_by_phone,[Phone]) of
    {ok,UserId} when is_list(UserId)->
        case [re:run(UserId,"@xiaomi.com/"),re:run(UserId,Sim_id)] of
        [{match,_},{match,_}] -> UserId;
        _->F()
        end;
    _->F()
    end.  

get_userid_by_phone(Phone)->    %also is xmid
    Url="https://api.account.xiaomi.com/pass/v3/user@id?type=MXPH&externalId="++Phone,
    case httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{result, s},{data, r}]) of
        {"ok", {obj, Params}}-> proplists:get_value("userId",Params);
        _-> error
        end;
    _->
        http_error
    end.
sendack_ack(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sock=Sock,user_id=User_id,sec=Sec})-> 
    Msg_=java:new(NodeId,'java.lang.String',[binary_to_list(Msg)]),
%    Msg_=binary_to_list(Msg),
    MsgAck_=java:call(MainObj,sendack_ack,[Msg_,User_id,Sec]),
    MsgAck=java:string_to_list(MsgAck_),
    log(St,"<==sendack_ack: ~p~n",[MsgAck]),
    gen_tcp:send(Sock,list_to_binary(MsgAck)),
    St.        
send_ack(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sock=Sock,user_id=User_id,sec=Sec})-> 
    Msg_=java:new(NodeId,'java.lang.String',[binary_to_list(Msg)]),
%    Msg_=binary_to_list(Msg),
    MsgAck_=java:call(MainObj,message_ack,[Msg_,User_id,Sec]),
    MsgAck=java:string_to_list(MsgAck_),
    log(St,"<==send_ack: ~p~n",[MsgAck]),
    gen_tcp:send(Sock,list_to_binary(MsgAck)),
    St.        
fetch_sms_(Imsi)->    fetch_sms_(Imsi,undefined).
fetch_sms_(Imsi,Debug)->    
    Url = geturl_by_type(Debug),
    fetch_sms_byurl(Url++"&Amount="++integer_to_list(?MAX_COUNT)++"&Imsi="++Imsi).
fetch_sms_byurl(Url)->    
    case httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            {Dests,MaxSend}=utility:decode_json(DataJson,[{phones,r},{maxsend,i}]),
            {ok,[Params||{obj,Params}<-Dests],MaxSend};
        _-> error
        end;
    _->
        http_error
    end.
geturl_by_type(precheck)-> "http://sms.91yunma.cn/openapi/getxmprecheckphones.html?Type=precheck";
geturl_by_type(onlinecheck)-> "http://sms.91yunma.cn/openapi/getxmphonestocheckonline.html?Type=onlinecheck";
geturl_by_type(_)-> "http://sms.91yunma.cn/openapi/getxmphones2.html?Type=fasong".

seturl_by_type(precheck)-> "http://sms.91yunma.cn/openapi/setxmprecheckstate.html?Type=fasong";
seturl_by_type(onlinecheck)-> "http://sms.91yunma.cn/openapi/setphonescheckonlineresult.html?Type=onlinecheck";
seturl_by_type(_)->   "http://sms.91yunma.cn/openapi/setxmsmsstate.html?Type=fasong".  
    
%log(_,_,_)->  void;
log(#st{phone=Phone,debug=Debug},Str,CmdList)->
%    io:format(Str++"~n",CmdList),
    Fn=if Debug==undefined-> "xm.log"; is_atom(Debug)-> atom_to_list(Debug); is_list(Debug)-> Debug; true-> "debug.log" end,
    utility:log(Fn,"Phone:~p "++Str,[Phone|CmdList]).

java_path()->?JAVAPATH.
getServerIp()->  "111.13.142.2".    
getServerPort()->5222.

test_raw1()->
    ["884995420","13697414600","GKNvxsO%2BcdEhxrm4dUy1sw%3D%3D","2.0%26amp%3BV1_mixin%26amp%3B1%3A1Frq_qaXkRY2maai7xnFbQ%3ASWF5CFmpF618g%2BCWtlIs4r4tx7gfP%2FFp68HvRLRvnzq6X7LN63yiZhUqrEGmsyaF%2B2xPjy5bNV45jFQ3LWT%2FAfrHqwXT2p07xnITk5PTFKGQwC8bbTCQo8fgv4XF1cui5ja0thejYBlQtN%2BEHdesAHKKptJLqgMPabpkKaf7f%2B8Wm2mLHmuWdx4QRNaMUa9HYw0CW076bUoa9WD6wN5%2BbA%3D%3D%26amp%3B1vEnLqHjrA%2FgKvzsWb77Ag%3D%3D"].
    
test_raw2()->
"userID=885025928&phone=13527636424&token=2.0%26amp%3BV1_mixin%26amp%3B1%3Ad-w318Whu_R0imPJGyynWA%3A0s8yuqUITJ%2F0vNG4z5UxJQB06%2F9Rm5wtmO%2FwjHApgnekVJXCj68qIv8gan8w57Ezm%2FLMk7aNrX6%2BNTrN5wJWco%2B3YR29xUXRYly%2F4oLGCmUU5w1lY7LPIlYWUt8i8BH6HyPdecWk%2FjbDjY4aiMT2zfY1YWkZ%2FNnqNtmALFkOWwxhMx4%2Fnab%2FU0wSLWjvYNHNsG49BmqfrTPWHs3hWAzvCw%3D%3D%26amp%3BHtSmbaRVvrpYkkYAAFwFJg%3D%3D&sec=WFEqZFUoiE6ug6bRMcqrVw%3D%3D".
test_raw3()->
"userID=885023515&phone=15800200347&token=2.0%26amp%3BV1_mixin%26amp%3B1%3A61D0U0tN06gQBet31Twgow%3Aw6OJg7tj%2Fa6SdU3GBcy4pwCrwZTX6dwNwQoztqueHKqXlQIIZdPV24dHf%2BfXs%2FINbkSjuTYNRpsOYyngZ4Nc%2BmXefd3QaAfPFfV1rr174WgOhSUfnqafW%2FXiJArfcyamkuW5GbI0WeGReUGhh9yksRfSWoOvaX3oTqbDrF9KMbs5D8Jv0bb4N5O53yB%2BV1Vlqs9A9VWDBREsGr0qNqKo6w%3D%3D%26amp%3BLhVg4FNdg9131UsIFFZdbA%3D%3D&sec=P7XdHWLnrpy85GWqTEId8Q%3D%3D".

set_debug(Pid,Debug)->
    Act=fun(St=#st{debug=Debug0})->
        {Debug0,St#st{debug=Debug}}
    end,
    my_server:call(Pid,{act,Act}).

all_msg_type()-> ?ALLMSGTYPE.
