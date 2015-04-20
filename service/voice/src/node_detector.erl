-module(node_detector).
-include("debug.hrl").
-compile(export_all).

nodes_to_detect()->
    ['tservice@ltalk.com'].
start()-> timer:apply_interval(5000, ?MODULE, ping, [nodes_to_detect()]).
ping(Nodes)-> [detect(Node) || Node<-Nodes].
detect(Node)-> 
    net_adm:ping(Node),
    ok.