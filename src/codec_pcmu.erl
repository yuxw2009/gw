-module(codec_pcmu).
-compile(export_all).

-include("desc.hrl").
-include("erl_debug.hrl").

-define(KFS,8).
-define(PCMU,0).
-define(LOSTSEQ,1003).

-record(st, {
	in,			% encoded data in pid
	out,		% raw pcm out pid
	ctx,
	mode,
	c_2udp,		% pid -> udp packets count
	sbuf= <<>>	% pid -> udp direction buffer
}).

init([From,PTime,To]) ->
	{ok,TR} = my_timer:send_interval(PTime, play_audio),
	{ok,#st{in=From,out=To,mode=PTime,c_2udp=0}}.

handle_info(#audio_frame{codec=?LOSTSEQ,samples=_N},ST) ->
	{noreply,ST};
handle_info(#audio_frame{codec=?PCMU,marker=Marker,body=Body,samples=Samples},#st{out=Out}=ST) ->
	Dec =  ?APPLY(erl_isac_nb, udec, [Body]) ,
	Out ! {pcm_raw,Samples,Dec},
	{noreply,ST};
handle_info({pcm_raw,Samples,Raw},#st{sbuf=Buf}=ST) ->
	{noreply,ST#st{sbuf= <<Buf/binary,Raw/binary>>}};
handle_info(play_audio,#st{in=In,sbuf=Buf,mode=PTime,c_2udp=C2udp}=ST) ->
	if size(Buf)>=PTime*?KFS*2 ->
		{R1,Rest} = split_binary(Buf,PTime*?KFS*2),
		Enc =  ?APPLY(erl_isac_nb, uenc, [R1]) ,
		Marker = if C2udp==0 -> 1; true -> 0 end,
		In ! #audio_frame{codec=?PCMU,marker=Marker,body=Enc,samples=PTime*?KFS},
		{noreply,ST#st{sbuf=Rest,c_2udp=C2udp+1}};
	true ->
		{noreply,ST}
	end.

handle_cast(stop,_ST) ->
	io:format("pcmu ~p stopped.~n",[self()]),
	{stop,normal,[]}.
terminate(normal,_) ->
	ok.

% ----------------------------------
start(From,SendTo) ->	% choice: resample cng
	{ok,Pid} = my_server:start(?MODULE,[From,20,SendTo],[]),
	Pid.