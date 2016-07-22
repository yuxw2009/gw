-define(DEFAULT_PWD,<<"888888">>).

-record(id,{id}).
-record(message,{message}).

-record(org,{id,name,count = 1,department = []}).
-record(company,{id,name,org,admin = <<"admin">>,password = ?DEFAULT_PWD}).

-record(employer_add,{name,jobNumber,phone1,phone2,banlance}).
-record(employer_load,{name,jobNumber,phone1,phone2,banlance,cost}).
-record(employer_load_detail,{caller,called,start_time,end_time,cost,recurl}).
-record(employer_modify,{phone1,phone2,balance,reset}).

-record(employer,{id,name,department,password = ?DEFAULT_PWD,phone1,phone2,balance = 200.0,reverse}).

-record(employer_stat,{ id,           %%{companyid,employeeid,year,month}
	                    count   = 0,
	                    time    = 0.0, %%unit = min
	                    charge  = 0.0,
	                    details = []   %%[employer_detail]
	                  }).
-record(employer_detail,{caller,called,start_time,end_time,duration,rate,charge,recurl="",pls=[]}).

-record(department_stat,{ id,          %%{companyid,departmentid}
	                      cur ={{},0.0,0},      %%{{year,month},total_charge,total_time}
	                      history = []  %%[{last_charge,last_time}...]
	                    }).
-record(department_load,{name = <<"">>,id = <<"">>,stat = <<"">>}).

-record(department_employer_load,{name = <<"">>,employerid = <<"">>,stat = <<"">>}).

%key: {session_id,service_id}  detais: employer_detail
-record(cdr, {key, type=voip,detail}). 


