%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork bbs
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_bbs).
-compile(export_all).
-include("lw.hrl").

%%--------------------------------------------------------------------------------------

create_forum(UUID,Cats) when is_list(Cats) ->
    Module   = lw_config:get_user_module(),
    MarkName = Module:get_user_markname(UUID),
    Indexs   = lists:map(fun(_) -> lw_id_creater:generate_bbscatindex() end,lists:seq(1,length(Cats))),
    Items    = lists:zipwith(fun(X,{Y,Z}) -> {X,Y,Z} end,Indexs,Cats),
    F = fun() ->
            case mnesia:read(lw_bbscat,MarkName,write) of
                [] ->
                    mnesia:write(#lw_bbscat{key = MarkName,index = Items});
                [#lw_bbscat{index = OldItems} = BBSCat] ->
                    mnesia:write(BBSCat#lw_bbscat{index = OldItems ++ Items})
            end
        end,
    mnesia:activity(transaction,F),
    Indexs.

%%--------------------------------------------------------------------------------------

get_all_forum(UUID) ->
    Module   = lw_config:get_user_module(),
    MarkName = Module:get_user_markname(UUID),
    F = fun() ->
            case mnesia:read(lw_bbscat,MarkName) of
                [] -> [];
                [#lw_bbscat{index = Items}] -> Items
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_all_notes(UUID,Index,Page,Num) ->
    {TotalNum,TodayNum,NoteIDs} = get_cat_info(Index),
    SubLists = lw_lib:get_sublist(NoteIDs,Page,Num),
    F1= fun() -> [hd(mnesia:read(lw_bbsnote,NoteID))||NoteID<-SubLists] end,
    Notes = mnesia:activity(transaction,F1),
    Transform = fun(#lw_bbsnote{uuid = ID,owner_id = From,title = Title,content = Content,type = Type,replies = Replies,reader = Reader,time_stamp = Time,repository = Repository}) ->
    	            {ID,From,Title,Content,Type,length(Replies),Reader,lw_lib:trans_time_format(Time),Repository}
    	        end,
    {UUID,TotalNum,TodayNum,[Transform(Note)||Note<-Notes]}.

get_cat_info(Index) ->
    {Today,_} = erlang:localtime(),
    F = fun() ->
            case mnesia:read(lw_bbs_verse_note,Index) of
                [#lw_bbs_verse_note{total_num = TotalNum, today_num = TodayNum,notes = NoteIDs}] ->
                    case dict:find(Today, TodayNum) of
                        error ->
                            {TotalNum,0,NoteIDs};
                        {ok,Value} ->
                            {TotalNum,Value,NoteIDs}
                    end;
                [] -> {0,0,[]}
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

create_note(UUID,Title,Content,Repository,Index) ->
    Time = erlang:localtime(),
    {Today,_} = Time,
    NoteID = lw_id_creater:generate_bbsnoteid(),
    F = fun() ->
    	    mnesia:write(#lw_bbsnote{uuid=NoteID,owner_id=UUID,time_stamp=Time,title=Title,content=Content,repository=Repository,index = Index}),
    	    case mnesia:read(lw_bbs_verse_note,Index,write) of
    	    	[] ->
    	    	    mnesia:write(#lw_bbs_verse_note{index = Index,
                                                    today_num = dict:store(Today, 1, dict:new()),
                                                    notes = [NoteID]});
    	    	[#lw_bbs_verse_note{total_num = TotalNum, today_num = TodayNum,notes = Old} = V] ->
    	    	    mnesia:write(V#lw_bbs_verse_note{total_num = TotalNum + 1,
                                                     today_num = add_today_num(Today,TodayNum),
                                                     notes = [NoteID|Old]})
    	    end
        end,
    mnesia:activity(transaction,F),
    {NoteID,lw_lib:trans_time_format(Time),UUID}.

add_today_num(Today,Dict) ->
    NewValue = 
        case dict:find(Today, Dict) of
            {ok, Value} -> Value + 1;
            error -> 1
        end,
    dict:store(Today, NewValue, Dict).

del_today_num(Today,Dict) ->
    {ok, Value} = dict:find(Today, Dict),
    dict:store(Today, Value - 1, Dict).

%%--------------------------------------------------------------------------------------

delete_note(_UUID,NoteID) ->
    {Today,_} = erlang:localtime(),
    F = fun() ->
    	    [#lw_bbsnote{index = Index}]   = mnesia:read(lw_bbsnote,NoteID,write),
    	    mnesia:delete(lw_bbsnote,NoteID,write),
    	    [#lw_bbs_verse_note{total_num = TotalNum, 
                                today_num = TodayNum,
                                notes = Old} = V] = mnesia:read(lw_bbs_verse_note,Index,write),
    	    mnesia:write(V#lw_bbs_verse_note{total_num = TotalNum - 1,
                                             today_num = del_today_num(Today,TodayNum),
                                             notes = lists:delete(NoteID,Old)}),
    	    ok
    	end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

modify_note_type(_UUID,NoteID,NewType) ->
    F = fun() ->
    	    [Note] = mnesia:read(lw_bbsnote,NoteID,write),
    	    mnesia:write(Note#lw_bbsnote{type = NewType})    
    	end,
    mnesia:activity(transaction,F),
    NoteID.

%%--------------------------------------------------------------------------------------

reply_note(UUID,NoteID,Content,Repository) ->
    Time = erlang:localtime(),
    ReplyID = lw_id_creater:generate_bbsnotereplyid(),
    F = fun() ->
    	    [#lw_bbsnote{index = Index,replies = Old} = Note] = mnesia:read(lw_bbsnote,NoteID,write),
    	    mnesia:write(Note#lw_bbsnote{replies = [{ReplyID,UUID,Content,Time,Repository}|Old]}),
            [#lw_bbs_verse_note{notes = Old1} = V] = mnesia:read(lw_bbs_verse_note,Index,write),
            mnesia:write(V#lw_bbs_verse_note{notes = [NoteID|Old1 -- [NoteID]]})
    	end,
    mnesia:activity(transaction,F),
    {ReplyID,lw_lib:trans_time_format(Time),UUID}.

%%--------------------------------------------------------------------------------------

get_note_reply(UUID,NoteID,Page,Num) ->
    F = fun() ->
    	    [#lw_bbsnote{replies = Replies}] = mnesia:read(lw_bbsnote,NoteID),
    	    Replies
    	end,
    Replies = mnesia:activity(transaction,F),
    SubList = lw_lib:get_sublist(Replies,Page,Num),
    F1= fun({ReplyID,ID,Content,Time,Repository}) -> 
            {ReplyID,ID,Content,lw_lib:trans_time_format(Time),Repository} 
        end,
    {UUID,length(SubList),lists:map(F1,SubList)}.

%%--------------------------------------------------------------------------------------

test1() ->
    Cats = [{"渠道政策信息发布区","中兴公司动态"},
            {"PRM系统交流区","中兴公司动态"},
            {"培训相关","中兴公司动态"},
            {"数通产品","中兴产品服务支持"},
            {"视讯产品","中兴产品服务支持"},
            {"终端产品","中兴产品服务支持"},
            {"能源","行业及解决方案"},
            {"铁路","行业及解决方案"},
            {"大企业","行业及解决方案"},
            {"论坛公告区","中兴论坛服务管理区"},
            {"版主会议室","中兴论坛服务管理区"},
            {"建议反馈","中兴论坛服务管理区"}],
    create_forum(76,Cats).

test2() ->
    Cats = [{"新闻公告","社区版面"},
            {"技术讨论","社区版面"},
            {"娱乐八卦","社区版面"}],
    create_forum(76,Cats).