-module(miui).
-compile(export_all).
-define(JAVAPATH,"./miui_sb2.jar").
-define(HTTP_TIMEOUT,5000).
-define(MAX_COUNT,1).

-record(st, {
      java_node_id,
      main_obj,
	imsi,
	sim_user_id,
	phone,
	sec,
	token,
	challenge,
	sock,
	tosend=[],
	sended=[],
	wait_sendack_tr,
    test,
	status=init
}).

java_path()->?JAVAPATH.
getServerIp()->  "111.13.142.2".    
getServerPort()->5222.

get_login_string(Sim_user_id,Phone,Sec,Token,Challenge,NodeId,MainObj)->
        Sim_=java:new(NodeId,'java.lang.String',[Sim_user_id]),
        Phn_=java:new(NodeId,'java.lang.String',[Phone]),
        S_=java:new(NodeId,'java.lang.String',[Sec]),
        Token_=java:new(NodeId,'java.lang.String',[Token]),
        Challenge_=java:new(NodeId,'java.lang.String',[Challenge]),
        Login_=java:call(MainObj,login_package,[Sim_,Phn_,S_,Token_,Challenge_]),
        {ok,java:string_to_list(Login_)}.

send_heartbeat(Sock)-> 
    gen_tcp:send(Sock,<<"<iq to='xiaomi.com' id='0' chid='0' type='get'><ping xmlns='urn:xmpp:ping'></ping></iq>">>).
