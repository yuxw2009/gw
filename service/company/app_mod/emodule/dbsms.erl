-module(dbsms).
-compile(export_all).

-define(UserPassFile, "./data/userpass.conf").
-define(RPTLog, "./data/report.log").

-record(u_state, {
	dts,
	seql
}).

init([PUAPs]) ->
	UPS = ets:new(ups, [ordered_set]),
	ets:insert(UPS, PUAPs),
	llog("dbsms open ets: ~p", [UPS]),
	{ok, #u_state{dts=UPS,seql=[]}}.

handle_call(reload_ups, _From, #u_state{dts=UPS}=ST) ->
	case file:consult(?UserPassFile) of
		{ok, Cont} ->
			true = ets:delete_all_objects(UPS),
			ets:insert(UPS, Cont),
			llog("ets ~p reloaded.", [UPS]),
			ok;
		{error, _X} ->
			llog("error read user-pass file."),
			error
	end,
	{reply, ok, ST};
	
handle_call({sms_logon, Aphno}, _From, #u_state{dts=UPS}=ST) ->
	Reply = userpass(Aphno, UPS),
	{reply, Reply, ST};
handle_call({op_incseq, Card}, _From, #u_state{seql=SeqL}=ST) ->
	{Seq,NSeqL} = case lists:keysearch(Card,1,SeqL) of
			{value, {_,N}} ->
				{N,lists:keyreplace(Card,1,SeqL,{Card,N+1})};
			false -> {1,SeqL}
		end,
	{reply,{ok, Seq},ST#u_state{seql=NSeqL}};
handle_call({op_setseq, Card, NSeq}, _From, #u_state{seql=SeqL}=ST) ->
	NSeqL = case lists:keymember(Card,1,SeqL) of
			true -> lists:keyreplace(Card,1,SeqL,{Card,NSeq});
			false -> [{Card,NSeq}|SeqL]
		end,
	{reply, ok, ST#u_state{seql=NSeqL}};
handle_call({sms_bind, Aphno, Seq, Card, Pass, Name}, _From, #u_state{dts=UPS}=ST) ->
	Res = addbind(UPS, Aphno, Seq, Card, Pass, Name),
	dumpuser(UPS),
	{reply, {ok, Res}, ST};
handle_call({sms_share, Aphno,Card,Pass,Nums},_From, #u_state{dts=UPS}=ST) ->
	R=addshare(UPS, Aphno,Card,Pass,Nums,[]),
        dumpuser(UPS),
	{reply, {ok,R}, ST};
handle_call({sms_unbind, Aphno}, _From, #u_state{dts=UPS}=ST) ->
	delbind(UPS, [Aphno]),
	dumpuser(UPS),
	{reply, ok, ST};
handle_call({sms_checkcard, Card},_From,#u_state{dts=UPS}=ST) ->
	R=findcard(UPS,Card),
	{reply,{ok,R},ST};
handle_call(dump_user, _From, #u_state{dts=UPS}=ST) ->
	dumpuser(UPS),
	{reply, {ok, ets:tab2list(UPS)}, ST};
	
handle_call({get_info, Company},_From,ST) ->
	{ok, Terms} = file:consult(?RPTLog),
	Dat = case Company of
			"" ->
				Terms;
			_ ->
				[{C2,DT,IP,Len,Txt,Report}||{C2,DT,IP,Len,Txt,Report}<-Terms,C2==Company]
		end,
	{reply, {ok, Dat},ST}.

handle_info({report, IP, Len, Txt}, ST) ->
	logreq(IP,"REPORT",Len,Txt,{noreply,null}),
	{noreply,ST};
handle_info({unparsed_req,IP,Company,Len,Txt}, ST) ->
	logreq(IP,Company,Len,Txt,{noreply,null}),
	{noreply,ST};
handle_info({gw_req,IP,Company,Aphno,Txt,Reply}, ST) ->
	logreq(IP,Company,Aphno,Txt,Reply),
	{noreply,ST};
handle_info({gw_req2,IP,Company,Aphno,{_RDate,_RTime,_RTZ},Txt,Reply}, ST) ->
	logreq(IP,Company,Aphno,Txt,Reply),
	{noreply,ST}.

handle_cast(stop, _ST) ->
	{stop, normal, []}.
	
terminate(Reason, _State) ->
	llog("db server stopped ~p", [Reason]),
	ok.

% ----------------------------------
% param: string,string,string,string,{atom,atom}
logreq(IP,Company,Idx,Cont,{Rep,RepMsg}) ->
	{ok, FH} = file:open(?RPTLog, [append]),
	io:fwrite(FH, "{~p,{~p,~p},~p, ~p, ~p,{~p,~p}}.\n", [Company,date(),time(),IP, Idx,Cont,Rep,RepMsg]),
	file:close(FH).
	
userpass(Phno, UPs) ->
	case ets:lookup(UPs, Phno) of
		[Dat] ->
			{ok, Dat};
		[] ->
			{err, "inv_phno"}
	end.

login_user(User, Pass) ->
	case ua:rpc({register, self(), User, Pass}) of
		timeout ->
			register_failed;
		R ->
			R
	end.

dumpuser(ETS) ->
	{ok, Handle}= file:open(?UserPassFile, [write]),
	dumpuser(ets:tab2list(ETS), Handle),
	file:close(Handle).

dumpuser([], _) -> ok;
dumpuser([{Phno, No, Seq, Name, Pass}|T], Handle) ->
	io:fwrite(Handle, "{~p, ~p, ~p, ~p, ~p}.\r\n", [Phno, No, Seq, Name, Pass]),
	dumpuser(T, Handle).

addbind(ETS, Aphno, Seq, Card, Pass, Name) ->
	delbind(ETS,findcard(ETS,Card)),
	ets:insert(ETS, {Aphno, Card, Seq, Name, Pass}),
	ok.

findcard(ETS,Card) ->
	% match result = [] or [[Phon1],[Phon2],...]
	lists:append(ets:match(ETS, {'$0', Card,'_','_','_'})).

delbind(_,[]) ->
	ok;
delbind(ETS, [Aphno|T]) ->
	ets:delete(ETS, Aphno),
	delbind(ETS,T).

addshare(_, _,_,_,[],R) ->
	lists:reverse(R);
addshare(UPS, Aphno,Card,Pass,[Phno|T],R) ->
	case ets:lookup(UPS, Phno) of
		[{Phno, _, _, _, _}] ->
			addshare(UPS,Aphno,Card,Pass,T,R);
		[] ->
			ets:insert(UPS, {Phno,Card,1,Aphno,Pass}),
			addshare(UPS,Aphno,Card,Pass,T,[Phno|R])
	end.
	
ts() ->
	dt2str(date(),time()).
	
dt2str({Y,Mo,D}, {H,Mi,S}) ->
	xt:int2(Y) ++ "/" ++ xt:int2(Mo) ++ "/" ++ xt:int2(D) ++ "," ++ xt:int2(H) ++ ":" ++ xt:int2(Mi) ++ ":" ++ xt:int2(S).

% ----------------------------------
llog(Txt) ->
    llog ! {self(), Txt}.
llog(Format, Args) ->
    llog ! {self(), Format, Args}.
    
start() ->
	llog:start(),
	io:format("start little log.~n"),
	KPRs = case file:consult(?UserPassFile) of
			{ok, Cont} ->
				Cont;
			{error, _X} ->
				llog("error read user-pass file."),
				[]
		end,
	{ok, Dbs} = my_server:start(dbsms, [KPRs], []),	% ets opened in dbs
	io:format("start db sms.~n"),
	register(dbsms, Dbs).
	
stop() ->
    llog ! stop,
	my_server:cast(dbsms, stop).
