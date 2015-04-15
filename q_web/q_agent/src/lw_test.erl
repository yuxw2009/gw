-module(lw_test).
-compile(export_all).
-include("lw.hrl").

do_this_once() ->
    mnesia:create_schema([node()]),
    mnesia:start(),

    mnesia:create_table(lw_register,[{attributes,record_info(fields,lw_register)}]),
    mnesia:create_table(lw_verse_register,[{attributes,record_info(fields,lw_verse_register)}]),

    mnesia:create_table(lw_auth,[{attributes,record_info(fields,lw_auth)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_instance,[{attributes,record_info(fields,lw_instance)},{disc_copies,[node()]}]),
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
    mnesia:stop().

add_table() ->
    mnesia:create_table(lw_task,[{attributes,record_info(fields,lw_task)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_task,[{attributes,record_info(fields,lw_verse_task)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_unread,[{attributes,record_info(fields,lw_unread)},{disc_copies,[node()]}]).

add_table1() ->
    mnesia:create_table(lw_topic,[{attributes,record_info(fields,lw_topic)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_topic,[{attributes,record_info(fields,lw_verse_topic)},{disc_copies,[node()]}]).

add_table2() ->
    mnesia:create_table(lw_polls,[{attributes,record_info(fields,lw_polls)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_polls,[{attributes,record_info(fields,lw_verse_polls)},{disc_copies,[node()]}]).

add_table3() ->
    mnesia:create_table(lw_news,[{attributes,record_info(fields,lw_news)},{disc_copies,[node()]}]).

add_table4() ->
    mnesia:create_table(lw_document,[{attributes,record_info(fields,lw_document)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_document,[{attributes,record_info(fields,lw_verse_document)},{disc_copies,[node()]}]).

add_table5() ->
    mnesia:create_table(lw_question,[{attributes,record_info(fields,lw_question)},{disc_copies,[node()]}]).

add_table6() ->
    mnesia:create_table(lw_task,[{attributes,record_info(fields,lw_task)},{disc_copies,[node()]}]),
    mnesia:create_table(lw_verse_task,[{attributes,record_info(fields,lw_verse_task)},{disc_copies,[node()]}]).


start() ->
    mnesia:start(),
    mnesia:wait_for_tables([lw_register,lw_verse_register,lw_auth,lw_instance,lw_group,lw_verse_group,lw_msg_queue,lw_id_creater],20000),
    register(?MONITOR,spawn(fun() -> lw_router:monitor() end)),
    ok.

stop() ->
    mnesia:stop(),
    lw_router:stop_monitor().

auth_add(ID,Password) ->
    UUID = lw_id_creater:generate_uuid(),
    F = fun() ->
            mnesia:write(#lw_auth{id = ID,md5 = hex:to(crypto:md5(Password)),uuid = UUID})
    	end,
    mnesia:transaction(F),
    UUID.

instance_add(UUID,EmployeeName,OrgID,EmployeeID,DepartmentID,Phone,Email) ->
    F = fun() ->
            mnesia:write(#lw_instance{uuid = UUID,
                      employee_name = EmployeeName,
                      org_id        = OrgID,
                      employee_id   = EmployeeID,
                      department_id = DepartmentID,
                      phone         = Phone,
                      email         = Email})
        end,
    mnesia:transaction(F).

recent_add(UUID) ->
    lw_group:create_group(UUID,"recent","rw").

add_new() ->
    UUID2 = auth_add({"livecom","0131000031"},"luowei"),
    instance_add(UUID2,"罗威","livecom","0131000031","department three",[],[]),

    UUID3 = auth_add({"livecom","0131000014"},"qianliangjian"),
    instance_add(UUID3,"钱良建","livecom","0131000014","department three",[],[]),
    
    UUID4 = auth_add({"livecom","0131000032"},"panliubing"),
    instance_add(UUID4,"潘刘兵","livecom","0131000032","department three",[],[]),

    UUID5 = auth_add({"livecom","0130000006"},"leiyuxin"),
    instance_add(UUID5,"雷玉新","livecom","0130000006","department three",[],[]),
    
    UUID6 = auth_add({"livecom","0131000028"},"xuxin"),
    instance_add(UUID6,"徐鑫","livecom","0131000028","department three",[],[]),

    UUID1 = auth_add({"livecom","0131000024"},"jingzhe"),
    instance_add(UUID1,"景喆","livecom","0131000024","department three",[],[]),

    UUID7 = auth_add({"livecom","10004278"},"zhaotao"),
    instance_add(UUID7,"赵涛","livecom","10004278","department three",[],[]),

    UUID8 = auth_add({"livecom","0131000025"},"zhaowenhao"),
    instance_add(UUID8,"赵文浩","livecom","0131000025","department three",[],[]),

    UUID9 = auth_add({"livecom","0131000040"},"puyun"),
    instance_add(UUID9,"濮云","livecom","0131000040","department three",[],[]),

    GroupID = lw_group:get_uuid(all_user,"all"),

    lw_group:add_members(test,GroupID,[UUID1,UUID2,UUID3,UUID4,UUID5,UUID6,UUID7,UUID8,UUID9]),

    lw_instance:add_user_group(UUID1,GroupID),
    lw_instance:add_user_group(UUID2,GroupID),
    lw_instance:add_user_group(UUID3,GroupID),
    lw_instance:add_user_group(UUID4,GroupID),
    lw_instance:add_user_group(UUID5,GroupID),
    lw_instance:add_user_group(UUID6,GroupID),
    lw_instance:add_user_group(UUID7,GroupID),
    lw_instance:add_user_group(UUID8,GroupID),
    lw_instance:add_user_group(UUID9,GroupID),

    recent_add(UUID1),
    recent_add(UUID2),
    recent_add(UUID3),
    recent_add(UUID4),
    recent_add(UUID5),
    recent_add(UUID6),
    recent_add(UUID7),
    recent_add(UUID8),
    recent_add(UUID9),
    ok.

add_user(Company,EID,Name,Department,Phone,Email,Pwd) ->
    UUID = auth_add({Company,EID},Pwd),
    instance_add(UUID,Name,Company,EID,Department,Phone,Email),
    GroupID = lw_group:get_uuid(all_user,"all"),
    lw_group:add_members(test,GroupID,[UUID]),
    lw_instance:add_user_group(UUID,GroupID),
    recent_add(UUID),
    ok.

add_dxd() ->
    add_user("livecom","0131000043","段先德","新业务开发部",["008613818986921"],[""],"livecom").

add_cp() ->
    add_user("livecom","10008160","陈沛","外协",["13570851641"],["chen.pei1@zte.com.cn"],"livecom").

add_tester() ->
    add_user("livecom","10000","顾忆民","测试",[""],[""],"8888"),
    add_user("livecom","10001","姚杰","测试",["008613501804128"],[""],"8888"),
    add_user("livecom","10002","胡加","测试",[""],[""],"8888").

add_tzh() ->
    add_user("livecom","0131000042","谭志红","业务二部",[""],[""],"livecom").

add_zss() ->
    add_user("livecom","00000008","周苏苏","缺省",[""],[""],"livecom"),
    add_user("livecom","30004011","邢晓江","缺省",[""],[""],"livecom").

add_wf() ->
    add_user("livecom","0131000044","王府","运维部",[""],[""],"wangfu").

add_fhl() ->
    add_user("livecom","0131000045","冯海龙","运维部",[""],[""],"livecom").

test() ->
    UUID1 = auth_add({"livecom","0131000018"},"zhangcongsong"),
    UUID2 = auth_add({"livecom","0131000010"},"chenjiapei"),
    UUID3 = auth_add({"livecom","0131000019"},"qianpei"),
    UUID4 = auth_add({"livecom","0131000020"},"denghui"),

    instance_add(UUID1,"张丛耸","livecom","0131000018","department three",["1"],["1@a.com"]),
    instance_add(UUID2,"陈佳培","livecom","0131000010","department three",["2"],["2@a.com"]),
    instance_add(UUID3,"钱沛","livecom","0131000019","department three",["3"],["3@a.com"]),
    instance_add(UUID4,"邓辉","livecom","0131000020","department three",["4"],["4@a.com"]),

    GroupID = lw_group:create_group_all(),
    lw_group:add_members(test,GroupID,[UUID1,UUID2,UUID3,UUID4]),

    lw_instance:add_user_group(UUID1,GroupID),
    lw_instance:add_user_group(UUID2,GroupID),
    lw_instance:add_user_group(UUID3,GroupID),
    lw_instance:add_user_group(UUID4,GroupID),

    recent_add(UUID1),
    recent_add(UUID2),
    recent_add(UUID3),
    recent_add(UUID4),
    ok.