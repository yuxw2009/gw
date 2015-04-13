-module(erl_amix).
-on_load(load_my_nifs/0).
-compile(export_all).

load_my_nifs() ->
      erlang:load_nif("./erl_amix", 0).

x(_L) -> false.
lx(_L)-> false.
phn(_A,_B) -> false.