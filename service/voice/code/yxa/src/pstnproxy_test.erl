%%%-------------------------------------------------------------------
%%% File    : pstnproxy_test.erl
%%% @author   Fredrik Thulin <ft@it.su.se>
%%% @doc      Test cases for the complete pstnproxy application.
%%%
%%% @since    29 Nov 2006 by Fredrik Thulin <ft@it.su.se>
%%% @end
%%% @hidden
%%%-------------------------------------------------------------------
-module(pstnproxy_test).

-export([test/0]).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("siprecords.hrl").
-include("sipsocket.hrl").
-include("pstnproxy.hrl").

%%====================================================================
%% Test functions
%%====================================================================

%%--------------------------------------------------------------------
%% @spec    () -> ok
%%
%% @doc     autotest callback
%% @hidden
%% @end
%%--------------------------------------------------------------------
-ifdef( YXA_NO_UNITTEST ).
test() ->
    {error, "Unit test code disabled at compile time"}.

-else.

test() ->
    UserDb =
	[{user, [
		 {name, "autotest1"},
		 {password, "secret"},
		 {classes, [internal,national,mobile]},
		 {addresses, ["sip:autotest1@example.org", "sip:234599@example.org"]}
		]},
	 {user, [
		 {name, "autotest2"},
		 {addresses, ["sip:autotest2@example.org"]}
		]}

	],
    ok = sipuserdb_test:init(UserDb),

    ExtraCfg = [
		{userdb_modules,	[sipuserdb_test]},
		{myhostnames,		["autotest.example.org"]},
		{internal_to_e164,	[{"234599", "+46234599"}]}
	       ],
    yxa_test_config:init(pstnproxy, ExtraCfg),

    ok = test_request(),
    ok.


test_request() ->
    autotest_util:store_unit_test_result(pstnproxy, testing_sippipe, {ok, self()}),
    autotest_util:store_unit_test_result(transactionlayer, get_branch_from_handler, "test-branch"),

    ok = test_OPTIONS(),
    ok = test_INVITE_from_gw(),
    ok = test_INVITE_to_pstn(),
    ok = test_From_addr_verification(),
    ok = test_BYE(),
    ok = test_various_auth_to_pstn(),
    ok.

test_OPTIONS() ->
    Cfg1 = [{myhostnames,	["test.example.org"]},
	    {pstngatewaynames,	["gw.example.org"]},
	    {userdb_modules,	[sipuserdb_test]}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    %% request(Request, YxaCtx)
    %%--------------------------------------------------------------------
    autotest:mark(?LINE, "request/2 - OPTIONS 1.0"),
    Message1 =
	"OPTIONS sip:test-NOT-FOUND@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST one.example.org\r\n"
	"From: Test <sip:test@example.org>\r\n"
	"\r\n",

    Request1 = sippacket:parse(Message1, none),
    YxaCtx1 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.11",
					     port  = 50000
					    }
		      },

    autotest:mark(?LINE, "request/2 - OPTIONS 1.1"),
    %% test OPTIONS request to unknown user at this proxy
    ok = pstnproxy:request(Request1, YxaCtx1),

    {404, "Not Found", [], <<>>} = autotest_util:get_created_response(),

    autotest:mark(?LINE, "request/2 - OPTIONS 2.0"),
    Message2 =
	"OPTIONS sip:test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST one.example.org\r\n"
	"From: Test <sip:test@example.org>\r\n"
	"\r\n",

    Request2 = sippacket:parse(Message2, none),

    autotest:mark(?LINE, "request/2 - OPTIONS 2.2"),
    %% test OPTIONS request to unknown user at this proxy
    ok = pstnproxy:request(Request2, YxaCtx1),

    {200, "OK", [], <<>>} = autotest_util:get_created_response(),

    yxa_test_config:stop(),
    ok.


