-module(miui).
-compile(export_all).
-define(JAVAPATH,"./miui_sb5.jar").
-define(HTTP_TIMEOUT,60000).
-define(MAX_COUNT,1).

-define(CHALLENGE,<<"challenge=">>).
-define(LOGINED,<<"type=\"result\"">>).
-define(AVAILABLE,<<"type=\"available\"">>).
-define(COMING_MSG,<<"s=\"1\"><s>">>).
-define(PEER_RECEIVED,<<"<received">>).
-define(UNAVAILABLE,<<"type=\"unavailable\"">>).
-define(DAY_INTERVAL,10000).
-define(NIGHT_INTERVAL,60*10*1000).
-define(WAIT_RECV_TIME,20*1000).
-define(WAIT_PRESENCE_TIME,1500).
-define(XMCTRLNODE,'xm_ctrl@119.29.62.190').

-record(st, {
      java_node_id,
      main_obj,
	imsi,
	sim_user_id,
	user_id,
	phone,
	sec,
	token,
	challenge,
	sock,
	tosend=[],
	sended=[],
	wait_sendack_tr,
	toack_msgs=[],  %{msgid,Params}
	send_count=0,
	ack_count=0,
	raw_count=0,
	max_send_count=0,
      debug,
	status=init
}).

java_path()->?JAVAPATH.
getServerIp()->  "111.13.142.2".    
getServerPort()->5222.

