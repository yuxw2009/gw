-module(node_detector).
-include("debug.hrl").
-compile(export_all).

nodes_to_detect()->
    ['gw1@119.29.62.190'].
start()-> timer:apply_interval(30000, ?MODULE, ping, [nodes_to_detect()]).
ping(Nodes)-> [detect(Node) || Node<-Nodes].
detect(Node)-> 
    net_adm:ping(Node),
    ok.