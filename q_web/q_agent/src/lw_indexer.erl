%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user search indexer
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_indexer).
-compile(export_all).
-include("lw.hrl").

-define(MARK,[",","，",
			  ".","。",
			  "'","‘","’",
			  ":","：",
			  "?","？",
			  "!","！",
			  "-",
			  "[","【",
			  "]","】",
			  "(","（",
			  ")","）",
			  "{","}",
			  "<","《",
			  ">","》",
			  "、",
              "\n","\r","\r\n"]).

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

index({Type,Id}, Owner, Content) ->
    F = fun() ->
            case mnesia:read(lw_instance,Owner) of
                [#lw_instance{employee_name = Name}] -> Name;
                [] -> []
            end
        end,
    OwnerName = mnesia:activity(transaction,F),
    NewContent = list_to_binary(OwnerName ++ binary_to_list(Content)),
    case split_content(NewContent) of
        httpc_failed ->
            httpc_failed;
        Words ->
            lists:foreach(fun(Word) -> write_index(Word,{Type,Id}) end,Words)
    end.

request_split_server(Content) when is_binary(Content) ->
    [Server] = lw_config:get_split_server_ip(),
    IP   = Server,
    URL  = lw_lib:build_url(IP,"",[],[]),
    Body = rfc4627:encode(lw_lib:build_body([txt],[Content],[r])),
    case lw_lib:httpc_call(post,{URL,Body}) of
        httpc_failed ->
            httpc_failed;
        Json ->
            lists:usort(element(1,lw_lib:parse_json(Json,[{split,as}],0)))
    end.

%%--------------------------------------------------------------------------------------

search(UUID,topics,Keyword)    -> search(UUID,topic,Keyword);
search(UUID,tasks,Keyword)     -> search(UUID,task,Keyword);
search(UUID,documents,Keyword) -> search(UUID,document,Keyword);
search(UUID,polls,Keyword)     -> search(UUID,poll,Keyword);
search(UUID,questions,Keyword) -> search(UUID,question,Keyword);
search(UUID,news,Keyword)      ->
    F = fun() ->
            case mnesia:read(lw_indexer,Keyword) of
                []     -> [];
                [Term] -> Term#lw_indexer.content
            end
        end,
    case mnesia:activity(transaction,F) of
        [] -> {0,[]};
        Results ->
            ResultIDs = [ID||{IDType,ID}<-Results,IDType =:= news],
            {length(ResultIDs),get_id_content(news,UUID,ResultIDs)}
    end;
search(UUID,Type,Content) ->
    case split_content(Content) of
        httpc_failed ->
            httpc_failed;
        Words ->
            TargetIDs = combine_words_index(UUID,Type,Words),
            {length(TargetIDs),get_id_content(Type,UUID,TargetIDs)}
    end.

split_content(Content) ->
    case request_split_server(Content) of
        httpc_failed ->
            httpc_failed;
        Splits ->
            lists:map(fun(X) -> list_to_binary(X) end,Splits)
    end.

combine_words_index(UUID,Type,Words) ->
    case Words of
        [] -> [];
        _  ->
            TargetIDs = sets:intersection([sets:from_list(search_one_word(UUID,Type,Word))||Word<-Words]),
            lists:reverse(lists:sort(sets:to_list(TargetIDs)))
    end.

search_one_word(UUID,Type,Keyword) ->
    F = fun() ->
            case mnesia:read(lw_indexer,Keyword) of
                []     -> [];
                [Term] -> Term#lw_indexer.content
            end
        end,
    case mnesia:activity(transaction,F) of
        [] -> [];
        Results ->
            ResultIDs = [ID||{IDType,ID}<-Results,IDType =:= Type],
            filter_related_id(Type,UUID,ResultIDs)
    end.

%%--------------------------------------------------------------------------------------

filter_related_id(task,UUID,ResultIDs)     -> lw_task:filter_related_id(UUID,ResultIDs);
filter_related_id(topic,UUID,ResultIDs)    -> lw_topic:filter_related_id(UUID,ResultIDs);
filter_related_id(document,UUID,ResultIDs) -> lw_document:filter_related_id(UUID,ResultIDs);
filter_related_id(poll,UUID,ResultIDs)     -> lw_poll:filter_related_id(UUID,ResultIDs);
filter_related_id(question,_,ResultIDs)    -> ResultIDs.

%%--------------------------------------------------------------------------------------

get_id_content(task,_,Results)     -> lw_task:get_task_content(Results,focus);
get_id_content(topic,_,Results)    -> lw_topic:get_topic_content(Results);
get_id_content(document,_,Results) -> lw_document:get_doc_content(Results);
get_id_content(poll,UUID,Results)  -> lw_poll:get_poll_content(UUID,Results);
get_id_content(news,_,Results)     -> lw_news:get_news_content(Results);
get_id_content(question,_,Results) -> lw_question:get_qus_content(Results).

%%--------------------------------------------------------------------------------------

make_index(Content) ->
    Sentences      = split_sentence(Content),
    CharactersList = lists:map(fun(Sentence) -> split_character(Sentence) end,Sentences),
    IndexList      = lists:flatten(lists:map(fun(Characters) -> build_word(Characters) end,CharactersList)),
    sets:to_list(sets:from_list([Binary||{_,Binary}<-IndexList])).

%%--------------------------------------------------------------------------------------

split_sentence(Content) when is_binary(Content) ->
    Mark = lists:map(fun(X) -> list_to_binary(X) end,?MARK),
    lists:filter(fun(Bin) -> Bin =/= <<>> end,binary:split(Content,Mark,[global])).

%%--------------------------------------------------------------------------------------

split_character(Content) ->
    split_character_iter(eat_one_space(Content),[]).

split_character_iter(Content,Result) ->
    case Content of
    	<<>> ->
    	    lists:reverse(Result);
    	_ ->
    	    {Character,Rest} = get_one_character(Content),
    	    split_character_iter(eat_one_space(Rest),[Character|Result])
    end.

%%--------------------------------------------------------------------------------------

get_one_character(Content) ->
    get_one_character(Content,current_character_type(Content)).

get_one_character(Content,chinese) ->
    <<Character:3/binary,Rest/binary>> = Content,
    {{chinese,Character},Rest};

get_one_character(Content,english) ->
    F = fun(S) ->
	        list_to_binary(string:to_lower(S))
	    end,
    get_one_character_iter(Content,[],F,english).

get_one_character_iter(Content,Result,Trans,english) ->
    case Content of
    	<<>> ->
    	    {{english,Trans(string:join(lists:reverse(Result),""))},<<>>};
    	_ ->
    	    <<Head:1/binary,Rest/binary>> = Content,
    	    case Head of
    	    	<<" ">> ->
    	    	    {{english,Trans(string:join(lists:reverse(Result),""))},Content};
    	    	_ ->
    	    	    case current_character_type(Content) of
    	    	    	english ->
    	    	    	    get_one_character_iter(Rest,[binary_to_list(Head)|Result],Trans,english);
    	    	    	chinese ->
    	    	    	    {{english,Trans(string:join(lists:reverse(Result),""))},Content}
    	    	    end
    	    end
    end.

%%--------------------------------------------------------------------------------------

current_character_type(Content) ->
    <<Head:8/integer,_/binary>> = Content,
    if
    	Head < 128 ->
    	    english;
    	true ->
    	    chinese
    end.

%%--------------------------------------------------------------------------------------

eat_one_space(Content) ->
    case Content of
    	<<>> ->
    	    <<>>;
    	_ ->    
		    <<Head:1/binary,Rest/binary>> = Content,
		    case Head of
		    	<<" ">> ->
		    	    eat_one_space(Rest);
		    	_ ->
		    	    Content
		    end
	end.

%%--------------------------------------------------------------------------------------

build_word(Chars,Num) ->
    Starts = lists:seq(1,length(Chars) - Num + 1),
    combine_word(lists:map(fun(Start) -> lists:sublist(Chars,Start,Num) end,Starts),Num).

%%--------------------------------------------------------------------------------------

combine_word(TermList,Num) ->
    F = fun(Sub) ->
            SubFirstTwo = lists:sublist(Sub,1,2),
            SubRest     = lists:sublist(Sub,3,Num - 2),
    	    [combine_word2(SubFirstTwo)|SubRest]
    	end,
    case Num of
        1 -> TermList;
    	_ ->
    	    NewTermList = lists:map(F,TermList),
    	    combine_word(NewTermList,Num - 1)
    end.

combine_word2([{english,A},{english,B}]) ->
    Space = list_to_binary(" "),
    {english,<<A/binary,Space/binary,B/binary>>};

combine_word2([{_,A},{_,B}]) ->
    {chinese,<<A/binary,B/binary>>}.

%%--------------------------------------------------------------------------------------

build_word(Chars) ->
    case length(Chars) of
        1 ->
            build_word(Chars,1);
        2 ->
            build_word(Chars,1) ++ build_word(Chars,2);
        3 ->
            build_word(Chars,1) ++ build_word(Chars,2) ++ build_word(Chars,3);
        _ ->
            build_word(Chars,1) ++ build_word(Chars,2) ++ build_word(Chars,3) ++ build_word(Chars,4)
    end.

%%--------------------------------------------------------------------------------------

write_sponsor(Sponsor,{Type,Id}) ->
    F = fun() ->
            case mnesia:read(lw_sponsor,Sponsor,write) of
                []  -> mnesia:write(#lw_sponsor{key = Sponsor,content = [{Type,Id}]});
                [_] -> update_table(lw_sponsor,content,Sponsor,{Type,Id},fun(New,Old) -> [New|Old] end)
            end
        end,
    mnesia:activity(transaction,F).

write_index(Index,{Type,Id}) ->
    F = fun() ->
            case mnesia:read(lw_indexer,Index,write) of
                []  -> mnesia:write(#lw_indexer{key = Index,content = [{Type,Id}]});
                [_] -> update_table(lw_indexer,content,Index,{Type,Id},fun(New,Old) -> [New|Old] end)
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

-define(UPDATE_TAB(Tab,Tag,Key,Content,Act),update_table(Tab,Tag,Key,Content,Act) ->
    [Item] = mnesia:read(Tab,Key,write),
    Old    = Item#Tab.Tag,
    New    = Act(Content,Old),
    mnesia:write(Item#Tab{Tag = New})).

?UPDATE_TAB(lw_indexer,content,Key,Value,Act);
?UPDATE_TAB(lw_sponsor,content,Key,Value,Act).

%%--------------------------------------------------------------------------------------