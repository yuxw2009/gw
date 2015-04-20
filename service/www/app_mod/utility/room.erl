-module(room).

-include("roomtopo.hrl").
-record(parti, {pt_role,
                in_pcs=[],       %%[connid|...]
                opts=[],
                uuid,
                pt               %%participant process. ptPid
                }).
-record(pconn, {pts=[],          %%[ptid1, ptid2]
                pc               %%peerconn process.
               }).
-record(state, {rid,
                topo,
	            partis=[],       %%key:ptid, value:#parti{}
                pconns=[],       %%key:connid, value:#pconn{}
                ptid_genr,
                connid_genr,
                waitings=[],    %% [ {ptId,#parti{}}]
                creator_attrs=[],         %% [{ptId,PtId}|params]  params is from create_room by browser
                pcMod           %%peerconn module name.
	           }).

-compile(export_all).
-behaviour(gen_server).
-export([init/1,
     handle_call/3,
     handle_cast/2,
     handle_info/2,
     terminate/2,
     code_change/3
    ]).

-define(MAX_WAITING_NUM, 5).
-define(ROOM_EXIST_TIME, 10*1000).
-define(LOGMAXSIZE, 2000000).
-define(LOGFILE, "./room.log").
-define(BACKLOG, "./room_bak.log").

%%% extra API.
create(Opts) -> 
    gen_server:start(?MODULE, Opts, []).

create(RoomID, Topo, test) -> 
    gen_server:start(?MODULE, {RoomID, Topo, test}, []).

destroy(Room) ->
    case is_process_alive(Room) of
    true-> gen_server:cast(Room, destroy);
    _-> void
    end.

enter(Room, Tm, Opts) ->
    gen_server:call(Room, {enter, Tm, Opts}).

leave(Room, Ptid) ->
    gen_server:cast(Room, {leave, Ptid}).

report(Room, Ptid, Pcid, PcData) ->
    gen_server:cast(Room, {report, Ptid, Pcid, PcData}).

get_room_info(RoomPid)->
    case is_pid(RoomPid) andalso is_process_alive(RoomPid) of
    true->
        #state{partis=PS, waitings=WS} = cur_state(RoomPid),
        WSINFO = [utility:pl2jso(proplists:delete(from_ip, Opts0))||{_,#parti{opts=Opts0}}<-WS],
        MSINFO = [utility:pl2jso(proplists:delete(from_ip, Opts))||{_,#parti{opts=Opts}}<-PS],
        [{member_num, length(PS)}, {waiting_num, length(WS)},{waitings_info, WSINFO},{members_info, MSINFO}];
    _-> []
    end.
    
cur_state(Room) ->
    gen_server:call(Room, get_current_state).

%%%
init(Opts) when is_list(Opts) ->
    log("~p room created,~nOpts:~p", [self(), Opts]),
    RoomID=proplists:get_value(rid, Opts), 
    Creator = proplists:get_value("uuid", Opts),
    opr_rooms:add_opr_room(Creator,{RoomID, self()}),
    
    {obj,Attr}=proplists:get_value("attr",Opts),
    Topo=roomtopo:from_type_attr(proplists:get_value("type", Opts), Attr),
    timer:send_interval(?ROOM_EXIST_TIME,check_room),
    {ok, #state{rid=RoomID, topo=Topo, ptid_genr=id_generator:new(pt), connid_genr=id_generator:new(pc), pcMod=peerconn,creator_attrs=Opts}};
init({RoomID, Topo, test}) ->
    {ok, #state{rid=RoomID, topo=Topo, ptid_genr=id_generator:new(pt), connid_genr=id_generator:new(pc), pcMod=mockpeerconn}}.

handle_info(check_room,State=#state{rid=RID,partis=PS}) ->
    CheckFun = fun({Ptid, #parti{pt=Termi,uuid=UUID}})->
    				case is_pid(Termi) andalso is_process_alive(Termi) of
    				true-> normal;
    				_->
    				    leave(self(), Ptid),
    				    log("room:check_room,Termi ~p not alive, so let uuid:~p leave room ~p~n", [Termi, UUID,RID])
    				end
    		        end,
    [CheckFun(Item)|| Item<-PS],
    case is_creator_in_room(State) of
    false-> 
        log("room is_creator_in_room: Room: ~p released as the creator not in.~n",[RID]),
        {stop,normal,State};
    true->  
        {noreply, State} 
    end;
handle_info(_Unhandled,State=#state{rid=_RID}) ->
    {noreply, State}.

handle_cast({report, Ptid, Pcid, PcData}, State=#state{rid=_RID, pconns=Pconns, pcMod=PcMod}) ->
    case proplists:get_value(Pcid, Pconns) of
        undefined -> log("room ~p pcid ~p no pconn! ", [self(),Pcid]);
        #pconn{pc=Pc}->
            PcMod:report(Pc, {Ptid, PcData})        
    end,
    {noreply, State};

handle_cast(destroy, State) ->
    {stop, normal, State};
handle_cast({leave, Ptid}, State=#state{rid=Room,creator_attrs=C_attrs, partis=Partis,waitings=WS}) ->
    case proplists:get_value(Ptid, Partis++WS) of
	    #parti{uuid=Leaver}->
	        opr_rooms:remove(Leaver);
	    _-> void
    end,
    NewSt = participant_leave(Ptid, State),
    case is_creator_in_room(NewSt) of
    true-> {noreply, NewSt};
    _-> 
        log("room:~p stop because the creator leave room ~p~n C_attrs:~p", [self(),Room,C_attrs]),
        {stop, normal, NewSt}
    end;
handle_cast(join_waiting, State=#state{topo=_Topo, partis=_Partis,waitings=[],ptid_genr=_PtidGenr}) ->
    {noreply, State};
handle_cast(join_waiting, State=#state{topo=_Topo, partis=Partis,waitings=[First={Ptid,#parti{}}|Tail],ptid_genr=_PtidGenr}) ->
    NewState=build_pcs(Ptid, proplists:get_keys(Partis), State#state{partis=Partis++[First]}),
    {noreply, NewState#state{waitings=Tail}};
handle_cast(_Msg, State)->
    {noreply, State}.

handle_call(get_current_state, _From, State) ->
    {reply, State, State};


handle_call({enter, Termi, Opts}, _From, State=#state{rid=Room,topo=Topo,partis=Partis,waitings=WS,ptid_genr=PtidGenr})->
    log("room:~p Termi ~p enter room ~p~n Opts:~p", [self(), Termi,Room,Opts]),
    Role = proplists:get_value(role,Opts),
    Enterer = proplists:get_value("uuid", Opts),
    Self=self(),
    Ptid = id_generator:gen(PtidGenr),
    NewMember = {Ptid, #parti{pt=Termi,pt_role=Role,uuid=Enterer,opts=Opts}},
    case opr_rooms:get(Enterer) of
    {Room, Self}->  % reenter
        case [I||I={_,#parti{uuid=UUID}}<-Partis,UUID == Enterer] of
	        [{Ptid_,#parti{}}]->
	               NState=participant_leave(Ptid_, State),
		        {reply, {ok, Ptid}, NState#state{waitings=[NewMember|WS]}};
		   []->
		        W_fun=fun({_, #parti{uuid=UUID, pt=Term}}) when UUID==Enterer-> xhr_poll:stop(Term), NewMember;  (J)-> J end,
		        NewWS = [W_fun(I)||I<-WS],
		       {reply, {waiting, Ptid}, State#state{waitings=NewWS}}
		   end;
    {Rid_old, _RPid_old}->
        {reply, {failed, already_in_room, Rid_old}, State};
    _->
	    RoleCapacity = roomtopo:capacity_of_role(Role, Topo),
	    RoleCurcount = current_count_of(Role, Partis),
	    if 
	        (RoleCapacity == any) or (RoleCapacity > RoleCurcount) ->
	            {Result, NewSt} = participant_enter([Termi, Role, Opts], State),
	            {reply, Result, NewSt};
	        length(WS)<?MAX_WAITING_NUM->
			opr_rooms:add(Enterer,{Room, self()}),
	            {reply, {waiting, Ptid}, State#state{waitings=WS++[NewMember]}};
	        true ->
	            {reply, {failed, room_is_full, null}, State}
	    end
    end;

handle_call(_Msg, _From, State)->
    {reply, ok, State}.

code_change(_Oldvsn, State, _Extra)->
    {ok, State}.

terminate(Reason, State=#state{ptid_genr=PtidGenr, connid_genr=ConnidGenr,partis=Partis,rid=Rid,waitings=WS, creator_attrs=C_attrs})->
    log("~p room:~p terminated, reason:~p,~nmembers:~p~n", [self(), Rid, Reason,Partis++WS]),
    opr_rooms:remove_opr_room(proplists:get_value("uuid", C_attrs)),
    room_mgr:delete(Rid),
    id_generator:delete(PtidGenr),
    id_generator:delete(ConnidGenr),
    Rel_fun = fun({PtId,#parti{pt=PtPid,opts=Opts}})->
    			browser_agent:send(PtPid,[{event,require_close_all}, {room,list_to_binary(Rid)},{ptId,list_to_binary(PtId)}]),
    			opr_rooms:remove(proplists:get_value("uuid", Opts))
    		end,
    [Rel_fun(Item)  || Item<-Partis++WS],
    lists:foldl(fun participant_leave/2, State, proplists:get_keys(Partis)),
    Reason.


%% inner methods.
handle_enter(Ptid, E_opts, State=#state{rid=Room, creator_attrs=C_attrs})->
	Enterer = proplists:get_value("uuid", E_opts),
	opr_rooms:add(Enterer,{Room, self()}),
	Creator = proplists:get_value("uuid", C_attrs),
	NewSt=	if Enterer ==  Creator-> State#state{creator_attrs=[{ptid,Ptid}|C_attrs]}; true-> State end,
	{ok, NewSt}.

is_creator_in_room(#state{creator_attrs=C_attrs, partis=Partis,waitings=WS})->
    Creator = proplists:get_value("uuid", C_attrs),
    [I || I={_,#parti{uuid=UUID}}<-Partis++WS, UUID==Creator] =/= [].
    
current_count_of(Role, Partis) ->
    length(lists:filter(fun({_PtID, #parti{pt_role=PtRole}}) -> Role==PtRole end, Partis)).

participant_enter([Termi, Role,Opts], State=#state{partis=Partis, ptid_genr=PtidGenr}) ->
    Ptid = id_generator:gen(PtidGenr),
    {ok, NewState}= handle_enter(Ptid, Opts, State),
    Enterer=proplists:get_value("uuid",Opts),
    {{ok, Ptid}, build_pcs(Ptid, proplists:get_keys(Partis), NewState#state{partis=Partis++[{Ptid, #parti{pt_role=Role,pt=Termi,opts=Opts,uuid=Enterer}}]})}.

build_pcs(_NewPtID, [], State) ->
    State;
build_pcs(NewPtID, [OldPtID|T], State=#state{rid=RID, topo=Topo, partis=Partis, pconns=Pconns, connid_genr=ConnidGenr, pcMod=PcMod}) ->
    NewPt = #parti{pt_role=Role1, in_pcs=Pcs1, pt=Pt1,opts=Opts1} = proplists:get_value(NewPtID, Partis),
    OldPt = #parti{pt_role=Role2, in_pcs=Pcs2, pt=Pt2,opts=Opts2} = proplists:get_value(OldPtID, Partis),
    NewSt = case roomtopo:tracks_between(Role1, Role2, Topo) of
                {{none, none}, {none, none}} ->
                    State;
                {Role1Tracks, Role2Tracks} ->
                    PcID = id_generator:gen(ConnidGenr),
                    Pc = PcMod:establish(RID, PcID, {NewPtID, Pt1, Role1Tracks,Opts1}, {OldPtID, Pt2, Role2Tracks,Opts2}, NewPtID),
                    State#state{partis=proplists:delete(NewPtID, proplists:delete(OldPtID, Partis))++[{NewPtID, NewPt#parti{in_pcs=Pcs1++[PcID]}}, {OldPtID, OldPt#parti{in_pcs=Pcs2++[PcID]}}], pconns=Pconns++[{PcID, #pconn{pts=[NewPtID, OldPtID], pc=Pc}}]}
            end,
    build_pcs(NewPtID, T, NewSt).


participant_leave(Ptid, State0=#state{partis=Partis, waitings=WS}) ->
    State = State0#state{waitings=proplists:delete(Ptid, WS)},
    case proplists:get_value(Ptid, Partis) of
        undefined ->
            State;
        #parti{in_pcs=Pcs1,pt=Termi} ->
            gen_server:cast(self(), join_waiting),
            xhr_poll:stop(Termi),
            NewSt=#state{partis=Partis1}=release_pcs(Pcs1, State),
            NewSt#state{partis=proplists:delete(Ptid, Partis1)}
    end.

release_pcs([], State) -> State;
release_pcs([Pcid|Others], State=#state{partis=Partis, pconns=Pconns, pcMod=PcMod}) ->
    case proplists:get_value(Pcid, Pconns) of
        undefined ->
            release_pcs(Others, State);
        #pconn{pts=Pts, pc=PC} ->
            PcMod:release(PC),
            RemainedPts = lists:foldl(fun(E, Acc) -> 
                                         case proplists:get_value(E, Acc) of
                                            undefined ->
                                                Acc;
                                            Parti=#parti{in_pcs=InPcs} ->
                                                proplists:delete(E, Acc)++[{E, Parti#parti{in_pcs=lists:delete(Pcid, InPcs)}}]
                                         end
                                      end, Partis, Pts),
            release_pcs(Others, State#state{partis=RemainedPts, pconns=proplists:delete(Pcid, Pconns)})
    end.


%% test cases.
test() ->
    test_2peers_enter_a_2p_p2proom(),
    test_3peers_enter_a_5P_p2proom(),
    test_the3rd_peer_failed_to_enter_p2proom(),
    ok.

test_2peers_enter_a_2p_p2proom() ->
    RmTopo = roomtopo:from_type_attr(p2pav, [{capacity, 2}]),
    #topo{roles=[{peer, 2}], drcts=[{peer, {[peer], [peer]}}], tracks=[{peer, {[{peer, av}], [{peer, av}]}}]} = RmTopo,
    {ok, Rm} = create("room108", RmTopo, test),
    #state{rid=RID, topo=RmTopo, partis=Partis, pconns=Pconns} = cur_state(Rm),
    0 = length(Partis),
    0 = length(Pconns),
    B1 = mockobj:start(),
    B2 = mockobj:start(),

    none = mockobj:last_call(B1),
    none = mockobj:last_call(B2),

    {ok, "pt_0"} = enter(Rm, B1, peer),

    #state{rid=RID, partis=Partis1, pconns=Pconns1} = cur_state(Rm),
    
    1 = length(Partis1),
    0 = length(Pconns1),
    #parti{pt_role=peer, in_pcs=[], pt=B1} = proplists:get_value("pt_0", Partis1),

    {ok, "pt_1"} = enter(Rm, B2, peer),

    #state{rid=RID, partis=Partis2, pconns=Pconns2} = cur_state(Rm),

    2 = length(Partis2),
    1 = length(Pconns2),
    #parti{pt_role=peer, in_pcs=["pc_0"], pt=B1} = proplists:get_value("pt_0", Partis2),
    #parti{pt_role=peer, in_pcs=["pc_0"], pt=B2} = proplists:get_value("pt_1", Partis2),
    #pconn{pts=Pts, pc=PC} = proplists:get_value("pc_0", Pconns2),
    2 = length(Pts),
    {establish, {"room108", "pc_0", {"pt_1", B2, {send_receive, send_receive}}, {"pt_0", B1, {send_receive, send_receive}}, "pt_1"}} = mockobj:last_call(PC),

    ok = leave(Rm, "pt_0"),

    #state{rid=RID, partis=Partis3, pconns=Pconns3} = cur_state(Rm),
    
    1 = length(Partis3),
    0 = length(Pconns3),
    #parti{pt_role=peer, in_pcs=[], pt=B2} = proplists:get_value("pt_1", Partis3),
    {release, {PC}} = mockobj:last_call(PC),

    ok = leave(Rm, "pt_1"),

    #state{rid=RID, partis=Partis4, pconns=Pconns4} = cur_state(Rm),
    
    0 = length(Partis4),
    0 = length(Pconns4),

    destroy(Rm),
    mockobj:stop(B1),
    mockobj:stop(B2),
    ok.

test_3peers_enter_a_5P_p2proom() ->
    RmTopo = roomtopo:from_type_attr(p2pav, [{capacity, 5}]),
    #topo{roles=[{peer, 5}], drcts=[{peer, {[peer], [peer]}}], tracks=[{peer, {[{peer, av}], [{peer, av}]}}]} = RmTopo,
    {ok, Rm} = create("room108", RmTopo, test),
    #state{rid=RID, topo=RmTopo, partis=Partis, pconns=Pconns} = cur_state(Rm),
    0 = length(Partis),
    0 = length(Pconns),
    B1 = mockobj:start(),
    B2 = mockobj:start(),
    B3 = mockobj:start(),

    none = mockobj:last_call(B1),
    none = mockobj:last_call(B2),

    {ok, "pt_0"} = enter(Rm, B1, peer),

    #state{rid=RID, partis=Partis1, pconns=Pconns1} = cur_state(Rm),
    
    1 = length(Partis1),
    0 = length(Pconns1),
    #parti{pt_role=peer, in_pcs=[], pt=B1} = proplists:get_value("pt_0", Partis1),

    {ok, "pt_1"} = enter(Rm, B2, peer),

    #state{rid=RID, partis=Partis2, pconns=Pconns2} = cur_state(Rm),
    
    2 = length(Partis2),
    1 = length(Pconns2),
    #parti{pt_role=peer, in_pcs=["pc_0"], pt=B1} = proplists:get_value("pt_0", Partis2),
    #parti{pt_role=peer, in_pcs=["pc_0"], pt=B2} = proplists:get_value("pt_1", Partis2),
    #pconn{pts=Pts, pc=PC} = proplists:get_value("pc_0", Pconns2),
    2 = length(Pts),
    {establish, {"room108", "pc_0", {"pt_1", B2, {send_receive, send_receive}}, {"pt_0", B1, {send_receive, send_receive}}, "pt_1"}} = mockobj:last_call(PC),

    {ok, "pt_2"} = enter(Rm, B3, peer),

    #state{rid=RID, partis=Partis3, pconns=Pconns3} = cur_state(Rm),
    
    3 = length(Partis3),
    3 = length(Pconns3),
    %mockobj:check_equal(?MODULE, ?LINE, #parti{pt_role=peer, in_pcs=["pc_0", "pc_2"], pt=Pt1}, proplists:get_value("pt_0", Partis3)),
    #parti{pt_role=peer, in_pcs=["pc_0", "pc_2"], pt=B1} = proplists:get_value("pt_0", Partis3),
    #parti{pt_role=peer, in_pcs=["pc_0", "pc_1"], pt=B2} = proplists:get_value("pt_1", Partis3),
    #parti{pt_role=peer, in_pcs=["pc_1", "pc_2"], pt=B3} = proplists:get_value("pt_2", Partis3),
    #pconn{pts=Pts, pc=PC} = proplists:get_value("pc_0", Pconns3),
    #pconn{pts=Pts1, pc=PC1} = proplists:get_value("pc_1", Pconns3),
    #pconn{pts=Pts2, pc=PC2} = proplists:get_value("pc_2", Pconns3),
    2 = length(Pts),
    2 = length(Pts1),
    2 = length(Pts2),

    %mockobj:check_equal(?MODULE, ?LINE, {establish, {"pc_1", bidi, {"pt_2", Pt3}, {"pt_1", Pt2}, "pt_2"}}, mockobj:last_call(PC1)),
    {establish, {"room108", "pc_1", {"pt_2", B3, {send_receive, send_receive}}, {"pt_1", B2, {send_receive, send_receive}}, "pt_2"}} = mockobj:last_call(PC1),
    {establish, {"room108", "pc_2", {"pt_2", B3, {send_receive, send_receive}}, {"pt_0", B1, {send_receive, send_receive}}, "pt_2"}} = mockobj:last_call(PC2),

    
    ok = leave(Rm, "pt_0"),

    #state{rid=RID, partis=Partis4, pconns=Pconns4} = cur_state(Rm),
    
    2 = length(Partis4),
    1 = length(Pconns4),
    #parti{pt_role=peer, in_pcs=["pc_1"], pt=B2} = proplists:get_value("pt_1", Partis4),
    #parti{pt_role=peer, in_pcs=["pc_1"], pt=B3} = proplists:get_value("pt_2", Partis4),

    {release, {PC}} = mockobj:last_call(PC),
    {release, {PC2}} = mockobj:last_call(PC2),

    ok = leave(Rm, "pt_1"),

    #state{rid=RID, partis=Partis5, pconns=Pconns5} = cur_state(Rm),
    
    1 = length(Partis5),
    0 = length(Pconns5),
    #parti{pt_role=peer, in_pcs=[], pt=B3} = proplists:get_value("pt_2", Partis5),  
    {release, {PC1}} = mockobj:last_call(PC1),

    ok = leave(Rm, "pt_2"),

    #state{rid=RID, partis=Partis6, pconns=Pconns6} = cur_state(Rm),
    
    0 = length(Partis6),
    0 = length(Pconns6),

    destroy(Rm),
    mockobj:stop(B1),
    mockobj:stop(B2),
    mockobj:stop(B3),
    ok.

test_the3rd_peer_failed_to_enter_p2proom() ->
    RmTopo = roomtopo:from_type_attr(p2pav, [{capacity, 2}]),
    {ok, Rm} = create("room108", RmTopo, test),
    B1 = mockobj:start(),
    B2 = mockobj:start(),
    B3 = mockobj:start(),

    {ok, "pt_0"} = enter(Rm, B1, peer),
    {ok, "pt_1"} = enter(Rm, B2, peer),
    %mockobj:check_equal(?MODULE, ?LINE, {failed, "Room can NOT accommodate any more participants of role[peer]."}, enter(Rm, B3, peer)),
    {failed, "Room can NOT accommodate any more participants of role[peer]."} = enter(Rm, B3, peer),
    ok = leave(Rm, "pt_0"),
    ok = leave(Rm, "pt_1"),
    destroy(Rm),
    mockobj:stop(B1),
    mockobj:stop(B2),
    mockobj:stop(B3),
    ok.

log(Str, CmdList) ->
    chk_log_size(),
    {ok, IODev} = file:open("./room.log", [append]),
    io:format(IODev,"~p: "++Str++"~n",[erlang:localtime()|CmdList]),
    file:close(IODev).

chk_log_size() ->
	case file:read_file_info(?LOGFILE) of
		{ok, Finfo} ->
			if
				element(2, Finfo) > ?LOGMAXSIZE ->
					file:copy(?LOGFILE, ?BACKLOG),
					file:delete(?LOGFILE);
				true ->
					void
			end;
		{error, _} ->
			void
	end.
    
