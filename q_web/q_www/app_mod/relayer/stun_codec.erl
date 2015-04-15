%%%-------------------------------------------------------------------
%%% File    : stun_codec.erl
%%% Author  : Evgeniy Khramtsov <ekhramtsov@process-one.net>
%%% Description : STUN codec
%%% Created :  7 Aug 2009 by Evgeniy Khramtsov <ekhramtsov@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2010   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%-------------------------------------------------------------------
-module(stun_codec).

%% API
-export([decode/1,decodeV2/2,
	 	 encode/1,encodeV2/2,
	 	 version/1,
	 	 reason/1,
	 	 pp/1]).

%% Tests
-export([test_udp/2,
	 test_tcp/2,
	 test_tls/2,
	 test_public/0]).

-include("stun.hrl").
-define(STUNHEADLENGTH,20).
-define(M_I_LENGTH, 24).
-define(FINGERPRINTLENGTH, 8).
-define(STUNXORVAL, 16#5354554E).

%%====================================================================
%% API
%%====================================================================
decode(<<0:2, Type:14, Len:16, Magic:32, TrID:96,
	Body:Len/binary, Tail/binary>>) ->
    case catch decode(Type, Magic, TrID, Body) of
	{'EXIT', _} ->
	    {error, unparsed};
	Res ->
	    {ok, Res, Tail}
    end;
decode(<<0:2, _/binary>>) ->
    more;
decode(<<>>) ->
    empty;
decode(_) ->
    {error, unparsed}.

decodeV2(RPwd, <<0:2, Type:14, Len:16, Magic:32, TrID:96, Body:Len/binary, Tail/binary>>) ->
    case catch decodeV2(RPwd, <<0:2, Type:14, Len:16, Magic:32, TrID:96>>, Type, Magic, TrID, Body) of
	{'EXIT', _} ->
	    {error, unparsed};
	Res ->
	    {ok, Res, Tail}
    end;
decodeV2(_, _) ->
	{error, unparsed}.

encode(#stun{class = Class,
	     method = Method,
	     magic = Magic,
	     trid = TrID} = Msg) ->
    ClassCode = case Class of
		    request -> 0;
		    indication -> 1;
		    response -> 2;
		    error -> 3
		end,
    Type = ?STUN_TYPE(ClassCode, Method),
    Attrs = enc_attrs(Msg),
    Len = size(Attrs),
    <<0:2, Type:14, Len:16, Magic:32, TrID:96, Attrs/binary>>.
    
encodeV2(LPwd,Msg) ->
	Raw1 = encode(Msg),
	Raw2 = if Msg#stun.'MESSAGE-INTEGRITY' == true ->
			{AuthPortion,M_I} = split_binary(Raw1,size(Raw1)-?M_I_LENGTH),
			<<MIHead:32,_/binary>> = M_I,
			MAC = crypto:sha_mac(LPwd,AuthPortion),
			<<AuthPortion/binary, MIHead:32, MAC/binary>>;
		true -> Raw1 end,
	Raw3 = if Msg#stun.'FINGERPRINT' == true ->
			<<Type:16,Len:16,Other/binary>> = Raw2,
			ActuralLen = Len + ?FINGERPRINTLENGTH,
			CRC32 = erlang:crc32(<<Type:16,ActuralLen:16,Other/binary>>) bxor ?STUNXORVAL,
			AttrFinger = enc_attr(?STUN_ATTR_FINGERPRINT,<<CRC32:32>>),
			<<Type:16,ActuralLen:16,Other/binary,AttrFinger/binary>>;
		true -> Raw2 end,
	Raw3.

pp(Term) ->
    io_lib_pretty:print(Term, fun pp/2).

