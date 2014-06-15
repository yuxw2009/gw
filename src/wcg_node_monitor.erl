-module(wcg_node_monitor).
-export([start/0, get_count/0, get_node/0]).

get_count() ->
    ?MODULE ! {get_count, self()},
	receive
	    {value, R} -> R
		after 2000 -> timeout
	end.
	
get_node() ->
    ?MODULE ! {get_node, self()},
	receive
	    {value, R} -> R
		after 2000 -> timeout
	end.

start() ->
    COOKIE = atom_to_list(erlang:get_cookie()),
	[_,AtNode] = string:tokens(atom_to_list(node()),"@"),
	NodeName = "wcg@"++AtNode,
	Cmd = "erl -name "++NodeName++" -setcookie "++COOKIE++" -pa ../ebin +K true -s voip -detached",
	register(?MODULE, spawn(fun() -> init(list_to_atom(NodeName), Cmd) end)).

init(Node, Cmd) ->
    monitor_node(Node, true),
	loop(Node, Cmd, 0).
	
loop(Node, Cmd, Count) ->
    receive
	    {nodedown, Node} ->
	             monitor_log(Node),
			os:cmd(Cmd),
			timer:send_after(5000, monitor_it),
			loop(Node, Cmd, Count+1);
		{get_count, From} ->
		    From ! {value, Count},
			loop(Node, Cmd, Count);
	    {get_node, From} ->
		    From ! {value, Node},
			loop(Node, Cmd, Count);
		monitor_it ->
		    monitor_node(Node,true),
			loop(Node, Cmd, Count)
	end.
	
monitor_log(Node)->
	{ok, Handle} = file:open("monitor.log", [append]),
	io:fwrite(Handle, llog:ts() ++ " ~p down \n", [Node]),
	file:close(Handle).
	
    
