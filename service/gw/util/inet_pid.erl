-module(inet_pid).
-compile(export_all).

get_udp_ports()-> get_all_ports(udp).
get_all_ports(Proto)->
    F=fun(P)->
	    Pid = proplists:get_value(connected,erlang:port_info(P)),
	    {ok,No} = inet:port(P),
	    Function = proplists:get_value(current_function,erlang:process_info(Pid)),
	    {P,Pid,No,Function} end,
    Name = name(Proto),
    [F(P) || P <- erlang:ports(), {name, Name} == erlang:port_info(P, name)].
    
get_pid(Port, Proto) when is_integer(Port), is_atom(Proto) ->
    Name = name(Proto),
    InetPorts = [P || P <- erlang:ports(), {name, Name} == erlang:port_info(P, name)],
    case port_info(InetPorts, Port) of
    {ok, P}->
        Pid = proplists:get_value(connected,erlang:port_info(P)),
        erlang:process_info(Pid);
    R-> R
    end.
 
 port_info([],_)-> not_found;
 port_info([P|Tail],Port)->
	case inet:port(P) of
	    {ok, Port} -> {ok, P};
	    _ -> port_info(Tail,Port)
	end.
     
     
 
name(tcp) -> "tcp_inet";
name(udp) -> "udp_inet";
name(sctp) -> "sctp_inet".
