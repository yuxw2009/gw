-module(room_handler).
-compile(export_all).

handle_room(<<"create_room">>, Params)->
%    Room=get_string("room",Params),
    case room_mgr:new(Params) of
    {ok, RId}-> utility:pl2jso([{status,ok}, {room, list_to_atom(RId)}]);
    {failed,Reason}-> utility:pl2jso([{status,failed}, {reason, list_to_atom(Reason)}])
    end;

handle_room(<<"enter_room">>, Params)->
    room:log("room_handler: enter_room ~p Params:~p", [self(),Params]),
    Room=get_string("room", Params),
    UUID = proplists:get_value("uuid", Params),
    IsCreator = proplists:get_value("is_creator", Params),

   BA=xhr_poll:start([{report_to,room_mgr:room_mgr()}]),
   Reg_fun=fun(PtId)->
       Rdm = integer_to_list((fun()->{_,_,N}=erlang:now(), N div 1000 end)()),
       Clt_chanPid = list_to_atom(Room++"_"++PtId++"_"++Rdm),
        register(Clt_chanPid, BA),
        xhr_poll:attrs(BA, [{ptId, PtId}, {room,Room}, {uuid, UUID},{is_creator, IsCreator},{name,Clt_chanPid}]),
        Clt_chanPid
    end,   
   case room_mgr:enter(Room, BA,[{role,peer}|Params]) of
   {ok, PtId}->
       utility:pl2jso([{status,ok}, {room,list_to_atom(Room)}, {ptId, list_to_atom(PtId)}, {chanId, Reg_fun(PtId)}]);
   {waiting,PtId}->
       utility:pl2jso([{status,ok}, {room,list_to_atom(Room)}, {ptId, list_to_atom(PtId)}, {chanId, Reg_fun(PtId)}, {waiting, true}]);
   {failed,Reason,Info}->
       xhr_poll:stop(BA),
       utility:pl2jso([{status,failed}, {reason,Reason},{info,Info}])
   end;

handle_room(<<"delete_room">>, Params)->
    Room=get_string("room", Params),
    room_mgr:delete(Room),

   utility:pl2jso([{status,ok}, {room,list_to_atom(Room)}, {evt, delete_room}]);
handle_room(<<"leave_room">>, Params)->
    Room=get_string("room", Params),
    PtId = get_string("ptId",Params),
    room_mgr:leave(Room, PtId),

   utility:pl2jso([{status,ok}, {room,list_to_atom(Room)}, {ptId, list_to_atom(PtId)}]);

handle_room(<<"peer_candidate">>, Params)->
    Room = get_string("room",Params),
    PtId = get_string("ptId",Params),
    PcId = get_string("pcId",Params),
%    Cdd = proplists:get_value("candidate",Params),
    room_mgr:report(Room, PtId, PcId, {candidate,Params}),
    utility:pl2jso([{status,ok}]);
handle_room(<<"report">>, Params)->
    Room = get_string("room",Params),
    PtId = get_string("ptId",Params),
    PcId = get_string("pcId",Params),
    Type = list_to_atom(get_string("type",Params)),
    Data =proplists:get_value("data", Params),
%    Cdd = proplists:get_value("candidate",Params),
    room_mgr:report(Room, PtId, PcId, {Type,Data}),
    utility:pl2jso([{status,ok}]);
handle_room(<<"get_opr_rooms">>, Params)->
    UUIDS = proplists:get_value("uuids",Params),
    Uuid_rooms = opr_rooms:get_all(),
    Opr_rooms = opr_rooms:get_all_opr_rooms(),
    Fun=fun({U,{RNo, RPid}})->
            [{uuid,U},{room,list_to_binary(RNo)} | room:get_room_info(RPid)]  end,
    Infos=
        if UUIDS== [<<"all">>] ->
            [Fun(T) ||T<-Opr_rooms];
        true->
            [Fun(T) ||T={U,{_, _}}<-Uuid_rooms, U1<-UUIDS, U==U1]
        end,
    utility:pl2jso([{status,ok}, {infos, [utility:pl2jso(Info) || Info<-Infos]}]);
handle_room(_Event, _Params)->
    utility:pl2jso([{status,failed},{reason,unhandled}]).


get_string(Key, CmdList)->
    case proplists:get_value(Key, CmdList) of
    undefined-> "";
    Bin->   binary_to_list(Bin)
    end.
    
