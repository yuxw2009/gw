-module(meeting_yaws).

-compile(export_all).

-behaviour(gen_server).
-include("debug.hrl").
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).

-record(state, {session, phones=["","","","","",""]}).

start(UUID)->
    gen_server:start({local, UUID}, ?MODULE, [], []).

accept(UUID, Phones)->
%    ?PRINT_INFO("uuid: ~p  accept: phones:~p", [UUID, Phones]),
    case whereis(UUID) of
    undefined->  
        start(UUID),
        lists:duplicate(6, "");
    _->
        gen_server:call(UUID, {accept, Phones})
    end.
    
init([])->
    {ok, #state{}}.

handle_call({accept, []}, _From, State=#state{phones=Ps})->
    {reply, Ps, State};
    
handle_call({accept, L}, _From, State=#state{})->
    NewPs = [P || {_,P} <- L, P=/=""],
    if 
        NewPs =/= []->
            operator:conf_test(NewPs);
        true->
            void
    end,
    NewPs1 = NewPs++lists:duplicate(max(6-length(NewPs), 0), ""),
    {reply, NewPs1, State#state{phones=NewPs1}};
    
handle_call(_Msg, _From, State)->
    {reply, ok, State}.

handle_cast(_Msg, State)->
    {noreply, State}.

handle_info({ack, UUID, SessionPid}, State) ->
    {noreply, State#state{session=SessionPid}};

handle_info(_Info, State=#state{}) ->
    {noreply, State}.    

code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(_Reason, #state{})->
    stop.

