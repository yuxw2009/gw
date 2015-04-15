-module(lw_server).
-compile(export_all).
-include("lw.hrl").

do_this_once() ->
    mnesia:create_schema([node()]),
    mnesia:start(),

    mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)}]),
    mnesia:create_table(lw_verse_register,[{attributes,record_info(fields,lw_verse_register)}]),

    mnesia:create_table(lw_auth,[{attributes,record_info(fields,lw_auth)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_instance,[{attributes,record_info(fields,lw_instance)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_instance_del,[{attributes,record_info(fields,lw_instance_del)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_group,[{attributes,record_info(fields,lw_group)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_group,[{attributes,record_info(fields,lw_verse_group)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_msg_queue,[{attributes,record_info(fields,lw_msg_queue)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_id_creater,[{attributes,record_info(fields,lw_id_creater)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_task,[{attributes,record_info(fields,lw_task)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_task,[{attributes,record_info(fields,lw_verse_task)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_unread,[{attributes,record_info(fields,lw_unread)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_topic,[{attributes,record_info(fields,lw_topic)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_topic,[{attributes,record_info(fields,lw_verse_topic)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_polls,[{attributes,record_info(fields,lw_polls)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_polls,[{attributes,record_info(fields,lw_verse_polls)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_news,[{attributes,record_info(fields,lw_news)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_document,[{attributes,record_info(fields,lw_document)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_document,[{attributes,record_info(fields,lw_verse_document)},{disc_copies,[node()]}]),
    
    mnesia:create_table(lw_question,[{attributes,record_info(fields,lw_question)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_indexer,[{attributes,record_info(fields,lw_indexer)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_sponsor,[{attributes,record_info(fields,lw_sponsor)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_org,[{index,[mark_name]},{attributes,record_info(fields,lw_org)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_department,[{attributes,record_info(fields,lw_department)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_focus,[{attributes,record_info(fields,lw_focus)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_dustbin,[{attributes,record_info(fields,lw_dustbin)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_meeting,[{attributes,record_info(fields,lw_meeting)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_sms,[{attributes,record_info(fields,lw_sms)},{disc_copies,[node()]}]),
    
    mnesia:create_table(lw_audit,[{attributes,record_info(fields,lw_audit)},{disc_copies,[node()]},{type, ordered_set}]),
    mnesia:create_table(lw_audit_verse,[{attributes,record_info(fields,lw_audit_verse)},{disc_copies,[node()]}]),
    
    mnesia:create_table(lw_external_partner,[{attributes,record_info(fields,lw_external_partner)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_bbscat,[{attributes,record_info(fields,lw_bbscat)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_bbsnote,[{attributes,record_info(fields,lw_bbsnote)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_bbs_verse_note,[{attributes,record_info(fields,lw_bbs_verse_note)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_salary,[{attributes,record_info(fields,lw_salary)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_salary_pwd,[{attributes,record_info(fields,lw_salary_pwd)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_salary_public,[{attributes,record_info(fields,lw_salary_public)},{disc_copies,[node()]}]),

    mnesia:create_table(lw_org_attr,[{attributes,record_info(fields,lw_org_attr)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_org_meeting,[{attributes,record_info(fields,lw_org_meeting)},{disc_copies,[node()]}]),

    mnesia:stop().

start() ->
    mnesia:start(),
    case mnesia:system_info(tables) of
        [schema] -> 
            mnesia:stop(),
            do_this_once(),
            mnesia:start();
        _  -> 
            ok
    end,
    mnesia:wait_for_tables([lw_register,
    						lw_verse_register,
    						lw_auth,
    						lw_instance,
                            lw_instance_del,
    						lw_group,
    						lw_verse_group,
    						lw_msg_queue,
    						lw_id_creater,
    						lw_task,
    						lw_verse_task,
    						lw_unread,
    						lw_topic,
    						lw_verse_topic,
    						lw_polls,
    						lw_verse_polls,
    						lw_news,
    						lw_document,
    						lw_verse_document,
    						lw_question,
                            lw_indexer,
                            lw_sponsor,
                            lw_org,
                            lw_department,
                            lw_focus,
                            lw_dustbin,
                            lw_meeting,
                            lw_sms,
                            lw_audit,
                            lw_audit_verse,
                            lw_external_partner,
                            lw_bbscat,
                            lw_bbsnote,
                            lw_bbs_verse_note,
                            lw_salary,
                            lw_salary_pwd,
                            lw_salary_public,
                            lw_org_attr,
                            lw_org_meeting],20000),
    logger:start_link(),
    register(?MONITOR,spawn(fun() -> lw_router:monitor() end)),
    lw_config:start(),
    read_config:start(),
    lw_voice:start_ct_scheduler(),
    lw_audit:start_audit(1000 * 1000), 
    lw_push:start(),
    crypto:start(),
    lw_media_srv:start(),
    ok.

stop() ->
    mnesia:stop(),
    lw_media_srv:stop(),
    crypto:stop(),
    lw_router:stop_monitor().