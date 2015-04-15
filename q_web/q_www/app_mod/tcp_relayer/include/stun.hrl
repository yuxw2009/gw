-define(VERSION, "1.0").
-define(STUN_MAGIC, 16#2112a442).

%% I know, this is terrible. Refer to 'STUN Message Structure' of
%% RFC5389 to understand this.
-define(STUN_METHOD(Type),
	((Type band 16#3e00) bsr 2) bor
	((Type band 16#e0) bsr 1) bor (Type band 16#f)).
-define(STUN_CLASS(Type),
	((Type band 16#100) bsr 7) bor
	((Type band 16#10) bsr 4)).
-define(STUN_TYPE(C, M),
	(((M band 16#f80) bsl 2)
	 bor ((M band 16#70) bsl 1)
	 bor (M band 16#f) )
	bor (((C band 16#2) bsl 7) bor ((C band 16#1) bsl 4))).

-define(is_required(A), (A =< 16#7fff)).

-define(STUN_METHOD_BINDING, 16#001).

%% Comprehension-required range (0x0000-0x7FFF)
-define(STUN_ATTR_MAPPED_ADDRESS, 16#0001).
-define(STUN_ATTR_USERNAME, 16#0006).
-define(STUN_ATTR_MESSAGE_INTEGRITY, 16#0008).
-define(STUN_ATTR_ERROR_CODE, 16#0009).
-define(STUN_ATTR_UNKNOWN_ATTRIBUTES, 16#000a).
-define(STUN_ATTR_REALM, 16#0014).
-define(STUN_ATTR_NONCE, 16#0015).
-define(STUN_ATTR_XOR_MAPPED_ADDRESS, 16#0020).
-define(STUN_ATTR_PRIORITY, 16#24).
-define(STUN_ATTR_USER_CANDIDATE, 16#25).

%% Comprehension-optional range (0x8000-0xFFFF)
-define(STUN_ATTR_SOFTWARE, 16#8022).
-define(STUN_ATTR_ALTERNATE_SERVER, 16#8023).
-define(STUN_ATTR_FINGERPRINT, 16#8028).
-define(STUN_ATTR_ICE_CONTROLLED, 16#8029).
-define(STUN_ATTR_ICE_CONTROLLING, 16#802A).

-record(stun, {class,
	       method,
	       magic = ?STUN_MAGIC,
	       trid,
	       unsupported = [],
	       'SOFTWARE',
	       'ALTERNATE-SERVER',
	       'MAPPED-ADDRESS',
	       'XOR-MAPPED-ADDRESS',
	       'USERNAME',
	       'REALM',
	       'NONCE',
	       'MESSAGE-INTEGRITY',
	       'ERROR-CODE',
	       'PRIORITY',
	       'USER-CANDIDATE',
	       'ICE-CONTROLLED',
	       'ICE-CONTROLLING',
	       'FINGERPRINT',
	       'UNKNOWN-ATTRIBUTES' = []}).
