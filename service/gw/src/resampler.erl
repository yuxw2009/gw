-module(resampler).

-compile(export_all).

-record(resampler, {
                     prev_high_samples = <<0,0,0,0,0,0,0,0,0,0>>,
                     prev_low_samples = <<0,0,0,0,0,0,0,0,0,0>>,
                     high,
                     low
                    }).

%% Extra APIs.
new(SampleRate, SampleRate) -> #resampler{high=SampleRate, low=SampleRate}; 
new(SampleRate1, SampleRate2) when SampleRate1 < SampleRate2 -> new(SampleRate2, SampleRate1);
new(SampleRate1, SampleRate2) when SampleRate1==16000, SampleRate2==8000 ->
    #resampler{ high=SampleRate1,
                low=SampleRate2}.

delete(#resampler{}) ->
    ok.

do(RawBlock, _, #resampler{high=S, low=S}=Ctx0) -> {RawBlock, S, Ctx0};
do(RawBlock, SampleRate, #resampler{high=SampleRate, low=To}=Ctx0) ->
    NewRawBlock = erl_resample:down8k(RawBlock),
    {NewRawBlock, To, Ctx0};
do(RawBlock, SampleRate, #resampler{low=SampleRate, high=To, prev_low_samples=PrevS}=Ctx0) ->
    NewRawBlock = erl_resample:up16k(RawBlock, PrevS),
    RemLen = size(RawBlock)-10,
    <<_:RemLen/binary, Last5Samples:10/binary>> = RawBlock,
    {NewRawBlock, To, Ctx0#resampler{prev_low_samples=Last5Samples}}.

