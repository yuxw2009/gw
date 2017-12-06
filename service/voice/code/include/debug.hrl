
-define(DEBUG_INFO(Str,ParaList), logger:log(debug, "[~p:~p]: "++Str++"~n",[?MODULE,?LINE]++ParaList)).
-define(DEBUG_INFO(Str), ?DEBUG_INFO(Str,[])).

-define(ERROR_INFO(Str,ParaList), logger:log(error, "[~p:~p,stacktrace:~p]: "++Str++"~n",[?MODULE,?LINE,erlang:get_stacktrace()]++ParaList)).
-define(ERROR_INFO(Str), ?ERROR_INFO(Str,[])).

-define(PRINT_INFO(Str,ParaList), io:format("[~p:~p]: "++Str++"~n",[?MODULE,?LINE]++ParaList)).
-define(PRINT_INFO(Str), ?PRINT_INFO(Str,[])).

