-module(mockbrowser).
-compile(export_all).

start_test_pc() ->
    register(mbc_test_pc, spawn(fun() -> test_pc_loop([]) end)).

end_test_pc()->
    mbc_test_pc ! stop,
    ok.

last_received() ->
    mbc_test_pc ! {last_received, self()},
    receive
        {last_received, A} ->
            A
        after 100 ->
            none
    end.

test_pc_loop(L) ->
    receive
    	{send, D} ->
    	    test_pc_loop([D|L]);
    	{last_received, Pid} ->
    	    [L1|_] = L,
            Pid ! {last_received, L1},
    	    test_pc_loop(L);
    	stop ->
    	    ok
    end.


new_pc(Ptid, ConnID, MediaC, Dir) ->
    mbc_test_pc ! {send, {new_pc, Ptid, ConnID, MediaC, Dir}},
   ok.

invite_pc(Ptid, ConnID, MediaC, Dir, SDP) ->
    mbc_test_pc ! {send, {invite_pc, Ptid, ConnID, MediaC, Dir, SDP}},
   ok.

peer_answered(Ptid, ConnID, SDP) ->
    mbc_test_pc ! {send, {peer_answered, Ptid, ConnID, SDP}},
   ok.

require_close(Ptid, ConnID) ->
    mbc_test_pc ! {send, {require_close, Ptid, ConnID}},
   ok.

%%
start_mockbrowser() -> 
    spawn(fun() -> mockbrowser_loop([]) end).

stop_mockbrowser(Pid) ->
    Pid ! stop.

last_received(Pid) ->
    Pid ! {last_received, self()},
    receive
        {last_received, A} ->
            A
        after 100 ->
            none
    end.

mockbrowser_loop(L) ->
    receive
        {send, D} ->
            mockbrowser_loop([D|L]);
        {last_received, Pid} ->
            case L of
                [] ->
                    Pid ! {last_received, none},
                     mockbrowser_loop(L);
                [L1|T] ->
                    Pid ! {last_received, L1},
                    mockbrowser_loop(T)
            end;
        stop ->
            ok
    end.
