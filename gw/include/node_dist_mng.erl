-module(node_dist_mng).
-compile(export_all).

addNode(NewNode,TableList) ->  
    io:format("New Node = ~p~n", [NewNode]),  
    RunningNodeList = mnesia:system_info(running_db_nodes),  
    io:format("-----------Adding Extra Node---------~n"),  
    addExtraNode(RunningNodeList, NewNode),  
    io:format("-----------Chang schema -> disc_copies---------~n"),  
    Rtn = mnesia:change_table_copy_type(schema, NewNode, disc_copies),  
    io:format("Rtn=~p~n", [Rtn]),  
    io:format("-----------Reboot Remote Node Mnesia---------~n"),  
    rpc:call(NewNode, mnesia, stop, []),  
    timer:sleep(1000),  
    rpc:call(NewNode, mnesia, start, []),  
    timer:sleep(1000),  
    io:format("-----------Adding Table List---------~n"),  
    addTableList(TableList, NewNode),  
    io:format("-----------Over All---------~n").  
  
addExtraNode([], _NewNode) ->  
    null;  
addExtraNode(_RunningNodeList = [Node | T], NewNode) ->  
    Rtn = rpc:call(Node, mnesia, change_config, [extra_db_nodes, [NewNode]]),  
    io:format("Node = ~p, Rtn=~p~n", [Node, Rtn]),  
    addExtraNode(T, NewNode).  
  
addTableList([], _NewNode) ->  
    null;  
addTableList(_TableList = [Table | T], NewNode) ->  
    Rtn = mnesia:add_table_copy(Table, NewNode, disc_copies),  
    io:format("Table = ~p, Rtn = ~p~n", [Table, Rtn]),  
    addTableList(T, NewNode). 
    
www_tables()->
    [lw_register].
add_wcg_node(Node)->    addNode(Node,www_tables()).
