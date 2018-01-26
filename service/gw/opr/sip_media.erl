-module(sip_media).    % the relay rtp with buffer module
-compile(export_all).

-include("sdp.hrl").

-include("erl_debug.hrl").
-define(RTPHEADLENGTH,12).
-define(RTCPHEADLENGTH,8).

-define(FS16K,16000).
-define(FS8K,8000).
-define(PTIME,20).
-define(PSIZE,160).
-define(ISACPTIME,30).
-define(ILBCPTIME,30).
-define(OPUSPTIME,60).
-define(AMRPTIME,40).

-define(PCMU,0).
-define(PCMA,8).
-define(LINEAR,99).
-define(G729,18).
-define(CN,13).
-define(PHN,101).
-define(iLBC,102).
-define(iSAC,103).
-define(iCNG,105).
-define(L16,107).
-define(OPUS,111).
-define(AMR,114).
-define(LOSTiSAC,1003).

-define(VADMODE,3).

-define(ILBCFRAMESIZE,50).
-define(PT160,160).

-define(V29BUFLEN, 120).    % chrome v29 voice buf length = 120ms
-define(VBUFOVERFLOW,2000). % voice buf overflow length = 2000ms

-define(STAT_INTERVAL, 1000).

-include("desc.hrl").

-record(apip, {        % audio pipe-line
    trace,            % voice / noise
    noise_deep,        % noise:1,2,3  voice:-1,0
    noise_duration,    % 1,2 = 0,1,2  3 = 0,1,2,3
    abuf,            % PCM16 audio buf, as isac_nb used, the sample-rate here is 8Khz
    passed,            % passed voice samples
    last_samples,    % for lost frame recovery
    vad,
    cnge,
    cngd,
    cdc
}).

-record(ev,{
    actived = false,
    step,
    tcount,            % count tone in samples
    gcount,            % count gap
    t_begin,
    t_end,            % used for tone gap
    nu,
    vol,
    dura,
    queue = []
}).

-record(packet_stats,{up_udppkts=0,last_up_udppkts=0,up_udpbytes=0,last_up_udpbytes=0,
                       down_udppkts=0,last_down_udppkts=0,down_udpbytes=0,last_down_udpbytes=0,
                       up_rtppkts=0,last_up_rtppkts=0,up_rtpbytes=0,last_up_rtpbytes=0,
                       down2rtppkts=0,last_down2rtppkts=0,down2rtpbytes=0,last_down2rtpbytes=0}).

-record(st, {
    sendcount=0,
    rcvcount=0,
      localport,
    session,
    webcodec,
    sipcodec,
    socket,
    peer,
    peerok=false,
    media,        % rtp <-> media (Pid)
    r_base,
    in_stream,    % local media audio_desc
    snd_pev = #ev{},    % rtp send phone event
    rcv_pev = #ev{},    % udp received phone event
    u2sip = <<>>,
    passu,
    noise,
    vcr,
    dual_vcr,
    newvcr,
    newvcr1,
    rtpvcr,
    vcr_buf= <<>>,    % temp store web audio
    sip_buf= <<>>,    % temp store sip audio
    timer,
    timeru,
    monitor,
    udp_froms=sets:new(),
    stats=#packet_stats{},
    to_sip,        % isac -> pcmu -> MG9000
  owner,
    to_web      % pcmu -> isac -> webrtc
}).

start_dual_record(Rrp,Vcr)->    if is_pid(Rrp)-> Rrp ! {start_dual_record,Vcr}; true-> not_alive end.

