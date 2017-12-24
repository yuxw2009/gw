-module(opr_test).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include("db_op.hrl").
-include("opr.hrl").
-define(GroupNo,"112").
-define(GroupPhone,"52300112").
-define(SeatNo,"6").
-define(User,"8866").
-define(Pwd, "8866").



mytest()->
    callb_test(),
    calla_test(),
    callb_and_calla_test(),
    unfocus_calla_test(),
    callb_and_calla_sideb_test(),
    mixer_2way_test(),
    ok.

% opr_logout_test()->
%     {ok,OprPid}=opr_sup:login(?SeatNo),
%     opr_sup:logout(?SeatNo),
%     utility1:delay(1000),
%     ?assert(not is_process_alive(OprPid)),
%     ok.

callb_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),
    %test callb
    board:callb(Board1,"8"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),

    % test sidea answer
    Board1 ! {callee_status,BUA, hook_off},  %模拟应答
    utility1:delay(20),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),    
   
    % test release sidea
    BUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sideb(Board1),
    ?assertEqual(null,board:get_status({"6",1})),   
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),  
    opr_sup:logout(?SeatNo),
         ok.
calla_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),
    #{ua:=AUA0,mediaPid:=AMedia0}=board:get_sidea(Board1),
    ?assert((not is_pid(AUA0)) andalso (not is_pid(AMedia0))),
    Mixer=board:get_mixer(Board1),

    %test calla
    board:calla(Board1,"8"),
    ?assertEqual(sidea,board:get_status({"6",1})),
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),
    ?assert(is_pid(AUA) andalso is_pid(AMedia)),
    ?assertEqual(2, maps:size(mixer:get_sides(Mixer))),


    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),

    % test unfocus
    board:unfocus(Board1),
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),
    ?assertEqual(1, maps:size(mixer:get_sides(Mixer))),

    board:focus(Board1),
    utility1:delay(20),
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assert( mixer:has_media(Mixer,OprMedia)),
    ?assertEqual(2, maps:size(mixer:get_sides(Mixer))),
        % test sidea answer
    Board1 ! {callee_status,AUA, hook_off},  %模拟应答
    utility1:delay(20),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
    
    board:unfocus(Board1),
    utility1:delay(50),
    ?assertEqual(sidea,board:get_status({"6",1})),    
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),
    % test release sidea
    AUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea(Board1),
    ?assertEqual(null,board:get_status({"6",1})),
    opr_sup:logout(?SeatNo),
    ok.

