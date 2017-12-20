-module(topus).
-compile(export_all).

-record(st, {
    n,
    cdc,
    fh,
    raw
}).

init([N]) ->
    {0,Id} = erl_opus:icdc(8000,5),
    {ok,Raw} = file:read_file("rbt.pcm"),
   	{ok,FH} = file:open("rbt_"++integer_to_list(N)++".pcm",[write,binary,raw]),
    {ok,#st{n=N,cdc=Id, fh=FH, raw=Raw}, 0}.

handle_info(timeout,#st{n=N,fh=FH,cdc=Id,raw=Raw}) ->
	AFs = transcode2(Id,300,Raw,<<>>),
	Fs = dec2(Id,300,AFs,<<>>),
	0 = erl_opus:xdtr(Id),
	file:write(FH,Fs),
	file:close(FH),
	{stop,normal,N}.

terminate(normal,N) ->
    io:format("~p stopped.~n",[N]),
    ok.

% ----------------------------------
transcode2(_Opus,0,_,Bin) ->
	Bin;
transcode2(Opus,N,<<F1:640/binary,Rest/binary>>, Bin) ->
	{0,Enc} = erl_opus:xenc(Opus,erl_resample:down8k(F1)),
	Size = size(Enc),
	transcode2(Opus,N-1,Rest,<<Bin/binary,Size:16,Enc/binary>>).


dec2(_Opus, 0, _, Out) ->
    Out;
dec2(Opus, N, <<Size:16,Bin/binary>>, Out) ->
    <<F1:Size/binary,Rest/binary>> = Bin,
    {0,_,PCM} = erl_opus:xdec(Opus, F1),
    dec2(Opus,N-1,Rest,<<Out/binary,PCM/binary>>).

% ----------------------------------
start(0) ->
    ok;
start(N) ->
    my_server:start(?MODULE,[N],[]),
    start(N-1).