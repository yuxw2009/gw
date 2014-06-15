-module(codec).
-compile(export_all).

-define(FS8K,8000).
-define(FS16K,16000).

-define(PCMU,0).
-define(G729,18).
-define(u16K,80).
-define(iLBC,102).
-define(AMR,114).
-define(iSAC,103).
-define(L16K,108).
-define(L8K,107).
-define(VADMODE,3).

-record(ctx,{
	id,
	vad,
	trace=voice,
	d_packets=0,
	d_losts=0,
	passed= <<>>,	% passed raw data. For recovery
	e_packets=0		% encoded 30ms packets
}).

init_codec(?iSAC,[Mode,BitRate,PTime]) ->		% ptime @timestamp_samples
	{0,Id} = erl_isac_nb:icdc(Mode,BitRate,PTime),
	{0,Vad} = erl_vad:ivad(),
	0 = erl_vad:xset(Vad,?VADMODE),				%% aggresive mode
	{ok,#ctx{id=Id,vad=Vad},PTime div (?FS16K div 1000)};
init_codec(?u16K,_) ->		% ptime @timestamp_samples
	{0,Id} = erl_isac_nb:iu16k(),
	{0,Vad} = erl_vad:ivad(),
	0 = erl_vad:xset(Vad,?VADMODE),
	{ok,#ctx{id=Id,vad=Vad},20};
init_codec(?PCMU,_) ->
	{0,Vad} = erl_vad:ivad(),
	trans:llog("codec get vad:~p",[Vad]),
	0 = erl_vad:xset(Vad,?VADMODE),
	{ok,#ctx{id=0,vad=Vad},20};
init_codec(?G729,_) ->
       {0,Ctx} = erl_g729:icdc(),
	{0,Vad} = erl_vad:ivad(),
	trans:llog("codec get g729: ~p  vad:~p",[Ctx, Vad]),
	0 = erl_vad:xset(Vad,?VADMODE),
	{ok,#ctx{id=Ctx,vad=Vad},20};
init_codec(?iLBC,[PTime]) ->
	{0,Id} = erl_ilbc:icdc(PTime),
	{0,Vad} = erl_vad:ivad(),
	trans:llog("codec get ilbc:~p vad:~p",[Id,Vad]),
	0 = erl_vad:xset(Vad,?VADMODE),
	{ok,#ctx{id=Id,vad=Vad},PTime};
init_codec(?AMR,[DTX,Rate]) ->
	{0,Id} = erl_amr:icdc(DTX,Rate),
	{0,Vad} = erl_vad:ivad(),
	trans:llog("codec get amr:~p vad:~p",[Id,Vad]),
	0 = erl_vad:xset(Vad,?VADMODE),
	{ok,#ctx{id=Id,vad=Vad},120}.

enc(?iSAC,#ctx{id=Id,vad=VAD,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS16K,30)};
					  true -> {false,Pass} end,
	{{_,F1},RestAB} = rrp:get_samples(VAD,?FS16K,30,Passed,AB),
	{0,_,Enc} = erl_isac_nb:xenc(Id,F1),
	{Ctx#ctx{passed=F1},Marker,480,Enc,RestAB};
enc(?u16K,#ctx{id=Id,vad=VAD,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS16K,20)};
					  true -> {false,Pass} end,
	{{_,F1},RestAB} = rrp:get_samples(VAD,?FS16K,20,Passed,AB),
	Enc = erl_isac_nb:ue16k(Id,F1),
	{Ctx#ctx{passed=F1},Marker,160,Enc,RestAB};
enc(?G729,#ctx{id=Id, vad=VAD,trace=Trace,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS8K,20)};
					  true -> {false,Pass} end,
	{{Type,F1},RestAB} = if Trace==noise ->
							rrp:shift_to_voice_and_get_samples(VAD,?FS8K,20,Passed,AB);
						 true ->
						 	rrp:get_samples(VAD,?FS8K,20,Passed,AB)
						 end,
	{0,2,Enc} = erl_g729:xenc(Id, F1),
	{Ctx#ctx{passed=F1,trace=Type},Marker,160,Enc,RestAB};
enc(?PCMU,#ctx{vad=VAD,trace=Trace,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS8K,20)};
					  true -> {false,Pass} end,
	{{Type,F1},RestAB} = if Trace==noise ->
							rrp:shift_to_voice_and_get_samples(VAD,?FS8K,20,Passed,AB);
						 true ->
						 	rrp:get_samples(VAD,?FS8K,20,Passed,AB)
						 end,
	Enc = erl_isac_nb:uenc(F1),
	{Ctx#ctx{passed=F1,trace=Type},Marker,160,Enc,RestAB};
enc(?iLBC,#ctx{id=Id,vad=VAD,trace=Trace,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS8K,30)};
					  true -> {false,Pass} end,
	{{Type,F1},RestAB} = if Trace==noise ->
							rrp:shift_to_voice_and_get_samples(VAD,?FS8K,30,Passed,AB);
						 true ->
						 	rrp:get_samples(VAD,?FS8K,30,Passed,AB)
						 end,
	{0,Enc} = erl_ilbc:xenc(Id,F1),
	{Ctx#ctx{passed=F1,trace=Type},Marker,240,Enc,RestAB};
enc(?AMR,#ctx{id=Id,vad=VAD,trace=Trace,passed=Pass}=Ctx, AB) ->
	{Marker,Passed} = if Pass== <<>> -> {true,rrp:zero_pcm16(?FS8K,120)};
					  true -> {false,Pass} end,
	{{Type,Frame},RestAB} = if Trace==noise ->
							rrp:shift_to_voice_and_get_samples(VAD,?FS8K,120,Passed,AB);
						 true ->
						 	rrp:get_samples(VAD,?FS8K,120,Passed,AB)
						 end,
	{0,Enc} = amr_60_enc(Id,Frame,<<>>),
	{Ctx#ctx{passed=Frame,trace=Type},Marker,960,Enc,RestAB}.

amr_60_enc(_Id,Body,Out) when size(Body)<320 ->
	{0,Out};
amr_60_enc(Id,<<F1:320/binary,Rest/binary>>,Out) ->
	{0,Enc} = erl_amr:xenc(Id,F1),
	amr_60_enc(Id,Rest,<<Out/binary,Enc/binary>>).

plc(?iSAC,#ctx{id=Id,d_losts=Losts}=Ctx,N) ->
	{0,Raw} = erl_isac_nb:xplc(Id,480),
	{ok,Ctx#ctx{d_losts=Losts+N},?L16K,Raw};
plc(?u16K,#ctx{id=_Id,d_losts=Losts}=Ctx,N) ->
	{ok,Ctx#ctx{d_losts=Losts+N},?L16K,rrp:zero_pcm16(?FS16K,20)};
plc(?PCMU,#ctx{id=_Id,d_losts=Losts}=Ctx,N) ->
	{ok,Ctx#ctx{d_losts=Losts+N},?L8K,rrp:zero_pcm16(?FS8K,20)};
plc(?G729,#ctx{id=_Id,d_losts=Losts}=Ctx,N) ->
	{ok,Ctx#ctx{d_losts=Losts+N},?L8K,rrp:zero_pcm16(?FS8K,20)};
plc(?iLBC,#ctx{id=Id,d_losts=Losts}=Ctx,N) ->
	{0,Raw} = erl_ilbc:xplc(Id),
	{ok,Ctx#ctx{d_losts=Losts+N},?L8K,Raw};
plc(?AMR,#ctx{id=_Id,d_losts=Losts}=Ctx,N) ->
	{ok,Ctx#ctx{d_losts=Losts+N},?L8K,rrp:zero_pcm16(?FS8K,120)}.

dec(?iSAC,#ctx{id=Id,d_packets=Pkts}=Ctx,_M,Samples,Body) ->
	{0, Raw} = erl_isac_nb:xdec(Id,Body,Samples,480),			% fix ts_delta, which is only for bw estimate
	{ok,Ctx#ctx{d_packets=Pkts+1},?L16K,Raw};
dec(?u16K,#ctx{id=Id,d_packets=Pkts}=Ctx,_M,_Samples,Body) ->
	Raw = erl_isac_nb:ud16k(Id,Body),
	{ok,Ctx#ctx{d_packets=Pkts+1},?L16K,Raw};
dec(?PCMU,#ctx{d_packets=Pkts}=Ctx,_M,_Samples,Body) ->
	Raw = erl_isac_nb:udec(Body),
	{ok,Ctx#ctx{d_packets=Pkts+1},?L8K,Raw};
dec(?G729,#ctx{id=Id, d_packets=Pkts}=Ctx,_M,_Samples,Body) ->
	{0,Raw} = erl_g729:xdec(Id, Body),
	{ok,Ctx#ctx{d_packets=Pkts+1},?L8K,Raw};
dec(?iLBC,#ctx{id=Id,d_packets=Pkts}=Ctx,_M,_Samples,Body) ->
	{0,Raw} = erl_ilbc:xdec(Id,Body),
	{ok,Ctx#ctx{d_packets=Pkts+1},?L8K,Raw};
dec(?AMR,#ctx{id=Id,d_packets=Pkts}=Ctx,_M,_Samples,Body) ->
	{0,Raw} = amr_60_dec(Id,Body,<<>>),
	{ok,Ctx#ctx{d_packets=Pkts+1},?L8K,Raw}.

amr_60_dec(_Id,Body,Out) when size(Body) < 13 ->
	{0,Out};
amr_60_dec(Id,<<F1:13/binary,Rest/binary>>,Out) ->
	{0,Raw} = erl_amr:xdec(Id,F1),
	amr_60_dec(Id,Rest,<<Out/binary,Raw/binary>>).

destory_codec(?iSAC,#ctx{id=Id,vad=Vad}) ->
	0 = erl_isac_nb:xdtr(Id),
	0 = erl_vad:xdtr(Vad),
	ok;
destory_codec(?u16K,#ctx{id=Id,vad=Vad}) ->
	0 = erl_isac_nb:du16k(Id),
	0 = erl_vad:xdtr(Vad),
	ok;
destory_codec(?PCMU,#ctx{vad=Vad}) ->
	0 = erl_vad:xdtr(Vad),
	ok;
destory_codec(?iLBC,#ctx{id=Id,vad=Vad}) ->
	0 = erl_ilbc:xdtr(Id),
	0 = erl_vad:xdtr(Vad),
	ok;
destory_codec(?G729,#ctx{id=Id,vad=Vad}) ->
	0 = erl_g729:xdtr(Id),
	0 = erl_vad:xdtr(Vad),
	ok;
destory_codec(?AMR,#ctx{id=Id,vad=Vad}) ->
	0 = erl_amr:xdtr(Id),
	0 = erl_vad:xdtr(Vad),
	ok.
	
