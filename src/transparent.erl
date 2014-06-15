-module(transparent).
-compile(export_all).

-record(ust,{
	wspid,
	sdp,
	rsdp,
	label,
	candidate,
	bye
}).

start() ->
	Pid = spawn(fun()->loop(#ust{},#ust{}) end),
	register(confs,Pid).
stop() ->
	confs ! stop.	

loop(U1,U2) ->
	receive
		{connected,Pid} ->
			if
				is_pid(U1#ust.wspid) ->
					loop(U1,U2#ust{wspid=Pid});
				true ->
					loop(U1#ust{wspid=Pid},U2)
			end;
		{disconnect,Pid} ->
			if
				U1#ust.wspid==Pid ->
					loop(U1#ust{wspid=null},U2);
				U2#ust.wspid==Pid ->
					loop(U1,U2#ust{wspid=null});
				true ->
					io:format("null pid disconnected.~n"),
					loop(U1,U2)
			end;
		{text,Pid,Bin} ->
			{ok,{obj,[{"type",_}|_JMsg]=JSON},_}=rfc4627:decode(Bin),
			{NU1,NU2} = if
					Pid==U1#ust.wspid ->
						send2ws(2,U2,JSON),
						{save4(U1,JSON),U2};
					Pid==U2#ust.wspid ->
						send2ws(1,U1,JSON),
						{U1,save4(U2,JSON)};
					true ->
						io:format("dropped msg ~p~n",[JSON]),
						{U1,U2}
				end,
			loop(NU1,NU2);
		list ->
			io:format("~p~n~p~n",[U1,U2]),
			loop(U1,U2);
		stop ->
			ok;
		flush ->
			loop(#ust{},#ust{});
		Msg ->
			io:format("unknow message ~p~n", [Msg]),
			loop(U1,U2)
	end.

send2ws(_,U,[{"type",<<"offer">>},{"sdp",SDP}]) ->
	io:format("offer from ~p~n",[U#ust.wspid]),
	io:format("~p~n",[SDP]),
	JOut = rfc4627:encode({obj,[{type,<<"offer">>},{sdp,SDP}]}),
	send2U(U,JOut);
send2ws(_,U,[{"type",<<"candidate">>},{"label",Label},{"candidate",Candid}]) ->
	io:format("candidate from ~p~n",[U#ust.wspid]),
	io:format("~p~n~p~n",[Label,Candid]),
	JOut = rfc4627:encode({obj,[{type,<<"candidate">>},{label,Label},{candidate,Candid}]}),
	send2U(U,JOut);
send2ws(_,U,[{"type",<<"answer">>},{"sdp",SDP}]) ->
	io:format("answer from ~p~n",[U#ust.wspid]),
	io:format("~p~n",[SDP]),
	JOut = rfc4627:encode({obj,[{type,<<"answer">>},{sdp,SDP}]}),
	send2U(U,JOut);
send2ws(_,U,[{"type",<<"bye">>},_]) ->
	io:format("bye from ~p~n",[U#ust.wspid]),
	JOut = rfc4627:encode({obj,[{type,<<"bye">>},{reason,<<"hangup">>}]}),
	send2U(U,JOut).
	
save4(U,[{"type",<<"offer">>},{"sdp",Bin}]) ->
	U#ust{sdp=Bin};
save4(U,[{"type",<<"candidate">>},{"label",Label},{"candidate",Candid}]) ->
	U#ust{label=Label,candidate=Candid};
save4(U,[{"type",<<"answer">>},{"sdp",SDP}]) ->
	U#ust{rsdp=SDP};
save4(U,[{"type",<<"bye">>},_]) ->
	U#ust{bye=true}.

send2U(U,JOut) ->
	yaws_api:websocket_send(U#ust.wspid, {text, list_to_binary(JOut)}).
	