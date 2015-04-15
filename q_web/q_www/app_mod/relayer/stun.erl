-module(stun).

-export([handle_msg/2,test/1,process/4]).

-include("stun.hrl").

-record(st, {
	ice,
	wan_ip
}).

%%====================================================================
%% API
%%====================================================================
handle_msg({udp_receive,Addr,Port,Bin},#st{ice={_,"1",{ice,LUf,_},{ice,RUf,_}}}=ST) ->
	case stun_codec:decode(Bin) of
		{ok, Msg, <<>>} ->
			case process(v1,Addr, Port, Msg) of
				RespMsg when is_record(RespMsg, stun) ->
					case is_authuser(usernameV1(LUf,RUf), Msg) of
						true ->
							Data1 = stun_codec:encode(RespMsg),
							{ok,{request,Data1},ST#st{wan_ip={Addr,Port}}};
						false ->
							auth_failure
					end;
				response ->
					{ok,response,ST#st{wan_ip={Addr,Port}}};
				_ ->
					pass
			end;
		_ ->
			pass
    end;    
handle_msg({udp_receive,Addr,Port,Bin},#st{ice={_,"2",{ice,LUf,LPwd},{ice,RUf,_RPwd}}}=ST) ->
	case stun_codec:decodeV2(LPwd,Bin) of
		{ok, Msg, <<>>} ->
			case process(v2,Addr, Port, Msg) of
				RespMsg when is_record(RespMsg, stun) ->
%					io:format("~p~n~p~n",[Msg,RespMsg]),
					case is_authuser(usernameV2(LUf,RUf), Msg) of
						true ->
							Data1 = stun_codec:encodeV2(LPwd,RespMsg),
							{ok,{request,Data1},ST#st{wan_ip={Addr,Port}}};
						false ->
							auth_failure
					end;
				response ->
					{ok,response,ST#st{wan_ip={Addr,Port}}};
				_ ->
					pass
			end;
		_ ->
			pass
    end;
    
handle_msg(bindreq, #st{ice={_,"1",{ice,LUf,_},{ice,RUf,_}}}=ST) ->
    Data1 = stun_codec:encode(#stun{class = request,
    								method = ?STUN_METHOD_BINDING,
    								trid = random:uniform(1 bsl 96),
    								'USERNAME' = list_to_binary(RUf++LUf)}),
    {ok,{request,Data1},ST};
handle_msg(bindreq, #st{ice={controlling,"2",{ice,LUf,_LPwd},{ice,RUf,RPwd}}}=ST) ->
	Common = prepare_V2req(),
	STUN = Common#stun{'USERNAME' = list_to_binary(RUf++":"++LUf),
    				   'ICE-CONTROLLING' = <<"12345678">>,
    				   'USER-CANDIDATE' = <<>>},
    Data1 = stun_codec:encodeV2(RPwd,STUN),
    {ok,{request,Data1},ST};
handle_msg(bindreq, #st{ice={controlled,"2",{ice,LUf,_LPwd},{ice,RUf,RPwd}}}=ST) ->
	Common = prepare_V2req(),
	STUN = Common#stun{'USERNAME' = list_to_binary(RUf++":"++LUf),
    				   'ICE-CONTROLLED' = <<"87654321">>},
    Data1 = stun_codec:encodeV2(RPwd,STUN),
    {ok,{request,Data1},ST}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
process(v1,Addr, Port, #stun{class = request, unsupported = []} = Msg) ->
    Resp = prepare_response(Msg),
    if Msg#stun.method == ?STUN_METHOD_BINDING ->
		Resp#stun{class = response,'MAPPED-ADDRESS' = {Addr, Port}};
    true ->
	    Resp#stun{class = error,
		      'ERROR-CODE' = {405, <<"Method Not Allowed">>}}
    end;
process(v2,Addr, Port, #stun{class = request, unsupported = []}=Msg) ->
	Head = prepare_head(Msg),
    Resp = Head#stun{'MESSAGE-INTEGRITY' = true,
			  'FINGERPRINT' = true},
    if Msg#stun.method == ?STUN_METHOD_BINDING ->
		Resp#stun{class = response,'XOR-MAPPED-ADDRESS' = {Addr, Port}};
    true ->
	    Resp#stun{class = error,
		      'ERROR-CODE' = {405, <<"Method Not Allowed">>}}
    end;
process(_,_Addr, _Port, #stun{class = request} = Msg) ->
    Resp = prepare_response(Msg),
    Resp#stun{class = error,
	      'UNKNOWN-ATTRIBUTES' = Msg#stun.unsupported,
	      'ERROR-CODE' = {420, stun_codec:reason(420)}};
process(_,_Addr, _Port, #stun{class = response}) ->
	response;
process(_,_Addr, _Port, #stun{class = error}) ->
	pass;
process(_,_Addr, _Port, _Msg) ->
    pass.

prepare_head(Msg) ->
    #stun{method = Msg#stun.method,
	  magic = Msg#stun.magic,
	  trid = Msg#stun.trid}.

prepare_response(Msg) ->
	Head = prepare_head(Msg),
    Head#stun{'USERNAME' = Msg#stun.'USERNAME'}.

prepare_V2req() ->
    #stun{class = request,
      method = ?STUN_METHOD_BINDING,
      trid = random:uniform(1 bsl 96),
      'PRIORITY' = <<16#7E001EFF:32>>,
      'MESSAGE-INTEGRITY' = true,
      'FINGERPRINT' = true}.
      
is_authuser(AuthUN, #stun{'USERNAME'=AuthUN}=Msg) ->
	if
		Msg#stun.'MESSAGE-INTEGRITY'==undefined andalso Msg#stun.'FINGERPRINT'== undefined -> true;
		Msg#stun.'MESSAGE-INTEGRITY'==true andalso Msg#stun.'FINGERPRINT'== true -> true;
		true -> false
	end;
is_authuser(_UN, _) -> false.

usernameV1(LUf,RUf) -> list_to_binary(LUf++RUf).
usernameV2(LUf,RUf) -> list_to_binary(LUf++":"++RUf).

%% *********************************
% test functions
test(v1) ->
	LUf = "Qfn3PDB5fjNFA6o1",
	RUf = "CbR9biGVKO4/KQGR",
	ST = #st{ice={default,"1",{ice,LUf,<<>>},{ice,RUf,<<>>}}},
	Bin = r2b:do("stunv1.dat"),
	R = handle_msg({udp_receive,{10,61,34,50},55000,Bin},ST),
	{ok,{request,Req},#st{wan_ip={_,55000}}} = R,
	io:format("pass~n~p~n",[Req]);

test(v2) ->
	LUf = "evtj",
	RUf = "h6vY",
	ST = #st{ice={controlling,"2",{ice,LUf,<<"jAVU/LKkNCcjk3qykb8UQTnW">>},{ice,RUf,<<"VOkJxbRl1RmTxUk/WvJxBt">>}}},
	Bin = r2b:do("stunv2.dat"),
	R = handle_msg({udp_receive,{10,60,108,148},56125,Bin},ST),
	io:format("~p~n",[R]),
	{ok,{request,Req},#st{wan_ip={_,56125}}} = R,
	io:format("testpass~n~p~n",[Req]);

test(v22) ->
	LUf = "8lT+t+bypjqjoItJ",
	RUf = "2Y+mzBLV6X3Fftk5",
	ST = #st{ice={controlling,"2",{ice,LUf,<<"jAVU/LKkNCcjk3qykb8UQTnW">>},{ice,RUf,<<"WCMBvYhpq7k5ETVdd45VSP9S">>}}},
	Bin = r2b:do("stunv22.dat"),
	R = handle_msg({udp_receive,{10,60,108,141},65054,Bin},ST),
	io:format("~p~n",[R]),
	{ok,{request,Req},#st{wan_ip={_,65054}}} = R,
%	Req = <<1,1,0,44,33,18,164,66,66,67,74,79,75,115,74,105,51,83,108,76,0,32,0,8,0,1,  223,12,43,46,200,207,0,8,0,20,88,142,96,77,95,94,56,178,200,81,199,157,76,  176,72,103,241,123,60,202,128,40,0,4,90,72,212,67>>.
	io:format("testpass~n~p~n",[Req]);

test(v23) ->
	ST = {st,{controlled,"2",
              {ice,"DJ7niVqN0mSu7Y/Y","cTw830KuJ2G/e32fIbzd5dCs"},
              {ice,"WRLJjg7MCdtsOaC2","d50LzTX9Ld3PD9eZWzbv9ug+"}},
             undefined},
	Bin = r2b:do("stunv23.dat"),
	R = handle_msg({udp_receive,{10,60,108,146},60372,Bin},ST),
	io:format("~p~n",[R]),
	{ok,{request,Req},#st{wan_ip={_,60372}}} = R,
	io:format("testpass~n~p~n",[Req]);
	
test(v24) ->
    ST = {st,{controlled,"2",
              {ice,"DJ7niVqN0mSu7Y/Y","cTw830KuJ2G/e32fIbzd5dCs"},
              {ice,"hu3kom0yDP0QT5bS","+C5AYfI+xd1IvadFRMEFb8Jz"}},
             undefined},
	Bin = r2b:do("stunv24.dat"),
	R = handle_msg({udp_receive,{10,60,108,146},56271,Bin},ST),
	io:format("~p~n",[R]),
	{ok,{request,Req},#st{wan_ip={_,56271}}} = R,
	io:format("testpass~n~p~n",[Req]);

test(v25) ->
    ST = {st,{controlled,"2",
              {ice,"Ca3fBCvEOQFV3ren","6YJlYeY//WRif/XZGsHiToiw"},
              {ice,"DJ7niVqN0mSu7Y/Y","cTw830KuJ2G/e32fIbzd5dCs"}},
             undefined},
    Bin = r2b:do("stunv25.dat"),
	R = handle_msg({udp_receive,{10,61,34,50},55000,Bin},ST),
	io:format("~p~n",[R]),
	{ok,{request,Req},#st{wan_ip={_,55000}}} = R,
	io:format("testpass~n~p~n",[Req]);
	
test(v2r) ->
	LUf = "2Y+mzBLV6X3Fftk5",
	RUf = "8lT+t+bypjqjoItJ",
	R = handle_msg(bindreq, #st{ice={controlled,"2",{ice,LUf,<<"jAVU/LKkNCcjk3qykb8UQTnW">>},{ice,RUf,<<>>}}}),
	io:format("~p~n",[R]),
	{ok, {request,Dat},_ST} = R,
	Dat.