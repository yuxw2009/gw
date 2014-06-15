-module(erl_ilbc).
-on_load(load_my_nifs/0).
-export([icdc/1,xdec/2,xplc/1,xenc/2,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_ilbc", 0).

icdc(_Mode) ->
	false.
	
xdec(_Ctx,_Frame) ->
	false.
xplc(_Ctx) ->
	false.
	
xenc(_Ctx,_Frame) ->
	false.
	
xdtr(_Ctx) ->
	false.
