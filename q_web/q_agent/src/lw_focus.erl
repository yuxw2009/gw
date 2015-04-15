%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user auth
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_focus).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

set(UUID, Items) ->
    lw_db:act(set,focus,{UUID, Items}).

%%--------------------------------------------------------------------------------------

cancel(UUID,EntityType, EntityID) ->
    lw_db:act(del,focus,{UUID,EntityType, EntityID}).

%%--------------------------------------------------------------------------------------

get_all(UUID) ->
    All = lw_db:act(get,all_focus,{UUID}),
    [get_focus_content(Ele)||Ele<-All].

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

get_focus_content({{tasks,ID},Tags,Time}) ->
    {tasks,Tags,lw_lib:trans_time_format(Time),lw_task:get_task_content(ID,focus)};
get_focus_content({{topics,ID},Tags,Time}) ->
    {topics,Tags,lw_lib:trans_time_format(Time),lw_topic:get_topic_content(ID)}.

%%--------------------------------------------------------------------------------------