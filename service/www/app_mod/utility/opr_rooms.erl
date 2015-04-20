-module(opr_rooms).
-compile(export_all).

-record(opr_rooms,  {uuid, room}).   %% room:{Rid,RPid}    rooms opr created
-record(enter_rooms,  {uuid, room}).   %% room:{Rid,RPid}  all user entering room

start()-> init_db().

create_tables() ->
    mnesia:create_table(enter_rooms,[{attributes,record_info(fields,enter_rooms)}]),
    mnesia:create_table(opr_rooms,[{attributes,record_info(fields,opr_rooms)}]).

init_once() ->
    mnesia:create_schema([node()]),
    init_db().
init_db() ->
    mnesia:start(),
    create_tables().

add(UUID, Room) ->
    F = fun() ->
    	    case mnesia:read(enter_rooms, UUID) of
	    	[_Item]  -> 
	    	    mnesia:delete({enter_rooms, UUID});
	    	_-> void
	     end,
	    mnesia:write(#enter_rooms{uuid=UUID, room=Room})
        end,
    mnesia:activity(transaction, F).    
    
add_opr_room(UUID, Room) ->
    F = fun() ->
    	    case mnesia:read(opr_rooms, UUID) of
	    	[_Item]  -> 
	    	    mnesia:delete({opr_rooms, UUID});
	    	_-> void
	     end,
	    mnesia:write(#opr_rooms{uuid=UUID, room=Room})
        end,
    mnesia:activity(transaction, F).    

remove(UUID) ->
    F = fun() ->
    	    mnesia:delete({enter_rooms, UUID})
        end,
    mnesia:activity(transaction, F).    

remove_opr_room(UUID) ->
    F = fun() ->
    	    mnesia:delete({opr_rooms, UUID})
        end,
    mnesia:activity(transaction, F).    

get(UUID) ->
    F = fun() ->
    	    case mnesia:read(enter_rooms, UUID) of
    	    [#enter_rooms{uuid=_,room=R}]->   R;
    	    _-> undefined
        end end,
    mnesia:activity(transaction, F).    

get_opr_room(UUID) ->
    F = fun() ->
    	    case mnesia:read(opr_rooms, UUID) of
    	    [#opr_rooms{uuid=_,room=R}]->   R;
    	    _-> undefined
        end end,
    mnesia:activity(transaction, F).    


get_all() ->
    F = fun() ->
    	    AK = mnesia:all_keys(enter_rooms),
    	    G  = fun(K) -> 
    	    	     [#enter_rooms{uuid=U,room=R}] = mnesia:read(enter_rooms, K), 
                     {U,R}
    	         end,
    	    [G(K) || K <- AK]
    	end,
    mnesia:activity(transaction, F).

get_all_opr_rooms() ->
    F = fun() ->
    	    AK = mnesia:all_keys(opr_rooms),
    	    G  = fun(K) -> 
    	    	     [#opr_rooms{uuid=U,room=R}] = mnesia:read(opr_rooms, K), 
                     {U,R}
    	         end,
    	    [G(K) || K <- AK]
    	end,
    mnesia:activity(transaction, F).

