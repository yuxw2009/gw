%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork router
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_router).
-compile(export_all).
-include("lw.hrl").

%%%-------------------------------------------------------------------------------------
%%% APIs
%%%-------------------------------------------------------------------------------------

stop_monitor() ->
    ?MONITOR ! {stop}.

%%--------------------------------------------------------------------------------------

register_ua(OrgID,UUID,IP) ->
    ?MONITOR ! {self(),register_ua, OrgID,UUID,IP},
    receive
        Ack -> 
            Ack
    after
        ?TIMEOUT ->
            failed
    end.

%%--------------------------------------------------------------------------------------
   
unregister_ua(UUID) ->
    do_unregister(UUID).

%%--------------------------------------------------------------------------------------

push_notification(To,Self,Type) ->
    UUIDs = lw_department:get_atom_uuids(To) -- [Self],
    case Type of
        task -> lw_push:push_notification(UUIDs,"You have a new task!");
        {reply,task} -> lw_push:push_notification(UUIDs,"You have a new task reply!");
        topic -> lw_push:push_notification(UUIDs,"You have a new topic!");
        {reply,topic} -> lw_push:push_notification(UUIDs,"You have a new topic reply!");
        _ -> ok
    end.

%%--------------------------------------------------------------------------------------

send(To, Msg) when is_integer(To) ->
    send([To], Msg);
send(To, Msg) when is_list(To) ->
    do_send(To, Msg, true).

%%--------------------------------------------------------------------------------------
    
send_when_alive(To,Msg) when is_integer(To) ->
    send_when_alive([To], Msg);
send_when_alive(To,Msg) when is_list(To) ->
    do_send(To, Msg, false).

%%--------------------------------------------------------------------------------------

