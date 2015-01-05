-module(sdp).
-author('Max Lapshin <max@maxidoors.ru>').

-compile(export_all).
%-export([decode/1, encode/2, prep_media_config/2]).
-include("sdp.hrl").

%%----------------------------------------------------------------------
%% @spec (Data::binary()) -> [media_desc()]
%%
%% @doc Called by {@link rtp_server.} to decode SDP when it meets "Content-Type: application/sdp"
%% in incoming headers. Returns list of preconfigured, but unsynced rtsp streams
%% @end
%%----------------------------------------------------------------------

decode(Announce) when is_binary(Announce) ->
  Lines = string:tokens(binary_to_list(Announce), "\r\n"),
  KeyValues = [{atom([K]), Value} || [K,$=|Value] <- Lines],
  decode(KeyValues);

decode(Announce) when is_list(Announce)->
  {Session, Announce2} = parse_session(Announce, #session_desc{}),
  Streams = parse_announce(Announce2, [], undefined, undefined),
  {Session,Streams}.
  
%%
parse_session([{m, Info} | Announce],Session) ->
  {Session, [{m, Info} | Announce]};
parse_session([{v, Version} | Announce],Session) ->
  parse_session(Announce, Session#session_desc{version=Version});
parse_session([{o, Str} | Announce],Session) ->
  Orig = parse_original(Str),
  parse_session(Announce, Session#session_desc{originator=Orig});
parse_session([{s, SName} | Announce],Session) ->
  parse_session(Announce, Session#session_desc{name=SName});
parse_session([{t, Str} | Announce],Session) ->
  {ok, [T1, T2], _} = io_lib:fread("~d~d",Str),
  parse_session(Announce, Session#session_desc{time={T1,T2}});
parse_session([{c, Connect} | Announce], Session) ->
  Parsed = parse_connect(Connect),
  parse_session(Announce, Session#session_desc{connect=Parsed});
parse_session([{a, Attribute} | Announce],#session_desc{attrs=Attr0}=Session) ->
  case string:chr(Attribute, $:) of
    0 -> Key = Attribute, Value = undefined;
    Pos when Pos > 0 ->
      Key = string:substr(Attribute, 1, Pos - 1),
      Value = string:substr(Attribute, Pos + 1)
  end,
  case Key of
    "group" ->
      parse_session(Announce, Session#session_desc{attrs=Attr0++[{group,Value}]});
    "msid-semantic" ->
      Msid2 = case string:tokens(Value," ") of
               ["WMS",Msid] -> Msid;
               ["WMS"] -> ""
             end,
      parse_session(Announce, Session#session_desc{attrs=Attr0++[{msid,Msid2}]});
    _ ->
      %%io:format("unknow attrs ~p : ~p in session.~n",[Key,Value]),
      parse_session(Announce, Session)
  end.

parse_original(Orig) ->
% <<"- 1750149717 1 IN IP4 127.0.0.1">>
  {ok, Re} = re:compile("([^$]+) ([\\d]+) ([\\d]+) IN +IP(\\d) +([^ ]+) *"),
  {match, [_,UN,Ssid,Ver,NT,Addr]} = re:run(Orig, Re, [{capture, all, list}]),
  Inet = case NT of
        "4" -> inet4;
        "6" -> inet6
      end,

  #sdp_o{username=list_to_binary(UN),
		 sessionid = Ssid,
		 version = Ver,
		 netaddrtype = Inet,
		 address = Addr}.
%
%% -------------------------------------
%	media description
%% -------------------------------------
%
parse_announce([], Streams, undefined, _Connect) ->
  lists:reverse(Streams);

parse_announce([], Streams, Stream, Connect) ->
  lists:reverse([Stream#media_desc{connect=Connect} | Streams]);

parse_announce([{m, Info} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  parse_announce([{m, Info} | Announce], [Stream#media_desc{connect=Connect} | Streams], undefined, Connect);

parse_announce([{m, Info} | Announce], Streams, undefined, Connect) ->
  [TypeS, PortS, "RTP/"++PF | PayloadTypes] = string:tokens(Info, " "),
  Type = binary_to_existing_atom(list_to_binary(TypeS), utf8),
  MediaDesc = #media_desc{type=Type, profile=PF, connect = Connect, port = list_to_integer(PortS),
						  payloads = [#payload{num = list_to_integer(PT)} || PT <- PayloadTypes]},
  parse_announce(Announce, Streams, MediaDesc, Connect);

parse_announce([{c, Conn} | Announce], Streams, #media_desc{} = Stream, _Connect) ->
  Parsed = parse_connect(Conn),
  parse_announce(Announce, Streams, Stream#media_desc{connect = Parsed}, Parsed);

parse_announce([{a, Attribute} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  {Key,Value} = get_kv(Attribute),
  {Stream1,Announce2} = parse_one_announce(Key,Value,Stream,Announce),
  parse_announce(Announce2, Streams, Stream1, Connect);

parse_announce([{_Other, _Info} | Announce], Streams, Stream, Connect) ->
  parse_announce(Announce, Streams, Stream, Connect).

%
%
%
parse_one_announce("rtpmap",Value,Stream,Announce) ->
% "a=rtpmap:111 opus/48000/2"
  {ok, Re} = re:compile("(\\d+) ([^/]+)/([\\d]+)"),
  {match, [Matched, PayLoadNum, CodecCode, ClockMap1]} = re:run(Value, Re, [{capture, all, list}]),
  Pt0 = Stream#media_desc.payloads,
  Codec = str2codec(CodecCode),
  ClockMap = list_to_integer(ClockMap1),
  Ch = case lists:split(length(Matched),Value) of
        {_,"/2"} -> stereo;
        {_,_} -> undefined
       end,
  {ok,PtCfg,Announce2} = parse_format_specified(Codec,PayLoadNum, [], Announce),
  Pt1 = #payload{num=list_to_integer(PayLoadNum),codec=Codec,clock_map=ClockMap,channel=Ch,config=PtCfg},
  NewPt = lists:keystore(Pt1#payload.num, #payload.num, Pt0, Pt1),
  {Stream#media_desc{payloads=NewPt},Announce2};
parse_one_announce("ice"++Type,Value,Stream,Announce) ->
  NewICE = case Type of
        	"-ufrag" ->
              {Value,""};
        	"-pwd" ->
              {element(1,Stream#media_desc.ice),Value};
        	"-options" ->
        	  %%io:format("~p is ignored.~n",[Value]),
        	  Stream#media_desc.ice
        end,
  {Stream#media_desc{ice=NewICE},Announce};
parse_one_announce("acap",Value,Stream,Announce) ->
  {parse_acap(Stream, Value),Announce};
parse_one_announce("crypto",Value,Stream,Announce) ->
  {parse_crypto(Stream, Value),Announce};
parse_one_announce("fingerprint",Value,Stream,Announce) ->
  {parse_fingerprint(Stream, Value), Announce};
parse_one_announce("ssrc",Value,Stream,Announce) ->
  {ok, Re} = re:compile("(\\d+) ([^:]+):([^$]+)"),
  {match, [_, SSID, Type, Str]} = re:run(Value, Re, [{capture, all, list}]),
  SSRC = Stream#media_desc.ssrc_info,
  {Stream#media_desc{ssrc_info = lists:keystore(Type,2,SSRC,{SSID,Type,Str})},Announce};
parse_one_announce("sendrecv"=Key,Value,Stream,Announce) ->
  NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
  {Stream#media_desc{attrs = NewAttrs},Announce};
parse_one_announce("recvonly"=Key,Value,Stream,Announce) ->
  NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
  {Stream#media_desc{attrs = NewAttrs},Announce};
parse_one_announce("mid"=Key,Value,Stream,Announce) ->
  NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
  {Stream#media_desc{attrs = NewAttrs},Announce};
parse_one_announce("rtcp-mux"=Key,Value,Stream,Announce) ->
  NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
  {Stream#media_desc{attrs = NewAttrs},Announce};
parse_one_announce("rtcp",Value,Stream,Announce) ->
  {RTCPPort,Connect2} = parse_rtcp(Value),
  {Stream#media_desc{rtcp = {RTCPPort,Connect2}},Announce};
parse_one_announce("candidate",Value,Stream,Announce) ->
  AttCH = <<"a=candidate:">>,
  AttCV = list_to_binary(Value),
  Cndd = cndd:decode(<<AttCH/binary,AttCV/binary>>),
  NewCandids = Stream#media_desc.candidates ++ [Cndd],
  {Stream#media_desc{candidates = NewCandids},Announce};
parse_one_announce("maxptime",Value,Stream,Announce) ->
  {Stream#media_desc{config=[#ptime{max=list_to_integer(Value)}]},Announce};
parse_one_announce("ptime",Value,Stream,Announce) ->
  {Stream#media_desc{config=[#ptime{avg=list_to_integer(Value)}]},Announce};
%"a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level"
parse_one_announce("extmap",Value,Stream,Announce) ->
  ExtMap = Stream#media_desc.extmap ++ [parse_extmap(Value)],
  {Stream#media_desc{extmap=ExtMap},Announce};
parse_one_announce(Else,Value,Stream,Announce) ->
  %%io:format("sdp unknow attr: ~p:~p~n",[Else,Value]),
  {Stream,Announce}.

parse_format_specified(Codec,PN, Cfg,[{a,Attribute} | Rest]=Announce) ->
  {Key,Value} = get_kv(Attribute),
  case Key of
    "fmtp" ->
      {ok, Re} = re:compile("(\\d+) ([^/]+)"),
      {match, [_, Format, Params]} = re:run(Value, Re, [{capture, all, list}]),
      if Format==PN ->
        Ccfg = parse_codec_params(Codec,Params),
        parse_format_specified(Codec,PN,[Ccfg|Cfg],Rest);
      true -> {ok,lists:reverse(Cfg),Announce} end;
    "rtcp-fb" ->	% "a=rtcp-fb:100 ccm fir" "a=rtcp-fb:100 nack "
      {ok, Re} = re:compile("(\\d+) ([^/]+)"),
      {match, [_, Format, Attrs]} = re:run(Value, Re, [{capture, all, list}]),
      if Format==PN -> parse_format_specified(Codec,PN,[parse_rtcp_fb_attr(Attrs)|Cfg],Rest);
      true -> {ok,lists:reverse(Cfg),Announce} end;
    _ ->
      {ok,lists:reverse(Cfg),Announce}
  end;
parse_format_specified(_,_,Cfg,Announce) ->
  {ok,lists:reverse(Cfg),Announce}.

parse_rtcp_fb_attr("ccm fir") -> {rtcp_fb,ccm_fir};
parse_rtcp_fb_attr("goog-remb") -> {rtcp_fb,goog_remb};
parse_rtcp_fb_attr("nack") -> {rtcp_fb,nack};
parse_rtcp_fb_attr("goog-remb ") -> {rtcp_fb,goog_remb};
parse_rtcp_fb_attr("nack ") -> {rtcp_fb,nack}.

get_kv(Attribute) ->
  case string:chr(Attribute, $:) of
    0 ->
      {Attribute,undefined};
    Pos when Pos > 0 ->
      {string:substr(Attribute, 1, Pos-1),string:substr(Attribute, Pos+1)}
  end.

parse_rtcp(Value) ->
  {ok, Re} = re:compile("(\\d+) IN +IP(\\d) +([^ ]+) *"),
  {match, [_, Port, NT, Addr]} = re:run(Value, Re, [{capture, all, list}]),
  N = case NT of
        "4" -> inet4;
        "6" -> inet6
      end,
  {list_to_integer(Port),{N, Addr}}.

parse_connect(Connect) ->
  {ok, Re} = re:compile("IN +IP(\\d) +([^ ]+) *"),
  {match, [_, NT, Addr]} = re:run(Connect, Re, [{capture, all, list}]),
  N = case NT of
        "4" -> inet4;
        "6" -> inet6
      end,
  {N, Addr}.

%parse_crypto(#media_desc{key_strategy=dtls}=Stream, _Crypto) ->
%  Stream;
%parse_crypto(#media_desc{key_strategy=crypto}=Stream, _Crypto) ->
%  Stream;
parse_crypto(Stream, Crypto) ->
  %"1 AES_CM_128_HMAC_SHA1_80 inline:XE+QXqoqyFUkRzQxUq/8PyMaRQk27YuK6FlcN1tX"
  Params = re:split(Crypto, "[ :]", [{return, list}]),
  Stream#media_desc{key_strategy=crypto, crypto={lists:nth(1,Params),lists:nth(2,Params),lists:nth(4,Params)}}.

parse_acap(Stream, Acap) ->
  %"1 crypto:1 AES_CM_128_HMAC_SHA1_80 inline:XE+QXqoqyFUkRzQxUq/8PyMaRQk27YuK6FlcN1tX"
  Params = re:split(Acap, "[ :]", [{return, list}]),
  Stream#media_desc{key_strategy=crypto, crypto={lists:nth(3,Params),lists:nth(4,Params),lists:nth(6,Params)}}.

parse_fingerprint(#media_desc{key_strategy=crypto}=Stream, _FingerPrint) ->
  Stream;
parse_fingerprint(Stream, FingerPrint) ->
  Space = string:chr(FingerPrint, $ ),
  Algo = digest_algo(string:substr(FingerPrint, 1, Space-1)),
  FPBin = fingerprint_bin(string:substr(FingerPrint, Space+1)),
  Stream#media_desc{fingerprint={Algo, FPBin}, key_strategy=dtls}.

digest_algo("sha-256") -> sha256;
digest_algo("sha-128") -> sha128;
digest_algo("sha-1") -> sha.

fingerprint_bin(Str) ->
  Bytes = re:split(Str, ":", [{return, list}]),
  iolist_to_binary(lists:map(fun(E) -> list_to_integer(E, 16) end, Bytes)).
  
% "a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level"
% "a=extmap:3 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time"
parse_extmap(Attr) ->
  {ok, Re} = re:compile("(\\d) urn:ietf:params:rtp-hdrext:([^ ]+)"),
  case re:run(Attr,Re,[{capture,all,list}]) of
    {match,[_Matched,Ch,Profile]} ->
      {list_to_integer(Ch),atom(Profile)};
    nomatch ->
      Ch = lists:takewhile(fun(C)->C=/=$  end,Attr),
      " "++Map = lists:dropwhile(fun(C)->C=/=$  end,Attr),
      {list_to_integer(Ch),Map}
  end.
  
atom(A) ->
    case (catch list_to_existing_atom(A)) of
      {'EXIT',_} ->
        list_to_atom(A);
    S  ->
        S
  end. 
 
%
%%
%
-define(LSEP, <<$\r,$\n>>).
encode(#session_desc{connect = GConnect} = Session,
       MediaSeq) ->
  S = encode_session(Session),
  M = encode_media_seq(MediaSeq, GConnect),
  <<S/binary,M/binary>>.

encode_session(S) ->
  encode_session(S, <<>>).

encode_session(#session_desc{version = Ver,
                             originator = #sdp_o{username = UN,
                                                 sessionid = SI,
                                                 version = OV,
                                                 netaddrtype = NAT,
                                                 address = AD},
                             name = N,
                             connect = Connect,
                             time = Time,
                             attrs = Attrs
                            } = _D, _A) ->
  SV = ["v=", Ver, ?LSEP],
  SO = ["o=", UN, $ , SI, $ , OV, $ , at2bin(NAT), $ , AD, ?LSEP],
  SN = ["s=", N, ?LSEP],
  SC =
    case Connect of
      {Type, Addr} when (is_atom(Type)
                         andalso (is_list(Addr) or is_binary(Addr))) ->
        ["c=", at2bin(Type), $ , Addr, ?LSEP];
      _ -> []
    end,
  AttrL = [begin
             ResB =
               case KV of
                 {msid,Msid} ->
                   ["msid-semantic: WMS ",Msid];
                 {K, V} when (is_atom(K)
                              andalso (is_list(V) or is_binary(V))) ->
                   [atom_to_list(K), $:, V];
                 _ when is_atom(KV) ->
                   atom_to_list(KV);
                 _Other ->
                   %%io:format("Err: ~p~n", [KV]),
                   ""
               end,
             ["a=", ResB, ?LSEP]
           end || KV <- Attrs],
  TimeB =
    case Time of
      {TimeStart, TimeStop} when is_integer(TimeStart), is_integer(TimeStop) ->
        ["t=", integer_to_list(TimeStart), $ , integer_to_list(TimeStop), ?LSEP];
      _ -> []
    end,
  iolist_to_binary([SV, SO, SN, SC, TimeB, AttrL]).

encode_media_seq(MS, GConnect) ->
  encode_media_seq(MS, GConnect, <<>>).

encode_media_seq([], _, A) ->
  A;
encode_media_seq([H|T], GConnect, A) ->
  NA = <<A/binary,(encode_media(H, GConnect))/binary>>,
  encode_media_seq(T, GConnect, NA).

encode_media(M, GConnect) ->
  encode_media(M, GConnect, <<>>).

encode_media(#media_desc{type = Type,
						 extmap = ExtMapCodes,
						 profile = PF,
                         connect = Connect,
                         rtcp = RTCP,
                         candidates = Candids,
                         port = Port,
                         payloads = PayLoads,
                         config = Config,
                         attrs = Attrs,
                         ice = ICE,
                         crypto = Crypto,
                         ssrc_info = SSRC
                        }, _GConnect, _A) ->
  Tb = type2bin(Type),
  ExtMap = [["a=extmap:",enc_extmap(Chid,DescProf),?LSEP]||{Chid,DescProf}<-ExtMapCodes],
  M = ["m=", Tb, $ , integer_to_list(Port), $ , "RTP/", PF, $ ,
       string:join([integer_to_list(PTnum) || #payload{num = PTnum} <- PayLoads], " "), ?LSEP],
  MC= enc_connect(Connect),
  MRTCP = enc_rtcp_attr(RTCP),
  MCandid = enc_candidates(Candids),
  EAttr = enc_attrs(Attrs),
  EICE = enc_ice(ICE),
  ECry = enc_crypto(Crypto),
  ESSRC = enc_ssrc(SSRC),
  %%
  AR = [begin
          Codecb = codec2bin(Codec),
          CMapb = integer_to_list(ClockMap),
          ChStr = if Ch==stereo -> "/2"; true -> "" end,
          if is_list(PTConfig) ->
              PTC = [encode_codec_params(Codec,PTnum,C) || C <- PTConfig];
             true ->
              PTC = []
          end,
          [["a=", "rtpmap:", integer_to_list(PTnum), $ , Codecb, $/,CMapb,ChStr, ?LSEP], PTC]
        end || #payload{num = PTnum, codec = Codec,clock_map = ClockMap,channel=Ch,config = PTConfig} <- PayLoads,Codec=/=undefined],
  ACfg = case Config of
           [#ptime{max=MaxT}] when is_integer(MaxT) ->
             [["a=","maxptime:",integer_to_list(MaxT), ?LSEP]];
           [#ptime{avg=AvgT}] when is_integer(AvgT) ->
             [["a=","ptime:",integer_to_list(AvgT), ?LSEP]];
           _ ->
             []
         end,
  iolist_to_binary([M, MC,MRTCP,MCandid,EAttr,EICE,ExtMap,ECry,AR,ACfg,ESSRC]);
encode_media(_, _, _) ->
  <<>>.

enc_extmap(Chid,Desc) when is_list(Desc) ->
  integer_to_list(Chid)++" "++Desc;
enc_extmap(Chid,DescProf) ->
  integer_to_list(Chid)++" urn:ietf:params:rtp-hdrext:"++atom_to_list(DescProf).

enc_connect(Connect) ->
	case Connect of
      {Type, Addr} when (is_atom(Type)
                         andalso (is_list(Addr) or is_binary(Addr))) ->
        ["c=", at2bin(Type), $ , Addr, ?LSEP];
      _ -> []
    end.

enc_rtcp_attr({Port,{Type,Addr}}) when is_integer(Port),is_atom(Type),is_list(Addr) ->
  ["a=rtcp:", int2bin(Port), $ , at2bin(Type), $ , Addr, ?LSEP];
enc_rtcp_attr(_) -> [].

enc_candidates(Candids) ->
  lists:map(fun(X) -> cndd:encode(X) end, Candids).

enc_attrs(Attrs) ->
  [begin
     {Sep,Value} = if Val1==undefined ->
              {"",[]};
             Val1 == [] ->
              {"",[]};
             true ->
              {":",Val1}
          end,
    ["a=", Key, Sep, Value, ?LSEP]
   end || {Key,Val1} <- Attrs].

enc_ice({Ufrag,Pwd}) when Pwd=/="" ->
  ["a=ice-ufrag:",Ufrag,?LSEP,
   "a=ice-pwd:",Pwd,?LSEP];
enc_ice(_) -> [].
  
enc_crypto(undefined) -> [];
enc_crypto({Ch,Alg,Inline}) ->
  ["a=crypto:",Ch,$ ,Alg,$ ,"inline:",Inline,?LSEP].
  
enc_ssrc(SSRC) ->
  [["a=ssrc:",ID,$ ,Type,":",Str,?LSEP]  
   || {ID,Type,Str} <- SSRC].

type2bin(T) ->
  case T of
    audio -> <<"audio">>;
    video -> <<"video">>
  end.

%
%
int2bin(Int) ->
	list_to_binary(integer_to_list(Int)).

at2bin(AT) ->
  case AT of
    inet4 -> <<"IN IP4">>;
    inet6 -> <<"IN IP6">>
  end.

codec2bin(C) ->
  case C of
    pcma -> <<"PCMA">>;
    pcmu -> <<"PCMU">>;
    g729 -> <<"G729">>;
    noise -> <<"CN">>;
    telephone -> <<"telephone-event">>;
    iSAC -> <<"ISAC">>;
    iLBC -> <<"ILBC">>;
    vp8 -> <<"VP8">>;
    red -> <<"red">>;
    ulpfec -> <<"ulpfec">>;
    opus -> <<"opus">>;
    pcm -> <<"L16">>
  end.

str2codec(CodecCode) ->
	case CodecCode of
        "G723" -> g723;
        "PCMA" -> pcma;
        "PCMU" -> pcmu;
        "G729" -> g729;
        "CN" -> noise;
        "telephone-event" -> telephone;
		"ISAC" -> iSAC;
		"ILBC" -> iLBC;
		"VP8" -> vp8;
		"red" -> red;
		"ulpfec" -> ulpfec;
		"SPEEX"->speex;
		"GSM"->gsm;
		"H264"->h264;
		"opus" -> opus;
		Oth-> list_to_atom(Oth)
    end.

% "fmtp:101 0-11"
parse_codec_params(telephone,Params) ->
	{ok, Re} = re:compile("(\\d+)-(\\d+)"),
	{match, [_Matched, BegN, EndN]} = re:run(Params, Re, [{capture, all, list}]),
	{list_to_integer(BegN),list_to_integer(EndN)};
% "fmtp:4 annexa=no"
parse_codec_params(g723,Params) ->
	{ok, Re} = re:compile("([^/]+)=([^/]+)"),
	{match, [_Matched, Type, T1]} = re:run(Params, Re, [{capture, all, list}]),
	{atom(Type),atom(T1)};
% "fmtp:18 annexb=no"
parse_codec_params(g729,Params) ->
	{ok, Re} = re:compile("([^/]+)=([^/]+)"),
	{match, [_Matched, Type, T1]} = re:run(Params, Re, [{capture, all, list}]),
	{atom(Type),atom(T1)};
% "a=fmtp:111 minptime=10"
parse_codec_params(opus, Params) ->
	{ok, Re} = re:compile("([^/]+)=(\\d+)"),
	{match, [_Matched, Type, T1]} = re:run(Params, Re, [{capture, all, list}]),
	{atom(Type),list_to_integer(T1)}.
	
encode_codec_params(telephone,PTnum,{BegN,EndN}) ->
  NRange = integer_to_list(BegN)++"-"++integer_to_list(EndN),
  ["a=", "fmtp:", integer_to_list(PTnum), $ , NRange, ?LSEP];
encode_codec_params(opus,PTnum,{Type,T1}) ->
  Ptime = atom_to_list(Type)++"="++integer_to_list(T1),
  ["a=", "fmtp:", integer_to_list(PTnum), $ , Ptime, ?LSEP];
encode_codec_params(vp8,PTnum,{rtcp_fb,ccm_fir}) ->
  ["a=", "rtcp-fb:", integer_to_list(PTnum), $ , "ccm fir", ?LSEP];
encode_codec_params(vp8,PTnum,{rtcp_fb,nack}) ->
  ["a=", "rtcp-fb:", integer_to_list(PTnum), $ , "nack", $ , ?LSEP];
encode_codec_params(vp8,PTnum,{rtcp_fb,goog_remb}) ->
  ["a=", "rtcp-fb:", integer_to_list(PTnum), $ , "goog-remb", $ , ?LSEP].
  
  
 llog(F,M) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",M);
		Pid -> Pid ! {self(),F,M}
	end.

% Example of SDP:
%
% v=0
% o=- 1266472632763124 1266472632763124 IN IP4 192.168.4.1
% s=Media Presentation
% e=NONE
% c=IN IP4 0.0.0.0
% b=AS:50000
% t=0 0
% a=control:*
% a=range:npt=0.000000-
% m=video 0 RTP/AVP 96
% b=AS:50000
% a=framerate:25.0
% a=control:trackID=1
% a=rtpmap:96 H264/90000
% a=fmtp:96 packetization-mode=1; profile-level-id=420029; sprop-parameter-sets=Z0IAKeNQFAe2AtwEBAaQeJEV,aM48gA==

%sample sdp from chrom <<"v=0\r\no=- 4254011305 3 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE audio video\r\na=msid-semantic: WMS q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BT\r\nm=audio 59768 RTP/SAVPF 111 103 104 0 8 107 106 105 13 126\r\nc=IN IP4 10.60.108.148\r\na=rtcp:59768 IN IP4 10.60.108.148\r\na=candidate:1600702733 1 udp 2113937151 10.60.108.148 59768 typ host generation 0\r\na=candidate:1600702733 2 udp 2113937151 10.60.108.148 59768 typ host generation 0\r\na=candidate:300627453 1 tcp 1509957375 10.60.108.148 50529 typ host generation 0\r\na=candidate:300627453 2 tcp 1509957375 10.60.108.148 50529 typ host generation 0\r\na=ice-ufrag:3JM/SI6Dq9Q/Bfgs\r\na=ice-pwd:FsCqFj96XEpNb/jsledUDGyX\r\na=ice-options:google-ice\r\na=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\na=sendrecv\r\na=mid:audio\r\na=rtcp-mux\r\na=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:K1DxPojz8+o8n2cFjwJz+d+7VJItoQPndJ59gqqz\r\na=rtpmap:111 opus/48000/2\r\na=fmtp:111 minptime=10\r\na=rtpmap:103 ISAC/16000\r\na=rtpmap:104 ISAC/32000\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:107 CN/48000\r\na=rtpmap:106 CN/32000\r\na=rtpmap:105 CN/16000\r\na=rtpmap:13 CN/8000\r\na=rtpmap:126 telephone-event/8000\r\na=maxptime:60\r\na=ssrc:2635129322 cname:nxAVLjbaS2KXGi1g\r\na=ssrc:2635129322 msid:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BT q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BTa0\r\na=ssrc:2635129322 mslabel:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BT\r\na=ssrc:2635129322 label:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BTa0\r\nm=video 59768 RTP/SAVPF 100 116 117\r\nc=IN IP4 10.60.108.148\r\na=rtcp:59768 IN IP4 10.60.108.148\r\na=candidate:1600702733 1 udp 2113937151 10.60.108.148 59768 typ host generation 0\r\na=candidate:1600702733 2 udp 2113937151 10.60.108.148 59768 typ host generation 0\r\na=candidate:300627453 1 tcp 1509957375 10.60.108.148 50529 typ host generation 0\r\na=candidate:300627453 2 tcp 1509957375 10.60.108.148 50529 typ host generation 0\r\na=ice-ufrag:3JM/SI6Dq9Q/Bfgs\r\na=ice-pwd:FsCqFj96XEpNb/jsledUDGyX\r\na=ice-options:google-ice\r\na=extmap:2 urn:ietf:params:rtp-hdrext:toffset\r\na=sendrecv\r\na=mid:video\r\na=rtcp-mux\r\na=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:K1DxPojz8+o8n2cFjwJz+d+7VJItoQPndJ59gqqz\r\na=rtpmap:100 VP8/90000\r\na=rtcp-fb:100 ccm fir\r\na=rtcp-fb:100 nack \r\na=rtpmap:116 red/90000\r\na=rtpmap:117 ulpfec/90000\r\na=ssrc:4188930134 cname:nxAVLjbaS2KXGi1g\r\na=ssrc:4188930134 msid:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BT q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BTv0\r\na=ssrc:4188930134 mslabel:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BT\r\na=ssrc:4188930134 label:q8TulspiumkwGxDfpxiXCrNboJYU7kkFc2BTv0\r\n">>
%sample sdp from feidu <<"v=0\r\no=- 42178 42180 IN IP4 221.233.240.50\r\ns=VOS3000\r\nc=IN IP4 221.233.240.50\r\nt=0 0\r\nm=audio 5742 RTP/AVP 0 101\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:101 telephone-event/8000\r\na=fmtp:101 0-11\r\na=sendrecv\r\n">>