version(#stun{magic = ?STUN_MAGIC}) ->
    new;
version(#stun{}) ->
    old.

reason(300) -> <<"Try Alternate">>;
reason(400) -> <<"Bad Request">>;
reason(401) -> <<"Unauthorized">>;
reason(420) -> <<"Unknown Attribute">>;
reason(438) -> <<"Stale Nonce">>;
reason(500) -> <<"Server Error">>;
reason(_) -> <<"Undefined Error">>.

%%====================================================================
%% Internal functions
%%====================================================================
decode(Type, Magic, TrID, Body) ->
    Method = ?STUN_METHOD(Type),
    Class = case ?STUN_CLASS(Type) of
		0 -> request;
		1 -> indication;
		2 -> response;
		3 -> error
	    end,
    dec_attrs(Body, #stun{class = Class,
			  method = Method,
			  magic = Magic,
			  trid = TrID}).
decodeV2(RPwd, Raw, Type, Magic, TrID, Body) ->
    Method = ?STUN_METHOD(Type),
    Class = case ?STUN_CLASS(Type) of
		0 -> request;
		1 -> indication;
		2 -> response;
		3 -> error
	    end,
    dec_attrsV2(RPwd, Raw, Body, #stun{class = Class,
										method = Method,
										magic = Magic,
										trid = TrID}).

dec_attrs(<<Type:16, Len:16, Rest/binary>>, Msg) ->
    PaddLen = padd_len(Len),
    <<Val:Len/binary, _:PaddLen, Tail/binary>> = Rest,
    NewMsg = dec_attr(Type, Val, Msg),
    if Type == ?STUN_ATTR_MESSAGE_INTEGRITY ->
        NewMsg;
      true ->
        dec_attrs(Tail, NewMsg)
    end;
dec_attrs(<<>>, Msg) ->
    Msg.

dec_attrsV2(RPwd, Raw, <<Type:16, Len:16, Rest/binary>>, Msg) ->
    PaddLen = padd_len(Len),
    <<Val:Len/binary, P:PaddLen, Tail/binary>> = Rest,
%    io:format("stun decode:~.16B~n~p~n", [Type, Val]),
    NewMsg = if Type == ?STUN_ATTR_MESSAGE_INTEGRITY ->
    		dec_integrity(RPwd,Raw,Val,Msg);
    	Type == ?STUN_ATTR_FINGERPRINT ->
    		dec_fingerprint(Raw,Val,Msg);
    	true ->
    		dec_attr(Type, Val, Msg)
    	end,
    dec_attrsV2(RPwd, <<Raw/binary, Type:16, Len:16, Val:Len/binary, P:PaddLen>>, Tail, NewMsg);
dec_attrsV2(_,_,<<>>, Msg) ->
    Msg.

