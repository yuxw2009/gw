%%%-------------------------------------------------------------------
%%% File    : incomingproxy.erl
%%% @author   Magnus Ahltorp <ahltorp@nada.kth.se>
%%% @doc      Server handling registrar functions and routing of SIP-
%%%           requests/responses. See the README file for more
%%            information.
%%%
%%% @since    15 Nov 2002 by Magnus Ahltorp <ahltorp@nada.kth.se>
%%% @end
%%%-------------------------------------------------------------------
-module(sip_virtual).

-behaviour(yxa_app).

%%--------------------------------------------------------------------
%%% Standard YXA SIP-application callback functions
%%--------------------------------------------------------------------
-export([
	 config_defaults/0,
	 init/0,
	 request/2,
	 response/2,
	 initdb/0,
	 add_a_x/3,
	 bind_b/2,
	 get_by_x/1,
	 get_by_x/3,
	 terminate/1
	]).

-export([test/0]).
%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("siprecords.hrl").
-include("sipsocket.hrl").
-include("yxa_config.hrl").
-include("db_op.hrl").
-include("virtual.hrl").
%%====================================================================
%% Behaviour functions
%% Standard YXA SIP-application callback functions
%%====================================================================

%%--------------------------------------------------------------------
%% @spec    () -> AppConfig
%%
%%            AppConfig = [#cfg_entry{}]
%%
%% @doc     Return application defaults.
%% @end
%%--------------------------------------------------------------------
config_defaults() ->
    [
	   #cfg_entry{key	= homedomain,
		      list_of	= true,
		      type	= string,
		      default	= ["10.32.3.213"],
		      required	= true
		     },
	 #cfg_entry{key	= timerT1,
		    default	= 800,
		    type	= integer
		   }

    ].%++?INCOMINGPROXY_CONFIG_DEFAULTS.
%config_defaults() ->
%    ?INCOMINGPROXY_CONFIG_DEFAULTS.
%%--------------------------------------------------------------------
%% @spec    () -> #yxa_app_init{}
%%
%% @doc     YXA applications must export an init/0 function.
%% @hidden
%% @end
%%--------------------------------------------------------------------
init() ->
    Registrar = {registrar, {registrar, start_link, []}, permanent, 2000, worker, [registrar]},
    Tables = [user, numbers, phone, cpl_script_graph, regexproute, gruu],
    #yxa_app_init{sup_spec	= {append, [Registrar]},
		  mnesia_tables	= Tables
		 }.


create_tables() ->
    mnesia:create_table(active_trans_t,[{attributes,record_info(fields,active_trans_t)},{ram_copies ,[node()]}]),
    mnesia:create_table(company_t,[{attributes,record_info(fields,company_t)},{disc_copies ,[node()]}]),
    mnesia:create_table(sip_nic_t,[{attributes,record_info(fields,sip_nic_t)},{disc_copies ,[node()]},{index, [addr_info,node]}]),
    mnesia:create_table(a_x_t,[{attributes,record_info(fields,a_x_t)},{disc_copies,[node()]},{index, [x]}]),
    create_axbt().
create_axbt()->mnesia:create_table(a_x_b_t,[{attributes,record_info(fields,a_x_b_t)},{disc_copies,[node()]}]).

