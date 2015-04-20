-module(tt).
-compile(export_all).

-include("sdp.hrl").

ss() ->
<<"
v=0
o=LTALK 100 1000 IN IP4 10.32.3.41
s=phone-call
c=IN IP4 0.0.0.0
t=0 0
m=audio 10792 RTP/AVP 18 4 8 0 101
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11
a=ptime:20\r\n\r\n">>.



ans() ->
<<"
v=0\r\n
o=- 1750149717 1 IN IP4 127.0.0.1\r\n
s=-\r\n
t=0 0\r\n
a=group:BUNDLE audio video\r\n
m=audio 1 RTP/SAVPF 103 104 0 8 106 105 13 126\r\n
c=IN IP4 0.0.0.0\r\n
a=rtcp:1 IN IP4 0.0.0.0\r\n
a=ice-ufrag:A/BvxuLODiaNYUfa\r\n
a=ice-pwd:71yKvJaoOz33eX+DAGM6B0Km\r\n
a=sendrecv\r\n
a=mid:audio\r\n
a=rtcp-mux\r\n
a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:XE+QXqoqyFUkRzQxUq/8PyMaRQk27YuK6FlcN1tX\r\n
a=rtpmap:103 ISAC/16000\r\n
a=rtpmap:104 ISAC/32000\r\n
a=rtpmap:0 PCMU/8000\r\n
a=rtpmap:8 PCMA/8000\r\n
a=rtpmap:106 CN/32000\r\n
a=rtpmap:105 CN/16000\r\n
a=rtpmap:13 CN/8000\r\n
a=rtpmap:126 telephone-event/8000\r\n
a=ssrc:3393357413 cname:8NA5PsQtN20xOoGB\r\n
a=ssrc:3393357413 mslabel:NHo2ZBoj9xPTUze7kwPOEviHw7f4ogFdd6hU\r\n
a=ssrc:3393357413 label:NHo2ZBoj9xPTUze7kwPOEviHw7f4ogFdd6hU00\r\n
m=video 1 RTP/SAVPF 100 101 102\r\n
c=IN IP4 0.0.0.0\r\n
a=rtcp:1 IN IP4 0.0.0.0\r\n
a=ice-ufrag:A/BvxuLODiaNYUfa\r\n
a=ice-pwd:71yKvJaoOz33eX+DAGM6B0Km\r\n
a=ice-options:google-ice\r\n
a=sendrecv\r\n
a=mid:video\r\n
a=rtcp-mux\r\n
a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:XE+QXqoqyFUkRzQxUq/8PyMaRQk27YuK6FlcN1tX\r\n
a=rtpmap:100 VP8/90000\r\n
a=rtpmap:101 red/90000\r\n
a=rtpmap:102 ulpfec/90000\r\n
a=ssrc:1132651326 cname:Rqm01FNyCgMqLqB6
a=ssrc:1132651326 msid:2i5hZHedZ2WsFgNarHqjul3ZrtKUuj4Isuur a0
a=ssrc:1132651326 mslabel:2i5hZHedZ2WsFgNarHqjul3ZrtKUuj4Isuur
a=ssrc:1132651326 label:2i5hZHedZ2WsFgNarHqjul3ZrtKUuj4Isuura0
 ">>.

offr() ->
<<"v=0\r\no=- 1304402651 3 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\n
a=group:BUNDLE audio\r\n
m=audio 52484 RTP/SAVPF 103 104 111 0 8 107 106 105 13 126\r\n
c=IN IP4 10.60.108.149\r\n
a=rtcp:52484 IN IP4 10.60.108.149\r\n
a=candidate:1802278933 1 udp 2113937151 10.60.108.149 52484 typ host generation 0\r\n
a=candidate:1802278933 2 udp 2113937151 10.60.108.149 52484 typ host generation 0\r\n
a=ice-ufrag:6xv4Yg+4CtK47V0W\r\n
a=ice-pwd:1aZb2COKJdrW0nD7H+nBExzW\r\n
a=ice-options:google-ice\r\n
a=sendrecv\r\n
a=mid:audio\r\n
a=rtcp-mux\r\n
a=crypto:0 AES_CM_128_HMAC_SHA1_32 inline:H/n9HFOtjZFyDX2mtLh0wtgSXfPZzZb353aQjLCW\r\na=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:vkv5nUtMc8iyftj/xnd24T4WbozemS/b7MUYQJHf\r\na=rtpmap:103 ISAC/16000\r\na=rtpmap:104 ISAC/32000\r\na=rtpmap:111 opus/48000\r\na=rtpmap:0 PCMU/8000\r\na=rtpmap:8 PCMA/8000\r\na=rtpmap:107 CN/48000\r\na=rtpmap:106 CN/32000\r\na=rtpmap:105 CN/16000\r\na=rtpmap:13 CN/8000\r\na=rtpmap:126 telephone-event/8000\r\na=ssrc:797531070 cname:m9zg14kBs2NnK5ao\r\na=ssrc:797531070 msid:QnY1CMTebT1IL5xrfcknco3SVXnNDI6PjvZ5 a0\r\na=ssrc:797531070 mslabel:QnY1CMTebT1IL5xrfcknco3SVXnNDI6PjvZ5\r\na=ssrc:797531070 label:QnY1CMTebT1IL5xrfcknco3SVXnNDI6PjvZ5a0\r\n
">>.
	
'SAMPLE'(Port) -> 
	Orig = #sdp_o{username = <<"VOS3000">>,
				  sessionid = "1234",
				  version = "1",
				  netaddrtype = inet4,
				  address = "10.61.34.50"},
	Sess = #session_desc{version = <<"0">>,
						 originator = Orig,
						 name = "phone-call",
						 connect = {inet4,"10.61.34.50"},
						 time = {0,0},
						 attrs = []},
	PL1 = #payload{num = 0},
	PL2 = #payload{num = 8},
	PL3 = #payload{num = 101,
				   codec = telephone,
				   clock_map = 8000,
				   config = [{0,11}]},
	Stream = #media_desc{type = audio,
						 port = Port,
						 payloads = [PL1,PL2,PL3],
						 config = [#ptime{avg=20}],
						 profile = "AVP"},
	{Sess,Stream}.

d() ->
	{Session,Streams} = sdp:decode(ans()),
	NewAttrs = lists:keyreplace(group,1,Session#session_desc.attrs,{group,"BUNDLE audio"}),
	[Audio] = [Strm||Strm<-Streams,Strm#media_desc.type==audio],
	P1 = lists:keydelete(103,2,Audio#media_desc.payloads),
	P2 = lists:keydelete(104,2,P1),
	P3 = lists:keydelete(105,2,P2),
	P4 = lists:keydelete(106,2,P3),
	P5 = lists:keydelete(126,2,P4),
	P6 = lists:keydelete(13,2,P5),
%	sdp:encode(Session#session_desc{attrs=NewAttrs},[Audio#media_desc{payloads=P6}]).
	{Session#session_desc{attrs=NewAttrs},[Audio#media_desc{payloads=P6}]}.