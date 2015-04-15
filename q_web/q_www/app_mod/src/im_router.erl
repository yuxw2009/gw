-module(im_router).
-compile(export_all).

%%-------------------------------------------------------------------------------------------------

start() ->
    F = fun() ->
    	    TID = ets:new(im_router,[named_table,set,public,{keypos,1}]),
    	    loop({TID,1})
    	end,
    register(im_router,spawn(fun() -> F() end)).

%%-------------------------------------------------------------------------------------------------

loop({TID,SessionID}) ->
    receive
    	{Command,From,Args} ->
    	    NextSessionID = 
	    	    try
	    	    	{Value,NewSessionID} = apply(im_router,Command,[[{TID,SessionID}|Args]]),
	    	    	From ! Value,
	    	    	NewSessionID
	    	    catch
	    	    	_:Reason ->
                        io:format("~p~n",[Reason]),
	    	    	    %logger:log(error,"im_router server error! reason:~p~nfun:~p~nArg:~p~n",[Reason,Command,Args]),
	    	    	    SessionID
	    	    end,
    	    loop({TID,NextSessionID})
    end.

%%-------------------------------------------------------------------------------------------------

wait_for_result() ->
    receive
    	Value -> Value
    after 
    	5000 -> failed
    end.

%%-------------------------------------------------------------------------------------------------

im_register(UUID,PID) ->
    im_router ! {im_register,self(),[UUID,PID]},
    wait_for_result().

im_register([{TID,SessionID},UUID,PID]) ->
    case ets:lookup(TID,UUID) of
        [] ->
            ok;
        [{UUID,OldPID}] ->
            im_unregister([{TID,SessionID},OldPID])
    end,
    ets:insert(TID, {UUID,PID}),
    ets:insert(TID, {PID,UUID}),
    {ok,SessionID}.

%%-------------------------------------------------------------------------------------------------

im_unregister(PID) when not is_list(PID) ->
    im_router ! {im_unregister,self(),[PID]},
    wait_for_result();

im_unregister([{TID,SessionID},PID]) ->
    case ets:lookup(TID,PID) of
        [] -> 
            ok;
        [{PID,UUID}] ->
            SessionIDList = get_session_index(TID,UUID),
            [leave([{TID,SessionID},UUID,DelSessionID])||DelSessionID<-SessionIDList],
            ets:delete(TID, UUID),
            ets:delete(TID, PID)
    end,
    {ok,SessionID}.

%%-------------------------------------------------------------------------------------------------

is_already_existed(TID,UUID,Members) ->
    case ets:lookup(TID,{im_session_index,UUID}) of
        [] -> false;
        [{{im_session_index,UUID},Dict,_}] -> dict:is_key(Members, Dict)
    end.

get_existed_session(TID,UUID,Members) ->
    [{{im_session_index,UUID},Dict,_}] = ets:lookup(TID,{im_session_index,UUID}),
    {ok,ExistedSessionID} = dict:find(Members, Dict),
    ExistedSessionID.

%%-------------------------------------------------------------------------------------------------

create_session(UUID,Members) ->
    im_router ! {create_session,self(),[UUID, Members]},
    wait_for_result().

create_session([{TID,SessionID},UUID,Members]) ->
    AllMembers = lists:usort([UUID|Members]),
    case is_already_existed(TID,UUID,AllMembers) of
        true ->
            ExistedSessionID = get_existed_session(TID,UUID,AllMembers),
            {ExistedSessionID,SessionID};
        false ->
            create_new_session(TID,SessionID,AllMembers),
            [add_session_index(TID,Member,SessionID,AllMembers)||Member<-AllMembers],
            {SessionID,SessionID + 1}
    end.

%%-------------------------------------------------------------------------------------------------

create_new_session(TID,SessionID,AllMembers) ->
    ets:insert(TID,{{im_session,SessionID},AllMembers}).

update_existed_session(TID,SessionID,NewAllMembers) ->
    case NewAllMembers of
        [] -> ets:delete(TID,{im_session,SessionID});
        _  -> ets:insert(TID,{{im_session,SessionID},NewAllMembers})
    end.

%%-------------------------------------------------------------------------------------------------

