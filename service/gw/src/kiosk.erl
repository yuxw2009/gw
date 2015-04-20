-module(kiosk).
-compile(export_all).

-define(VOIPNODE, "wcg").

kiosk() ->
	COOKIE = atom_to_list(erlang:get_cookie()),
	[_,AtNode] = string:tokens(atom_to_list(node()),"@"),
	NodeName = ?VOIPNODE++"@"++AtNode,
	Line = "erl -name "++NodeName++" -setcookie "++COOKIE++" -pa ./ebin -s voip -detached",
%	Line = "yaws --conf yaws.conf --name "++NodeName++" --erlarg \"-setcookie "++COOKIE++"\" --daemon",
	os:cmd(Line),
	Node = list_to_atom(NodeName),
	timer:send_after(1000, {monitor,Node}),
	loop(Node,Line,0).

loop(Node,Cmd,Ver) ->
	receive
		{nodedown, Node} ->
			io:format("~p restarted.~n",[Node]),
			os:cmd(Cmd),
			timer:send_after(1000, {monitor,Node}),
			loop(Node,Cmd,Ver+1);
		{monitor,_Node} ->
			monitor_node(Node,true),
			loop(Node,Cmd,Ver);
		{ver,From} ->
			From ! {ok,Ver},
			loop(Node,Cmd,Ver);
		{stop,xyz} ->
			monitor_node(Node,false),
			rpc:call(Node,erlang,halt,[]),
			io:format("~p stopped.~n",[Node]),
			ok;
		Msg ->
			io:format("unknow ~p.~n",[Msg]),
			loop(Node,Cmd,Ver)
	end.

% ----------------------------------
start() ->
	Pid = spawn(fun() -> kiosk() end),
	register(kiosk, Pid).	