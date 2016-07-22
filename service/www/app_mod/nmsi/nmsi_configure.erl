-module(nmsi_configure).
-export([ip/0,port/0,nmsi_account/0,nmsi_pwd/0,ss_account/0,ss_pwd/0,heart_interval/0,heart_retry/0,ss_pwd1/0]).

ip() ->
    {0,0,0,0}.
    %{10,32,3,52}.

port() ->
    5321.

nmsi_account() ->
    "kylintvboss".

nmsi_pwd() ->
    "13051506".

ss_account() ->
    "root".

ss_pwd() ->
    "livecomlaoss".

ss_pwd1() ->
    "LIVECOMLAOSS".

heart_interval() ->
    120 * 1000.

heart_retry() ->
    3.
