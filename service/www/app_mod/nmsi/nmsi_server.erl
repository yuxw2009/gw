-module(nmsi_server).
-behaviour(gen_server).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
-include("nmsi_server.hrl").
-record(conn_state,{status=socket_connected,debug=true,pls=[]}).
-compile(export_all).

init([IP,Port]) when is_tuple(IP) and is_integer(Port) ->
    io:format("~p init~n",[?MODULE]),
    Options= if is_tuple(IP)-> [binary,{ip,IP},{packet,raw},{active,once},{keepalive,true}];
                true-> [binary,{packet,raw},{active,once},{keepalive,true}]
             end,
    case gen_tcp:listen(Port,Options) of
        {ok,Listen} ->
            {ok,{listened,Listen,[]}};
        {error,Reason} ->
            {stop,{listen_failed,Reason}}
    end.

terminate(Reason,{listened,Listen,Pids}) ->
    utility:log("nmsi_server terminated reason:~p",[Reason]),
    gen_tcp:close(Listen),
    [exit(Pid,kill)||{Pid,_}<-Pids],
    ok.


handle_call(accept,_From,{listened,Listen,Pids}) ->
    Self=self(),
    Pid = spawn(fun() -> waiting_for_accept(Listen,Self) end),
    io:format("accept:~p~n",[Pid]),
    erlang:monitor(process,Pid),
    {reply,ok,{listened,Listen,[Pid|Pids]}};

handle_call({act,Act},_From,State) ->
    {Reply,NewSt} = Act(State),
    {reply,Reply,NewSt};

handle_call(stop,_From,State) ->
    {stop,normal,stopped,State}.

handle_cast({new_socket,Pid,Socket},{listened,Listen,Pids}) ->
    {ok,{PeerAddr,PeerPort}}=inet:peername(Socket),
    io:format("new_socket:pid:~p,socket:~p from~p~n",[Pid,Socket,{PeerAddr,PeerPort}]),
    erlang:monitor(process,Pid),
    {noreply,{listened,Listen,[{Pid,PeerAddr}|Pids]}};

handle_cast({accept_failed,_Reason},State) ->
    {noreply,State}.

handle_info({'DOWN', _Ref, process, Pid, _Reason},{listened,Listen,Pids})->
    case lists:keyfind(Pid,1,Pids) of
    {Pid,PeerAddr}->
        utility:log("nmsi_server pid ~p down reason:~p peer:~p",[Pid,_Reason,PeerAddr]);
    _->
        utility:log("nmsi_server pid ~p down reason:~p unknown peer",[Pid,_Reason])
    end,
    {noreply,{listened,Listen,lists:delete(Pid,lists:keydelete(Pid,1,Pids))}};
handle_info(_Msg,State) ->
    {noreply,State}.

code_change(_Old,State,_Extra) ->
    {noreply,State}.

