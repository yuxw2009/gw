-module(mixer).

-include("packet.hrl").

-compile(export_all).

-define(VADMODE, 3).

-define(MIX_PERIOD, 20).
-define(MIX_SR, 16000).

-record(in, {
    media,
    buf,
    resampler
}).

-record(out, {
    media,
    resampler,
    f = 1.0            % sum factor.
}).

-record(state, {
    ins = [],
    outs = [],
    vip_out = {iSAC, 16000, 16000, undefined},
    vad,
    common_f = 1.0,
    tmr
}).


%% Extra APIs.
start() ->
    my_server:start(?MODULE, [], []).

stop(Pid) ->
    my_server:cast(Pid, stop).

add(Pid, SessPid, Role) ->
    my_server:cast(Pid, {add, SessPid, Role}).

sub(Pid, SessPid) ->
    my_server:cast(Pid, {sub, SessPid}).

set_role(Pid, SessPid, Role) ->
    my_server:cast(Pid, {set_role, SessPid, Role}).

%% my_server callbacks.
init([]) ->
    {0, VAD} = cdc_factory:new(vad, [?VADMODE]),
    {VipCdc, VipSR, VipRawSR} = {iSAC, 16000, 16000},
    {ok, VipOut} = broadcaster:new({pcm16, ?MIX_SR}, {VipCdc, VipSR, VipRawSR}),
    {ok, TRef} = my_timer:send_interval(?MIX_PERIOD, mix),
    {ok, #state{vad=VAD, vip_out={VipCdc, VipSR, VipRawSR, VipOut}, tmr=TRef}}.

handle_cast({add, SessPid, Role}, #state{ins=Ins, outs=Outs, vip_out={VipPtN, VipSR, VipRawSR, VipOut}}=ST) ->
    {MediaPid, {PtN, SR, RawSR}} = session:get_media_info(SessPid, audio),
    %io:format("Role:~p.~n", [Role]),
    {In, Out} = 
        if 
            Role == speaker -> 
                {new_in(MediaPid, RawSR), new_out(MediaPid, RawSR)};
            true -> 
                if
                    PtN == VipPtN, SR == VipSR, RawSR == VipRawSR ->
                        ok = broadcaster:add(VipOut, SessPid, out),
                        {[], []};
                    true ->
                        {[], new_out(MediaPid, RawSR)}
                end 
        end,
    session:set_exchange(SessPid, audio, {self(), pcm16, MediaPid}),
    {noreply, ST#state{ins=Ins++In, outs=Outs++Out}};

handle_cast({sub, SessPid}, #state{ins=Ins0, outs=Outs0, vip_out={_VipPtN, _VipSR, _VipRawSR, VipOut}}=ST) ->
    {MediaPid, {_PtN, _SR, _RawSR}} = session:get_media_info(SessPid, audio),
    session:clear_exchange(SessPid, audio),
    Ins = lists:keydelete(MediaPid, #in.media, Ins0),
    Outs = lists:keydelete(MediaPid, #in.media, Outs0),
    broadcaster:sub(VipOut, SessPid, out),
    {noreply, ST#state{ins=Ins, outs=Outs}};

handle_cast({set_role, SessPid, Role}, #state{ins=Ins0, outs=Outs0, vip_out={VipPtN, VipSR, VipRawSR, VipOut}}=ST) ->
    {MediaPid, {PtN, SR, RawSR}} = session:get_media_info(SessPid, audio),
    case lists:keyfind(MediaPid, #in.media, Ins0) of
        #in{} ->
            if 
                Role == listener -> 
                    Outs = if
                               PtN == VipPtN, SR == VipSR, RawSR == VipRawSR ->
                                   ok= broadcaster:add(VipOut, SessPid, out),
                                   lists:keydelete(MediaPid, #out.media, Outs0);
                               true ->
                                   Outs0
                           end,
                    {noreply, ST#state{ins=lists:keydelete(MediaPid, #in.media, Ins0), outs=Outs}};
                true -> 
                    {noreply, ST} 
            end;
        false ->
            if 
                Role == speaker ->
                    Outs = case lists:keyfind(MediaPid, #out.media, Outs0) of
                               #out{} ->
                                   Outs0;
                               false ->
                                   broadcaster:sub(VipOut, SessPid, out),
                                   Outs0++new_out(MediaPid, RawSR)
                           end, 
                    {noreply, ST#state{ins=Ins0++new_in(MediaPid, RawSR), outs=Outs}};
                true -> 
                    {noreply, ST} 
            end
    end;

handle_cast(stop, #state{vad=VAD, vip_out={_VipPtN, _VipSR, _VipRawSR, VipOut}, tmr=Tmr}) ->
    0 = cdc_factory:delete(vad, VAD),
    broadcaster:delete(VipOut),
    my_timer:cancel(Tmr),
    {stop, normal, []}.

handle_info({#raw_packet{format=pcm16, sample_rate=SR0, body=Body0}, From},
            #state{ins=Ins0}=ST) ->
	%io:format("m[~p]", [Body0]),
    case lists:keyfind(From, #in.media, Ins0) of
        #in{buf=Buf0, resampler=Rsm0}=In0 ->
            {Body, _, Rsm} = 
                if Rsm0 == undefined, SR0 == ?MIX_SR ->
                    {Body0, SR0, undefined};
                true -> resampler:do(Body0, SR0, Rsm0) end,
            {noreply, ST#state{ins=lists:keyreplace(From, #in.media, Ins0, In0#in{buf= <<Buf0/binary, Body/binary>>, resampler=Rsm})}};
        false ->
            {noreply, ST}
    end;

handle_info(mix, #state{ins=Ins0, outs=Outs0, vad=Vad, common_f=CF0, vip_out={_, _, _, VipOut}}=ST) ->
    {SmpSums0, Ins} = mix_up(Ins0, Vad),
    {SmpSums, CF} = convert_common(SmpSums0, CF0),
    Outs = send_out(SmpSums, Outs0),
    send_vip(SmpSums, VipOut),
    {noreply, ST#state{ins=Ins, outs=Outs, common_f=CF}}.

terminate(normal, _ST) ->
    ok.

%% Inner Methods.
new_out(MediaPid, RawSR) ->
    Rsm = if RawSR == ?MIX_SR -> undefined;
             true -> resampler:new(RawSR, ?MIX_SR) end,
    [#out{media=MediaPid, resampler=Rsm}].

new_in(MediaPid, RawSR) ->
    Rsm = if RawSR == ?MIX_SR -> undefined;
             true -> resampler:new(RawSR, ?MIX_SR) end,
    [#in{media=MediaPid, buf= <<>>, resampler=Rsm}].

mix_up(Ins0, Vad) ->
    {SmpLs, Ins} = collect_samples(Vad, Ins0),
    {mix_samples(SmpLs), Ins}.

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
send_out(SmpSums, Outs0) ->
    lists:map(fun(#out{media=M, resampler=Rsm0, f=F0}=P0) ->
                  case get_body(SmpSums, M, F0) of
                      {<<>>, _F} -> 
                          P0;
                      {Body0, F} ->
                          {Body, SR, Rsm} = 
                              if Rsm0 /= undefined ->  
                                    resampler:do(Body0, ?MIX_SR, Rsm0);
                              true -> {Body0, ?MIX_SR, undefined} end,
                          M ! #raw_packet{format=pcm16, 
                                          body=Body, 
                                          sample_rate=SR,
                                          sample_count=(?MIX_PERIOD*?MIX_SR div 1000)},
                          P0#out{resampler=Rsm, f=F}
                  end
              end, Outs0).

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

send_vip(SmpSums, VipOut) ->
    {common, Bin} = lists:keyfind(common, 1, SmpSums),
    if size(Bin) == 0 -> pass;
    true ->
        VipOut ! #raw_packet{format=pcm16, 
                             body=Bin, 
                             sample_rate=?MIX_SR,
                             sample_count=(?MIX_PERIOD*?MIX_SR div 1000)}
    end,
    ok.

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

