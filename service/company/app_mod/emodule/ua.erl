-module(ua).
-compile(export_all).

-define(AppNode, 'service@10.32.3.38').
-define(AppMod, serviceapi).
-define(CardMod,card).

set_pass(Card,NewPass) ->
	case rpc:call(?AppNode,?CardMod,change_password,[Card,NewPass]) of
		{badrpc,_Reason} ->
			{auth_failed, "service unavailable"};
		ok -> ok
	end.

lookup_balance(Card,Pass) ->
	{ok,Seq} = my_server:call(dbsms, {op_incseq,Card}),		%% seq auto inc after 'get'
	Digest = digest([Seq, Card, Pass]),
	case rpc:call(?AppNode, ?AppMod, lookup_balance, [Seq, Card, Digest]) of
		{auth_failed,{seqno_wrong,NSeq}} ->
			my_server:call(dbsms,{op_setseq,Card,NSeq+1}),
			NDigest = digest([NSeq, Card, Pass]),
			rpc:call(?AppNode, ?AppMod, lookup_balance, [NSeq, Card, NDigest]);
		{badrpc, _Reason} ->
			{auth_failed, "service unavailable"};
		R ->
			R
	end.

move_balance(ToCard,FromCard) ->
	case rpc:call(?AppNode,?CardMod,move,[ToCard,FromCard]) of
		{value,NewBal} ->
			{value,NewBal};
		{badrpc, _} ->
			{auth_failed, "service unavailable"}
	end.

callonce(Card,Pass,NO1,NO2) ->
	{ok,Seq} = my_server:call(dbsms, {op_incseq,Card}),
	Digest = digest([Seq,Card,NO1,NO2,Pass]),
	case rpc:call(?AppNode, ?AppMod, call,[Seq,Card,NO1,NO2,Digest]) of
		{auth_failed,{seqno_wrong,NSeq}} ->
			my_server:call(dbsms,{op_setseq,Card,NSeq+1}),
			NDigest = digest([NSeq,Card,NO1,NO2,Pass]),
			rpc:call(?AppNode, ?AppMod, call,[NSeq,Card,NO1,NO2,NDigest]);
		{badrpc, _Reason} ->
			{auth_failed, "service unavailable"};
		R ->
			R
	end.

call(Card,Pass,NO1,NO2) ->
	case callonce(Card,Pass,NO1,NO2) of
		{call_ok,_}=R ->
			spawn(fun()->callguard(Card,{1,{Card,NO1,NO2,Pass}}) end),
			R;
		R ->
			R
	end.

callagain({3, _}) ->
	ok;
callagain({N, {Card,NO1,NO2,Pass}}) ->
	case callonce(Card,Pass,NO1,NO2) of
		{call_ok,_} ->
			spawn(fun()->callguard(Card,{N+1,{Card,NO1,NO2,Pass}}) end);
		_ ->
			ok
	end.

callguard(Card,Param) ->
	timer:send_after(1010,timeout),
	callguard(0,Card,Param,[]).

callguard(60,_,Param,Res) ->
	llog("call guard ~p",[Res]),
	case lists:member(ready,Res) of
		true ->
			ok;
		false ->
			callagain(Param)
	end;
callguard(N,Card,Param,Res) ->
	receive
		timeout -> ok
	end,
	case rpc:call(?AppNode,operator,get_call_status, [Card]) of
		session_not_exist ->
			callguard(60,Card,Param,[session_not_exist|Res]);
		{session_status,{_,ready},_} ->
			callguard(60,Card,Param,[ready|Res]);
		{session_status,{_,CallSt},_} ->
			timer:send_after(1010,timeout),
			callguard(N+1,Card,Param,[CallSt|Res])
	end.

% ----------------------------------
digest(X) ->
	hex2bcd(erlang:md5([integer_to_list(hd(X))|tl(X)])).

hex2bcd(Bin) ->
	hex2bcd(Bin, "").
	
hex2bcd(<<>>, Res) ->
	Res;
hex2bcd(<<Int:8, Rest/binary>>, Res) ->
	hex2bcd(Rest, Res++int2bcd(Int)).
	
int2bcd(Int) ->
	R = Int rem 16,
	D = Int div 16,
	[tobcd(D),tobcd(R)].
	
tobcd(X) when X >= 0 andalso X =< 9 -> X + $0;
tobcd(X) -> X - 10 + $a.

llog(Txt) ->
    llog ! {self(), Txt}.
llog(Format, Args) ->
    llog ! {self(), Format, Args}.
    

% ----------------------------------
uarouter() -> {ua_router, 'sip@uarouter.com'}.
monitor() -> {ua_monitor, 'sip@uarouter.com'}.

send(Msg) ->
	uarouter() ! Msg.

rpc(Msg) ->
	uarouter() ! Msg,
	receive
		R -> R
	after 5000 ->
		timeout
	end.
