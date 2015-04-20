-module(cdrgenerator).
-compile(export_all).

start_monitor() ->
    {Pid,_} = spawn_monitor(fun()-> init() end),
	register(?MODULE, Pid),
	Pid.
	
%% uuid,{Phone1,Rate1},{Phone2,Rate2},{StartTime,EndTime,Duration}
notify_new_cdr(UUID,CallerInfo,CalleeInfo,TimeInfo) ->
    ?MODULE ! {new_cdr,{UUID,CallerInfo,CalleeInfo,TimeInfo}}.

get_temp_cdrs() ->
    ?MODULE ! {get_temp_cdrs, self()}.	
	
init() -> 
    CdrSeqState = open_cdr_seq_file("./priv/cdr.seq"),
	{ok,cdr_temp_log} = dets:open_file(cdr_temp_log,[{file,"./priv/cdrtemp.log"},{auto_save, 5000}]),
    loop(CdrSeqState).

loop(CdrSeqState) ->
    receive
	    {new_cdr,{UUID,CallerInfo,CalleeInfo,{StartTime,EndTime,Duration}}} ->
	        {CdrSeq,NewCdrSeqState} = gen_cdr_seq(CdrSeqState),
			NewCdr = {CdrSeq, UUID,CallerInfo,CalleeInfo,{calendar:now_to_local_time(StartTime),
			                                              calendar:now_to_local_time(EndTime),
			                                              Duration}},
			dets:insert(cdr_temp_log,NewCdr),
			send_to_cdr_server(NewCdr),
			loop(NewCdrSeqState);
        {get_temp_cdrs,From} ->
		    From ! {temp_cdrs, dets:traverse(cdr_temp_log,fun(X) -> {continue, X} end)},
			loop(CdrSeqState);			
		{cdr_server_ack,CdrSeq} ->
		    dets:delete(cdr_temp_log,CdrSeq),
		    loop(CdrSeqState);
	    Unexpected -> 
		    io:fromat("CDRGenerator receive unexpected message ~p~n",[Unexpected]),
			loop(CdrSeqState)
	end.

open_cdr_seq_file(FileName) ->	
    Seq = case file:read_file(FileName) of
	         {error,_} ->
			     InitSeq = 10000000,
		         file:write_file(FileName,integer_to_list(InitSeq)),
				 InitSeq;
		     {ok,Bin} ->
			     list_to_integer(binary_to_list(Bin))
	      end,
	{Seq,FileName}.

gen_cdr_seq({CdrSeq,CdrSeqFile}) ->
    NextCdrSeq = CdrSeq+1,
	file:write_file(CdrSeqFile,integer_to_list(NextCdrSeq)),
	{CdrSeq, {NextCdrSeq,CdrSeqFile}}.

send_to_cdr_server(NewCdr) ->
    %% todo
	io:format("Send to cdr server: ~p~n.",[NewCdr]).