-module(net_stats).
-compile(export_all).

-define(SAMPLE_INTERVAL, 800).

-record(state, {io_device=undefined, error_count=0, data=[]}).

get()->
    ?MODULE ! {get_infos, self()},
    receive
        {value, R}-> R
    after 5000-> timeout
    end.

start()->
    P = spawn(fun()-> init() end),
    register(?MODULE, P),
    P.


open_log_file() ->
    case file:open("/var/log/eth0_traff.log",[read]) of
       {ok, F} -> file:position(F, eof), F;
       _       -> undefined
    end.

init()->
    timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    loop(#state{io_device=open_log_file()}).
	
loop(State)->
    receive
        Message -> 
	        loop(on_message(Message, State))
    end.

on_message({get_infos, From}, #state{data=Data, io_device=IODevice}=State)->
    case IODevice of
	    undefined ->
		    From ! {value, [<<"noneKB/s   noneKB/s   20131121_13:13:33\n">>]},
			State;
		_         ->
            From ! {value, lists:reverse(Data)},
            State#state{data=[]}
	end;
	
on_message({new_bandwith_stat, Stat}, #state{data=Data}=State)->
    NewData = 
		    case length(Data) > 10 of
		    	true  -> [Stat];
		    	false -> [Stat|Data]
		    end,
	State#state{data=NewData, error_count=0};	    

on_message(error_read, #state{io_device=IODevice, error_count=EC}=State)->
    if
        EC > 10 ->
            file:close(IODevice),
            State#state{io_device=undefined, error_count=0};
        true ->
            State#state{error_count=EC+1}
    end;

on_message(sample_timer, #state{io_device=IODevice}=State)->
    timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    case IODevice of
    	undefined ->
    	    State#state{io_device=open_log_file()};
    	_ ->
		    Self = self(),
			spawn(fun()->
				        case file:read_line(IODevice) of
					        {ok, Line} ->
			              	    Self ! {new_bandwith_stat, list_to_binary(Line)};
                            _ ->
                                Self ! error_read   
			            end
			      end),
			State
	end;
	
on_message(_,S)-> S.    

