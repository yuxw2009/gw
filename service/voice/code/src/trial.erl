-module(trial).
-compile(export_all).

-record(applied, {phone,card_no,password}).
-record(binding, {card_no,phone}).
-record(trial,{card_no, password}).

create_tab() ->
    mnesia:start(),
    mnesia:create_table(applied, [{disc_copies,[node()]},
	                              {attributes, record_info(fields, applied)}]),	

    mnesia:create_table(trial, [{disc_copies,[node()]},
	                            {attributes, record_info(fields, trial)}]),

    mnesia:create_table(binding, [{disc_copies,[node()]},
	                              {attributes, record_info(fields, binding)}]),
    ok.

import(FileName) ->
    Cards = utility:readlines(FileName),
    [add(CardNo, PassWord) || [CardNo, PassWord] <- Cards].


add(CardNo,Password) ->
    F = fun() ->
    	    mnesia:write(#trial{card_no=CardNo, password=Password})
    	end,
    mnesia:activity(transaction, F).

apply(Phone) ->
    F = fun() ->
	    	case mnesia:read(applied, Phone) of
	    		[] ->
	    		    case get_trial_card() of
	    		        [] -> 
	    		            {error, no_card_available};
	    		        [#trial{card_no=CardNo, password=Password}] ->
	    		            mnesia:write(#applied{phone=Phone,card_no=CardNo,password=Password}),
	    		            mnesia:write(#binding{card_no=CardNo,phone=Phone}),
	    		            mnesia:delete({trial, CardNo}),
	                        {value, CardNo, Password}
	    		    end;
	    		[#applied{phone=Phone,card_no=CardNo,password=Password}] ->
	    		     {value, CardNo, Password}
	    	end
	    end,
    mnesia:activity(transaction, F).

check_binding(CardNo, Phone1, Phone2) ->
	F = fun() ->
		   case mnesia:read(binding, CardNo) of
		   	   [] -> check_success;
		       [#binding{card_no=CardNo, phone=Phone}] ->
		           if 
		           	    Phone =:= Phone1 ->
		           	        check_success;
		           	    true ->
		                    check_failed
		           end
		   end 
		end,
    mnesia:activity(transaction,F).


%%% internal function
get_trial_card() ->
    case mnesia:all_keys(trial) of    
        []     -> [];
        [No|_] -> mnesia:read(trial,No)
    end.