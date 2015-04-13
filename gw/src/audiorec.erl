-module(audiorec).
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
	peer
}).

init([Name]) ->
	{ok,FH}=file:open(Name++"_01.pcm",[write,binary]),
	{ok,#st{name=Name,hbuf= <<>>, file=FH,lasteof=0,ortp=null}}.
	
handle_info({play,RTP}, #st{peer=undefined}=ST) ->
	{noreply,ST#st{ortp=RTP}};
handle_info(#audio_frame{codec=Type,samples=Samples,body=Dat}=Frame,
			#st{ortp=Ortp,hbuf=Hbuf,file=FH,lasteof=LastEOF}=ST) ->
	if is_pid(Ortp) -> Ortp ! Frame;
	true -> pass end,
	file:write(FH,Dat),
	Size=size(Dat),
	{ok,EOF} = file:position(FH,eof),
	{noreply,ST#st{hbuf= <<Hbuf/binary, Samples:12,Type:4,Size:16,LastEOF:32>>, lasteof=EOF}}.

handle_cast(stop,#st{name=Name,hbuf=Hbuf,file=FH}) ->
	file:close(FH),
	file:write_file(Name++".idx",Hbuf),
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start(?MODULE,[Name],[]),
	Pid.
	
stop(Pid) when is_pid(Pid) ->
	my_server:cast(Pid,stop).
