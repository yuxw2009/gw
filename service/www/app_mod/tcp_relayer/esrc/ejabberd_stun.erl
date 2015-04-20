-module(ejabberd_stun).

%% API
-export([start/2,udp_recv/4,udp_recv2/4,bindreq/4]).

%% gen_fsm callbacks
-export([init/1,
	 handle_info/3,
	 terminate/3]).

%% gen_fsm states
-export([session_established/2]).

-include("log.hrl").
-include("stun.hrl").

-define(MAX_BUF_SIZE, 4*1024). %% 4kb

-record(state, {sock,
		peer,
		buf = <<>>}).

%%====================================================================
%% API
%%====================================================================
start(Sock,Peer) ->
    gen_fsm:start(?MODULE, [Sock,Peer], []).

udp_recv(Sock, Addr, Port, Data) ->
    case stun_codec:decode(Data) of
	{ok, Msg, <<>>} ->
	    case process(Addr, Port, Msg) of
		RespMsg when is_record(RespMsg, stun) ->
		    Data1 = stun_codec:encode(RespMsg#stun{'USERNAME'=Msg#stun.'USERNAME'}),
		    gen_udp:send(Sock, Addr, Port, Data1),
		    ok;
		response ->
			ok;
		_ ->
		    pass
	    end;
	_ ->
	    pass
    end.
    
udp_recv2(Sock, Addr, Port, Data) ->
    case stun_codec:decode(Data) of
	{ok, Msg, <<>>} ->
	    case process(Addr, Port, Msg) of
		RespMsg when is_record(RespMsg, stun) ->
		    Data1 = stun_codec:encode(RespMsg#stun{'USERNAME'=Msg#stun.'USERNAME'}),
		    gen_udp:send(Sock, Addr, Port, Data1),
		    {ok,Msg#stun.'USERNAME'};
		_ ->
		    pass
	    end;
	_ ->
	    pass
    end.

bindreq(Sock, Addr, Port, UserName) ->
    Data1 = stun_codec:encode(#stun{class = request,
    								method = ?STUN_METHOD_BINDING,
    								trid = random:uniform(1 bsl 96),
    								'USERNAME' = UserName}),
    gen_udp:send(Sock, Addr, Port, Data1),
    ok.
%%====================================================================
%% gen_fsm callbacks
%%====================================================================
init([Sock,Addr]) ->
    State = #state{sock = Sock, peer = Addr},
    {ok, session_established, State}.

session_established(Msg, State) when is_record(Msg, stun) ->
    {Addr, Port} = State#state.peer,
    case process(Addr, Port, Msg) of
	Resp when is_record(Resp, stun) ->
	    Data = stun_codec:encode(Resp);
%	    (State#state.sock_mod):send(State#state.sock, Data);
	_ ->
	    ok
    end,
    {next_state, session_established, State};
session_established(Event, State) ->
    ?PRINT("unexpected event in session_established: ~p", [Event]),
    {next_state, session_established, State}.

handle_info(Info, StateName, State) ->
    ?PRINT("unexpected info: ~p", [Info]),
    {next_state, StateName, State}.

terminate(_Reason, _StateName, State) ->
    ok.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
process(Addr, Port, #stun{class = request, unsupported = []} = Msg) ->
    Resp = prepare_response(Msg),
    if Msg#stun.method == ?STUN_METHOD_BINDING ->
		    Resp#stun{class = response,'MAPPED-ADDRESS' = {Addr, Port}};
    true ->
	    Resp#stun{class = error,
		      'ERROR-CODE' = {405, <<"Method Not Allowed">>}}
    end;
process(_Addr, _Port, #stun{class = request} = Msg) ->
    Resp = prepare_response(Msg),
    Resp#stun{class = error,
	      'UNKNOWN-ATTRIBUTES' = Msg#stun.unsupported,
	      'ERROR-CODE' = {420, stun_codec:reason(420)}};
process(_Addr, _Port, #stun{class = response} = Msg) ->
	response;
process(_Addr, _Port, _Msg) ->
    pass.

prepare_response(Msg) ->
    Version = list_to_binary("ejabberd " ++ ?VERSION),
    #stun{method = Msg#stun.method,
	  magic = Msg#stun.magic,
	  trid = Msg#stun.trid}.

process_data(NextStateName, #state{buf = Buf} = State, Data) ->
    NewBuf = <<Buf/binary, Data/binary>>,
    case stun_codec:decode(NewBuf) of
	{ok, Msg, Tail} ->
	    gen_fsm:send_event(self(), Msg),
	    process_data(NextStateName, State#state{buf = <<>>}, Tail);
	empty ->
	    NewState = State#state{buf = <<>>},
	    {next_state, NextStateName, NewState};
	more when size(NewBuf) < ?MAX_BUF_SIZE ->
	    NewState = State#state{buf = NewBuf},
	    {next_state, NextStateName, NewState};
	_ ->
	    {stop, normal, State}
    end.