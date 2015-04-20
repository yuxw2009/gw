-module(account).

-compile(export_all).
-define(ACCOUNT_TBL, ?MODULE).
-record(?ACCOUNT_TBL, {apikey, secret, servs}).
-record(incr_table, {key,value}).
-include("db_op.hrl").

init_once()->
	mnesia:stop(),
	mnesia:create_schema([node()]),
	mnesia:start(),
	mnesia:create_table(?ACCOUNT_TBL, [{disc_copies, [node()]},{attributes, record_info(fields, ?ACCOUNT_TBL)}]),
	create_incr_table(),
	mnesia:stop().
create_incr_table()->mnesia:create_table(incr_table, [{disc_copies, [node()]},{attributes, record_info(fields, incr_table)}]).
start()->
	mnesia:start(),
	{A,B,C} = now(),
	random:seed(A,B,C),
    case mnesia:wait_for_tables([?ACCOUNT_TBL], 3000) of
	ok ->
	    ok;
	{timeout, _Bad_Tab_List} ->
	    throw("timeout when waiting table "++?ACCOUNT_TBL);
	{error, Reason} ->
	    throw("error when waiting table "++?ACCOUNT_TBL ++" reason: "++Reason)
    end.

create(Services)->
	Apikey=apikey(),
	Secret=base64:encode(integer_to_list(random:uniform(10000000000000))),
	?DB_WRITE(#?ACCOUNT_TBL{apikey=Apikey, secret=Secret, servs=Services}),
	[Apikey,Secret].

apikey()-> 
	I=mnesia:dirty_update_counter(incr_table, apikey, 1),
	B=100000000,
	string:substr(integer_to_list(B+I), 2).

secret(Ak) when is_binary(Ak)-> secret(binary_to_list(Ak));
secret(Ak)->
	{atomic, [#?ACCOUNT_TBL{secret=Scr}]} = ?DB_READ(?ACCOUNT_TBL, Ak),
	binary_to_list(Scr).
