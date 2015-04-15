
-record(lw_org_attr,{orgid,
	                 phone,
	                 video,
	                 cost,
	                 max_employee_num,
	                 reverse = []}).

-record(lw_org_meeting,{meetingid,
	                    nums = 0}).

-record(lw_auth,{id, %% ie.{OrgID, "0130000020"} %%
	             md5,
	             uuid,
	             reverse = []}).

-record(lw_salary_pwd,{usr,pwd,reverse = []}).
-record(lw_salary,{key,option = dict:new(),reverse = []}). %% key = {OrgID,Year,Month}
-record(lw_salary_public,{key,public = false}). %% key = {OrgID,Y,M},public = true or false

-define(TIMEOUT,10 * 1000).

-record(lw_audit,{bill_id,
	              year,
	              month,
				  group_code,
				  type,
				  quantity,
				  charge,
				  audit_info,
				  detail,
				  reverse = []}).

-record(lw_audit_verse,{key,bill_id = [],reverse = []}).

-record(lw_external_partner,{uuid,partner = [],reverse = []}).


-record(lw_instance, {uuid,
					  employee_name,
					  org_id,
					  employee_id,
					  department_id,
					  photo = <<"/images/photo/defalt_photo.gif">>,
					  phone = [],
					  email = [],
					  group = [], % {id}...
					  default_group = "recent",
					  default_view  = "task",
					  group_all_id,
					  group_recent_id,
					  reverse = []}).

-record(lw_instance_del, 
	 				 {uuid,
					  employee_name,
					  org_id,
					  employee_id,
					  department_id,
					  photo = <<"/images/photo/defalt_photo.gif">>,
					  phone = [],
					  email = [],
					  group = [], % {id}...
					  default_group = "recent",
					  default_view  = "task",
					  group_all_id,
					  group_recent_id,
					  reverse = []}).

-record(lw_unread,{key, % {id,tag} ie. {1,task}
	               unread = [],
	               reverse = []}).

-define(NO_VALUE,no_register).
-define(DEADLINE,120 * 1000).



-record(lw_group, {uuid,
                   user_id,
				   group_name,
				   attribute,
				   member = [],
				   reverse = []}).


-record(lw_verse_group,{name, % {UserID,GroupName}
                        uuid,
                        reverse = []}).

-record(lw_department, {id,
						org_id,
	                    name, 
	                    up,             % department_id
	                    downs = [],     % [department_id]
	                    employees = [], % [UUID]
	                    other_attrs = [],
	                    reverse = []}).

-record(lw_org, {id, 
	             full_name,
	             mark_name,
	             top_departments,
	             admin_name = "admin",
	             admin_pass = "888888", 
	             navigators = [],  % [{label, URL}]
	             logo,        
	             other_attrs = [],
	             reverse = []}).


-record(lw_register,{uuid,pid,reverse = []}).
-record(lw_verse_register,{pid,uuid,reverse = []}).
-record(lw_msg_queue,{uuid,msgs=[],reverse = []}). % msgs = [...]

-define(MONITOR,monitor).



-record(lw_id_creater, {id,counter = 10000}).  % uuid which include user id and group id |  messageid | ...  





-record(lw_task,{uuid,
	             owner_id,
	             contents,
	             members_id = [],
	             replies    = [],
	             attachment = [],
	             trace      = [],
	             time_stamp,
	             finish_stamp,
	             reverse = []}).

-record(lw_verse_cache_task,{uuid,
	             	   		 assign_unfinished = [],
	             	   		 relate_unfinished = [],
	             	   		 assign_finished   = [],
	             	   		 relate_finished   = [],
	             	   		 reverse = []}).

-record(lw_verse_task,{uuid,
	             	   assign_unfinished = [],
	             	   relate_unfinished = [],
	             	   assign_finished   = [],
	             	   relate_finished   = [],
	             	   reverse = []}).



-record(lw_topic,{uuid,
	              owner_id,
	              contents,
	              members_id = [],
	              replies    = [],
	              attachment = [],
	              trace      = [],
	              time_stamp,
	              reverse = []}).

-record(lw_polls,{uuid,
	              owner_id,
				  type,
				  members_id = [],
				  replies    = [],
				  trace      = [],
				  contents,
				  options = [], % ie. {selcet,content,num}
				  time_stamp,
				  attachment,
				  reverse = []}).

-record(lw_question,{uuid,
	             	 owner_id,
	             	 title,
				 	 contents,
				 	 tags,
				 	 time_stamp,
				 	 replies = [],
				 	 reverse = []}).

-record(lw_verse_topic,{uuid,
						assign = [],
						relate = [],
						reverse = []}).




-record(lw_verse_polls,{uuid,
						assign = [],
						relate = [], % ie. {pool_id,{is_already_vote,selcet}}
						reverse = []}).



-record(lw_news,{uuid,
	             owner_id,
				 contents,
				 replies = [],
				 time_stamp,
				 attachment,
				 attachment_name,
				 reverse = []}).




-record(lw_document,{uuid,
					 owner_id,
					 file_name,
					 file_id,
					 file_size,
					 members_id = [],
					 time_stamp,
					 discription,
					 quote = 1,
					 reverse = []}).

-record(lw_verse_document,{uuid,
						   assign = [],
						   relate = [],
						   reverse = []}).


-record(lw_sms,{uuid,sms = [],reverse = []}).


-define(PAGELEN,50).
-define(PAGENUM,12).



-record(lw_indexer,{key,
	             	content = [],
				 	reverse = []}).

-record(lw_sponsor,{key,
	             	content = [],
				 	reverse = []}).


-record(lw_company,{name,
					departments,
					adminstrator,
					password,
					navigator,
					reverse = []}).

-record(lw_focus,{uuid,
				  focus = [], % [{{type,id},tags=[],time}]
				  reverse = []}).


-record(lw_dustbin,{uuid,
				    dustbin = [],
				    reverse = []}).

-record(lw_meeting,{uuid,meeting = [],reverse = []}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-record(lw_bbscat,{key,index,reverse = []}).

-record(lw_bbsnote,{uuid,owner_id,time_stamp,title,content,repository,index,reader = 0,replies = [],type = normal,reverse = []}).

-record(lw_bbs_verse_note,{index,total_num = 1,today_num = dict:new(),notes = []}).
-record(lw_history, {uuid,orgid,history=[{login,[]}]}).
