-module(dtls4srtp_test).

-compile(export_all).

-include_lib("ssl/src/ssl_internal.hrl").
-include_lib("ssl/src/ssl_handshake.hrl").
-include("dtls4srtp_record.hrl").

as_client() ->
    application:start(crypto),
    application:start(asn1),
    application:start(public_key),
    application:start(ssl),

    CertF = "./MyCert.pem",
    KeyF = "./MyCert_key.pem",

    Dtls = dtls4srtp:new(client, not_specified, undefined, CertF, KeyF),

    {ok, Socket} =gen_udp:open(5670, [binary, {active, true}, {recbuf, 8192}]),
    Owner = spawn(fun() -> test_loop(Dtls, undefined, Socket) end),
    gen_udp:controlling_process(Socket, Owner),

    %
    PeerIPPort = mock_peer_ipport(),
    PeerFingerprint = mock_peer_fingerprint(),
    Owner ! {start, PeerIPPort, PeerFingerprint},

    timer:send_after(3000, Owner, stop).

test_loop(D, Peer, Sock) ->
    receive
    	{start, PeerIpPort, PeerFP} ->
    	    dtls4srtp:set_owner(D, self()),
            dtls4srtp:set_peer_cert_fingerprint(D, PeerFP),
            dtls4srtp:start(D),
            test_loop(D, PeerIpPort, Sock);
    	{dtls, flight, <<_RecordType,254,255,_Epoch:16,_Seq:48,_Len:16, _ContentType, _Bin/binary>>=Data} ->
    	    io:format("Data:~n~p~n", [Data]),
            send_flight(Sock, Peer, Data),
    	    test_loop(D, Peer, Sock);
        {udp, _Socket, _Addr, _Port, <<0:2,_:1,1:1,_:1,1:1,_:2,_/binary>>=DtlsFlight} ->
            dtls4srtp:on_received(D, DtlsFlight),
            test_loop(D, Peer, Sock);
    	stop ->
            dtls4srtp:shutdown(D),
    	    io:format("test stopped.~n")
    end.

mock_peer_ipport() ->
    {"x.x.x.x", 5670}.

mock_peer_fingerprint() ->
    {sha256, <<16#aa>>}.

send_flight(Sock, {PeerIp, PeerPort}, Data) ->
    gen_udp:send(Sock, PeerIp, PeerPort, Data).

mock_server_hello() ->
    <<16#16feff000000000000000000680200005c000000000000005cfeff51b921f625f98b9dd4411f2d77197366ba36ec243c21bce04c0ee1e6f3fb4c7a2010e4b1ff3803bd3913daf688840f2b4e570028ee6286169e60d7f857d59b1f1cc014000014ff01000100000b00020100000e0005000200010016feff000000000000000101e30b0001d700010000000001d70001d40001d1308201cd30820136a0030201020204416e5fbd300d06092a864886f70d0101050500302b31293027060355040313203465316338636236343632303361633335643531336462356565346434323462301e170d3133303631323031333533305a170d3133303731333031333533305a302b3129302706035504031320346531633863623634363230336163333564353133646235656534643432346230819f300d06092a864886f70d010101050003818d0030818902818100c74badbafd8bc4e3aadbe79f4326cdd4eb42b6be5baaf9375fa2bfa9f836bd4e5169639a35807363f7c32ee94df6cd7bffd6198de119b9bfe007a2f648956cd70e4d59cb8145f2c35656b6443cf0520d40553115c78f354e707bc0cebec173b24fd6617bc6812262a7b040b791a98057130abc83454775f2d2cd07b073526ccf0203010001300d06092a864886f70d01010505000381810090f19d7ee4ce97e3774b0505556b79299f874ab985b252cabefd0c77dc6da9663419bd7c1c16f39a78285781f9b8f750247bccd55db6f02ddc3ec17926501b7daeb1b6fa786d252b0504fa269aac9f362651ee1e628dc663991f7eb7163e8b40b6c0ef44ee8e3c18bd275524fa658eb89b3e97a8912be7b0328a9921cb580a0516feff000000000000000200d30c0000c700020000000000c7030017410475dffd54868e13550638cc21e017457d8b79efa14ff86ffedf405496b01681482aed610afe5d847b12f30a40a15a52ee2437314a35edd94c5fbf2ec248ac350300807958d5b5c391f42dd86b1b4fd3c4186d3a35aa6bf29f402077333318c6963e7047399def3660c050879ca40a40f1d77cd8fe38c00133d7309370e11030a5fb828e19e904d8e55b96871ef02f2c55aed72aa63bf87a231001e1ffc34ab8bdb1cb23a5fd1be2a4fb2271b0d6f26a8f1eec4b8ef768b35c9ac26fcc912fadd01f5616feff000000000000000300120d000006000300000000000603010240000016feff0000000000000004000c0e0000000004000000000000:7144>>.

mock_change_spec() ->
    <<16#14feff000000000000000500010116feff00010000000000000040ffc8b8e782709773bcb7e38afb3153dadbae097005b47b381a400411b6f922ea9cc815565eeeab5c3d0933954a148fa2a1638ffb9cbe389da2fb7551c3776f13:728>>.
