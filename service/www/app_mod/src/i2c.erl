-module(i2c).
-on_load(load_my_nifs/0).
-export([findLocal/1]).

load_my_nifs() ->
      erlang:load_nif("./i2c", 0).

findLocal(_) ->
	false.
