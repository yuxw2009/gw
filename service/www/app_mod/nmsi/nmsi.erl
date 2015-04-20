-module(nmsi).
-export([start/0,start/2,stop/0,handle_cmd/2]).
-compile(export_all).

start() ->
    start(nmsi_configure:ip(),nmsi_configure:port()).

start(IP,Port) ->
    case gen_server:start({local,nmsi},nmsi_server,[IP,Port],[]) of
    	{ok,Pid} ->
            ok = gen_server:call(Pid,accept),
    	    {ok,Pid};
    	{error,Reason} ->
    	    Reason
    end.

stop() ->
    gen_server:call(nmsi,stop).

show()->
    Fun=fun(State={listened,Listen,Pids})->
               {{Listen,Pids},State}
           end,
    gen_server:call(nmsi,{act,Fun}).

handle_cmd("CREATE_SDN",Para) ->
    io:format("~p~n",["CREATE_SDN"]),
    io:format("~p~n",[Para]),
    lw_agent_oss:create_sdn(Para);

handle_cmd("CREATE_SIPREG_USER",Para) ->
    io:format("~p~n",[create_sipreg_user]),
    io:format("~p~n",[Para]),
    lw_agent_oss:bind_sipdn(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("DELETE_SDN",Para) ->
    io:format("~p~n",[delete_sdn]),
    io:format("~p~n",[Para]),
    lw_agent_oss:unbind_sipdn(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("CREATE_MSN",Para) ->  %fushuhaoma  for did use
    io:format("~p~n",["CREATE_MSN"]),
    io:format("~p~n",[Para]),
    lw_agent_oss:create_did(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("DELETE_MSN",Para) ->  
    io:format("~p~n",["DELETE_MSN"]),
    io:format("~p~n",[Para]),
    lw_agent_oss:destroy_did(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("CREATE_MIXSUB",Para) ->   %  cid
    io:format("~p~n",["CREATE_MSN"]),
    io:format("~p~n",[Para]),
    lw_agent_oss:create_did(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("DELETE_MIXSUB",Para) ->
    io:format("~p~n",["DELETE_MIXSUB"]),
    io:format("~p~n",[Para]),
    lw_agent_oss:destroy_did(Para);
%    [{"RETN","0"},{"DESC","Success."}];

handle_cmd("MODIFY_SUB_ATTR",Para) ->
    io:format("~p~n",[modify_sub_attr]),
    io:format("~p~n",[Para]),
    lw_agent_oss:modify_sub_attr(Para);

handle_cmd(_Cmd,Para) ->
    io:format("unhandled:~p~n",[_Cmd]),
    io:format("~p~n",[Para]),
    [{"RETN","0"},{"DESC","unhandled."}].
