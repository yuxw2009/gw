-module(erl_vad).
-on_load(load_my_nifs/0).
-export([ivad/0,xset/2,xprcs/3,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_vad", 0).

ivad() ->
	false.
	
xset(_Ctx,_Mode) ->
	false.
	
xprcs(_Ctx,_Frame,_Rate) ->
	false.
	
xdtr(_Ctx) ->
	false.
