-module(db).
-compile(export_all).
-include("db.hrl").
-include("jsonerl.hrl").
-include("db_op.hrl").
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

do_this_once() ->
	mnesia:create_schema([node()]),
	mnesia:start(),
	mnesia:create_table(cdr,[{attributes,record_info(fields,cdr)},{disc_copies,[node()]}]),
	mnesia:create_table(company,[{attributes,record_info(fields,company)},{index, [name]},{disc_copies,[node()]}]),
    mnesia:create_table(employer,[{attributes,record_info(fields,employer)},{disc_copies,[node()]}]),
    mnesia:create_table(employer_stat,[{attributes,record_info(fields,employer_stat)},{disc_copies,[node()]}]),
    mnesia:create_table(department_stat,[{attributes,record_info(fields,department_stat)},{disc_copies,[node()]}]).

start() ->
    mnesia:start(),
    case mnesia:system_info(tables) of
        [schema] -> 
            mnesia:stop(),
            do_this_once();
        _  -> 
            ok
    end,
    mnesia:wait_for_tables([company,employer,employer_stat,department_stat],20000).

stop() ->
    mnesia:stop().

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

create_org(CompanyID,CompanyName) when is_integer(CompanyID) andalso is_binary(CompanyName) ->
    Org     = [#org{id=CompanyID,name=CompanyName}],
    Company = #company{id=CompanyID,name=CompanyName,org=Org},
    F = fun() ->
    	    mnesia:write(Company)
    	end,
    mnesia:transaction(F),
    ok.

load_org(CompanyID) when is_integer(CompanyID) ->
    F = fun() ->
    	    mnesia:read(company, CompanyID)
    	end,
    {atomic,[Company]} = mnesia:transaction(F),
    hd(Company#company.org).

add_org(CompanyID,DepartmentID,DepartmentName) when is_integer(CompanyID) andalso is_list(DepartmentID) andalso is_binary(DepartmentName) ->
    F = fun() ->
            case is_exist_employer(CompanyID,DepartmentID) of
                true ->
                    error_exist_employer;
                false ->
            	    [Company] = mnesia:read(company, CompanyID, write),
            	    {RtnInfo,NewOrgs} = 
                        case add_department(DepartmentID,DepartmentName,Company#company.org) of
                            error_exist ->
                                {error_exist,Company#company.org};
                            error_non_exist ->
                                {error_non_exist,Company#company.org};
                            {AddID,RtnOrgs} ->
                                {AddID,RtnOrgs}
                        end,
                    mnesia:write(Company#company{org=NewOrgs}),
                    RtnInfo
            end
    	end,
    {atomic,Info} = mnesia:transaction(F),
    Info.

del_org(CompanyID,DepartmentID) when is_integer(CompanyID) andalso is_list(DepartmentID) ->
    F = fun() ->
            case is_exist_employer(CompanyID,DepartmentID) of
                false ->   
            	    [Company] = mnesia:read(company, CompanyID, write),
            	    {RtnInfo,NewOrgs} = 
                        case del_department(DepartmentID,Company#company.org) of
                            error_exist_sub_department ->
                                {error_exist_sub_department,Company#company.org};
                            error_non_exist ->
                                {error_non_exist,Company#company.org};
                            RtnOrgs ->
                                {ok,RtnOrgs}
                        end,
                    mnesia:write(Company#company{org=NewOrgs}),
                    RtnInfo;
                true ->
                    error_exist_employer
            end
    	end,
    {atomic,Info} = mnesia:transaction(F),
    Info.

modify_org(CompanyID,DepartmentID,DepartmentName) when is_integer(CompanyID) andalso is_list(DepartmentID) andalso is_binary(DepartmentName) ->    
    F = fun() ->
            [Company] = mnesia:read(company, CompanyID, write),
    	    {RtnInfo,NewOrgs} = 
                case modify_department(DepartmentID,DepartmentName,Company#company.org) of
                    error_non_exist ->
                        {error_non_exist,Company#company.org};
                    RtnOrgs ->
                        {ok,RtnOrgs}
                end,
            mnesia:write(Company#company{org=NewOrgs}),
            RtnInfo
    	end,
    {atomic,Info} = mnesia:transaction(F),
    Info.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% add_org department %%
add_department([H|T],Name,Orgs) ->
    case lists:keysearch(H,#org.id,Orgs) of
    	{value,Target} ->
    	    case add_department(T,Name,Target#org.department,Target#org.count) of
    	    	error_exist ->
    	    	    error_exist;
    	    	error_non_exist ->
    	    	    error_non_exist;
    	    	{update_count,Count,NewDep} ->
    	    	    {Count,lists:keyreplace(H,#org.id,Orgs,Target#org{count=Count+1,department=NewDep})};
    	    	{Count,NewDep} ->
    	    	    {Count,lists:keyreplace(H,#org.id,Orgs,Target#org{department=NewDep})}
    	    end;
    	false ->
    	    error_non_exist
    end.
add_department([H|T],Name,Orgs,_Count) ->
    case lists:keysearch(H,#org.id,Orgs) of
    	{value,Target} ->
    	    Result = add_department(T,Name,Target#org.department,Target#org.count),
    	    case Result of
    	    	error_exist ->
    	    	    error_exist;
    	    	error_non_exist ->
    	    	    error_non_exist;
    	    	{update_count,Count,NewDep} ->
    	    	    {Count,lists:keyreplace(H,#org.id,Orgs,Target#org{count=Count+1,department=NewDep})};
    	    	{Count,NewDep} ->
    	    	    {Count,lists:keyreplace(H,#org.id,Orgs,Target#org{department=NewDep})}
    	    end;
    	false ->
    	    error_non_exist
    end;
add_department([],Name,Orgs,Count) ->
    case lists:keysearch(Name,#org.name,Orgs) of
    	{value,_} ->
    	    error_exist;
    	false ->
            {update_count,Count,lists:append(Orgs,[#org{id=Count,name=Name}])}
    end.
%% del_org department %%
del_department(ID,Orgs) when length(ID) > 1 ->
    [H|T] = ID,
    case lists:keysearch(H,#org.id,Orgs) of
        {value,Target} ->
            case del_department(T,Target#org.department) of
                error_exist_sub_department ->
                    error_exist_sub_department;
                error_non_exist ->
                    error_non_exist;
                NewDep ->
                    lists:keyreplace(H,#org.id,Orgs,Target#org{department=NewDep})
            end;
        false ->
            error_non_exist
    end;
del_department(ID,Orgs) when length(ID) =:= 1 ->
    [H] = ID,
    case lists:keysearch(H,#org.id,Orgs) of
        {value,Target} ->
            case Target#org.department of
                [] ->
                    lists:keydelete(H,#org.id,Orgs);
                _ ->
                    error_exist_sub_department
            end;
        false ->
            error_non_exist
    end.
%% modify_org department %%
modify_department(ID,Name,Orgs) when length(ID) > 1 ->
    [H|T] = ID,
    case lists:keysearch(H,#org.id,Orgs) of
        {value,Target} ->
            case modify_department(T,Name,Target#org.department) of
                error_non_exist ->
                    error_non_exist;
                NewDep ->
                    lists:keyreplace(H,#org.id,Orgs,Target#org{department=NewDep})
            end;
        false ->
            error_non_exist
    end;
modify_department(ID,Name,Orgs) when length(ID) =:= 1 ->
    [H] = ID,
    case lists:keysearch(H,#org.id,Orgs) of
        {value,Target} ->
            lists:keyreplace(H,#org.id,Orgs,Target#org{name=Name});
        false ->
            error_non_exist
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

test() ->
    do_this_once(),
    start(),

    create_org(1,<<"zte">>),

    1 = add_org(1,[1],<<"manage">>),
    #org{id=1,name= <<"zte">>,count=2,department=[#org{id=1,name= <<"manage">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test1 passed!"]),

    error_exist = add_org(1,[1],<<"manage">>),
    #org{id=1,name= <<"zte">>,count=2,department=[#org{id=1,name= <<"manage">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test2 passed!"]),

    2 = add_org(1,[1],<<"HR">>),
    #org{id=1,name= <<"zte">>,count=3,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test3 passed!"]),

    error_non_exist = add_org(1,[1,3,4],<<"manage">>),
    #org{id=1,name= <<"zte">>,count=3,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test4 passed!"]),

    1 = add_org(1,[1,2],<<"hrnj">>),
    #org{id=1,name= <<"zte">>,count=3,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]}]} = load_org(1),
    io:format("~p~n",["test5 passed!"]),

    3 = add_org(1,[1],<<"product">>),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test6 passed!"]),

    error_exist_sub_department = del_org(1,[1]),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test7 passed!"]),

    error_exist_sub_department = del_org(1,[1,2]),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test8 passed!"]),

    error_non_exist = del_org(1,[1,6]),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test9 passed!"]),

    error_non_exist = del_org(1,[1,2,1,1]),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[#org{id=1,name= <<"hrnj">>,count=1,department=[]}]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test10 passed!"]),

    ok = del_org(1,[1,2,1]),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"HR">>,count=2,department=[]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test11 passed!"]),

    ok = modify_org(1,[1,2],<<"human resource">>),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"human resource">>,count=2,department=[]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test12 passed!"]),

    error_non_exist = modify_org(1,[1,2,1],<<"human resource">>),
    #org{id=1,name= <<"zte">>,count=4,department=[#org{id=1,name= <<"manage">>,count=1,department=[]},#org{id=2,name= <<"human resource">>,count=2,department=[]},#org{id=3,name= <<"product">>,count=1,department=[]}]} = load_org(1),
    io:format("~p~n",["test13 passed!"]),

    mnesia:delete_table(company),
    mnesia:stop(),
    mnesia:delete_schema([node()]),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

add_employer(CompanyID,DepartmentID,EmployerAddRecordList) when is_integer(CompanyID) andalso is_list(DepartmentID) andalso is_list(EmployerAddRecordList) ->
    F = fun() ->
            Insert= fun(Employer) ->
                        case mnesia:read(employer,Employer#employer.id,write) of
                            [] ->
                                mnesia:write(Employer),
                                "";
                            _ ->
                                element(2,Employer#employer.id) ++ "&"
                        end
                    end,
            lists:foldl(fun(X,Acc) -> Acc ++ Insert(X) end,"",tool:add_to_db(CompanyID,DepartmentID,EmployerAddRecordList))
        end,
    {atomic,Ack} = mnesia:transaction(F),
    case Ack of
        "" ->
            list_to_bitstring("ok");
        _ ->
            list_to_bitstring(Ack)
    end.

del_employer(CompanyID,EmployerDelIDList) when is_integer(CompanyID) andalso is_list(EmployerDelIDList) ->
    F = fun() ->
            lists:foreach(fun(EmployerDelID) -> mnesia:delete({employer,{CompanyID,EmployerDelID}}) end,EmployerDelIDList)
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

modify_employer_depid(CompanyID,EID,DepartmentID) when is_integer(CompanyID) andalso is_list(EID) andalso is_list(DepartmentID) ->
    F = fun() ->
            case mnesia:read(employer,{CompanyID,EID},write) of
                [] ->
                    ok;
                [Employer] ->
                    mnesia:write(Employer#employer{department = DepartmentID}),
                    ok
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

load_employer(CompanyID,DepartmentID) when is_integer(CompanyID) andalso is_list(DepartmentID) ->
    {Year,Month} = get_cur_year_and_month(),
    F = fun() ->
            MatchHead = #employer{id={'$1','_'},department='$2',_ = '_'},
            Guard1  = {'==', '$1', CompanyID},
            Guard2  = {'==', '$2', DepartmentID},
            Result  = '$_',
            EmployerList = mnesia:select(employer,[{MatchHead,[Guard1,Guard2],[Result]}]),
            GetCost =   fun(Employer) ->
                            {CompanyID,EmployerID} = Employer#employer.id,
                            case mnesia:read(employer_stat,{CompanyID,EmployerID,Year,Month},read) of
                                [EmployerStat] ->
                                    {Employer,EmployerStat#employer_stat.charge};
                                [] ->
                                    {Employer,0.0}
                            end
                        end,
            lists:map(GetCost,EmployerList)
        end,
    {atomic,EmployerStatList} = mnesia:transaction(F),
    tool:db_to_load(EmployerStatList).

trans_dep(CompanyID,New,EIDs) when is_integer(CompanyID) andalso is_list(New) andalso is_list(EIDs)->
    [modify_employer_depid(CompanyID,EID,New)||EID<-EIDs],
    ok.

load_employer_detail(CompanyID,EmployerID) when is_integer(CompanyID) andalso is_list(EmployerID) ->
    {Year,Month} = get_cur_year_and_month(),
    load_employer_detail(CompanyID,EmployerID,Year,Month).

load_employer_detail(CompanyID,EmployerID,Year,Month) ->
    F = fun() ->
            mnesia:read(employer_stat,{CompanyID,EmployerID,Year,Month},read)
        end,
    case mnesia:transaction(F) of
    {atomic,[EmployerStat]}->    tool:detail_db_to_load(EmployerStat#employer_stat.details);
    _-> []
    end.


modify_employer(CompanyID,JobNumber,EmployerModify) when is_integer(CompanyID) andalso is_list(JobNumber) andalso is_record(EmployerModify,employer_modify) ->
    F = fun() ->
            [Employer] = mnesia:read(employer,{CompanyID,JobNumber},write),
            mnesia:write(tool:modify_to_db(Employer,EmployerModify))
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

is_exist_employer(CompanyID,DepartmentID) when is_integer(CompanyID) andalso is_list(DepartmentID) ->
    MatchHead = #employer{id={'$1','_'},department='$2',_ = '_'},
    Guard1  = {'==', '$1', CompanyID},
    Guard2  = {'==', '$2', DepartmentID},
    Result  = '$_',
    case mnesia:select(employer,[{MatchHead,[Guard1,Guard2],[Result]}],1,read) of
        {_,_} ->
            true;
        '$end_of_table' ->
            false
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

db_person_transform() ->
    F = fun({employer,ID,Name,Department,Password,Phone1,Phone2,Balance,Reverse}) ->
            {employer,ID,Name,Department,Password,Phone1,Phone2,Balance,0.0,Reverse}
        end,
    mnesia:transform_table(employer, F, [id,name,department,password,phone1,phone2,balance,cost,reverse]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

update({CompanyID,EmployerID},Detail) when is_integer(CompanyID) andalso is_list(EmployerID) andalso is_record(Detail,employer_detail) ->
    {{Year,Month,_},_} = Detail#employer_detail.end_time,
    update_employer_state({CompanyID,EmployerID,Year,Month},Detail),
    update_department_stat({CompanyID,EmployerID},Detail).
    

update_employer_state(ID,Detail) when is_tuple(ID) andalso is_record(Detail,employer_detail) ->
    F = fun() ->
            case mnesia:read(employer_stat,ID,write) of
                [EmployerStat] ->
                    mnesia:write(merge_employer_state(EmployerStat,Detail));
                [] ->
                    mnesia:write(merge_employer_state(#employer_stat{id=ID},Detail))
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

merge_employer_state(EmployerStat,Detail) ->
    NewCount   = EmployerStat#employer_stat.count  + 1,
    NewTime    = EmployerStat#employer_stat.time   + Detail#employer_detail.duration,
    NewCharge  = EmployerStat#employer_stat.charge + Detail#employer_detail.charge,
    NewDetails = [Detail|EmployerStat#employer_stat.details],
    EmployerStat#employer_stat{count=NewCount,time=NewTime,charge=NewCharge,details=NewDetails}.

update_department_stat(ID,Detail) when is_tuple(ID)  andalso is_record(Detail,employer_detail) ->
    F = fun() ->
            CompanyID  = element(1,ID),
            [Employer] = mnesia:read(employer,ID,read),
            Department = Employer#employer.department,
            case mnesia:read(department_stat,{CompanyID,Department},write) of
                [DepartmentStat] ->
                    mnesia:write(merge_department_stat(DepartmentStat,Detail));
                [] ->
                    mnesia:write(merge_department_stat(#department_stat{id={CompanyID,Department}},Detail))
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

merge_department_stat(DepartmentStat,Detail) ->
    {{Year,Month,_},_} = Detail#employer_detail.end_time,
    CurDate            = element(1,DepartmentStat#department_stat.cur),
    if
        {Year,Month} > CurDate ->
            NewHistory = 
                case CurDate of
                    {} ->
                        DepartmentStat#department_stat.history;
                    _ ->
                        [DepartmentStat#department_stat.cur|DepartmentStat#department_stat.history]
                end,
            NewCur     = {{Year,Month},Detail#employer_detail.charge,Detail#employer_detail.duration},
            DepartmentStat#department_stat{cur=NewCur,history=NewHistory};
        {Year,Month} =:= CurDate ->
            NewCurCharge = element(2,DepartmentStat#department_stat.cur) + Detail#employer_detail.charge,
            NewCurTime   = element(3,DepartmentStat#department_stat.cur) + Detail#employer_detail.duration,
            DepartmentStat#department_stat{cur={CurDate,NewCurCharge,NewCurTime}};
        true ->
            DepartmentStat
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

test1() ->
    load_sub_org_stat(1,[1]).

load_sub_org_stat(CompanyID,DepartmentID) when is_integer(CompanyID) andalso is_list(DepartmentID) ->
    {Year,Month} = get_cur_year_and_month(),
    CalcPrev5Month = fun({CurYear,CurMonth}) ->
                        case CurMonth of
                            1 ->
                                [{CurYear-1,9},{CurYear-1,10},{CurYear-1,11},{CurYear-1,12},{CurYear,CurMonth}];
                            2 ->
                                [{CurYear-1,10},{CurYear-1,11},{CurYear-1,12},{CurYear,1},{CurYear,CurMonth}];
                            3 ->
                                [{CurYear-1,11},{CurYear-1,12},{CurYear,1},{CurYear,2},{CurYear,CurMonth}];
                            4 ->
                                [{CurYear-1,12},{CurYear,1},{CurYear,2},{CurYear,3},{CurYear,CurMonth}];
                            5 ->
                                [{CurYear,1},{CurYear,2},{CurYear,3},{CurYear,4},{CurYear,CurMonth}];
                            6 ->
                                [{CurYear,2},{CurYear,3},{CurYear,4},{CurYear,5},{CurYear,CurMonth}];
                            7 ->
                                [{CurYear,3},{CurYear,4},{CurYear,5},{CurYear,6},{CurYear,CurMonth}];
                            8 ->
                                [{CurYear,4},{CurYear,5},{CurYear,6},{CurYear,7},{CurYear,CurMonth}];
                            9 ->
                                [{CurYear,5},{CurYear,6},{CurYear,7},{CurYear,8},{CurYear,CurMonth}];
                            10 ->
                                [{CurYear,6},{CurYear,7},{CurYear,8},{CurYear,9},{CurYear,CurMonth}];
                            11 ->
                                [{CurYear,7},{CurYear,8},{CurYear,9},{CurYear,10},{CurYear,CurMonth}];
                            12 ->
                                [{CurYear,8},{CurYear,9},{CurYear,10},{CurYear,11},{CurYear,CurMonth}]
                        end
                    end,
    FindMatchDate = fun(Date,L) ->
                        case lists:keysearch(Date,1,L) of
                            {value, {Date,Charge,_}} ->
                                {Date,Charge};
                            false ->
                                {Date,0.0}
                        end
                    end,
    AddTwoList  =   fun(L1,L2) ->
                        lists:zipwith(fun({{Y,M},X1}, {{Y,M},X2}) -> {{Y,M},X1+X2} end, L1, L2)
                    end,
    F = fun() ->
            GetOrg        = fun(ID) -> [Company] = mnesia:dirty_read(company,ID),hd(Company#company.org) end,
            GetSubDepID   = fun(ID,Node) -> [lists:append(ID,[X#org.id])||X<-Node#org.department] end,
            GetSubDepName = fun(Node) -> [X#org.name||X<-Node#org.department] end,
            CompanyOrg = GetOrg(CompanyID),
            Node       = db:get_department_node(CompanyOrg,DepartmentID),
            SubDepID   = GetSubDepID(DepartmentID,Node),
            SubDepName = GetSubDepName(Node),
            DateList   = lists:reverse(CalcPrev5Month({Year,Month})),
            GetStat =   fun(ID) -> 
                            AllLeaf = db:get_all_leaf_department(CompanyOrg,ID),
                            LeafDepStat =   fun(LeafDepartmentID) ->
                                                case mnesia:dirty_read(department_stat,{CompanyID,LeafDepartmentID}) of
                                                    [DepartmentStat] ->
                                                        {CDate,CurCharge,_} = DepartmentStat#department_stat.cur,
                                                        if
                                                            {Year,Month} =:= CDate ->
                                                                [{CDate,CurCharge}|lists:map(fun(Date) -> FindMatchDate(Date,DepartmentStat#department_stat.history) end,tl(DateList))];
                                                            {Year,Month} > CDate ->
                                                                [{{Year,Month},0.0}|lists:map(fun(Date) -> FindMatchDate(Date,[DepartmentStat#department_stat.cur|DepartmentStat#department_stat.history]) end,tl(DateList))]
                                                        end;
                                                    [] ->
                                                        lists:zip(DateList,[0.0,0.0,0.0,0.0,0.0])
                                                end
                                            end,
                            lists:foldl(fun(ID2,Acc) -> AddTwoList(LeafDepStat(ID2),Acc) end,lists:zip(DateList,[0.0,0.0,0.0,0.0,0.0]),AllLeaf)
                        end,
            lists:zip3(SubDepName,SubDepID,lists:map(GetStat,SubDepID))
        end,
%    {atomic,SubStats} = mnesia:transaction(F),
    SubStats=F(),
    tool:depstat_to_load(SubStats).

get_department_node(Org,DepartmentID) when is_record(Org,org) andalso is_list(DepartmentID) ->
    LookOne =   fun(Node,ID) -> [Target] = [X||X<-Node#org.department,X#org.id =:= ID],Target end,
    Look    =   fun(Root,IDList,Act) ->
                    case IDList of
                            [] ->
                                Root;
                            _ ->
                                NewRoot = LookOne(Root,hd(IDList)),
                                Act(NewRoot,tl(IDList),Act)
                    end
                end,
    Look(Org,tl(DepartmentID),Look). 

get_all_leaf_department(Org,DepartmentID) when is_record(Org,org) andalso is_list(DepartmentID) ->
    Recursive = fun(CompanyOrg,Queue,LeafSet,Act) ->
                    case queue:len(Queue) of
                        0 ->
                            LeafSet;
                        _ ->
                            {{value,IDList},Q2} = queue:out_r(Queue),
                            Node = get_department_node(CompanyOrg,IDList),
                            case Node#org.department of
                                [] ->
                                    Act(CompanyOrg,Q2,[IDList|LeafSet],Act);
                                _ ->
                                    Act(CompanyOrg,lists:foldl(fun(X,NewQueue) -> queue:in(lists:append(IDList,[X#org.id]),NewQueue) end,Q2,Node#org.department),LeafSet,Act)
                            end
                    end
                end,
    Recursive(Org,queue:in(DepartmentID,queue:new()),[],Recursive). 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_depID_by_name(ComName,Depname)  ->
    case mnesia:dirty_index_read(company,ComName,#company.name) of
    [#company{id=Id,org=[Org]}|_]-> 
        case [X||X<-Org#org.department,X#org.name =:= Depname] of
        [#org{id=DepId}|_]->         [Id,DepId];
        _-> dep_notfound
        end;
    _->  company_notfound
    end.

get_department_calldetails(ComName,Depname,Year,Month)->
    DepartmentID=[CompanyID|_]=db:get_depID_by_name(ComName,Depname),
    Employers=db:get_all_empleyers(CompanyID,DepartmentID),
    lists:concat([db:load_employer_detail(CompanyID,EmpID,Year,Month)||#employer{id={_,EmpID}}<-Employers]).
    
    
get_all_empleyers(CompanyID,DepartmentID)->
            MatchHead = #employer{id={'$1','_'},department='$2',_ = '_'},
            Guard1  = {'==', '$1', CompanyID},
            Guard2  = {'==', '$2', DepartmentID},
            Result  = '$_',
            EmployerList = mnesia:dirty_select(employer,[{MatchHead,[Guard1,Guard2],[Result]}]).
get_all_employer_stat_in_department(CompanyID,DepartmentID) when is_integer(CompanyID) andalso is_list(DepartmentID) ->
    {Year,Month} = get_cur_year_and_month(),
    F = fun() ->
            CalcPrev5Month = fun({CurYear,CurMonth}) ->
                                case CurMonth of
                                    1 ->
                                        [{CurYear-1,9},{CurYear-1,10},{CurYear-1,11},{CurYear-1,12},{CurYear,CurMonth}];
                                    2 ->
                                        [{CurYear-1,10},{CurYear-1,11},{CurYear-1,12},{CurYear,1},{CurYear,CurMonth}];
                                    3 ->
                                        [{CurYear-1,11},{CurYear-1,12},{CurYear,1},{CurYear,2},{CurYear,CurMonth}];
                                    4 ->
                                        [{CurYear-1,12},{CurYear,1},{CurYear,2},{CurYear,3},{CurYear,CurMonth}];
                                    5 ->
                                        [{CurYear,1},{CurYear,2},{CurYear,3},{CurYear,4},{CurYear,CurMonth}];
                                    6 ->
                                        [{CurYear,2},{CurYear,3},{CurYear,4},{CurYear,5},{CurYear,CurMonth}];
                                    7 ->
                                        [{CurYear,3},{CurYear,4},{CurYear,5},{CurYear,6},{CurYear,CurMonth}];
                                    8 ->
                                        [{CurYear,4},{CurYear,5},{CurYear,6},{CurYear,7},{CurYear,CurMonth}];
                                    9 ->
                                        [{CurYear,5},{CurYear,6},{CurYear,7},{CurYear,8},{CurYear,CurMonth}];
                                    10 ->
                                        [{CurYear,6},{CurYear,7},{CurYear,8},{CurYear,9},{CurYear,CurMonth}];
                                    11 ->
                                        [{CurYear,7},{CurYear,8},{CurYear,9},{CurYear,10},{CurYear,CurMonth}];
                                    12 ->
                                        [{CurYear,8},{CurYear,9},{CurYear,10},{CurYear,11},{CurYear,CurMonth}]
                                end
                            end,
            EmployerList = get_all_empleyers(CompanyID,DepartmentID),
            DateList = lists:reverse(CalcPrev5Month({Year,Month})),
            GetEmployerDetail = fun(Employer,{QYear,QMonth}) ->
                                    QComanyID   = element(1,Employer#employer.id),
                                    QEmployerID = element(2,Employer#employer.id),
                                    QName = Employer#employer.name,
                                    case mnesia:read(employer_stat,{QComanyID,QEmployerID,QYear,QMonth},read) of
                                        [EmployerStat] ->
                                            {QName,QEmployerID,{QYear,QMonth},EmployerStat#employer_stat.charge};
                                        [] ->
                                            {QName,QEmployerID,{QYear,QMonth},0.0}
                                    end
                                end,
            GetAllEmployerDetail =  fun({QYear,QMonth}) ->
                                        lists:foldl(fun(Employer,Acc) -> [GetEmployerDetail(Employer,{QYear,QMonth})|Acc] end,[],EmployerList)
                                    end,
            StatList = lists:map(GetAllEmployerDetail,DateList),
            Combine =   fun({QName,QEmployerID,{QYear,QMonth},Charge},Dict) ->
                            case dict:find({QName,QEmployerID},Dict) of
                                {ok,_} ->
                                    dict:append({QName,QEmployerID}, {{QYear,QMonth},Charge}, Dict);
                                error ->
                                    dict:store({QName,QEmployerID}, [{{QYear,QMonth},Charge}], Dict) 
                            end
                        end,
            lists:keysort(1,dict:to_list(lists:foldl(Combine,dict:new(),lists:flatten(StatList))))
        end,
    {atomic,DepEmployerStats} = mnesia:transaction(F),
    tool:dep_employer_stat_to_load(DepEmployerStats).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_employee(EmployeeID) when is_tuple(EmployeeID) ->
    F = fun() ->
            case mnesia:read(employer,EmployeeID,read) of
                [Employee] ->
                    Employee;
                [] ->
                    []
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

change_password(EmployeeID,NewPassword) when is_tuple(EmployeeID) andalso is_list(NewPassword) ->
    F = fun() ->
            case mnesia:read(employer,EmployeeID,write) of
                [Employee] ->
                    mnesia:write(Employee#employer{password = NewPassword});
                [] ->
                    []
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

get_callstat(ID,Year,Month) when is_tuple(ID) andalso is_integer(Year) andalso is_integer(Month) ->
    F = fun() ->
            {CompanyID,EmployeeID} = ID,
            case mnesia:read(employer_stat,{CompanyID,EmployeeID,Year,Month},read) of
                [EmployerStat] ->
                    EmployerStat;
                [] ->
                    []
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_cur_year_and_month() ->
    {Year,Month,_Day} = date(),
    {Year,Month}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
login_by_name(ComName,Username,Password) ->
    case mnesia:dirty_index_read(company,ComName,#company.name) of
    [#company{id=Id}|_]-> login(Id,Username,Password);
    _->  "error"
    end.
login(CompanyID,Username,Password) ->
    utility:log("db:login ~p~n",[{CompanyID,Username,Password}]),
    F = fun() ->
            [Company] = mnesia:read(company,CompanyID),
            if
                Username =:= Company#company.admin andalso Password =:= Company#company.password ->
                    "ok";
                true ->
                    "error"
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

modify_password(CompanyID,Username,OldPassword,NewPassword) ->
    F = fun() ->
            [Company] = mnesia:read(company,CompanyID),
            if
                Username =:= Company#company.admin andalso OldPassword =:= Company#company.password ->
                    mnesia:write(Company#company{password = NewPassword}),
                    "ok";
                true ->
                    "error"
            end
        end,
    {atomic,Ack} = mnesia:transaction(F),
    Ack.

org_to_json(J)-> jsonerl:encode(J).
org_to_json_(Org=#org{department=DS})->
    NDS=[org_to_json(D)||D<-DS],
    (?record_to_struct(org,Org#org{department=NDS})).
    
save_cdr(Options,CallDetail)->
    {ServiceId, _UUID}=proplists:get_value(uuid,Options),
    if ServiceId=="xh"->
        Subgroup_id=proplists:get_value(subgroup_id,Options,""),
        Guid=proplists:get_value(guid,Options,""),
        Key=Subgroup_id++"_"++Guid,
        ?DB_WRITE(#cdr{key=Key,detail=CallDetail});
    true->
        void
    end.

get_a_cdr(Subgroup_id,Guid)->
    Key=Subgroup_id++"_"++Guid,
    Details=
    case ?DB_READ(cdr,Key) of
    {atomic,[#cdr{detail=Detail}]}-> [Detail];
    _-> []
    end,
    tool:detail_db_to_load(Details).


    
