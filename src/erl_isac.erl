-module(erl_isac).
-on_load(load_my_nifs/0).
-export([icdc/3,xdec/4,xplc/2,xenc/2,xdtr/1]).

load_my_nifs() ->
      erlang:load_nif("./erl_isac", 0).

icdc(_Mode,_BitRate,_FrameLen) ->
	false.
	
xdec(_Ctx,_Frame,_Samples,_TsInterval) ->
	false.
xplc(_Ctx,_Samples) ->
	false.
	
xenc(_Ctx,_Frame) ->
	false.
	
xdtr(_Ctx) ->
	false.
