-module(recorder).
-compile(export_all).

-define(VP8, 100).

-include("desc.hrl").

-record(st,{
	name,
	vp,
	vbuf	% video frame buffer
}).

init([Name]) ->
	{ok,#st{name=Name,vp=0,vbuf=[]}}.

handle_info({leVeled_vp8,KF,_Level,EncDat}, #st{vp=VP}=ST) ->
	VH = meeting_room:packetVP8(VP,KF,0,EncDat),
	self() ! VH,
	{noreply,ST#st{vp=VP+1}};
handle_info(#audio_frame{codec=Codec}=VF,#st{vbuf=VB}=ST) when Codec==?VP8 ->
	checkVP8(VF),
	{noreply,ST#st{vbuf=[VF|VB]}};
handle_info(VFs,#st{vbuf=VB}=ST) when is_list(VFs) ->
	[checkVP8(VF)||VF<-VFs],
	{noreply,ST#st{vbuf=lists:append([lists:reverse(VFs),VB])}};
handle_info(Msg, ST) ->
	io:format("unkn ~p  ",[Msg]),
	{noreply,ST}.

handle_cast(stop,#st{name=Name,vbuf=VB}) ->
	io:format("video buffer stopped.~nget ~p frames.~n",[length(VB)]),
	saveVP8(Name,lists:reverse(VB)),
	{stop,normal,[]}.
terminate(normal, _) ->
	ok.

% ----------------------------------	

checkVP8(#audio_frame{marker=M, body=Body, samples=TC}=VF) ->
%	io:format("~p ~p ",[M,TC]),
	case Body of
		<<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8, 16#9D012A:24, Hpara:16/little,Vpara:16/little,_/binary>> ->
%			Size = Size0 + 8*Size1 + 2048*Size2,
%			io:format("~p [~p] (~px~p) ~p~n",[IDX,Size,Hpara,Vpara,P]),
			VF;
		<<16#8080:16, 1:1,IDX:15, _/binary>> ->
%			io:format("~p~n",[IDX]),
			VF;
		<<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8,_/binary>> ->
%			Size = Size0 + 8*Size1 + 2048*Size2,
%			io:format("~p [~p] ~p~n",[IDX,Size,P]),
			VF
	end.

saveVP8(Name,VB) ->
	{IDX,W,H} = getWH(hd(VB)),
	{LastIDX,OVB} = saveVP8(IDX,VB,<<>>,[]),
	NF = LastIDX-IDX,
	io:format("processed ~p frames, get ~p frames.~n",[NF, length(OVB)]),
	DKIF = <<"DKIF">>,
	VPCD = <<"VP80">>,
	FRate = 30000,
	TScale= 1000,
	IVF_HDR = <<DKIF/binary, 0:16, 32:16/little, VPCD/binary, W:16/little,H:16/little,FRate:32/little,TScale:32/little, NF:32/little, 0:32>>,
	{ok,FH} = file:open(Name++".ivf", [write,raw,binary]),
	ok = file:write(FH, IVF_HDR),
	saveIVF(FH, 0, OVB),
	file:close(FH).


	
saveVP8(IDX,[],_,R) ->
	{IDX,lists:reverse(R)};
saveVP8(IDX, [#audio_frame{marker=false,
					  body= <<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8, 16#9D012A:24, Hpara:16/little,Vpara:16/little,_/binary>> =Body,
					  samples=_TC}|T],<<>>,[]) ->
	saveVP8(IDX, T,frameOf(Body),[]);
saveVP8(IDX,[#audio_frame{marker=false,
					  body= <<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8,_Bin/binary>> =Body,
					  samples=_TC}|T],<<>>,R) ->
	saveVP8(IDX, T, frameOf(Body), R);
saveVP8(IDX,[#audio_frame{marker=false,
					  body= <<16#8080:16, 1:1,IDX:15, Bin/binary>>,
					  samples=_TC}|T],Tmp,R) ->
	saveVP8(IDX, T, <<Tmp/binary,Bin/binary>>,R);
saveVP8(IDX,[#audio_frame{marker=true,
					  body= <<16#8080:16, 1:1,IDX:15, Bin/binary>>,
					  samples=_TC}|T],Tmp,R) when Tmp=/= <<>> ->
	saveVP8(IDX+1, T, <<>>, [<<Tmp/binary,Bin/binary>>|R]);
saveVP8(IDX,[#audio_frame{marker=true,
					  body= <<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8,_/binary>> =Body,
					  samples=_TC}|T],<<>>,R) ->
	Bin = frameOf(Body),
	saveVP8(IDX+1, T, <<>>, [Bin|R]);
saveVP8(I,VF,Tmp,R) ->
	io:format("~p ~p ~p ~p~n",[I,hd(VF),Tmp,length(R)]),
	{0,[]}.

frameOf(Bin) ->
	{_,Out} = split_binary(Bin,4),
	Out.
	
getWH(#audio_frame{body= <<16#9080:16, 1:1,IDX:15, Size0:3,1:1,0:3,P:1, Size1:8,Size2:8, 16#9D012A:24, Hpara:16/little,Vpara:16/little,_/binary>>}) ->
	Size = Size0 + 8*Size1 + 2048*Size2,
	io:format("~p [~p] (~px~p) ~p~n",[IDX,Size,Hpara,Vpara,P]),
	{IDX,Hpara,Vpara}.

saveIVF(_FH, _N, []) ->
	ok;
saveIVF(FH, N, [H|T]) ->
	Size = size(H),
	F_HDR = <<Size:32/little, N:64/little>>,
	file:write(FH, [F_HDR,H]),
	saveIVF(FH,N+1,T).

% ----------------------------------	
start(Name) ->
	{ok,Pid} = my_server:start(?MODULE,[Name],[]),
	Pid.
	
stop(Pid) ->
	my_server:cast(Pid,stop).