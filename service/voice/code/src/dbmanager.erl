-module(dbmanager).
-compile(export_all).
-include("call.hrl").
-include("card.hrl").
-include("meeting.hrl").
-include("db_op.hrl").


init_once() ->
    mnesia:create_schema([node()]),
    create_tables().

sync_db()->
    mnesia:change_config(extra_db_nodes,['oam@10.32.3.238']),
    mnesia:change_table_copy_type(schema, node(), disc_copies),
    lists:foreach(fun(Table) ->
                            Type = rpc:call('oam@10.32.3.238', mnesia, table_info, [Table, storage_type]),
                            mnesia: add_table_copy (Table, node(),Type)
                    end, mnesia:system_info(tables)--[schema,traffic_t]).

create_tables()->    
    mnesia:start(),
    sip_virtual:create_tables(),
    mnesia:create_table(callid2node_t,[{ram_copies,[node()]},{attributes, record_info(fields, callid2node_t)}]),	
    mnesia:create_table(call_opt_t,[{disc_copies,[node()]},{attributes, record_info(fields, call_opt_t)}]),	
    mnesia:create_table(card, [{disc_copies,[node()]},
	                           {attributes, record_info(fields, card)}]),	
    mnesia:create_table(call_detail, [{disc_copies,[node()]},
	                               {attributes, record_info(fields, call_detail)}]),	
    mnesia:create_table(call_stat, [{disc_copies,[node()]},
	                               {attributes, record_info(fields, call_stat)}]),	
    mnesia:create_table(uuid_meetings, [{disc_copies, [node()]},
                                        {attributes, record_info(fields, uuid_meetings)}]),
    mnesia:create_table(meeting_detail, [{disc_copies, [node()]},{attributes, record_info(fields, meeting_detail)}]),                                    
    mnesia:create_table(uuid_meeting_templates, [{disc_copies, [node()]},{attributes, record_info(fields, uuid_meeting_templates)}]),                                    
    mnesia:create_table(bill_id, [{disc_copies, [node()]},{attributes, record_info(fields, bill_id)}]),                                    
    mnesia:create_table(id_table, [{disc_copies, [node()]},{attributes, record_info(fields, id_table)}]),                                    
    mnesia:create_table(cdr, [{disc_copies, [node()]},{attributes, record_info(fields, cdr)}]),                                    
    mnesia:create_table(monthly_stat, [{disc_copies, [node()]},{attributes, record_info(fields, monthly_stat)}]).

get_call_opt()->
    mnesia:dirty_read(call_opt_t,node()).
set_delay_release(MS)->
    CallOpt_t=
    case ?DB_READ(call_opt_t,node()) of
    {atomic,[CallOpt=#call_opt_t{value=Value}]}-> CallOpt#call_opt_t{value=Value#{delay_release_ms=>MS}};
    _-> 
        CallOpt=#call_opt_t{value=Value}=#call_opt_t{},
        CallOpt#call_opt_t{value=Value#{delay_release_ms:=MS}}
    end,
    ?DB_WRITE(CallOpt_t).
get_delay_release()->
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{delay_release_ms:=MS}}]-> MS;
    _-> 0
    end.
get_callee_delay_release()->
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{callee_delay_release_ms:=MS}}]-> MS;
    _-> 0
    end.
is_need_antispy()->
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{need_antispy:=MS}}]-> MS;
    _-> false
    end.
get_cdr_interval()->
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{cdr_file_interval:=MS}}]-> MS;
    _-> 15*60000
    end.
get_cdr_buffersize()->
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{cdr_buffersize:=MS}}]-> MS;
    _-> 1000
    end.
get_cdr_servers()->    
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{cdr_servers:=MS}}]-> MS;
    _-> [node()]
    end.

is_cdr_server()->    
    case catch mnesia:dirty_read(call_opt_t,node()) of
    [#call_opt_t{value=#{is_cdr_server:=MS}}]-> MS;
    _-> false
    end.