test_INVITE_from_gw() ->
    Cfg1 = [{myhostnames,	["test.example.org"]},
	    {pstngatewaynames,	["gw.example.org", "192.0.2.33"]},
	    {userdb_modules,	[sipuserdb_test]}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    %% request(Request, YxaCtx)
    %%--------------------------------------------------------------------
    autotest:mark(?LINE, "request/2 - INVITE from gw 1.0"),
    Message1 =
	"INVITE sip:contact@somewhere-else.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:test@example.org>\r\n"
	"Route: <sip:192.0.2.11;lr>\r\n"
	"\r\nbody",

    Request1 = sippacket:parse(Message1, none),
    YxaCtx1 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.33",
					     port  = 50000
					    }
		      },

    autotest:mark(?LINE, "request/2 - INVITE from gw 1.1"),
    %% test INVITE with Route received from gateway, should be passed on
    ok = pstnproxy:request(Request1, YxaCtx1),

    autotest:mark(?LINE, "request/2 - INVITE from gw 1.2"),
    %% verify result
    {Request1, _SentCtx1, route, AppData1} = autotest_util:get_sippipe_result(),
    [#pstn_ctx{} = PstnCtx1] = AppData1,
    [from_gateway, has_route] = lists:sort(PstnCtx1#pstn_ctx.tags),
    "192.0.2.33" = PstnCtx1#pstn_ctx.ip,

    yxa_test_config:stop(),
    ok.


test_INVITE_to_pstn() ->
    Cfg1 = [{myhostnames,	["test.example.org"]},
	    {pstngatewaynames,	["gw.example.org", "192.0.2.33"]},
	    {userdb_modules,	[sipuserdb_test]},
	    {classdefs,		[{"^\\+123456$",	national},
				 {"^\\+1111$",		free},
				 {"^\\+2222$",		pay}
				]},
	    {sipauth_unauth_classlist,	[free]},
	    {e164_to_pstn,	[{"(.+)",	"sip:\\1@gw.example.org"}]}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    %% request(Request, YxaCtx)
    %%--------------------------------------------------------------------
    autotest:mark(?LINE, "request/2 - INVITE to pstn 1.0"),
    %% test INVITE to PSTN without credentials
    Message1 =
	"INVITE sip:+123456@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: E164-national <sip:e164-national@example.org>\r\n"
	"\r\nbody",

    Request1 = sippacket:parse(Message1, none),
    YxaCtx1 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.9",
					     port  = 50000
					    }
		      },

    autotest:mark(?LINE, "request/2 - INVITE to pstn 1.1"),
    ok = pstnproxy:request(Request1, YxaCtx1),

    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [_]}], <<>>} = autotest_util:get_created_response(),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 2.0"),
    %% test INVITE to free PSTN destination
    Message2 =
	"INVITE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: E164-national <sip:e164-national@example.org>\r\n"
	"\r\nbody",

    Request2 = sippacket:parse(Message2, none),
    YxaCtx2 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.9",
					     port  = 50000
					    }
		      },

    autotest:mark(?LINE, "request/2 - INVITE to pstn 2.2"),
    ok = pstnproxy:request(Request2, YxaCtx2),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 2.3"),
    DstUrl2 = sipurl:parse("sip:+1111@gw.example.org"),
    {Request2, _YxaCtx2_res, DstUrl2, AppData2} = autotest_util:get_sippipe_result(),
    [#pstn_ctx{} = PstnCtx2] = AppData2,
    [] = lists:sort(PstnCtx2#pstn_ctx.tags),
    "192.0.2.9" = PstnCtx2#pstn_ctx.ip,



    autotest:mark(?LINE, "request/2 - INVITE to pstn 3.0"),
    %% test INVITE to PSTN destination that is not permitted for this user
    %% (also test SIPS URL in, rewrite resulting in SIP URL)
    Message3 =
	"INVITE sip:+2222@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: PSTN <sip:number@example.org>\r\n"
	"\r\nbody",

    Request3_1 = sippacket:parse(Message3, none),
    Request3 = autotest_util:add_valid_credentials("Proxy-Authorization", Request3_1, "autotest1"),

    YxaCtx3 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.9",
					     port  = 50000
					    }
		      },
    autotest:mark(?LINE, "request/2 - INVITE to pstn 3.2"),
    ok = pstnproxy:request(Request3, YxaCtx3),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 3.3"),
    {403, "Forbidden", [], <<>>} = autotest_util:get_created_response(),



    autotest:mark(?LINE, "request/2 - INVITE to pstn 4.0"),
    %% test INVITE to allowed (free) PSTN destination
    Message4 =
	"INVITE sips:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: PSTN <sip:number@example.org>\r\n"
	"\r\nbody",

    Request4_1 = sippacket:parse(Message4, none),
    Request4 = autotest_util:add_valid_credentials("Proxy-Authorization", Request4_1, "autotest1"),

    YxaCtx4 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.9",
					     port  = 50000
					    }
		      },
    autotest:mark(?LINE, "request/2 - INVITE to pstn 4.2"),
    ok = pstnproxy:request(Request4, YxaCtx4),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 4.3"),
    {Request4_Res, _YxaCtx4_res, DstUrl4_Res, AppData} = autotest_util:get_sippipe_result(),
    Request4 = Request4_Res,
    DstUrl4_Res = sipurl:parse("sips:+1111@gw.example.org"),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 4.4"),
    [#pstn_ctx{user		= "autotest1",
	       stale_auth	= false,
	       called_number	= "+1111",
	       destination	= pstn
	      }] = AppData,


    autotest:mark(?LINE, "request/2 - INVITE to pstn 5.0"),
    %% test INVITE to allowed (but not free) PSTN destination, with stale authorization
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Message5 =
	"INVITE sips:+123456@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:foo@remote.example.org>\r\n"
	"To: PSTN <sip:number@example.org>\r\n"
	"\r\n",
    Request5_1 = sippacket:parse(Message5, none),
    Request5 = autotest_util:add_valid_credentials("Proxy-Authorization", Request5_1, "autotest1"),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 5.1"),
    ok = pstnproxy:request(Request5, YxaCtx4),

    autotest:mark(?LINE, "request/2 - INVITE to pstn 5.2"),
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [Challenge5]}], <<>>} = autotest_util:get_created_response(),
    Dict5 = sipheader:auth(Challenge5),
    {ok, "true"} = dict:find("stale", Dict5),
    {ok, "test.example.org"} = dict:find("realm", Dict5),
    {ok, _} = dict:find("nonce", Dict5),
    {ok, _} = dict:find("opaque", Dict5),


    yxa_test_config:stop(),
    ok.