init([Session,Socket,_Vcr,Port,Owner]) ->
    SipCdc=rrp_get_sip_codec(),
    Noise = tone:cn_pcm(),
    ST1=#st{noise=Noise},
    SipC=SipCdc,
    erlang:monitor(process,Owner),
    {ok,ST1#st{sipcodec=SipC,session=Session,socket=Socket,localport=Port,owner=Owner,r_base=#base_info{timecode=0}}}.


handle_call({act,Act},_From, ST=#st{}) ->
    try Act(ST) of
    {Res,NST}->
        {reply,Res,NST}
    catch
      Error:Reason->
          utility1:log("sip_media: act error:~p~n",[{Error,Reason}]),
        {reply,Error,ST}
    end;
handle_call({set_peer_addr,{IP,Port}},_From,ST) ->
    IPRecord=
        case string:tokens(IP, ".") of
        [A,B,C,D]-> {list_to_integer(A),list_to_integer(B),list_to_integer(C),list_to_integer(D)};
        _->IP
        end,

    WallClock = os:timestamp(),
    Timecode = init_rnd_timecode(),
    BaseRTP = #base_rtp{ssrc = init_rnd_ssrc(),
                        seq = init_rnd_seq(),
                        base_timecode = Timecode,
                        timecode = Timecode,
                        wall_clock = WallClock},        
    {reply,ok,ST#st{peer={IPRecord,Port},peerok=true,in_stream=BaseRTP}};
handle_call(stop, _From, #st{vcr=VCR, timer=TR,timeru=TRU,newvcr=Nvcr}=ST) ->
    llog1(ST,"rrtp ~p stopped.",[ST#st.session]),
    vcr:stop(VCR),
    vcr:stop(Nvcr),
    my_timer:cancel(TR),
    if TRU=/=undefined -> my_timer:cancel(TRU); true->pass end,
    {stop,normal, ok, ST#st{peerok=false}};
handle_call(_Call, _From, ST) ->
    {noreply,ST}.    
    
handle_info(stats,ST)->
%    io:format("|"),
    NewST = stats_log(ST),
    {noreply,NewST};
handle_info({play,undefined}, ST) ->
    WallClock = os:timestamp(),
    Timecode = init_rnd_timecode(),
    BaseRTP = #base_rtp{ssrc = init_rnd_ssrc(),
                        seq = init_rnd_seq(),
                        base_timecode = Timecode,
                        timecode = Timecode,
                        wall_clock = WallClock},
    WCdc = ST#st.webcodec,
    llog1(ST,"play ~p",[WCdc]),
    my_timer:cancel(ST#st.timer),
      %{ok,_} = my_timer:send_after(60,delay_pcmu_to_sip),
      {noreply,ST#st{in_stream=BaseRTP,u2sip= <<>>,media=undefined}};
handle_info({play,WebRTP}, ST) ->
    %%io:format("RRP get webrtc ~p.~n",[WebRTP]),
    WallClock = os:timestamp(),
    Timecode = init_rnd_timecode(),
    BaseRTP = #base_rtp{ssrc = init_rnd_ssrc(),
                        seq = init_rnd_seq(),
                        base_timecode = Timecode,
                        timecode = Timecode,
                        wall_clock = WallClock},

    my_timer:cancel(ST#st.timer),

    if is_pid(WebRTP)-> erlang:monitor(process, WebRTP); true-> void end,
    {noreply,ST#st{media=WebRTP,in_stream=BaseRTP,u2sip= <<>>}};
handle_info(delay_pcmu_to_sip, ST) ->
    my_timer:cancel(ST#st.timeru),
%    io:format("delay_pcmu_to_sip received!~n"),
    %{ok,TR} = my_timer:send_interval(?PTIME,pcmu_to_sip),
    {noreply,ST};
handle_info({deplay,MediaPid}, #st{timer=TR,timeru=TRU,media=MediaPid0}=ST) ->
    %%io:format("RRP leave rtp: ~p.~n",[WebRTP]),
    my_timer:cancel(TR),
    if TRU=/=undefined -> my_timer:cancel(TRU); true->pass end,
    Media1=if MediaPid0==MediaPid-> undefined; true-> MediaPid0 end,
    {noreply,ST#st{media=Media1}};
handle_info({pause,_WebRTP}, #st{timer=TR,timeru=TRU}=ST) ->
    %%io:format("RRP leave rtp: ~p.~n",[WebRTP]),
    my_timer:cancel(TR),
    if TRU=/=undefined -> my_timer:cancel(TRU); true->pass end,
    {noreply,ST};
%
% send phone event to sip
%
handle_info({send_phone_event,Nu,Vol,Dura},#st{snd_pev=SPEv}=ST) ->
    utility:my_print("send DTMF ~p~n",[{ST#st.session,SPEv,Nu,Vol,Dura}]),
    SPEv2 = if SPEv#ev.actived==false -> 
                #ev{actived=true,step=init,t_begin=os:timestamp(),nu=Nu,vol=Vol,dura=Dura};
            true ->
                InQ = SPEv#ev.queue,
                SPEv#ev{queue=InQ++[{Nu,Vol,Dura}]}
            end,
    {noreply,ST#st{snd_pev=SPEv2}};
handle_info({start_dual_record,NVcr1},#st{dual_vcr=DualVcr}=ST) ->
    vcr:stop(DualVcr),
    io:format("rrp rec start_dual_record:~p~n",[NVcr1]),
    {noreply,ST#st{dual_vcr=NVcr1}};
%
%
% udp received   second-dial
%
handle_info({udp,_Socket,Addr,Port,<<2:2,_:6,Mark:1,?PHN:7,Seq:16,TS:32,SSRC:4/binary,Info:4/binary,_/binary>>},
            #st{media=OM,r_base=#base_info{seq=LastSeq,timecode=LastTs},rcv_pev=RPEv,peer={Addr,Port}}=ST) ->
%    <<Nu:8,IsEnd:1,_IsRsv:1,Volume:6,Dura:16>> = Info,
      NewSt=record_ip_port(ST,{Addr,Port}),
      
    M = if Mark==0 -> false; true-> true end,
    RPEv2 = processRPE(RPEv,{LastSeq,LastTs},{Seq,TS},M,Info),
    Random=get_random_160s(ST#st.noise),
    {noreply,NewSt#st{r_base=#base_info{seq=Seq,timecode=TS},rcv_pev=RPEv2}};
% sip@pcmu old(test) version,no voice_buf version
handle_info({udp,_Sck,Addr,Port,<<2:2,_:6,_Mark:1,PN:7,Seq:16,TS:32,SSRC:4/binary,Body/binary>>},
            #st{media=OM,r_base=#base_info{seq=LastSeq},peer={_Addr,_Port},rcvcount=RC}=ST)
            when PN==?PCMU;PN==?G729;PN==?PCMA ->
    %io:format("."),
      NewSt=record_ip_port(ST,{Addr,Port}),
    {PCMU,PCM} = if PN==?PCMU -> {Body,?APPLY(erl_isac_nb, udec, [Body])};
                 true -> Linear = uncompress_voice(ST#st.sipcodec,PN,Body,ST),
                         {?APPLY(erl_isac_nb, uenc, [Linear]),Linear}
                 end,
    Frame = #audio_frame{codec = ?PCMU, body = PCMU,samples=?PSIZE,pcm=PCM},
    if is_pid(OM) -> OM ! Frame;
    true -> pass end,
    processVCR_rrp(ST#st.newvcr1,ST#st.vcr_buf,PCM),
    processVCR_rrp(ST#st.newvcr,ST#st.vcr_buf,PCM),
    {noreply,NewSt#st{rcvcount=RC+1, r_base=#base_info{seq=Seq,timecode=TS}}};
% sip@isac/opus/ilbc   send rtppacket yxw
handle_info(UdpMsg={udp,_Sck,Addr,Port,<<2:2,_:6,_Mark:1,PN:7,_Seq:16,_TS:32,_SSRC:4/binary,_Body/binary>> =_Bin},
            #st{peer=undefined}=ST)  when PN==?PCMU;PN==?G729;PN==?PCMA ->
            if is_pid(ST#st.vcr)-> ST#st.vcr ! #audio_frame{codec=?LINEAR,body=ST#st.vcr_buf,samples=?PSIZE}; true-> void end,
            handle_info(UdpMsg, ST#st{peer={Addr,Port},vcr_buf= <<>>});
handle_info({udp,_Sck,Addr,Port,<<2:2,_:6,_Mark:1,PN:7,Seq:16,TS:32,_SSRC:4/binary,Body/binary>> =Bin},
            #st{webcodec=Wcdc,media=OM,r_base=#base_info{seq=LastSeq},to_web=ToWeb,passu=PsU,peer={_Addr0,_Port0}}=ST)
            when PN==?PCMU;PN==?G729;PN==?PCMA ->
%      io:format("x"),
      NewStats=down_udp_stats(ST#st.stats,Bin),
      NewSt=record_ip_port(ST#st{stats=NewStats},{Addr,Port}),
      PCM0 = uncompress_voice(ST#st.sipcodec,PN,Body,ST),
      PCM=adjust_gain(PCM0),
      processVCR_rrp(ST#st.newvcr1,ST#st.vcr_buf,PCM),
      processVCR_rrp(ST#st.newvcr,ST#st.vcr_buf,PCM),
      processVCR_rrp(ST#st.vcr,ST#st.vcr_buf,PCM),
    AB = ToWeb#apip.abuf,
    if size(AB) > ?VBUFOVERFLOW * (?FS8K div 1000) * 2 ->
           {noreply,NewSt#st{r_base=#base_info{seq=Seq,timecode=TS}}};
    true ->
        if Wcdc==isac ->
            PCM16_16K = if LastSeq==undefined -> ?APPLY(erl_resample, up16k, [PCM,<<0,0,0,0,0,0,0,0,0,0>>]);
                                   size(PsU) < 10 -> ?APPLY(erl_resample, up16k, [PCM,<<0,0,0,0,0,0,0,0,0,0>>]);
                        true -> ?APPLY(erl_resample, up16k, [PCM,PsU]) end,
            Abuf2 = <<AB/binary,PCM16_16K/binary>>,
            PsU2 = 
                case PCM of
                <<_:310/binary,PsU2_/binary>> -> PsU2_;
                _->  <<0,0,0,0,0,0,0,0,0,0>>
                end,
            {noreply,NewSt#st{r_base=#base_info{seq=Seq,timecode=TS},to_web=ToWeb#apip{abuf=Abuf2},passu=PsU2}};
        true ->     % ilbc or opus
            Abuf2 = <<AB/binary,PCM/binary>>,
%            io:format("."),
            {noreply,NewSt#st{r_base=#base_info{seq=Seq,timecode=TS},to_web=ToWeb#apip{abuf=Abuf2}}}
        end
    end;
handle_info({udp,_,Addr,Port,<<2:2,_:6,_:1,PN:7,_:16,_:32,_:4/binary,_/binary>>}, ST) when PN==?CN ->
%            io:format("*"),
    {noreply,record_ip_port(ST,{Addr,Port})};
handle_info({udp,_,Addr,Port,B},ST) ->
            io:format("#",[]),
    llog1(ST,"unexcept binary from ~p:~p~n~p~n",[Addr,Port,B]),
    {noreply,record_ip_port(ST,{Addr,Port})};
%
%   isac codec (wcg -> sip)
%
handle_info(#audio_frame{codec=?LOSTiSAC,samples=_N},#st{to_sip=#apip{abuf=AB,cdc=Isac,last_samples=LastSamples}=ToSip}=ST) ->
    {noreply,ST}; % #st{to_sip=ToSip#apip{abuf=AB2}}};
handle_info(AudioFrame=#audio_frame{},ST=#st{}) -> 
%    send_2_monitor(Mon,AudioFrame),
    R=handle_audio_frame(AudioFrame,ST),
    R;
%
handle_info({'DOWN', _Ref, process, Media, _Reason}, ST=#st{media=Media}) ->
    {noreply,ST#st{media=undefined}};
handle_info({'DOWN', _Ref, process, Owner, _Reason}, ST=#st{owner=Owner}) ->
    {stop,owner_crash,ST};
handle_info(Msg, ST) ->
    llog1(ST,"rrp unexcept msg ~p ~p.~n",[Msg,ST#st.webcodec]),
    {noreply,ST}.
handle_cast(_,St)-> {noreply,St}.
terminate(_Reason,St =#st{vcr=VCR,newvcr=NVCR,newvcr1=NVCR1,rtpvcr=RVCR,dual_vcr=Vcr1}) ->
    %io:format("rrp terminate reason:~p~n",[Reason]),
    vcr:stop(Vcr1), 
    vcr:stop(VCR),  
    vcr:stop(NVCR), 
    vcr:stop(NVCR1),    
    vcr:stop(RVCR), 
    ok.

record_ip_port(St=#st{udp_froms=Froms,peer=Peer,monitor=Mon,localport=LocalPort}, Peer1={Addr,Port})->
    NewFroms = 
    case sets:is_element(Addr,Froms) of
    false->    
        if Peer=/= Peer1-> 
%              F=fun({Ip,P})-> trans:make_ip_str(Ip)++":"++integer_to_list(P);
%                      (O)-> utility:term_to_list(O) end,
%           llog1(St,"unexpected_mgsid_peer:udp peer:~p sdppeer:~p",[Peer1,Peer]);
            ok;
%           send_msg(Mon,{unexpected_mgsid_peer,[xt:dt2str(erlang:localtime()),F(Peer1), F(Peer),LocalPort,atom_to_list(node())]});
              true-> void
     end,
%        send_msg(Mon,{mgside_peerip,trans:make_ip_str(Addr)}),
%        NormalMgIp = if Peer==undefined-> "undefined"; true-> {Addr0,Port0} = Peer, trans:make_ip_str(Addr0) end,
%        send_msg(Mon,{normal_mgip,NormalMgIp}),
        sets:add_element(Addr,Froms);
    _-> Froms
    end,
    St#st{udp_froms=NewFroms}.

%
% sip pcmu <-> web pcmu with cng (old version)
%
handle_audio_frame(#audio_frame{codec=Codec},#st{webcodec=pcmu,peerok=false} = ST) when Codec==?PCMU;Codec==?CN ->
    io:format("2"),
    {noreply,ST};
handle_audio_frame(Frame=#audio_frame{codec=?PCMU,body=_Body}, #st{}=ST) ->
    % io:format("a"),
    NST=send_pcmu(Frame,ST),
    {noreply, NST};
handle_audio_frame(Frame=#audio_frame{codec=?CN}, #st{noise=Noise}=ST) ->
    Body=get_random_160s(Noise),
    NST=send_pcmu(Frame#audio_frame{body=Body},ST),
    {noreply, NST};
handle_audio_frame(#audio_frame{}=Frame,ST) ->
    llog1(ST,"rrp unexcept audio_frame ~p #st.webcodec:~p.~n",[Frame, ST#st.webcodec]),
    {noreply, ST}.
    

erl_cng_xenc(CNGE,ND1,0) ->
    case ?APPLY(erl_cng, xenc, [CNGE,ND1,0]) of
        {0,<<>>} -> ok;
        {0,Sid} -> llog("~p cng unexpected out ~p",[self(),Sid])
    end,
    {0,<<>>}.

ilbc_dec_pkgs(Ilbc, Body, Out) when size(Body) >= ?ILBCFRAMESIZE ->
    <<F1:?ILBCFRAMESIZE/binary,Rest/binary>> = Body,
    {0,Adec} = ?APPLY(erl_ilbc, xdec, [Ilbc,F1]),
    ilbc_dec_pkgs(Ilbc,Rest,<<Out/binary,Adec/binary>>);
ilbc_dec_pkgs(_,_,Out) ->
    Out.

ilbc_enc60(Ilbc,<<F1:480/binary,F2:480/binary>>) ->
    {0,Aenc1} = ?APPLY(erl_ilbc, xenc, [Ilbc,F1]),
    {0,Aenc2} = ?APPLY(erl_ilbc, xenc, [Ilbc,F2]),
    <<Aenc1/binary,Aenc2/binary>>.
    
amr_dec(_Id,Body,Out) when size(Body) < 13 ->
    {0,Out};
amr_dec(Id,<<F1:13/binary,Rest/binary>>,Out) ->
    {0,Raw} =  ?APPLY(erl_amr, xdec, [Id,F1]) ,
    amr_dec(Id,Rest,<<Out/binary,Raw/binary>>).

amr_enc60(Id,Body)-> amr_60_enc(Id,Body,<<>>).
amr_60_enc(_Id,Body,Out) when size(Body)<320 ->
    Out;
amr_60_enc(Id,<<F1:320/binary,Rest/binary>>,Out) ->
    {0,Enc} =  ?APPLY(erl_amr, xenc, [Id,F1]) ,
    amr_60_enc(Id,Rest,<<Out/binary,Enc/binary>>).

% ----------------------------------
%
flush_msg_pev(Msg) ->
    receive Msg -> flush_msg_pev(Msg)
     after 0 -> ok
     end,
     pass.
flush_msg(Msg) ->
%    receive Msg -> flush_msg(Msg)
%     after 0 -> ok
%     end,
     pass.

mkday_dir(Date)->
    {Y,Mo,D} = Date,
    xt:int2(Y)++xt:int2(Mo)++xt:int2(D).
mkvfn(Name) ->
    {H,M,S} = time(),
    Date=mkday_dir(date()),
    Date++"/"++Name++"_"
             ++xt:int2(H)
             ++xt:int2(M)
             ++xt:int2(S).

llog1(ST=#st{peer=Peer},F,P)->
    llog("ip:~p "++F, [Peer|P]).

llog(F,P) -> llog:log(F,P).

compress_voice(pcma,BodyL) ->
    Enc = ?APPLY(erl_isac_nb, uenc, [BodyL]),
    {?PCMA,tc:pcmMu2A(Enc)};
compress_voice(pcmu,BodyL) ->
    Enc = ?APPLY(erl_isac_nb, uenc, [BodyL]),
    {?PCMU,Enc};
compress_voice({g729,Ctx},BodyL) ->
    {0,2,Enc} = ?APPLY(erl_g729, xenc, [Ctx,BodyL],[Ctx]),
    {?G729,Enc}.

uncompress_voice(pcma,?PCMA,BodyA,_ST) when size(BodyA)==160; size(BodyA) == 80->
    BodyU=tc:pcmA2Mu(BodyA),
    BodyL = ?APPLY(erl_isac_nb, udec, [BodyU]),
    BodyL;
uncompress_voice(pcmu,?PCMA,BodyA,_ST)->
%    io:format("*"),
    BodyU=tc:pcmA2Mu(BodyA),
    uncompress_voice(pcmu,?PCMU,BodyU,_ST);
uncompress_voice(pcmu,?PCMU,BodyU,_ST) when size(BodyU) < 80->   <<>>;
uncompress_voice(pcmu,?PCMU,<<BodyU:80/binary, Rest/binary>>,ST) ->
    BodyL = ?APPLY(erl_isac_nb, udec, [BodyU]),
    RestPcm=uncompress_voice(pcmu,?PCMU,Rest,ST),
    <<BodyL/binary,RestPcm/binary>>;
    
%uncompress_voice({g729,Ctx},?G729,Body,_ST) when size(Body)==2 ->
%    {0,<<Body1:160/binary,_/binary>>} = ?APPLY(erl_g729, xdec, [Ctx,Body]),
%    {0,<<Body2:160/binary,_/binary>>} = ?APPLY(erl_g729, xdec, [Ctx,Body]),
%    <<Body1/binary,Body2/binary>>;
uncompress_voice({g729,Ctx},?G729,<<Body:10/binary,Other/binary>>,ST)->
    {0,<<Body1:160/binary,_/binary>>} = ?APPLY(erl_g729, xdec, [Ctx,Body]),
    Body2 =uncompress_voice({g729,Ctx},?G729,Other,ST),
    <<Body1/binary,Body2/binary>>;
uncompress_voice(Type0,Type1,Body,_St) when size(Body)==2 orelse size(Body)==0->
    <<>>;
uncompress_voice(Type0,Type1,Body,_St)->
%    io:format("Type0:~p,Type1:~p,Bodysize:~p~n",[Type0,Type1,size(Body)]),
    <<>>.

zero_pcm16(Freq,Time) ->
    Samples = Time * Freq div 1000,
    list_to_binary(lists:duplicate(Samples*2,0)).

shift_for_real_ts(PCM16,Samples) ->
    Bytes = size(PCM16),
    if Bytes=<Samples*2 ->
        PCM16;        % time passed, recovery is not needed
    true ->
        {_,Out} = split_binary(PCM16,Bytes-Samples*2),
        Out
    end.

generate_noise_nb(CNGD,Samples,Noise) when Samples=<640 ->
    {0,NN} = ?APPLY(erl_cng, xgen, [CNGD,Samples]),
    <<Noise/binary,NN/binary>>;
generate_noise_nb(CNGD,Samples,Noise) ->
    {0,NN} = ?APPLY(erl_cng, xgen, [CNGD,640]),
    generate_noise_nb(CNGD,Samples-640,<<Noise/binary,NN/binary>>).

get_nearest_samples(0,Freq,Dura,Passed) ->
    Samples = Freq*Dura div 1000,
    get_nearest_samples(0,Samples*2,Passed).

get_nearest_samples(Jump,Bytes,PCM16) when size(PCM16)==Bytes ->
    {Jump,PCM16};
get_nearest_samples(Jump,Bytes,PCM16) ->
    <<_:Bytes/binary,Rest/binary>> =PCM16,
    get_nearest_samples(Jump+1,Bytes,Rest).

shift_to_voice_keep_get_samples(Vad,Freq,Dura,PrevAB,AB) ->
    KeepSize = ?V29BUFLEN * (Freq div 1000) * 2,
    Samples = Freq * Dura div 1000,
    Bytes30ms = 2*Freq*30 div 1000,
    Bytes10ms = 2*Freq*10 div 1000,
    if
        size(AB) > Samples*2+Bytes30ms+KeepSize ->
            {F10ms,Rest} = split_binary(AB,Bytes10ms),
             case voice_type(Freq,Vad,F10ms) of
                 unactive ->
                       shift_to_voice_keep_get_samples(Vad,Freq,Dura,PrevAB,Rest);        % just drop noise left previousAB to be unchanged
                actived ->
                        get_voice_samples(Vad,Freq,Samples*2,PrevAB,AB)
             end;
        size(AB) < KeepSize ->
%             io:format("p"),
             {{voice, PrevAB},AB};
        true ->
            get_samples2(Vad,Freq,Samples*2,PrevAB,AB)
    end.


shift_to_voice_and_get_samples(Vad,Freq,Dura,PrevAB,AB) ->
    Samples = Freq * Dura div 1000,
    Bytes10ms = 2*Freq*10 div 1000,
    if size(AB)>Samples*2+Bytes10ms ->
        {F10ms,Rest} = split_binary(AB,Bytes10ms),
        case voice_type(Freq,Vad,F10ms) of
            unactive ->
                shift_to_voice_and_get_samples(Vad,Freq,Dura,PrevAB,Rest);        % just drop noise left previousAB to be unchanged
            actived ->
                get_voice_samples(Vad,Freq,Samples*2,PrevAB,AB)
        end;
    true ->
          get_samples2(Vad,Freq,Samples*2,PrevAB,AB)
    end.

get_samples(VAD,Freq,Dura,Passed,AB) ->
    get_samples2(VAD,Freq,(Freq*Dura div 1000)*2,Passed,AB).

get_samples2(Vad,Freq,Bytes,_Prev,AB) when size(AB)>=Bytes ->
    {Outp,Rest} = split_binary(AB,Bytes),
    case voice_type(Freq,Vad,Outp) of
        actived ->  {{voice,Outp},Rest};
        unactive -> {{noise,Outp},Rest}
    end;
get_samples2(Vad,Freq,Bytes,PrevAB,AB) -> % size(AB)<Bytes
%    io:format("2"),
    %{_,Patch} = split_binary(PrevAB,size(PrevAB)-(Bytes-size(AB))),
      Patch = binary:copy(<<0>>, Bytes-size(AB)),
    case voice_type(Freq,Vad,<<Patch/binary,AB/binary>>) of
        actived ->  {{voice,<<Patch/binary,AB/binary>>},<<>>};
        unactive -> {{noise,<<Patch/binary,AB/binary>>},<<>>}
    end.

get_voice_samples(_Vad,_Freq,Bytes,_Prev,AB) when size(AB)>=Bytes ->
    {Outp,Rest} = split_binary(AB,Bytes),
    {{voice,Outp},Rest};
get_voice_samples(_Vad,_Freq,Bytes,PrevAB,AB) -> % size(AB)<Bytes
%    io:format("3"),
%    {_,Patch} = split_binary(PrevAB,size(PrevAB)-(Bytes-size(AB))),
      Patch = binary:copy(<<0>>, Bytes-size(AB)),
    {{voice,<<Patch/binary,AB/binary>>},<<>>}.

voice_type(?FS8K,Vad,PCM16) when size(PCM16)==160 ->    % 8Khz 10ms 80samples, PCMU
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS8K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==320 ->    % 8Khz 20ms 160samples, PCMU
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS8K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==480 ->    % 8Khz 30ms 240samples, iLBC
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS8K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS8K,Vad,PCM16) when size(PCM16)==960 ->    % 8Khz 60ms 480samples, iLBC
    <<D1:480/binary,D2/binary>> = PCM16,
    case ?APPLY(erl_vad, xprcs, [Vad,D1,?FS8K]) of
        {0,0} ->
            case ?APPLY(erl_vad, xprcs, [Vad,D2,?FS8K]) of
                {0,0} -> unactive;
                {0,1} -> actived
            end;
        {0,1} -> actived
    end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==320 ->    % 16Khz 10ms 80samples, iSAC & u16K
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS16K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==640 ->    % 16Khz 20ms 160samples, u16K
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS16K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==960 ->    % 16Khz 30ms 240samples, iSAC
    case ?APPLY(erl_vad, xprcs, [Vad,PCM16,?FS16K]) of
        {0,0} -> unactive;
        {0,1} -> actived
    end;
voice_type(?FS16K,Vad,PCM16) when size(PCM16)==1920 ->    % 16Khz 60ms 480samples, iSAC
    <<D1:960/binary,D2/binary>> = PCM16,
    case ?APPLY(erl_vad, xprcs, [Vad,D1,?FS16K]) of
        {0,0} ->
            case ?APPLY(erl_vad, xprcs, [Vad,D2,?FS16K]) of
                {0,0} -> unactive;
                {0,1} -> actived
            end;
        {0,1} -> actived
    end;
voice_type(_,_,_) ->
    actived.
%
% ----------------------------------
%% Compose one RTP-packet from whole Data
%
compose_rtp(#base_rtp{seq = Sequence, marker = Marker,
                      packets = Packets, bytes = Bytes} = Base, Codec, Data) ->
    if Marker -> M = 1; true -> M = 0 end,
    Pack = make_rtp_pack(Base, M, Codec, Data),
    NewSeq = inc_seq(Sequence),
    {Base#base_rtp{codec = Codec,
                   seq = NewSeq,
                   packets = inc_packets(Packets, 1),
                   bytes = inc_bytes(Bytes, size(Pack))}, Pack}.

make_rtp_pack(#base_rtp{seq = Sequence,
                        timecode = Timestamp,
                        ssrc = SSRC}, Marker, PayloadType, Payload) ->
  Version = 2,
  Padding = 0,
  Extension = 0,
  CSRC = 0,
  <<Version:2, Padding:1, Extension:1, CSRC:4, Marker:1, PayloadType:7, Sequence:16, Timestamp:32, SSRC:32, Payload/binary>>.


init_rnd_seq() ->
  random:uniform(16#FF).    % star with a small number
  
init_rnd_ssrc() ->
  random:uniform(16#FFFFFFFF).

init_rnd_timecode() ->
  Range = 1000000000,
  random:uniform(Range) + Range.

inc_timecode(#base_rtp{wall_clock = _WC,
                       timecode = TC} = ST,Inc) ->
  NewWC = os:timestamp(),
  NewTC = TC + Inc,
  ST#base_rtp{timecode = NewTC, wall_clock = NewWC}.

inc_seq(S) ->
    (S+1) band 16#FFFF.

inc_packets(S, V) ->
  (S+V) band 16#FFFFFFFF.

inc_bytes(S, V) ->
  (S+V) band 16#FFFFFFFF.

get_random_160s(Noise) ->
    Rndm = random:uniform(8000 - 160),
    <<_:Rndm/binary,O160:160/binary,_/binary>> = Noise,
    O160.

processSPE(#ev{step=init,nu=Nu,vol=Vol}=SPEv) ->
    utility:my_print("start dtmf sending:~p~n",[{Nu,Vol}]),
    {SPEv#ev{step=tone,tcount=?PT160*2},true,?PT160,<<Nu:8,0:1,0:1,Vol:6,?PT160:16>>};
processSPE(#ev{step=tone,tcount=TC,nu=Nu,vol=Vol,dura=Dura}=SPEv) when Dura>TC ->
    {SPEv#ev{tcount=TC+?PT160},false,0,<<Nu:8,0:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=tone,tcount=TC,nu=Nu,vol=Vol,dura=Dura}=SPEv) when Dura=<TC ->
    {SPEv#ev{step=gap,gcount=1},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol}=SPEv) when GC<3 ->
    {SPEv#ev{gcount=GC+1},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol,queue=[]}=SPEv) when GC>=3 ->
    utility:my_print("end dtmf sending:~p~n",[{Nu,Vol}]),
    {SPEv#ev{actived=false},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>};
processSPE(#ev{step=gap,tcount=TC,gcount=GC,nu=Nu,vol=Vol,queue=[{Nu2,Vol2,Dura}|QT]}=SPEv) when GC>=3 ->
    utility:my_print("end dtmf sending:~p~n",[{Nu,Vol}]),
    {SPEv#ev{step=init,nu=Nu2,vol=Vol2,dura=Dura,queue=QT},false,0,<<Nu:8,1:1,0:1,Vol:6,TC:16>>}.
    
processRPE(#ev{actived=false},_,_,true, <<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->
    #ev{actived=true,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=false},_,_,false,<<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->    % no mark with valid info, just accepted it
    #ev{actived=true,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=false}=RPEv,_,_,_,_Info) ->    % error parameters or end_flag set.
    RPEv;
processRPE(#ev{actived=true,nu=Nu}=RPEv,{_,TS},{_,TS},false,<<0:4,Nu:4,0:1,_IsRsv:1,Volume:6,Dura:16>>) ->
    RPEv#ev{vol=Volume,dura=Dura};
processRPE(#ev{actived=true,nu=Nu}=RPEv,{_,TS},{_,TS},false,<<0:4,Nu:4,1:1,_IsRsv:1,Volume:6,Dura:16>>) ->
    llog("dtmf ~p detected.",[Nu]),
    RPEv#ev{actived=false,nu=Nu,vol=Volume,dura=Dura};
processRPE(#ev{actived=true,nu=Nu1},_,_,_,<<0:4,Nu2:4,0:1,_IsRsv:1,Volume:6,Dura:16>>)
           when Nu1=/=Nu2 ->    % all end_flag lost.
    llog("dtmf ~p dailed.",[Nu1]),
    #ev{actived=true,nu=Nu2,vol=Volume,dura=Dura};
processRPE(Ev,_,_,_,Info)->    % not handled
%   llog1(ST,"dtmf packet unhandled EV:~p  Info:~p~n.",[Ev, Info]),
    Ev.

processVCR_rrp(VCR,Vbuf,PCM) when is_pid(VCR) ->    %linear
%    PCM16K = ?APPLY(erl_resample, up16k, [PCM,<<0,0,0,0,0,0,0,0,0,0>>]),
%   VCR ! #audio_frame{codec=?LINEAR,body=PCM16K,samples=?PSIZE},
%    io:format(" rrp x "),
        VCR ! #audio_frame{codec=?LINEAR,body=PCM,samples=?PSIZE},
    {ok,Vbuf};
processVCR_rrp(_,_,_) ->
%    io:format(" rrp y "),

    {ok,<<>>}.

send2_newvcr(VCR,PCM,SID)->
    if is_pid(VCR)-> VCR ! #audio_frame{codec=?LINEAR,body=PCM,stream_id=SID}; true-> void end.
    
mix2(Bin1,Bin2) when is_binary(Bin1), is_binary(Bin2)->  
    mix2(sample_list(Bin1),sample_list(Bin2),[]).
mix2([],[],R)->
    R1=lists:reverse(R),
    to_bin(R1);
mix2([H1|R1],[H2|R2],R)->   mix2(R1,R2, [(H1+H2) div 2 |R]).

sample_list(Bin) -> sample_list(Bin, []).

sample_list(<<>>, L) -> lists:reverse(L);
sample_list(<<S:16/signed-little, R/binary>>, L) ->
    sample_list(R, [S|L]).

to_bin(L) ->
    to_bin(L, <<>>).

to_bin([], Bin) -> Bin;
to_bin([S|T], Bin) ->
    to_bin(T, << Bin/binary,S:16/signed-little>>).
    
% ----------------------------------
rrp_get_web_codec(g729) ->g729;
rrp_get_web_codec(pcmu) ->pcmu;
rrp_get_web_codec(amr) ->
    {0,Amr} =  ?APPLY(erl_amr, icdc, [0,4750]) ,
    {0,VAD} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD,?VADMODE]),                %% aggresive mode
    {0,VAD2} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD2,?VADMODE]),            %% to SS-MG9000 there is no CNG. vad is used for noise duration compress
    {0,CNGE} = ?APPLY(erl_cng, ienc, [?FS16K,100,8]),         %% 16Khz 100ms 8-byte Sid
    {0,CNGD} = ?APPLY(erl_cng, idec, []),
    {amr,Amr,VAD,VAD2,{CNGE,CNGD}};
rrp_get_web_codec(isac) ->
    {0,Isac} = ?APPLY(erl_isac_nb, icdc, [0,15000,960]),    %% bitrate=15kbits
    {0,VAD} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD,?VADMODE]),                %% aggresive mode
    {0,VAD2} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD2,?VADMODE]),            %% to SS-MG9000 there is no CNG. vad is used for noise duration compress
    {0,CNGE} = ?APPLY(erl_cng, ienc, [?FS16K,100,8]),         %% 16Khz 100ms 8-byte Sid
    {0,CNGD} = ?APPLY(erl_cng, idec, []),
    {isac,Isac,VAD,VAD2,{CNGE,CNGD}};
rrp_get_web_codec(ilbc) ->
    {0,Ilbc} = ?APPLY(erl_ilbc, icdc, [?ILBCPTIME]),
    {0,VAD} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD,?VADMODE]),                %% aggresive mode
    {0,VAD2} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD2,?VADMODE]),            %% to SS-MG9000 there is no CNG. vad is used for noise duration compress
    {0,CNGE} = ?APPLY(erl_cng, ienc, [?FS8K,100,8]),         %% 16Khz 100ms 8-byte Sid
    {0,CNGD} = ?APPLY(erl_cng, idec, []),
    {ilbc,Ilbc,VAD,VAD2,{CNGE,CNGD}};
rrp_get_web_codec(opus) ->
    {0,Opus} = ?APPLY(erl_opus, icdc, [8000,5]),            %% bitrate=1000
    {0,VAD} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD,?VADMODE]),                %% aggresive mode
    {0,VAD2} = ?APPLY(erl_vad, ivad, []),
    0 = ?APPLY(erl_vad, xset, [VAD2,?VADMODE]),            %% to SS-MG9000 there is no CNG. vad is used for noise duration compress
    {0,CNGE} = ?APPLY(erl_cng, ienc, [?FS8K,100,8]),         %% 8Khz 100ms 8-byte Sid
    {0,CNGD} = ?APPLY(erl_cng, idec, []),
    {opus,Opus,VAD,VAD2,{CNGE,CNGD}}.

rrp_release_codec(undefined) ->
    ok;
rrp_release_codec({WebCdc,SipCdc}) ->
    rrp_release_codec2(WebCdc),
    rrp_release_codec2(SipCdc),
    ok.


rrp_release_codec2(g729) ->
    pass;
rrp_release_codec2(undefined) ->
    pass;
rrp_release_codec2(pcmu) ->
    pass;
rrp_release_codec2(pcma) ->
    pass;
rrp_release_codec2({g729,Ctx}) ->
    0 = ?APPLY(erl_g729, xdtr, [Ctx]);
rrp_release_codec2({isac,Isac,VAD,VAD2,{CNGE,CNGD}}) ->
    0 = ?APPLY(erl_isac_nb, xdtr, [Isac]),
    0 = ?APPLY(erl_vad, xdtr, [VAD]),
    0 = ?APPLY(erl_vad, xdtr, [VAD2]),
    0 = ?APPLY(erl_cng, xdtr, [CNGE,0]),
    0 = ?APPLY(erl_cng, xdtr, [CNGD,1]);
rrp_release_codec2({ilbc,Ilbc,VAD,VAD2,{CNGE,CNGD}}) ->
    0 = ?APPLY(erl_ilbc, xdtr, [Ilbc]),
    0 = ?APPLY(erl_vad, xdtr, [VAD]),
    0 = ?APPLY(erl_vad, xdtr, [VAD2]),
    0 = ?APPLY(erl_cng, xdtr, [CNGE,0]),
    0 = ?APPLY(erl_cng, xdtr, [CNGD,1]);
rrp_release_codec2({amr,Ilbc,VAD,VAD2,{CNGE,CNGD}}) ->
    0 = ?APPLY(erl_amr, xdtr, [Ilbc]),
    0 = ?APPLY(erl_vad, xdtr, [VAD]),
    0 = ?APPLY(erl_vad, xdtr, [VAD2]),
    0 = ?APPLY(erl_cng, xdtr, [CNGE,0]),
    0 = ?APPLY(erl_cng, xdtr, [CNGD,1]);
rrp_release_codec2({opus,Opus,VAD,VAD2,{CNGE,CNGD}}) ->
    0 = ?APPLY(erl_opus, xdtr, [Opus]),
    0 = ?APPLY(erl_vad, xdtr, [VAD]),
    0 = ?APPLY(erl_vad, xdtr, [VAD2]),
    0 = ?APPLY(erl_cng, xdtr, [CNGE,0]),
    0 = ?APPLY(erl_cng, xdtr, [CNGD,1]).

rrp_get_sip_codec() ->
    case avscfg:get(sip_codec) of
        pcmu -> pcmu;
        pcma->pcma;
        g729 ->
            {0,Ctx} = ?APPLY(erl_g729, icdc, []),
            {g729,Ctx}
    end.

start(Session,Owner) ->
    {SS_BEGIN_UDP_RANGE,SS_END_UDP_RANGE} = avscfg:get(ss_udp_range),
    {Port,Socket} = try_port(SS_BEGIN_UDP_RANGE,SS_END_UDP_RANGE),
    {ok,Pid} = my_server:start(?MODULE,[Session,Socket,avscfg:get_vcr(),Port,Owner],[]),
      gen_udp:controlling_process(Socket, Pid),
    SDP_TO_SS = get_local_sdp(Port),
    {ok,Pid,SDP_TO_SS}.

stop(RRP) ->
    my_server:call(RRP,stop).

set_peer_addr(RrpPid, Addr) ->
    my_server:call(RrpPid,{set_peer_addr,Addr}).
    
try_port(Port) ->
    {ok,IP4sip} = inet_parse:address(avscfg:get(sip_socket_ip)),
    case gen_udp:open(Port, [binary, {active, true},{ip,IP4sip}, {recbuf, 4096}]) of
        {ok, Socket} ->
            {Port,Socket};
        {error, _} ->
            try_port(Port + 2)
    end.

try_port(Begin, End) ->
    From =   case app_manager:get_last_used_ssport() of
        undefined-> Begin;
        {ok, From1}-> From1
        end,
    try_port(Begin, End, From, From+2).
    
try_port(Begin, End, From, Port) when Port==From ->
    {error,udp_over_range};
try_port(Begin, End, From, Port) when Port>End ->
    try_port(Begin, End, From, Begin);
try_port(Begin, End, From, Port) ->
    {ok,IP4sip} = inet_parse:address(avscfg:get(sip_socket_ip)),
    case gen_udp:open(Port, [binary, {active, true},{ip,IP4sip}, {recbuf, 4096}]) of
        {ok, Socket} ->
          app_manager:set_last_used_ssport(Port),
            {Port,Socket};
        {error, _} ->
            try_port(Begin, End, From, Port+2)
    end.
    
send_udp(Socket, Addr, Port, RTPs) ->
  F = fun(P) ->
          gen_udp:send(Socket, Addr, Port, P)
      end,
  send_rtp(F, RTPs).

send_rtp(F, RTP) when is_binary(RTP) ->
  F(RTP);
send_rtp(F, RTPs) when is_list(RTPs) ->
  [begin
     if is_list(R) ->
         [F(Rr) || Rr <- R];
        true ->
         F(R)
     end
   end || R <- RTPs].

send_2_monitor(P,UdpInfo)->
    send_msg(P, {last,node(),UdpInfo,self()}).
send_msg(P,M)   ->
    if is_pid(P)-> P ! M; true-> void end.
    
up_udp_stats(#packet_stats{up_udppkts=Uup1,up_udpbytes=Uub1}=Stats,Bin)-> 
    Stats#packet_stats{up_udppkts=Uup1+1,up_udpbytes=Uub1+size(Bin)}.
down2rtp_stats(#packet_stats{down2rtppkts=Urp1,down2rtpbytes=Urb1}=Stats,Bin)-> 
    Stats#packet_stats{down2rtppkts=Urp1+1,down2rtpbytes=Urb1+size(Bin)}.
up_rtp_stats(Stats=#packet_stats{up_rtppkts=Drp1,up_rtpbytes=Drb1},Bin)->
    Stats#packet_stats{up_rtppkts=Drp1+1,up_rtpbytes=Drb1+size(Bin)}.
down_udp_stats(Stats=#packet_stats{down_udppkts=Dup1,down_udpbytes=Dub1},Bin)->
    Stats#packet_stats{down_udppkts=Dup1+1,down_udpbytes=Dub1+size(Bin)}.
stats_log(ST=#st{stats=Stats=#packet_stats{up_udppkts=Uup1,last_up_udppkts=Uup0,up_udpbytes=Uub1,last_up_udpbytes=Uub0,      
                       down_udppkts=Dup1,last_down_udppkts=Dup0,down_udpbytes=Dub1,last_down_udpbytes=Dub0,
                       up_rtppkts=Urp1,last_up_rtppkts=Urp0,up_rtpbytes=Urb1,last_up_rtpbytes=Urb0,
                       down2rtppkts=Drp1,last_down2rtppkts=Drp0,down2rtpbytes=Drb1,last_down2rtpbytes=Drb0}})->
    llog1(ST, "rrp:sendudp ~ppkts ~ppps ~pB ~pbps udprcv:~ppkts ~ppbs ~pB ~pbps tortp: ~ppkts ~ppbs ~pB ~pbps ",
                            [Uup1,Uup1-Uup0,Uub1,8*(Uub1-Uub0),Dup1,Dup1-Dup0,Dub1,8*(Dub1-Dub0),Drp1,Drp1-Drp0,Drb1,8*(Drb1-Drb0)]),                      
%    llog1(ST, "rrp:sendudp ~ppkts ~ppps ~pB ~pbps fromrtp:~ppkts ~pps ~pB ~pbps tortp: ~ppkts ~ppbs ~pB ~pbps udprcv:~ppkts ~ppbs ~pB ~pbps",
%                            [Uup1,Uup1-Uup0,Uub1,8*(Uub1-Uub0),Urp1,Urp1-Urp0,Urb1,8*(Urb1-Urb0),Drp1,Drp1-Drp0,Drb1,Drb0,Dup1,Dup1-Dup0,Dub1,8*(Dub1-Dub0)]),                      
    ST#st{stats=Stats#packet_stats{last_up_udppkts=Uup1,last_up_udpbytes=Uub1,last_down_udppkts=Dup1,last_down_udpbytes=Dub1,
                                            last_up_rtppkts=Urp1,last_up_rtpbytes=Urb1,last_down2rtppkts=Drp1,last_down2rtpbytes=Drb1}}.                        
    
adjust_gain(PCM)->PCM.
adjust_gain0(PCM)->
    Lists=sample_list(PCM),
    F=fun(I)->
            if I>32767-> 32767;
               I< -32767-> -32767;
               true-> I
            end 
            end,
    Lists1 = [F(trunc(I*1.4))||I<-Lists],
    to_bin(Lists1).
    
raw2wav(Freq,InF,OutF)->
    {ok,Payload}=file:read_file(InF),
    PayloadLen = size(Payload),
    AllSize = PayloadLen + 44,
    FileSize = AllSize -8,
    {ok, Fd} = file:open(OutF, [write,raw,binary]),
    file:write(Fd, <<"RIFF">>),
    file:write(Fd, <<FileSize:32/little>>),
    file:write(Fd,<<"WAVEfmt ">>),
    file:write(Fd, <<16:32/little>>),  % fmt size
    file:write(Fd, <<1:16/little, 1:16/little>>),  % PCM linear,  single channel
    file:write(Fd, <<Freq:32/little>>), % frequency
    file:write(Fd, <<32000:32/little>>),   %Bps
    file:write(Fd,<<2:16/little,16:16/little>>), % channels*bits/8, 16bit
    file:write(Fd, <<"data">>),
    file:write(Fd,<<PayloadLen:32/little>>),
    file:write(Fd,Payload),
    file:close(Fd).    

acquire_codec() ->
  rrp_get_sip_codec().
get_local_sdp(LPort) ->
    {Se1,St1} = 'SAMPLE'(LPort),
    sdp:encode(Se1,[St1]).
'SAMPLE'(Port) -> 
  HOST = avscfg:get(ip4sip),
    Orig = #sdp_o{username = <<"LVOS3000">>,
                  sessionid = "1234",
                  version = "1",
                  netaddrtype = inet4,
                  address = HOST},
    Sess = #session_desc{version = <<"0">>,
                         originator = Orig,
                         name = "phone-call",
                         connect = {inet4,HOST},
                         time = {0,0},
                         attrs = []},
    PL1 = case avscfg:get(sip_codec) of
          pcmu -> #payload{num = ?PCMU};
          pcma -> #payload{num = ?PCMA};
          g729 -> #payload{num = ?G729}
        end,
    PL3 = #payload{num = 101,
                   codec = telephone,
                   clock_map = 8000,
                   config = [{0,11}]},
    Stream = #media_desc{type = audio,
                         profile = "AVP",
                         port = Port,
                         payloads = [PL1,PL3],
                         config = [#ptime{avg=20}]
            },
    {Sess,Stream}.      

send_pcmu(_,#st{peer=undefined} = ST)-> ST;
send_pcmu(#audio_frame{body=Body,marker=M},#st{in_stream=BaseRTP,socket=Socket,peer={IP,Port},sendcount=SC} = ST)->
    {PN,Enc} = {?PCMU,Body},
    {NewBaseRTP, RTP} = compose_rtp(inc_timecode(BaseRTP#base_rtp{marker=M},?PSIZE),PN,Enc),
    send_udp(Socket,IP,Port,RTP),
    ST#st{in_stream = NewBaseRTP,sendcount=SC+1}.

show(Pid)->
    F=fun(State)->
            {State,State}
       end,
    act(Pid,F).

act(Pid,Act)->    my_server:call(Pid,{act,Act}).
get_peer(Pid)->
    F=fun(State=#st{peer=Peer})->
            {Peer,State}
       end,
    act(Pid,F).    
get_media(Pid)->
    F=fun(State=#st{media=Media})->
            {Media,State}
       end,
    act(Pid,F).    
cutoff_temporary(OprMedia)->
    F=fun(State=#st{media=Media})->
            if is_pid(Media)->
                Media ! {play,undefined};
            true-> void
            end,
            {Media,State#st{media=undefined}}
       end,
    act(OprMedia,F).    
set_peer(Pid,Peer) when is_pid(Pid)-> 
    case is_process_alive(Pid) of true-> Pid ! {play,Peer}; _-> void end;
set_peer(_,_)-> void.

sub(Pid,Peer)->unset_peer(Pid,Peer).
unset_peer(Pid,Peer)when is_pid(Pid)-> Pid ! {deplay,Peer};
unset_peer(_,_)-> void.

get_count(Pid)->
    F=fun(State=#st{rcvcount=RC,sendcount=SC})->
            {{SC,RC},State}
       end,
    act(Pid,F).   