waiting_for_accept(Listen,Parent) ->
    case gen_tcp:accept(Listen) of
        {ok,Socket} ->
            Pid = spawn(fun() -> waiting_for_accept(Listen,Parent) end),
            gen_server:cast(Parent,{new_socket,Pid,Socket}),
            {ok,TRef} = timer:send_after(nmsi_configure:heart_interval(),heart_interval_arrive),
            loop(Socket,#conn_state{},{TRef,0});
        {error,Reason} ->
            gen_server:cast(Parent,{accept_failed,Reason})
    end.

handle_cmd(2100,[{1,Account},{2,Pwd}],nmsi_login) when is_list(Account) and is_list(Pwd)->
    case (Account =:= nmsi_configure:ss_account()) and (Pwd =:= nmsi_configure:ss_pwd() orelse Pwd =:= nmsi_configure:ss_pwd1()) of
        true ->
            {[{"RETN","0"},{"DESC","Success."}],ss_login};
        false ->
            {[{"RETN","90004"}],nmsi_login}
    end;
handle_cmd(2100,[{1,_Account},{2,_Pwd}],socket_connected) ->
    {[{"RETN","90001"}],socket_connected};
handle_cmd(2100,[{1,_Account},{2,_Pwd}],ss_login) ->
    {[{"RETN","90002"}],ss_login};

handle_cmd(2101,[],ss_login) ->
    {[{"RETN","0"},{"DESC","Success."}],nmsi_login};
handle_cmd(2101,[],State) ->
    {[{"RETN","90010"}],State};

handle_cmd(90000,[{1,Account},{2,Pwd}],socket_connected) when is_list(Account) and is_list(Pwd)->
    case (Account =:= nmsi_configure:nmsi_account()) and (Pwd =:= nmsi_configure:nmsi_pwd()) of
        true ->
            {[{"RETN","0"},{"DESC","Success."}],nmsi_login};
        false ->
            {[{"RETN","90004"}],socket_connected}
    end;
handle_cmd(90000,[{1,_Account},{2,_Pwd}],State) ->
    io:format("90000 state is ~p~n",[State]),
    {[{"RETN","90002"}],State};

handle_cmd(90001,[],nmsi_login) ->
    {[{"RETN","0"},{"DESC","Success."}],socket_connected};
handle_cmd(90001,[],socket_connected) ->
    {[{"RETN","90001"}],socket_connected};
handle_cmd(90001,[],ss_login) ->
    {[{"RETN","90010"}],ss_login};

handle_cmd(CMD,Para,ss_login) ->
    Ack = nmsi:handle_cmd(CMD,Para),
    io:format("nmsi_server:handle_cmd ack:~p~n",[Ack]),
    {Ack,ss_login};
handle_cmd(_,_,State) ->
    {[{"RETN","90010"}],State}.

handle_msg({?MSG_HEAD,?MSG_MML_TYPE,?MSG_VERSION,_,_,_,_,_,_,Act,State}) ->
    {Cmd,Para} = parse_act(Act),
    io:format("nmsi_server:handle_msg:~p~n",[{Cmd,Para}]),
    NewCmd =     
        try
            list_to_integer(Cmd)
        catch
            _:_ ->
                Cmd
        end, 
    {Ack,NewState} = handle_cmd(NewCmd,Para,State),
    utility:log("log/nmsi.log","st:~p =>~p para:~p~nack:~p~n",[State,NewCmd,Para,Ack]),
    {Cmd,Ack,NewState};
handle_msg({?MSG_HEAD,?MSG_MML_TYPE,_,_,_,_,_,_,_,Act,State}) ->
    {Cmd,_} = parse_act(Act),
    {Cmd,[{"RETN","90021"}],State};
handle_msg({?MSG_HEAD,_,_,_,_,_,_,_,_,Act,State}) ->
    {Cmd,_} = parse_act(Act),
    {Cmd,[{"RETN","90023"}],State};
handle_msg({_,_,_,_,_,_,_,_,_,Act,State}) ->
    {Cmd,_} = parse_act(Act),
    {Cmd,[{"RETN","90024"}],State}.

ack_msg(Cmd,[{"RETN",Ack}|_] = CmdAck,EID,TID) ->
    AckStr = string:join(["ACK",ack_date(),Cmd,string:join([A++"="++B||{A,B}<-CmdAck],",")]," : "),
    list_to_binary([?MSG_HEAD,?MSG_ACK_TYPE,<<(39+length(AckStr)):32>>,?MSG_VERSION,EID,TID,<<(list_to_integer(Ack)):32>>,<<0:8>>,<<1:16>>,<<0:16/integer-unit:8>>,list_to_binary(AckStr)]).

ack_date() ->
    {{Year,Month,Day},{Hour,Minute,Second}} = calendar:now_to_local_time(erlang:now()),
    int_to_str(Year)   ++ "-" ++ int_to_str(Month)  ++ "-" ++
    int_to_str(Day)    ++ " " ++ int_to_str(Hour)  ++ ":" ++
    int_to_str(Minute) ++ ":" ++ int_to_str(Second).

int_to_str(I) ->
    if
        I < 10 ->
            "0" ++ integer_to_list(I);
        true ->
            integer_to_list(I)
    end.

conn_status(Pid)->
    Act=fun(S)->
                     {S,S}   end,
    exe_cmd(Pid,Act).
set_debug(Pid,Debug)->
    Act=fun(S)->  {ok,S#conn_state{debug=Debug}} end,
    exe_cmd(Pid,Act).
exe_cmd(Pid,Act)->                     
    Pid !{act,Act,self()},
    receive
    {ack,Res}->
        Res
    after 2000->
        timeout
    end.

loop(Socket,ConnState=#conn_state{status=State,debug=Debug},{TRef,_Retry} = Heart) ->
    if Debug-> io:format(".~p.",[self()]); true-> void end,
    {_,Peer}=inet:peername(Socket),
    HeartMML = list_to_binary([?MSG_HEAD,?MSG_HEART_TYPE]),
    receive
        {tcp,Socket,<<Head:4/binary,Type:1/binary,Len:4/integer-unit:8,Ver:4/binary,EID:8/binary,TID:4/binary,Ack:4/binary,FUP:1/binary,CPID:2/binary,Rev:16/binary,Rest/binary>>} ->
            ActLen = Len - 39,
            NewState = 
                try 
                    <<Act:ActLen/binary>> = Rest,
                    {Cmd,CmdAck,NState} = handle_msg({Head,Type,Ver,EID,TID,Ack,FUP,CPID,Rev,Act,State}),
                    io:format("~p~n~p~n~p~n",[Cmd,CmdAck,NState]),
                    gen_tcp:send(Socket,ack_msg(Cmd,CmdAck,EID,TID)),
                    NState
                catch
                    E_H:E_S ->
                        io:format("90020 err,~p~n~p~n",[E_H,E_S]),
                        gen_tcp:send(Socket,ack_msg("Unknow",[{"RETN","90020"}],EID,TID)),
                        State
                end,
            inet:setopts(Socket,[{active,once}]),
            io:format("normal loop~n"),
            loop(Socket,ConnState#conn_state{status=NewState},Heart);
        {tcp,Socket,HeartMML} ->
            {ok,cancel}  = timer:cancel(TRef),
            {ok,NewTRef} = timer:send_after(nmsi_configure:heart_interval(),heart_interval_arrive),
            inet:setopts(Socket,[{active,once}]),
            loop(Socket,ConnState,{NewTRef,0});
        {tcp,Socket,_Bin} ->
            EID = <<0:64>>,
            TID = <<0:32>>,
            io:format("again 90020 err,~p~n",[_Bin]),
            gen_tcp:send(Socket,ack_msg("Unknow",[{"RETN","90020"}],EID,TID)),
            inet:setopts(Socket,[{active,once}]),
            loop(Socket,ConnState,Heart);
        {tcp_closed,Socket} ->
            utility:log("peer close socket ~p~n",[Peer]),
            {ok,cancel} = timer:cancel(TRef),
            gen_tcp:close(Socket);
        stop ->
            utility:log("we stop socket,peer:~p",[Peer]),
            {ok,cancel} = timer:cancel(TRef),
            gen_tcp:close(Socket);
        {act,Act,From} ->
            {R,NS}=Act(ConnState),
            From ! {ack,R},
            loop(Socket,NS,Heart);
        heart_interval_arrive ->
            {ok,cancel} = timer:cancel(TRef),
            {ok,NewTRef} = timer:send_after(nmsi_configure:heart_interval(),heart_interval_arrive),
            loop(Socket,ConnState,{NewTRef,0});
            %MaxRetry = nmsi_configure:heart_retry(),
            %case Retry of
            %    MaxRetry ->
            %        gen_tcp:close(Socket);
            %    _ ->
            %        {ok,NewTRef} = timer:send_after(nmsi_configure:heart_interval(),heart_interval_arrive),
            %        gen_tcp:send(Socket,HeartMML),
            %        loop(Socket,State,{NewTRef,Retry+1})
            %end
        _Msg ->
            loop(Socket,ConnState,Heart)
    end.

parse_act(Cmd) ->
    [Head|Rest] = string:tokens(string:strip(binary_to_list(Cmd),right,$;),":"),
    Para = 
        case length(Rest) of
            1 ->
                hd(Rest);
            _ ->
                string:join(Rest,":")
        end,
    F = fun(S) ->
            [K,V] = string:tokens(S,"="),
            NewK  = try
                        list_to_integer(K)
                    catch
                        _:_ ->
                            try
                                list_to_existing_atom(string:to_lower(K))
                            catch
                                _:_ ->
                                    list_to_atom(string:to_lower(K))
                            end
                    end,
            NewV  = try
                        list_to_integer(V)
                    catch
                        _:_ ->
                            string:strip(V,both,$")
                    end,
            {NewK,NewV}
        end,
    {Head,lists:map(fun(S) -> F(S) end,string:tokens(Para,","))}.