callb_and_calla_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    %test callb
    board:callb(Board1,"9"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
    ?assert(mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    % test sidea
    board:calla(Board1,"8"),    
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assertEqual(undefined,sip_media:get_media(BMedia)),
    ?assert(not mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),    
    %模拟B应答
    Board1 ! {callee_status,BUA, hook_off},  
    utility1:delay(20),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),    
    ?assertEqual(sidea,board:get_status({"6",1})),

    % test release sidea
    AUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea(Board1),
    ?assertEqual(null,board:get_status({"6",1})),   
    opr_sup:logout(?SeatNo),
         ok.
unfocus_calla_test()->
    BoardIndex={?SeatNo,1},
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release(BoardIndex),
    board:unfocus(BoardIndex),
    Board1=opr:get_board(?SeatNo,1),
    Mixer=board:get_mixer(Board1),    
    board:calla(Board1,"8"),
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),    
    OprMedia=opr:get_mediaPid(OprPid),    
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    board:focus(BoardIndex),
    ?assert( mixer:has_media(Mixer,OprMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    Board1 ! {callee_status,AUA,hook_off},
    ?assert( mixer:has_media(Mixer,OprMedia)),
    utility1:delay(20),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
    opr_sup:logout(?SeatNo),
    ok.
callb_and_calla_sideb_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    %test callb
    board:callb(Board1,"9"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
    ?assert(mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    % test calla
    board:calla(Board1,"8"),    
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assertEqual(undefined,sip_media:get_media(BMedia)),
    ?assert(not mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),   

    %模拟B应答
    Board1 ! {callee_status,BUA, hook_off},  
    utility1:delay(20),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),    
    ?assertEqual(sidea,board:get_status({"6",1})),

    % sideb test
    board:sideb(Board1),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),    
    ?assertEqual(sideb,board:get_status({"6",1})),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assert( mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(not mixer:has_media(Mixer,AMedia)),        

    % sidea test
    board:sidea(Board1),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),    
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assert( mixer:has_media(Mixer,AMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(not mixer:has_media(Mixer,BMedia)),       

    % test release sidea
    AUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea(Board1),
    ?assertEqual(null,board:get_status({"6",1})),   
    opr_sup:logout(?SeatNo),
         ok.
mixer_2way_test()->
    {ok,Mixer}=mixer:start(),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),    

    %test callb
    board:callb(Board1,"8"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    mixer:add(Mixer,OprMedia),
    mixer:add(Mixer,BMedia),
    ?assertEqual(#{OprMedia=>[],BMedia=>[]},mixer:get_sides(Mixer)),
    %opr_sup:logout(?SeatNo),
    % sip_media:stop(BMedia),
    % ?assertEqual(#{OprMedia=>[]},mixer:get_sides(Mixer)),
    % sip_media:stop(OprMedia),
    % ?assertEqual(#{},mixer:get_sides(Mixer)),
    ok.    
add_opr_test()->
    GroupNo= ?GroupNo,
    SeatNo= ?SeatNo,
    User= ?User,
    Pwd= ?Pwd,
    opr_sup:add_opr(GroupNo,SeatNo,User,Pwd),
    [_Opr=#opr{seat_no=SeatNo,item=#{user:=User,group_no:=GroupNo}}]=opr_sup:get_by_seatno(SeatNo),
    {atomic, [_]}=opr_sup:get_user(User).

del_opr_test()->
    opr_sup:del_opr(?SeatNo),
    []=opr_sup:get_by_seatno(?SeatNo),
    ok.
add_oprgroup_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    [#oprgroup_t{key=_GroupNo,item=#{phone:=?GroupPhone}}]=opr_sup:get_oprgroup(?GroupNo),
    ok.
login_test()->
    opr_sup:stop(),
    add_opr_test(),
    %OprPid=spawn(fun()-> receive a-> wait end end),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    ?assert(whereis(opr_sup)=/=undefined),
    ?assertEqual(OprPid,opr_sup:get_opr_pid(?SeatNo)),
    UA=opr:get_ua(OprPid),
    UANode=node(UA),
    ?assert(is_pid(UA) andalso rpc:call(UANode,erlang,is_process_alive,[UA])),
    MediaPid=opr:get_mediaPid(OprPid),
    ?assert(is_pid(MediaPid) andalso rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
    Boards=opr:get_boards(OprPid),
    {ok,OprPid1}=opr_sup:login(?SeatNo),
    ?assertEqual(OprPid,OprPid1),
    ?assert(length(Boards)==16 andalso is_pid(hd(Boards)) andalso is_process_alive(hd(Boards))),
    MediaPid=opr:get_mediaPid(OprPid),
    opr:stop(OprPid),
     utility1:delay(500),
     ?assert(not rpc:call(UANode,erlang,is_process_alive,[UA])),
     ?assert(not rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
     undefined=opr_sup:get_opr_pid(?SeatNo),
    ok.
ab_test()->
    opr_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Boards=opr:get_boards(OprPid),
    Board1=hd(Boards),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    %test callb
    board:callb(Board1,"9"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
    ?assert(mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    %模拟B应答
    Board1 ! {callee_status,BUA, hook_off},  
    utility1:delay(20),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),    
    ?assertEqual(sideb,board:get_status({"6",1})),

    % test calla
    board:calla(Board1,"8"),    
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assertEqual(undefined,sip_media:get_media(BMedia)),
    ?assert(not mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),    
    % test ab
    board:ab(Board1),
    ?assertEqual(ab,board:get_status({"6",1})),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assert( mixer:has_media(Mixer,BMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),        
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(ab,board:get_status({"6",1})),       
    % test release sidea
    AUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea(Board1),
    ?assertEqual(null,board:get_status({"6",1})),   
    opr_sup:logout(?SeatNo),
         ok.
inserta_test()->
   todo.
insertb_test()->
   todo.
third_test()->
   todo.
splita_test()->
   todo.
splitb_test()->
    todo.
monitor_test()->
    todo.
releasea_test()->
    todo.
releaseb_test()->
    todo.
crossboard_test()->
    todo.             
incomingcall_test()->
    todo.