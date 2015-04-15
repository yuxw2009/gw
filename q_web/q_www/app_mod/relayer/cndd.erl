-module(cndd).
-compile(export_all).

-include("sdp.hrl").
-define(LSEP, <<$\r,$\n>>).

encode(Candid) ->
	Component = integer_to_list(Candid#cdd.compon),
	Foundation = integer_to_list(Candid#cdd.founda),
	Priority = integer_to_list(Candid#cdd.priori),
	Proto = atom_to_list(Candid#cdd.proto),
	IP = iolist_to_binary([Candid#cdd.addr,$ ,integer_to_list(Candid#cdd.port)]),
	Type = iolist_to_binary(["typ ",Candid#cdd.typ]),
	Gnrtn = iolist_to_binary(["generation ",integer_to_list(Candid#cdd.genera)]),
	iolist_to_binary(["a=candidate:",Foundation,$ ,Component,$ ,Proto,$ ,Priority,$ ,IP,$ ,Type,$ ,Gnrtn,?LSEP]).
	
decode(Bin) ->
	{ok, Re} = re:compile("a=candidate:(\\d+) (\\d) udp (\\d+) ([^$]+) (\\d+) typ host generation 0"),
	case re:run(binary_to_list(Bin), Re, [{capture, all, list}]) of
		{match, [_,Foundation,Component,Priority,Addr,Port]} ->
			#cdd{compon = list_to_integer(Component),
		 		founda = list_to_integer(Foundation),
		 		priori = list_to_integer(Priority),
		 		proto = udp,
		 		addr = Addr,
		 		port = list_to_integer(Port)};
		 _ ->
		 	#cdd{}
	end.

get(ipp,#cdd{addr=A,port=P}) -> {A,P};
get(founda,#cdd{founda = F}) -> F;
get(priori,#cdd{priori = P}) -> P;
get(compon,#cdd{compon = C}) -> C.

repl(ipp,{A,P},C1) -> C1#cdd{addr=A,port=P};
repl(founda,F,C1) -> C1#cdd{founda=F};
repl(priori,P,C1) -> C1#cdd{priori=P};
repl(compon,C,C1) -> C1#cdd{compon=C}.

test() ->
	Candid = <<"a=candidate:2814167122 1 udp 2130714367 10.60.108.150 65266 typ host generation 0\r\n">>,
	Cndd = decode(Candid),
	Bin = encode(Cndd),
	Candid = Bin,
	{Cndd#cdd.addr,Cndd#cdd.port}.