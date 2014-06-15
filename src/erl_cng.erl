-module(erl_cng).
-on_load(load_my_nifs/0).
-export([ienc/3,idec/0,xenc/3,xupd/2,xgen/2,xdtr/2]).

load_my_nifs() ->
      erlang:load_nif("./erl_cng", 0).

ienc(_SampleRate_or_ID, _SidUpdate, _CNGParams) ->
	false.
idec() ->
	false.
	
xenc(_Ctx,_Frame,_ForceSid) ->
	false.

xupd(_Ctx,_Sid) ->
	false.
xgen(_Ctx,_Samples) ->
	false.
	
xdtr(_Ctx,_Type) ->
	false.
