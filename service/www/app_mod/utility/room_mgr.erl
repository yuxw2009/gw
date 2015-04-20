-module(room_mgr).

-compile(export_all).


%% external API.
new(Opts) ->
    Creator = proplists:get_value("uuid",Opts),
    case opr_rooms:get_opr_room(Creator) of
    undefined->
	    room_mgr() ! {new, Opts, self()},
	    receive
	        Rslt -> Rslt
	    end;
    {Rid,P}->{failed, "already_create_"++Rid++pid_to_list(P)}
    end.

delete(RoomID) ->
    room_mgr() ! {delete, RoomID}.

enter(RoomID, Tm, Opts) ->
    room_mgr() ! {enter, RoomID, {Tm, Opts}, self()},
    receive
        Rslt -> Rslt
    end.

leave(RoomID, PtID) ->
    room_mgr() ! {leave, RoomID, PtID}.

report(RoomID, PtID, PcID, Data) ->
    room_mgr() ! {report, RoomID, {PtID, PcID, Data}}.

show()->
    room_mgr() ! {show, self()},
    receive
        {show, Results}->
            Results
    after 500->
        timeout
    end.
%%%%%
room_mgr() ->
    case whereis(room_mgr) of
        undefined ->
            register(room_mgr, spawn(fun() -> room_loop0() end));
        _ -> ok
    end,
    whereis(room_mgr).

room_loop0()->
    room_mgr_loop([], id_generator:new("rm")).
    
room_mgr_loop(Rooms, RIDGenr) ->
    Fun = fun()->
	    receive
	    	{new, Opts, From} ->
	    	    NewRID = id_generator:gen(RIDGenr),
	    	    case room:create([{rid, NewRID}|Opts]) of
	                {ok, RmP} ->
	                    From ! {ok, NewRID},
	                    Rooms++[{NewRID, RmP}];
	                _ -> 
	                    From ! {failed, "create room failed."},
	                    Rooms
	            end;
	        {delete, RoomID} ->
	            case proplists:get_value(RoomID,Rooms) of
	                undefined -> ok;
	                RoomP ->
	                    room:destroy(RoomP)
	            end,
	            proplists:delete(RoomID, Rooms);
	        {enter, RoomID, {Tm, Opts}, From} ->
	            case proplists:get_value(RoomID,Rooms) of
	                undefined ->
	                    From ! {failed, room_not_existed,null};
	                RoomP ->
	                    From ! room:enter(RoomP, Tm, Opts)
	            end,
	            Rooms;
	        {leave, RoomID, PtID} ->
	            case proplists:get_value(RoomID,Rooms) of
	                undefined -> ok;
	                RoomP ->
	                    room:leave(RoomP, PtID)
	            end,
	            Rooms;
	        {report, RoomID, {PtID, PcID, Data}} ->
	            case proplists:get_value(RoomID,Rooms) of
	                undefined -> ok;
	                RoomP ->
	                    room:report(RoomP, PtID, PcID, Data)
	            end,
	            Rooms;
	        {xhr_poll_shake_timeout, Attrs}->
	            Room = proplists:get_value(room, Attrs),
	            PtId = proplists:get_value(ptId, Attrs),
	            room_mgr:leave(Room, PtId),
	            Rooms;
	        {show, From}->
	            From ! {show, Rooms},
	            Rooms
	    end
    end,
    
    NewRooms= case catch Fun() of
        {'EXIT', Reason}->
		{ok, IODev} = file:open("./log/room_error.log", [append]),
		file:close(IODev),
		Rooms;
        R->R end,
    room_mgr_loop(NewRooms, RIDGenr).
            