add_session_index(TID,UUID,SessionID,AllMembers) ->
    case ets:lookup(TID,{im_session_index,UUID}) of
        [] -> ets:insert(TID,{{im_session_index,UUID},dict:store(AllMembers,SessionID,dict:new()),[SessionID]});
        [{{im_session_index,UUID},Dict,SessionIDList}] -> ets:insert(TID,{{im_session_index,UUID},dict:store(AllMembers,SessionID,Dict),[SessionID|SessionIDList]})
    end.

del_session_index(TID,UUID,SessionID,OldMembers) ->
    case ets:lookup(TID,{im_session_index,UUID}) of
        [] -> 
            [];
        [{{im_session_index,UUID},Dict,SessionIDList}] ->
            Dict1 = dict:erase(OldMembers,Dict),
            SessionIDList1 = SessionIDList -- [SessionID],
            case SessionIDList1 of
                [] -> ets:delete(TID,{im_session_index,UUID});
                _  -> ets:insert(TID,{{im_session_index,UUID},Dict1,SessionIDList1})
            end
    end.

update_session_index(TID,UUID,SessionID,OldMembers,AllMembers) when AllMembers =/= [] ->
    case ets:lookup(TID,{im_session_index,UUID}) of
        [] ->
            [];
        [{{im_session_index,UUID},Dict,SessionIDList}] ->
            Dict1 = dict:erase(OldMembers,Dict),
            Dict2 = dict:store(AllMembers,SessionID,Dict1),
            ets:insert(TID,{{im_session_index,UUID},Dict2,SessionIDList})
    end.

get_session_index(TID,UUID) ->
    case ets:lookup(TID,{im_session_index,UUID}) of
        [] -> [];
        [{{im_session_index,UUID},_,SessionIDList}] -> SessionIDList
    end.

%%-------------------------------------------------------------------------------------------------

invite(FromUUID,SessionID,Members) when is_list(Members) ->
    im_router ! {invite,self(),[FromUUID,SessionID,Members]},
    wait_for_result().

invite([{TID,CurSessionID},_FromUUID,SessionID,Members]) ->
    [{{im_session,SessionID},OldMembers}] = ets:lookup(TID,{im_session,SessionID}),
    AllMembers = lists:usort(lists:append(OldMembers,Members)),
    update_existed_session(TID,SessionID,AllMembers),
    [add_session_index(TID,Member,SessionID,AllMembers)||Member<-Members],
    [update_session_index(TID,Member,SessionID,OldMembers,AllMembers)||Member<-AllMembers],
    {ok,CurSessionID}.

%%-------------------------------------------------------------------------------------------------

leave(UUID,SessionID) ->
    im_router ! {leave,self(),[UUID,SessionID]},
    wait_for_result().

leave([{TID,CurSessionID},UUID,SessionID]) ->
    case ets:lookup(TID,{im_session,SessionID}) of
        [] -> 
            ok;
        [{{im_session,SessionID},OldMembers}] ->
            AllMembers = OldMembers -- [UUID],
            update_existed_session(TID,SessionID,AllMembers),
            del_session_index(TID,UUID,SessionID,OldMembers),
            [update_session_index(TID,Member,SessionID,OldMembers,AllMembers)||Member<-AllMembers]
    end,
    {ok,CurSessionID}.

%%-------------------------------------------------------------------------------------------------

message(From,SessionID,Content) ->
    im_router ! {message,self(),[From,SessionID,Content]},
    wait_for_result().

message([{TID,CurSessionID},From,SessionID,Content]) ->
    [{{im_session,SessionID},Members}] = ets:lookup(TID,{im_session,SessionID}),
    Json= rfc4627:encode(utility:pl2jso([{cmd,im},
                                         {from,From},
                                         {session_id,SessionID},
                                         {members,Members},
                                         {content,Content}])),
    PIDs = id2pid(TID,Members),
    [ws_agent:notify(PID,Json)||PID<-PIDs],
    {ok,CurSessionID}.

%%-------------------------------------------------------------------------------------------------

id2pid(TID,IDs) when is_list(IDs) ->
    [PID||PID<-[id2pid(TID,ID)||ID<-IDs],PID =/= not_existed];

id2pid(TID,ID) when is_integer(ID) ->
    case ets:lookup(TID,ID) of
    	[] -> not_existed;
    	[{ID,PID}] -> PID
    end.

%%-------------------------------------------------------------------------------------------------

