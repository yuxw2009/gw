-module(tmp).
-compile(export_all).
-include("db.hrl").

modify_balance() ->
    F1= fun(Key) ->
    	    [Employee] = mnesia:read(employer,Key,write),
    	    mnesia:write(Employee#employer{balance = 50.0})
    	end,
    F2= fun() ->
    	    AllKeys = mnesia:all_keys(employer),
    	    [F1(Key)||Key<-AllKeys],
    	    ok
        end,
    mnesia:activity(transaction,F2).

month_charge() ->
    F1= fun({_,EID} = Key) ->
            [Employee] = mnesia:read(employer,Key,write),
            %%{EID ++ "@ZTE",Employee#employer.balance}
            {EID ++ "@ZTE",50.0}
        end,
    F2= fun() ->
            AllKeys = mnesia:all_keys(employer),
            [F1(Key)||Key<-AllKeys]
        end,
    Result = mnesia:activity(transaction,F2),
    rpc:call('service@10.32.3.38',card,batch_reset,[Result]).

charge_once() ->
    {{Year,Month,_},_} = erlang:localtime(),
    F1= fun({CompanyID,JobNumber}) ->
    	    [Employee] = mnesia:read(employer,{CompanyID,JobNumber}),
    	    Cost = 
                case mnesia:read(employer_stat,{CompanyID,JobNumber,Year,Month}) of
                    [] -> 0;
                    [Stat] -> Stat#employer_stat.charge
                end,
    	    Employee#employer.balance - Cost
    	end,
    F2= fun() -> 
    	    Keys = mnesia:all_keys(employer),
    	    [{JobNumber ++ "@ZTE",F1({CompanyID,JobNumber})}||{CompanyID,JobNumber}<-Keys]
    	end,
    Result = mnesia:activity(transaction,F2),
    rpc:call('service@10.32.3.38',card,batch_reset,[Result]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

charge({CompanyID,JobNumber}) ->
    {{Year,Month,_},_} = erlang:localtime(),
    F = fun() ->
    	    [Employee] = mnesia:read(employer,{CompanyID,JobNumber}),
    	    Cost = 
                case mnesia:read(employer_stat,{CompanyID,JobNumber,Year,Month}) of
                    [] -> 0;
                    [Stat] -> Stat#employer_stat.charge
                end,
    	    Employee#employer.balance - Cost
    	end,
    Result = mnesia:activity(transaction,F),
    rpc:call('service@10.32.3.38',card,batch_reset,[[{JobNumber ++ "@ZTE",Result}]]).

calc_days() ->
    {{Year,Month,_},_} = erlang:localtime(),
    calc_days(Year,Month).

calc_days(_,1) -> 
    31;
calc_days(Year,2) -> 
	case Year rem 400 of
		0 -> 29;
		_ ->
		    if
		    	((Year rem 4) =:= 0) andalso ((Year rem 100) =/= 0) -> 29;
		    	true -> 28
		    end
	end;
calc_days(_,3) -> 
    31;
calc_days(_,4) -> 
    30;
calc_days(_,5) -> 
    31;
calc_days(_,6) -> 
    30;
calc_days(_,7) -> 
    31;
calc_days(_,8) -> 
    31;
calc_days(_,9) -> 
    30;
calc_days(_,10) -> 
    31;
calc_days(_,11) -> 
    30;
calc_days(_,12) -> 
    31.

auto_month_charge()->
    spawn(fun()-> auto_month_charge(date()) end).
    
auto_month_charge({_,Mon0,_})->
    io:format("."),
    timer:sleep(1000*60*60),
    Date={_,Mon,_}=date(),
    if Mon=/=Mon0->  
        io:format("auto_month_charge~n"),
        month_charge();
    true-> void
    end,
    ?MODULE:auto_month_charge(Date).



