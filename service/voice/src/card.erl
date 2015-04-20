-module(card).
-compile(export_all).
-include("card.hrl").

get(No) ->
    do_when_exist(No, fun(C)-> C end).

get_all() ->
    F = fun(C,Acc) -> [C|Acc] end,
    result(mnesia:transaction(fun() -> mnesia:foldl(F,[],card) end)).

add(No,Password,Balance) ->
    F = fun() ->
    	    mnesia:write(#card{no=No,password=Password,balance=Balance})
    	end,
    result(mnesia:transaction(F)).

assign(No,Groupid,Billid) ->
    do_update(No,fun(C) -> C#card{groupid=Groupid,billid=Billid} end).

delete(No) ->
    F = fun() ->
    	    mnesia:delete({card,No})
    	end,
    result(mnesia:transaction(F)).

activate(No) ->
    do_update(No,fun(C) -> C#card{status=active} end).
    
deactivate(No) ->
    do_update(No,fun(C) -> C#card{status=deactive} end).

change_password(No,NewPassword) ->
    do_update(No,fun(C) -> C#card{password=NewPassword} end).

charge(No,Value) ->
    do_update(No,fun(C) -> 
    	             OldV = C#card.balance,
    	             C#card{balance=OldV+Value} 
    	         end).

consume(No,Value) ->
    do_update(No,fun(C) -> 
    	             OldV = C#card.balance,
    	             C#card{balance=OldV-Value} 
    	         end).

update_seqno(No,Seqno) ->
    do_when_exist(No,fun(C) -> 
                        mnesia:write(C#card{seqno=Seqno})
                     end).

balance(No) ->
    do_when_exist(No,fun(C) -> C#card.balance end).
    
is_active(No) ->
    do_when_exist(No,fun(C) -> C#card.status =:= active end).

password(No) ->
    do_when_exist(No,fun(C) -> C#card.password end).

billid(No) ->
    do_when_exist(No,fun(C) -> C#card.billid end).

do_update(No,UpdateFun) ->
    do_when_exist(No,fun(C) -> mnesia:write(UpdateFun(C)) end).

do_when_exist(No,Action) ->
    F = fun() ->
    	    case mnesia:read(card,No) of
    	    	[] ->
    	    	    {error,card_not_exist};
                [C] ->
                    Action(C)
            end
        end,
    result(mnesia:transaction(F)).

result({atomic,Value}) -> Value;
result({aborted,Value}) -> Value.
