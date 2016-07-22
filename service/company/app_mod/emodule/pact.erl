-module(pact).
-compile(export_all).

p_resp(Txt) ->
	case rm_space(Txt) of
		{ok, Txt2} ->
			p_resp(Txt2,[]);
		{err, _} ->
			[]
	end.

p_resp([H|T], Res) when (H >= $a andalso H =< $f) orelse (H >= $A andalso H =< $F) ->
	{ok,Nums,Rest}=get_num(T),
	p_resp(Rest,[{a2cc(H),Nums}|Res]);
p_resp([H|T], Res) when H >= $0 andalso H =< $9 ->
	{ok, Nums, Rest} = get_num([H|T]),
	p_resp(Rest,[{num,Nums}|Res]);
p_resp([$+|T], Res) ->
	{ok, Nums, Rest} = get_num([$+|T]),
	p_resp(Rest,[{num,Nums}|Res]);
p_resp([H|T], Res) when H == $\n ->
	p_resp(T,Res);
p_resp(_, Res) ->
	lists:reverse(Res).
	
rm_space(Txt) ->
	case morechinese(Txt) of
		yes ->
			{err, "~~"};
		no ->
			rm_space(Txt,"")
	end.

morechinese("") -> no;
morechinese([$~,$~|_]) -> yes;
morechinese([_|T]) -> morechinese(T).

rm_space("", R) ->
	{ok,lists:reverse(R)};
rm_space([$\s|T],R) ->
	rm_space(T,R);
rm_space([$\r,$\n|T],R) ->	%% \r\n to \n
	rm_space(T, [$\n|R]);
rm_space([$\r|T],R) ->		%% \r to \n
	rm_space(T, [$\n|R]);
rm_space([H|T], R) ->
	rm_space(T, [H|R]).

get_num(S) ->
	{Res,Rest} = get_num(S, [""]),
	{ok, [X||X<-Res,X=/=""], Rest}.
	
get_num("", R) ->
	{lists:reverse(R), ""};
get_num([H|T], [Rh|Rt]) when H >= $0, H =< $9 ->
	get_num(T, [Rh++[H]|Rt]);
get_num([$+|T],[""|Rt]) ->
	get_num(T, ["00"|Rt]);
get_num([H|T], R) when H==$*; H==$,; H==$~ ->
	get_num(T, ["" |R]);
get_num([H|T], R) when H==$\s; H==$- ->
	get_num(T, R);
get_num([H|T], R) when H==$#; H==$\n ->
	{lists:reverse(R), T};
get_num([_|T],R) ->
	{lists:reverse(R), ""}.

a2cc($a) -> alpha;
a2cc($A) -> alpha;
a2cc($b) -> bravo;
a2cc($B) -> bravo;
a2cc($c) -> charlie;
a2cc($C) -> charlie;
a2cc($d) -> delta;
a2cc($D) -> delta;
a2cc($e) -> echo;
a2cc($E) -> echo;
a2cc($f) -> foxtrot;
a2cc($F) -> foxtrot.

% ----------------------------------
test() ->
	[{num, ["13651629502","13681850180"]}] = p_resp("\r\n13651629502,13681850180\r\n"),
	[{num,["13651629502"]}, {num, ["13681850180"]}] = p_resp("\r\n13651629502\r\n13681850180\r\n\r\n\r\n"),
	[{num, ["13651629502"]}] = p_resp("13651629502\r\n"),
	
	[{alpha, ["0001", "1234"]}] = p_resp("a0001*1234#"),
	[{alpha, ["0001", "1234"]}] = p_resp("A0001*1234"),
	[{bravo, ["0002"]}] = p_resp("b0002#"),
	[{bravo, ["0002"]}] = p_resp("B0002"),
	[{bravo, []}] = p_resp("b#"),
	[{bravo, []}] = p_resp("b\r\n"),
	[{bravo, []}] = p_resp("B"),
	[{num, ["13801961496"]}] = p_resp("138 0196 1496"),
	[{num, ["13801961496"]}] = p_resp(" 138-0196-1496"),
	[{num, ["008613801961496"]}] = p_resp("+8613801961496"),
	[{num, ["008613801961496","00862168895100"]}] = p_resp("+8613801961496,+862168895100"),
	ok.