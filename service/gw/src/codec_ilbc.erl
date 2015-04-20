-module(codec_ilbc).
-compile(export_all).

-include("erl_debug.hrl").
-include("desc.hrl").

-define(KFS,8).
-define(iLBC,102).
-define(LOSTSEQ,1003).

-record(st, {
	in,			% ilbc data in pid
	out,		% raw pcm out pid
	ctx,
	mode,
	c_2udp,		% pid -> udp packets count
	sbuf= <<>>	% pid -> udp direction buffer
}).

init([From,PTime,To]) ->
	{0,Ctx} =  ?APPLY(erl_ilbc, icdc, [PTime]) ,
	io:format("ilbc ~p busy.~n",[Ctx]),
	{ok,TR} = my_timer:send_interval(PTime, play_audio),
	{ok,#st{in=From,out=To,ctx=Ctx,mode=PTime,c_2udp=0}}.

handle_info(#audio_frame{codec=?LOSTSEQ,samples=N},#st{ctx=Ctx}=ST) ->
	{0,_} =  ?APPLY(erl_ilbc, xplc, [Ctx]) ,
	{noreply,ST};
handle_info(#audio_frame{codec=?iLBC,marker=Marker,body=Body,samples=Samples},
			#st{ctx=Ctx,out=Out}=ST) ->
	{0,Dec} =  ?APPLY(erl_ilbc, xdec, [Ctx,Body]) ,
	Out ! {pcm_raw,Samples,Dec},
	{noreply,ST};
handle_info({pcm_raw,Samples,Raw},#st{sbuf=Buf}=ST) ->
	{noreply,ST#st{sbuf= <<Buf/binary,Raw/binary>>}};
handle_info(play_audio,#st{in=In,ctx=Ctx,sbuf=Buf,mode=PTime,c_2udp=C2udp}=ST) ->
	if size(Buf)>=PTime*?KFS*2 ->
		{R1,Rest} = split_binary(Buf,PTime*?KFS*2),
		{0,Enc} =  ?APPLY(erl_ilbc, xenc, [Ctx,R1]) ,
		Marker = if C2udp==0 -> 1; true -> 0 end,
		In ! #audio_frame{codec=?iLBC,marker=Marker,body=Enc,samples=PTime*?KFS},
		{noreply,ST#st{sbuf=Rest,c_2udp=C2udp+1}};
	true ->
		{noreply,ST}
	end.

handle_cast(stop,#st{ctx=Ctx}=ST) ->
	io:format("ilbc ~p stopped.~n",[Ctx]),
	0 =  ?APPLY(erl_ilbc, xdtr, [Ctx]) ,
	{stop,normal,[]}.
terminate(normal,_) ->
	ok.

% ----------------------------------
start(From,SendTo) ->	% choice: resample cng
	{ok,Pid} = my_server:start(?MODULE,[From,30,SendTo],[]),
	Pid.