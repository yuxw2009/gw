-module(u_mix).
-on_load(load_my_nifs/0).
-compile(export_all).

load_my_nifs() ->
      erlang:load_nif("./u_mix", 0).

x(_L) -> false.