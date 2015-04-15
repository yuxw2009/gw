-module(ws_callback).
-compile(export_all).

-define(UAS, {uas, 'wrtc@10.32.3.52'}).

% Type :: text|binary
% Data :: binary()
% HandlerResult :: {reply, {Type, Data}}
%                | noreply
%                | {close, Reason}
handle_message({text, <<"client-connected">>}) ->
	?UAS ! {connected, self()},
	noreply;
handle_message({text, <<"client-disconnected">>}) ->
	?UAS ! {disconnect,self()},
	{close,normal};
handle_message({text, Data}) ->
	Connect = <<"client-connected=">>,
	Lc = size(Connect),
	Disconn = <<"client-disconnected=">>,
	Ld = size(Disconn),
	case Data of
		<<Connect:Lc/binary,UUID/binary>> ->
			?UAS ! {binduser, self(),binary_to_list(UUID)},
			noreply;
		<<Disconn:Ld/binary,_/binary>> ->
			?UAS ! {disconnect, self()},
			{close,normal};
		_ ->
			?UAS ! {text, self(), Data},
			noreply
	end;
handle_message({close,_,_Bin}) ->
	?UAS ! {disconnect,self()},
	{close,normal};
handle_message(Msg) ->
	io:format("ws rcv:~p~n",[Msg]),
	noreply.