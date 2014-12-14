-module(erl_resample).
-on_load(load_my_nifs/0).
-export([up16k/2,down8k/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_resample", 0).

up16k(_L8k,_Passed) ->
	false.
down8k(_L16K) ->
	false.
