-module(uas).
-compile(export_all).


-record(ust,{
    wspid,
    worker,
    json
}).

start() ->
    my_server:start({local,uas}, ?MODULE, [], []),
    io:format("start log.~n"),
    llog:start(),
    io:format("start rtp_sup.~n"),
    rtp_sup:start(),
    io:format("start relay_sup.~n"),
    relay_sup:start(),
    io:format("start meeting rooms.~n"),
    rooms:start(),
    ok.
stop() ->
    my_server:cast(uas, stop).

init([]) ->
    {ok,[]}.
    
handle_info({connected,Pid},ST) ->
    Wkr = start_wkr(Pid),
    llog("~p in",[Pid]),
    {noreply,[#ust{wspid=Pid,worker=Wkr}|ST]};
handle_info({binduser, Pid,UUID},ST) ->
    Wkr = start_wkr(Pid,UUID),
    llog("~p in with ~p", [Pid,UUID]),
    {noreply,[#ust{wspid=Pid,worker=Wkr}|ST]};
handle_info({disconnect,Pid},ST) ->
    case lists:keysearch(Pid,2,ST) of
        {value,#ust{worker=Wkr}} ->
            ok = stop_wkr(Wkr),
            llog("~p out",[Pid]),
            {noreply,lists:keydelete(Pid,2,ST)};
        false ->
            llog("~p dead",[Pid]),
            {noreply,ST}
    end;
handle_info({text,Pid,Bin},ST) ->
  case rfc4627:decode(Bin) of
    {ok,{obj,[{"type",_}|_JMsg]=JSON},_} ->
      llog("~p send ~p",[Pid,Bin]),
      case lists:keysearch(Pid,2,ST) of
        {value,U1} ->
            ok = info_wkr(U1#ust.worker,JSON),
            Old=U1#ust.json,
            {noreply,lists:keyreplace(Pid,2,ST,U1#ust{json=[JSON|Old]})};
        false ->
            io:format("unconnected user ~p~n",[Pid]),
            {noreply,ST}
      end;
    _ ->
      llog("~p unknow ~p", [Pid, Bin]),
      {noreply,ST}
  end.

handle_call(random32,_From,ST) ->
    {reply, random:uniform(16#FFFFFFFF),ST};
handle_call(list,_From,ST) ->
    {reply, {ok,ST},ST}.
    
handle_cast(stop,_ST) ->
    {stop,normal,[]}.
terminate(normal,_) ->
    ok.

start_wkr(WsPid) ->
    {ok,Pid} = my_server:start(wkr,[WsPid,""],[]),
    Pid.
start_wkr(WsPid,UUID) ->
    {ok,Pid} = my_server:start(wkr,[WsPid,UUID],[]),
    Pid.
    
stop_wkr(Wkr) ->
    my_server:cast(Wkr,stop).
    
info_wkr(Wkr,JSON) ->
    Wkr ! {json,JSON},
    ok.
    
llog(_F,_M) -> ok.
%    llog ! {self(),F,M}.