%%%-------------------------------------------------------------------
%%% File    : sipserver.erl
%%% @author   Magnus Ahltorp <ahltorp@nada.kth.se>
%%% @doc      Main OTP application startup function, and per-request
%%%           start processing function.
%%%
%%% @since    12 Dec 2002 by Magnus Ahltorp <ahltorp@nada.kth.se>
%%% @end
%%%-------------------------------------------------------------------
-module(sipserver).
%%-compile(export_all).

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
	 start/2,
	 stop/0,
	 
	 restart/0,
	 process/2
	]).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("sipsocket.hrl").
-include("siprecords.hrl").

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------

%%====================================================================
%% External functions
%%====================================================================

%%--------------------------------------------------------------------
%% @spec    (normal, [AppModule]) ->
%%            {ok, Pid}
%%
%%            AppModule = atom() "name of this YXA application"
%%
%%            Pid = pid() "the YXA OTP supervisor (module sipserver_sup)"
%%
%% @doc     The big start-function for the YXA stack. Invoke this
%%          function to make the sun go up, and tell it the name of
%%          your YXA application (AppModule) to have the stack invoke
%%          the correct init/0, request/3 and response/3 methods.
%% @end
%%--------------------------------------------------------------------
start(normal, [AppModule]) ->
    %% First of all, we add a custom error_logger module. This is the only
    %% way to really get all information about why supervised subsystems fails
    %% to start.
    sup_error_logger:start(),
    ok = init_statistics(),
    case sipserver_sup:start_link(AppModule, []) of
	{ok, Supervisor} ->
	    local:init(),
	    logger:log(debug, "starting, supervisor is ~p", [Supervisor]),
				
	    case siphost:myip() of
		"127.0.0.1" ->
		    logger:log(normal, "NOTICE: siphost:myip() returns 127.0.0.1, it is either "
			       "broken on your platform or you have no interfaces (except loopback) up");
		_ ->
		    true
	    end,
	   %% ok = init_mnesia(MnesiaTables),
	    {ok, Supervisor} = sipserver_sup:start_transportlayer(Supervisor),
	    {ok, Supervisor};
	Unknown ->
	    io:format("Unknown ~p~n",[Unknown]),
	    E = lists:flatten(io_lib:format("Failed starting supervisor : ~p", [Unknown])),
	    {error, E}
    end.

%%--------------------------------------------------------------------
%% @spec    () -> term() "does not return"
%%
%% @doc     Log and then shut down application. Shuts down the whole
%%          Erlang virtual machine, so never really returns.
%% @end
%%--------------------------------------------------------------------
stop() ->
    logger:log(normal, "Sipserver: shutting down"),
    {ok, AppModule} = yxa_config:get_env(yxa_appmodule),
    case (catch AppModule:terminate(shutdown)) of
	ok ->
	    ok;
	Res ->
	    logger:log(debug, "Sipserver: ~p:terminate/1 terminated with reason other than 'ok' : ~p", [AppModule, Res])
    end,
    init:stop().

%%--------------------------------------------------------------------
%% @spec    () -> term() "does not return"
%%
%% @doc     Log and then restart application. Will never really
%%          return.
%% @end
%%--------------------------------------------------------------------
restart() ->
    logger:log(normal, "Sipserver: restarting"),
    init:restart().

%%--------------------------------------------------------------------
%% @spec    (Tables) ->
%%            ok
%%
%%            Tables = [atom()] "names of Mnesia tables needed by this YXA application."
%%
%%            DescriptiveAtom = atom() "reason converted to atom since atoms are displayed best when an application fails to start"
%%
%% @throws  DescriptiveAtom
%%
%% @doc     Initiate Mnesia on this node. If there are no remote
%%          mnesia-tables, we conclude that we are a mnesia master
%%          and check if any of the tables needs to be updated.
%% @end
%%--------------------------------------------------------------------


%%--------------------------------------------------------------------
%% @spec    (Tables) ->
%%            ok
%%
%%            Tables = [atom()] "list of table names"
%%
%%            DescriptiveAtom = atom() "reason converted to atom since atoms are displayed best when an application fails to start"
%%
%% @throws  DescriptiveAtom
%%
%% @doc     Make sure the tables listed in Tables exist, otherwise
%%          halt the Erlang runtime system.
%% @end
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @spec    (Descr, Tables) ->
%%            ok
%%
%%            Descr  = string() "\"local\" or \"remote\""
%%            Tables = [atom()] "names of local/remote Mnesia tables needed by this YXA application."
%%
%%            DescriptiveAtom = atom() "reason converted to atom since atoms are displayed best when an application fails to start"
%%
%% @throws  DescriptiveAtom
%%
%% @doc     Do mnesia:wait_for_tables() for RemoteTables, with a
%%          timeout since Mnesia doesn't always start correctly due
%%          to network issues, fast restarts or other reasons.
%% @end
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @spec    () -> ok
%%
%% @doc     Create ETS tables used by YXA.
%% @end
%%--------------------------------------------------------------------
init_statistics() ->
    ets:new(yxa_statistics, [public, set, named_table]),
    true = ets:insert(yxa_statistics, {starttime, util:timestamp()}),
    ok.