test() ->
    start(),
    test1(),
    test2(),
    test3(),
    test4(),
    test5(),
    test6(),
    test7().

test1() ->
    im_register(1,a),
    im_register(2,b),
    [{1,a}] = ets:lookup(im_router,1),
    [{2,b}] = ets:lookup(im_router,2),
    im_unregister(a),
    im_unregister(b),
    [] = ets:lookup(im_router,1),
    [] = ets:lookup(im_router,2),
    io:format("~p~n",["test1 passed!"]).

test2() ->
    im_register(1,a),
    im_register(2,b),
    SessionID = create_session(1,[2]),
    SessionID = create_session(2,[1]),
    im_unregister(a),
    im_unregister(b),
    io:format("~p~n",["test2 passed!"]).

test3() ->
    im_register(1,a),
    im_register(2,b),
    im_register(3,c),
    SessionID = create_session(1,[2]),
    NewSessionID = create_session(3,[1]),
    NewSessionID = SessionID + 1,
    im_unregister(a),
    im_unregister(b),
    im_unregister(c),
    io:format("~p~n",["test3 passed!"]).

test4() ->
    im_register(1,a),
    im_register(2,b),
    im_register(3,c),
    SessionID = create_session(1,[2,3]),
    [{{im_session,SessionID},OldMembers}] = ets:lookup(im_router,{im_session,SessionID}),
    OldMembers = [1,2,3],
    im_unregister(a),
    im_unregister(b),
    im_unregister(c),
    io:format("~p~n",["test4 passed!"]).

test5() ->
    im_register(1,a),
    im_register(2,b),
    im_register(3,c),
    im_register(4,d),
    SessionID = create_session(1,[2,3]),
    invite(1,SessionID,[4]),
    [{{im_session,SessionID},OldMembers}] = ets:lookup(im_router,{im_session,SessionID}),
    OldMembers = [1,2,3,4],
    im_unregister(a),
    im_unregister(b),
    im_unregister(c),
    im_unregister(d),
    io:format("~p~n",["test5 passed!"]).

test6() ->
    im_register(1,a),
    im_register(2,b),
    im_register(3,c),
    im_register(4,d),
    SessionID = create_session(1,[2,3,4]),
    leave(2,SessionID),
    [{{im_session,SessionID},OldMembers}] = ets:lookup(im_router,{im_session,SessionID}),
    OldMembers = [1,3,4],
    false = is_already_existed(im_router,1,[1,2,3,4]),
    false = is_already_existed(im_router,2,[1,2,3,4]),
    false = is_already_existed(im_router,3,[1,2,3,4]),
    false = is_already_existed(im_router,4,[1,2,3,4]),
    true  = is_already_existed(im_router,1,[1,3,4]),
    true  = is_already_existed(im_router,3,[1,3,4]),
    true  = is_already_existed(im_router,4,[1,3,4]),
    [] = ets:lookup(im_router,{im_session_index,2}),
    im_unregister(a),
    im_unregister(b),
    im_unregister(c),
    im_unregister(d),
    io:format("~p~n",["test6 passed!"]).

test7() ->
    im_register(1,a),
    im_register(2,b),
    im_register(3,c),
    im_register(4,d),
    SessionID  = create_session(1,[2,3]),
    SessionID1 = create_session(3,[4]),
    true = is_already_existed(im_router,1,[1,2,3]),
    true = is_already_existed(im_router,2,[1,2,3]),
    true = is_already_existed(im_router,3,[1,2,3]),
    true = is_already_existed(im_router,3,[3,4]),
    true = is_already_existed(im_router,4,[3,4]),
    leave(3,SessionID),
    leave(3,SessionID1),
    true = is_already_existed(im_router,1,[1,2]),
    true = is_already_existed(im_router,2,[1,2]),
    true = is_already_existed(im_router,4,[4]),
    [] = ets:lookup(im_router,{im_session_index,3}),
    true = ([] =/= ets:lookup(im_router,{im_session_index,4})),
    leave(4,SessionID1),
    [] = ets:lookup(im_router,{im_session_index,4}),
    [] = ets:lookup(im_router,{im_session,SessionID1}),
    im_unregister(a),
    im_unregister(b),
    im_unregister(c),
    im_unregister(d),
    io:format("~p~n",["test7 passed!"]).