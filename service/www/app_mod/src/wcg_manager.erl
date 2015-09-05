%%---------------------------------------------------------------------------------------
%%% @author ZhangCongSong
%%% @copyright 2012-2014 LiveCom
%%% @doc WCG Manager
%%% @end
%%---------------------------------------------------------------------------------------
-module(wcg_manager).
-export([start/0,pinging/0]).
-compile(export_all).

start() ->
       io:format("6666666666666666666**********************~n"),
    init_db(),
    token_keeper:start(),
    spawn(fun pinging/0),
    nmsi:start(),
    my_process:start().
	
init_db() ->
       io:format("7777777777**********************~n"),
%    mnesia:start(),
       io:format("8888888888888888**********************nodes:~p~n",[nodes()]),
       net_adm:ping('www_t@10.32.7.28'),
    case catch mnesia:change_config(extra_db_nodes, wwwcfg:cluster() -- [node()]) of  
    {ok, []} ->  
       io:format("*************************************************~n"),
        Tables = mnesia:system_info(tables),
        case lists:member(wcg_conf, Tables) of
        	true -> 
        	    login_processor:start(),
        	    pass;
        	false ->
        	    mnesia:stop(),
                mnesia:create_schema([node()]),
                mnesia:start(),
                wcg_disp:create_tables(),
                login_processor:start(),
    	         opr_rooms:create_tables(),
    	         lwdb:do_this_once()
        end,
        mnesia:wait_for_tables([wcg_conf, opr_rooms],20000),
        wcg_disp:init_wcg_queue();
    {ok,R=[_|_]}-> 
        io:format("wcg_manager:init_db ack:~p~n",[R]);
    Other->
        io:format("wcg_manager:init_db other:~p~n",[Other])
    end.

db_nodes_detect()->
    case lists:member('www_dth@10.32.3.52',mnesia:system_info(running_db_nodes)) of
    true-> 
        io:format("(db nodes ok)"),
        pass;
    _->
        io:format("******db_nodes down~n"),
        mnesia:stop(),
        mnesia:start()
    end.

interval_do(T,Fun)->    
    Fun(),
    receive
    impossible-> void
    after 60*1000->
        interval_do(T,Fun)
    end.    

pinging()->
    Ml=net_adm:ping(wwwcfg:get_wcgnode("Mainland")),
    Eu=net_adm:ping(wwwcfg:get_wcgnode("Europe")),
    As=net_adm:ping(wwwcfg:get_wcgnode("Asia")),
    io:format("ping:~p ",[{Ml,Eu,As}]),
    db_nodes_detect(),
    receive
    impossible-> void
    after 60*1000->
        pinging()
    end.
