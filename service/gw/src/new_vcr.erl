-module(new_vcr).
-compile(export_all).

-define(PCMU,0).
-define(LINEAR,99).
-define(VP8, 100).
-define(DIR, "./new_vcr/").

-define(MIX_PERIOD, 20).
-define(MIX_SR, 8000).

-include("desc.hrl").

-record(in, {
    media,
    buf,
    resampler
}).


-record(st,{
	name,
	ins=[],
      outs = [],
	ah,		% audio handle
	ac,		% audio frame count
	tmr,
      common_f = 1.0,
	bgn		% begin time
}).

vcr_path()-> ?DIR.

start(Name) ->
	{ok,Pid} = my_server:start(?MODULE,[Name],[]),
	Pid.
	

init([{abs,Name}]) ->
     io:format("new_vcr:open:~p~n",[Name]),
    Dir=filename:dirname(Name),
    file:make_dir(Dir),	
    {ok,AH} = file:open(Name, [write,raw,binary]),
    {ok, TRef} = my_timer:send_interval(?MIX_PERIOD, mix_2_file),
	{ok,#st{name=Name,ac=0,ah=AH,bgn=now(),tmr=TRef}};
init([Name]) ->
	init([{abs,vcr_path()++Name++".pcm"}]).
handle_info(mix_2_file, #st{ins=Ins0, ah=FH, common_f=CF0}=ST) ->
    {SmpSum0, Ins} = mix_all(Ins0),
    {Bin, CF} = to_bin(SmpSum0, CF0),
    save_pcmu_frame(FH,Bin),
    {noreply, ST#st{ins=Ins, common_f=CF}};

handle_info(#audio_frame{codec=?LINEAR,body=Body,stream_id=From},#st{ins=Ins0,ac=AC0}=ST) ->
	%io:format("m[~p]", [Body0]),
    case lists:keyfind(From, #in.media, Ins0) of
        #in{buf=Buf0}=In0 ->
            {noreply, ST#st{ac=AC0+1,ins=lists:keyreplace(From, #in.media, Ins0, In0#in{buf= <<Buf0/binary, Body/binary>>})}};
        false ->
            {noreply, ST#st{ac=AC0+1,ins=[#in{buf=Body,media=From}|Ins0]}}
    end;

handle_info(Msg, ST) ->
	io:format("unkn ~p  ",[Msg]),
	{noreply,ST}.

handle_call(stop,_From,ST) ->
	{stop,normal,ok,ST}.

handle_cast(stop,ST) ->
	{stop,normal,ST}.
terminate(normal, #st{name=Name,ac=AC,ah=AH}) ->
	file:close(AH),
	if AC==0-> file:delete(?DIR++Name++".pcm");
	true -> pass end,
%	io:format("new_vcr ~p stopped ~p audio.~n",[Name,AC]),
	ok.

% ----------------------------------	
mkday_dir(Date)->
    {Y,Mo,D} = Date,
    xt:int2(Y)++xt:int2(Mo)++xt:int2(D).
mkvfn(Name) ->
    {H,M,S} = time(),
    Date=mkday_dir(date()),
    NewName=Date++"/"++Name++"_"
             ++xt:int2(H)
             ++xt:int2(M)
             ++xt:int2(S),
    {vcr_path()++NewName++".pcm", NewName++".pcm"}.

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
stop(Pid) when is_pid(Pid) ->
	my_server:call(Pid,stop);
stop(_) -> ok.

new_in(MediaPid, RawSR) ->
    Rsm = if RawSR == ?MIX_SR -> undefined;
             true -> resampler:new(RawSR, ?MIX_SR) end,
    [#in{media=MediaPid, buf= <<>>, resampler=Rsm}].

mix_all(Ins0) ->
    {SmpLs, Ins} = collect_samples_novad(Ins0),
    {add_sample_lists(SmpLs), Ins}.

mix_up(Ins0, Vad) ->
    {SmpLs, Ins} = collect_samples(Vad, Ins0),
    {mix_samples(SmpLs), Ins}.

collect_samples_novad(Ins0) -> collect_samples_novad(Ins0,[],[]).
collect_samples_novad([], Bins, Ins) -> {Bins, Ins};
collect_samples_novad([#in{media=M, buf=Buf0}=In0|T], Bins0, Ins0) ->
    GotLen = ?MIX_SR * ?MIX_PERIOD div 1000 * 2,
    {Bin, Buf} = 
        if 
            size(Buf0) >= GotLen ->
                {B,Rest}=split_binary(Buf0,GotLen),
                {[{M, sample_list(B)}],Rest};
            true ->
                {[], Buf0}
        end,
    collect_samples_novad(T, Bins0++Bin, Ins0++[In0#in{buf=Buf}]).

collect_samples(Vad, Ins0) ->
    collect_samples(Vad, Ins0, [], []).

collect_samples(_Vad, [], Bins, Ins) -> {Bins, Ins};
collect_samples(Vad, [#in{media=M, buf=Buf0}=In0|T], Bins0, Ins0) ->
    GotLen = ?MIX_SR * ?MIX_PERIOD div 1000 * 2,
    {Bin, Buf} = 
        if 
            size(Buf0) >= GotLen ->
        	    %<<Got:GotLen/binary, Rest/binary>> = Buf0,
        	    %{[{M, Got}], Rest};
                case pcm16:skip_to_voice_and_get_raw_block(Vad,?MIX_SR,GotLen,<<>>,Buf0) of
                    {{noise, _B}, Rest} ->
                        {[], Rest};
                    {{voice, B}, Rest} ->
                        {[{M, sample_list(B)}], Rest}
                end;
            true ->
                {[], Buf0}
        end,
    collect_samples(Vad, T, Bins0++Bin, Ins0++[In0#in{buf=Buf}]).

sample_list(Bin) -> sample_list(Bin, []).

sample_list(<<>>, L) -> lists:reverse(L);
sample_list(<<S:16/signed-little, R/binary>>, L) ->
    sample_list(R, [S|L]).

mix_samples(SmpLs) ->
    SpecBins = lists:map(fun({M, _SampleList}) ->
                             OtherSLs = lists:keydelete(M, 1, SmpLs),
                             {M, add_sample_lists(OtherSLs)}
                         end, SmpLs),
    SpecBins++[{common, add_sample_lists(SmpLs)}].

add_sample_lists([]) -> [];
add_sample_lists([{_M, L}]) -> L;
add_sample_lists([{_, H}|T]) -> 
    SumL = lists:foldl(fun({_M, SampleList}, CurL) -> 
                           add_sample_list(CurL, SampleList) 
                       end, H, T),
    SumL.

add_sample_list(L1, L2) ->
    lists:map(fun({S1, S2}) -> 
                  S1+S2
              end, lists:zip(L1, L2)).

to_bin(L, F0) ->
    to_bin(F0, lists:reverse(L), <<>>).

to_bin(F, [], Bin) -> {Bin, F};
to_bin(F0, [S0|T], Bin) ->
    {S, F} = mod(S0, F0),
    to_bin(F, T, <<S:16/signed-little, Bin/binary>>).

mod(S, F) ->
    R = trunc(S * F),
    if
        R > 32767 -> {32767, 32767/R};
        R < -32768 -> {-32768, -32768/R};
        true -> if 
                    F < 1.0 -> {R, F+((1.0-F)/32)};
                    true -> {R, F}
                end
    end.

mod1(S, F) ->
    R = S,
    if
        R > 32767 -> {32767, F};
        R < -32768 -> {-32768, F};
        true -> {R, F}
    end.

%
convert_common(SmpSums, CF0) ->
    {common, SmpSum} = lists:keyfind(common, 1, SmpSums),
    {Bin, CF} = case lists:keyfind(common, 1, SmpSums) of
                    {common, []} ->
                        {<<>>, 1};
                    {common, SmpSum} ->
                        to_bin(SmpSum, CF0)
                end,
    {lists:keyreplace(common, 1, SmpSums, {common, Bin}), CF}.

get_body(SmpSums, Media, F0) ->
    case lists:keyfind(Media, 1, SmpSums) of
        {Media, []} -> 
            {<<>>, 1};
        {Media, SmpSum} -> 
            to_bin(SmpSum, F0);
        false ->
            {common, Bin} = lists:keyfind(common, 1, SmpSums),
            {Bin, F0}
    end.


% 640 bytes of 16#0.
noise_raw() ->
<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>.


% for test
save_amr_hdr(FH) ->
	DKIF = <<"#!AMR\n">>,
	ok = file:write(FH, DKIF).
pcm_to_amr(Fn)->
    {ok,Bin} = file:read_file(Fn),
    to_amr(Bin).
to_amr(PCM)->
    {0,Amr} =  erl_amr:icdc(0,4750) ,
    Out=rrp:amr_enc60(Amr,PCM),
    {ok,FH} = file:open("test.amr", [write,raw,binary]),
    save_amr_hdr(FH),
    file:write(FH,Out),
    file:close(FH).

