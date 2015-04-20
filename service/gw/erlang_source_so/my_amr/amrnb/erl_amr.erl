-module(erl_amr).
-on_load(load_my_nifs/0).
-export([icdc/2,xdec/2,xenc/2,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_amr", 0).

icdc(_Mode,_Rate) ->
	false.
	
xdec(_Ctx,_Frame) ->
	false.
	
xenc(_Ctx,_Frame) ->
	false.
	
xdtr(_Ctx) ->
	false.