%%--------------------------------------------------------------------
%% @spec    (Request, Socket, Status, Reason, ExtraHeaders) ->
%%            ok  |
%%            Res
%%
%%            Request      = #request{}
%%            Socket       = #sipsocket{}
%%            Status       = integer() "SIP response code"
%%            Reason       = string() "error description"
%%            ExtraHeaders = #keylist{}
%%
%%            Res = term() "result of transportlayer:send_result()"
%%
%% @doc     In sipserver we do lots of checking in the dark areas of
%%          transport layer, transaction layer or somewhere in
%%          between. When we detect unparsable requests for example,
%%          we generate an error response in sipserver but special
%%          care must be taken so that we do not generate responses
%%          to malformed ACK's. This function checks that.
%% @end
%%--------------------------------------------------------------------
my_send_result(Request, Socket, Status, Reason, ExtraHeaders) when is_record(Request, request) ->
    case Request#request.method of
	"ACK" ->
	    %% Empirical evidence says that it is a really bad idea to send responses to ACK
	    %% (since the response may trigger yet another ACK). Although not very clearly,
	    %% RFC3261 section 17 (Transactions) do say that responses to ACK is not permitted :
	    %% ' The client transaction is also responsible for receiving responses
	    %%   and delivering them to the TU, filtering out any response
	    %%   retransmissions or disallowed responses (such as a response to ACK).'
	    logger:log(normal, "Sipserver: Suppressing application error response '~p ~s' in response to ACK ~s",
		       [Status, Reason, sipurl:print(Request#request.uri)]);
	_ ->
	    case transactionlayer:send_response_request(Request, Status, Reason, ExtraHeaders) of
		ok -> ok;
		_ ->
		    logger:log(error, "Sipserver: Failed sending caught error ~p ~s (in response to ~s ~s) " ++
			       "using transaction layer - sending directly on the socket we received the request on",
			       [Status, Reason, Request#request.method, sipurl:print(Request#request.uri)]),
		    transportlayer:send_result(Request#request.header, Socket, <<>>, Status, Reason, ExtraHeaders)
	    end
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, Socket) ->
%%            ok  |
%%            Res
%%
%%            Request = #request{}
%%            Socket  = #sipsocket{}
%%
%%            Res = term() "result of transportlayer:send_result()"
%%
%% @doc     Send a 500 Server Internal Error, or some other given
%%          error, in response to a request (Request) received on a
%%          specific socket (Socket).
%% @end
%%--------------------------------------------------------------------
internal_error(Request, Socket) when is_record(Request, request), is_record(Socket, sipsocket) ->
    my_send_result(Request, Socket, 500, "Server Internal Error", []).

internal_error(Request, Socket, Status, Reason) when is_record(Request, request), is_record(Socket, sipsocket) ->
    my_send_result(Request, Socket, Status, Reason, []).

internal_error(Request, Socket, Status, Reason, ExtraHeaders) when is_record(Request, request),
								   is_record(Socket, sipsocket) ->
    my_send_result(Request, Socket, Status, Reason, ExtraHeaders).

%%--------------------------------------------------------------------
%% @spec    (Packet, Origin) -> void() "does not matter."
%%
%%            Packet = binary() | #request{} | #response{}
%%            Origin = #siporigin{}
%%
%% @doc     Check if something we received from a socket (Packet) is a
%%          valid SIP request/response by calling parse_packet() on
%%          it. Then, use my_apply to either send it on to the
%%          transaction layer, or invoke a modules request/3 or
%%          response/3 function on it - depending on the contents of
%%          Dst.
%% @end
%%--------------------------------------------------------------------
process(Packet, Origin) when is_record(Origin, siporigin) ->
    SipSocket = Origin#siporigin.sipsocket,
    case parse_packet(Packet, Origin) of
	{ok, Request, YxaCtx} when is_record(Request, request) ->
	    %% Ok, the parsing and checking of the request is done now
	    try	my_apply(transactionlayer, Request, YxaCtx) of
		_ -> true
	    catch
		error:
		  E ->
		    ST = erlang:get_stacktrace(),
		    logger:log(error, "=ERROR REPORT==== from SIP message handler (in sipserver:process()) :~n"
			       "~p, stacktrace : ~p", [E, ST]),
		    internal_error(Request, SipSocket),
		    %% pass the error on
		    erlang:error({caught_error, E, ST});
		exit:
		  E ->
		    logger:log(error, "=ERROR REPORT==== from SIP message handler (in sipserver:process()) :~n~p", [E]),
		    internal_error(Request, SipSocket),
		    %% pass the error on
		    erlang:exit(E);
		throw:
		  {siperror, Status, Reason} ->
		    logger:log(error, "FAILED processing request: ~s -> ~p ~s",
			       [YxaCtx#yxa_ctx.logstr, Status, Reason]),
		    internal_error(Request, SipSocket, Status, Reason),
		    %% throw a new error, but not the same since we have handled the SIP error sending
		    throw({error, application_failed_processing_request});
		  {siperror, Status, Reason, ExtraHeaders} ->
		    logger:log(error, "FAILED processing request: ~s -> ~p ~s",
			       [YxaCtx#yxa_ctx.logstr, Status, Reason]),
		    internal_error(Request, SipSocket, Status, Reason, ExtraHeaders),
		    %% throw a new error, but not the same since we have handled the SIP error sending
		    throw({error, application_failed_processing_request})
	    end;
	{ok, Response, YxaCtx} when is_record(Response, response) ->
	    my_apply(transactionlayer, Response, YxaCtx);
	Unspecified ->
	    Unspecified
    end.

%%--------------------------------------------------------------------
%% @spec    (Dst, Request, YxaCtx) ->
%%            ignore      |
%%            SIPerror    |
%%            ApplyResult
%%
%%            Dst     = transactionlayer | Module
%%            Module  = atom() "YXA application module name"
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%
%%            SIPerror    = {siperror, Status, Reason}
%%            Status      = integer()
%%            Reason      = string()
%%            ApplyResult = term() "result of applications request/3 or response/3 function."
%%
%% @doc     If Dst is transactionlayer, gen_server call the
%%          transaction layer and let it decide our next action. If
%%          Dst is the name of a module, apply() that modules
%%          request/2 or response/2 function.
%% @end
%%--------------------------------------------------------------------
my_apply(transactionlayer, R, YxaCtx) when is_record(R, request) orelse is_record(R, response),
					   is_record(YxaCtx, yxa_ctx) ->
    %% Dst is the transaction layer.
    case transactionlayer:from_transportlayer(R, YxaCtx) of
	continue ->
	    %% terminate silently, the transaction layer found an existing transaction
	    %% for this request/response
	    ignore;
	{pass_to_core, AppModule, NewYxaCtx1} ->
	    %% Dst (the transaction layer presumably) wants us to apply a function with this
	    %% request/response as argument. This is common when the transaction layer has started
	    %% a new server transaction for this request and wants it passed to the core (or TU)
	    %% but can't do it itself because that would block the transactionlayer process.
	   Action =
	   if
		    is_record(R, request) ->
	   		    local:new_request(AppModule, R, NewYxaCtx1);
	 	    is_record(R, response) ->
			    local:new_response(AppModule, R, NewYxaCtx1)
		end,
	    case Action of
		undefined ->
		    my_apply(AppModule, R, NewYxaCtx1);
		{modified, NewAppModule, NewR, NewYxaCtx} ->
		    logger:log(debug, "Sipserver: Passing possibly modified request/response to application"),
		    my_apply(NewAppModule, NewR, NewYxaCtx);
		ignore ->
		    ignore
	    end
    end;
my_apply(AppModule, Request, YxaCtx) when is_atom(AppModule), is_record(Request, request),
					  is_record(YxaCtx, yxa_ctx) ->
    AppModule:request(Request, YxaCtx);
my_apply(AppModule, Response, YxaCtx) when is_atom(AppModule), is_record(Response, response),
					   is_record(YxaCtx, yxa_ctx) ->
    AppModule:response(Response, YxaCtx).

%%--------------------------------------------------------------------
%% @spec    (Packet, Origin) ->
%%            {ok, R, YxaCtx}       |
%%            void() "unspecified"
%%
%%            Packet = binary() | #request{} | #response{}
%%            Origin = #siporigin{}
%%
%%            R      = #request{}  |
%%            #response{}
%%            YxaCtx = #yxa_ctx{}
%%
%% @doc     Check if something we received from a socket (Packet) is a
%%          valid SIP request/response. What we return is a parsed
%%          request/response that has been checked for loops, correct
%%          top-Via etc. together with a logging string that descr-
%%          ibes this request/response.
%% @end
%%--------------------------------------------------------------------
parse_packet(Packet, Origin) when is_record(Origin, siporigin) ->
    Socket = Origin#siporigin.sipsocket,
    case parse_packet2(Packet, Origin) of
	{ok, Parsed} when is_record(Parsed, request) orelse is_record(Parsed, response) ->
	    %% Ok, we have done the elementary parsing of the request/response. Now check it
	    %% for bad things, like loops, wrong IP in top Via (for responses) etc. etc.
	    %%
	    %% From here on, we can generate responses to the UAC on error since we have parsed
	    %% enough of the packet to have a SIP request or response with headers.
	    try process_parsed_packet(Parsed, Origin) of
		{ok, R, YxaCtx} when is_record(R, request) orelse is_record(R, response),
				     is_record(YxaCtx, yxa_ctx) ->
		    {ok, R, YxaCtx};
		invalid ->
		    invalid
	    catch
		exit:
		  E ->
		    logger:log(error, "=ERROR REPORT==== from sipserver:process_parsed_packet() :~n~p", [E]),
		    erlang:exit(E);
		throw:
		  {sipparseerror, request, Header, Status, Reason} ->
		    logger:log(error, "INVALID request [client=~s]: -> ~p ~s",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    parse_do_internal_error(Header, Socket, Status, Reason, []);
		  {sipparseerror, request, Header, Status, Reason, ExtraHeaders} ->
		    logger:log(error, "INVALID request [client=~s]: -> ~p ~s",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    parse_do_internal_error(Header, Socket, Status, Reason, ExtraHeaders);
		  {sipparseerror, response, _Header, Status, Reason} ->
		    logger:log(error, "INVALID response [client=~s] -> '~p ~s' (dropping)",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    false;
		  {sipparseerror, response, _Header, Status, Reason, _ExtraHeaders} ->
		    logger:log(error, "INVALID response [client=~s] -> '~p ~s' (dropping)",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    false;
		  {siperror, Status, Reason} ->
		    logger:log(error, "INVALID packet [client=~s] -> '~p ~s', CAN'T SEND RESPONSE",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    false;
		  {siperror, Status, Reason, _ExtraHeaders} ->
		    logger:log(error, "INVALID packet [client=~s] -> '~p ~s', CAN'T SEND RESPONSE",
			       [transportlayer:origin2str(Origin), Status, Reason]),
		    false;
		error:
		  E ->
		    ST = erlang:get_stacktrace(),
		    logger:log(error, "=ERROR REPORT==== from SIP message parser (stage 2) "
			       "(in sipserver:parse_packet()) -> CAN'T SEND RESPONSE :~n~p, "
			       "stacktrace : ~p", [E, ST]),
		    %% pass the error on (will probably go unnoticed)
		    erlang:error({caught_error, E, ST})
	    end;
	ignore -> ignore;
	error -> error
    end.

%% parse_packet2/2 - part of parse_packet/2. Parse the data if it is not in fact already parsed.
parse_packet2(Msg, Origin) when is_record(Msg, request) orelse is_record(Msg, response),
				is_record(Origin, siporigin) ->
    %% is already parsed
    {ok, Msg};
parse_packet2(Packet, Origin) when is_binary(Packet), is_record(Origin, siporigin) ->
    try sippacket:parse(Packet, Origin) of
	keepalive ->
	    ignore;
	Parsed when is_record(Parsed, request) orelse is_record(Parsed, response) ->
	    {ok, Parsed}
    catch
	exit:
	  E ->
	    logger:log(error, "=ERROR REPORT==== from sippacket:parse() [client=~s]~n~p",
		       [transportlayer:origin2str(Origin), E]),
	    %% awful amount of debug output here, but a parsing crash is serious and it might be
	    %% needed to track the bug down
	    logger:log(debug, "CRASHED parsing packet (binary version):~n~p", [Packet]),
	    logger:log(debug, "CRASHED parsing packet (ASCII version):~n~p", [binary_to_list(Packet)]),
	    error;
	throw:
	  {siperror, Status, Reason} ->
	    logger:log(error, "INVALID packet [client=~s] -> '~p ~s', CAN'T SEND RESPONSE",
		       [transportlayer:origin2str(Origin), Status, Reason]),
	    error;
	  {siperror, Status, Reason, _ExtraHeaders} ->
	    logger:log(error, "INVALID packet [client=~s] -> '~p ~s', CAN'T SEND RESPONSE",
		       [transportlayer:origin2str(Origin), Status, Reason]),
	    error;
	  Error ->
	    logger:log(error, "INVALID packet [client=~s], probably not SIP-message at all (reason: ~p) ",
		       [transportlayer:origin2str(Origin), Error]),
	    error
    end.

%%--------------------------------------------------------------------
%% @spec    (Header, Socket, Status, Reason, ExtraHeaders) -> ok
%%
%%            Header       = term() "opaque #(keylist{})"
%%            Socket       = term() "opaque #(sipsocket{})"
%%            Status       = integer() "SIP status code"
%%            Reason       = string() "SIP reason phrase"
%%            ExtraHeaders = term() "opaque #(keylist{})"
%%
%% @doc     Handle errors returned during initial parsing of a
%%          request. These errors occur before the transaction layer
%%          is notified of the requests, so there are never any
%%          server transactions to handle the errors. Just send them.
%% @end
%%--------------------------------------------------------------------
parse_do_internal_error(Header, Socket, Status, Reason, ExtraHeaders) ->
    try sipheader:cseq(Header) of
	{_Num, "ACK"} ->
	    %% Empirical evidence says that it is a really bad idea to send responses to ACK
	    %% (since the response may trigger yet another ACK). Although not very clearly,
	    %% RFC3261 section 17 (Transactions) do say that responses to ACK is not permitted :
	    %% ' The client transaction is also responsible for receiving responses
	    %%   and delivering them to the TU, filtering out any response
	    %%   retransmissions or disallowed responses (such as a response to ACK).'
	    logger:log(normal, "Sipserver: Suppressing parsing error response ~p ~s because CSeq method is ACK",
		       [Status, Reason]);
	{_Num, _Method} ->
	    transportlayer:send_result(Header, Socket, <<>>, Status, Reason, ExtraHeaders)
    catch
	throw: {yxa_unparsable, cseq, Reason} ->
	    logger:log(error, "Sipserver: Malformed CSeq in response we were going to send, dropping response : ~p",
		       [Reason])
    end,
    ok.

%%--------------------------------------------------------------------
%% @spec    (Request, Origin) -> {ok, NewRequest, YxaCtx}
%%
%%            Request = #request{}
%%            Origin  = #siporigin{} "information about where this Packet was received from"
%%
%% @doc     Do alot of transport/transaction layer checking/work on a
%%          request or response we have received and previously
%%          concluded was parsable. For example, do RFC3581 handling
%%          of rport parameter on top via, check for loops, check if
%%          we received a request from a strict router etc.
%% @end
%%--------------------------------------------------------------------
process_parsed_packet(Request, Origin) when is_record(Request, request), is_record(Origin, siporigin) ->
    NewHeader2 = fix_topvia_received_rport(Request#request.header, Origin),
    check_packet(Request#request{header = NewHeader2}, Origin),
    {NewURI1, NewHeader3} =
	case received_from_strict_router(Request#request.uri, NewHeader2) of
	    true ->
		%% RFC3261 #16.4 (Route Information Preprocessing)
		logger:log(debug, "Sipserver: Received request with a"
			   " Request-URI I (probably) put in a Record-Route. "
			   "Pop real Request-URI from Route-header."),
		ReverseRoute = lists:reverse(keylist:fetch('route', NewHeader2)),
		[LastRoute | ReverseRouteRest] = ReverseRoute,
		[ParsedLastRoute] = contact:parse([LastRoute]),
		NewReqURI = sipurl:parse(ParsedLastRoute#contact.urlstr),
		NewH =
		    case ReverseRouteRest of
			[] ->
			    keylist:delete("Route", NewHeader2);
			_ ->
			    keylist:set("Route", lists:reverse(ReverseRouteRest), NewHeader2)
		end,
		{NewReqURI, NewH};
	    false ->
		{Request#request.uri, NewHeader2}
	end,
    NewURI = remove_maddr_matching_me(NewURI1, Origin),
    NewHeader4 = remove_route_matching_me(NewHeader3),
    NewRequest = Request#request{uri    = NewURI,
				 header = NewHeader4
				},
    LogStr = make_logstr(NewRequest, Origin),
    YxaCtx = #yxa_ctx{origin = Origin,
		      logstr = LogStr
		     },
    {ok, NewRequest, YxaCtx};

%%--------------------------------------------------------------------
%% @spec    (Response, Origin) ->
%%            {NewResponse, LogStr} |
%%            invalid
%%
%%            Response = #response{}
%%            Origin   = #siporigin{} "information about where this Packet was received from"
%%
%% @doc     Do alot of transport/transaction layer checking/work on a
%%          request or response we have received and previously
%%          concluded was parsable. For example, do RFC3581 handling
%%          of rport parameter on top via, check for loops, check if
%%          we received a request from a strict router etc.
%% @end
%%--------------------------------------------------------------------
process_parsed_packet(Response, Origin) when is_record(Response, response), is_record(Origin, siporigin) ->
    check_packet(Response, Origin),
    TopVia = sipheader:topvia(Response#response.header),
    case check_response_via(Origin, TopVia) of
	ok ->
	    LogStr = make_logstr(Response, Origin),
	    YxaCtx = #yxa_ctx{origin = Origin,
			      logstr = LogStr
			     },
	    {ok, Response, YxaCtx};
	error ->
	    %% Silently drop packet
	    invalid
    end.

%%--------------------------------------------------------------------
%% @spec    (Origin, TopVia) ->
%%            ok    |
%%            error
%%
%%            Origin = #siporigin{} "information about where this Packet was received from"
%%            TopVia = #via{} | none
%%
%% @doc     Check that there actually was a Via header in this
%%          response, and check if it matches us.
%% @end
%%--------------------------------------------------------------------
check_response_via(Origin, none) when is_record(Origin, siporigin) ->
    logger:log(error, "INVALID top-Via in response [client=~s] (no Via found).",
	       [transportlayer:origin2str(Origin)]),
    error;
check_response_via(Origin, TopVia) when is_record(Origin, siporigin), is_record(TopVia, via) ->
    %% Check that top-Via is ours (RFC 3261 18.1.2),
    %% silently drop message if it is not.

    %% Create a Via that looks like the one we would have produced if we sent the request
    %% this is an answer to, but don't include parameters since they might have changed
    Proto = Origin#siporigin.proto,
    %% This is what we expect, considering the protocol in Origin (Proto)
    MyViaNoParam = siprequest:create_via(Proto, []),
    %% But we also accept this, which is the same but with the protocol from this response - in
    %% case we sent the request out using TCP but received the response over UDP for example
    SentByMeNoParam = siprequest:create_via(sipsocket:viastr2proto(TopVia#via.proto), []),
    case sipheader:via_is_equal(TopVia, MyViaNoParam, [proto, host, port]) of
        true ->
	    ok;
	false ->
	    case sipheader:via_is_equal(TopVia, SentByMeNoParam, [proto, host, port]) of
		true ->
		    %% This can happen if we for example send a request out on a TCP socket, but the
		    %% other end responds over UDP.
		    logger:log(debug, "Sipserver: Warning: received response [client=~s]"
			       " matching me, but different protocol ~p (received on: ~p)",
			       [transportlayer:origin2str(Origin),
				TopVia#via.proto, sipsocket:proto2viastr(Origin#siporigin.proto)]),
		    ok;
		false ->
		    logger:log(error, "INVALID top-Via in response [client=~s]."
			       " Top-Via (without parameters) (~s) does not match mine (~s). Discarding.",
			       [transportlayer:origin2str(Origin),
				sipheader:via_print([TopVia#via{param = []
							       }
						    ]),
				sipheader:via_print([MyViaNoParam])]),
		    error
	    end
    end.

%%--------------------------------------------------------------------
%% @spec    (Header, Origin) ->
%%            NewHeader
%%
%%            Header = term() "opaque #(keylist{})"
%%            Origin = #siporigin{}
%%
%%            NewHeader = term() "opaque (a new #keylist{})"
%%
%% @doc     Implement handling of rport= top Via parameter upon
%%          receiving a request with an 'rport' parameter. RFC3581.
%%          Even if there is no rport parameter, we check if we must
%%          add a received= parameter (RFC3261 #18.2.1).
%% @end
%%--------------------------------------------------------------------
%% XXX this RFC3581 implementation is not 100% finished. RFC3581 Section 4 says we MUST
%% send the responses to this request back from the same IP and port we received the
%% request to. We should be able to solve this when sending responses if we keep a list
%% of requests and sockets even for requests received over UDP too. XXX make it so.
fix_topvia_received_rport(Header, Origin) when is_record(Origin, siporigin) ->
    IP = Origin#siporigin.addr,
    Port = Origin#siporigin.port,
    PortStr = integer_to_list(Port),
    TopVia = sipheader:topvia(Header),
    ParamDict = sipheader:param_to_dict(TopVia#via.param),
    %% RFC3581 Section 4 says we MUST add a received= parameter when client
    %% requests rport even if the sent-by is set to the IP-address we received
    %% the request from, so if we find an rport below we always add received=
    %% information.
    case dict:find("rport", ParamDict) of
	error ->
	    %% No rport, check "sent-by" in top-Via to see if we still MUST add a
	    %% received= parameter (RFC 3261 #18.2.1)
	    case TopVia#via.host of
		IP ->
		    Header;
		_ ->
		    NewDict = dict:store("received", IP, ParamDict),
		    NewVia = TopVia#via{param=sipheader:dict_to_param(NewDict)},
		    logger:log(debug, "Sipserver: Top Via host ~p does not match IP ~p, appending received=~s parameter",
			       [TopVia#via.host, IP, IP]),
		    replace_top_via(NewVia, Header)
	    end;
	{ok, []} ->
	    %% rport without value, this is like it should be. Add value and received=.
	    logger:log(debug, "Sipserver: Client requests symmetric response routing, setting rport=~p", [Port]),
	    NewDict1 = dict:store("rport", PortStr, ParamDict),
	    NewDict = dict:store("received", IP, NewDict1),
	    NewVia = TopVia#via{param=sipheader:dict_to_param(NewDict)},
	    replace_top_via(NewVia, Header);
	{ok, PortStr} ->
	    %% rport already set to the value we would have set it to - client is not
	    %% RFC-compliant. Just add received= information.
	    logger:log(debug, "Sipserver: Top Via has rport already set to ~p, remote party "
		       "isn't very RFC3581 compliant.", [Port]),
	    NewDict = dict:store("received", IP, ParamDict),
	    NewVia = TopVia#via{param=sipheader:dict_to_param(NewDict)},
	    replace_top_via(NewVia, Header);
	{ok, RPort} ->
	    %% rport already set, and to the WRONG value. Must be a NAT or some other
	    %% evildoer in the path of the request. Fix the rport value, and add received=.
	    logger:log(normal, "Sipserver: Received request with rport already containing a value (~p)! "
		       "Overriding with the right port (~p).", [RPort, Port]),
	    NewDict1 = dict:store("rport", PortStr, ParamDict),
	    NewDict = dict:store("received", IP, NewDict1),
	    NewVia = TopVia#via{param=sipheader:dict_to_param(NewDict)},
	    replace_top_via(NewVia, Header)
    end.

%% Replace top Via header in a keylist record()
replace_top_via(NewVia, Header) when is_record(NewVia, via) ->
    [_FirstVia | Via] = sipheader:via(Header),
    keylist:set("Via", sipheader:via_print(lists:append([NewVia], Via)), Header).

%%--------------------------------------------------------------------
%% @spec    (URI, Header) ->
%%            true |
%%            false
%%
%%            URI    = #sipurl{}
%%            Header = term() "opaque #(keylist{})"
%%
%% @doc     Look at the URI of a request we just received to see if it
%%          is something we (possibly) put in a Record-Route and this
%%          is a request sent from a strict router (RFC2543 compliant
%%          UA).
%% @end
%%--------------------------------------------------------------------
received_from_strict_router(URI, Header) when is_record(URI, sipurl) ->
    MyPorts = sipsocket:get_all_listenports(),
    {ok, MyHostnames} = yxa_config:get_env(myhostnames, []),
    HostnameList = MyHostnames ++ siphost:myip_list(),
    %% If the URI has a username in it, it is not something we've put in a Record-Route
    case URI#sipurl.user of
	T when is_list(T) ->
	    %% short-circuit the rest of the checks for efficiency (most normal Request-URI's
	    %% have the username part set).
	    false;
	none ->
	    LCHost = string:to_lower(URI#sipurl.host),
	    HostnameIsMyHostname = lists:member(LCHost, HostnameList),
	    %% In theory, we should not treat an absent port number in this Request-URI as
	    %% if the default port number was specified in there, but in practice that is
	    %% what we have to do since some UAs can remove the port we put into the
	    %% Record-Route
	    Port = sipsocket:default_port(URI#sipurl.proto, sipurl:get_port(URI)),
	    PortMatches = lists:member(Port, MyPorts),
	    HeaderHasRoute = case keylist:fetch('route', Header) of
				 [] -> false;
				 _ -> true
			     end,
	    if
		HostnameIsMyHostname /= true -> false;
		PortMatches /= true -> false;
		HeaderHasRoute /= true ->
		    logger:log(debug, "Sipserver: Warning: Request-URI looks like something"
			       " I put in a Record-Route header, but request has no Route!"),
		    false;
		true -> true
	    end
    end.

%%--------------------------------------------------------------------
%% @spec    (URI, Origin) ->
%%            NewURI
%%
%%            URI    = #sipurl{}
%%            Origin = #siporigin{}
%%
%%            NewURI = #sipurl{}
%%
%% @doc     Perform some rather complex processing of a Request-URI if
%%          it has an maddr parameter. RFC3261 #16.4 (Route
%%          Information Preprocessing) requires this as some kind of
%%          backwards compatibility thing for clients that are trying
%%          to do loose routing while being strict routers. The world
%%          would be a better place without this need.
%% @end
%%--------------------------------------------------------------------
remove_maddr_matching_me(URI, Origin) when is_record(URI, sipurl), is_record(Origin, siporigin) ->
    case url_param:find(URI#sipurl.param_pairs, "maddr") of
        [MAddr] ->
	    LCMaddr = string:to_lower(MAddr),
	    {ok, MyHostnames} = yxa_config:get_env(myhostnames, []),
	    {ok, Homedomains} = yxa_config:get_env(homedomain, []),
	    case lists:member(LCMaddr, siphost:myip_list())
		orelse lists:member(LCMaddr, MyHostnames)
		orelse lists:member(LCMaddr, Homedomains) of
		true ->
		    %% Ok, maddr matches me or something 'the proxy is configured
		    %% to be responsible for'. Now check if port and transport in URI
		    %% matches what we received the request using, either explicitly
		    %% or by default. Sigh.
		    Port = sipsocket:default_port(URI#sipurl.proto, sipurl:get_port(URI)),
		    MyPort = case URI#sipurl.proto of
				 "sips" -> sipsocket:get_listenport(tls);
				 _ -> sipsocket:get_listenport(udp)
			     end,
		    case (Port == MyPort) of
			true ->
			    IsDefaultPort = (Port == sipsocket:default_port(URI#sipurl.proto, none)),
			    %% lastly check transport parameter too
			    case url_param:find(URI#sipurl.param_pairs, "transport") of
				[] ->
				    NewParam = url_param:remove(URI#sipurl.param_pairs, "maddr"),
				    %% implicit match since transport was not specified,
				    %% now 'strip the maddr and any non-default port'
				    case IsDefaultPort of
					true ->
					    sipurl:set([{param, NewParam}], URI);
					false ->
					    sipurl:set([{param, NewParam}, {port, none}], URI)
				    end;
				[Transport] ->
				    LCTransport = string:to_lower(Transport),
				    Matches =
					case {LCTransport, Origin#siporigin.proto} of
					    {"tcp", TCP} when TCP == tcp; TCP == tcp6 -> true;
					    {"udp", UDP} when UDP == udp; UDP == udp6 -> true;
					    {"tls", TLS} when TLS == tls; TLS == tls6 -> true;
					    _ -> false
					end,
				    case Matches of
					true ->
					    %% explicit match on transport, 'strip the maddr and any
					    %% non-default port or transport parameter'
					    NewParam1 = url_param:remove(URI#sipurl.param_pairs, "maddr"),
					    NewParam = url_param:remove(NewParam1, "transport"),
					    case IsDefaultPort of
						true ->
						    sipurl:set([{param, NewParam}], URI);
						false ->
						    sipurl:set([{param, NewParam}, {port, none}], URI)
					    end;
					false ->
					    %% transport parameter did not match
					    URI
				    end
			    end;
			false ->
			    %% port did not match
			    URI
		    end;
		false ->
		    %% maddr does not match me
		    URI
	    end;
	_ ->
	    %% no maddr
	    URI
    end.

%%--------------------------------------------------------------------
%% @spec    (Header) ->
%%            NewHeader
%%
%%            Header = term() "opaque #(keylist{})"
%%
%%            NewHeader = #keylist{}
%%
%% @doc     Look at the first Route header element in Header (if any)
%%          and see if it matches this proxy. If so, remove the first
%%          element and return a new Header.
%% @end
%%--------------------------------------------------------------------
remove_route_matching_me(Header) ->
    case keylist:fetch('route', Header) of
        [FirstRoute | RouteRest] ->
	    [FirstRouteParsed] = contact:parse([FirstRoute]),
	    case route_matches_me(FirstRouteParsed) of
		true ->
		    logger:log(debug, "Sipserver: First Route ~p matches me, removing it.",
			       [FirstRoute]),
		    case RouteRest of
			[] ->
			    keylist:delete('route', Header);
			_ ->
			    keylist:set("Route", RouteRest, Header)
		    end;
		false ->
		    Header
	    end;
	_ ->
	    %% No Route header
	    Header
    end.

%%--------------------------------------------------------------------
%% @spec    (Route) ->
%%            true  |
%%            false
%%
%%            Route = #contact{}
%%
%% @doc     Helper function for remove_route_matching_me/1. Check if
%%          an URL matches this proxys name (or address) and port.
%% @end
%%--------------------------------------------------------------------
route_matches_me(Route) when is_record(Route, contact) ->
    URL = sipurl:parse(Route#contact.urlstr),

    MyPorts = sipsocket:get_all_listenports(),
    Port = sipsocket:default_port(URL#sipurl.proto, sipurl:get_port(URL)),
    PortMatches = lists:member(Port, MyPorts),

    LChost = string:to_lower(URL#sipurl.host),
    {ok, MyHostnames} = yxa_config:get_env(myhostnames, []),
    HostnameMatches = (lists:member(LChost, MyHostnames) orelse
		       lists:member(LChost, siphost:myip_list())
		      ),

    case {HostnameMatches, PortMatches} of
	{true, true} ->
	    true;
	{true, false} ->
	    logger:log(debug, "Sipserver: Hostname ~p matches me, but port ~p derived from Route-header does not. "
		       "Concluding that first Route does not match me.", [LChost, Port]),
	    false;
	_ ->
	    false
    end.

%%--------------------------------------------------------------------
%% @spec    (Packet, Origin) -> ok
%%
%%            Packet = #request{} | #response{}
%%            Origin = #siporigin{} "information about where this Packet was received from"
%%
%% @throws  {sipparseerror, request, Header, Status, Reason}
%%
%% @doc     Sanity check To: and From: in a received request/response
%%          and, if Packet is a request record(), also check sanity
%%          of CSeq and (unless configured not to) check for a
%%          looping request.
%% @end
%%--------------------------------------------------------------------
%%
%% Packet is request record()
%%
check_packet(Request, Origin) when is_record(Request, request), is_record(Origin, siporigin) ->
    {Method, Header} = {Request#request.method, Request#request.header},
    true = check_supported_uri_scheme(Request#request.uri, Header),
    %% from here on, the request is guaranteed to have a parsed URI
    sanity_check_contact(request, "From", Header),
    sanity_check_contact(request, "To", Header),
    try sipheader:cseq(Header) of
	{CSeqNum, CSeqMethod} ->
	    case util:isnumeric(CSeqNum) of
		false ->
		    throw({sipparseerror, request, Header, 400, "CSeq number '" ++
			   CSeqNum ++ "' is not an integer"});
		_ -> true
	    end,
	    if
		CSeqMethod /= Method ->
		    throw({sipparseerror, request, Header, 400, "CSeq Method " ++ CSeqMethod ++
			   " does not match request Method " ++ Method});
		true -> true
	    end
    catch
	throw:
	  {yxa_unparsable, cseq, Reason} ->
	    logger:log(error, "INVALID CSeq in packet from ~s : ~p", [transportlayer:origin2str(Origin), Reason]),
	    throw({sipparseerror, request, Header, 400, "Invalid CSeq"})
    end,
    case yxa_config:get_env(detect_loops) of
	{ok, true} ->
	    check_for_loop(Header, Request#request.uri, Origin);
	{ok, false} ->
	    ok
    end;
%%
%% Packet is response record()
%%
check_packet(Response, Origin) when is_record(Response, response), is_record(Origin, siporigin) ->
    %% Check that the response code is within range. draft-ietf-sipping-torture-tests-04.txt
    %% #3.1.2.19 suggests that an element that receives a response with an overly large response
    %% code should simply drop it (that is what happens if we throw a sipparseerror when parsing
    %% responses).
    if
	Response#response.status >= 100, Response#response.status =< 699 -> ok;
	true ->
	    throw({sipparseerror, response, Response#response.header, 400, "Response code out of bounds"})
    end,
    sanity_check_contact(response, "From", Response#response.header),
    sanity_check_contact(response, "To", Response#response.header),
    ok.

%%--------------------------------------------------------------------
%% @spec    (Header, URI, Origin) -> ok
%%
%%            Header = term() "opaque #(keylist{})"
%%            URI    = term() "opaque #(sipurl{})"
%%            Origin = #siporigin{} "information about where this Packet was received from"
%%
%% @throws  {sipparseerror, request, Header, Status, Reason}
%%
%% @doc     Inspect Header's Via: record(s) to make sure this is not a
%%          looping request.
%% @end
%%--------------------------------------------------------------------
check_for_loop(Header, URI, Origin) when is_record(Origin, siporigin) ->
    LoopCookie = siprequest:get_loop_cookie(Header, URI, Origin#siporigin.proto),
    MyHostname = siprequest:myhostname(),
    MyPort = sipsocket:get_listenport(Origin#siporigin.proto),
    CmpVia = #via{host = MyHostname,
		  port = MyPort
		 },

    case via_indicates_loop(LoopCookie, CmpVia, sipheader:via(Header)) of
	true ->
	    logger:log(debug, "Sipserver: Found a loop when inspecting the Via headers, "
		       "throwing SIP-serror '482 Loop Detected'"),
	    throw({sipparseerror, request, Header, 482, "Loop Detected"});
	false ->
	    ok
    end.

%%--------------------------------------------------------------------
%% @spec    (LoopCookie, CmpVia, ViaList) ->
%%            true  |
%%            false
%%
%%            LoopCookie = string() "loop cookie as generated by siprequest:get_loop_cookie/3."
%%            CmpVia     = #via{} "what my Via would look like"
%%            ViaList    = [#via{}]
%%
%% @doc     Helper function for check_for_loop/3. See that function.
%% @end
%%--------------------------------------------------------------------
via_indicates_loop(_LoopCookie, _CmpVia, []) ->
    false;
via_indicates_loop(LoopCookie, CmpVia, [TopVia | Rest]) when is_record(TopVia, via)->
    case sipheader:via_is_equal(TopVia, CmpVia, [host, port]) of
	true ->
	    %% Via matches me
	    ParamDict = sipheader:param_to_dict(TopVia#via.param),
	    %% Can't use sipheader:get_via_branch() since it strips the loop cookie
	    case dict:find("branch", ParamDict) of
		error ->
		    %% XXX should broken Via perhaps be considered fatal?
		    logger:log(error, "Sipserver: Request has Via that matches me,"
			       " but no branch parameter. Loop checking broken!"),
		    logger:log(debug, "Sipserver: Via ~p matches me, but has no branch parameter."
			       " Loop checking broken!",
			       sipheader:via_print([TopVia])),
		    via_indicates_loop(LoopCookie, CmpVia, Rest);
		{ok, Branch} ->
		    case extract_loopcookie(Branch, length(LoopCookie)) of
			LoopCookie ->
			    true;
			_ ->
			    %% Loop cookie does not match, check next (request might have passed
			    %% this proxy more than once, loop can be further back the via trail)
			    via_indicates_loop(LoopCookie, CmpVia, Rest)
		    end
	    end;
	false ->
	    %% Via doesn't match me, check next.
	    via_indicates_loop(LoopCookie, CmpVia, Rest)
    end.

%% part of via_indicates_loop/3
%% Returns: LoopCookieString | error
extract_loopcookie(Branch, CookieLen) when CookieLen + 13 >= length(Branch) -> %% 13 is length("z9hG4bK-yxa-X")
    %% XXX should broken Via perhaps be considered fatal?
    logger:log(error, "Sipserver: Request has Via that matches me, but is too short. Loop checking broken!"),
    error;
extract_loopcookie(Branch, CookieLen) ->
    %% We lowercase the branch here because branches are tokens which are case-
    %% insensitive. Detecting loops are important, so we go through the extra
    %% trouble of being compliant by the letter here, in case someone has changed
    %% the casing of our Via header branch (never seen, but rumored to happen).
    RBranch1 = lists:reverse(Branch),
    %% lowercase as little of Branch as possible
    RBranch2 = string:to_lower( string:substr(RBranch1, 1, CookieLen + 2) ),	%% 2 is length("-o")
    %% now check for -o indicating a real loop cookie
    case lists:reverse(RBranch2) of
	"-o" ++ LoopCookie ->
	    LoopCookie;
	_ ->
	    %% XXX should broken Via perhaps be considered fatal?
	    logger:log(error, "Sipserver: Request has Via that matches me, has no loop cookie. Loop checking broken!"),
	    error
    end.


%%--------------------------------------------------------------------
%% @spec    (R, Origin) ->
%%            LogStr
%%
%%            R      = #request{} | #response{}
%%            Origin = #siporigin{}
%%
%%            LogStr = string()
%%
%% @doc     Create a textual representation of a request/response, for
%%          use in logging. Note :
%%          draft-ietf-sipping-torture-tests-04.txt argues that a
%%          proxy shouldn't fail processing a packet just because it
%%          has a From: header using an URI scheme that it doesn't
%%          understand - like http. Well, we do - here. The reason
%%          for not just fixing this here is that there might be
%%          other places where we expect the From: to be parsable by
%%          our sipheader:from() - and this hasn't been a problem in
%%          real life.
%% @end
%%--------------------------------------------------------------------
make_logstr(Request, Origin) when is_record(Request, request), is_record(Origin, siporigin) ->
    {Method, Header} = {Request#request.method, Request#request.header},
    URLstr =
	case Request#request.uri of
	    URI when is_record(URI, sipurl) ->
		sipurl:print(URI);
	    _ ->
		"unparsable"
	end,
    FromURLstr = make_logstr_get_sipheader(from, Header),
    ToURLstr   = make_logstr_get_sipheader(to, Header),
    ClientStr  = transportlayer:origin2str(Origin),
    lists:flatten(io_lib:format("~s ~s [client=~s, from=<~s>, to=<~s>]",
				[Method, URLstr, ClientStr, FromURLstr, ToURLstr]));
make_logstr(Response, Origin) when is_record(Response, response), is_record(Origin, siporigin) ->
    Header = Response#response.header,
    CSeqMethod = make_logstr_get_sipheader(cseq, Header),
    FromURLstr = make_logstr_get_sipheader(from, Header),
    ToURLstr   = make_logstr_get_sipheader(to, Header),
    ClientStr  = transportlayer:origin2str(Origin),
    case keylist:fetch('warning', Header) of
	[Warning] when is_list(Warning) ->
	    lists:flatten(io_lib:format("~s [client=~s, from=<~s>, to=<~s>, warning=~p]",
					[CSeqMethod, ClientStr, FromURLstr, ToURLstr, Warning]));
	_ ->
	    %% Zero or more than one Warning-headers
	    lists:flatten(io_lib:format("~s [client=~s, from=<~s>, to=<~s>]",
					[CSeqMethod, ClientStr, FromURLstr, ToURLstr]))
    end.

%% part of make_logstr/2
make_logstr_get_sipheader(Func, Header) ->
    try {Func, sipheader:Func(Header)} of
	{from, {_DisplayName, URI}} -> sipurl:print(URI);
	{to,   {_DisplayName, URI}} -> sipurl:print(URI);
	{cseq, {_Seq, Method}} -> Method
    catch
	throw: _ -> "unparsable"
    end.

%%--------------------------------------------------------------------
%% @spec    (Type, Name, Header) -> term()
%%
%%            Type   = request | response
%%            Name   = string() "\"From\" or \"To\" or similar"
%%            Header = #keylist{}
%%
%% @throws  {sipparseerror, Type, Header, Status, Reason}
%%
%% @doc     Check if the header Name (from Header) is parsable.
%%          Currently we define parsable as parsable by
%%          sipheader:from().
%% @end
%%--------------------------------------------------------------------
sanity_check_contact(Type, Name, Header) when Type == request; Type == response; is_list(Name),
					      is_record(Header, keylist) ->
    case keylist:fetch(Name, Header) of
	[Str] when is_list(Str) ->
	    try sipheader:from([Str]) of
		{_, URI} when is_record(URI, sipurl) ->
		    sanity_check_uri(Type, Name ++ ":", URI, Header);
		_ ->
		    throw({sipparseerror, Type, Header, 400, "Invalid " ++ Name ++ ": header"})
	    catch
		_X: _Y ->
		    throw({sipparseerror, Type, Header, 400, "Invalid " ++ Name ++ ": header"})
	    end;
	_ ->
	    %% Header is either missing, or there was more than one
	    throw({sipparseerror, Type, Header, 400, "Missing or invalid " ++ Name ++ ": header"})
    end.

%% part of sanity_check_contact/4
sanity_check_uri(Type, Desc, URI, Header)  when is_record(URI, sipurl), URI#sipurl.host == none ->
    throw({sipparseerror, Type, Header, 400, "No host part in " ++ Desc ++ " URL"});
sanity_check_uri(_Type, _Desc, URI, _Header) when is_record(URI, sipurl) ->
    ok.

%%--------------------------------------------------------------------
%% @spec    (URI, Header) -> true
%%
%%            URI    = #sipurl{} | {yxa_unparsable, uri, {Error :: atom(), URIstr :: string()}}
%%            Header = #keylist{}
%%
%% @throws  {sipparseerror, Type, Header, Status, Reason}
%%
%% @doc     Check if we supported the URI scheme of a request. If we
%%          didn't support the URI scheme, sipurl:parse(...) will
%%          have failed, and we just format the 416 error response.
%% @end
%%--------------------------------------------------------------------
check_supported_uri_scheme({yxa_unparsable, url, {invalid_proto, _URIstr}}, Header) when is_record(Header, keylist) ->
    throw({sipparseerror, request, Header, 416, "Missing URI Scheme"});
check_supported_uri_scheme({yxa_unparsable, url, {unknown_proto, _URIstr}}, Header) when is_record(Header, keylist) ->
    throw({sipparseerror, request, Header, 416, "Unsupported URI Scheme"});
check_supported_uri_scheme({yxa_unparsable, url, _Reason}, Header) when is_record(Header, keylist) ->
    throw({sipparseerror, request, Header, 400, "Unparsable Request-URI"});
check_supported_uri_scheme(URI, Header) when is_record(URI, sipurl), is_record(Header, keylist) ->
    true.


%%====================================================================
%% Internal functions
%%====================================================================

%%--------------------------------------------------------------------
%% Function:
%% Descrip.:
%% Returns :
%%--------------------------------------------------------------------


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