test_From_addr_verification() ->
    Cfg1 = [{myhostnames,		["test.example.org"]},
	    {pstngatewaynames,		["gw.example.org", "192.0.2.33"]},
	    {userdb_modules,		[sipuserdb_test]},
	    {x_yxa_peer_auth_secret,	"peersecret"},
	    {classdefs,			[{"^\\+1111$",	national}]},
	    {sipauth_unauth_classlist,	[free]},
	    {e164_to_pstn,		[{"(.+)",	"\\1@gw.example.org"}]}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    %% request(Request, YxaCtx)
    %%--------------------------------------------------------------------
    autotest:mark(?LINE, "request/2 - From address verification - 1.0"),
    %% test with wrong From: for this authentication user
    Message1 =
	"INVITE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:autotest2@example.org>\r\n"
	"To: E164-national <sip:e164-national@example.org>\r\n"
	"\r\nbody",

    Request1_1 = sippacket:parse(Message1, none),
    Request1 = autotest_util:add_valid_credentials("Proxy-Authorization", Request1_1, "autotest1"),

    YxaCtx1 = #yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		       origin   = #siporigin{proto = yxa_test,
					     addr  = "192.0.2.9",
					     port  = 50000
					    }
		      },

    autotest:mark(?LINE, "request/2 - From address verification - 1.1"),
    ok = pstnproxy:request(Request1, YxaCtx1),

    autotest:mark(?LINE, "request/2 - From address verification - 1.2"),
    {403, "Forbidden", [], <<>>} = autotest_util:get_created_response(),


    autotest:mark(?LINE, "request/2 - From address verification - 2.0"),
    %% test the same 'wrong From: for this authentication user' as in test 1
    %% above, only now with X-Yxa-Peer-Auth authorization (should be allowed)
    Request2 = autotest_util:add_valid_credentials("X-Yxa-Peer-Auth", Request1, "autotest1", "peersecret"),

    autotest:mark(?LINE, "request/2 - From address verification - 2.1"),
    ok = pstnproxy:request(Request2, YxaCtx1),

    autotest:mark(?LINE, "request/2 - From address verification - 2.2"),
    {Request2_Res, _YxaCtx2, DstURL2_Res, AppData2_Res} = autotest_util:get_sippipe_result(),
    Request2_Res = Request2,
    DstURL2_Res = sipurl:parse("sip:+1111@gw.example.org"),
    [#pstn_ctx{user = "autotest1",
	       stale_auth = false
	      } = PstnCtx2] = AppData2_Res,
    true = lists:member(peer_auth, PstnCtx2#pstn_ctx.tags),


    autotest:mark(?LINE, "request/2 - From address verification - 3.0"),
    %% test the same 'wrong From: for this authentication user' with peer-auth as
    %% in test 2 above, but this time the peer auth is stale so it will be ignored
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Request3 = autotest_util:add_valid_credentials("X-Yxa-Peer-Auth", Request1, "autotest1", "peersecret"),

    autotest:mark(?LINE, "request/2 - From address verification - 3.1"),
    ok = pstnproxy:request(Request3, YxaCtx1),

    autotest:mark(?LINE, "request/2 - From address verification - 3.2"),
    {403, "Forbidden", [], <<>>} = autotest_util:get_created_response(),
    yxa_test_config:set(sipauth_challenge_expiration, 30),


    autotest:mark(?LINE, "request/2 - From address verification - 4.0"),
    %% test with correct From: for this authentication user, but stale auth
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Message4 =
	"INVITE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:autotest1@example.org>\r\n"
	"To: E164-national <sip:e164-national@example.org>\r\n"
	"\r\nbody",

    Request4_1 = sippacket:parse(Message4, none),
    Request4 = autotest_util:add_valid_credentials("Proxy-Authorization", Request4_1, "autotest1"),

    autotest:mark(?LINE, "request/2 - From address verification - 4.1"),
    ok = pstnproxy:request(Request4, YxaCtx1),

    autotest:mark(?LINE, "request/2 - From address verification - 4.2"),
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [Challenge4]}], <<>>} = autotest_util:get_created_response(),
    Dict4 = sipheader:auth(Challenge4),
    {ok, "true"} = dict:find("stale", Dict4),
    {ok, "test.example.org"} = dict:find("realm", Dict4),
    {ok, _} = dict:find("nonce", Dict4),
    {ok, _} = dict:find("opaque", Dict4),
    yxa_test_config:set(sipauth_challenge_expiration, 30),


    autotest:mark(?LINE, "request/2 - From address verification - 5.0"),
    %% test with From: belonging to one of our users, but no credentials
    Message5 =
	"INVITE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST gw.example.org\r\n"
	"From: Test <sip:autotest1@example.org>\r\n"
	"To: E164-national <sip:e164-national@example.org>\r\n"
	"\r\nbody",

    Request5 = sippacket:parse(Message5, none),

    autotest:mark(?LINE, "request/2 - From address verification - 5.1"),
    ok = pstnproxy:request(Request5, YxaCtx1),

    autotest:mark(?LINE, "request/2 - From address verification - 5.2"),
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [Challenge5]}], <<>>} = autotest_util:get_created_response(),
    Dict5 = sipheader:auth(Challenge5),
    error = dict:find("stale", Dict5),
    {ok, "test.example.org"} = dict:find("realm", Dict5),
    {ok, _} = dict:find("nonce", Dict5),
    {ok, _} = dict:find("opaque", Dict5),

    yxa_test_config:stop(),
    ok.


