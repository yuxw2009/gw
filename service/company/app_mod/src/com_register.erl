-module(com_register).

-compile(export_all).

-include("db.hrl").

authen_url(UserId, Password) ->
    "http://10.30.2.114:9086/LdapWeb/servlet/LdapServlet?userID=" ++ UserId ++ "&" ++ 
        "passWord="++ Password ++ "&sysFlag=MOBILE_IM_SYS".

check_authen("ZTE", "0131000051", Pwd) ->
    utility:log("0131000051 authen pwd:~p~n",[Pwd]),
    true;
check_authen("ZTE", UserId, Password) ->
    inets:start(),
    case httpc:request(authen_url(UserId, Password)) of
    	{ok,{_,_,"0000"}} -> true;
    	_                 -> false
    end.

register_user(Account, Password) ->
    [UserId, CompanyName] = string:tokens(Account,"@"),
    case check_authen(CompanyName, UserId, Password) of
    	true ->
    	    case db:get_employee({1, UserId}) of
    	    	[] -> failed;
    	    	Employee ->
    	    	    NewPassword = gen_password(),
    	    	    case rpc:call('service@10.32.3.38', card, add_card, [Account, NewPassword, Employee#employer.balance, "ZTE", "ZTE"]) of
    	    	    	ok -> {ok, Account, NewPassword};
    	                _   -> failed
                     end
    	    end;

    	false ->
    	    failed
    end.

gen_password() ->
    random:seed(erlang:now()),
    random_str(8, list_to_tuple("qwertyQWERTY1234567890")).

random_str(0, _Chars) -> [];
random_str(Len, Chars) -> [random_char(Chars)|random_str(Len-1, Chars)].
random_char(Chars) -> element(random:uniform(tuple_size(Chars)), Chars).
