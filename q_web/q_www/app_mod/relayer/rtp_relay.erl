-module(rtp_relay).
-compile(export_all).

-include("desc.hrl").
-indlude("rtp_rtcp.hrl").

-define(DIGESTLENGTH,10).
-define(RTPHEADLENGTH,12).
-define(RTCPHEADLENGTH,8).
-define(RTCPEIDXLENGTH,4).
-define(RTCPINTERVAL,2500).
-define(RTCPSENDLIMIT,10000).

-define(PCMU,0).
-define(CN,13).
-define(iSAC,103).
-define(iCNG,105).
-define(wPHN,126).
-define(VP8,100).

-define(DEFAULTVP8TS,2880).
-define(MINVBITRATE,96000).

-define(JITTERLENGTH,32).
-define(SENTSAVELENGTH,64).
-define(PSIZE,160).
-define(MAXRTPLEN, 1222).		% for vp8 enpack

-record(st, {
	ice,
	wan_ip
}).

-record(state, {
	sess,
	socket,
	peerok = false,
	peerchecked=false,
	firstframe=true,
	peer,
	relay,
	ice_state,
	base_wall_clock,
	report_to
}).

init([Session,Socket,Options]) ->
	{Mega,Sec,_Micro} = now(),
	BaseWC = {Mega,Sec,0},
	ReportTo = proplists:get_value(report_to,Options),
	{ok,#state{sess=Session,peerok=false,socket=Socket,base_wall_clock=BaseWC,report_to=ReportTo}}.

handle_call({options,Options},_From,ST) ->
	io:format("rtp options ~p~n",[Options]),
	OM = proplists:get_value(outmedia,Options),
	STUN = proplists:get_value(stun,Options),
	{reply,ok,ST#state{relay=OM,ice_state=#st{ice=STUN}}};
handle_call({add_candidate,{IP,Port}},_From,State) ->
	io:format("candidate ~p add @ice: ~p.~n",[{IP,Port},(State#state.ice_state)#st.ice]),
	OK = if (State#state.ice_state)#st.ice==undefined -> true;
		 true -> timer:send_after(50,stun_bindreq),false
		 end,
	{reply, ok, State#state{peerok=OK,peer={IP,Port}}}.

%
%% ******** STUN ********
%
handle_info({udp,_,_,_,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},#state{ice_state=undefined}=ST) ->			% STUN
	io:format("unset stun bin: ~p.~n",[Bin]),
	{noreply,ST};
handle_info({udp,_,_,_,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},#state{ice_state=#st{ice=undefined}}=ST) ->			% STUN
	io:format("unknow/unset stun bin: ~p.~n",[Bin]),
	{noreply,ST};
handle_info({udp,Socket,Addr,Port,<<0:7,_:1,_:8,_Len:14,0:2,_/binary>> =Bin},#state{sess=Sess,ice_state=ICE,peerchecked=Peerchecked,relay=Relay,firstframe=Firstframe}=ST) ->			% STUN
	case stun:handle_msg({udp_receive,Addr,Port,Bin},ICE) of
		{ok,{request,Response},NewICE} ->
		      if Sess == "offer", not Peerchecked ->  not_send_stun_respons;
		          true-> 	
		              if Firstframe-> llog("session ~p send stun response~n", [Sess]); true-> void end,
		              send_udp(Socket,Addr,Port,Response)
		      end,
			{noreply,ST#state{ice_state=NewICE,peer=NewICE#st.wan_ip}};
		{ok,response,NewICE} ->
			if not ST#state.peerok ->
				llog("report_to ~p",[ST#state.report_to]),
				rtp_report(ST#state.report_to,Sess,{stun_locked,self()}),
				send_media(ST#state.relay,{stun_locked,self()}),
				llog("peer_ip_looked ~p",[NewICE#st.wan_ip]),
				{noreply,ST#state{peerok=true,peer=NewICE#st.wan_ip,ice_state=NewICE}};
			true -> {noreply,ST} end;
		_ -> {noreply, ST}
	end;
handle_info(stun_bindreq,#state{socket=Socket,peer={Addr,Port},ice_state=ICE}=ST) ->
	{ok,{request,Request},_} = stun:handle_msg(bindreq,ICE),
	case ICE#st.wan_ip of
		undefined ->
			send_udp(Socket,Addr,Port,Request);
		{WAddr,WPort} ->
			send_udp(Socket,WAddr,WPort,Request)
	end,
	timer:send_after(500,stun_bindreq),
	{noreply,ST};

%
% ******** DTLS *******
%
handle_info({udp, _Socket, Addr, Port, <<0:2,_:1,1:1,_:1,1:1,_:2,_/binary>>},ST) ->
	io:format("DTLS message from~p ~p.~n",[Addr,Port]),
	{noreply,ST};

%
%% ******** RTP/RTCP MEDIA RECEIVE ********
%
handle_info({udp,S,A,P,Bin},#state{relay=Relay,firstframe=IsFirst, sess=Sess}=ST) ->
      if IsFirst-> 
          timer:send_after(2000,Relay, peerchecked),
          llog("session ~p rcv first frame: ~p~n", [Sess, Bin]); 
      true-> void end,
	Relay ! {udp_packet,Bin,self()},
	{noreply,ST#state{firstframe=false}};
handle_info({udp_packet,Bin,_From},#state{socket=Socket,peer={IP,Port}}=ST) ->
	gen_udp:send(Socket,IP,Port,Bin),
	{noreply,ST};
%
handle_info(peerchecked,ST) ->
	{noreply,ST#state{peerchecked=true}};
handle_info(Msg,ST) ->
	io:format("rtp unknow_msg ~p~n",[Msg]),
	{noreply,ST}.

%
% ******** socket closed *******
%
handle_cast(stop,#state{relay=Media}=ST) ->
	io:format("rtp ~p stopped.~n",[self()]),
%	Media ! {deplay,self()},
	{stop,normal,[]}.
terminate(normal,_) ->
	ok.

%

%
% ----------------------------------
%
start_relay_pair({Session,Session2},Options,{BEGIN_UDP_RANGE,END_UDP_RANGE}) ->
	case try_port(BEGIN_UDP_RANGE,END_UDP_RANGE) of
		{ok,Port,Socket} ->
			case try_port(Port+1,END_UDP_RANGE) of
				{ok,Port2,Socket2} ->
					{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Options],[]),
					gen_udp:controlling_process(Socket, Pid),
					{ok,Pid2} = my_server:start(?MODULE,[Session2,Socket2,Options],[]),
					gen_udp:controlling_process(Socket2, Pid2),
					{ok,Port,Port2,Pid,Pid2};
				{error,Reason} ->
					gen_udp:close(Socket),
					{error,Reason}
			end;
		{error, Reason} ->
			{error,Reason}
	end.

start_within(Session,Options,{BEGIN_UDP_RANGE,END_UDP_RANGE}) ->
	case try_port(BEGIN_UDP_RANGE,END_UDP_RANGE) of
		{ok,Port,Socket} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Options],[]),
			gen_udp:controlling_process(Socket, Pid),
			{ok,Port,Pid};
		{error, Reason} ->
			{error,Reason}
	end.

start(Session,Options) ->
	{WEB_BEGIN_UDP_RANGE,WEB_END_UDP_RANGE} = avscfg:get(web_udp_range),
	case try_port(WEB_BEGIN_UDP_RANGE,WEB_END_UDP_RANGE) of
		{ok,Port,Socket} ->
			{ok,Pid} = my_server:start(?MODULE,[Session,Socket,Options],[]),
			gen_udp:controlling_process(Socket, Pid),
			{ok,Pid,Port};
		{error, Reason} ->
			{error,Reason}
	end.
	
stop(RTP) ->
	my_server:cast(RTP,stop).
info(Pid,Info) ->
	my_server:call(Pid,Info).
rtp_report(To,Sess,Cmd) ->
	my_server:call(To,{rtp_report,Sess,Cmd}).
	
try_port(Port,END_UDP_RANGE) when Port > END_UDP_RANGE ->
	{error,udp_over_range};
try_port(Port,END_UDP_RANGE) ->
	case gen_udp:open(Port, [binary, {active, true}, {recbuf, 8192}]) of
		{ok, Socket} ->
			{ok,Port,Socket};
		{error, _} ->
			try_port(Port + 1,END_UDP_RANGE)
	end.
	
send_udp(Socket, Addr, Port, RTPs) ->
  F = fun(P) ->
          gen_udp:send(Socket, Addr, Port, P)
      end,
  send_rtp(F, RTPs).

send_rtp(F, RTP) when is_binary(RTP) ->
  F(RTP);
send_rtp(F, RTPs) when is_list(RTPs) ->
  [begin
     if is_list(R) ->
         [F(Rr) || Rr <- R];
        true ->
         F(R)
     end
   end || R <- RTPs].

send_media(OM, Frame) when is_pid(OM),is_record(Frame,audio_frame) ->
	if Frame#audio_frame.body== <<>> -> pass;
	true -> OM ! Frame#audio_frame{owner=self()}
	end;
send_media(OM, SR) when is_pid(OM) ->
	OM ! SR;
send_media(undefined,_) ->
	ok.

llog(F,P) ->
	case whereis(llog) of
		undefined -> io:format(F++"~n",P);
		Pid when is_pid(Pid) -> llog ! {self(), F, P}
	end.