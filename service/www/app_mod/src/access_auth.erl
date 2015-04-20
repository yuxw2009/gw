-module(access_auth).
-export([check_origin/1, check_token/1,allow_origins/0]).

check_origin(Origin) -> true.
%    lists:member(Origin, allow_origins()).


allow_origins()->
    ["http://www.10086china.com",
	 "https://www.10086china.com",
     "http://test.10086china.com",
	 "https://test.10086china.com", 
	 "http://fzd.lw.mobile",
	 "http://www.shuobar.cn",
	 "https://www.shuobar.cn",
	 "http://14.17.107.196",
	 "http://test.shuobar.cn",
	 "https://test.shuobar.cn"].

check_token(Token) ->
    true.