-module(prefix_trie).
-export([new/1,find_max_prex/2,traversal/2,test/0]).
-record(node,{key,value=[],children=[]}).
test() ->
    Root = new([{"24",{"Angola-Mobile Unitel 2","0.2252",{2011,1,1}}},
	            {"24492",{"Angola-Mobile Unitel","0.2252",{2011,1,2}}},
	            {"24493",{"Angola-Mobile Unitel 1","0.23",{2011,1,4}}},
				{"24493",{"Angola-Mobile Unitel 2","0.26",{2011,1,3}}}]),
	{"",[]} = find_max_prex("123",Root),	
    io:format("test 1 passed!~n"),	
	{"24",[{"Angola-Mobile Unitel 2","0.2252",{2011,1,1}}]} = find_max_prex("244",Root),
	io:format("test 2 passed!~n"),
	{"24",[{"Angola-Mobile Unitel 2","0.2252",{2011,1,1}}]} = find_max_prex("24498",Root),
	io:format("test 3 passed!~n"),
	{"",[]} = find_max_prex("2",Root),
	io:format("test 4 passed!~n"),
	{"24",[{"Angola-Mobile Unitel 2","0.2252",{2011,1,1}}]} = find_max_prex("24",Root),
	io:format("test 5 passed!~n"),
	{"24492",[{"Angola-Mobile Unitel","0.2252",{2011,1,2}}]} = find_max_prex("24492",Root),
	io:format("test 6 passed!~n"),
	{"24493",[{"Angola-Mobile Unitel 2","0.26",{2011,1,3}},{"Angola-Mobile Unitel 1","0.23",{2011,1,4}}]} = find_max_prex("24493",Root),
	io:format("test 7 passed!~n"),
	{"24492",[{"Angola-Mobile Unitel","0.2252",{2011,1,2}}]} = find_max_prex("244921",Root),
	io:format("test 8 passed!~n"),
	{"24493",[{"Angola-Mobile Unitel 2","0.26",{2011,1,3}},{"Angola-Mobile Unitel 1","0.23",{2011,1,4}}]} = find_max_prex("244938",Root),
	io:format("test 9 passed!~n"),
	[{"24",{"Angola-Mobile Unitel 2","0.2252",{2011,1,1}}},
	 {"24492",{"Angola-Mobile Unitel","0.2252",{2011,1,2}}},
	 {"24493",{"Angola-Mobile Unitel 2","0.26",{2011,1,3}}},
	 {"24493",{"Angola-Mobile Unitel 1","0.23",{2011,1,4}}}] =
	 traversal(Root,test_fun()),
	io:format("test 10 passed!~n"),
	io:format("all test passed!~n").
test_fun() ->
    fun(Prefix,Fees) -> 
	    case {Prefix,Fees} of
			{finish,finish} ->
				[];
		    _ ->
			    {Fees,test_fun()}
		end
	end.
%% build new prefix trie %%
new(L) when is_list(L) ->
	Root = #node{key=root},
    new(L,Root).
new([],Root) ->
    Root;
new([H|T],OldRoot) ->
    NewRoot = insert(H,OldRoot),
	new(T,NewRoot).
%% insert code %%	
insert({[H|T],Value},Node)->
	Children = Node#node.children,
    case lists:keysearch(H,#node.key,Children) of
		{value,NodeValue} ->
		    NewChlid = insert({T,Value},NodeValue),
			NewChildren = lists:keyreplace(H,#node.key,Children,NewChlid),
			Node#node{children=NewChildren};
		false ->
			NewChild = insert({T,Value},#node{key=H}),
			%% sort key, make key seq like 1,2,3,4.... %%
			Node#node{children=lists:keysort(#node.key,[NewChild|Children])}
	end;
insert({[],Value},Node)->
    NewValue = [Value|Node#node.value],
	%% sort value by date %%
	Node#node{value = lists:keysort(3,NewValue)}.
%% find proc %%
find_max_prex([H|T],Node,Acc,Prefix,Value) ->
	Children = Node#node.children,
	case lists:keysearch(H,#node.key,Children) of
	    false ->
		    {Prefix,Value};
		{value,NodeValue} ->
		    NewValue = NodeValue#node.value,
			case NewValue of
			    [] ->
				    find_max_prex(T,NodeValue,[H|Acc],Prefix,Value);
				_ ->
				    NewPrefix = lists:reverse([H|Acc]),
				    find_max_prex(T,NodeValue,[H|Acc],NewPrefix,NewValue)
			end
	end;
find_max_prex([],_,_,Prefix,Value) ->
    {Prefix,Value}.
find_max_prex(Str,Root) ->
    find_max_prex(Str,Root,"","",[]).
%% travel whole trie,Proc fee value by Proc that the user input %%
traversal(Root,Proc) ->
    {FProc,Result} = lists:foldl(fun(Node,{DProc,Sum})->traversal(Node,DProc,Sum,[]) end,{Proc,[]},Root#node.children),
	lists:keymerge(1,lists:reverse(Result),FProc(finish,finish)).
traversal(Node,Proc,Rtn,Code) ->
    %% visit self %%
    NewCode = [Node#node.key|Code],
    {NewProc,NewRtn} = 
	    case Node#node.value of
	        [] ->
	            {Proc,Rtn};
		    Fees ->
			    Prefix = lists:reverse(NewCode),
		        {NewFees,NextProc} = Proc(Prefix,Fees),
				{NextProc,[{Prefix,NewFees}|Rtn]}
		end,
	%% visit children %%
	lists:foldl(fun(CNode,{DProc,Sum}) -> traversal(CNode,DProc,Sum,NewCode) end,{NewProc,NewRtn},Node#node.children).