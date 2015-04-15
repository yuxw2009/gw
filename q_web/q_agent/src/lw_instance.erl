%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork user instance
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_instance).
-compile(export_all).
-include("lw.hrl").
-include("db_op.hrl").

-record(user_state,{uuid,ip,org_id}).

-record(interval,{onlines   = dict:new(),
                  offlines  = dict:new(),
                  news      = 0,
                  poll      = 0,
                  document  = 0,
                  topic     = [],
                  task      = [],
                  question  = [],
                  task_finished = [],
                  video  = [],
                  reverse}).

%%%-------------------------------------------------------------------------------------
%%% API
%%%-------------------------------------------------------------------------------------

lookup_org_markname("unknow") ->
    "unknow";
lookup_org_markname(OrgID) ->
    case mnesia:dirty_read(lw_org,OrgID) of
        [#lw_org{mark_name = MarkName}] ->
            MarkName;
        [] ->
            "unknow"
    end.

lookup_user_info(UUID) ->
    case mnesia:dirty_read(lw_instance_del,UUID) of
        [#lw_instance_del{employee_id = EID,employee_name = Name,org_id = OrgID}] ->
            {EID,Name,OrgID};
        [] ->
            case mnesia:dirty_read(lw_instance,UUID) of
                [#lw_instance{employee_id = EID,employee_name = Name,org_id = OrgID}] ->
                    {EID,Name,OrgID};
                [] ->
                    {"unknow","unknow","unknow"}
            end
    end. 

lookup_user_name(UUID) when is_integer(UUID) ->
    {EID,Name,OrgID} = lookup_user_info(UUID),
    MarkName = lookup_org_markname(OrgID),
    {UUID,EID,Name,MarkName};
lookup_user_name(UUIDs) when is_list(UUIDs) ->
    [lookup_user_name(UUID)||UUID<-UUIDs].

%%--------------------------------------------------------------------------------------

request(UUID, Module, Function, Args, IP) ->
    lw_router:send_when_alive(UUID, {request, self(), Module, Function, Args, IP}),
    receive
        {failed,access_forbidden} ->
            {failed,access_forbidden};
        {value,Result} ->
            {value,Result}
    after 
        ?TIMEOUT ->
            {failed,overtime}
    end.

%%--------------------------------------------------------------------------------------

notify_when_alive(To, Event) ->
    lw_router:send_when_alive(To, {notify, Event}).

%%--------------------------------------------------------------------------------------

check_ip(From,UUID,IP) ->
    lw_router:send_when_alive(UUID, {check_ip, From, IP}).

force_reregister(FromPid,UUID,IP,Msg) ->
    lw_router:send_when_alive(UUID, {force_reregister, FromPid, IP, Msg}).

%%--------------------------------------------------------------------------------------

poll_updates(UUID,IP) ->
    lw_router:send_when_alive(UUID, {poll_updates, self(), IP}),
    receive
        {failed,access_forbidden} ->
            {failed,access_forbidden};
        {value,Result} ->
            {value,Result}
    after 
        ?TIMEOUT ->
            {failed,overtime}
    end.

%%--------------------------------------------------------------------------------------

log_in(OrgID,UUID,IP) ->
    State    = #user_state{uuid = UUID,ip = IP,org_id = OrgID},
    Interval = get_interval(UUID),
    TRef     = erlang:send_after(?DEADLINE, self(), idle_too_long),
    handle_log_in(State),
    NewInterval = handle_new_event(UUID,Interval),
    instance_loop({State,NewInterval,TRef}).

%%--------------------------------------------------------------------------------------

log_out(UUID, IP) -> 
    lw_router:send_when_alive(UUID, {log_out, IP}).

%%--------------------------------------------------------------------------------------

get_unreads(UUID,Type,IP) ->
    lw_router:send_when_alive(UUID, {get_unreads, self(), Type, IP}),
    receive
        {failed,access_forbidden} ->
            {failed,access_forbidden};
        {value,Result} ->
            {value,Result}
    after 
        ?TIMEOUT ->
            {failed,overtime}
    end.

%%--------------------------------------------------------------------------------------

get_recent_replies(UUID,Type,IP) ->
    lw_router:send_when_alive(UUID, {get_recent_replies, self(), Type, IP}),
    receive
        {failed,access_forbidden} ->
            {failed,access_forbidden};
        {value,Result} ->
            {value,Result}
    after 
        ?TIMEOUT ->
            {failed,overtime}
    end.

%%--------------------------------------------------------------------------------------

new_video_invite(FromUUID,ToUUID,FromSDP) ->
    lw_router:send_when_alive(ToUUID, {video,FromUUID,FromSDP,self()}),
    receive
        {value,SDP} -> {value,SDP}
    after
        60 * 1000 -> invite_timeout
    end.

accept_video_invite(_UUID, SDP, _FromUUID, RecvPid) ->
    list_to_pid(RecvPid) ! {value,SDP},
    ok.

stop_video(UUID, PeerUUID) ->
    lw_router:send_when_alive(PeerUUID, {video_stop,UUID}),
    ok.

new_mvideo_invite(From,To,Room,Position) ->
    lw_router:send_when_alive(To, {mvideo,From,Room,Position}).

%%--------------------------------------------------------------------------------------

get_user_attr(UserID,Types) when is_list(Types) ->
    F = fun() -> do_get_attr(UserID,lw_instance,Types) end,
    mnesia:activity(transaction,F).

%%%-------------------------------------------------------------------------------------
%%% internal functions
%%%-------------------------------------------------------------------------------------

instance_loop({#user_state{uuid = UUID,ip = _RegisterIP} = State,Interval,TRef}) ->
    receive
        {check_ip,FromPid,_} ->            
            FromPid ! ok,
            instance_loop({State,Interval,TRef});
        %{check_ip,FromPid,OtherIP} ->            
        %    FromPid ! failed,
        %    logger:log(error,"lw_instance check_ip ~p ~p~n",[UUID, OtherIP]),
        %    instance_loop({State,Interval,TRef});

        {force_reregister, FromPid, NewIP, Msg} ->
            handle_log_out(State),
            logger:log(normal,"UUID:~p OldIP:~p NewIP:~p force_reregister~n",[UUID,_RegisterIP,NewIP]),
            FromPid ! Msg;

        {poll_updates,FromPid,_} ->
            NewInterval = handle_poll_updates(UUID, FromPid, Interval),
            NewTRef     = update_timer(TRef),
            instance_loop({State,NewInterval,NewTRef});
        %{poll_updates,FromPid,OtherIP} ->
        %    FromPid ! {failed, access_forbidden},
        %    logger:log(error,"lw_instance poll_updates ~p ~p~n",[UUID, OtherIP]),
        %    instance_loop({State,Interval,TRef});

        {get_unreads,FromPid,Type,_} ->
            Contents    = do_load_unreads(UUID,Type),
            FromPid ! {value,Contents},
            NewInterval = update_after_unread(Interval,Type,interval_change(del,Type)),
            NewTRef     = update_timer(TRef),
            instance_loop({State,NewInterval,NewTRef});
        %{get_unreads,FromPid,Type,OtherIP} ->
        %    FromPid ! {failed, access_forbidden},
        %    logger:log(error,"lw_instance get_unreads ~p ~p ~p~n",[UUID, Type, OtherIP]),
        %    instance_loop({State,Interval,TRef});

        {get_recent_replies,FromPid,Type,_} ->
            {IDs, Replies} = lists:unzip(lists:sublist(read_unread(UUID,{reply,history,Type}),1,50)),
            Contents = multi_load(UUID,IDs,Type),
            del_unread(UUID,{reply,Type}),
            FromPid ! {value,lists:zip(Contents,Replies)},
            NewInterval = update_after_unread(Interval,Type,interval_change(del,{reply,Type})),
            NewTRef     = update_timer(TRef),
            instance_loop({State,NewInterval,NewTRef});
        %{get_recent_replies,FromPid,Type,OtherIP} ->
        %    FromPid ! {failed, access_forbidden},
        %    logger:log(error,"lw_instance get_recent_replies ~p ~p ~p~n",[UUID, Type, OtherIP]),
        %    instance_loop({State,Interval,TRef});

        idle_too_long ->
            logger:log(normal,"~p idle_too_long~n",[UUID]),
            handle_log_out(State);

        {log_out, _} ->
            handle_log_out(State);
        %{log_out, OtherIP} ->
        %    logger:log(error,"lw_instance log_out ~p ~p~n",[UUID, OtherIP]),
        %    instance_loop({State,Interval,TRef});

        {request, FromPid, Module, Function, Args, _} ->
            logger:log(normal,"~p ~p ~p:~p(~p)~n",[UUID, _RegisterIP, Module, Function, Args]),
            Result = handle_request(Module, Function, Args),
            FromPid ! {value,Result},
            NewTRef = update_timer(TRef),
            instance_loop({State,Interval,NewTRef});
        %{request, FromPid, Module, Function, Args, OtherIP} ->
        %    logger:log(error,"~p ~p ~p:~p(~p)~n",[UUID, OtherIP, Module, Function, Args]),                
        %    FromPid ! {failed, access_forbidden},
        %    instance_loop({State,Interval,TRef});

        {notify, Event} ->
            NewInterval = handle_notify(UUID, Interval, Event),
            instance_loop({State,NewInterval,TRef});

        {video, FromUUID,FromSDP,FromPID} ->
            NewInterval = Interval#interval{video = [p2p,FromUUID,FromSDP,list_to_binary(pid_to_list(FromPID))]},
            NewTRef = update_timer(TRef),
            logger:log(normal,"video ~p ~n",[FromUUID]),
            instance_loop({State,NewInterval,NewTRef});

        {video_stop,From} ->
            NewInterval = Interval#interval{video = [p2p_stop,From]},
            NewTRef = update_timer(TRef),
            logger:log(normal,"video_stop ~p ~n",[From]),
            instance_loop({State,NewInterval,NewTRef});

        {mvideo,From,Room,Position} ->
            NewInterval = Interval#interval{video = [mp,From,Room,Position]},
            NewTRef = update_timer(TRef),
            logger:log(normal,"mvideo ~p ~n",[From]),
            instance_loop({State,NewInterval,NewTRef});

        Other ->
            logger:log(error,"lw_instance other ~p ~p~n",[UUID, Other]),
            instance_loop({State,Interval,TRef})
    end.

%%--------------------------------------------------------------------------------------

handle_request(Module, Function, Args) ->
    try apply(Module, Function, Args)
    catch
        _:Reason ->
            logger:log(error,"lw_instance handle_request ~p ~n",[Reason]),
            {error,Reason}
    end.

%%--------------------------------------------------------------------------------------

move_element(Ele,Src,Dst) ->
    case dict:is_key(Ele,Src) of
        true  -> {dict:erase(Ele, Src),dict:store(Ele,true,Dst)};
        false -> {Src,dict:store(Ele,true,Dst)}
    end.

%%--------------------------------------------------------------------------------------

handle_notify(UUID, Interval, {other_log_in,OtherUUID}) when UUID =/= OtherUUID ->
    {NewOff,NewOn} = move_element(OtherUUID,Interval#interval.offlines,Interval#interval.onlines),
    Interval#interval{onlines = NewOn,offlines = NewOff};
handle_notify(UUID,Interval, {other_log_out,OtherUUID}) when UUID =/= OtherUUID ->
    {NewOn,NewOff} = move_element(OtherUUID,Interval#interval.onlines,Interval#interval.offlines),
    Interval#interval{onlines = NewOn,offlines = NewOff};
handle_notify(UUID, Interval, new_event) ->
    handle_new_event(UUID,Interval);
handle_notify(_UUID,Interval, _) ->
    Interval.

%%--------------------------------------------------------------------------------------

update_timer(TRef) ->
    erlang:cancel_timer(TRef),
    erlang:send_after(?DEADLINE, self(), idle_too_long).

%%--------------------------------------------------------------------------------------
get_login_history(OrgId)->
    case ?DB_OP(qlc:e(qlc:q([X||X<-mnesia:table(lw_history), X#lw_history.orgid == OrgId]))) of
    {atomic,Hs}->
        R= [{UUid,proplists:get_value(login,Timelist)}||{_,UUid,_orgid,Timelist}<-Hs],
        {UUIDs,Tls} = lists:unzip(R),
        Users = local_user_info:get_user(UUIDs),
        Members=[{Name,Eid,DepId}||#lw_instance{employee_name=Name, employee_id=Eid,department_id=DepId}<-Users],
        {ok,lists:zip(Members, Tls)};
    _->    query_login_error
    end.
        
update_login_history(State)->
    UUID  = State#user_state.uuid,
    OrgID = State#user_state.org_id,
    io:format("update_login_history:~p~n",[UUID]),
    case ?DB_READ(lw_history,UUID) of
    {atomic, [Item=#lw_history{history=History}]}->
        io:format("update_login_history1:~p~n",[Item]),
        Logins=proplists:get_value(login,History),
        Logins1=[calendar:local_time()|Logins],
        History1=lists:keystore(login,1,History,{login,Logins1}),
        ?DB_WRITE(Item#lw_history{history=History1}),
        ok;
    _R->
        io:format("update_login_history2:~p~n",[_R]),
        ?DB_WRITE(#lw_history{uuid=UUID,orgid=OrgID,history=[{login,[calendar:local_time()]}]}),
        ok
    end.
    
handle_log_in(State) ->
    update_login_history(State),
    UUID  = State#user_state.uuid,
    OrgID = State#user_state.org_id,
    Module = lw_config:get_user_module(),
    ExternalPartnerIDs = Module:get_external_partnerid(UUID),
    notify_when_alive([OrgID|ExternalPartnerIDs],{other_log_in,UUID}).

%%--------------------------------------------------------------------------------------

handle_log_out(State) ->
    UUID  = State#user_state.uuid,
    OrgID = State#user_state.org_id,
    Module = lw_config:get_user_module(),
    ExternalPartnerIDs = Module:get_external_partnerid(UUID),
    notify_when_alive([OrgID|ExternalPartnerIDs],{other_log_out,UUID}),
    lw_router:do_unregister(UUID).

%%--------------------------------------------------------------------------------------

handle_new_event(UUID, Interval) ->
    F = fun({_,_,OwnerID},IntervalAcc) when OwnerID =:= UUID -> 
                IntervalAcc;
           ({Tag,ID,_},IntervalAcc) -> 
                do_handle_new_event(UUID,IntervalAcc,ID,Tag,interval_change(add,Tag));
           ({reply,_,_,OwnerID},IntervalAcc) when OwnerID =:= UUID ->
               IntervalAcc;
           ({reply,Tag,Content,_},IntervalAcc) -> 
               do_handle_new_reply_event(UUID,IntervalAcc,Content,Tag,interval_change(add,{reply,Tag}))
        end,
    Msgs = lw_router:fetch_messages(UUID),
    lists:foldl(F,Interval,Msgs).

%%--------------------------------------------------------------------------------------

handle_poll_updates(UUID,FromPid,Interval) ->
    FromPid ! {value,[{onlines,  dict:fetch_keys(Interval#interval.onlines)}, 
                      {offlines, dict:fetch_keys(Interval#interval.offlines)}, 
                      {news,     Interval#interval.news}, 
                      {polls,    Interval#interval.poll}, 
                      {documents,Interval#interval.document}, 
                      {topics,   Interval#interval.topic}, 
                      {tasks,    Interval#interval.task},
                      {questions,Interval#interval.question},
                      {tasks_finished,Interval#interval.task_finished},
                      {video,Interval#interval.video}]},
    del_unread(UUID,task_finished),
    Interval#interval{onlines = dict:new(), offlines = dict:new(), task_finished = [] ,video = []}.

%%--------------------------------------------------------------------------------------

modify_user_info(UUID,Telephone,EMail) -> 
    Module = lw_config:get_user_module(),
    Module:modify_user_info(UUID,Telephone,EMail).
modify_user_photo(UUID,PhotoURL) -> 
    Module = lw_config:get_user_module(),
    Module:modify_user_photo(UUID,PhotoURL).

%%--------------------------------------------------------------------------------------

get_interval(UUID) ->
    #interval{onlines  = dict:new(),
              offlines = dict:new(),
              poll  = get_unread_num(UUID,poll),
              topic = [get_unread_num(UUID,topic),get_unread_num(UUID,{reply,topic})],
              task  = [get_unread_num(UUID,task),get_unread_num(UUID,{reply,task})],
              task_finished = read_unread(UUID,task_finished)}.

%%--------------------------------------------------------------------------------------

multi_load(_UUID,IDs,task) ->
    lw_task:get_task_content(IDs,normal);
multi_load(_UUID,IDs,topic) ->
    lw_topic:get_topic_content(IDs);
multi_load(UUID,IDs,poll) ->
    lw_poll:get_poll_content(UUID,IDs);
multi_load(_UUID,IDs,document) ->
    lw_document:get_doc_content(IDs).

%%--------------------------------------------------------------------------------------

do_load_unreads(UUID,Tag) ->
    {IDs,Contents} = do_load_unreads2(UUID,Tag),
    case Tag of
        task -> lw_task:trace_task(UUID, IDs, {read});
        _    -> ok
    end,
    Contents.

do_load_unreads2(UUID,Tag) ->
    IDs = read_unread(UUID,Tag),
    Contents = multi_load(UUID,IDs,Tag),
    del_unread(UUID,Tag),
    {IDs,Contents}.

%%--------------------------------------------------------------------------------------

save_verse(task,UUID,TaskID) -> 
    lw_task:do_add_task(UUID,TaskID);
save_verse(task_finished,UUID,{TaskID,_}) ->
    lw_task:finish_task(relate,UUID,TaskID);
save_verse(topic,UUID,TopicID) ->
    lw_topic:do_add_topic(UUID,TopicID);
save_verse(poll,UUID,PollID) ->
    lw_poll:do_add_poll(UUID,{PollID,{not_voted,none}});
save_verse(document,UUID,DocItem) ->
    lw_document:do_add_doc(UUID,DocItem).

%%--------------------------------------------------------------------------------------

-define(HANDLE_NEW_EVENT(UUID,Interval,Content,Tag,Act),do_handle_new_event(UUID,Interval,Content,Tag,Act) ->
    case is_repeat(Tag,UUID,Content) of
        false ->
            save_unread(UUID,{Tag,Content}),
            save_verse(Tag,UUID,Content),
            Old = Interval#interval.Tag,
            New = Act(Content,Old),
            Interval#interval{Tag = New};
        true -> Interval
    end).

-define(HANDLE_NEW_REPLY_EVENT(UUID,Interval,Content,Tag,Act),do_handle_new_reply_event(UUID,Interval,Content,Tag,Act) ->
    case  is_repeat(Tag,UUID,Content) of
        true ->
            save_unread(UUID,{{reply,Tag},Content}),
            save_unread(UUID,{{reply,history,Tag},Content}),
            Old = Interval#interval.Tag,
            New = Act(Content,Old),
            Interval#interval{Tag = New};
        false -> Interval
    end).

?HANDLE_NEW_EVENT(UUID,Interval,ID,task,Act);
?HANDLE_NEW_EVENT(UUID,Interval,ID,topic,Act);
?HANDLE_NEW_EVENT(UUID,Interval,ID,poll,Act);
?HANDLE_NEW_EVENT(UUID,Interval,ID,document,Act);
?HANDLE_NEW_EVENT(UUID,Interval,Content,task_finished,Act).

?HANDLE_NEW_REPLY_EVENT(UUID,Interval,Content,task,Act);
?HANDLE_NEW_REPLY_EVENT(UUID,Interval,Content,topic,Act);
?HANDLE_NEW_REPLY_EVENT(UUID,Interval,Content,poll,Act).

%%--------------------------------------------------------------------------------------

is_repeat(task,UUID,ID) when is_integer(ID) -> lw_task:is_repeat(UUID,ID);
is_repeat(task,UUID,{ID,_}) -> lw_task:is_repeat(UUID,ID);

is_repeat(topic,UUID,ID) when is_integer(ID) -> lw_topic:is_repeat(UUID,ID);
is_repeat(topic,UUID,{ID,_}) -> lw_topic:is_repeat(UUID,ID);

is_repeat(poll,UUID,ID) when is_integer(ID) -> lw_poll:is_repeat(UUID,ID);
is_repeat(document,UUID,{ID,_,_}) -> lw_document:is_repeat(UUID,ID);

is_repeat(task_finished,_UUID,_ID) -> false.

%%--------------------------------------------------------------------------------------

-define(GET_ATTR(Term,Table,Tag),do_get_attr1(Term,Table,Tag) when is_atom(Tag) ->
    Term#Table.Tag).

do_get_attr(Key,Table,Tags) when is_list(Tags) ->
    case mnesia:read(Table,Key,read) of
        []     -> [];
        [Term] -> [do_get_attr1(Term,Table,Tag)||Tag<-Tags]
    end.

?GET_ATTR(Term,lw_unread,unread);
?GET_ATTR(Term,lw_instance,group);
?GET_ATTR(Term,lw_instance,org_id);
?GET_ATTR(Term,lw_instance,department_id).

%%--------------------------------------------------------------------------------------

-define(UPDATE_TAB(Tab,Tag,Key,Content,Act),update_table(Tab,Tag,Key,Content,Act) ->
    [Item] = mnesia:read(Tab,Key,write),
    Old    = Item#Tab.Tag,
    New    = Act(Content,Old),
    mnesia:write(Item#Tab{Tag = New})).

?UPDATE_TAB(lw_unread,unread,ID,Content,Act);
?UPDATE_TAB(lw_instance,group,ID,Content,Act);
?UPDATE_TAB(lw_instance,phone,ID,Content,Act);
?UPDATE_TAB(lw_instance,email,ID,Content,Act);
?UPDATE_TAB(lw_instance,photo,ID,Content,Act).

%%--------------------------------------------------------------------------------------

save_unread(UUID,{Tag,Save}) ->
    F = fun() ->
            case mnesia:read(lw_unread,{UUID,Tag},write) of
                []  -> mnesia:write(#lw_unread{key = {UUID,Tag},unread = [Save]});
                [_] -> update_table(lw_unread,unread,{UUID,Tag},Save,fun(New,Old) -> [New|Old] end)
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

del_unread(UUID,Tag) ->
    F = fun() ->
            case mnesia:read(lw_unread,{UUID,Tag},write) of
                [] -> ok;
                _  -> mnesia:delete(lw_unread,{UUID,Tag},write)
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

read_unread(UUID,Tag) ->
    F = fun() -> 
            case do_get_attr({UUID,Tag},lw_unread,[unread]) of
                [] -> [];
                [Unread] -> Unread 
            end
        end,
    mnesia:activity(transaction,F).

%%--------------------------------------------------------------------------------------

get_unread_num(UUID,Tag) ->
    Unread = read_unread(UUID,Tag),
    length(Unread).

%%--------------------------------------------------------------------------------------

-define(UPDATE_AFTER_UNREAD(Interval,Tag,Act),update_after_unread(Interval,Tag,Act) ->
    Old = Interval#interval.Tag,
    New = Act(Old),
    Interval#interval{Tag = New}).

?UPDATE_AFTER_UNREAD(Interval,task,Act);
?UPDATE_AFTER_UNREAD(Interval,topic,Act);
?UPDATE_AFTER_UNREAD(Interval,poll,Act);
?UPDATE_AFTER_UNREAD(Interval,document,Act);
?UPDATE_AFTER_UNREAD(Interval,video,Act).

%%--------------------------------------------------------------------------------------

interval_change(add,task) -> fun(_New,[Num1,Num2])  -> [Num1 + 1,Num2] end;
interval_change(del,task) -> fun([_Num1,Num2]) -> [0,Num2] end;

interval_change(add,topic) -> fun(_New,[Num1,Num2]) -> [Num1 + 1,Num2] end;
interval_change(del,topic) -> fun([_Num1,Num2]) -> [0,Num2] end;

interval_change(add,poll) -> fun(_New,Num) -> Num + 1 end;
interval_change(del,poll) -> fun(_) -> 0 end;

interval_change(add,document) -> fun(_New,Num) -> Num + 1 end;
interval_change(del,document) -> fun(_) -> 0 end;

interval_change(add,task_finished) -> fun(New,Old) -> [New|Old] end;
interval_change(del,task_finished) -> fun(_) -> 0 end;

interval_change(add,{reply,task}) -> fun(_New,[Num1,Num2]) -> [Num1,Num2 + 1] end;
interval_change(del,{reply,task}) -> fun([Num1,_Num2]) -> [Num1,0] end;

interval_change(add,{reply,topic}) -> fun(_New,[Num1,Num2]) -> [Num1,Num2 + 1] end;
interval_change(del,{reply,topic}) -> fun([Num1,_Num2]) -> [Num1,0] end;

%%interval_change(add,{reply,poll}) -> fun(_New,[Num1,Num2]) -> [Num1,Num2 + 1] end;
%%interval_change(del,{reply,poll}) -> fun([Num1,_Num2]) -> [Num1,0] end;

interval_change(del,video) -> fun(_) -> [] end.

%%--------------------------------------------------------------------------------------

for_all_transform_phone() ->
    F1= fun(UUID) ->
            [Ins]    = mnesia:read(lw_instance,UUID,write),
            Phone = 
                case Ins#lw_instance.phone of
                    [] -> "";
                    [Value] -> Value
                end,
            NewPhone = list_to_binary(rfc4627:encode(lw_lib:build_body([mobile,pstn,extension,other],[Phone,"","",[]],[b,b,b,r]))),
            mnesia:write(Ins#lw_instance{phone = NewPhone})
        end,
    F2= fun() ->
            Keys = mnesia:all_keys(lw_instance),
            [F1(UUID)||UUID<-Keys]
        end,
    mnesia:activity(transaction,F2).

%%--------------------------------------------------------------------------------------
