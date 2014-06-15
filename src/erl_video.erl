-module(erl_video).
-on_load(load_my_nifs/0).
-export([xscl/5]).

load_my_nifs() ->
      erlang:load_nif("./erl_video", 0).

xscl(_YUV,_SW,_SH,_DW,_DH) ->
	false.