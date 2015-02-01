-module(vcr).
-compile(export_all).

-define(PCMU,0).
-define(LINEAR,99).
-define(VP8, 100).
-define(DIR, "./vcr/").

-include("desc.hrl").

-record(st,{
	name,
	fc,		% frame count
	fh,		% file handle
	ah,		% audio handle
	ac,		% audio frame count
	bgn		% begin time
}).

init([Name]) ->
	{ok,FH} = file:open(?DIR++Name++".ivf", [write,raw,binary]),
	{ok,AH} = file:open(?DIR++Name++".pcm", [write,raw,binary]),
	ok = save_ivf_hdr(FH),
	{ok,#st{name=Name,fc=0,fh=FH,ac=0,ah=AH,bgn=now()}}.
handle_info(#audio_frame{codec=?PCMU,body=Body},#st{ac=AC,ah=FH}=ST) ->
	save_pcmu_frame(FH,Body),
	{noreply,ST#st{ac=AC+1}};
handle_info(#audio_frame{codec=?LINEAR,body=Body},#st{ac=AC,ah=FH}=ST) ->
	save_pcmu_frame(FH,Body),
	{noreply,ST#st{ac=AC+1}};
handle_info({leVeled_vp8,_KF,_Level,EncDat}, #st{fc=FC,fh=FH}=ST) ->
	save_ivf_frame(FH,EncDat),
	{noreply,ST#st{fc=FC+1}};
handle_info(Msg, ST) ->
	io:format("unkn ~p  ",[Msg]),
	{noreply,ST}.

handle_call(stop,_From,ST=#st{name=Name,fc=FC,fh=FH,ac=AC,ah=AH,bgn=Bgn}) ->
	{stop,normal,ok,ST}.

handle_cast(stop,ST=#st{name=Name,fc=FC,fh=FH,ac=AC,ah=AH,bgn=Bgn}) ->
	{stop,normal,ST}.
terminate(normal, #st{name=Name,fc=FC,fh=FH,ac=AC,ah=AH,bgn=Bgn}) ->
	ok = save_ivf_frame_count(FH,FC,Bgn),
	file:close(FH),
	file:close(AH),
	if AC==0-> file:delete(?DIR++Name++".pcm");
	true -> pass end,
	if FC==0-> file:delete(?DIR++Name++".ivf");
	true -> pass end,
	io:format("vcr ~p stopped @~p video and ~p audio.~n",[Name,FC,AC]),
	ok.

% ----------------------------------	
save_ivf_hdr(FH) ->
	{W,H} = {640,480},
	NF = 0,
	DKIF = <<"DKIF">>,
	VPCD = <<"VP80">>,
	FRate = 1000,
	TScale= 1,
	IVF_HDR= <<DKIF/binary,0:16,32:16/little,VPCD/binary,W:16/little,H:16/little,FRate:32/little,TScale:32/little,NF:32/little,0:32>>,
	ok = file:write(FH, IVF_HDR).

save_ivf_frame(FH,Bin) ->
%	<<_:32,TS:64/little,_/binary>> = Bin,
%	io:format(" ~p ",[TS]),
	ok = file:write(FH, Bin).

save_ivf_frame_count(FH,_C,Bgn) ->
	T = timer:now_diff(now(),Bgn) div 1000,
	file:position(FH, 24),
	ok = file:write(FH, <<T:32/little>>).

save_pcmu_frame(FH,Bin) ->
	ok = file:write(FH,Bin).
% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start(?MODULE,[Name],[]),
	Pid.
	
stop(Pid) when is_pid(Pid) ->
	my_server:call(Pid,stop);
stop(_) -> ok.
