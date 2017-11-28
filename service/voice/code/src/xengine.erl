-module(xengine).
-compile(export_all).

-include("yxa_config.hrl").
-include("siprecords.hrl").

sip_port()->
    {_,_,S}= erlang:now(),    
    5000+ (S div 1000).

config_defaults() ->
    [#cfg_entry{key		= listenport,
        default	= 5060,   %sip_port(),
        type	= integer,
        soft_reload	= false
       }].

start() ->
    spawn(fun()-> init() end).

init()->
    process_flag(trap_exit,true),
    mnesia:start(),
    sipserver:start(normal,[?MODULE]),
    CdrPid=cdrserver:start_monitor(),
    RatePid = rateserver:start_monitor(),
    OperatorPid=operator:start_monitor(),
%    conf_mgr:start(),
%    node_detector:start(),
%    ybed_sup:start_link(),
    loop({CdrPid,RatePid,OperatorPid}).
	
loop({CdrPid,RatePid,OperatorPid}=Pids) ->
    receive
	    {'DOWN', _Ref, process, Pid, _Reason} ->
	           timer:sleep(500),
		    NewPids =
			    case Pid of
			        CdrPid -> 
					    NewCdrPid = cdrserver:start_monitor(),
						{NewCdrPid,RatePid,OperatorPid};
					RatePid ->
                        NewRatePid = rateserver:start_monitor(),
						{CdrPid,NewRatePid,OperatorPid};
                    OperatorPid ->				
					    NewOperatorPid = operator:start_monitor(),
						{CdrPid,RatePid,NewOperatorPid}		
			    end,
			loop(NewPids);
        Message -> 
            io:format("XEngine receive: ~p~n",[Message]),
            loop(Pids)
    end.
    
response(Response, YxaCtx) when is_record(Response, response), is_record(YxaCtx, yxa_ctx) ->
    logger:log(normal, "XEngine receive Response : ~p~n",[Response]).
   
request(Request, YxaCtx)->
    %%logger:log(normal, "XEngine receive Request : ~p~n",[Request]),
    #yxa_ctx{thandler = THandler} = YxaCtx,
	case Request#request.method of
	    "OPTIONS" ->
		    transactionlayer:send_response_handler(THandler, 200, "OK");
          "INVITE"->
              io:format("invite received xengine~n"),
              p2p_tp_ua:start(Request,YxaCtx);
	    Oth ->
	          io:format("xengine:unhandled request:~p~n",[Oth]),
		    pass
	end.
