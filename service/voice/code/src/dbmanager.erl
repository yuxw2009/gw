-module(dbmanager).
-compile(export_all).
-include("call.hrl").
-include("card.hrl").
-include("meeting.hrl").


init_once() ->
    mnesia:create_schema([node()]),
    create_tables().

create_tables()->    
    mnesia:start(),
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

