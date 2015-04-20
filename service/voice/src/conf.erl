-module(conf).
-compile(export_all).

-include("siprecords.hrl").
-include("sipsocket.hrl").
-include("debug.hrl").
-record(state,{status,  conf_name, ms_uas=[], tref}).

-behaviour(gen_server).
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).

%% external API
create(ConfInfos)->
    conf_mgr:create_conf(ConfInfos).
    
join_conf(Confname, UserInfo)->
    act_conf(Confname, fun(Pid)-> Pid ! {join, UserInfo} end).

destroy(Confname) -> 
    act_conf(Confname, fun(Pid)-> Pid ! stop end).

get_ms(Confname)->
    case act_conf(Confname, fun(Pid)-> Pid ! {get_ms, self()} end) of
    ok->
        receive 
        {get_ms, Result}-> io:format("ms:~n~p~n", [Result])
        after 2000->  timeout
        end;
    Fail-> Fail
    end.
    
start(Owner, ConfInfos = [Confname|_]) ->
    {ok, Conf} = gen_server:start({local, list_to_atom(Confname)}, ?MODULE, {Owner, ConfInfos}, []),
    Conf.

init({_Owner,[ConfName, _MeetingPid | _]}) ->
    {ok, Tr} = timer:send_after(2000, timeout),
    {ok, #state{status=creating,conf_name=ConfName, tref=Tr}}.

%% StateName: creating | created
handle_info({join, _UserInfo},State=#state{status = creating, conf_name=Confname}) ->
    ?PRINT_INFO("ua join conf ~p, when conf is not created~n", [Confname]),
    {noreply, State};
handle_info({join, UserInfo=[_Phone |_]},State=#state{status = created, conf_name=Confname,ms_uas=List}) ->
    MsUa = ms_ua:start_monitor(UserInfo),
    ms_ua:join_conf(MsUa, Confname),
    {noreply, State#state{ms_uas=[MsUa |List]}};
handle_info({join, MsUa},State=#state{status = created, conf_name=Confname,ms_uas=List})  when is_pid(MsUa)->
    monitor(process, MsUa),
    ms_ua:join_conf(MsUa, Confname),
    {noreply, State#state{ms_uas=[MsUa |List]}};
handle_info({get_ms, From},State=#state{ms_uas=List}) ->
    From ! {get_ms, List},
    {noreply, State};

handle_info({'DOWN', _Ref, process, FromPid, Reason},State=#state{ms_uas=List}) ->
    ?PRINT_INFO("conf ua is over, reason is ~p~n", [Reason]),
    {noreply, State#state{ms_uas=lists:delete(FromPid, List)}};
    
handle_info(stop,State=#state{}) ->
    {stop, normal, State};
handle_info(timeout,State=#state{}) ->
    {stop, conf_wait_200_timeout, State};
handle_info({get_status, From},State=#state{status=Status}) ->
    From ! {get_status_result, Status},
    {noreply, State};
handle_info({branch_result,_,_,_,#response{status=200,body=_SDP}},State=#state{status=creating, tref=TR}) ->
    timer:cancel(TR),
    {noreply, State#state{status=created}};
handle_info(Unhandeld,State=#state{status=Status}) ->
    ?DEBUG_INFO("receive unhandled message: ~p STATE: ~p~n",[Unhandeld,Status]),
    {noreply, State}.

handle_cast(_Msg, State)->
    {noreply, State}.

handle_call(_Msg, _From, State)->
    {reply, ok, State}.

code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(Reason, #state{conf_name=Confname, ms_uas=Ms_uas, tref=TR})->
    timer:cancel(TR),
    conf_mgr:destroy_conf(Confname),
    [ms_ua:stop(MU) || MU<-Ms_uas],
    Reason.

%% internal function	
act_conf(Confname, Act)->
    case conf_pid(Confname) of
        undefined-> {fail,conf_not_existed};
        Pid-> 
            Act(Pid),
            ok
    end.
    
msip() ->   "10.32.3.47".  %"10.61.59.2".   10.32.3.53

ms_addr(Phone)->
    user_host2url(Phone, msip()).
    
user_host2url(User, Host)->
    [Addr] = contact:parse(["<sip:"++User++"@"++Host++">"]),
    Addr.

conf_pid(Confname)->
    PName = list_to_atom(Confname),
    Pid = whereis(PName),
    case is_pid(Pid) andalso is_process_alive(Pid) of
        true-> Pid;
        _->  undefined
    end.

