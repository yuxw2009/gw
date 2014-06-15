-module(erl_vp8).
-on_load(load_my_nifs/0).
-export([idec/0,xdec/2,gdec/1,xdtr/2]).
-export([ienc/3,xenc/5,genc/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_vp8_temporal", 0).

idec() ->
	false.
ienc(_W,_H,_BR) ->
	false.
	
xdec(_Ctx,_Frame) ->
	false.
gdec(_Ctx) ->
	false.
	
xenc(_Ctx,_Frame,_Pts,_Dur,_Flags) ->
	false.
genc(_Ctx) ->
	false.
	
xdtr(_Ctx,_Type) ->
	false.
