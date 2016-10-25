-module(push_service).
-compile(export_all).
-include("yaws_api.hrl").
-include("login_info.hrl").


handle(Arg,_Params)->
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    Ip1=utility:client_ip(Arg),
    {SelfPhone,Acc, Did,Clidata} = utility:decode(Arg,[{self_phone, s},{acc, s},{device_id, s},{clidata,r}]),
    utility:log("./log/xhr_poll.log","push_service:~p did:~p acc:~p~n clidata:~p~n",[SelfPhone,Did,Acc,Clidata]),
    case login_processor:get_account_tuple(SelfPhone) of
    #login_itm{acc=Acc,devid=Did,ip=Ip0,pls=Pls}=Itm-> 
        Pid0=whereis(list_to_atom(Did)),
        Pid =
            case Pid0 of
            undefined-> login_processor:start_poll(Did,SelfPhone);
            P-> P
            end,
        xhr_poll:attrs(Pid,Params),
        xhr_poll:up(Pid),
%        io:format("android_push:~p~n",[{SelfPhone,Pid0,Pid}]),
        if Ip1 =/=Ip0 orelse Pid0=/=Pid -> 
            Ip=login_processor:get_wan_ip(Ip1,Ip0),
            login_processor:update_itm(Itm#login_itm{ip=Ip,pls=lists:keystore(push_pid,1,Pls,{push_pid,Pid})}); true-> void end,
        erlang:monitor(process,Pid),
        receive
            {failed,Reason}-> 
                utility:log("./log/xhr_poll.log","push_service:failed:~p ~n",[Reason]),
                utility:pl2jso([{status,failed}, {reason,Reason},{clidata,Clidata}]);
            {'DOWN', _Ref, process, Pid, _Reason}->
                utility:pl2jso([{status,ok}, {data,utility:pl2jsos([[]])},{clidata,Clidata}]);
            Msgs->
                utility:log("./log/xhr_poll.log","push_service:msg:~p ~n",[Msgs]),
                utility:pl2jso([{status,ok}, {data, utility:pl2jsos(Msgs)},{clidata,Clidata}])
        after 300000->
            utility:pl2jso([{status,failed},{reason, timeout}])
        end;
    O=#login_itm{acc=_Acc,devid=_Did}->
        io:format("push_service otherwhere:~p,~nshould:~p~n",[{SelfPhone,Acc, Did},O] ),
        utility:log("./log/xhr_poll.log", "push_service otherwhere:~p, ~nshould:~p~n",[{SelfPhone,Acc, Did},O] ),
        ack_event(login_otherwhere,Clidata);
    Unexpected->
        utility:log("./log/xhr_poll.log","push_service unlogined from ~p~nack:~p~n",[{SelfPhone,Acc, Did},Unexpected] ),
        ack_event(unlogined,Clidata)
    end.
    
ack_event(Evt)-> ack_event(Evt, null).
ack_event(Evt,Clidata)->
    utility:pl2jso([{status,ok},{data,utility:pl2jsos([[{event,Evt}]])},{clidata,Clidata}]).