get_messages_len(UUID) ->
    F = fun() ->
            case mnesia:read(lw_msg_queue, UUID, write) of 
                [] -> 0;
                [#lw_msg_queue{msgs = Msgs}] -> length(Msgs)
            end
        end,
    mnesia:activity(transaction, F).

%%--------------------------------------------------------------------------------------

fetch_messages(UUID) ->
    F = fun() ->
            case mnesia:read(lw_msg_queue, UUID, write) of 
                [] -> [];
                [#lw_msg_queue{msgs = Msgs}] -> mnesia:delete(lw_msg_queue,UUID,write),Msgs
            end
        end,
    mnesia:activity(transaction, F).

%%--------------------------------------------------------------------------------------

is_user_alive(UUID) when is_integer(UUID) ->
    case get_registered_pids([UUID]) of
        []    -> false;
        [Pid] -> is_process_alive(Pid)
    end.

%%--------------------------------------------------------------------------------------

get_registered_states(UUIDs) when is_list(UUIDs) ->
    F1= fun(UUID) ->    
            case mnesia:read(lw_register, UUID) of
                [] -> offline;
                [#lw_register{pid = Pid}] ->
                    case is_process_alive(Pid) of
                        true  -> online;
                        false -> offline
                    end
            end
        end,
    F2 = fun() -> [F1(UUID)||UUID<-UUIDs] end,
    mnesia:activity(transaction, F2).

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

do_send(To, Msg, NeedPersistent) ->
    UUIDs = lw_department:get_atom_uuids(To),
    NewMsg = 
        if 
            NeedPersistent -> put_in_queue(UUIDs, Msg),{notify, new_event};
            true           -> Msg
        end,
    AlivePids = get_alive_pids(UUIDs),
    send_alive_message(AlivePids, NewMsg).

%%--------------------------------------------------------------------------------------

send_alive_message(AlivePids, Msg) ->
    [Pid ! Msg || Pid <- AlivePids].

%%--------------------------------------------------------------------------------------

put_in_queue(UUIDs, Msg) when is_list(UUIDs)->
    F1 = fun(ID) -> Queue = get_uuid_queue(ID), push_message(Queue, Msg) end,
    F2 = fun() -> [F1(ID) || ID<-UUIDs] end,
    mnesia:activity(transaction, F2).

%%--------------------------------------------------------------------------------------

get_alive_pids(UUIDs) when is_list(UUIDs) ->
    Pids = get_registered_pids(UUIDs),
    [P || P<-Pids, is_process_alive(P)].

%%--------------------------------------------------------------------------------------
    
get_registered_pids(UUIDs) ->
    F1= fun(UUID, Acc) ->    
            case mnesia:read(lw_register, UUID) of
                [] -> Acc;
                [#lw_register{pid = Pid}] -> [Pid|Acc]
            end
        end,
    F2 = fun() -> lists:foldl(F1, [], UUIDs) end,
    mnesia:activity(transaction, F2).

%%--------------------------------------------------------------------------------------

get_uuid_queue(UUID) ->
    case mnesia:read(lw_msg_queue, UUID, write) of
        [] -> #lw_msg_queue{uuid = UUID, msgs = []};
        [Queue] -> Queue
    end.

%%--------------------------------------------------------------------------------------

push_message(Queue, Msg) ->
    Msgs = Queue#lw_msg_queue.msgs,
    mnesia:write(Queue#lw_msg_queue{msgs=lists:append(Msgs,[Msg])}).

%%--------------------------------------------------------------------------------------

do_register(UUID,Pid) ->
    F = fun() ->
            mnesia:write(#lw_register{uuid = UUID,pid = Pid}),
            mnesia:write(#lw_verse_register{pid = Pid,uuid = UUID})
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

do_unregister(UUID) when is_integer(UUID) ->
    Pid = lookup_pid(UUID),
    do_unregister2(UUID,Pid);

do_unregister(Pid) when is_pid(Pid) ->
    UUID = lookup_uuid(Pid),
    do_unregister2(UUID,Pid).

do_unregister2(UUID,Pid) ->
    F = fun() ->
            mnesia:delete(lw_register,UUID,write),
            mnesia:delete(lw_verse_register,Pid,write)
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

lookup_pid(UUID) ->
    F = fun() -> [#lw_register{pid = Pid}] = mnesia:read(lw_register,UUID),Pid end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

lookup_uuid(Pid) ->
    F = fun() -> [#lw_verse_register{uuid = UUID}] = mnesia:read(lw_verse_register,Pid),UUID end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

user_register(FromPid,OrgID,UUID,IP) ->
    {Pid,_} = spawn_monitor(fun() -> lw_instance:log_in(OrgID,UUID,IP) end),
    do_register(UUID,Pid),
    FromPid ! ok.

%%--------------------------------------------------------------------------------------

monitor() ->
    receive
        {From,register_ua,OrgID,UUID,IP} ->
            try
                case is_user_alive(UUID) of
                	false -> user_register(From,OrgID,UUID,IP);
                    true  -> From ! ok
                end
            catch
                _:Reason ->
                    logger:log(error,"monitor register ua failed.reason:~p~n",[Reason])
            end,
            monitor();
        {'DOWN',_,process,_Pid,normal} ->
            monitor();
        {'DOWN',_,process,Pid,_Other} ->    
            %io:format("pid: ~p reason:~p~n",[Pid,_Other]),        
            spawn(fun() -> 
                      UUID = lookup_uuid(Pid),
                      do_unregister(Pid),         
                      write_error_log({UUID,_Other}),
                      [OrgID] = lw_instance:get_user_attr(UUID,[org_id]),
                      lw_instance:notify_when_alive(OrgID,{other_log_out,UUID})
                  end),                        
            monitor();
        {stop} -> ok
    end.

%%--------------------------------------------------------------------------------------

-define(ERROR_LOG,"./error/log.dat").

write_error_log(Log) ->
    {ok,S} = file:open(?ERROR_LOG,[append]),
    io:format(S,"Time:~p,log:~p.~n",[calendar:local_time(),Log]),
    file:close(S).

%%--------------------------------------------------------------------------------------