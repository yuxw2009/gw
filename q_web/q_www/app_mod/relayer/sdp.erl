%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2010 Max Lapshin
%%% @doc        SDP decoder module
%%% @end
%%% @reference  See <a href="http://erlyvideo.org/rtp" target="_top">http://erlyvideo.org</a> for common information.
%%% @end
%%%
%%% This file is part of erlang-rtp.
%%%
%%% erlang-rtp is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% erlang-rtp is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with erlang-rtp.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%---------------------------------------------------------------------------------------
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
  KeyValues = [{list_to_atom([K]), Value} || [K,$=|Value] <- Lines],
  decode(KeyValues);

decode(Announce) ->
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
      parse_session(Announce, Session#session_desc{attrs=[{group,Value}|Attr0]});
    _ ->
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

%%
parse_announce([], Streams, undefined, _Connect) ->
  lists:reverse(Streams);

parse_announce([], Streams, Stream, Connect) ->
  lists:reverse([Stream#media_desc{connect=Connect} | Streams]);

%parse_announce([{v, _} | Announce], Streams, Stream, Connect) ->
%  parse_announce(Announce, Streams, Stream, Connect);

%parse_announce([{o, _} | Announce], Streams, Stream, Connect) ->
%  parse_announce(Announce, Streams, Stream, Connect);

%parse_announce([{s, _} | Announce], Streams, Stream, Connect) ->
%  parse_announce(Announce, Streams, Stream, Connect);

parse_announce([{e, _} | Announce], Streams, Stream, Connect) ->
  parse_announce(Announce, Streams, Stream, Connect);

parse_announce([{b, _} | Announce], Streams, undefined, Connect) ->
  parse_announce(Announce, Streams, undefined, Connect);

parse_announce([{c, Connect} | Announce], Streams, Stream, undefined) ->
  Parsed = parse_connect(Connect),
  parse_announce(Announce, Streams, Stream, Parsed);

%parse_announce([{t, _} | Announce], Streams, Stream, Connect) ->
%  parse_announce(Announce, Streams, Stream, Connect);

parse_announce([{a, _} | Announce], Streams, undefined, Connect) ->
  parse_announce(Announce, Streams, undefined, Connect);

parse_announce([{m, Info} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  parse_announce([{m, Info} | Announce], [Stream#media_desc{connect=Connect} | Streams], undefined, Connect);

parse_announce([{m, Info} | Announce], Streams, undefined, Connect) ->
  [TypeS, PortS, "RTP/"++PF | PayloadTypes] = string:tokens(Info, " "), % TODO: add support of multiple payload
  Type = binary_to_existing_atom(list_to_binary(TypeS), utf8),
  MediaDesc = #media_desc{type=Type, profile=PF, connect = Connect, port = list_to_integer(PortS),
						  payloads = [#payload{num = list_to_integer(PT)} || PT <- PayloadTypes]},
  parse_announce(Announce, Streams, MediaDesc, Connect);

parse_announce([{b, _Bitrate} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  parse_announce(Announce, Streams, Stream, Connect);

parse_announce([{a, Attribute} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  case string:chr(Attribute, $:) of
    0 -> Key = Attribute, Value = undefined;
    Pos when Pos > 0 ->
      Key = string:substr(Attribute, 1, Pos - 1),
      Value = string:substr(Attribute, Pos + 1)
  end,

  Stream1 = case Key of
    "rtpmap" ->
      {ok, Re} = re:compile("(\\d+) ([^/]+)/([\\d]+)"),
      {match, [_, PayLoadNum, CodecCode, ClockMap1]} = re:run(Value, Re, [{capture, all, list}]),
      Pt0 = Stream#media_desc.payloads,
      Codec = str2codec(CodecCode),
      ClockMap = case Codec of
        g726_16 -> 8000;
        _ -> list_to_integer(ClockMap1)
      end,
      Pt1 = #payload{num = list_to_integer(PayLoadNum), codec = Codec, clock_map = ClockMap},
      NewPt = lists:keystore(Pt1#payload.num, #payload.num, Pt0, Pt1),
      Stream#media_desc{payloads = NewPt};
    "control" ->
      Stream#media_desc{track_control = Value};
    "fmtp" ->
      {ok, Re} = re:compile("([^=]+)=(.*)"),
      [_ | OptList] = string:tokens(Value, " "),
      Opts = lists:map(fun(Opt) ->
        case re:run(Opt, Re, [{capture, all, list}]) of
          {match, [_, Key1, Value1]} ->
            {string:to_lower(Key1), Value1};
          _ -> Opt
        end
      end, string:tokens(string:join(OptList, ""), ";")),
      parse_fmtp(Stream, Opts);
    "ice"++Type ->
      NewICE = case Type of
        	"-ufrag" ->
        		{Value,""};
        	"-pwd" ->
        		{element(1,Stream#media_desc.ice),Value};
        	"-options" ->
        		Stream#media_desc.ice
        end,
      Stream#media_desc{ice = NewICE};
    "crypto" ->
      parse_crypto(Stream, Value);
    "ssrc" ->
      %"ssrc:2860201785 cname:8NA5PsQtN20xOoGB"
      {ok, Re} = re:compile("(\\d+) ([^:]+):([^$]+)"),
      {match, [_, SSID, Type, Str]} = re:run(Value, Re, [{capture, all, list}]),
      SSRC = Stream#media_desc.ssrc_info,
      Stream#media_desc{ssrc_info = lists:keystore(Type,2,SSRC,{SSID,Type,Str})};
    "sendrecv" ->
      NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
      Stream#media_desc{attrs = NewAttrs};
    "recvonly" ->
      NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
      Stream#media_desc{attrs = NewAttrs};
    "mid" ->
      NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
      Stream#media_desc{attrs = NewAttrs};
    "rtcp-mux" ->
      NewAttrs = lists:keystore(Key,1,Stream#media_desc.attrs,{Key,Value}),
      Stream#media_desc{attrs = NewAttrs};
    "rtcp" ->
      {RTCPPort,Connect2} = parse_rtcp(Value),
      Stream#media_desc{rtcp = {RTCPPort,Connect2}};
    "candidate" ->
      AttCH = <<"a=candidate:">>,
      AttCV = list_to_binary(Value),
      Cndd = cndd:decode(<<AttCH/binary,AttCV/binary>>),
      NewCandids = Stream#media_desc.candidates ++ [Cndd],
      Stream#media_desc{candidates = NewCandids};
    _Else ->
      io:format("sdp unknow attr: ~p:~p~n",[Key,Value]),
      Stream
  end,
  parse_announce(Announce, Streams, Stream1, Connect);

parse_announce([{c, Connect} | Announce], Streams, #media_desc{} = Stream, Connect) ->
  parse_announce(Announce, Streams, Stream#media_desc{connect = Connect}, Connect);

parse_announce([{_Other, _Info} | Announce], Streams, Stream, Connect) ->
  parse_announce(Announce, Streams, Stream, Connect).


parse_fmtp(#media_desc{type = video} = Stream, Opts) ->
  case proplists:get_value("sprop-parameter-sets", Opts) of
    Sprop when is_list(Sprop) ->
      case [base64:decode(S) || S <- string:tokens(Sprop, ",")] of
        [SPS, PPS] -> Stream#media_desc{pps = PPS, sps = SPS};
        [SPS, PPS|_] -> error_logger:error_msg("SDP with many PPS: ~p", [Sprop]), Stream#media_desc{pps = PPS, sps = SPS};
        _ -> Stream
      end;
    _ ->
      Stream
  end;

parse_fmtp(#media_desc{type = audio} = Stream, Opts) ->
  Config = case proplists:get_value("config", Opts) of
    undefined -> undefined;
    HexConfig -> ssl_debug:unhex(HexConfig)
  end,
  Stream#media_desc{config = Config}.

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

parse_crypto(Stream, Crypto) ->
  %"1 AES_CM_128_HMAC_SHA1_80 inline:XE+QXqoqyFUkRzQxUq/8PyMaRQk27YuK6FlcN1tX"
  Params = re:split(Crypto, "[ :]", [{return, list}]),
  Stream#media_desc{crypto={lists:nth(1,Params),lists:nth(2,Params),lists:nth(4,Params)}}.

%%
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
                 {K, V} when (is_atom(K)
                              andalso (is_list(V) or is_binary(V))) ->
                   [atom_to_list(K), $:, V];
                 _ when is_atom(KV) ->
                   atom_to_list(KV);
                 _Other ->
                   io:format("Err: ~p~n", [KV]),
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
						 profile = PF,
                         connect = Connect,
                         rtcp = RTCP,
                         candidates = Candids,
                         port = Port,
                         payloads = PayLoads,
                         track_control = TControl,
                         config = Config,
                         attrs = Attrs,
                         ice = ICE,
                         crypto = Crypto,
                         ssrc_info = SSRC
                        }, _GConnect, _A) ->
  Tb = type2bin(Type),
  M = ["m=", Tb, $ , integer_to_list(Port), $ , "RTP/", PF, $ ,
       string:join([integer_to_list(PTnum) || #payload{num = PTnum} <- PayLoads], " "), ?LSEP],
  MC= enc_connect(Connect),
  MRTCP = enc_rtcp_attr(RTCP),
  MCandid = enc_candidates(Candids),
  EAttr = enc_attrs(Attrs),
  EICE = enc_ice(ICE),
  ECry = enc_crypto(Crypto),
  ESSRC = enc_ssrc(SSRC),
  AC = case TControl of undefined -> []; _ -> ["a=", "control:", TControl, ?LSEP] end,
  %% TODO: support of several payload types
  AR = [begin
          Codecb = codec2bin(Codec),
          CMapb = integer_to_list(ClockMap),
          if is_list(PTConfig) ->
              PTC = [["a=", "fmtp:", integer_to_list(PTnum), $ , C, ?LSEP] || C <- PTConfig];
             true ->
              PTC = []
          end,
          if is_integer(PTime) ->
              PTimeS = ["a=", "ptime:", integer_to_list(PTime), ?LSEP];
             true ->
              PTimeS = []
          end,
          if is_integer(MaxPt) ->
              MaxPT = ["a=", "maxptime:", integer_to_list(MaxPt), ?LSEP];
             true ->
              MaxPT = []
          end,
          [["a=", "rtpmap:", integer_to_list(PTnum), $ , Codecb, $/, CMapb, ?LSEP], PTC, PTimeS,MaxPT]
        end || #payload{num = PTnum, codec = Codec,clock_map = ClockMap,
                        ptime = PTime, maxptime=MaxPt,config = PTConfig} <- PayLoads,Codec=/=undefined],
  ACfg = case Config of
           %% _ when (is_list(Config) or
           %%         is_binary(Config)) ->
           _ when ((is_list(Config) and (length(Config) > 0))
                   or (is_binary(Config) and (size(Config) > 0))) ->
             [["a=", "fmtp:", integer_to_list(PTnum), $ , Config, ?LSEP] || #payload{num = PTnum} <- PayLoads];
           _ ->
             []
         end,
  iolist_to_binary([M, MC,MRTCP,MCandid,EAttr,EICE,ECry,AC, AR, ACfg,ESSRC]);
encode_media(_, _, _) ->
  <<>>.

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
    noise -> <<"CN">>;
    telephone -> <<"telephone-event">>;
    iSAC -> <<"ISAC">>;
    vp8 -> <<"VP8">>;
    red -> <<"red">>;
    ulpfec -> <<"ulpfec">>;
    opus -> <<"opus">>;
    pcm -> <<"L16">>
  end.

str2codec(CodecCode) ->
	case CodecCode of
        "PCMA" -> pcma;
        "PCMU" -> pcmu;
        "CN" -> noise;
        "telephone-event" -> telephone;
		"ISAC" -> iSAC;
		"VP8" -> vp8;
		"red" -> red;
		"ulpfec" -> ulpfec;
		"opus" -> opus;
        "L16" -> pcm
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