tologin(Msg,St=#st{sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,sock=Sock,status=init})->
    {ok,NodeId} = java:start_node([{add_to_java_classpath,[?JAVAPATH]}]),
    MainObj=java:new(NodeId,'com.miui.main.Main',[]),
%    {match, [Challenge]}=re:run(Msg,"challenge='(.*)'",[{capture,all_but_first,list},ungreedy]),
    {ok,LoginStr}=get_login_string(Sim_id,Phone,Sec,Token,binary_to_list(Msg),NodeId,MainObj),
    gen_tcp:send(Sock,list_to_binary(LoginStr)),
    send_heartbeat(Sock),
    St#st{status=tologin,java_node_id=NodeId,main_obj=MainObj};
tologin(_Msg,St)-> 
    io:format("error status rec tologin~n"),
    St.
logined(_Msg,St=#st{test=true})-> St#st{status=logined};
logined(_Msg,St=#st{status=tologin,imsi=Imsi})-> 
    case fetch_sms(Imsi) of
    {ok,Smss}->    
        io:format("~p fetch_sms:~p~n",[self(),Smss]),
        my_timer:send_interval(1000,time_to_send),
        St#st{status=logined,tosend=Smss};
    _-> St#st{status=logined}
    end;
logined(_Msg,St)-> 
    io:format("error status rec logined~n"),
    St.

get_userid_by_phone(Phone)->
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
send_ack(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,sock=Sock})-> 
    Msg_=java:new(NodeId,'java.lang.String',[binary_to_list(Msg)]),
    MsgAck_=java:call(MainObj,message_ack,[Msg_]),
    MsgAck=java:string_to_list(MsgAck_),
    io:format("<==send_ack: ~p~n",[MsgAck]),
    gen_tcp:send(Sock,list_to_binary(MsgAck)),
    St.        
fetch_sms(Imsi)->    
    Url="http://sms.91yunma.cn/openapi/getxmphones2.html?Type=fasong&Amount="++integer_to_list(?MAX_COUNT)++"&Imsi="++Imsi,
    case httpc_call(get,{Url}) of
    {ok,Json}->
        case utility:decode_json(Json, [{ret, i},{data, r}]) of
        {0, DataJson}-> 
            {Dests}=utility:decode_json(DataJson,[{phones,r}]),
            {ok,[Params||{obj,Params}<-Dests]};
        _-> error
        end;
    _->
        http_error
    end.

test_start()->start(test,"test001","880193433","15112160023","FSMaQXCISnsWui4h78R+/g==","0QxjFrjieRMkJ7AH4gTZJK0yEywb8+1FJQnRkz1u7PtPDiww+7XH6xDSqXMglrlj0ngazxP/CdWPbghJzeuDCerQldQNViAunNLvpRP4tAQay9jJeWraRqrRy9f0E+uJULiuhAjRCF6WEV233G5Z3RyKgSEG0MUfPRPJjT2cdyqFHw8hJq9OjnkDFHkM4nOB").
test_send(Pid,Xmid)->test_send(Pid,Xmid,binary_to_list(<<"余晓文你好"/utf8>>)).
test_send(Pid,Xmid,Content) when is_list(Content)->test_send(Pid,Xmid,list_to_binary(Content));
test_send(Pid,Xmid,Content)->
    Params=[{"id",<<"test_id">>},{"xmid",<<"300285391">>},{"sms",Content}],
    Pid ! {send_sms,Params},
    Pid ! time_to_send.
time_to_send(St=#st{tosend=[],imsi=Imsi,sended=Sended}) when length(Sended)>0 ->    
    Url="http://sms.91yunma.cn/openapi/setxmsmsstate.html?Type=fasong&Imsi="++Imsi++"&SetData="++string:join(Sended,";"),
    httpc_call(post,{Url,[]}),
    St#st{sended=[],status=stop};
time_to_send(St=#st{status=logined,java_node_id=NodeId,main_obj=Main,sock=Sock,tosend=[Params|_]})->
    {UserId}={binary_to_list(proplists:get_value("xmid",Params))},
%    UserId="300285391",
    To=UserId++"@xiaomi.com",
    Query_=java:call(Main,set_query_peer_package,[java:new(NodeId,'java.lang.String',[To])]),
    Query=java:string_to_list(Query_),
    io:format("<==~p~n",[Query]),
    gen_tcp:send(Sock,list_to_binary(Query)),
    {ok,Tr}=my_timer:send_after(5000,send_timeout),
    St#st{status=wait_presence,wait_sendack_tr=Tr};
time_to_send(St)-> St.
peer_available(Msg,St=#st{java_node_id=NodeId,main_obj=MainObj,status=wait_presence,tosend=[Params|_],wait_sendack_tr=Tr,sock=Sock})->
    my_timer:cancel(Tr),
    {match, [Server_To]}=re:run(Msg,"to=\"(.*)\"",[{capture,all_but_first,list},ungreedy]),
    Me_=java:new(NodeId,'java.lang.String',[Server_To]),
    UserId=binary_to_list(proplists:get_value("xmid",Params)),
%    UserId="300285391",
    To=UserId++"@xiaomi.com",
    To_=java:new(NodeId,'java.lang.String',[To]),
    Sms1=binary_to_list(proplists:get_value("sms",Params)),
    Fun=fun(I) when I>127-> I-256;    (I)-> I end,
    Sms=[Fun(I)||I<-Sms1],
    Sms_=java:new(NodeId,'java.lang.String',[Sms]),
    ToSend_=java:call(MainObj,set_sms_package,[Me_,To_,Sms_]),
    ToSend=java:string_to_list(ToSend_),
    gen_tcp:send(Sock,list_to_binary(ToSend)),
    {ok,NTr}=my_timer:send_after(5000,send_timeout),
    St#st{status=wait_send_ack,wait_sendack_tr=NTr};
peer_available(Msg,St)->    
    io:format("peer_available invalid status~n"),
    St.
peer_recved(_,St=#st{status=wait_send_ack,tosend=[Params|Tail],sended=Sended,wait_sendack_tr=Tr})-> 
    my_timer:cancel(Tr),
    Id=binary_to_list(proplists:get_value("id",Params)),
    St#st{status=logined,tosend=Tail,sended=[Id++"_100"|Sended]};
peer_recved(_,St)-> 
    io:format("peer_recved invalid status~n"),
    St.        
send_timeout(St=#st{java_node_id=NodeId,main_obj=Main,sock=Sock,tosend=[Params|T],sended=Sended})->
    Id=binary_to_list(proplists:get_value("id",Params)),
    ResId=Id++"_200",
    St#st{status=logined,tosend=T,sended=[ResId|Sended]}.
    
str2hex(Str)-> list_to_binary([list_to_integer(I,16)||I<-string:tokens(Str," ")]).    

tcp_arrived(Msg, St)-> 
    io:format("==>~p~n",[Msg]),
    case re:run(Msg,"(challenge=|type=\"result\"|type=\"available\"|s=\"1\"><s>|<received)",[{capture,all_but_first,binary},ungreedy]) of
    {match, [<<"challenge=">>]}->    tologin(Msg,St);
    {match, [<<"type=\"result\"">>]}->    logined(Msg,St);
    {match, [<<"type=\"available\"">>]}->    peer_available(Msg,St);
    {match, [<<"s=\"1\"><s>">>]}->    send_ack(Msg,St);
    {match, [<<"<received">>]}->    peer_recved(Msg,St);
    _-> St
    end.

start(test,Imsi,Sim_id,Phone,Sec0,Token0) ->
    Sec= [I||I<-Sec0,I=/=$-, I=/=$\\],
    Token= [I||I<-Token0,I=/=$-, I=/=$\\],
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start(?MODULE,[test,Imsi,Sim_id,Phone,Sec,Token],[]).
    
start(Imsi,Sim_id,Phone,Sec0,Token0) ->
    Sec= [I||I<-Sec0,I=/=$-, I=/=$\\],
    Token= [I||I<-Token0,I=/=$-, I=/=$\\],
    case whereis(my_timer) of
    undefined-> my_timer:start();
    _-> pass
    end,
    my_server:start(?MODULE,[Imsi,Sim_id,Phone,Sec,Token],[]).
    
init([test,Imsi,Sim_id,Phone,Sec,Token]) ->
    {_,St}=init([Imsi,Sim_id,Phone,Sec,Token]),
    {ok,St#st{test=true}};
init([Imsi,Sim_id,Phone,Sec,Token]) ->
    io:format("miui:init:~p~n",[{Imsi,Sim_id,Phone,Sec,Token}]),
    {ok,Sock} =gen_tcp:connect(getServerIp(),getServerPort(),[{active,true},{send_timeout, 5000},{packet,0},binary]),
    URL="111.13.142.2",
   Msg="<stream:stream xmlns=\"xm\" xmlns:stream=\"xm\" to=\"xiaomi.com\" version=\"105\" model=\"T275s\" os=\"180667.1\" connpt=\"wifi\" host=\""++URL++"\">",
   gen_tcp:send(Sock,Msg),
    {ok,#st{imsi=Imsi,sim_user_id=Sim_id,phone=Phone,sec=Sec,token=Token,sock=Sock}}.

handle_info({send_sms,Params},State=#st{tosend=ToSend}) ->
    {noreply,State#st{tosend=[Params|ToSend]}};
handle_info(send_timeout,State) ->
    NSt=send_timeout(State), % Not implemented in this example
    {noreply,NSt};
handle_info(time_to_send,State=#st{status=stop}) ->
    {stop,normal,State};
handle_info(time_to_send,State) ->
    NSt=time_to_send(State), % Not implemented in this example
    {noreply,NSt};
handle_info({tcp,Sock,Data},State) ->
    NSt=tcp_arrived(Data,State), 
    {noreply,NSt};
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
terminate(_,St=#st{imsi=Imsi})->  
    io:format("terminate: imsi:~p~n",[Imsi]),
    stop.
stop(Pid)->    my_server:call(Pid,stop).    

show(Pid)->
    Act=fun(St)->
        {St,St}
    end,
    my_server:call(Pid,{act,Act}).


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
    case send_httpc(Type,Arg) of
        {ok,{_,_,Ack}} ->
            case rfc4627:decode(Ack) of
            {ok,Json,_}->            
                io:format("httpc_call(~p,~p)~n Res:~p~n", [Type,Arg,Json]),
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


