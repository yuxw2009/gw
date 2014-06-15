-module(statistic).
-compile(export_all).

-define(SAMPLE_INTERVAL, 5000).

-record(state, {current_calls=0, cpu_usage="0.0", processes=[]}).

get()->
    ensure_alive(),
    ?MODULE ! {get_infos, self()},
    receive
        {value, R}-> R
    after 5000-> timeout
    end.

add_call()->
    ensure_alive(),
    ?MODULE ! add_call.

dec_call()->
    ensure_alive(),
    ?MODULE ! dec_call.

start()->
    register(?MODULE, spawn(fun()-> init() end)).

init()->
    State = #state{processes=[{llog, 0}]},
    timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    loop(State).
	
loop(State)->
    receive
        Message -> 
	        loop(on_message(Message,State))
    end.

on_message(add_call, State=#state{current_calls=Calls})->
    State#state{current_calls=Calls+1};

on_message(dec_call, State=#state{current_calls=Calls})->
    State#state{current_calls=Calls-1};

on_message({cpu_usage_report,CpuUsage}, State)->
    State#state{cpu_usage=CpuUsage};	
	
on_message({get_infos, From}, State=#state{cpu_usage=CpuUsage, processes=Procs})->
    {value, Calls} = app_manager:get_app_count(),
	From ! {value, [{current_calls, Calls},{cpu_usage, CpuUsage}, {processes, Procs}]},
    State;
	
on_message(sample_timer, State=#state{processes=Procs})->
    Self = self(),
	spawn(fun()->
              	Self ! {cpu_usage_report, get_cpu_usage()}
	      end),
    
    NewProcs = detect_processes(Procs),
	timer:send_after(?SAMPLE_INTERVAL, sample_timer),
    State#state{processes=NewProcs};
	
on_message(_,S)-> S.    

ensure_alive()->
    case whereis(?MODULE) of
        undefined->    
            start();
        _-> void
    end.
	
detect_processes(Procs) -> detect_processes(Procs,[]).	
detect_processes([], Acc) -> Acc;
detect_processes([{Name,RestartCount}=Proc|T], Acc) -> 
    case whereis(Name) of
	    undefined  ->
            Name:start(),		
		    detect_processes(T, [{Name, RestartCount+1}|Acc]);
		_          -> 
		    detect_processes(T, [Proc|Acc])
	end.
	
get_cpu_usage() ->
   C = os:cmd("top -b -n 2 -d .5 | grep \"Cpu(s):\""),
   scan_cpu_usage(lists:nth(2,string:tokens(C,"\n"))).

scan_cpu_usage("Cpu(s):" ++ T) ->
    scan_cpu_usage(T, in, []).

scan_cpu_usage("%us"++_Rest, in, Acc) -> string:strip(Acc);
scan_cpu_usage([A|T], in, Acc) -> scan_cpu_usage(T, in, Acc++[A]).
