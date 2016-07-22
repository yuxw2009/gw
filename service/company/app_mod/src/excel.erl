-module(excel).
-compile(export_all).
-include("db.hrl").

%-define(DIR,"D:\\livecom\\livecom work\\lwork\\www\\lwork\\tmp\\").
-define(DIR,"/home/ayu/www/zte/tmp/").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%get_detail(StatIDs) when is_list(StatIDs) ->
%%    F1= fun({ComID,EID,Y,M,}) -> 
%%            [Data]  = mnesia:read(employer_stat,{ComID,EID,Y,M}),
%%            Data#employer_stat.details
%%        end,
%%    F2= fun() -> [F1(StatID)||StatID<-StatIDs] end,
%%    mnesia:activity(transaction,F2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

outfile(CompanyID,Year,Month) ->
    StatIDs    = get_stat_id(CompanyID,Year,Month),
    NewStatIDs = lists:keysort(6,append_employee_name_and_department(CompanyID,StatIDs)),
    StatData   = get_stat_data(NewStatIDs),
    Stats      = lists:zip(NewStatIDs,StatData),
    write_to_file(Stats,Year,Month),
    CMD = "python -c \"import outfile;outfile.outfile(" ++ integer_to_list(Year) ++ "," ++ integer_to_list(Month) ++ ")\"",
    case os:cmd(CMD) of
        "ok" -> {ok,"zte-ltalk-" ++ integer_to_list(Year) ++ "-" ++ integer_to_list(Month) ++ ".xls"};
        []   -> error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_stat_data(StatIDs) when is_list(StatIDs) ->
    F1= fun({ComID,EID,Y,M,_,_}) ->
            case mnesia:read(employer_stat,{ComID,EID,Y,M}) of
                [] ->
                    {0.0,0.0};
                [Data] ->
                    {Data#employer_stat.time,Data#employer_stat.charge}
            end
    	end,
    F2= fun() -> [F1(StatID)||StatID<-StatIDs] end,
    mnesia:activity(transaction,F2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_stat_id(CompanyID,Year,Month) ->
    AllDetailID   = [{ComID,EID,DY,DM}||{ComID,EID,DY,DM}<-get_all_stat_id(),{CompanyID,Year,Month}=:={ComID,DY,DM}],
    AllEmployeeID = [{ComID,EID,Year,Month}||{ComID,EID}<-get_all_employee_id(),CompanyID =:= ComID],
    lists:usort(AllDetailID ++ AllEmployeeID).

get_all_employee_id() ->
    F = fun() -> mnesia:all_keys(employer) end,
    mnesia:activity(transaction,F).

get_all_stat_id() ->
    F = fun() -> mnesia:all_keys(employer_stat) end,
    mnesia:activity(transaction,F).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

append_employee_name_and_department(CompanyID,StatIDs) when is_list(StatIDs) ->
    F1= fun({ComID,EID,Year,Month}) when (ComID =:= CompanyID) ->
    	    case mnesia:read(employer,{CompanyID,EID}) of
    	    	[] -> 
    	    	    {CompanyID,EID,Year,Month,"----","----"};
    	    	[Employee] -> 
    	    	    {CompanyID,EID,Year,Month,Employee#employer.name,Employee#employer.department}
    	    end
        end,
    F2= fun() -> [F1(StatID)||StatID<-StatIDs] end,
    NewStatIDs = mnesia:activity(transaction,F2),
    Org = db:load_org(CompanyID),
    [{ComID,EID,Y,M,EName,get_department_name(Org,EDep)}||{ComID,EID,Y,M,EName,EDep}<-NewStatIDs].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_department_name(_,"----")  -> 
    "----";
get_department_name(Org,[_H|T]) ->
    get_department_name_iter(Org#org.department,T,[]).

get_department_name_iter(_,[],Acc) ->
    string:join(lists:reverse(Acc), "\\");
get_department_name_iter(Org,[H|T],Acc) ->
    NewOrg =  lists:keyfind(H,#org.id,Org),
    get_department_name_iter(NewOrg#org.department,T,[[NewOrg#org.name]|Acc]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

write_to_file(Stats,Year,Month) ->
    {ok, S}     = file:open(?DIR ++ "stat", [write]),
    {Start,End} = get_start_end(Year,Month),
    F = fun({{_,EID,_,_,EName,EDep},{Duration,Charge}}) ->
    	    io:format(S,"~s,~s,~s,~s,~p,~p,~s,~s~n",[EDep,EID,EName,"国际长途",Charge,Duration,Start,End])
        end,
    [F(Stat)||Stat<-Stats],
    file:close(S).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_start_end(Year,Month) ->
    case Month of
        1 ->
            {integer_to_list(Year) ++ "-01-01",integer_to_list(Year) ++ "-01-31"};
        2 ->
            case Year rem 400 of
            	0 ->
            	    {integer_to_list(Year) ++ "-02-01",integer_to_list(Year) ++ "-02-29"};
            	_ ->
            	    if
            	    	((Year rem 4) =:= 0) andalso ((Year rem 100) =/= 0) ->
            	    		{integer_to_list(Year) ++ "-02-01",integer_to_list(Year) ++ "-02-29"};
            	    	true ->
            	    	    {integer_to_list(Year) ++ "-02-01",integer_to_list(Year) ++ "-02-28"}
            	    end
            end;
        3 ->
            {integer_to_list(Year) ++ "-03-01",integer_to_list(Year) ++ "-03-31"};
        4 ->
            {integer_to_list(Year) ++ "-04-01",integer_to_list(Year) ++ "-04-30"};
        5 ->
            {integer_to_list(Year) ++ "-05-01",integer_to_list(Year) ++ "-05-31"};
        6 ->
            {integer_to_list(Year) ++ "-06-01",integer_to_list(Year) ++ "-06-30"};
        7 ->
            {integer_to_list(Year) ++ "-07-01",integer_to_list(Year) ++ "-07-31"};
        8 ->
            {integer_to_list(Year) ++ "-08-01",integer_to_list(Year) ++ "-08-31"};
        9 ->
            {integer_to_list(Year) ++ "-09-01",integer_to_list(Year) ++ "-09-30"};
        10 ->
            {integer_to_list(Year) ++ "-10-01",integer_to_list(Year) ++ "-10-31"};
        11 ->
            {integer_to_list(Year) ++ "-11-01",integer_to_list(Year) ++ "-11-30"};
        12 ->
            {integer_to_list(Year) ++ "-12-01",integer_to_list(Year) ++ "-12-31"}
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%mnesia:dirty_write(#employer_stat{id={1,"123",2010,11},count=1,time=10.0,charge=2.0,details=[#employer_detail{caller="0086123",called="0086456",start_time={{2012,11,5},{11,11,11}},end_time={{2012,11,5},{11,22,11}},duration=10.0,rate=0.5,charge=2.0}]}).
