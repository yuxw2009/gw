-module(traffic).
-compile(export_all).
-include("virtual.hrl").
-include("db_op.hrl").
%-record(call_t,{caller,oppid,callee,tppid,calltype,hktime=utility:ts(),starttime="not_talking",endtime,reason,op_sip_ip,tp_sip_ip,op_media_ip,tp_media_ip}).
-record(st,{started=true,callers=[],interval_stats=#traffic_t{},cdrs=[],other=[],fd,stat_tref}).
-define(CDR_INTERVAL, dbmanager:get_cdr_interval()).
-define(STAT_INTERVAL, 10000).
-define(CDR_FILENAME_BASE,"cdr/cdr").

get_call_nums()->
    length(ets:tab2list(yxa_dialogs)).

start_monitor()->
    {_,Pid}=start(),
    erlang:monitor(process,Pid),
    Pid.
start()->
    my_server:start({local,?MODULE}, ?MODULE,[],[]).
to_binary(M=#{})->    
    Keys=maps:keys(M),
    Values0=maps:values(M),
    Values=[utility:value2binary(V)||V<-Values0],
    maps:from_list(lists:zip(Keys,Values));
to_binary(#traffic_item{caller=Caller,callee=Callee,newcaller=NCaller,newcallee=NCallee})-> 
    #traffic_item{caller=utility:value2binary(Caller),callee=utility:value2binary(Callee),newcaller=utility:value2binary(NCaller),newcallee=utility:value2binary(NCallee)}.
add_traffic(Traffic_0)->
    Traffic=to_binary(Traffic_0),
    Act=fun(ST=#st{started=true,interval_stats=Traffics0=#traffic_t{items=Items}})->
                    {[Traffic|Items],ST#st{interval_stats=Traffics0#traffic_t{items=[Traffic|Items]}}};
                (ST)->   {not_started,ST}
           end,
    cast(Act).
add_cdr(Cdr0=#{})->
    Cdr=to_binary(Cdr0),
    case dbmanager:get_cdr_servers() of      
    Nodes when is_list(Nodes)->
        %io:format("traffic:add_cdr sent to ~p~n",[Nodes]),
        [{traffic,Node} ! {add_cdr,Cdr}||Node<-Nodes];
    _-> logger:log(debug,"unbelievable in traffic:add_cdr~n")
    end.
add_call(OpPid,Call=#{})->
    Act=fun(ST=#st{callers=Callers})->
                erlang:monitor(process,OpPid),
                {ok,ST#st{callers=[{OpPid,Call}|Callers]}}
          end,
    cast(Act).
add_call({Caller,Callee,OpPid,TpPid,NewCaller,NewCallee})->
    Act=fun(ST=#st{callers=Callers})->
                erlang:monitor(process,OpPid),
                {ok,ST#st{callers=[#{hktime=>utility:ts(),caller=>Caller,callee=>Callee,oppid=>OpPid,tppid=>TpPid,newcaller=>NewCaller,newcallee=>NewCallee,starttime=>null}|Callers]}}
          end,
    cast(Act).
enter_talking(OpPid)->
    Act=fun(ST=#st{callers=Callers})->
                case lists:keytake(OpPid,1,Callers) of
                {value,{_OpPid,CallItem},NCallers}->
                    NCallItem=CallItem#{reason:= <<"0">>,starttime:=integer_to_list(sip_tp:seconds(erlang:localtime()))},
                    {noreply,ST#st{callers=[{OpPid,NCallItem}|NCallers]}};
                _->
                    {noreply,ST}
                end
          end,
    cast(Act).
modify(Match_key,Match_val,Mod_key,Mod_val,Lists)-> modify(Match_key,Match_val,Mod_key,Mod_val,Lists,[]).
modify(_Match_key,_Match_val,_Mod_key,_Mod_val,[],Res)-> lists:reverse(Res);
modify(Match_key,Match_val,Mod_key,Mod_val,[Head|Tails],Res)->
    case maps:get(Match_key,Head,undefined) of
    Match_val-> lists:reverse(Res)++[#{Mod_key=>Mod_val}|Tails];
    _-> modify(Match_key,Match_val,Mod_key,Mod_val,Tails,[Head|Res])
    end.
    
take(Match_key,Match_val,Lists)-> take(Match_key,Match_val,Lists,[]).
take(_Match_key,_Match_val,[],_Res)-> false;
take(Match_key,Match_val,[Head|Tails],Res)->
    case maps:get(Match_key,Head,undefined) of
    Match_val-> {value,Head,lists:reverse(Res)++Tails};
    _-> take(Match_key,Match_val,Tails,[Head|Res])
    end.

get_traffic()->
    Act=fun(ST=#st{interval_stats=Traffic})-> {Traffic,ST} end,
    act(Act).
show()->
    Act=fun(ST)-> {ST,ST} end,
    act(Act).
% callback for my_server
init([]) ->     
    {ok, Fd} = file:open(?CDR_FILENAME_BASE, [append]),
    my_timer:send_interval(?STAT_INTERVAL, stats),
    {ok,#st{fd=Fd}}.

handle_info(cdr_stats,State0=#st{cdrs=Cdrs,fd=Fd0})->
     write_cdr(State0),
     State=reset_cdr_file(State0),
    {noreply,State#st{cdrs=[]}};
handle_info(stats,State=#st{interval_stats=Traffic=#traffic_t{items=Items},cdrs=Cdrs,fd=Fd0})->
     if length(Items)>0-> ?DB_WRITE(Traffic#traffic_t{items=lists:reverse(Items)}); true-> void end,
    {noreply,State#st{interval_stats=#traffic_t{}}};
handle_info({'DOWN',_,process,Pid,_},State=#st{callers=Callers})->
    %{value,CallItem,NCallers} =take(oppid,Pid,Callers),
    case lists:keytake(Pid,1,Callers) of
    {value,{_OpPid,CallItem},NCallers}->
        traffic(CallItem),
        add_cdr(CallItem#{endtime:=integer_to_list(sip_tp:seconds(erlang:localtime()))}),
        {noreply,State#st{callers=NCallers}};
    _->
        {noreply,State}
    end;
handle_info({add_cdr,Cdr},State=#st{cdrs=Cdrs,stat_tref=StatTref})->
    State1=
    if StatTref==undefined->  
        {ok,Tref1}=my_timer:send_interval(?CDR_INTERVAL, cdr_stats),
        State#st{stat_tref=Tref1};
    true-> State
    end,
    {noreply,handle_cdr(State1#st{cdrs=[Cdr|Cdrs]})};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST=#st{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.
handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(R,_St=#st{callers=Callers})->  
    io:format("traffic terminate reason:~p~n",[R]),
    [sip_op:stop(OpPid)||#{oppid:=OpPid}<-Callers],
    stop.

% my utility function
recre()->
    F = fun(State)->
             {ok, reset_cdr_file(State)}
         end,
     act(?MODULE,F).
handle_cdr(State=#st{fd=_Handle,cdrs=Cdrs})->    
     BufSize=dbmanager:get_cdr_buffersize(),
     if length(Cdrs)>=BufSize-> 
         write_cdr(State),
         State#st{cdrs=[]};
    true->
         State
    end.
reset_cdr_file(State=#st{fd=Handle})->
    file:close(Handle),
    Date=erlang:localtime(),
    NewFn=?CDR_FILENAME_BASE++utility:d2s(Date,"","","_")++".txt",
    case file:read_file(NewFn) of
    {error,enoent}-> file:rename(?CDR_FILENAME_BASE, NewFn);
    {ok,_Bin}->
        case file:read_file(?CDR_FILENAME_BASE) of
            {error,enoent}->void;
            {ok,Bin1}-> file:write_file(NewFn,Bin1,[append])
        end
    end,
    {ok, NewHd} = file:open(?CDR_FILENAME_BASE, [append]),
    State#st{fd=NewHd}.
write_cdr(State=#st{cdrs=Cdrs,fd=Fd})->
    write_cdr(Cdrs,Fd).
write_cdr([],_Fd)-> void;
write_cdr(Cdrs,Fd)->
    LenList=get_sectionlenlist(),
    Fmt=string:join(["~"++integer_to_list(Len)++"s"||Len<-LenList],"")++"\n",
    Content=lists:flatten([io_lib:format(Fmt,get_cdr_values(Cdr))||Cdr<-Cdrs]),
    io:format(Fd,Content,[]).
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).
cast(Act)->my_server:cast(whereis(?MODULE),{act,Act}).
% my log functiong
spy_traffic(Caller,Callee,#{callee:=Callee0,starttime:=StartTime})->
    utility:log("spy.log","~p ~p ~p ~p ~p",[utility:ts(),Caller,Callee,Callee0,StartTime]).
traffic({_OpPid,CallMap})->traffic(CallMap);
traffic(#{hktime:=Hktime,caller:=Caller,callee:=Callee,starttime:=StartTime,newcaller:=NewCaller,newcallee:=NewCallee})->
    T_item=#traffic_item{hktime=Hktime,caller=Caller,callee=Callee,starttime=StartTime,endtime=utility:ts(),newcaller=NewCaller,newcallee=NewCallee},
    add_traffic(T_item);
traffic(_)-> void.
get_cdr_sectionlens()->
    [{companyid,10},{ver,2},{a,20},{x,20},{transid,20},{mode,7},{clientip,16},{node,20},{hktime,15},{caller,20},{callee,20},{newcaller,20},{newcallee,20},{reason,5},{starttime,15},{endtime,15}].
get_cdr_keys()->[ver|maps:keys(?CdrTemplate)--[ver]].
get_cdr_values(Cdr)->[maps:get(Key,Cdr)||Key<-get_cdr_keys()].
get_sectionlenlist()->
    Keys=get_cdr_keys(),
    [proplists:get_value(Key,get_cdr_sectionlens(),aaaa)||Key<-Keys].
write_cdr_keys()->    
    Keys=get_cdr_keys(),
    Lens=get_sectionlenlist(),
    KeyLens=[atom_to_list(Key)++"("++integer_to_list(Len)++")"||{Key,Len}<-lists:zip(Keys,Lens)],
    Fmt=string:join(["~"++integer_to_list(Len)++"s"||Len<-Lens],"")++"\n",
    Content=lists:flatten([io_lib:format(Fmt,KeyLens)]),
    file:write_file("cdr/cdr_readme.txt",Content).

