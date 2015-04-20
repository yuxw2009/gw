-module(id_generator).
-compile(export_all).

%% extra APIs.
new(Prefix) when is_atom(Prefix) ->
    spawn(fun() -> id_genr_loop(atom_to_list(Prefix), 0) end);
new(Prefix) when is_list(Prefix)->
    spawn(fun() -> id_genr_loop(Prefix, 0) end);
new(_) -> create_id_generator_failed.

delete(Genr) ->
    Genr ! stop,
    ok.

gen(Genr) ->
    Genr ! {gen, self()},
    receive
    	{new_generated_id, NewID} -> NewID
    end.

%%
id_genr_loop(Prefix, CurCount) ->
    receive
   	    {gen, From} ->
   	        From ! {new_generated_id, Prefix++"_"++integer_to_list(CurCount)},
   	        id_genr_loop(Prefix, CurCount + 1);
   	    stop ->
   	        ok
   	end.

%%%%
test() ->
   Gnr = new("aabb"),
   "aabb_0" = gen(Gnr),
   "aabb_1" = gen(Gnr),
   ok.



