-module(opr_rbt).
-compile(export_all).

-include("erl_debug.hrl").
-define(PCMU,0).
-define(iSAC,103).
-include("desc.hrl").

-record(st,{
	isac,
	ilbc,
	pcmu,
	tick,		% [0...5]
	usrs
}).

-record(us,{
	pid,
	isac,
	cdc_type,
	fp,
	live
}).

init([]) ->
	{ok,Isac} = file:read_file(avscfg:get_root()++"rbt.isac"),
%	{ok,Ilbc} = file:read_file("untitled.ilbc"),
	{ok,Tone} = file:read_file(avscfg:get_root()++"rbt.pcmu"),
	my_timer:send_interval(10,play_audio),
	{ok,#st{isac=Isac,pcmu=Tone,tick=1,usrs=[]}}.

handle_call(get_info,_,ST) ->
	{reply,ST#st.usrs,ST}.

handle_info(#audio_frame{owner=Owner,codec=Codec}, #st{usrs=Users}=ST) ->
	case lists:keysearch(Owner,2,Users) of
		{value,U1} ->
			{noreply,ST#st{usrs=lists:keyreplace(Owner,2,Users,U1#us{live=now()})}};
		false ->
			U1 = #us{pid=Owner,isac=is_isac(Codec),fp=0,live=now(),cdc_type=Codec},
			{noreply,ST#st{usrs=[U1|Users]}}
	end;
handle_info(play_audio,#st{tick=Tick,usrs=Us}=ST) ->
	Us2 = kick_out_timeouts(Us),
	Us3 = play_rbt(Tick,ST#st.isac,ST#st.pcmu,Us2,ST),
	{noreply,ST#st{tick=(Tick+1) rem 6,usrs=Us3}};
handle_info({play,_RTP}, ST) ->
	{noreply,ST};
handle_info({stun_locked,_RTP}, ST) ->
	{noreply,ST};
handle_info({deplay,RTP}, #st{usrs=Us}=ST) ->
	{noreply,ST#st{usrs=lists:keydelete(RTP,2,Us)}};
handle_info(Msg,ST) ->
	io:format("rbt unknow ~p.~n",[Msg]),
	{noreply,ST}.

handle_cast(stop,#st{isac=UseIsac}) ->
	io:format("rbt(~p) stopped.~n",[UseIsac]),
	{stop,command,[]};
handle_cast(_,St) ->
	{noreply,St}.
terminate(_,_) ->
	ok.

% ----------------------------------
output_interval(T,Msg) ->
	my_timer ! {self(),T,Msg}.

is_isac(103) -> true;
is_isac(102) -> true;
is_isac(105) -> true;
is_isac(_) -> false.

kick_out_timeouts(Us) ->
	Now = now(),
	kick_out_tos(Now,Us,[]).
kick_out_tos(_Now,[],NUs) ->
	lists:reverse(NUs);
kick_out_tos(Now,[#us{live=LastT}=U1|Us],NUs) ->
	case timer:now_diff(Now,LastT) div 1000 of
		Dt when Dt>150 ->		% more than 150ms
			kick_out_tos(Now,Us,NUs);
		_ ->
			kick_out_tos(Now,Us,[U1|NUs])
	end.

play_rbt(Tick,_,Tone,Us,_) when Tick rem 2 == 0 ->
	Us1 = [U1||#us{isac=false}=U1<-Us],
	NewUs = lists:map(fun(U) -> send_tone(?PCMU,160,Tone,U) end,Us1),
	NewUs++[U1||#us{isac=true}=U1<-Us];
play_rbt(Tick,Tone,_,Us,ST) when Tick==3 ->
	IsacUs = [U1||#us{isac=true}=U1<-Us],
	NewUs = lists:map(fun(U) -> send_tone(?iSAC,960,Tone,U) end,IsacUs),
	NewUs++[U1||#us{isac=false}=U1<-Us];
play_rbt(_,_,_,Us,_) ->
	Us.

send_tone(Codec,_PTime,Bin,#us{fp=0,pid=Pid}=U) ->
	Pid ! #audio_frame{codec=Codec,marker=true,samples=0,body=get_tone(0,Bin)},
	U#us{fp=1};
send_tone(Codec,PTime,Bin,#us{fp=FP,pid=Pid}=U) ->
	Pid ! #audio_frame{codec=Codec,marker=false,samples=PTime,body=get_tone(FP,Bin)},
	U#us{fp=(FP+1) rem (if Codec==?iSAC -> 100;true -> 300 end)}.

get_tone(0,<<Size:16,Bin/binary>>) ->
	<<Tone:Size/binary,_/binary>> = Bin,
	Tone;
get_tone(FP,<<Size:16,Bin/binary>>) ->
	<<_:Size/binary,Rest/binary>> = Bin,
	get_tone(FP-1,Rest).

% ----------------------------------
write_tone(pcm2ilbc,Ilbc,Bin,FH,PCM_UNIT_LEN) when size(Bin)>=PCM_UNIT_LEN ->
    {Outp,Rest} = split_binary(Bin,PCM_UNIT_LEN),
    EncBin = rrp:ilbc_enc60(Ilbc, Outp),
    Size= size(EncBin),
    Buf = <<Size:16,EncBin/binary>>,
    file:write(FH, Buf),
    write_tone(pcm2ilbc,Ilbc,Rest,FH,PCM_UNIT_LEN);
write_tone(pcm2ilbc,Ilbc,Bin,FH,_)->
    EncBin = rrp:ilbc_enc60(Ilbc, Bin),
    Size= size(EncBin),
    Buf = <<Size:16,EncBin/binary>>,
    file:write(FH, Buf),
    file:close(FH).
    
make_tone(pcm2ilbc,InFileName,OutFileName) ->
	{ok,Bin} = file:read_file(InFileName),
	{ok,FH} = file:open(OutFileName,[write,binary,raw]),
	PCM60ms_len = 2*(8000*60 div 1000),
	{0,Ilbc} =  ?APPLY(erl_ilbc, icdc, [30]) ,
	write_tone(pcm2ilbc,Ilbc,Bin,FH, PCM60ms_len).
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

start() ->
    my_server:start({local,rbt},?MODULE,[],[]).	
    
  to_pcm({pcmu,PCMU})-> to_pcm({pcmu,PCMU},<<>>).
  to_pcm({pcmu,PCMU},R) when size(PCMU) <160 ->   R;
  to_pcm({pcmu,<<H:160/binary,Rest/binary>>},Result)-> 
      New= erl_isac_nb:udec(H),
      to_pcm({pcmu,Rest},<<Result/binary,New/binary>>).
    