delete_a_x(A)-> 
    case ?DB_READ(a_x_t,utility:value2binary(A)) of
    {atomic,[#a_x_t{x=X,companyid=ComId}]}->
        case ?DB_READ(company_t,ComId) of
        {atomic,[Xt=#company_t{available_xs=Xs0,used_xs=Ux0}]}->
            Xs1=case lists:member(X,Ux0) of
                        true-> [X|Xs0]; _-> Xs0 
                    end,
            ?DB_WRITE(Xt#company_t{available_xs=Xs1,used_xs=Ux0--[X]});
        _-> void
        end,
       ?DB_DELETE({a_x_t,utility:value2binary(A)});
    _-> void
    end.
add_a_x(ComId,A,X)->add_a_x(ComId,A,X,undefined).
add_a_x(ComId,A,X,_Trans)->
    [Comp=#company_t{available_xs=AXS,used_xs=UXS}]=config_intf:get_company(ComId),
    ?DB_WRITE(Comp#company_t{available_xs=AXS--[X],used_xs=[X|UXS]}),
    ?DB_WRITE(#a_x_t{a=utility:value2binary(A),x=utility:value2binary(X),companyid=utility:value2binary(ComId)}),
    %bind_b(?NULL_B,A),
    ok.

add_a_x_inc(_ComId,_A,_X,Trans,0)    -> void;
add_a_x_inc(ComId,A,X,Trans,Num) when is_integer(A),is_integer(X),is_integer(Num)->    
    add_a_x(ComId,utility:value2binary(A),utility:value2binary(X),Trans),
    add_a_x_inc(ComId,A+1,X+1,Trans,Num-1).
get_a_x_by_x(X)->
    mnesia:dirty_index_read(a_x_t,utility:value2binary(X),#a_x_t.x).
unbind_b(X)-> unbind_b(X,?DEFAULT_TRANS).
unbind_b(X,Trans)->unbind_b(X,Trans,single).
unbind_b(X,Trans,Mode)->
    ?DB_DELETE({a_x_b_t,{X,Trans}}).
bind_b(B,A)->bind_b(B,A,?DEFAULT_TRANS).
bind_b(B,A,Trans)->bind_b(B,A,Trans,single).
bind_b(B,A,Trans,Mode)-> bind_b1(utility:value2binary(B),utility:value2binary(A),utility:value2binary(Trans),Mode).
bind_b1(B,A,Trans,Mode)->
    io:format("bind_b:~p~n",[{B,A,Trans}]),
    case mnesia:dirty_read(a_x_t,A) of
    	[#a_x_t{a=A,x=X}]->
    	     ?DB_WRITE(#a_x_b_t{x_t={X,Trans},b=B,a=A,mode=Mode}),
    	     {true,""};
    	_-> 
    	    io:format("bind_b not found a:~p~n",[A]),
    	    {false,"a_error"}
    end.
bind_bs([])-> void;
bind_bs([#a_x_t{a=A}|T])->
    bind_b(?NULL_B,A),
    bind_bs(T).
get_by_x(X)    -> get_by_x(X,?DEFAULT_TRANS).
get_by_x(X,Trans)->get_by_x(X,Trans,single).
get_by_x(X,Trans,Mode)   when is_binary(Mode) -> get_by_x(X,Trans,list_to_atom(binary_to_list(Mode)));
get_by_x(X,Trans,Mode)   when is_list(Mode) -> get_by_x(X,Trans,list_to_atom(Mode));
get_by_x(X,Trans,Mode)-> get_by_x1(utility:value2binary(X),utility:value2binary(Trans),Mode).
get_by_x1(X,Trans,_Mode)    ->
    case mnesia:dirty_read(a_x_b_t,{X,Trans}) of
    	[X_I=#a_x_b_t{}]-> X_I;
    	_->[]
    end.
init_axbt()->    
    	    case ?DB_QUERY(a_x_t) of
    	    	{atomic,Lists}-> 
    	    	    create_axbt(),
    	    	    bind_bs(Lists);
    	    	_-> void
    	    end.
initdb()->
    mnesia:start(),
    Tables = mnesia:system_info(tables),
    case lists:member(a_x_t, Tables) of
    	true -> 
%    	    init_axbt(),
    	    pass;
    	false ->
    	    mnesia:stop(),
            mnesia:create_schema([node()]),
            mnesia:start(),
            io:format("no available a_x_t~n"),
	        create_tables()
    end,
	io:format("mensia start waiting!~n"),
    mnesia:wait_for_tables([a_x_t],20000),
	io:format("mensia waiting end!~n").

%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx) ->
%%            term() "Yet to be specified. Return 'ok' for now."
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%
%% @doc     YXA applications must export a request/2 function.
%% @end
%%--------------------------------------------------------------------
%%
%% ACK
%%
request(#request{method = "INVITE"} = Request, YxaCtx) when is_record(YxaCtx, yxa_ctx) ->
    sip_op:start(Request,YxaCtx,?MODULE),
    ok;
request(#request{method = "ACK"} = Request, YxaCtx) when is_record(YxaCtx, yxa_ctx) ->
    transportlayer:stateless_proxy_ack("incomingproxy", Request, YxaCtx),
    ok;

%%
%% non-ACK
%%
request(Request, YxaCtx) when is_record(Request, request), is_record(YxaCtx, yxa_ctx) ->
    LogTag = transactionlayer:get_branchbase_from_handler(YxaCtx#yxa_ctx.thandler),
    YxaCtx1 =
	YxaCtx#yxa_ctx{app_logtag = LogTag
		      },
    request2(Request, YxaCtx1).

%%
%% REGISTER
%%
%% XXX REGISTER request processing is done slightly out of order
%% (step 2) compared to the RFC (RFC 3261 chapter 10.3) specification.
%% This could theoreticaly result in unexpected, but legal, error
%% responses.
request2(#request{method = "REGISTER"} = Request, YxaCtx) when is_record(YxaCtx, yxa_ctx) ->
    case siplocation:process_register_request(Request, YxaCtx, incomingproxy) of
	not_homedomain ->
	    do_request(Request, YxaCtx);
	_ ->
	    true
    end,
    ok;

%%
%% CANCEL or BYE
%%
%% These requests cannot be challenged. CANCEL because it can't be resubmitted (RFC3261 #22.1),
%% and ACK because it is illegal to send responses to ACK. Bypass check of authorized From: address.
request2(#request{method = Method} = Request, YxaCtx) when Method == "CANCEL" orelse Method == "BYE",
							  is_record(YxaCtx, yxa_ctx) ->
    do_request(Request, YxaCtx),
    ok;

%%
%% Request other than REGISTER, ACK, CANCEL or BYE
%%
request2(Request, YxaCtx) when is_record(Request, request), is_record(YxaCtx, yxa_ctx) ->
    {_, FromURI} = sipheader:from(Request#request.header),
    %% Check if the From: address matches our homedomains, and if so
    %% call verify_homedomain_user() to make sure the user is
    %% authorized and authenticated to use this From: address
    case local:homedomain(FromURI#sipurl.host) of
	true ->
	    case verify_homedomain_user(Request, YxaCtx) of
		true ->
		    do_request(Request, YxaCtx);
		false ->
		    logger:log(normal, "~s: incomingproxy: Not authorized to use this From: -> 403 Forbidden",
			       [YxaCtx#yxa_ctx.app_logtag]),
		    transactionlayer:send_response_handler(YxaCtx#yxa_ctx.thandler, 403, "Forbidden");
		drop ->
		    ok
	    end;
	_ ->
	    do_request(Request, YxaCtx)
    end,
    ok.

%%--------------------------------------------------------------------
%% @spec    (Response, YxaCtx) ->
%%            term() "Yet to be specified. Return 'ok' for now."
%%
%%            Request = #response{}
%%            YxaCtx  = #yxa_ctx{}
%%
%% @doc     YXA applications must export an response/3 function.
%% @end
%%--------------------------------------------------------------------
response(Response, YxaCtx) when is_record(Response, response), is_record(YxaCtx, yxa_ctx) ->
    {Status, Reason} = {Response#response.status, Response#response.reason},
    logger:log(normal, "incomingproxy: Response to ~s: '~p ~s', no matching transaction - proxying statelessly",
	       [YxaCtx#yxa_ctx.logstr, Status, Reason]),
    transportlayer:send_proxy_response(none, Response),
    ok.

%%--------------------------------------------------------------------
%% @spec    (Mode) ->
%%            term() "Yet to be specified. Return 'ok' for now."
%%
%%            Mode = shutdown | graceful | atom()
%%
%% @doc     YXA applications must export a terminate/1 function.
%% @hidden
%% @end
%%--------------------------------------------------------------------
terminate(Mode) when is_atom(Mode) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================


%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx) -> true | false | drop
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%
%% @doc     If a request has a From: matching our homedomains, this
%%          function is called to make sure the user really is who it
%%          says it is, and not someone else forging our users
%%          identity.
%% @end
%%--------------------------------------------------------------------
verify_homedomain_user(Request, YxaCtx) when is_record(Request, request), is_record(YxaCtx, yxa_ctx) ->
    case yxa_config:get_env(always_verify_homedomain_user) of
	{ok, true} ->
	    ToTag = sipheader:get_tag( keylist:fetch('to', Request#request.header) ),
	    {ok, AuthInDialog} = yxa_config:get_env(authenticate_in_dialog_requests),
	    if
		ToTag /= none, AuthInDialog /= true ->
		    %% This is a request inside a dialog. There is not as much need to authenticate such requests.
		    logger:log(debug, "incomingproxy: NOT authenticating in-dialog request"),
		    true;
		true ->
		    verify_homedomain_user2(Request, YxaCtx)
	    end;
	{ok, false} ->
	    true
    end.

verify_homedomain_user2(Request, YxaCtx) ->
    LogTag = YxaCtx#yxa_ctx.app_logtag,
    {Method, Header} = {Request#request.method, Request#request.header},
    {_, FromURI} = sipheader:from(Header),
    %% Request has a From: address matching one of my domains.
    %% Verify sending user.
    case local:get_user_verified_proxy(Header, Method) of
	{authenticated, SIPUser} ->
	    case local:can_use_address(SIPUser, FromURI) of
		true ->
		    logger:log(debug, "Request: User ~p is allowed to use From: address ~p",
			       [SIPUser, sipurl:print(FromURI)]),
		    %% Generate a request_info event with some information about this request
		    L = [{from_user, SIPUser}],
		    event_handler:request_info(normal, LogTag, L),
		    true;
		false ->
		    logger:log(error, "Authenticated user ~p may NOT use address ~p",
			       [SIPUser, sipurl:print(FromURI)]),
		    false
	    end;
	{stale, SIPuser} ->
	    logger:log(normal, "~s: incomingproxy: From: address requires authentication (stale, user ~p)",
		       [LogTag, SIPuser]),
	    transactionlayer:send_challenge_request(Request, proxy, true, none),
	    drop;
	false ->
	    case keylist:fetch('proxy-authenticate', Header) of
		[] ->
		    logger:log(normal, "~s: incomingproxy: From: address requires authentication", [LogTag]),
		    transactionlayer:send_challenge_request(Request, proxy, false, none),
		    drop;
		_ ->
		    OStr = transportlayer:origin2str(YxaCtx#yxa_ctx.origin),
		    LogStr = YxaCtx#yxa_ctx.logstr,
		    Msg = io_lib:format("Request from ~s failed authentication : ~s", [OStr, LogStr]),
		    event_handler:generic_event(normal, auth, LogTag, Msg),
		    false
	    end
    end.


%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx) -> term() "Does not matter"
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%
%% @doc     Calls route_request() to determine what to do with a
%%          request, and then takes whatever action we are supposed
%%          to.
%% @end
%%--------------------------------------------------------------------
do_request(Request, YxaCtx) when is_record(Request, request), is_record(YxaCtx, yxa_ctx) ->
    #yxa_ctx{origin     = Origin,
	     thandler   = THandler,
	     app_logtag = LogTag
	    } = YxaCtx,
    {Method, URI} = {Request#request.method, Request#request.uri},
    logger:log(debug, "incomingproxy: Processing request ~s ~s~n", [Method, sipurl:print(URI)]),
    Location = route_request(Request, Origin, LogTag),
    logger:log(debug, "incomingproxy: Routing desicion: ~s", [lookup:lookup_result_to_str(Location)]),
    case Location of
	none ->
	    logger:log(normal, "~s: incomingproxy: 404 Not found", [LogTag]),
	    transactionlayer:send_response_handler(THandler, 404, "Not Found");

	{error, Errorcode} ->
	    logger:log(normal, "~s: incomingproxy: Error ~p", [LogTag, Errorcode]),
	    transactionlayer:send_response_handler(THandler, Errorcode, "Unexplained error");
	{response, Status, Reason} ->
	    logger:log(normal, "~s: incomingproxy: Response '~p ~s'", [LogTag, Status, Reason]),
	    transactionlayer:send_response_handler(THandler, Status, Reason);

	{proxy, Loc,NRequest} when is_record(Loc, sipurl) ->
	    logger:log(normal, "~s: incomingproxy: Proxy ~s -> ~s", [LogTag, Method, sipurl:print(Loc)]),
	    proxy_request(NRequest, YxaCtx, Loc);
	{proxy, Loc} when is_record(Loc, sipurl) ->
	    logger:log(normal, "~s: incomingproxy: Proxy ~s -> ~s", [LogTag, Method, sipurl:print(Loc)]),
	    proxy_request(Request, YxaCtx, Loc);
	{proxy, [H | _] = DstList} when is_record(H, sipdst) ->
	    logger:log(normal, "~s: incomingproxy: Proxy ~s to list of destinations", [LogTag, Method]),
	    logger:log(debug, "~s: incomingproxy: Proxy ~s -> ~s", [LogTag, Method, DstList]),
	    proxy_request(Request, YxaCtx, DstList);
	{proxy, route} ->
	    logger:log(normal, "~s: incomingproxy: Proxy ~s according to Route header", [LogTag, Method]),
	    proxy_request(Request, YxaCtx, route);
	{proxy, {with_path, URL, Path}} when is_record(URL, sipurl), is_list(Path) ->
            %% RFC3327
            logger:log(normal, "~s: incomingproxy: Proxy ~s -> ~s (with path: ~p)",
                       [LogTag, Method, sipurl:print(URL), Path]),
            NewHeader = keylist:prepend({"Route", Path}, Request#request.header),
            proxy_request(Request#request{uri = URL,
					  header = NewHeader
					 }, YxaCtx, route);

	{redirect, Loc} when is_record(Loc, sipurl) ->
	    logger:log(normal, "~s: incomingproxy: Redirect to ~s", [LogTag, sipurl:print(Loc)]),
	    Contact = [contact:new(none, Loc, [])],
	    ExtraHeaders = [{"Contact", sipheader:contact_print(Contact)}],
	    transactionlayer:send_response_handler(THandler, 302, "Moved Temporarily", ExtraHeaders);

	{relay, Loc} when (is_record(Loc, sipurl) orelse Loc == route orelse is_list(Loc)) ->
	    relay_request(Request, YxaCtx, Loc);

	{forward, #sipurl{user = none, pass = none} = FwdURL} ->
	    logger:log(normal, "~s: incomingproxy: Forward ~s ~s to ~s",
		       [LogTag, Method, sipurl:print(URI), sipurl:print(FwdURL)]),
	    forward_request(Request, YxaCtx, FwdURL);

	to_this_proxy ->
	    siprequest:request_to_me(Request, YxaCtx, _ExtraHeaders = []);

	_ ->
	    logger:log(error, "~s: incomingproxy: Invalid Location ~p", [LogTag, Location]),
	    transactionlayer:send_response_handler(THandler, 500, "Server Internal Error")
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, Origin, LogTag) ->
%%            {error, Status}            |
%%            {response, Status, Reason} |
%%            {proxy, Location}          |
%%            {relay, Location}          |
%%            {forward, Location}        |
%%            to_this_proxy              |
%%            none
%%
%%            Request = #request{}
%%            Origin  = #siporigin{}
%%            LogTag  = string()
%%
%% @doc     Check if a request is destined for this proxy, a local
%%          domain or a remote domain. In case of a local domain, we
%%          call request_to_homedomain(), and in case of a remote
%%          domain we call request_to_remote(). If these functions
%%          return 'nomatch' we call lookupdefault().
%% @end
%%--------------------------------------------------------------------
route_request(Request=#request{uri=Uri=#sipurl{user="*0086"++Phone}}, _Origin=#siporigin{addr="10.32.4.11"}, _LogTag) ->
    {proxy, Uri#sipurl{user="0086"++Phone,host="10.32.4.11"},Request};%#request{header=keylist:delete(via,Request#request.header)}};
route_request(Request, Origin, LogTag) when is_record(Request, request), is_list(LogTag) ->
    URL = Request#request.uri,
    case keylist:fetch('route', Request#request.header) of
	[] ->
	    IsHomedomain = local:homedomain(URL#sipurl.host),
	    IsMyPort =
		case URL#sipurl.port of
		    none ->
			true;
		    Port ->
			lists:member(Port, sipsocket:get_all_listenports())
		end,
	    Loc1 = case IsHomedomain andalso IsMyPort of
		       true ->
			   case local:is_request_to_this_proxy(Request) of
			       true ->
				   to_this_proxy;
			       _ ->
				   request_to_homedomain(Request, Origin, LogTag)
			   end;
		       _ ->
			   request_to_remote(Request, Origin)
		   end,
	    case Loc1 of
		nomatch ->
		    logger:log(debug, "Routing: No match - trying default route"),
		    local:lookupdefault(URL);
		_ ->
		    Loc1
	    end;
	_ ->
	    %% Request has Route header
	    case local:get_user_with_contact(URL) of
		none ->
		    %% XXX also do proxy instead of relay if Request-URI matching one of our users addresses?
		    %% Maybe we should do proxying instead of relaying if the Request-URI matches one of our
		    %% homedomains?
		    logger:log(debug, "Routing: Request has Route header, relaying according to Route."),
		    {relay, route};
		User ->
		    logger:log(debug, "Routing: Request has Route header, and is for our user ~p - "
			       "proxy according to Route.", [User]),
		    {proxy, route}
	    end
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, Origin, LogTag) ->
%%            {error, Status}              |
%%            {response, Status, Reason}   |
%%            {proxy, Location}            |
%%            {relay, Location}            |
%%            {forward, Location}          |
%%            none
%%
%%            Request = #request{}
%%            Origin  = #siporigin{}
%%            LogTag  = string()
%%
%% @doc     Find out where to route this request which is for one of
%%          our homedomains.
%% @end
%%--------------------------------------------------------------------
request_to_homedomain(Request, Origin, LogTag) when is_record(Request, request), is_record(Origin, siporigin),
						    is_list(LogTag) ->
    request_to_homedomain(Request, Origin, LogTag, init).

request_to_homedomain(Request, Origin, LogTag, Recursing) when is_record(Request, request), is_record(Origin, siporigin),
							       is_list(LogTag) ->
    URL = Request#request.uri,
    URLstr = sipurl:print(URL),
    logger:log(debug, "Routing: Request to homedomain, URI ~p", [URLstr]),

    case request_homedomain_event(Request, Origin) of
	{forward, FwdURL} when is_record(FwdURL, sipurl) ->
	    {forward, FwdURL};
	false ->
	    case local:lookupuser(URL) of
		nomatch ->
		    request_to_homedomain_not_sipuser(Request, Origin, LogTag, Recursing);
		{ok, Users, none} ->
		    logger:log(debug, "Routing: I currently have no locations for user(s) ~p, "
			       "in the location database, answering '480 Temporarily Unavailable'",
			       [Users]),
		    {response, 480, "Users location currently unknown"};
		{ok, Users, Res} when is_list(Users) ->
		    request_to_homedomain_log_result(URLstr, Res),

		    %% Generate a request_info event with some information about this request
		    L = [{to_users, Users}],
		    event_handler:request_info(normal, LogTag, L),

		    Res;
		{ok, none, Res} ->
		    Res
	    end
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, Origin, LogTag) ->
%%            {forward, Location} |
%%            false
%%
%%            Request = #request{}
%%            Origin  = #siporigin{}
%%
%% @doc     Find out where to route a PUBLISH or SUBSCRIBE to one of
%%          our homedomains.
%% @end
%%--------------------------------------------------------------------
request_homedomain_event(#request{method = Method} = Request, Origin) when Method == "PUBLISH" orelse
									   Method == "SUBSCRIBE" ->
    case local:incomingproxy_request_homedomain_event(Request, Origin) of
	undefined ->
	    {ok, EventDstL} = yxa_config:get_env(eventserver_for_package),
	    EventPackage = sipheader:event_package(Request#request.header),

	    case lists:keysearch(EventPackage, 1, EventDstL) of
		{value, {EventPackage, URL}} when is_record(URL, sipurl) ->
		    {forward, URL};
		false ->
		    %% use default eventserver parameter since we found no
		    %% match for this specific EventPackage
		    case yxa_config:get_env(eventserver) of
			{ok, #sipurl{user = none, pass = none} = URL} ->
			    {forward, URL};
			none ->
			    false
		    end
	    end;
	Res ->
	    Res
    end;
request_homedomain_event(_Request, _Origin) ->
    false.

request_to_homedomain_log_result(URLstr, {A, U}) when is_atom(A), is_record(U, sipurl) ->
    logger:log(debug, "Routing: lookupuser on ~p -> ~p to ~p", [URLstr, A, sipurl:print(U)]);
request_to_homedomain_log_result(URLstr, {forward, Proto, Host, Port}) ->
    logger:log(debug, "Routing: lookupuser on ~p -> forward to ~p:~s:~p", [URLstr, Proto, Host, Port]);
request_to_homedomain_log_result(URLstr, Res) ->
    logger:log(debug, "Routing: lookupuser on ~p -> ~p", [URLstr, Res]).

%%--------------------------------------------------------------------
%% @spec    (Request, Origin, LogTag, Recursing) ->
%%            {error, Status}            |
%%            {response, Status, Reason} |
%%            {proxy, Location}          |
%%            {relay, Location}          |
%%            {forward, Location}        |
%%            none
%%
%%            Request   = #request{}
%%            Origin    = #siporigin{}
%%            LogTag    = string()
%%            Recursing = init | loop "have we recursed already?"
%%
%% @doc     Second part of request_to_homedomain/1. The request is not
%%          for one of our SIP-users, call
%%          local:lookup_homedomain_request() and if that does not
%%          result in something usefull then see if this is something
%%          we can interpret as a phone number.
%% @end
%%--------------------------------------------------------------------
request_to_homedomain_not_sipuser(_Request, _Origin, _LogTag, loop) ->
    none;
request_to_homedomain_not_sipuser(Request, Origin, LogTag, init)
  when is_record(Request, request), is_record(Origin, siporigin), is_list(LogTag) ->
    URL = Request#request.uri,

    Loc1 = local:lookup_homedomain_request(Request, Origin),
    logger:log(debug, "Routing: local:lookup_homedomain_request on ~s -> ~p", [sipurl:print(URL), Loc1]),

    case Loc1 of
	none ->
	    %% local:lookuppotn() returns 'none' if argument is not numeric,
	    %% so we don't have to check that...
	    Res1 = local:lookuppotn(URL#sipurl.user),
	    logger:log(debug, "Routing: lookuppotn on ~s -> ~p", [URL#sipurl.user, Res1]),
	    Res1;
	{proxy, NewURL} when is_record(NewURL, sipurl) ->
	    logger:log(debug, "Routing: request_to_homedomain_not_sipuser: Calling request_to_homedomain on "
		       "result of local:lookup_homedomain_request (local URL ~s)",
		       [sipurl:print(NewURL)]),
	    request_to_homedomain(Request#request{uri = URL}, Origin, LogTag, loop);
	{relay, Dst} ->
	    logger:log(debug, "Routing: request_to_homedomain_not_sipuser: Turning relay into proxy, original "
		       "request was to a local domain"),
	    {proxy, Dst};
	_ ->
	    Loc1
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, Origin) ->
%%            {error, Status}            |
%%            {response, Status, Reason} |
%%            {proxy, Location}          |
%%            {relay, Location}          |
%%            {forward, Location}        |
%%            none
%%
%%            Request = #request{}
%%            Origin  = #siporigin{}
%%
%% @doc     Find out where to route this request which is for a remote
%%          domain.
%% @end
%%--------------------------------------------------------------------
request_to_remote(Request, Origin) when is_record(Request, request), is_record(Origin, siporigin) ->
    URL = Request#request.uri,
    case local:lookup_remote_request(Request, Origin) of
	none ->
	    case local:get_user_with_contact(URL) of
		none ->
		    logger:log(debug, "Routing: ~p is not a local domain, relaying", [URL#sipurl.host]),
		    {relay, URL};
		SIPuser ->
		    logger:log(debug, "Routing: ~p is not a local domain,"
			       " but it is a registered location of SIPuser ~p. Proxying.",
			       [sipurl:print(URL), SIPuser]),
		    {proxy, URL}
	    end;
	Location ->
	    logger:log(debug, "Routing: local:lookup_remote_request() ~s -> ~p", [sipurl:print(URL), Location]),
	    Location
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx, FwdURL) -> term() "Does not matter"
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%            FwdURL  = #sipurl{}
%%
%% @doc     Forward a request somewhere without authentication. This
%%          function is used when forwarding requests to another
%%          proxy that should handle it instead of us. It preserves
%%          the Request-URI.
%% @end
%%--------------------------------------------------------------------
forward_request(Request, YxaCtx, FwdURL) ->
    THandler = YxaCtx#yxa_ctx.thandler,
    URI = Request#request.uri,
    ApproxMsgSize = siprequest:get_approximate_msgsize(Request#request{uri=FwdURL}),
    case sipdst:url_to_dstlist(FwdURL, ApproxMsgSize, URI) of
	{error, nxdomain} ->
	    logger:log(debug, "incomingproxy: Failed resolving FwdURL : NXDOMAIN"
		       " (responding '604 Does Not Exist Anywhere')"),
	    transactionlayer:send_response_handler(THandler, 604, "Does Not Exist Anywhere"),
	    error;
	{error, What} ->
	    logger:log(normal, "incomingproxy: Failed resolving FwdURL : ~p", [What]),
	    transactionlayer:send_response_handler(THandler, 500, "Failed resolving forward destination"),
	    error;
	DstList when is_list(DstList) ->
	    proxy_request(Request, YxaCtx, DstList)
    end.

%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx, Dst) -> term() "Does not matter"
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%            Dst     = #sipdst{} | #sipurl{} | route | [#sipdst{}]
%%
%% @doc     Proxy a request somewhere without authentication.
%% @end
%%--------------------------------------------------------------------
proxy_request(Request, YxaCtx, Dst) when is_record(Request, request) ->
    start_sippipe(Request, YxaCtx, Dst, []).

%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx, Dst) -> term() "Does not matter"
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%            Dst     = #sipdst{} | #sipurl{} | route | [#sipdst{}]
%%
%% @doc     Relay request to remote host. If there is not valid
%%          credentials present in the request, challenge user unless
%%          local policy says not to. Never challenge CANCEL or BYE
%%          since they can't be resubmitted and therefor cannot be
%%          challenged.
%% @end
%%--------------------------------------------------------------------

%%
%% CANCEL or BYE
%%
relay_request(#request{method = Method} = Request, YxaCtx, Dst) when Method == "CANCEL"; Method == "BYE" ->
    logger:log(normal, "~s: incomingproxy: Relay ~s ~s (unauthenticated)",
	       [YxaCtx#yxa_ctx.app_logtag, Method, sipurl:print(Request#request.uri)]),
    start_sippipe(Request, YxaCtx, Dst, []);

%%
%% Anything but CANCEL or BYE
%%
relay_request(Request, YxaCtx, Dst) when is_record(Request, request) ->
    {Method, Header} = {Request#request.method, Request#request.header},
    #yxa_ctx{origin	= Origin,
	     thandler	= THandler,
	     app_logtag	= LogTag
	    } = YxaCtx,
    case local:get_user_verified_proxy(Header, Method) of
	{authenticated, User} ->
	    logger:log(debug, "Relay: User ~p is authenticated", [User]),
	    logger:log(normal, "~s: incomingproxy: Relay ~s (authenticated)", [LogTag, relay_dst2str(Dst)]),
	    start_sippipe(Request, YxaCtx, Dst, []);
	{stale, User} ->
	    case local:incomingproxy_challenge_before_relay(Origin, Request, Dst) of
		false ->
		    logger:log(debug, "Relay: STALE authentication (user ~p), but local policy says we "
			       "should not challenge", [User]),
		    start_sippipe(Request, YxaCtx, Dst, []);
		true ->
		    logger:log(debug, "Relay: STALE authentication, sending challenge"),
		    logger:log(normal, "~s: incomingproxy: Relay ~s -> STALE authentication (user ~p) ->"
			       " 407 Proxy Authentication Required",
			       [LogTag, relay_dst2str(Dst), User]),
		    transactionlayer:send_challenge(THandler, proxy, true, none)
	    end;
	false ->
            case local:incomingproxy_challenge_before_relay(Origin, Request, Dst) of
                false ->
                    logger:log(debug, "Relay: Failed authentication, but local policy says we should not challenge"),
		    start_sippipe(Request, YxaCtx, Dst, []);
                _ ->
		    logger:log(debug, "Relay: Failed authentication, sending challenge"),
		    logger:log(normal, "~s: incomingproxy: Relay ~s -> 407 Proxy Authorization Required",
			       [LogTag, relay_dst2str(Dst)]),
		    transactionlayer:send_challenge(THandler, proxy, false, none)
	    end
    end.

relay_dst2str(URI) when is_record(URI, sipurl) ->
    sipurl:print(URI);
relay_dst2str(route) ->
    "according to Route header";
relay_dst2str(_) ->
    "unknown dst".

%%--------------------------------------------------------------------
%% @spec    (Request, YxaCtx, Dst, AppData) ->
%%            term() "result of local:start_sippipe/4"
%%
%%            Request = #request{}
%%            YxaCtx  = #yxa_ctx{}
%%            Dst     = [#sipdst{}] | route | #sipurl{}
%%            AppData = term() "data from this application passed to local:start_sippipe/4."
%%
%% @doc     Start a sippipe unless we are currently unit testing.
%% @end
%%--------------------------------------------------------------------
start_sippipe(Request, YxaCtx, Dst, AppData) when is_record(Request, request), is_record(YxaCtx, yxa_ctx) ->
    case autotest_util:is_unit_testing(?MODULE, testing_sippipe) of
	{true, {Res, Pid}} when is_pid(Pid) ->
	    Pid ! {start_sippipe, {Request, YxaCtx, Dst, AppData}},
	    Res;
	{true, Res} ->
	    Res;
	false ->
	    local:start_sippipe(Request, YxaCtx, Dst, AppData)
    end.


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
    ok = incomingproxy_test:test(),
    ok.

-endif.

-compile(export_all).
test_dual_add()->
    sip_virtual:add_a_x("a","x"),
    sip_virtual:bind_b("b","a"),
    #a_x_b_t{a="a",b="b",x_t={"x",?DEFAULT_TRANS}}=sip_virtual:get_by_x("x"),
    ?DB_DELETE({a_x_b_t,{"x",?DEFAULT_TRANS}}),
    sip_virtual:bind_b("b","a",?DEFAULT_TRANS,dual),
    #a_x_b_t{a="a",b="b",x_t={"x",?DEFAULT_TRANS}}=sip_virtual:get_by_x("x",?DEFAULT_TRANS,dual),
    ?DB_DELETE({a_x_b_t,{"x",?DEFAULT_TRANS}}),
    ok.

    
