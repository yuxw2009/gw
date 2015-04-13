-module(erl_g729).
-on_load(load_my_nifs/0).
-export([icdc/0,xdec/2,xenc/2,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_g729", 0).

icdc() ->
	false.
	
xdec(_Ctx,_Frame) ->
	false.
	
xenc(_Ctx,_Frame) ->
	false.
	
xdtr(_Ctx) ->
	false.
