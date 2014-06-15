-module(app_manager).

-export([start/0, register_app/1, lookup_app_pid/1, get_app_count/0, get_random32/0]).
-export([init/1, handle_cast/2, handle_call/3, handle_info/2, terminate/2]).

-record(state,{app_id=0, app_count=0, app_tab, app_tab_reverse}). 

%% APIs
start() ->
    my_server:start({local,?MODULE},?MODULE,[],[]).
		
register_app(AppPid) when is_pid(AppPid)->
    my_server:call(?MODULE, {register_app, AppPid}).    

lookup_app_pid(AppId) ->
    my_server:call(?MODULE, {lookup_app_pid, AppId}).	

get_app_count() ->
    my_server:call(?MODULE, get_app_count).	
	
get_random32() ->
    my_server:call(?MODULE, get_random32).	
	
%% callbacks
init([]) ->
	Tab  = ets:new(?MODULE,[set,protected,{keypos,1}]),
	RTab = ets:new(?MODULE,[set,protected,{keypos,1}]),
    {ok,#state{app_count=0, app_tab=Tab, app_tab_reverse=RTab}}.
	
	
handle_call({register_app, AppPid}, _, 
                 State=#state{app_id=Aid,app_count=CS,app_tab=AT,app_tab_reverse=ATR}) ->
    case ets:lookup(ATR, AppPid) of
	    [] ->
	        NewState=State#state{app_id=Aid+1,app_count=CS+1},
			ets:insert(AT, {Aid, AppPid}),
			ets:insert(ATR,{AppPid, Aid}),
			erlang:monitor(process, AppPid),
	        {reply, {value, Aid}, NewState};
        _ ->
		    {reply, {error, pid_alread_exists}, State}
    end;		
handle_call({lookup_app_pid, AppId}, _, State=#state{app_tab=AT}) ->
    case ets:lookup(AT, AppId) of
        [{AppId, AppPid}] ->
		    {reply, {value, AppPid}, State};
		_ ->
		    {reply, {error, not_found}, State}
	end;
handle_call(get_app_count, _, State=#state{app_count=CS}) ->
    {reply, {value, CS}, State};
handle_call(get_random32, _, State) ->
    {reply, {value, random:uniform(16#FFFFFF)}, State};
handle_call(_Call, _From, State) ->
    {noreply,State}.
    
handle_cast(_Msg, State) ->
    {noreply, State}.
	
handle_info({'DOWN', _Ref, process, AppPid, _Reason},State=#state{app_count=CS,app_tab=AT,app_tab_reverse=ATR})->
    case ets:lookup(ATR,AppPid) of
	    [{AppPid, AppId}] ->
		    ets:delete(AT,AppId),
			ets:delete(ATR,AppPid),
			{noreply, State#state{app_count=CS-1}};
		_ ->
		    {noreply, State}
    end;        
handle_info(_Msg,State) ->
    {noreply, State}.

terminate(_Reason, _State) -> 
    ok.	
	