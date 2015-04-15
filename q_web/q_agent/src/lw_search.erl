%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user search server
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_search).
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
			  "、"]).

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

%%--------------------------------------------------------------------------------------

split_sentence(Content) ->
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
    	2 ->
    	    lists:map(fun(Sub) ->combine_word2(Sub) end,TermList);
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

test() ->
    [{chinese,<<228,184,173>>},
     {chinese,<<229,133,180>>},
     {english,<<"abc">>},
     {english,<<"efg">>}] = split_character(list_to_binary("中兴abc efg")),
    io:format("~p~n",["test1 passed!"]),

    [{english,<<"123">>},
     {english,<<"abc">>},
     {english,<<"456">>}] = split_character(list_to_binary("123 abc 456")),
    io:format("~p~n",["test2 passed!"]),

    [{english,<<"123">>}] = split_character(list_to_binary("123  ")),
    io:format("~p~n",["test3 passed!"]),

    [{english,<<"abc">>}] = split_character(list_to_binary("ABC")),
    io:format("~p~n",["test4 passed!"]),

    [{english,<<"abc">>},
     {chinese,<<228,184,173>>},
     {chinese,<<229,133,180>>},
     {english,<<"abc">>}] = split_character(list_to_binary("abc中兴abc")),
    io:format("~p~n",["test5 passed!"]),

    [{english,<<"abc">>},
     {chinese,<<228,184,173>>},
     {chinese,<<229,133,180>>},
     {english,<<"abc">>}] = split_character(list_to_binary("abc  中兴abc")),
    io:format("~p~n",["test6 passed!"]),

    [{english,<<"abc">>},
     {chinese,<<228,184,173>>},
     {chinese,<<229,133,180>>},
     {english,<<"abc">>}] = split_character(list_to_binary("    abc  中兴abc")),
    io:format("~p~n",["test7 passed!"]),

    Term1 = list_to_binary("你好"),
    Term2 = list_to_binary("我是第八个测试用例"),
    [Term1,Term2] = split_sentence(list_to_binary("你好，我是第八个测试用例！")),
    io:format("~p~n",["test8 passed!"]),

    Term11 = list_to_binary("你好"),
    Term12 = list_to_binary("我是第九个abc"),
    Term13 = list_to_binary("测试用例"),
    [Term11,Term12,Term13] = split_sentence(list_to_binary("你好，我是第九个abc,测试用例！")),
    io:format("~p~n",["test9 passed!"]),

    Term21 = list_to_binary("你好"),
    Term22 = list_to_binary(" 我是第十个abc "),
    Term23 = list_to_binary("测试  用例"),
    [Term21,Term22,Term23] = split_sentence(list_to_binary("你好， 我是第十个abc 【测试  用例】")),
    io:format("~p~n",["test10 passed!"]),

    io:format("~p~n",[build_word(split_character(list_to_binary("中兴abc efg")),2)]),
    io:format("~p~n",[build_word(split_character(list_to_binary("中兴abc efg")),3)]),
    io:format("~p~n",[build_word(split_character(list_to_binary("中兴abc efg")),4)]).