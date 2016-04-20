-module(node_dist_mng).
-compile(export_all).

addNode(NewNode) ->  
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
    addTableList(NewNode),  
    io:format("-----------Over All---------~n").  
  
addExtraNode([], _NewNode) ->  
    null;  
addExtraNode(_RunningNodeList = [Node | T], NewNode) ->  
    Rtn = rpc:call(Node, mnesia, change_config, [extra_db_nodes, [NewNode]]),  
    io:format("Node = ~p, Rtn=~p~n", [Node, Rtn]),  
    addExtraNode(T, NewNode).  

addTableList(Nodes) ->  
    addTableList(lwdb:disc_tables(), Nodes,disc_copies),
    addTableList(lwdb:ram_tables(), Nodes,ram_copies).

add_ram_copy(Tables,Nodes)->
    addTableList(Tables,Nodes,ram_copies).
add_disc_copy(Tables,Nodes)->
    addTableList(Tables,Nodes,disc_copies).

addTableList([], _NewNode,_) ->  
    null;  
addTableList(_TableList = [Table | T], NewNode,Type) ->  
    Rtn = mnesia:add_table_copy(Table, NewNode, Type),  
    io:format("Table = ~p, Rtn = ~p~n", [Table, Rtn]),  
    addTableList(T, NewNode,Type). 

www_tables()->
   lwdb:tables().
add_www_node(Node)->    addNode(Node).
