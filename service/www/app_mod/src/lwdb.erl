-module(lwdb).
-compile(export_all).
-include("lwdb.hrl").

do_this_once() ->
    mnesia:start(),
    create_mail_t(),
    mnesia:create_table(openim_t,[{attributes,record_info(fields,openim_t)},{disc_copies,[node()]}]),
    mnesia:create_table(devid_reg_t,[{attributes,record_info(fields,devid_reg_t)},{disc_copies,[node()]}]),
    mnesia:create_table(pay_types_record,[{attributes,record_info(fields,pay_types_record)},{disc_copies,[node()]}]),
    mnesia:create_table(third_reg_t,[{attributes,record_info(fields,third_reg_t)},{disc_copies,[node()]}]),
    mnesia:create_table(pay_record,[{attributes,record_info(fields,pay_record)},{disc_copies,[node()]}]),
    mnesia:create_table(id_table, [{disc_copies, [node()]},{attributes, record_info(fields, id_table)}]),                                    
    mnesia:create_table(name2uuid,[{attributes,record_info(fields,name2uuid)},{disc_copies,[node()]}]),
    mnesia:create_table(agent_oss_item,[{attributes,record_info(fields,agent_oss_item)},{disc_copies,[node()]}]),
    mnesia:create_table(agent_did2sip,[{attributes,record_info(fields,agent_did2sip)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)},{disc_copies,[node()]}]),
    ok.

transform_table()->
    F=fun(Mail_t={mail_t,Account,Mail_infos,Uuid,Pls,Max_uid})-> 
                 #mail_t{account=Account,mail_infos=Mail_infos,uuid=Uuid,pls=Pls}
            end,
    mnesia:transform_table(mail_t,F,record_info(fields,mail_t)).

test()->mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)},{disc_copies,[node()]}]).
create_mail_t()->
    mnesia:create_table(mail_t0,[{attributes,record_info(fields,mail_t0)},{disc_copies,[node()]}]).

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
    [lw_register,agent_did2sip,name2uuid,agent_oss_item,pay_record,id_table,third_reg_t,devid_reg_t,pay_types_record].
ram_tables()->
    [login_itm,wcg_queue].
delete_tables()->
    [mnesia:delete_table(I)||I<-tables()].
