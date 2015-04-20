-module(my_process).
-compile(export_all).

-define(CHOOSE_INTERVAL, 15*1000*60).  % 15min
-record(state,{unknow}). 
 
%% APIs
start() ->
    my_server:start({local,?MODULE},?MODULE,[],[]).
		
%% callbacks
init([]) ->
    timer:send_interval(?CHOOSE_INTERVAL, choose_interval),
    {ok,#state{}}.
	
	
handle_call(_Call, _From, State) ->
    {noreply,State}.
    
handle_cast(_Msg, State) ->
    {noreply, State}.
	
handle_info(choose_interval,State) ->
    io:format("~nmy_process:choose_interval~n"),
    _New=wcg_disp:rechoose(),
%    io:format("~p:choose ~p~n",[time(),New]),
    {noreply, State};
handle_info(_Msg,State) ->
    {noreply, State}.

terminate(_Reason, _State) -> 
    ok.	
	
