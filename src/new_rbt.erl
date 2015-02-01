-module(new_rbt).
-compile(export_all).

-include("erl_debug.hrl").
-define(PCMU,0).
-define(iSAC,103).
-define(iLBC,102).
-define(L16,107).
-include("desc.hrl").

-define(PLAY_INTERVAL, 60).
-define(FREQ, 8000).
-define(PCM_UNIT_LEN,(2*(?FREQ*?PLAY_INTERVAL div 1000))).

-record(st,{
	ilbc,
	pcm,
	tick,		% [0...5]
	usrs
}).

-record(us,{
	pid,   % media pid
	owner, % w2p
	cdc_type,
	fp,
	timelen=0,
	loop=true,
	live
}).

init([IlbcFn,PcmFn]) ->
	{ok,Ilbc} = file:read_file(avscfg:get_root()++IlbcFn),
	{ok,Pcm} = file:read_file(avscfg:get_root()++PcmFn),
	my_timer:send_interval(?PLAY_INTERVAL,new_play_audio),
	{ok,#st{ilbc=Ilbc,pcm=Pcm,tick=1,usrs=[]}}.

handle_call(get_info,_,ST) ->
	{reply,ST#st.usrs,ST}.

handle_info({delete,OutMedia}, #st{usrs=Users}=ST) ->
    io:format("new_rbt (~p) deleted.~n",[OutMedia]),
    Users1= lists:keydelete(OutMedia,2,Users),
    {noreply,ST#st{usrs=Users1}};
handle_info({'DOWN', _Ref, process, OutMedia, _Reason},#st{usrs=Users}=ST)->
    io:format("new_rbt rec ~p Down,delete it~n",[OutMedia]),
    {noreply,ST#st{usrs=lists:keydelete(OutMedia,2,Users)}};
handle_info({add,OutMedia,Owner, Secs,CdcType,Loop}, #st{usrs=Users}=ST) ->
    io:format("new_rbt (~p) ~p added.~n",[Secs,OutMedia]),
    case lists:keysearch(OutMedia,2,Users) of
    	{value,U1} ->
    		{noreply,ST#st{usrs=lists:keyreplace(OutMedia,2,Users,U1#us{live=now(),cdc_type=CdcType,pid=OutMedia, owner=Owner,timelen=Secs,loop=Loop})}};
    	false ->
    	      erlang:monitor(process,OutMedia),
    		U1 = #us{pid=OutMedia, owner=Owner,timelen=Secs,cdc_type=CdcType,fp=0,live=now(),loop=Loop},
    		{noreply,ST#st{usrs=[U1|Users]}}
    end;
handle_info(new_play_audio,#st{tick=Tick,usrs=Us}=ST) ->
	Us2 = kick_out_timeouts(Us),
	Us3 = new_play_rbt(Tick,Us2,ST),
	Us4 = [I||I=#us{}<-Us3],
	{noreply,ST#st{tick=(Tick+1) rem 6,usrs=Us4}};
handle_info(Msg,ST) ->
	io:format("new rbt unknow ~p.~n",[Msg]),
	{noreply,ST}.

handle_cast(stop,_) ->
	{stop,command,[]};
handle_cast(_,St) ->
	{noreply,St}.
terminate(_,_) ->
	ok.

% ----------------------------------

kick_out_timeouts(Us) ->
	Now = now(),
	kick_out_tos(Now,Us,[]).
kick_out_tos(_Now,[],NUs) ->
	lists:reverse(NUs);
kick_out_tos(Now,[#us{live=LastT,timelen=TimeLen}=U1|Us],NUs) ->
	case timer:now_diff(Now,LastT) div 1000 of
		Dt when Dt>TimeLen*1000 ->		% more than TimeLen s
			kick_out_tos(Now,Us,NUs);
		_ ->
			kick_out_tos(Now,Us,[U1|NUs])
	end.

new_play_rbt(Tick,Us,ST)  ->
%	Us1 = [U1||#us{isac=false}=U1<-Us],
      Us1 = Us,
	lists:map(fun(U) -> send_tone(?PLAY_INTERVAL*8,U,ST) end,Us1).
send_tone(PTime,#us{fp=FP,pid=Pid,owner=Owner,cdc_type=CdcType,loop=Loop}=U,St) ->
    Bin = if CdcType == ?L16->  St#st.pcm; true-> St#st.ilbc end,
    Body = get_tone(CdcType,FP,Bin),
    if size(Body) > 0 ->
        {Samples,Marker} = if FP == 0 ->  {0,true}; true-> {PTime,false} end,
        Pid ! #audio_frame{codec=CdcType,marker=Marker,samples=Samples,body=Body},
%        io:format("~p ",[FP]),
        U#us{fp=FP+1};
    Loop->  U#us{fp=0};
    true-> 
        io:format("send_tone over alert_over to  (~p, ~p).~n",[Owner,U]),
        if is_pid(Owner)-> Owner ! {alert_over,self()}; true-> void end,
        undefined
    end.

get_tone(?L16,Fp,Bin) when size(Bin) >= (Fp+1)*?PCM_UNIT_LEN  ->
      Len1 = (Fp*?PCM_UNIT_LEN),
	<<_:Len1/binary,Tone:?PCM_UNIT_LEN/binary, _/binary>> = Bin,
	Tone;
get_tone(?iLBC,0,<<Size:16,Bin/binary>>) ->
	<<Tone:Size/binary,_/binary>> = Bin,
	Tone;
get_tone(?iLBC,FP,<<Size:16,Bin/binary>>) ->
	<<_:Size/binary,Rest/binary>> = Bin,
	get_tone(?iLBC,FP-1,Rest);
get_tone(_,_,_) ->
    <<>>.
% ----------------------------------
write_tone(pcm2ilbc,Ilbc,Bin,FH,PcmUnitLen) when size(Bin)>=PcmUnitLen ->
    {Outp,Rest} = split_binary(Bin,PcmUnitLen),
    EncBin = rrp:ilbc_enc60(Ilbc, Outp),
    Size= size(EncBin),
    Buf = <<Size:16,EncBin/binary>>,
    file:write(FH, Buf),
    write_tone(pcm2ilbc,Ilbc,Rest,FH,PcmUnitLen);
write_tone(pcm2ilbc,Ilbc,Bin,FH,_)->
%    EncBin = rrp:ilbc_enc60(Ilbc, Bin),
%    Size= size(EncBin),
%    Buf = <<Size:16,EncBin/binary>>,
%    file:write(FH, Buf),
    file:close(FH).
    
make_tone(pcm2ilbc,InFileName,OutFileName) ->
	{ok,Bin} = file:read_file(InFileName),
	{ok,FH} = file:open(OutFileName,[write,binary,raw]),
	PcmUnitLen = ?PCM_UNIT_LEN,
	{0,Ilbc} =  ?APPLY(erl_ilbc, icdc, [30]) ,
	write_tone(pcm2ilbc,Ilbc,Bin,FH, PcmUnitLen).
	
make_tone(isac,FileName) ->
	{ok,Bin} = file:read_file(FileName),
	{ok,FH} = file:open("rbt.isac",[write,binary,raw]),
	{0,Isac} =  ?APPLY(erl_isac_nb, icdc, [0,32000,960]) ,
	AFs = transcode(Isac,100,Bin,<<>>),
	0 =  ?APPLY(erl_isac_nb, xdtr, [Isac]) ,
	file:write(FH,AFs),
	file:close(FH);
make_tone(ilbc,FileName) ->
	{ok,Bin} = file:read_file(FileName),
	{ok,FH} = file:open("rbt1.ilbc",[write,binary,raw]),
	{0,Ilbc} = ?APPLY(erl_ilbc, icdc, [30]),
	AFs = transcode_ilbc(Ilbc,100,Bin,<<>>),
	0 =  ?APPLY(erl_ilbc, xdtr, [Ilbc]) ,
	file:write(FH,AFs),
	file:close(FH);
make_tone(pcmu,FileName) ->
	{ok,Bin} = file:read_file(FileName),
	{ok,FH} = file:open("rbt.pcmu",[write,binary,raw]),
	AFs = transcode_pcm(300,Bin,<<>>),
	file:write(FH,AFs),
	file:close(FH).

transcode_ilbc(_Isac,0,_,Bin) ->
	Bin;
transcode_ilbc(Ilbc,N,<<F1:480/binary,F2:480/binary,Rest/binary>>, Bin) ->
	Enc=rrp:ilbc_enc60(Ilbc,<<F1/binary,F2/binary>>),
	Size = size(Enc),
	transcode(Ilbc,N-1,Rest,<<Bin/binary,Size:16,Enc/binary>>).

transcode(_Isac,0,_,Bin) ->
	Bin;
transcode(Isac,N,<<F1:1920/binary,Rest/binary>>, Bin) ->
	{0,_,Enc} = ?APPLY(erl_isac_nb, xenc, [Isac,F1]),
	Size = size(Enc),
	transcode(Isac,N-1,Rest,<<Bin/binary,Size:16,Enc/binary>>).

transcode_pcm(0,_,Bin) ->
	Bin;
transcode_pcm(N,<<F1:640/binary,Rest/binary>>,Bin) ->
	Enc = ?APPLY(erl_isac_nb, ue16k, [0,F1]),
	Size = size(Enc),
	transcode_pcm(N-1,Rest,<<Bin/binary,Size:16,Enc/binary>>).

start() -> start(["alert.ilbc","ringback.pcm"]).
start([IlbcFn,PcmFn]) ->
    my_server:start({local,new_rbt},?MODULE,[IlbcFn,PcmFn],[]).	
    
  to_pcm({pcmu,PCMU})-> to_pcm({pcmu,PCMU},<<>>).
  to_pcm({pcmu,PCMU},R) when size(PCMU) <160 ->   R;
  to_pcm({pcmu,<<H:160/binary,Rest/binary>>},Result)-> 
      New= erl_isac_nb:udec(H),
      to_pcm({pcmu,Rest},<<Result/binary,New/binary>>).
    

