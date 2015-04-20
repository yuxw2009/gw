-module(lwdb).
-compile(export_all).
-include("lwdb.hrl").

do_this_once() ->
    mnesia:start(),
    mnesia:create_table(pay_record,[{attributes,record_info(fields,pay_record)},{disc_copies,[node()]}]),
    mnesia:create_table(id_table, [{disc_copies, [node()]},{attributes, record_info(fields, id_table)}]),                                    
    mnesia:create_table(name2uuid,[{attributes,record_info(fields,name2uuid)},{disc_copies,[node()]}]),
    mnesia:create_table(agent_oss_item,[{attributes,record_info(fields,agent_oss_item)},{disc_copies,[node()]}]),
    mnesia:create_table(agent_did2sip,[{attributes,record_info(fields,agent_did2sip)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)},{disc_copies,[node()]}]),
    ok.

test()->mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)},{disc_copies,[node()]}]).


start() ->
    mnesia:start(),
    Tables = mnesia:system_info(tables),
    case lists:member(schema, Tables) of
    	true -> pass;
    	false ->
    	    mnesia:stop(),
            mnesia:create_schema([node()]),
            mnesia:start()
    end,

    case mnesia:system_info(tables) of
        [schema] -> 
            mnesia:stop(),
            do_this_once(),
            wcg_disp:create_tables(),
            opr_rooms:create_tables(),
            mnesia:start();
        _  -> 
            ok
    end,
    mnesia:wait_for_tables(tables(),20000),
    ok.

stop() ->
    mnesia:stop().
    
tables()-> ram_tables()++disc_tables().    
disc_tables()->
    [lw_register,agent_did2sip,name2uuid,agent_oss_item,pay_record].
ram_tables()->
    [login_itm].
delete_tables()->
    [mnesia:delete_table(I)||I<-tables()].
