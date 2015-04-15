-module(sdemo).
-compile(export_all).

-include("sdp.hrl").
-include("desc.hrl").

-define(STUNV2, "2").
-define(CC_RTP,1).		% component-id of candidate
-define(CC_RTCP,2).

-record(st, {
	fsm,
	rlyr,
	proto,
	session,
	caller,
	called,
	o_sdp,
	a_sdp,
	o_sdp2,
	a_sdp2
}).

init([Proto]) ->
	{ok,#st{fsm=idle,proto=Proto}}.

handle_call({waiting,Uid}, _From, #st{fsm=idle,proto=Proto,rlyr=undefined}=ST) ->
	Session = integer_to_list(Uid),
	Rlyr = swap:create_relayer(Proto),
	{reply,{failure,waiting},ST#st{fsm=waiting,rlyr=Rlyr,session=Session,called=Uid}};
handle_call({waiting,Uid}, _From, #st{fsm=idle}=ST) ->
	Session = integer_to_list(Uid),
	{reply,{failure,waiting},ST#st{fsm=waiting,session=Session,called=Uid}};
handle_call({waiting,Uid}, _From, #st{fsm=waiting,called=Uid}=ST) ->
	{reply,{failure,waiting},ST};
handle_call({waiting,Uid}, _From, #st{fsm=offer,session=Session,called=Uid,o_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST};
handle_call({answer,Uid,Sdp}, _From, #st{fsm=offer,session=Session,rlyr=Rlyr,called=Uid}=ST) ->
    Sdp2 = swap:update_answer(Rlyr,Sdp),
	{reply,{successful,Session},ST#st{fsm=answer,a_sdp=Sdp,a_sdp2=Sdp2}};

handle_call({offer,Uid,Sdp}, _From, #st{fsm=waiting,session=Session,rlyr=Rlyr}=ST) ->
    Sdp2 = swap:update_offer(Rlyr,Sdp),
	{reply,{successful,Session},ST#st{fsm=offer,caller=Uid,o_sdp=Sdp,o_sdp2=Sdp2}};
handle_call({polling,Session}, _From, #st{fsm=answer,session=Session,a_sdp2=Sdp}=ST) ->
	{reply,{successful,Session,Sdp},ST#st{fsm=busy}};
handle_call({release,Session}, _From, #st{fsm=FSM,session=Session,rlyr=Rlyr}=ST) ->
	io:format("~p released @ ~p.~n",[Rlyr,FSM]),
	swap:destroy_relayer(Rlyr),
	{reply,successful,ST#st{fsm=idle,rlyr=undefined}};

handle_call(get_info,_From,ST) ->
	{reply,ST,ST};
handle_call(Cmd,_From,ST) ->
	io:format("unavailable cmd: ~p @ ~p.~n",[Cmd,ST]),
	{reply,{failure,unprocessed},ST}.

terminate(_,ST) ->
	io:format("left_2_right manager stopped @~p~n",[ST]),
	ok.

% ----------------------------------
% ----------------------------------
start() ->
	case whereis(my_timer) of
		undefined -> my_timer:start();
		_ -> pass
	end,
	{ok,_Pid} = my_server:start({local,lrman},?MODULE,[avscfg:get(relay_proto)],[]),
	relayudp:start(),
	relay443:start(),
	ok.

go() ->
	my_timer:start(),
	start().
%
% ----------------------------------
%	Interfaces of manager
%	rpc:called from yaws
% ----------------------------------
%
offer(Uuid, Sdp) when is_integer(Uuid) ->
	case my_server:call(lrman,{offer,Uuid,Sdp}) of
		{successful,Session} -> {ok,Session};
		{failure,Reason} -> {failed, Reason}
	end.
polling(Session) when is_list(Session) ->
	case my_server:call(lrman,{polling,Session}) of
		{successful,Session,AnswerSDP} -> {ok,Session,AnswerSDP};
		{failure,Reason} -> {failed, Reason}
	end.
release(Session) when is_list(Session) ->
	my_server:call(lrman,{release,Session}),
	ok.
	
waiting(Uuid) when is_integer(Uuid) ->
	case my_server:call(lrman,{waiting,Uuid}) of
		{successful,Session,OfferSDP} -> {ok,Session,OfferSDP};
		{failure,Reason} -> {failed, Reason}
	end.
answer(Uuid, Sdp) when is_integer(Uuid) ->
	case my_server:call(lrman,{answer,Uuid,Sdp}) of
		{successful,Session} -> {ok,Session};
		{failure,Reason} -> {failed, Reason}
	end.