get_login_string(Sim_user_id,Phone,Sec,Token,Challenge,NodeId,MainObj)->
%        Sim_=java:new(NodeId,'java.lang.String',[Sim_user_id]),
%        Phn_=java:new(NodeId,'java.lang.String',[Phone]),
%        S_=java:new(NodeId,'java.lang.String',[Sec]),
%        Token_=java:new(NodeId,'java.lang.String',[Token]),
%        Challenge_=java:new(NodeId,'java.lang.String',[Challenge]),
        [Sim_,Phn_,S_,Token_,Challenge_]=[Sim_user_id,Phone,Sec,Token,Challenge],
        Login_=java:call(MainObj,login_package,[Sim_,Phn_,S_,Token_,Challenge_]),
        {ok,java:string_to_list(Login_)}.

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
logined(_Msg,St=#st{debug=test})-> St#st{status=logined};
logined(_Msg,St=#st{debug=recsms_sayhi})-> St#st{status=logined};
logined(_Msg,St=#st{status=tologin,imsi=Imsi})-> 
    fetch_sms(St#st{status=logined});
logined(_Msg,St)-> 
    io:format("error status rec logined~n"),
    St.

fetch_sms(St=#st{status=logined,imsi=Imsi})-> 
    case fetch_sms_(Imsi) of
    {ok,Smss,MaxSend}->    
%        io:format("~p fetch_sms:~p~n",[self(),Smss]),
        my_timer:send_interval(1000,time_to_send),
%        rpc:call(?XMCTRLNODE,config,xmphones,[Smss]),
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
send_ack(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sock=Sock,user_id=User_id,sec=Sec})-> 
    Msg_=java:new(NodeId,'java.lang.String',[binary_to_list(Msg)]),
%    Msg_=binary_to_list(Msg),
    MsgAck_=java:call(MainObj,message_ack,[Msg_,User_id,Sec]),
    MsgAck=java:string_to_list(MsgAck_),
    io:format("<==send_ack: ~p~n",[MsgAck]),
    gen_tcp:send(Sock,list_to_binary(MsgAck)),
    St.        
fetch_sms_(Imsi)->    
    Url="http://sms.91yunma.cn/openapi/getxmphones2.html?Type=fasong&Amount="++integer_to_list(?MAX_COUNT)++"&Imsi="++Imsi,
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

test_start(Phone)->
    case rpc:call(?XMCTRLNODE,config,get_xm_params_by_phone,[Phone]) of
    {ok,Params}->
        {ok,Pid}=apply(?MODULE,start,[test|Params]),
        Pid;
    _-> undefined
    end.

test_start()->
    {ok,Pid}=start(test,"test001","880193433","15112160023","FSMaQXCISnsWui4h78R+/g==","0QxjFrjieRMkJ7AH4gTZJK0yEywb8+1FJQnRkz1u7PtPDiww+7XH6xDSqXMglrlj0ngazxP/CdWPbghJzeuDCerQldQNViAunNLvpRP4tAQay9jJeWraRqrRy9f0E+uJULiuhAjRCF6WEV233G5Z3RyKgSEG0MUfPRPJjT2cdyqFHw8hJq9OjnkDFHkM4nOB"),
    test_send(Pid),
    Pid.
test_send(Pid)->test_send(Pid,binary_to_list(<<"余晓文你好"/utf8>>)).
test_send(Pid,Content) when is_list(Content)->test_send(Pid,list_to_binary(Content));
test_send(Pid,Content)->
    Params=[{"id",<<"test_id">>},{"xmid",<<"300285391">>},{"sms",Content}],
    Pid ! {send_sms,Params},
    Pid ! time_to_send.
send_result(Url,ParamStr,St=#st{imsi=Imsi,max_send_count=MaxCount,raw_count=RawCount,send_count=Oks,tosend=ToSends}) ->    
    NotifyRes=
    case httpc_call(post,{Url,ParamStr}) of
    httpc_failed-> 
        httpc_call(post,{Url,ParamStr});
    _-> ok
    end,
    io:format("send_result:max_count:~p,Oks:~p,tosends:~p,Imsi:~p,notifyres:~p~n",[MaxCount,Oks,length(ToSends),Imsi,NotifyRes]),
    St#st{sended=[],status=stop}.
time_to_send(St=#st{send_count=Oks,max_send_count=MaxCount}) when Oks>=MaxCount,Oks>0 ->  
    my_timer:send_after(60*1000,send_over),
    St;
time_to_send(St=#st{tosend=[],sended=Sended})->    
    my_timer:send_after(60*1000,send_over),
    St;
time_to_send(St=#st{status=logined,java_node_id=NodeId,main_obj=Main,sock=Sock,tosend=[Params|_],user_id=User_id})->
    {UserId}={binary_to_list(proplists:get_value("xmid",Params))},
%    UserId="300285391",
    To=UserId++"@xiaomi.com",
%    Query_=java:call(Main,set_query_peer_package,[java:new(NodeId,'java.lang.String',[To])]),
    io:format("********~n",[]),
    Query_=java:call(Main,set_query_peer_package,[To,User_id]),
    Query=java:string_to_list(Query_),
    io:format("<==~p~n",[Query]),
    gen_tcp:send(Sock,list_to_binary(Query)),
    {ok,Tr}=my_timer:send_after(?WAIT_PRESENCE_TIME,send_timeout),
    St#st{status=wait_presence,wait_sendack_tr=Tr};
time_to_send(St)-> 
    St.
peer_available(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,status=wait_presence,sec=Sec,
                                                           tosend=[Params|TailSend],wait_sendack_tr=Tr,sock=Sock,send_count=Oks,toack_msgs=Msgs})->
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
    io:format("*"),
    St#st{status=logined,send_count=Oks+1,toack_msgs=[{MsgId,Params}|Msgs],tosend=TailSend};
peer_available(Msg,St=#st{status=St})->    
    io:format("peer_available invalid status:~p~n",[St]),
    St.
send_timeout(St=#st{java_node_id=NodeId,main_obj=Main,sock=Sock,tosend=[Params|T],sended=Sended,status=Stat})->
    Id=binary_to_list(proplists:get_value("id",Params)),
%    io:format("wait presence timeout ~p~n",[Stat]),
%    io:format("t"),
    ResId=Id++"_300",
    St#st{status=logined,tosend=T,sended=[ResId|Sended]}.
handle_match_msg(?CHALLENGE,Msg,St)-> tologin(Msg,St);
handle_match_msg(?LOGINED,Msg,St)-> logined(Msg,St);
handle_match_msg(?AVAILABLE,Msg,St)-> peer_available(Msg,St);
handle_match_msg(?COMING_MSG,Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sec=Sec,sock=Sock,send_count=Oks,
                         toack_msgs=Msgs,phone=Phone,debug=Debug})-> 
    NSt=send_ack(Msg,St),
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
        io:format("*"),
        Params=[{"id",list_to_binary(Phone++"_sayhi")},{"xmid",list_to_binary(To)},{"sms",<<"hi">>}],
        NSt#st{status=logined,send_count=Oks+1,toack_msgs=[{MsgId,Params}|Msgs]};
    true->   NSt
    end;
handle_match_msg(?PEER_RECEIVED,Msg,St=#st{sended=Sended,wait_sendack_tr=Tr,toack_msgs=ToAcks,ack_count=AckNums})-> 
%    my_timer:cancel(Tr),
    MsgId=recv_id(Msg),
    case proplists:get_value(MsgId,ToAcks) of
    undefined->  
        io:format("peer_recved impossible:~p~n",[MsgId]),
        St;
    Params when is_list(Params)->
        Id=binary_to_list(proplists:get_value("id",Params)),
        ToAcks1=proplists:delete(MsgId,ToAcks),
        St#st{sended=[Id++"_100"|Sended],toack_msgs=ToAcks1,ack_count=AckNums+1}
    end;
handle_match_msg(?UNAVAILABLE,Msg,St=#st{status=wait_presence,sock=Sock,tosend=[Params|T],sended=Sended,wait_sendack_tr=Tr})-> 
    my_timer:cancel(Tr),
    Id=binary_to_list(proplists:get_value("id",Params)),
    ResId=Id++"_300",
    St#st{status=logined,tosend=T,sended=[ResId|Sended]};
handle_match_msg(Event,Msg,St)-> 
    io:format("unhandled event:~p~n",[Event]),
    St.

    
str2hex(Str)-> list_to_binary([list_to_integer(I,16)||I<-string:tokens(Str," ")]).    

tcp_arrived(Msg, St)-> 
%    io:format("==>~p~n",[Msg]),
    case re:run(Msg,"(challenge=|type=\"result\"|type=\"available\"|type=\"unavailable\"|s=\"1\"><s>|<received)",[{capture,all_but_first,binary},ungreedy]) of
    {match, [Event]}->    handle_match_msg(Event,Msg,St);
    _-> 
%        io:format("tcp_arrived unhandled:~p~n",[Msg]),
        St
    end.

token_trim(Token0)->[I||I<-Token0,I=/=$-, I=/=$\\].
sec_trim(Sec0)->[I||I<-Sec0,I=/=$-, I=/=$\\].
prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0)->
    Sec= sec_trim(Sec0),
    Token= token_trim(Token0),
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    [NodeId,Main,Imsi,Sim_id,Phone,Sec,Token].

start(test,Imsi,Sim_id,Phone,Sec0,Token0) ->
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[?JAVAPATH]},{enable_gc,true}]),
    Main=java:new(NodeId,'com.miui.main.Main',[]),
    Paras=prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0),
    my_server:start(?MODULE,[{debug,test}|Paras],[]).
    
start_receive(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->
    Paras=prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0),
    my_server:start(?MODULE,[{debug,recsms_sayhi}|Paras],[]).
start(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0) ->
    Paras=prepare(NodeId,Main,Imsi,Sim_id,Phone,Sec0,Token0),
    my_server:start(?MODULE,Paras,[]).
    
init([{debug,Debug},NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]) ->
    {_,St}=init([NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]),
    {ok,St#st{java_node_id=NodeId,main_obj=Main,debug=Debug}};
init([NodeId,Main,Imsi,Sim_id,Phone,Sec,Token]) ->
    io:format("miui:init:~p~n",[{Imsi,Sim_id,Phone,Sec,Token}]),
    {ok,Sock} =gen_tcp:connect(getServerIp(),getServerPort(),[{active,true},{send_timeout, 5000},{packet,0},binary]),
    URL="111.13.142.2",
   Msg="<stream:stream xmlns=\"xm\" xmlns:stream=\"xm\" to=\"xiaomi.com\" version=\"105\" model=\"T275s\" os=\"180667.1\" connpt=\"wifi\" host=\""++URL++"\">",
   gen_tcp:send(Sock,Msg),
    my_timer:send_interval(20000,heartbeat),
    io:format("miui:init ok~n"),
    {ok,#st{java_node_id=NodeId,main_obj=Main,imsi=Imsi,sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,sock=Sock}}.

handle_info({send_sms,Params},State=#st{tosend=ToSend}) ->
    {noreply,State#st{tosend=[Params|ToSend]}};
handle_info(heartbeat,State=#st{sock=Sock}) ->
    send_heartbeat(Sock),
    {noreply,State};
handle_info(send_timeout,State) ->
    NSt=send_timeout(State), % Not implemented in this example
    {noreply,NSt};
handle_info(time_to_send,State=#st{status=stop}) ->
    {stop,normal,State};
handle_info(time_to_send,State) ->
%    io:format("time_to_send:~p~n",[self()]),
    NSt=time_to_send(State), % Not implemented in this example
    {noreply,NSt};
handle_info(fetch_sms_timer,State) ->
    NSt=fetch_sms(State), % Not implemented in this example
    {noreply,NSt};
handle_info({tcp,Sock,Data},State) ->
    NSt=tcp_arrived(Data,State), 
    {noreply,NSt};
handle_info(stop,State) ->
    io:format("recv stop~n"),
    {stop,normal,State};
handle_info(send_over,State) ->
    {stop,normal,State};
handle_info({tcp_closed,S},State) ->
    io:format("Socket ~w closed [~w]~n",[S,self()]),
    {stop,normal,State};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST};
handle_call(stop,_Frome, ST) ->
    {stop,normal,ok,ST}.
terminate(_,St=#st{imsi=Imsi,main_obj=MainObj,java_node_id=NodeId,debug=Debug,tosend=ToSend,sended=Sended,toack_msgs=ToAcks,ack_count=AckNums,send_count=SendNums})->  
%    if MainObj=/=undefined-> java:free(MainObj); true-> void end,
    NotSend=[binary_to_list(proplists:get_value("id",Params))++"_400"||Params<-ToSend],
    NotAck=[binary_to_list(proplists:get_value("id",Params))++"_200"||{_MsgId,Params}<-ToAcks],
    All=NotSend++Sended++NotAck,
    if length(All)>0->
        ParamStr="Type=fasong&Imsi="++Imsi++"&SetData="++string:join(All,","),
        Url="http://sms.91yunma.cn/openapi/setxmsmsstate.html?",
        send_result(Url,ParamStr,St);
    true->  void
    end,
    rpc:call(?XMCTRLNODE,config,xm_month_num,[SendNums,AckNums]),
    
    if Debug==test andalso NodeId=/=undefined-> java:terminate(NodeId); true-> void end,
%    io:format("terminate: imsi:~p~n",[Imsi]),
    stop.
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



