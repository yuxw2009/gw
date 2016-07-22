-module(tool).
-compile(export_all).
-include("db.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

my_float_to_list(Float) ->
    CalcFloat=
        if
            is_integer(Float) ->
                Float * 1.0;
            true ->
                Float
        end,
    [FloatStr] = io_lib:format("~.2f",[CalcFloat]),
    FloatStr.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
add_to_db(CompanyID,DepartmentID,EmployerAddRecordList) when is_integer(CompanyID) andalso is_list(DepartmentID) andalso is_list(EmployerAddRecordList) ->
    F = fun(EmployerAddRecord) ->
	        Name      = binary_to_list(EmployerAddRecord#employer_add.name),
	        JobNumber = binary_to_list(EmployerAddRecord#employer_add.jobNumber),
	        Phone1    = binary_to_list(EmployerAddRecord#employer_add.phone1),
	        Phone2    = binary_to_list(EmployerAddRecord#employer_add.phone2),
	        Banlance  = list_to_float(binary_to_list(EmployerAddRecord#employer_add.banlance)),
	        #employer{id={CompanyID,JobNumber},name=Name,department=DepartmentID,phone1=Phone1,phone2=Phone2,balance=Banlance}
	    end,
    lists:map(F,EmployerAddRecordList).

modify_to_db(Employer,EmployerModify) ->
    Phone1    = binary_to_list(EmployerModify#employer_modify.phone1),
    Phone2    = binary_to_list(EmployerModify#employer_modify.phone2),
    Balance   = list_to_float(binary_to_list(EmployerModify#employer_modify.balance)),
    Reset     = binary_to_list(EmployerModify#employer_modify.reset),
    case Reset of
        "1" ->
            Employer#employer{password = ?DEFAULT_PWD,phone1=Phone1,phone2=Phone2,balance=Balance};
        "0" ->
            Employer#employer{phone1=Phone1,phone2=Phone2,balance=Balance}
    end.

db_to_load(Employers) when is_list(Employers) ->
    F = fun({Employer,Cost}) ->
	        JobNumber = list_to_bitstring(element(2,Employer#employer.id)),
            Name      = list_to_bitstring(Employer#employer.name),
            Phone1    = list_to_bitstring(Employer#employer.phone1),
            Phone2    = list_to_bitstring(Employer#employer.phone2),
            Banlance  = list_to_bitstring(my_float_to_list(Employer#employer.balance)),
            StrCost   = list_to_bitstring(my_float_to_list(Cost)),
            #employer_load{name=Name,jobNumber=JobNumber,phone1=Phone1,phone2=Phone2,banlance=Banlance,cost=StrCost}
	    end,
    lists:map(F,Employers).

detail_db_to_load(EmployersDetails) when is_list(EmployersDetails) ->
    F = fun(Detail) ->
            Caller  = list_to_bitstring(Detail#employer_detail.caller),
            Called  = list_to_bitstring(Detail#employer_detail.called),
            {{SYear,SMonth,SDay},{SHour,SMinute,SSecond}} = Detail#employer_detail.start_time,
            {{EYear,EMonth,EDay},{EHour,EMinute,ESecond}} = Detail#employer_detail.end_time,
            Start   = list_to_bitstring(string:join([integer_to_list(SYear),integer_to_list(SMonth),integer_to_list(SDay),integer_to_list(SHour),integer_to_list(SMinute),integer_to_list(SSecond)],"-")),
            End     = list_to_bitstring(string:join([integer_to_list(EYear),integer_to_list(EMonth),integer_to_list(EDay),integer_to_list(EHour),integer_to_list(EMinute),integer_to_list(ESecond)],"-")),
            Cost    = list_to_bitstring(my_float_to_list(Detail#employer_detail.charge)),
            RecUrl=list_to_bitstring(Detail#employer_detail.recurl),
            #employer_load_detail{caller=Caller,called=Called,start_time=Start,end_time=End,cost=Cost,recurl=RecUrl}
        end,
    lists:map(F,EmployersDetails).

depstat_to_load(DepStats) ->
    F = fun(DepStat) ->
            Name  = element(1,DepStat),
            ID    = element(2,DepStat),
            StrID = list_to_bitstring(string:join([integer_to_list(X)||X<-ID],"-")),
            Stats = element(3,DepStat),
            BuildStr =  fun({{Year,Month},Charge},Acc) ->
                            Acc ++ integer_to_list(Year) ++ "-" ++ integer_to_list(Month) ++ ":" ++ my_float_to_list(Charge) ++ ";"
                        end,
            Stat = list_to_bitstring(lists:foldl(BuildStr,"",Stats)),
            #department_load{name=Name,id=StrID,stat=Stat}
        end,
    lists:map(F,DepStats).

dep_employer_stat_to_load(DepEmployerStats) ->
    F = fun({{Name,EmployerID},List}) ->
            StrName        = list_to_bitstring(Name),
            StrEmployerID  = list_to_bitstring(EmployerID),
            BuildStr =  fun({{Year,Month},Charge},Acc) ->
                            Acc ++ integer_to_list(Year) ++ "-" ++ integer_to_list(Month) ++ ":" ++ my_float_to_list(Charge) ++ ";"
                        end,
            Stat = list_to_bitstring(lists:foldl(BuildStr,"",List)),
            #department_employer_load{name=StrName,employerid=StrEmployerID,stat=Stat}
        end,
    lists:map(F,DepEmployerStats).

