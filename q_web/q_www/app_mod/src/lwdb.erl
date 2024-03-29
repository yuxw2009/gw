-module(lwdb).
-compile(export_all).
-include("lwdb.hrl").
-include("login_info.hrl").

do_this_once() ->
    mnesia:start(),
    mnesia:create_table(recharge_authcode,[{attributes,record_info(fields,recharge_authcode)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)},{disc_copies,[node()]}]),
    mnesia:create_table(id_table, [{disc_copies, [node()]},{attributes, record_info(fields, id_table)}]),                                    
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
    mnesia:create_table(login_itm,[{attributes,record_info(fields,login_itm)}]),
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
