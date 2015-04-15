-module(video_server).

-compile(export_all).


register_uuid(UUID, Pid) ->
    ?MODULE ! {self(), register_uuid, UUID, Pid},
    receive
    	ok -> ok
    end.

create_session(UUID1, UUID2) ->
    ?MODULE ! {self(), create_session, UUID1, UUID2},
    receive
    	ok -> ok
    end.

send_message(UUID, Message) ->
    case ets:lookup(route_tab,UUID) of
        [] -> pass;
        [{UUID,Pid}] ->
           case is_process_alive(Pid) of
           	  true ->
		            yaws_api:websocket_send(Pid, {text, Message});
		      false ->
		            pass
		   end
    end.	

hangup(Pid) ->
    io:format("hangup ~n"),
    case ets:lookup(route_tab,Pid) of
        [] -> pass;
        [{Pid,UUID}] ->

            Peer = get_peer(UUID),
            io:format("send_message to:~p ~n",[Peer]),
            send_message(Peer, rfc4627:encode(utility:pl2jso([{command, hangup},{from, UUID},{to, Peer}])))
    end. 

get_peer(UUID) ->
    case ets:lookup(session_tab, UUID) of
        [] -> pass;
        [{UUID,Peer}] -> Peer
    end. 

start() ->
   register(?MODULE,spawn(fun()-> init() end)).
 
init() ->
    ets:new(session_tab,[named_table,protected]),
	ets:new(route_tab,[named_table,protected]),
	main_loop().

main_loop() ->
    receive
    	{From, register_uuid, UUID, Pid} ->
    	    ets:insert(route_tab, {UUID, Pid}),
            ets:insert(route_tab, {Pid, UUID}),
    	    From ! ok,
    	    main_loop();
    	{From, create_session, UUID1, UUID2} ->
    	    ets:insert(session_tab, {UUID1, UUID2}),
    	    ets:insert(session_tab, {UUID2, UUID1}),
    	    From ! ok,
    	    main_loop()
    end.



	
    
