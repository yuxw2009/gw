-module(mockpeerconn).
-compile(export_all).


establish(Rid, Pcid, PtI1, PtI2, Offerer) ->
    Pc = mockobj:start(),
    %%io:format("new parti:~p ~n", [Pt]),
    Pc ! {call_api, {establish, {Rid, Pcid, PtI1, PtI2, Offerer}}},
    Pc.

release(Pc) ->
    Pc ! {call_api, {release, {Pc}}}.


