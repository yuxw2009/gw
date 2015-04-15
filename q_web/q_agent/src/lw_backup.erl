%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user backup
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_backup).
-compile(export_all).
-include("lw.hrl").

start() ->
    case dets:open_file(?MODULE) of
    	{ok,?MODULE} ->
    	    register(?MODULE,spawn(fun() -> loop() end)),
    	    ok;
    	{error,_} -> 
    	    backup_start_failed
    end.

insert(Key,Value) when is_list(Value) ->
    ?MODULE ! {insert,Key,Value};
insert(Key,Value) ->
    ?MODULE ! {insert,Key,[Value]}.

loop() ->
    receive
    	{insert,Key,Value} ->
    	    case dets:lookup(?MODULE, Key) of
    	        {error, _} ->
    	            dets:insert(?MODULE,{Key,Value});
    	        {Key,OldValue} ->
    	            dets:insert(?MODULE,{Key,Value ++ OldValue})
            end,
            loop()
    end.