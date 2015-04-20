-module(ns).
-compile(export_all).

hostname() ->
    {ok,HN} = inet:gethostname(),
%    HN.
    Node=node(),
    NodeStr=atom_to_list(Node),
    [_, Host]=string:tokens(NodeStr, "@"),
    Host.

ftp_node() ->
    utility:atom("swftp@" ++ hostname()).

service_node() ->
    utility:atom("www@" ++ hostname()).

ftp_node2() ->
    'wftp@AFu'.

service_node2() ->
    'ringo@caspar-PC'.
    
get(max_calls)-> 600.

    
