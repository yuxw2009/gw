-module(peerconn).
-compile(export_all).

-record(pt, {ptid,       
             parti,      %% Process of participant. 
             opts,
             audio,      %% send_only|receive_only|send_receive|none. 
             video       %% send_only|receive_only|send_receive|none. 
            }).

-record(state, {rid,
                pcid,
                status = broken,  %% broken, offering, answering, connected
	            pt1,              %% #pt  offer
	            pt2,              %% #pt  answer
	            relayer,
                offerer           %% ptid of the offerer.
	            }).


-behaviour(gen_server).
-export([init/1,
     handle_call/3,
     handle_cast/2,
     handle_info/2,
     terminate/2,
     code_change/3
    ]).

%%% external API.
%%%%%%%%%%%%%%%%%%%%%%
%% PCID -peerconnection ID.
%% Pt1  -{Ptid1, PtP1, AudioDirection1, VideoDirection1}
%% Pt2  -{Ptid1, PtP1, AudioDirection2, VideoDirection2}
%% Offerer -The offerer, the value must equal to Ptid1 or Ptid2.
%%%%%%%%%%%%%%%%%%%%%%%
establish(RID, PCID, _OPt=Pt1={_Ptid1, _Pt1, {_A1, _V1}, _Opts1}, _APt=Pt2={_Ptid2, _Pt2, {_A2, _V2},_Opts2}, Offerer) ->
    {ok, Pc} = gen_server:start(?MODULE, {RID, PCID, Pt1, Pt2, Offerer}, []),
    gen_server:cast(Pc, {establish, Offerer}),
    Pc.

release(Pc) ->
    gen_server:cast(Pc, {release}),
    Pc ! {release},
    ok.

current_state(PC) ->
   gen_server:call(PC, {get_cur_state}).

report(PC, {From, {offer, Data}}) ->
   on_offer(PC, {From, Data});
report(PC, {From, {answer, Data}}) ->
   on_answer(PC, {From, Data});
report(PC, {From, {candidate, Data}}) ->
   on_candidate(PC, {From, Data});
report(PC, {From, {state, Data}}) ->
   on_state(PC, {From, Data}).

on_offer(PC, {Offerer, Sdp}) ->
   gen_server:cast(PC, {on_offer, {Offerer, Sdp}}).

on_answer(PC, {Answerer, Sdp}) ->
   gen_server:cast(PC, {on_answer, {Answerer, Sdp}}).

on_candidate(PC, {From, Can}) ->
   gen_server:cast(PC, {on_candidate, {From, Can}}).

on_state(PC, {From, Data}) ->
   gen_server:cast(PC, {on_state, {From, Data}}).

