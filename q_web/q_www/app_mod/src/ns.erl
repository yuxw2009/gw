-module(ns).
-compile(export_all).

hostname() ->
    {ok,HN} = inet:gethostname(),
    HN.

ftp_node2() ->
    utility:atom("wftp@" ++ hostname()).

service_node2() ->
    utility:atom("ringo@" ++ hostname()).

ftp_node() ->
    'wftp@AFu'.

service_node() ->
    'ringo@caspar-PC'.