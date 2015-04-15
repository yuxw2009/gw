-module(ice_lite).
-compile(export_all).

-define(STUNPORT,19303).

-include("stun.hrl").

-record(st,{
	socket
}).

init([Socket]) ->
	{ok,#st{socket=Socket}}.

handle_info({udp,Socket,A,P,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin}, #st{socket=Socket}=ST) ->
	case stun_codec:decode(Bin) of
		{ok, Msg, <<>>} ->
			case stun:process(v1,A,P,Msg) of
				RespMsg when is_record(RespMsg, stun) ->
					llog("ice address request from ~p ~p",[A,P]),
					Data1 = stun_codec:encode(RespMsg),
					gen_udp:send(Socket,A,P,Data1),
					ok;
				response ->
					llog("why is response. from ~p ~p",[A,P]),
					pass;
				_ ->
					pass
			end;
		_ -> pass
	end,
	{noreply,ST};
handle_info({udp,_,A,P,Bin}, ST) ->
	llog("stun unknow udp ~p~nfrom ~p~p",[Bin,A,P]),
	{noreply,ST};
handle_info(Msg, ST) ->
	llog("stun unknow msg ~p",[Msg]),
	{noreply,ST}.

handle_cast(stop,#st{socket=Socket}) ->
	gen_udp:close(Socket),
	{stop,normal}.
terminate(_,_) ->
	ok.

% ----------------------------------
llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.

start() ->
	{ok, Socket} = gen_udp:open(?STUNPORT, [binary, {active, true}, {recbuf, 1024}]),
	{ok,Pid} = my_server:start({local,ice},?MODULE,[Socket],[]),
	gen_udp:controlling_process(Socket, Pid),
	{ok,Socket,Pid}.

stop() ->
	my_server:cast(ice,stop).

% ----------------------------------
test(FName) ->
	Bin = r2b:do("./rtcp_vector/"++FName),
	{ok,Msg,<<>>} = stun_codec:decode(Bin),
	stun:process(v1,"10.60.108.147", 55000, Msg).