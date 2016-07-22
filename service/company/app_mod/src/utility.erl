-module(utility).
-compile(export_all).

hexstr2bin(S) ->
    list_to_binary(hexstr2list(S)).

hexstr2list([X,Y|T]) ->
    [mkint(X)*16 + mkint(Y) | hexstr2list(T)];
hexstr2list([]) ->
    [].

mkint(C) when $0 =< C, C =< $9 ->
    C - $0;
mkint(C) when $A =< C, C =< $F ->
    C - $A + 10;
mkint(C) when $a =< C, C =< $f ->
    C - $a + 10.

readlines(FileName) ->
    {ok, Device} = file:open(FileName, [read]),
    get_all_lines(Device, []).

get_all_lines(Device, Accum) ->
    case io:get_line(Device, "") of
        eof  -> file:close(Device), Accum;
        Line -> get_all_lines(Device, Accum ++ [string:tokens(string:strip(Line,right,$\n)," ")])
    end.

import(FileName,GroupId,BillId) ->
    Cards = readlines(FileName),
    add_card(Cards,[],GroupId,BillId).

add_card([],[],_,_) -> ok;
add_card([],ErrAcc,_,_) -> {error_no, ErrAcc};
add_card([[[_,M1,M2|_]=No,PassWord]|T],ErrAcc,GroupId,BillId) -> 
    case card:get(No) of
    	{error,card_not_exist} ->
    	    Money = (M1-$0)*100.0 + (M2-$0)*10.0,
    	    card:add(No,PassWord,Money),
    	    card:assign(No,GroupId,BillId),
            add_card(T,ErrAcc,GroupId,BillId);
    	_ ->
    	   add_card(T,[No|ErrAcc],GroupId,BillId) 
    end;
add_card(_,_,_,_) -> pass. 


activate(FileName) ->
    Cards = readlines(FileName),
    activate_card(Cards,[]).

activate_card([],[]) -> ok;
activate_card([],ErrorAcc) -> {error_no,ErrorAcc};
activate_card([[No,_]|T],ErrorAcc) ->
    case card:get(No) of
    	{error,card_not_exist} ->
    	    activate_card(T,[No|ErrorAcc]);
    	_ ->
    	   card:activate(No),
           activate_card(T,ErrorAcc)
    end; 

activate_card(_,_) -> pass.


deactivate(FileName) ->
    Cards = readlines(FileName),
    deactivate_card(Cards,[]).

deactivate_card([],[]) -> ok;
deactivate_card([],ErrorAcc) -> {error_no,ErrorAcc};
deactivate_card([[No,_]|T],ErrorAcc) ->
    case card:get(No) of
        {error,card_not_exist} ->
            deactivate_card(T,[No|ErrorAcc]);
        _ ->
           card:deactivate(No),
           deactivate_card(T,ErrorAcc)
    end; 

deactivate_card(_,_) -> pass.


add_trail_card([],[],_,_) -> ok;
add_trail_card([],ErrAcc,_,_) -> {error_no, ErrAcc};
add_trail_card([[[_,M1,M2|_]=No,PassWord]|T],ErrAcc,GroupId,BillId) -> 
    case card:get(No) of
    	{error,card_not_exist} ->
    	    Money = 5.0,
    	    card:add(No,PassWord,Money),
    	    card:assign(No,GroupId,BillId),
            add_trail_card(T,ErrAcc,GroupId,BillId);
    	_ ->
    	   add_trail_card(T,[No|ErrAcc],GroupId,BillId) 
    end;
add_trail_card(_,_,_,_) -> pass. 

import_trail(FileName,GroupId,BillId) ->
    Cards = readlines(FileName),
    add_trail_card(Cards,[],GroupId,BillId).


import2(FileName,GroupId,BillId,Balance) ->
    Cards = readlines(FileName),
    add_card2(Cards,GroupId,BillId,Balance).

add_card2([],_,_,_) -> ok;
add_card2([[No,PassWord]|T],GroupId,BillId,Balance) ->
    card:add(No,PassWord,Balance),
    card:assign(No,GroupId,BillId),
    card:activate(No),
    add_card2(T,GroupId,BillId,Balance);
add_card2(_,_,_,_) -> pass.     


log(Arg)-> log(Arg,[]).
log(Arg,Ps)-> log("./log/voice.log",Arg,Ps).
log(FN, Arg,Reason)->
	{ok, IODev} = file:open(FN, [append]),
	io:format(IODev, "~p:  "++Arg++"~n", [erlang:localtime()|Reason]),
	file:close(IODev).

