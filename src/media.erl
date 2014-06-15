-module(media).
-compile(export_all).

-include("desc.hrl").

-define(PCMU,0).
-record(st,{
	name,
	rtp,
	hbuf,
	file,
	lasteof,
	ortp,
	obuf,	% out data buf
	ohd,	% out head buf
	obc,	% out block count
	peer,
	noise,
	bnis,
	remain,
	payl
}).

init([Name,null]) ->
	{ok,FH}=file:open(Name++"_01.pcm",[write,binary]),
	{ok,#st{name=Name,hbuf= <<>>, file=FH,lasteof=0,ortp=null,remain=0}}.
	
handle_info({play,RTP}, #st{peer=undefined}=ST) ->
	{ok,RHd} = file:read_file("xyz.idx"),
	{ok,RDat} = file:read_file("xyz_01.pcm"),
	{ok,Noise} = file:read_file("cn.pcm"),
%	timer:send_interval(20,{play_media,now}),	% package time 20ms
	{noreply,ST#st{ortp=RTP,obuf=RDat,ohd=RHd,obc=0,noise=Noise,bnis=0}};
handle_info({play_media,_},#st{ortp=Ortp,obuf=Dat,ohd=Ohd,obc=OBC1,remain=0}=ST) ->
	OBL = (OBC1 rem (size(Ohd) div 8)) * 8,
	<<_:OBL/binary, Samples:12,Type:4,Size:16,Pos:32, _/binary>> = Ohd,
	<<_:Pos/binary, Body:Size/binary,_/binary>> = Dat,
	Frame = #audio_frame{codec = Type,body = Body,samples=Samples},
	if Samples == 160 -> 
		Ortp ! Frame,
		{noreply,ST#st{obc=OBC1+1}};
	true ->
		#st{noise=Noise,bnis=Bnis} = ST,
		Pos = Bnis * 160,
		<<_:Pos/binary,Body:160/binary,_/binary>> = Noise,
		FNoise = #audio_frame{codec = ?PCMU,body = Body,samples=160},
		Ortp ! FNoise,
		{noreply,ST#st{remain=Samples,payl=Frame,bnis=(Bnis+1) rem 50}}
	end;
handle_info({play_media,_},#st{ortp=Ortp,obc=OBC1,remain= 160,payl=Frame}=ST) ->
	Ortp ! Frame,
	{noreply,ST#st{obc=OBC1+1,remain=0}};
handle_info({play_media,_},#st{remain=Remain}=ST) when Remain > 160 ->
	{noreply,ST#st{remain=Remain-160}};
handle_info(#audio_frame{codec=Type,samples=Samples,body=Dat},#st{hbuf=Hbuf,file=FH,lasteof=LastEOF}=ST) ->
	io:format("W"),
	file:write(FH,Dat),
	Size=size(Dat),
	{ok,EOF} = file:position(FH,eof),
	{noreply,ST#st{hbuf= <<Hbuf/binary, Samples:12,Type:4,Size:16,LastEOF:32>>, lasteof=EOF}}.

handle_cast({pcm,Type,Samples,Dat},#st{hbuf=Hbuf,file=FH,lasteof=LastEOF}=ST) ->
	file:write(FH,Dat),
	Size=size(Dat),
	{ok,EOF} = file:position(FH,eof),
	{noreply,ST#st{hbuf= <<Hbuf/binary, Samples:8,Type:8,Size:16,LastEOF:32>>, lasteof=EOF}};
handle_cast(stop,#st{name=Name,hbuf=Hbuf,file=FH}) ->
	file:close(FH),
	file:write_file(Name++".idx",Hbuf),
	{ok,Info} = file:read_file_info(Name++".idx"),
	case element(2,Info) of
		0 -> ok;
		_ ->
			file:copy(Name++".idx","xyz.idx"),
			file:copy(Name++"_01.pcm","xyz_01.pcm")
	end,
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------	
start(Name,ORTP) ->
	{ok,Pid} = my_server:start(?MODULE,[Name,ORTP],[]),
	Pid.
	
stop(loop) -> ok;
stop(Pid) when is_pid(Pid) ->
	my_server:cast(Pid,stop).
	
rinfo(Pid,Info) ->
	my_server:cast(Pid,Info).
save(Pid,Ptype,Samples,Dat) ->
	my_server:cast(Pid,{pcm,Ptype,Samples,Dat}).