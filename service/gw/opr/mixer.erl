-module(mixer).

-include("desc.hrl").

-compile(export_all).

-define(VADMODE, 3).

-define(MIX_PERIOD, 20).
-define(MIX_SR, 16000).

-record(in, {
    audio_frames=[]
}).

-record(state, {
    sides = #{},      %pid=>[#audio_frame{}]
    common_f = 1.0,
    tmr
}).


has_media(Pid,MediaPid)->
    F=fun(State=#state{sides=Sides})->
            {maps:is_key(MediaPid,Sides),State}
       end,
    act(Pid,F).
get_sides(Pid)->
    F=fun(State=#state{sides=Sides})->
            {Sides,State}
       end,
    act(Pid,F).
%% Extra APIs.
start() ->
    my_server:start(?MODULE, [], []).

stop(Pid) ->
    my_server:cast(Pid, stop).

add(Pid,MediaPid) ->
    my_server:cast(Pid, {add, MediaPid}).

sub(Pid, MediaPid) ->
    my_server:cast(Pid, {sub,MediaPid}).


%% my_server callbacks.
init([]) ->
    {ok, TRef} = my_timer:send_interval(?MIX_PERIOD, mix),
    {ok, #state{tmr=TRef}}.

handle_call({act,Act}, _, State) ->
    {Res,State1} = Act(State),
    {reply,Res,State1};
handle_call(_Call, _From, State) ->
    {noreply,State}.
handle_cast({add, MediaPid}, #state{sides=Sides}=ST) ->
    erlang:monitor(process,MediaPid),
    {noreply, ST#state{sides=Sides#{MediaPid=>[]}}};

handle_cast({sub, MediaPid}, #state{sides=Sides}=ST) ->
    NSides=maps:remove(MediaPid,Sides),
    {noreply, ST#state{sides=NSides}};

handle_cast(stop, #state{tmr=Tmr}) ->
    my_timer:cancel(Tmr),
    {stop, normal, []}.

handle_info({'DOWN', _Ref, process, MediaPid, _Reason},State=#state{sides=Sides})->
    NSides=maps:remove(MediaPid,Sides),
    {noreply,State#state{sides=NSides}};   
handle_info(Frame=#audio_frame{owner=MediaPid},
            #state{sides=Sides}=ST) ->
	case maps:get(MediaPid,Sides,undefined) of
    undefined-> {noreply,ST};
    Frames0->
        NFrames1=Frames0++[Frame],
        {noreply,ST#state{sides=Sides#{MediaPid:=NFrames1}}}
  end;

handle_info(mix, #state{}=ST) ->
    %io:format("mix "),
    % {SmpSums0, Ins} = mix_up(Ins0, Vad),
    % {SmpSums, CF} = convert_common(SmpSums0, CF0),
    % Outs = send_out(SmpSums, Outs0),
    % send_vip(SmpSums, VipOut),
    NST=mix_and_send(ST),
    {noreply, (NST)}.

terminate(normal, _ST) ->
    ok.

mix_and_send(ST=#state{sides=Sides=#{},common_f=_CF})->
    NSides=
    case maps:to_list(Sides) of
      [{Media1,[Frame=#audio_frame{}|T]},{Media2,[]}]-> 
          Media2 ! Frame,
          Sides#{Media1:=T};
      [{Media1,[]},{Media2,[Frame=#audio_frame{}|T]}]->      
          Media1 ! Frame,
          Sides#{Media2:=T};
      [{Media1,[Frame1=#audio_frame{}|T1]},{Media2,[Frame2=#audio_frame{}|T2]}]->      
          Media2 ! Frame1,
          Media1 ! Frame2,
          Sides#{Media1:=T1,Media2:=T2};
      [{Media1,[]},{Media2,[]}]->      
          Sides;
      []-> Sides;
      [{Media1,_}]->      
          Sides#{Media1:=[]}
    end,
    ST#state{sides=NSides}.
%% Inner Methods.
% mix_up(Ins0, Vad) ->
%     {SmpLs, Ins} = collect_samples(Vad, Ins0),
%     {mix_samples(SmpLs), Ins}.

% collect_samples(Vad, Ins0) ->
%     collect_samples(Vad, Ins0, [], []).

% collect_samples(_Vad, [], Bins, Ins) -> {Bins, Ins};
% collect_samples(Vad, [#in{media=M, buf=Buf0}=In0|T], Bins0, Ins0) ->
%     GotLen = ?MIX_SR * ?MIX_PERIOD div 1000 * 2,
%     {Bin, Buf} = 
%         if 
%             size(Buf0) >= GotLen ->
%         	    %<<Got:GotLen/binary, Rest/binary>> = Buf0,
%         	    %{[{M, Got}], Rest};
%                 case pcm16:skip_to_voice_and_get_raw_block(Vad,?MIX_SR,GotLen,<<>>,Buf0) of
%                     {{noise, _B}, Rest} ->
%                         {[], Rest};
%                     {{voice, B}, Rest} ->
%                         {[{M, sample_list(B)}], Rest}
%                 end;
%             true ->
%                 {[], Buf0}
%         end,
%     collect_samples(Vad, T, Bins0++Bin, Ins0++[In0#in{buf=Buf}]).

% sample_list(Bin) -> sample_list(Bin, []).

% sample_list(<<>>, L) -> lists:reverse(L);
% sample_list(<<S:16/signed-little, R/binary>>, L) ->
%     sample_list(R, [S|L]).

% mix_samples(SmpLs) ->
%     SpecBins = lists:map(fun({M, _SampleList}) ->
%                              OtherSLs = lists:keydelete(M, 1, SmpLs),
%                              {M, add_sample_lists(OtherSLs)}
%                          end, SmpLs),
%     SpecBins++[{common, add_sample_lists(SmpLs)}].

% add_sample_lists([]) -> [];
% add_sample_lists([{_M, L}]) -> L;
% add_sample_lists([{_, H}|T]) -> 
%     SumL = lists:foldl(fun({_M, SampleList}, CurL) -> 
%                            add_sample_list(CurL, SampleList) 
%                        end, H, T),
%     SumL.

% add_sample_list(L1, L2) ->
%     lists:map(fun({S1, S2}) -> 
%                   S1+S2
%               end, lists:zip(L1, L2)).

% to_bin(L, F0) ->
%     to_bin(F0, lists:reverse(L), <<>>).

% to_bin(F, [], Bin) -> {Bin, F};
% to_bin(F0, [S0|T], Bin) ->
%     {S, F} = mod(S0, F0),
%     to_bin(F, T, <<S:16/signed-little, Bin/binary>>).

% mod(S, F) ->
%     R = trunc(S * F),
%     if
%         R > 32767 -> {32767, 32767/R};
%         R < -32768 -> {-32768, -32768/R};
%         true -> if 
%                     F < 1.0 -> {R, F+((1.0-F)/32)};
%                     true -> {R, F}
%                 end
%     end.

% mod1(S, F) ->
%     R = S,
%     if
%         R > 32767 -> {32767, F};
%         R < -32768 -> {-32768, F};
%         true -> {R, F}
%     end.

% %
% send_out(SmpSums, Outs0) ->
%     lists:map(fun(#out{media=M, resampler=Rsm0, f=F0}=P0) ->
%                   case get_body(SmpSums, M, F0) of
%                       {<<>>, _F} -> 
%                           P0;
%                       {Body0, F} ->
%                           {Body, SR, Rsm} = 
%                               if Rsm0 /= undefined ->  
%                                     resampler:do(Body0, ?MIX_SR, Rsm0);
%                               true -> {Body0, ?MIX_SR, undefined} end,
%                           M ! #raw_packet{format=pcm16, 
%                                           body=Body, 
%                                           sample_rate=SR,
%                                           sample_count=(?MIX_PERIOD*?MIX_SR div 1000)},
%                           P0#out{resampler=Rsm, f=F}
%                   end
%               end, Outs0).

% convert_common(SmpSums, CF0) ->
%     {common, SmpSum} = lists:keyfind(common, 1, SmpSums),
%     {Bin, CF} = case lists:keyfind(common, 1, SmpSums) of
%                     {common, []} ->
%                         {<<>>, 1};
%                     {common, SmpSum} ->
%                         to_bin(SmpSum, CF0)
%                 end,
%     {lists:keyreplace(common, 1, SmpSums, {common, Bin}), CF}.

% get_body(SmpSums, Media, F0) ->
%     case lists:keyfind(Media, 1, SmpSums) of
%         {Media, []} -> 
%             {<<>>, 1};
%         {Media, SmpSum} -> 
%             to_bin(SmpSum, F0);
%         false ->
%             {common, Bin} = lists:keyfind(common, 1, SmpSums),
%             {Bin, F0}
%     end.

% send_vip(SmpSums, VipOut) ->
%     {common, Bin} = lists:keyfind(common, 1, SmpSums),
%     if size(Bin) == 0 -> pass;
%     true ->
%         VipOut ! #raw_packet{format=pcm16, 
%                              body=Bin, 
%                              sample_rate=?MIX_SR,
%                              sample_count=(?MIX_PERIOD*?MIX_SR div 1000)}
%     end,
%     ok.

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



act(Pid,Act)->    my_server:call(Pid,{act,Act}).