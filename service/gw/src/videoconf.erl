-module(videoconf).
-compile(export_all).

-define(PCMU,0).
-define(CN,13).
-define(VP8, 100).

-include("desc.hrl").

-record(st, {
	name,
	parties
}).

init([Name]) ->
	{ok,#st{name=Name,parties=[]}}.

handle_info({play,RTP}, #st{parties=Prts}=ST) ->
	{noreply,ST#st{parties=[RTP|Prts]}};
handle_info(#audio_frame{codec=Codec}=VF, #st{parties=Prts}=ST) when Codec==?VP8;Codec==?CN;Codec==?PCMU ->
	Others = lists:delete(VF#audio_frame.owner,Prts),
	lists:map(fun(X)-> X!VF end,Others),
	{noreply,ST};
handle_info(#audio_frame{codec=Codec}=VF, #st{parties=Prts}=ST) when Codec==?CN;Codec==?PCMU ->
	ChairMan = hd(Prts),
	if ChairMan==VF#audio_frame.owner ->
		lists:map(fun(X)-> X!VF end,Prts);	% all member can hear me
	true -> ok end,
	{noreply,ST};
handle_info({send_sr,From,Type}, #st{parties=Prts}=ST) ->
	Others = lists:delete(From,Prts),
	lists:map(fun(X)-> X!{send_sr,self(),Type} end,Others),
	{noreply,ST};	
handle_info({send_sr,From,pli,Params}, #st{parties=Prts}=ST) ->
	Others = lists:delete(From,Prts),
	lists:map(fun(X)-> X!{send_sr,self(),pli,Params} end,Others),
	{noreply,ST};	
handle_info({stun_locked,_From},ST) ->
	{noreply,ST};
handle_info(Msg, ST) ->
	io:format("unknow ~p~n~p~n",[Msg,ST#st.parties]),
	{noreply,ST}.

handle_cast(stop,ST) ->
	io:format("video conference stopped at: ~n~p~n",[ST]),
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start({local,vc},?MODULE,[Name],[]),
	Pid.
	
stop() ->
	my_server:cast(vb,stop).