%%% gen_server callbacks
init({RID, PCID, {Ptid1, Pt1, {A1, V1},Opts1}, {Ptid2, Pt2, {A2, V2},Opts2}, Offerer}) ->
    {ok, #state{rid=RID, pcid=PCID, status=broken, pt1=#pt{ptid=Ptid1, parti=Pt1, audio=A1, video=V1,opts=Opts1}, pt2=#pt{ptid=Ptid2, parti=Pt2, audio=A2, video=V2,opts=Opts2}, offerer=Offerer}}.

handle_info(_Unhandeld,State=#state{status=_Status}) ->
    {noreply, State}.

handle_cast({establish, Offerer}, State=#state{rid=RID, pcid=PCID, status=broken, pt1=#pt{ptid=Ptid1, parti=Pt1, audio=A1, video=V1}, pt2=#pt{ptid=Ptid2, parti=Pt2, audio=A2, video=V2}})->
    {Pt, Ptid, Tracks, PeerPt} = case Offerer of
                            Ptid1 -> {Pt1, Ptid1, [{a, A1}, {v, V1}], Pt2};
                            Ptid2 -> {Pt2, Ptid2, [{a, A2}, {v, V2}], Pt1}
                         end,
    Pt ! {require, offer, {RID, Ptid, PCID, Tracks, PeerPt}},
    {noreply, State#state{status=offering}};

handle_cast({on_offer, {Offerer, Sdp}}, State=#state{rid=RID, pcid=PCID, status=offering, pt1=#pt{ptid=Ptid1, parti=Pt1, audio=A1, video=V1,opts=Opts1}, pt2=#pt{ptid=Ptid2, parti=Pt2, audio=A2, video=V2,opts=Opts2}})->
    {Pt, Ptid, Tracks,PeerPt,O_opts,A_opts} = case Offerer of
                            Ptid1 -> {Pt2, Ptid2, [{a, A2}, {v, V2}], Pt1,Opts1,Opts2};
                            Ptid2 -> {Pt1, Ptid1, [{a, A1}, {v, V1}],Pt2,Opts2,Opts1}
                          end,
    Relayer=create_relayer([{proto,udp},{o_opts,O_opts}, {a_opts,A_opts}]),
    NewSdp = update_offer(Relayer, Sdp),
    Pt ! {require, answer, {RID, Ptid, PCID, {Tracks, NewSdp},PeerPt}},
    {noreply, State#state{status=answering,relayer=Relayer}};

handle_cast({on_answer, {Answerer, Sdp}}, State=#state{rid=RID, pcid=PCID, status=answering, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2},relayer=Relayer}) ->
    {Pt, Ptid} = case Answerer of
                     Ptid1 -> {Pt2, Ptid2};
                     Ptid2 -> {Pt1, Ptid1}
                 end,
    NewSdp = update_answer(Relayer, Sdp),
    Pt ! {notify, answer, {RID, Ptid, PCID, NewSdp}},
    {noreply, State#state{status=connected}};

handle_cast({on_candidate, {From, Can}}, State=#state{rid=RID, pcid=PCID, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2}}) ->
    {Pt, Ptid} = case From of
                     Ptid1 -> {Pt2, Ptid2};
                     Ptid2 -> {Pt1, Ptid1}
                 end,
    Pt ! {notify, candidate, {RID, Ptid, PCID, Can}},
    {noreply, State};

handle_cast({on_state, {From, <<"kickout">>}}, State=#state{rid=RID, pcid=PCID, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2}}) ->
    {Pt, Ptid} = case From of
                     Ptid1 -> {Pt2, Ptid2};
                     Ptid2 -> {Pt1, Ptid1}
                 end,
    Pt ! {notify, state, {RID, Ptid, PCID, <<"kickout">>}},
    room_mgr:leave(RID, Ptid),
    {noreply, State};

handle_cast({on_state, {From, Data}}, State=#state{rid=RID, pcid=PCID, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2}}) ->
    {Pt, Ptid} = case From of
                     Ptid1 -> {Pt2, Ptid2};
                     Ptid2 -> {Pt1, Ptid1}
                 end,
    Pt ! {notify, state, {RID, Ptid, PCID, Data}},
    {noreply, State};

handle_cast({release}, State=#state{status=broken}) ->
    {stop, normal, State#state{status=broken}};
handle_cast({release}, State=#state{rid=RID, pcid=PCID, status=offering, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2}, offerer=Offerer}) ->
    {Pt, Ptid} = case Offerer of
                     Ptid1 -> {Pt2, Ptid2};
                     Ptid2 -> {Pt1, Ptid1}
                 end,
    Pt ! {require, close, {RID, Ptid, PCID}},
    {stop, normal, State#state{status=broken}};
handle_cast({release}, State=#state{rid=RID, pcid=PCID, pt1=#pt{ptid=Ptid1, parti=Pt1}, pt2=#pt{ptid=Ptid2, parti=Pt2}}) ->
    Pt1 ! {require, close, {RID, Ptid1, PCID}},
    Pt2 ! {require, close, {RID, Ptid2, PCID}},
    {stop, normal, State#state{status=broken}};

handle_cast(_Msg, State)->
    {noreply, State}.

handle_call({get_cur_state}, _From, State) ->
    {reply, State, State};
handle_call(_Msg, _From, State)->
    {reply, ok, State}.

code_change(_Oldvsn, State, _Extra)->
    {ok, State}.


terminate(Reason, #state{relayer=Relayer})->
    room:log("~p peerconn ~p terminate, reason:~p, destroy relayer ~p", [erlang:localtime(), self(), Reason, Relayer]),
    destroy_relayer(Relayer),
    Reason.

%% Inner Methods.

%%%% test case.
test() ->
    test_normally_one_way_pc(),
    timer:sleep(300),
    test_normally_bidi_pc(),
    ok.

test_normally_one_way_pc() ->
    Pt1 = mockobj:start(),
    Pt2 = mockobj:start(),
    
    PC = establish("rm1", "pc_28", {"pt_1", Pt1, {send_only, send_only},[]},
                            {"pt_2", Pt2, {receive_only, receive_only},[]}, "pt_2"),
    timer:sleep(10),

    {require, offer, {"rm1", "pt_2", "pc_28", [{a, receive_only}, {v, receive_only}], Pt1}} = mockobj:last_call(Pt2),
    #state{pcid="pc_28", status=offering, pt1=#pt{ptid="pt_1", parti=Pt1, audio=send_only, video=send_only}, pt2=#pt{ptid="pt_2", parti=Pt2, audio=receive_only, video=receive_only}, offerer="pt_2"} = current_state(PC),
    
    on_offer(PC, {"pt_2", "sdp2"}),
    timer:sleep(10),
    
    {require, answer, {"rm1", "pt_1", "pc_28", {[{a, send_only}, {v, send_only}], "sdp2"}, Pt2}} = mockobj:last_call(Pt1),
    #state{pcid="pc_28", status=answering} = current_state(PC),
    
    on_answer(PC, {"pt_1", "sdp1"}),
    timer:sleep(10),

    {notify, answer, {"rm1", "pt_2", "pc_28", "sdp1"}} = mockobj:last_call(Pt2),
    #state{pcid="pc_28", status=connected} = current_state(PC),
    
    release(PC),
    mockobj:stop(Pt1),
    mockobj:stop(Pt2),
    ok.

test_normally_bidi_pc() ->
    Pt1 = mockobj:start(),
    Pt2 = mockobj:start(),
    
    PC = establish("rm1", "pc_28", {"pt_1", Pt1, {send_receive, send_receive}},
                            {"pt_2", Pt2, {send_receive, send_receive}}, "pt_1"),
    timer:sleep(10),

    {require, offer, {"rm1", "pt_1", "pc_28", [{a, send_receive}, {v, send_receive}]}} = mockobj:last_call(Pt1),
    #state{pcid="pc_28", status=offering, pt1=#pt{ptid="pt_1", parti=Pt1, audio=send_receive, video=send_receive}, pt2=#pt{ptid="pt_2", parti=Pt2, audio=send_receive, video=send_receive}, offerer="pt_1"} = current_state(PC),
    
    on_offer(PC, {"pt_1", "sdp1"}),
    timer:sleep(10),
    
    {require, answer, {"rm1", "pt_2", "pc_28", [{a, send_receive}, {v, send_receive}], "sdp1"}} = mockobj:last_call(Pt2),
    #state{pcid="pc_28", status=answering} = current_state(PC),
    
    on_answer(PC, {"pt_2", "sdp2"}),
    timer:sleep(10),

    {notify, answer, {"rm1", "pt_1", "pc_28", "sdp2"}} = mockobj:last_call(Pt1),
    #state{pcid="pc_28", status=connected} = current_state(PC),
    
    release(PC),
    mockobj:stop(Pt1),
    mockobj:stop(Pt2),
    ok.

create_relayer(Pls)  ->
    swap:create_relayer(Pls).
update_offer(PID, OfferSDP) ->
  swap:update_offer(PID,OfferSDP).
%    OfferSDP.
update_answer(PID, AnswerSDP) -> 
    swap:update_answer(PID, AnswerSDP).
%    AnswerSDP.
destroy_relayer(undefined)->
    void;
destroy_relayer(PID)->
    swap:destroy_relayer(PID).

