-module(access_auth).
-export([check_origin/1, check_token/1,allow_origins/0]).

check_origin(Origin) -> true.
%    lists:member(Origin, allow_origins()).


allow_origins()->
    [	 "https://lwork.hk", "http://lwork.hk","http://119.29.62.190"].

check_token(Token) ->
    true.