-ifndef(dtls4srtp_handshake).
-define(dtls4srtp_handshake, true).

-include_lib("ssl/src/ssl_handshake.hrl").

-record(use_srtp, {protection_profile,
	               mki
	               }).

-record(dtls_server_hello, {server_version,
							random,
							session_id,
							cipher_suite,
							compression_method,
							renegotiation_info,
							hash_signs,
							elliptic_curves,
						    use_srtp}).

-record(hello_verify_request, {
	  protocol_version,
	  cookie
	 }).

-define(HELLO_VERIFY_REQUEST, 3).
-define(USE_SRTP_EXT, 16#000e).

-endif.