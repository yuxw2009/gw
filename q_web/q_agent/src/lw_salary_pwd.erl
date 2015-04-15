-module(lw_salary_pwd).
-compile(export_all).
-include("lw.hrl").

checkSalaryUsrAndPwd(Usr,Pwd) ->
    F = fun() ->
    	    case mnesia:read(lw_salary_pwd,Usr) of
    	    	[#lw_salary_pwd{pwd = Pwd} = _Salary] -> ok;
    	        _ -> fail
    	    end
    	end,
    mnesia:activity(transaction,F).

initSalaryUsrAndPwd() ->
    F = fun() ->
    	    mnesia:write(#lw_salary_pwd{usr="admin" ,pwd = hex:to(crypto:md5("888888"))})
    	end,
    mnesia:activity(transaction,F),
    ok.

saveNewSalaryUsrAndPwd(Usr,Old,Pwd) ->
    F = fun() ->
    	    case mnesia:read(lw_salary_pwd,Usr,write) of
    	    	[#lw_salary_pwd{pwd = Old} = Salary] -> 
    	    	    mnesia:write(Salary#lw_salary_pwd{pwd = Pwd}),
    	    	    ok;
    	        _ -> 
    	            fail
    	    end
    	end,
    mnesia:activity(transaction,F).

getSalaryAdminPwd() ->
    F = fun() ->
            [#lw_salary_pwd{pwd = Pwd}] = mnesia:read(lw_salary_pwd,"admin"),
            Pwd
        end,
    mnesia:activity(transaction,F).