test_BYE() ->
    Cfg1 = [{myhostnames,		["test.example.org"]},
	    {pstngatewaynames,		["gw.example.org",	"192.0.2.33"]},
	    {userdb_modules,		[sipuserdb_test]},
	    {classdefs,			[{"^\\+1(...)$",		national},
					 {"^\\+2...$",			pay}
					]},
	    {sipauth_unauth_classlist,	[]},
	    {internal_to_e164,		[{"^1234$",		"+2345"}]},
	    {e164_to_pstn,		[{"^\\+(2...)$",	"sip:ext.\\1@specialgw.example.org"},
					 {"(.+)",		"sip:\\1@gw.example.org"}
					]},
	    {pstnproxy_challenge_bye_to_pstn_dst, true}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    YxaCtx1 =
	#yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		 origin   = #siporigin{proto = yxa_test,
				       addr  = "192.0.2.9",
				       port  = 50000
				      }
		},

    %% request(Request, YxaCtx)
    %%--------------------------------------------------------------------
    autotest:mark(?LINE, "request/2 - BYE 1.0"),
    %% test BYE message to (non-free) PSTN destination, no auth
    Message1 =
	"BYE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: Number <sip:number@example.org>\r\n"
	"\r\n",

    Request1 = sippacket:parse(Message1, none),
    autotest:mark(?LINE, "request/2 - BYE 1.1"),
    ok = pstnproxy:request(Request1, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE 1.2"),
    %% verify result (should not be 'stale')
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [Challenge1]}], <<>>} = autotest_util:get_created_response(),
    Dict1 = sipheader:auth(Challenge1),
    error = dict:find("stale", Dict1),



    autotest:mark(?LINE, "request/2 - BYE 2.0"),
    %% test BYE message to (non-free) PSTN destination, stale auth
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Message2 =
	"BYE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: Number <sip:number@example.org>\r\n"
	"\r\n",

    Request2_1 = sippacket:parse(Message2, none),
    Request2 = autotest_util:add_valid_credentials("Proxy-Authorization", Request2_1, "autotest1"),

    autotest:mark(?LINE, "request/2 - BYE 2.1"),
    ok = pstnproxy:request(Request2, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE 2.2"),
    %% verify result (should be allowed, even with stale auth)
    {Request2_Res, _YxaCtx2, DstURL2_Res, AppData2_Res} = autotest_util:get_sippipe_result(),
    Request2_Res = Request2,
    DstURL2_Res = sipurl:parse("sip:+1111@gw.example.org"),
    [#pstn_ctx{tags		= [],
	       user		= "autotest1",
	       stale_auth	= true,
	       dst_number	= "+1111",
	       dst_class	= national,
	       destination	= pstn
	      }] = AppData2_Res,
    yxa_test_config:set(sipauth_challenge_expiration, 30),


    autotest:mark(?LINE, "request/2 - BYE 3.0"),
    %% test BYE to non-numeric userpart @ gateway
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Message3 =
	"BYE sip:foo@gw.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>;tag=abc\r\n"
	"To: Number <sip:number@example.org>;tag=123\r\n"
	"\r\n",

    Request3_1 = sippacket:parse(Message3, none),
    Request3 = autotest_util:add_valid_credentials("Proxy-Authorization", Request3_1, "autotest1"),

    autotest:mark(?LINE, "request/2 - BYE 3.1"),
    ok = pstnproxy:request(Request3, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE 3.2"),
    %% verify result (should be allowed, even with stale auth)
    {Request3_Res, _YxaCtx3, DstURL3_Res, [PstnCtxOut3]} = autotest_util:get_sippipe_result(),
    Request3_Res = Request3,
    DstURL3_Res = sipurl:parse("sip:foo@gw.example.org"),
    ExpectedPstnCtx3 =
	#pstn_ctx{tags		= [],
		  ip		= "192.0.2.9",
		  cert_subject	= undefined,
		  user		= "autotest1",
		  stale_auth	= true,
		  orig_uri	= DstURL3_Res,
		  dst_number	= undefined,
		  dst_class	= undefined,
		  destination	= pstn
		 },
    ok = test_compare_records(PstnCtxOut3, ExpectedPstnCtx3, []),

    autotest:mark(?LINE, "request/2 - BYE 4.0"),
    %% test same thing (BYE to non-numeric userpart @ gateway) but without a To-tag
    yxa_test_config:set(sipauth_challenge_expiration, -1),
    Message4 =
	"BYE sip:foo@gw.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>;tag=abc\r\n"
	"To: Number <sip:number@example.org>\r\n"
	"\r\n",

    Request4_1 = sippacket:parse(Message4, none),
    Request4 = autotest_util:add_valid_credentials("Proxy-Authorization", Request4_1, "autotest1"),

    autotest:mark(?LINE, "request/2 - BYE 4.1"),
    ok = pstnproxy:request(Request4, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE 4.2"),
    %% BYE sent outside a dialog shoudl NOT be allowed
    {403, "Forbidden", [], <<>>} = autotest_util:get_created_response(),


    autotest:mark(?LINE, "request/2 - BYE 5.0"),
    %% test BYE message to (non-free) PSTN destination, no auth - should not require auth
    yxa_test_config:set([{pstnproxy_challenge_bye_to_pstn_dst, false}]),
    Message5 =
	"BYE sip:1234@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>\r\n"
	"To: Number <sip:number@example.org>\r\n"
	"\r\n",

    Request5 = sippacket:parse(Message5, none),

    autotest:mark(?LINE, "request/2 - BYE 5.1"),
    ok = pstnproxy:request(Request5, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE 5.2"),
    %% verify result (should be allowed, we are configured not to challenge BYE)
    {Request5_Res, _YxaCtx5, DstURL5_Res, [PstnCtxOut5]} = autotest_util:get_sippipe_result(),
    Request5_Res = Request5,
    DstURL5_Res = sipurl:parse("sip:ext.2345@specialgw.example.org"),
    ExpectedPstnCtx5 =
	#pstn_ctx{tags		= [],
		  ip		= "192.0.2.9",
		  user		= undefined,
		  stale_auth	= false,
		  orig_uri	= sipurl:parse("sip:1234@test.example.org"),
		  called_number	= "1234",
		  dst_number	= "+2345",
		  dst_class	= pay,
		  destination	= pstn
		 },
    ok = test_compare_records(PstnCtxOut5, ExpectedPstnCtx5, []),

    %% restore config
    yxa_test_config:set([{pstnproxy_challenge_bye_to_pstn_dst, true}]),

    ok.

test_various_auth_to_pstn() ->
    Cfg1 = [{myhostnames,		["test.example.org"]},
	    {pstngatewaynames,		["gw.example.org",	"192.0.2.33"]},
	    {userdb_modules,		[sipuserdb_test]},
	    {classdefs,			[{"^\\+1(...)$",		national},
					 {"^\\+2...$",			pay}
					]},
	    {sipauth_unauth_classlist,	[]},
	    {internal_to_e164,		[{"^1234$",		"+2345"}]},
	    {e164_to_pstn,		[{"^\\+(2...)$",	"sip:ext.\\1@specialgw.example.org"},
					 {"(.+)",		"sip:\\1@gw.example.org"}
					]},
	    {pstnproxy_challenge_bye_to_pstn_dst, false}
	   ],

    ok = yxa_test_config:init(pstnproxy, Cfg1),

    YxaCtx1 =
	#yxa_ctx{thandler = transactionlayer:test_get_thandler_self(),
		 origin   = #siporigin{proto = yxa_test,
				       addr  = "192.0.2.9",
				       port  = 50000
				      }
		},

    autotest:mark(?LINE, "request/2 - BYE with Route 1.0"),
    %% test BYE message to (non-free) PSTN destination, no auth - should not require auth
    Message1 =
	"BYE sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>;tag=x\r\n"
	"To: Number <sip:number@example.org>;tag=y\r\n"
	"Route: <sip:gw.example.org;lr>\r\n"
	"\r\n",

    Request1 = sippacket:parse(Message1, none),

    autotest:mark(?LINE, "request/2 - BYE with Route 1.1"),
    ok = pstnproxy:request(Request1, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE with Route 1.2"),
    %% verify result (should be allowed, we are configured not to challenge BYE)
    {Request1_Res, _YxaCtx1, DstURL1_Res, [PstnCtxOut1]} = autotest_util:get_sippipe_result(),
    Request1_Res = Request1,
    DstURL1_Res = route,
    ExpectedPstnCtx1 =
	#pstn_ctx{tags		= [has_route,route_to_gw],
		  ip		= "192.0.2.9",
		  user		= undefined,
		  stale_auth	= false,
		  orig_uri	= sipurl:parse("sip:+1111@test.example.org"),
		  called_number	= undefined,
		  dst_number	= undefined,
		  dst_class	= undefined,
		  destination	= pstn
		 },
    ok = test_compare_records(PstnCtxOut1, ExpectedPstnCtx1, []),


    %% test same thing, but configured to challenge BYEs
    yxa_test_config:set([{pstnproxy_challenge_bye_to_pstn_dst, true}]),

    autotest:mark(?LINE, "request/2 - BYE with Route 2.1"),
    Request2 = Request1,
    ok = pstnproxy:request(Request2, YxaCtx1),

    autotest:mark(?LINE, "request/2 - BYE with Route 2.2"),
    %% verify result (should be challenged this time)
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [_]}], <<>>} = autotest_util:get_created_response(),

    %% restore config
    yxa_test_config:set([{pstnproxy_challenge_bye_to_pstn_dst, false}]),


    autotest:mark(?LINE, "request/2 - OPTIONS with Route 3.0"),
    %% test OPTIONS message to (non-free) PSTN destination, no auth - should be challenged
    Message3 =
	"OPTIONS sip:+1111@test.example.org SIP/2.0\r\n"
	"Via: SIP/2.0/YXA-TEST client.example.org\r\n"
	"From: Test <sip:test@remote.example.org>;tag=x\r\n"
	"To: Number <sip:number@example.org>;tag=y\r\n"
	"Route: <sip:gw.example.org;lr>\r\n"
	"\r\n",

    Request3 = sippacket:parse(Message3, none),

    autotest:mark(?LINE, "request/2 - OPTIONS with Route 3.1"),
    ok = pstnproxy:request(Request3, YxaCtx1),

    autotest:mark(?LINE, "request/2 - OPTIONS with Route 3.2"),
    %% verify result (should NOT be allowed)
    {407, "Proxy Authentication Required", [{"Proxy-Authenticate", [_]}], <<>>} = autotest_util:get_created_response(),



    ok.

%%====================================================================
%% Helper functions
%%====================================================================

%% compare two records element by element and give good information on where they
%% are not equal
test_compare_records(R1, R2, ShouldChange) when is_tuple(R1), is_tuple(R2), is_list(ShouldChange) ->
    RecName = element(1, R1),
    Fields = test_record_info(RecName),
    autotest_util:compare_records(R1, R2, ShouldChange, Fields).

%% add more records here when needed
test_record_info(pstn_ctx) ->
    record_info(fields, pstn_ctx);
test_record_info(sipurl) ->
    record_info(fields, sipurl).

-endif.