enc_attrs(Msg) ->
    list_to_binary(
      [enc_attr(?STUN_ATTR_SOFTWARE, Msg#stun.'SOFTWARE'),
       enc_addr(?STUN_ATTR_MAPPED_ADDRESS, Msg#stun.'MAPPED-ADDRESS'),
       enc_xor_addr(?STUN_ATTR_XOR_MAPPED_ADDRESS,
		    Msg#stun.magic, Msg#stun.trid,
		    Msg#stun.'XOR-MAPPED-ADDRESS'),
       enc_addr(?STUN_ATTR_ALTERNATE_SERVER, Msg#stun.'ALTERNATE-SERVER'),
       enc_attr(?STUN_ATTR_USERNAME, Msg#stun.'USERNAME'),
       enc_attr(?STUN_ATTR_REALM, Msg#stun.'REALM'),
       enc_attr(?STUN_ATTR_NONCE, Msg#stun.'NONCE'),
       enc_attr(?STUN_ATTR_ICE_CONTROLLED, Msg#stun.'ICE-CONTROLLED'),
       enc_attr(?STUN_ATTR_ICE_CONTROLLING, Msg#stun.'ICE-CONTROLLING'),
       enc_attr(?STUN_ATTR_USER_CANDIDATE, Msg#stun.'USER-CANDIDATE'),
       enc_attr(?STUN_ATTR_PRIORITY, Msg#stun.'PRIORITY'),
       enc_attr(?STUN_ATTR_MESSAGE_INTEGRITY, Msg#stun.'MESSAGE-INTEGRITY'),
       enc_attr(?STUN_ATTR_FINGERPRINT, Msg#stun.'FINGERPRINT'),
       enc_error_code(Msg#stun.'ERROR-CODE'),
       enc_unknown_attrs(Msg#stun.'UNKNOWN-ATTRIBUTES')]).

dec_attr(?STUN_ATTR_MAPPED_ADDRESS, Val, Msg) ->
    <<_, Family, Port:16, AddrBin/binary>> = Val,
    Addr = dec_addr(Family, AddrBin),
    Msg#stun{'MAPPED-ADDRESS' = {Addr, Port}};
dec_attr(?STUN_ATTR_XOR_MAPPED_ADDRESS, Val, Msg) ->
    <<_, Family, XPort:16, XAddr/binary>> = Val,
    Magic = Msg#stun.magic,
    Port = XPort bxor (Magic bsr 16),
    Addr = dec_xor_addr(Family, Magic, Msg#stun.trid, XAddr),
    Msg#stun{'XOR-MAPPED-ADDRESS' = {Addr, Port}};
dec_attr(?STUN_ATTR_SOFTWARE, Val, Msg) ->
    Msg#stun{'SOFTWARE' = Val};
dec_attr(?STUN_ATTR_USERNAME, Val, Msg) ->
    Msg#stun{'USERNAME' = Val};
dec_attr(?STUN_ATTR_REALM, Val, Msg) ->
    Msg#stun{'REALM' = Val};
dec_attr(?STUN_ATTR_NONCE, Val, Msg) ->
    Msg#stun{'NONCE' = Val};
dec_attr(?STUN_ATTR_MESSAGE_INTEGRITY, Val, Msg) ->
    Msg#stun{'MESSAGE-INTEGRITY' = Val};
dec_attr(?STUN_ATTR_USER_CANDIDATE, Val, Msg) ->
	Msg#stun{'USER-CANDIDATE' = Val};
dec_attr(?STUN_ATTR_ALTERNATE_SERVER, Val, Msg) ->
    <<_, Family, Port:16, Address/binary>> = Val,
    IP = dec_addr(Family, Address),
    Msg#stun{'ALTERNATE-SERVER' = {IP, Port}};
dec_attr(?STUN_ATTR_ERROR_CODE, Val, Msg) ->
    <<_:21, Class:3, Number:8, Reason/binary>> = Val,
    if Class >=3, Class =< 6, Number >=0, Number =< 99 ->
	    Code = Class * 100 + Number,
	    Msg#stun{'ERROR-CODE' = {Code, Reason}}
    end;
dec_attr(?STUN_ATTR_UNKNOWN_ATTRIBUTES, Val, Msg) ->
    Attrs = dec_unknown_attrs(Val, []),
    Msg#stun{'UNKNOWN-ATTRIBUTES' = Attrs};
dec_attr(?STUN_ATTR_PRIORITY, Val, Msg) ->
    Msg#stun{'PRIORITY' = Val};
dec_attr(?STUN_ATTR_ICE_CONTROLLING, Val, Msg) ->
	Msg#stun{'ICE-CONTROLLING' = Val};
dec_attr(Attr, _Val, #stun{unsupported = Attrs} = Msg)
  when Attr =< 16#7fff ->
    Msg#stun{unsupported = [Attr|Attrs]};
dec_attr(_Attr, _Val, Msg) ->
    Msg.

dec_integrity(RPwd,Raw,Val,Msg) ->
	Res = chk_integrity(RPwd,Raw,Val),
	Msg#stun{'MESSAGE-INTEGRITY' = Res}.

dec_fingerprint(Raw,Val,Msg) ->
	Res = chk_fingerprint(Raw,Val),
	Msg#stun{'FINGERPRINT' = Res}.

chk_integrity(RPwd,Raw,Val) ->
	ActuralLen = size(Raw) - ?STUNHEADLENGTH + ?M_I_LENGTH,
	<<ReqType:16,_Len:16,Rest/binary>> = Raw,
	MAC = crypto:sha_mac(RPwd,<<ReqType:16,ActuralLen:16,Rest/binary>>),
	MAC =:= Val.
chk_fingerprint(Raw,<<Val:32>>) ->
	CRC32 = erlang:crc32(Raw) bxor ?STUNXORVAL,
	CRC32 =:= Val.

dec_addr(1, <<A1, A2, A3, A4>>) ->
    {A1, A2, A3, A4};
dec_addr(2, <<A1:16, A2:16, A3:16, A4:16,
	     A5:16, A6:16, A7:16, A8:16>>) ->
    {A1, A2, A3, A4, A5, A6, A7, A8}.

dec_xor_addr(1, Magic, _TrID, <<XAddr:32>>) ->
    Addr = XAddr bxor Magic,
    dec_addr(1, <<Addr:32>>);
dec_xor_addr(2, Magic, TrID, <<XAddr:128>>) ->
    Addr = XAddr bxor ((Magic bsl 96) bor TrID),
    dec_addr(2, <<Addr:128>>).

dec_unknown_attrs(<<Attr:16, Tail/binary>>, Acc) ->
    dec_unknown_attrs(Tail, [Attr|Acc]);
dec_unknown_attrs(<<>>, Acc) ->
    lists:reverse(Acc).

enc_attr(_Attr, Val) when Val==undefined;Val==false ->
    <<>>;
enc_attr(?STUN_ATTR_FINGERPRINT,true) ->
	<<>>;															% calculate when pack
enc_attr(?STUN_ATTR_MESSAGE_INTEGRITY,true) ->
	Dummy = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	% 20 zero
	<<?STUN_ATTR_MESSAGE_INTEGRITY:16,20:16,Dummy/binary>>;
enc_attr(?STUN_ATTR_FINGERPRINT,Val) when is_binary(Val) ->
	<<?STUN_ATTR_FINGERPRINT:16,4:16,Val/binary>>;
enc_attr(Attr, Val) ->
    Len = size(Val),
    PaddLen = padd_len(Len),
    <<Attr:16, Len:16, Val/binary, 0:PaddLen>>.

enc_addr(_Type, undefined) ->
    <<>>;
enc_addr(Type, {{A1, A2, A3, A4}, Port}) ->
    enc_attr(Type, <<0, 1, Port:16, A1, A2, A3, A4>>);
enc_addr(Type, {{A1, A2, A3, A4, A5, A6, A7, A8}, Port}) ->
    enc_attr(Type, <<0, 2, Port:16, A1:16, A2:16, A3:16,
		    A4:16, A5:16, A6:16, A7:16, A8:16>>).

enc_xor_addr(_Type, _Magic, _TrID, undefined) ->
    <<>>;
enc_xor_addr(Type, Magic, _TrID, {{A1, A2, A3, A4}, Port}) ->
    XPort = Port bxor (Magic bsr 16),
    <<Addr:32>> = <<A1, A2, A3, A4>>,
    XAddr = Addr bxor Magic,
    enc_attr(Type, <<0, 1, XPort:16, XAddr:32>>);
enc_xor_addr(Type, Magic, TrID,
	     {{A1, A2, A3, A4, A5, A6, A7, A8}, Port}) ->
    XPort = Port bxor (Magic bsr 16),
    <<Addr:128>> = <<A1:16, A2:16, A3:16, A4:16,
		    A5:16, A6:16, A7:16, A8:16>>,
    XAddr = Addr bxor ((Magic bsl 96) bor TrID),
    enc_attr(Type, <<0, 2, XPort:16, XAddr:128>>).

enc_error_code(undefined) ->
    <<>>;
enc_error_code({Code, Reason}) ->
    Class = Code div 100,
    Number = Code rem 100,
    enc_attr(?STUN_ATTR_ERROR_CODE,
	     <<0:21, Class:3, Number:8, Reason/binary>>).

enc_unknown_attrs([]) ->
    <<>>;
enc_unknown_attrs(Attrs) ->
    enc_attr(?STUN_ATTR_UNKNOWN_ATTRIBUTES,
	     list_to_binary([<<Attr:16>> || Attr <- Attrs])).

%%====================================================================
%% Auxiliary functions
%%====================================================================
pp(Tag, N) ->
    try
	pp1(Tag, N)
    catch _:_ ->
	    no
    end.

pp1(stun, N) ->
    N = record_info(size, stun) - 1,
    record_info(fields, stun);
pp1(_, _) ->
    no.

%% Workaround for stupid clients.
-ifdef(NO_PADDING).
padd_len(_Len) ->
    0.
-else.
padd_len(Len) ->
    case Len rem 4 of
	0 -> 0;
	N -> 8*(4-N)
    end.
-endif.

%%====================================================================
%% Test functions
%%====================================================================
bind_msg() ->
    Msg = #stun{method = ?STUN_METHOD_BINDING,
		class = request,
		trid = random:uniform(1 bsl 96),
		'SOFTWARE' = <<"test">>},
    encode(Msg).

test_udp(Addr, Port) ->
    test(Addr, Port, gen_udp).

test_tcp(Addr, Port) ->
    test(Addr, Port, gen_tcp).

test_tls(Addr, Port) ->
    test(Addr, Port, ssl).

test(Addr, Port, Mod) ->
    Res = case Mod of
	      gen_udp ->
		  Mod:open(0, [binary, {active, false}]);
	      _ ->
		  Mod:connect(Addr, Port,
			      [binary, {active, false}], 1000)
	  end,
    case Res of
	{ok, Sock} ->
	    if Mod == gen_udp ->
		    Mod:send(Sock, Addr, Port, bind_msg());
	       true ->
		    Mod:send(Sock, bind_msg())
	    end,
	    case Mod:recv(Sock, 0, 1000) of
		{ok, {_, _, Data}} ->
		    try_dec(Data);
		{ok, Data} ->
		    try_dec(Data);
		Err ->
		    io:format("err: ~p~n", [Err])
	    end,
	    Mod:close(Sock);
	Err ->
	    io:format("err: ~p~n", [Err])
    end.

try_dec(Data) ->
    case decode(Data) of
	{ok, Msg, _} ->
	    io:format("got:~n~s~n", [pp(Msg)]);
	Err ->
	    io:format("err: ~p~n", [Err])
    end.

public_servers() ->
    [{"stun.ekiga.net", 3478, 3478, 5349},
     {"stun.fwdnet.net", 3478, 3478, 5349},
     {"stun.ideasip.com", 3478, 3478, 5349},
     {"stun01.sipphone.com", 3478, 3478, 5349},
     {"stun.softjoys.com", 3478, 3478, 5349},
     {"stun.voipbuster.com", 3478, 3478, 5349},
     {"stun.voxgratia.org", 3478, 3478, 5349},
     {"stun.xten.com", 3478, 3478, 5349},
     {"stunserver.org", 3478, 3478, 5349},
     {"stun.sipgate.net", 10000, 10000, 5349},
     {"numb.viagenie.ca", 3478, 3478, 5349},
     {"stun.ipshka.com", 3478, 3478, 5349},
     {"localhost", 3478, 5349, 5349}].

test_public() ->
    ssl:start(),
    lists:foreach(
      fun({Addr, UDPPort, TCPPort, TLSPort}) ->
	      io:format("trying ~s:~p on UDP... ", [Addr, UDPPort]),
	      test_udp(Addr, UDPPort),
	      io:format("trying ~s:~p on TCP... ", [Addr, TCPPort]),
	      test_tcp(Addr, TCPPort),
	      io:format("trying ~s:~p on TLS... ", [Addr, TLSPort]),
	      test_tls(Addr, TLSPort)
      end, public_servers()).
