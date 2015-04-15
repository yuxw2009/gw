-module(lw_salary).
-compile(export_all).
-include("lw.hrl").

%%--------------------------------------------------------------------------------------
-define(MANAGEHTMLTILE,
<<"<table class=\"table table-bordered table-striped\">
    <tr>   
    <th>%%locate%%</th>
    <th>%%company%%</th>
    <th>%%id%%</th>
    <th>%%department%%</th>
    <th>%%name%%</th>
    <th>%%basic-salary%%</th>
    <th>%%post-salary%%</th>
    <th>%%allowance%%</th>
    <th>%%subsidy%%</th>
    <th>%%floating-salary%%</th>
    <th>%%bonus%%</th>
    <th>%%other-leave%%</th>
    <th>%%sick-leave%%</th>
    <th>%%real-wages%%</th>
    <th>%%endowment-insurance%%</th>
    <th>%%medical-insurance%%</th>
    <th>%%unemployment-insurance%%</th>
    <th>%%house-fund%%</th>
    <th>%%taxable-salary%%</th>
    <th>%%taxable-income%%</th>
    <th>%%tax-rate%%</th>
    <th>%%quick-calculation-deduction%%</th>
    <th>%%deduct-tax%%</th>
    <th>%%should-pay%%</th>
    <th>%%meal-cost%%</th>
    <th>%%traffic-cost%%</th>
    <th>%%other-cost%%</th>
    <th>%%real-pay%%</th>
    </tr>">>).

-define(MANAGEHTMLBODY,
<<"<tr class=\"odd gradeX\">
    <td>##locate##</td>
    <td>##company##</td>
    <td>##id##</td>
    <td>##department##</td>
    <td>##name##</td>
    <td>##basic-salary##</td>
    <td>##post-salary##</td>
    <td>##allowance##</td>
    <td>##subsidy##</td>
    <td>##floating-salary##</td>
    <td>##bonus##</td>
    <td>##other-leave##</td>
    <td>##sick-leave##</td>
    <td>##real-wages##</td>
    <td>##endowment-insurance##</td>
    <td>##medical-insurance##</td>
    <td>##unemployment-insurance##</td>
    <td>##house-fund##</td>
    <td>##taxable-salary##</td>
    <td>##taxable-income##</td>
    <td>##tax-rate##</td>
    <td>##quick-calculation-deduction##</td>
    <td>##deduct-tax##</td>
    <td>##should-pay##</td>
    <td>##meal-cost##</td>
    <td>##traffic-cost##</td>
    <td>##other-cost##</td>
    <td>##real-pay##</td>
    </tr>">>).

-define(MANAGEHTMLTAIL,"</table>").

%%--------------------------------------------------------------------------------------

-define(SINGLEHTML,
<<"<table class=\"salarytable\">
<tr class = \"title\">
    <td>%%locate%%</td>
    <td>%%company%%</td>
    <td>%%id%%</td>
    <td>%%department%%</td>
    <td>%%name%%</td>
    <td>%%basic-salary%%</td>
    <td>%%post-salary%%</td>
</tr>
<tr>
    <td>##locate##</td>
    <td>##company##</td>
    <td>##id##</td>
    <td>##department##</td>
    <td>##name##</td>
    <td>##basic-salary##</td>
    <td>##post-salary##</td>
</tr>
<tr class = \"title\">
    <td>%%allowance%%</td>
    <td>%%subsidy%%</td>
    <td>%%floating-salary%%</td>
    <td>%%bonus%%</td>
    <td>%%other-leave%%</td>
    <td>%%sick-leave%%</td>
    <td>%%real-wages%%</td>
</tr>
<tr>
    <td>##allowance##</td>
    <td>##subsidy##</td>
    <td>##floating-salary##</td>
    <td>##bonus##</td>
    <td>##other-leave##</td>
    <td>##sick-leave##</td>
    <td>##real-wages##</td>
</tr>
<tr class = \"title\">
    <td>%%endowment-insurance%%</td>
    <td>%%medical-insurance%%</td>
    <td>%%unemployment-insurance%%</td>
    <td>%%house-fund%%</td>
    <td>%%taxable-salary%%</td>
    <td>%%taxable-income%%</td>
    <td>%%tax-rate%%</td>
</tr>
<tr>
    <td>##endowment-insurance##</td>
    <td>##medical-insurance##</td>
    <td>##unemployment-insurance##</td>
    <td>##house-fund##</td>
    <td>##taxable-salary##</td>
    <td>##taxable-income##</td>
    <td>##tax-rate##</td>
</tr>
<tr class = \"title\">
    <td>%%quick-calculation-deduction%%</td>
    <td>%%deduct-tax%%</td>
    <td>%%should-pay%%</td>
    <td>%%meal-cost%%</td>
    <td>%%traffic-cost%%</td>
    <td>%%other-cost%%</td>
    <td>%%real-pay%%</td>
</tr>
<tr>
    <td>##quick-calculation-deduction##</td>
    <td>##deduct-tax##</td>
    <td>##should-pay##</td>
    <td>##meal-cost##</td>
    <td>##traffic-cost##</td>
    <td>##other-cost##</td>
    <td>##real-pay##</td>
</tr>
</table>">>).

%%--------------------------------------------------------------------------------------

trans(ID, Lan) -> t(ID, Lan).

t("locate", ch) -> "地点";
t("company", ch) -> "类别";
t("id", ch) -> "工号";
t("department", ch) -> "部门";
t("name", ch) -> "姓名";
t("basic-salary", ch) -> "基本工资";
t("post-salary", ch) -> "岗位/绩效工资";
t("allowance", ch) -> "津贴";
t("subsidy", ch) -> "电脑补贴";
t("floating-salary", ch) -> "浮动工资";
t("bonus", ch) -> "奖金";
t("other-leave", ch) -> "事假/缺勤/迟到/矿工";
t("sick-leave", ch) -> "病假";
t("real-wages", ch) -> "本月实际工资";
t("endowment-insurance", ch) -> "代扣养老保险";
t("medical-insurance", ch) -> "代扣医疗保险";
t("unemployment-insurance", ch) -> "代扣失业保险";
t("house-fund", ch) -> "代扣住房公积金";
t("taxable-salary", ch) -> "计税工资";
t("taxable-income", ch) -> "应纳税所得额";
t("tax-rate", ch) -> "税率";
t("quick-calculation-deduction", ch) -> "速算扣除数";
t("deduct-tax", ch) -> "应扣个税";
t("should-pay", ch) -> "本月应发";
t("meal-cost", ch) -> "扣除（餐费）";
t("traffic-cost", ch) -> "扣除（班车费）";
t("other-cost", ch) -> "扣除（其他）";
t("real-pay", ch) -> "本月实发";
t(Content, en) -> Content.

%%--------------------------------------------------------------------------------------

eval("地点") -> "locate";
eval("类别") -> "company";
eval("工号") -> "id";
eval("部门") -> "department";
eval("姓名") -> "name";
eval("基本工资") -> "basic-salary";
eval("岗位/绩效工资") -> "post-salary";
eval("津贴") -> "allowance";
eval("电脑补贴") -> "subsidy";
eval("浮动工资") -> "floating-salary";
eval("奖金") -> "bonus";
eval("事假/缺勤/迟到/矿工") -> "other-leave";
eval("病假") -> "sick-leave";
eval("本月实际工资") -> "real-wages";
eval("代扣养老保险") -> "endowment-insurance";
eval("代扣医疗保险") -> "medical-insurance";
eval("代扣失业保险") -> "unemployment-insurance";
eval("代扣住房公积金") -> "house-fund";
eval("计税工资") -> "taxable-salary";
eval("应纳税所得额") -> "taxable-income";
eval("税率") -> "tax-rate";
eval("速算扣除数") -> "quick-calculation-deduction";
eval("应扣个税") -> "deduct-tax";
eval("本月应发") -> "should-pay";
eval("扣除（餐费）") -> "meal-cost";
eval("扣除（班车费）") -> "traffic-cost";
eval("扣除（其他）") -> "other-cost";
eval("本月实发") -> "real-pay";
eval(Other) -> Other.

%%--------------------------------------------------------------------------------------

run(MarkName,FileName,Y,M) ->
    F = fun(SalaryInfo,Index) ->
            insert_db(SalaryInfo,Index,Y,M),
            Index + 1
        end,
    SalaryInfos = read_file(FileName),
    lists:foldl(F,1,SalaryInfos),
    setPublicFalse(MarkName,Y,M),
    ok.

read_file(FileName) ->
    {ok, Binary} = file:read_file(FileName),
    Lines = string:tokens(binary_to_list(Binary),"\r\n"),
    [parse_line(Line)||Line<-Lines].

parse_line(Line) ->
    ParseKeyVal = 
        fun(KeyVal) ->
            case string:tokens(KeyVal,":") of
            	[Key] -> {Key,""};
            	[Key,Value] -> {Key,Value}
            end
        end,
    [ParseKeyVal(KeyValStr)||KeyValStr <- string:tokens(Line,"@")].

%%--------------------------------------------------------------------------------------

str_cancel_char(Name,Char) ->
    string:join(string:tokens(Name,Char),"").

insert_db(SalaryKeyVals,Index,Y,M) ->
    {_,MarkName}  = lists:keyfind("公司",1,SalaryKeyVals),
    {_,EID}       = lists:keyfind("工号",1,SalaryKeyVals),
    {_,InputName} = lists:keyfind("姓名",1,SalaryKeyVals),
    Module = lw_config:get_user_module(),
    OrgID  = Module:get_org_id_by_mark_name(MarkName),
    UUID   = Module:get_user_id(OrgID,EID),
    SavedName = getUserName(UUID),
    case str_cancel_char(InputName," ") =:= str_cancel_char(SavedName," ") of
        true ->
            F1= fun({Key,Val}) ->
                    case Val of
                        "" -> {Key,Val};
                        _  -> {Key,do_encrypt(EID,Val)}
                    end
                end,
            SalaryInfo = lists:map(F1,SalaryKeyVals),
            F = fun() ->
            	    case mnesia:read(lw_salary,{OrgID,Y,M},write) of
            	    	[]  -> 
                            mnesia:write(#lw_salary{key = {OrgID,Y,M},option = dict:store({UUID,EID}, {Index,SalaryInfo}, dict:new())});
            	    	[#lw_salary{option = D} = Salary] -> 
                            mnesia:write(Salary#lw_salary{option = dict:store({UUID,EID}, {Index,SalaryInfo}, D)})
            	    end
                end,
            mnesia:activity(transaction,F);
        false ->
            logger:log(error,"lw_salary wrong name match:uuid:~p orgid:~p eid:~p inputname:~p savedname~p ~n",[UUID,OrgID,EID,InputName,SavedName])
    end.

%%--------------------------------------------------------------------------------------

do_get_salary_info(OrgID,Y,M) ->
    Sort   = fun({_,{Key1,_}},{_,{Key2,_}}) -> Key1 < Key2 end,
    F = fun() ->
            D = 
                case mnesia:read(lw_salary,{OrgID,Y,M}) of
                    [] -> dict:new();
                    [#lw_salary{option=Dict}] -> Dict
                end,
            [{A,B}||{A,{_,B}}<-lists:sort(Sort,dict:to_list(D))]
        end,
    mnesia:activity(transaction,F).

do_get_salary_info(OrgID,UUID,EID,Y,M) ->
    F = fun() ->
    	    case mnesia:read(lw_salary,{OrgID,Y,M}) of
    	    	[] -> {{UUID,EID},[]};
    	    	[#lw_salary{option=Dict}] -> 
                    case dict:find({UUID,EID},Dict) of 
                        {ok,{_,Val}} -> {{UUID,EID},Val};
                        error    -> {{UUID,EID},[]}
                    end
    	    end
    	end,
    case getPublic(OrgID,Y,M) of
        false -> {{UUID,EID},[]};
        true  -> mnesia:activity(transaction,F)
    end.

%%--------------------------------------------------------------------------------------

make_key(Key) ->
    list_to_binary(hex:to(crypto:md5(Key))).

do_encrypt(Key,Content) ->
    crypto:aes_ctr_encrypt(make_key(Key), <<"livecomhk-caspar">>, list_to_binary(Content)).

do_decrypt(Key,Content) ->
    binary_to_list(crypto:aes_ctr_decrypt(make_key(Key), <<"livecomhk-caspar">>, Content)).

%%--------------------------------------------------------------------------------------

scan(<<"%%", Rest/binary>>, ID, Acc, in, EID, Dict) ->
    scan(Rest,[],[trans(lists:reverse(ID), ch)|Acc],out, EID, Dict);
scan(<<"%%", Rest/binary>>, [], Acc, out, EID, Dict) ->
    scan(Rest,[],Acc,in, EID, Dict);
scan(<<"##", Rest/binary>>, ID, Acc, in, EID, Dict) ->
    scan(Rest,[],[get_value(lists:reverse(ID),EID,Dict)|Acc],out, EID, Dict);
scan(<<"##", Rest/binary>>, [], Acc, out, EID, Dict) ->
    scan(Rest,[],Acc,in, EID, Dict);
scan(<<I, Rest/binary>>, ID, Acc, in, EID, Dict) ->
    scan(Rest, [I|ID], Acc, in, EID, Dict);
scan(<<I, Rest/binary>>, [], Acc, out, EID, Dict) ->
    scan(Rest, [], [I|Acc], out, EID, Dict);
scan(<<>>, _, Acc, _, _, _) ->
    lists:reverse(Acc).
scan(Bin, EID, Dict) -> scan(Bin, [], [], out, EID, Dict).

%%--------------------------------------------------------------------------------------

get_value(Key,EID,Dict) ->
    case dict:find(Key,Dict) of
        {ok,Val} -> do_decrypt(EID,Val);
        error    -> ""
    end.

%%--------------------------------------------------------------------------------------

trans_to_html({{_,_},[]},both) ->
    "";
trans_to_html({{_,EID},SalaryInfos},both) when is_list(SalaryInfos) ->
    F = fun({Key,Val}) -> 
            {"<th>" ++ Key ++ "</th>",
             "<td>" ++ do_decrypt(EID,Val) ++ "</td>"} 
        end,
    lists:unzip(lists:map(F,SalaryInfos));
trans_to_html({{_,_},[]},value) ->
    "";
trans_to_html({{_,EID},SalaryInfos},value) when is_list(SalaryInfos) ->
    F = fun({_,Val}) -> 
            "<td>" ++ do_decrypt(EID,Val) ++ "</td>" 
        end,
    lists:map(F,SalaryInfos).

%%--------------------------------------------------------------------------------------

get_salary_info(MarkName,Y,M) when is_list(MarkName) ->
    Module = lw_config:get_user_module(),
    OrgID  = Module:get_org_id_by_mark_name(MarkName),
    Pwd  = lw_salary_pwd:getSalaryAdminPwd(),
    HTML = 
        case do_get_salary_info(OrgID,Y,M) of
            [] ->
                "";
            [H|T] ->
                {TH,TD} = trans_to_html(H,both),
                Others  = lists:map(fun(X) -> trans_to_html(X,value) end,T),
                Joins   = lists:map(fun(X) -> string:join(X,"") end,Others),
                TrJoins = lists:map(fun(X) -> "<tr class = \"title\">" ++ X ++ "</tr>" end,Joins),
                "<tr class = \"title\">" ++ string:join(TH,"") ++ "</tr>" ++
                "<tr class = \"title\">" ++ string:join(TD,"") ++ "</tr>" ++
                string:join(TrJoins,"")
        end,
    {ok,getPublic(OrgID,Y,M),lw_lib:easyEncrypt(
        Pwd,
        "<table class=\"table table-bordered table-striped\">" ++ HTML ++ "</table>")};
get_salary_info(UUID,Y,M) when is_integer(UUID) ->
    {OrgID,EID} = getUserOrgIDAndEID(UUID),
    MD5 = getUserMD5(OrgID,EID),
    SalaryInfo = do_get_salary_info(OrgID,UUID,EID,Y,M),
    try
        HTML = 
            case trans_to_html(SalaryInfo,both) of
                "" -> "";
                {TH,TD} -> combineby7(TH,TD)
            end,
        lw_lib:easyEncrypt(MD5,
            "<table class=\"salarytable\">" ++ HTML ++ "</table>")
    catch
        _:_ -> ""
    end.

%%--------------------------------------------------------------------------------------

combineby7([],[]) ->
    "";
combineby7(TH,TD) when length(TH) =:= length(TD) andalso length(TD) < 7 ->
    RestLen = 7 - length(TD),
    RestTH  = lists:duplicate(RestLen, "<th></th>"),
    RestTD  = lists:duplicate(RestLen, "<td></td>"),
    "<tr class = \"title\">" ++ string:join(TH ++ RestTH,"") ++ "</tr>" ++
    "<tr>" ++ string:join(TD ++ RestTD,"") ++ "</tr>";
combineby7(TH,TD) when length(TH) =:= length(TD) ->
    SubTH = lists:sublist(TH,1,7),
    SubTD = lists:sublist(TD,1,7),
    "<tr class = \"title\">" ++ string:join(SubTH,"") ++ "</tr>" ++
    "<tr>" ++ string:join(SubTD,"") ++ "</tr>" ++ 
    combineby7(lists:nthtail(7,TH),lists:nthtail(7,TD)).

%%--------------------------------------------------------------------------------------

getUserName(UUID) ->
    F = fun() ->
            case mnesia:read(lw_instance,UUID) of
                [] ->
                    "";
                [#lw_instance{employee_name = UsrName}] ->
                    UsrName
            end
        end,
    mnesia:activity(transaction,F).

getUserOrgIDAndEID(UUID) ->
    F = fun() ->
            [#lw_instance{org_id=OrgID,employee_id=EID}] = mnesia:read(lw_instance,UUID),
            {OrgID,EID}
        end,
    mnesia:activity(transaction,F).

getUserMD5(OrgID,EID) ->
    F = fun() ->
            [#lw_auth{md5 = MD5}] = mnesia:read(lw_auth,{OrgID,EID}),
            MD5
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

setPublicTrue(MarkName,Y,M) ->
    Module = lw_config:get_user_module(),
    OrgID  = Module:get_org_id_by_mark_name(MarkName),
    F = fun() ->
            mnesia:write(#lw_salary_public{key = {OrgID,Y,M},public = true})
        end,
    mnesia:activity(transaction,F).

setPublicFalse(MarkName,Y,M) ->
    Module = lw_config:get_user_module(),
    OrgID  = Module:get_org_id_by_mark_name(MarkName),
    F = fun() ->
            mnesia:write(#lw_salary_public{key = {OrgID,Y,M},public = false})
        end,
    mnesia:activity(transaction,F).

getPublic(OrgID,Y,M) ->
    F = fun() ->
            case mnesia:read(lw_salary_public,{OrgID,Y,M}) of
                [] -> false;
                [#lw_salary_public{public = Public}] -> Public
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------