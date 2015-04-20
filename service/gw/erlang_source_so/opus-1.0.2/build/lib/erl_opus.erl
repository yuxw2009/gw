-module(erl_opus).
-on_load(load_my_nifs/0).
-export([icdc/2,xdec/2,xenc/2,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_opus", 0).

icdc(_BitRate,_Complex) ->
	false.
	
xdec(_Ctx,_Frame) ->
	false.
	
xenc(_Ctx,_Frame) ->
	false.
	
xdtr(_Ctx) ->
	false.
