-module(opr_test).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include("db_op.hrl").
-include("opr.hrl").
-define(GroupNo,"912").
-define(GroupPhone,"52300112").
-define(SeatPhone,"52300001").
-define(OPRID,"001").
-define(SeatNo,"6").
-define(User,"8866").
-define(Pwd, "8866").
-define(OPRID1,"002").
-define(SeatNo1,"8").
-define(User1,"888").
-define(Pwd1, "888").

%  sample
third_sample()->
   ab_sample(),
   OprMedia=opr:get_mediaPid(?SeatNo),
   Board1=board:get({?SeatNo,1}),
   %board:third(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"third","seatId"=>?SeatNo,"boardIndex"=>"1"}),

   Mixer=board:get_mixer(Board1),
   ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
   ?assertEqual(third,board:get_status(Board1)),
   ?assertEqual(3,maps:size(mixer:get_sides(Mixer))),
   ok.
ab_sample()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    OprUA=opr:get_ua(OprPid),
    Board1=opr:get_board(OprPid,1),
    opr:focus(OprPid,1),    
    %board:focus(Board1),
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
    utility1:delay(50),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),    
    ?assertEqual(sideb,board:get_status({"6",1})),
    [{OSC,ORC},void,{BSC,BRC}]=board:get_count(Board1),

    % test calla
    board:calla(Board1,"8"),    
    #{ua:=AUA,mediaPid:=AMedia}=board:get_sidea(Board1),
    ?assertEqual(sidea,board:get_status({"6",1})),
    ?assertEqual(undefined,sip_media:get_media(BMedia)),
    ?assert(not mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),    
    ?assertMatch([{_,_},{ASC,ARC},{BSC,BRC}],board:get_count(Board1)),
    % test ab
    %board:ab(Board1),
   {ok,#{"status":=<<"ok">>,"boardState":=_}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"ab","seatId"=>?SeatNo,"boardIndex"=>"1"}),

    ?assertEqual(ab,board:get_status({"6",1})),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assert( mixer:has_media(Mixer,BMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),
    ?assert(mixer:has_media(Mixer,AMedia)),        
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(ab,board:get_status({"6",1})),
    ok.


mytest()->
    callb_test(),
    calla_test(),
    callb_and_calla_test(),
    unfocus_calla_test(),
    callb_and_calla_sideb_test(),
    mixer_2way_test(),
    ok.

callb_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
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
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
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
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
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
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
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
    %board:sideb(Board1),
    %utility1:delay(100),
    {ok,#{"status":=<<"ok">>}}=
        utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"sideb","seatId"=>?SeatNo,"boardIndex"=>"1"}),

    ?assertEqual(sideb,board:get_status({"6",1})),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assert( mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    ?assert(not mixer:has_media(Mixer,AMedia)),        
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),    

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
    Board1=opr:get_board(OprPid,1),
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
    [_Opr=#seat_t{seat_no=SeatNo,item=#{user:=User,group_no:=GroupNo}}]=opr_sup:get_by_seatno(SeatNo),
    {atomic, [_]}=opr_sup:get_user(User).

del_opr_test()->
    opr_sup:del_opr(?SeatNo),
    []=opr_sup:get_by_seatno(?SeatNo),
    ok.
login_test()->
    add_opr_test(),
    TESTIP="192.16.1.1",
    %OprPid=spawn(fun()-> receive a-> wait end end),
    {ok,OprPid}=opr_sup:login(?SeatNo,TESTIP,?OPRID),
    ?assertEqual(OprPid,opr_sup:get_oprpid_by_oprid(?OPRID)),
    ?assert(whereis(opr_sup)=/=undefined),
    ?assertEqual(OprPid,opr_sup:get_opr_pid(?SeatNo)),
    ?assertEqual(TESTIP,opr:get_client_host(OprPid)),
    UA=opr:get_ua(OprPid),
    UANode=node(UA),
    ?assert(is_pid(UA) andalso rpc:call(UANode,erlang,is_process_alive,[UA])),
    MediaPid=opr:get_mediaPid(OprPid),
    ?assert(is_pid(MediaPid) andalso rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
    Board1=opr:get_board(OprPid,1),
    Boards=opr:get_boards(OprPid),
    {ok,OprPid1}=opr_sup:login(?SeatNo),
    ?assertEqual(OprPid,OprPid1),
    ?assert(length(Boards)==14 andalso is_pid(Board1) andalso is_process_alive(Board1)),
    MediaPid=opr:get_mediaPid(OprPid),
    opr:stop(OprPid),
     utility1:delay(500),
     ?assert(not rpc:call(UANode,erlang,is_process_alive,[UA])),
     ?assert(not rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
     undefined=opr_sup:get_opr_pid(?SeatNo),
    ok.
clean_board_test()->
    third_sample(),       
    % test release sidea
    Mixer=board:get_mixer({?SeatNo,1}),
    ?assertEqual(third,board:get_status({?SeatNo,1})),
    ?assertEqual(3,maps:size(mixer:get_sides(Mixer))),
    BMedia=board:get_b_media({?SeatNo,1}),
    AMedia=board:get_a_media({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(?SeatNo),
    ?assertEqual(Mixer,sip_media:get_media(AMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
  
    {ok,#{"status":=<<"ok">>}}=
        utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"clean_board","seatId"=>?SeatNo,"boardIndex"=>"1"}),
    Mixer=board:get_mixer({?SeatNo,1}),
    ?assertEqual(null,board:get_status({?SeatNo,1})),
    ?assertEqual(0,maps:size(mixer:get_sides(Mixer))),
    undefined=board:get_b_media({?SeatNo,1}),
    undefined=board:get_a_media({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(?SeatNo),
    utility1:delay(100),
    ?assert(not is_process_alive(AMedia)),
    ?assert(not is_process_alive(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    AMedia.
ab_test()->
    ab_sample(),       
    % test release sidea
    AUA=board:get_a_ua({?SeatNo,1}),
    AUA ! stop,
    utility1:delay(50),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea({?SeatNo,1}),
    ?assertEqual(null,board:get_status({"6",1})),   
    opr_sup:logout(?SeatNo),
         ok.
board_mixer_exit_test()->
   ab_sample(),
   Board1=board:get({?SeatNo,1}),
   Mixer=board:get_mixer(Board1),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   ?assert( mixer:has_media(Mixer,BMedia)),
   ?assert( mixer:has_media(Mixer,AMedia)),
   mixer:stop(Mixer),
   utility1:delay(30),
   Mixer1=board:get_mixer(Board1),
   ?assert(is_pid(Mixer1) andalso Mixer1=/=Mixer andalso is_process_alive(Mixer1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer1))),  
   ?assert( mixer:has_media(Mixer1,BMedia)),
   ?assert( mixer:has_media(Mixer1,AMedia)),
   ok.

board_exit_test()->
   ab_sample(),
   Board=board:get({?SeatNo,1}),
   Mixer=board:get_mixer(Board),
   BMedia=board:get_b_media(Board),
   AMedia=board:get_a_media(Board),
   ?assert( mixer:has_media(Mixer,BMedia)),
   ?assert( mixer:has_media(Mixer,AMedia)),
   board:stop(Board),
   utility1:delay(30),
   Board1=board:get({?SeatNo,1}),
   ?assert(is_pid(Board1) andalso Board1=/=Board andalso is_process_alive(Board1)),
   Mixer1=board:get_mixer(Board1),
   ?assert(is_pid(Mixer1) andalso Mixer1=/=Mixer andalso is_process_alive(Mixer1)),
   ok.

inserta_test()->
   ab_sample(),
   Board1=board:get({?SeatNo,1}),
   %board:inserta(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"inserta","seatId"=>?SeatNo,"boardIndex"=>"1"}),

   Mixer=board:get_mixer(Board1),
   ?assertEqual(inserta,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   OprMedia=opr:get_mediaPid(?SeatNo),
   ?assert(not mixer:has_media(Mixer,BMedia)),
   ?assert(mixer:has_media(Mixer, AMedia)),
   ?assert(mixer:has_media(Mixer, OprMedia)),

   % test ab
   board:ab(Board1),
   ?assertEqual(ab,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,OprMedia)),
   ?assert(mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,BMedia)),

   %test inserta,a down
   board:inserta(Board1),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(null,board:get_status(Board1)),
   ?assertEqual(1,maps:size(mixer:get_sides(Mixer))),  
   board:sideb(Board1), 
   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),  
   %test mixer exit
   mixer:stop(Mixer),
   utility1:delay(30),
   Mixer1=board:get_mixer(Board1),
   ?assert(is_pid(Mixer1) andalso Mixer1=/=Mixer andalso is_process_alive(Mixer1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer1))),  

   opr_sup:logout("6"),
   ok.
insertb_test()->
   ab_sample(),
   Board1=board:get({?SeatNo,1}),

   % test insertb
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"insertb","seatId"=>?SeatNo,"boardIndex"=>"1"}),
   Mixer=board:get_mixer(Board1),
   ?assertEqual(insertb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   OprMedia=opr:get_mediaPid(?SeatNo),
   ?assert(not mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer, BMedia)),
   ?assert(mixer:has_media(Mixer, OprMedia)),

   % test ab
   board:ab(Board1),
   ?assertEqual(ab,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,OprMedia)),
   ?assert(mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,BMedia)),

   %test insertb,a down
   board:insertb(Board1),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),  
   opr_sup:logout("6"),
   ok.

third_test()->
   ab_sample(),
   OprMedia=opr:get_mediaPid(?SeatNo),
   Board1=board:get({?SeatNo,1}),
   board:third(Board1),
   Mixer=board:get_mixer(Board1),
   ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
   ?assertEqual(third,board:get_status(Board1)),
   ?assertEqual(3,maps:size(mixer:get_sides(Mixer))),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),   
   opr_sup:logout("6"),
   ok.
splita_test()->
   ab_sample(),
   Board1=board:get({?SeatNo,1}),

   %board:splita(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"splita","seatId"=>?SeatNo,"boardIndex"=>"1"}),
   Mixer=board:get_mixer(Board1),
   ?assertEqual(splita,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   OprMedia=opr:get_mediaPid(?SeatNo),
   ?assert(not mixer:has_media(Mixer,BMedia)),
   ?assert(mixer:has_media(Mixer, AMedia)),
   ?assert(mixer:has_media(Mixer, OprMedia)),

   % test ab
   board:ab(Board1),
   ?assertEqual(ab,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,OprMedia)),
   ?assert(mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,BMedia)),

   %test splita,a down
   board:splita(Board1),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(null,board:get_status(Board1)),
   ?assertEqual(1,maps:size(mixer:get_sides(Mixer))),  
   board:sideb(Board1), 
   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),  
   opr_sup:logout("6"),
   ok.
splitb_test()->
   ab_sample(),
   Board1=board:get({?SeatNo,1}),

   % test splitb
   %board:splitb(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"splitb","seatId"=>?SeatNo,"boardIndex"=>"1"}),
   Mixer=board:get_mixer(Board1),
   ?assertEqual(splitb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   OprMedia=opr:get_mediaPid(?SeatNo),
   ?assert(not mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer, BMedia)),
   ?assert(mixer:has_media(Mixer, OprMedia)),

   % test ab
   board:ab(Board1),
   ?assertEqual(ab,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,OprMedia)),
   ?assert(mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,BMedia)),

   %test insertb,a down
   board:insertb(Board1),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),  
   opr_sup:logout("6"),
   ok.
monitor_test()->
   ab_sample(),
   OprMedia=opr:get_mediaPid(?SeatNo),
   Board1=board:get({?SeatNo,1}),
   %board:monitor(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"monitor","seatId"=>?SeatNo,"boardIndex"=>"1"}),
   Mixer=board:get_mixer(Board1),
   ?assertEqual(undefined,sip_media:get_media(OprMedia)),
   ?assertEqual(monitor,board:get_status(Board1)),
   ?assertEqual(3,maps:size(mixer:get_sides(Mixer))),
   AUA=board:get_a_ua(Board1),
   AUA ! stop,
   utility1:delay(50),
   ?assertEqual(null,board:get_status(Board1)),
   ?assertEqual(0,maps:size(mixer:get_sides(Mixer))),   
   opr_sup:logout("6"),
   ok.
releasea_test()->
   ab_sample(),
   OprMedia=opr:get_mediaPid(?SeatNo),
   Board1=board:get({?SeatNo,1}),
   Mixer=board:get_mixer(Board1),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   board:insertb(Board1),
   %board:releasea(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"releasea","seatId"=>?SeatNo,"boardIndex"=>"1"}),

   ?assertEqual(sideb,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,BMedia)),
   ?assert(mixer:has_media(Mixer,OprMedia)),
   ok.
releaseb_test()->
   ab_sample(),
   OprMedia=opr:get_mediaPid(?SeatNo),
   Board1=board:get({?SeatNo,1}),
   Mixer=board:get_mixer(Board1),
   BMedia=board:get_b_media(Board1),
   AMedia=board:get_a_media(Board1),
   board:inserta(Board1),
   {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"releaseb","seatId"=>?SeatNo,"boardIndex"=>"1"}),
   ?assertEqual(sidea,board:get_status(Board1)),
   ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
   ?assert(not mixer:has_media(Mixer,BMedia)),
   ?assert(mixer:has_media(Mixer,AMedia)),
   ?assert(mixer:has_media(Mixer,OprMedia)),
   opr_sup:logout(?SeatNo),
   ok.
cross_board_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),
    %board1 callb
    board:callb(Board1,"8"),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sidea(Board1),
    SideB1=board:get_sideb(Board1),
   ?assertEqual(sideb,board:get_status(Board1)),
    %board2 calla
    Board2=opr:get_board(OprPid,2),
    board:focus(Board2),    
    board:calla(Board2,"8"),
    #{ua:=AUA2,mediaPid:=AMedia2}=board:get_sidea(Board2),
    ?assertEqual(ok, board:cross_board(Board2,Board1)),
    #{ua:=AUA2,mediaPid:=AMedia2}=board:get_sidea(Board1),
    SideB1=board:get_sideb(Board1),
   ?assertEqual(sidea,board:get_status(Board1)),
    ok.             
incoming_pickup_and_sidea_test()->
    oprgroup:stop(?GroupNo),
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    TestClientHost=self(), % for test
    {ok,OprPid}=opr_sup:login(?SeatNo,TestClientHost),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    GroupPid=oprgroup_sup:get_group_pid(?GroupNo),
    ?assert(is_pid(GroupPid) andalso is_process_alive(GroupPid)),
    [OprPid]=oprgroup:get_oprs(GroupPid),
    SDP0=sdp_sample(),

    % callopr with mockua
    MockUA=self(),
    R=rpc:call(node_conf:get_voice_node(),callopr,invite2opr,["test_op",?GroupPhone,SDP0,MockUA]),
    ?assert(is_pid(GroupPid) andalso is_process_alive(GroupPid)),
    [#{caller:="test_op",callee:=?GroupPhone,peersdp:=SDP0,mediaPid:=MediaPid,ua:=From}|T]=oprgroup:get_queues(GroupPid),
    io:format("grouppid:~p mediaPid:~p~n",[GroupPid,MediaPid]),
    {_,_}=sip_media:get_peer(MediaPid),
    ?assertMatch({ok,GroupPid},R),

    {broadcast,Jsonbin}=?REC_MatchMsg({broadcast,_Jsonbin}),
    #{"calls":=[{obj,CallPlist}],"msgType":=<<"broadcast">>}=utility1:jsonbin2map(Jsonbin),
    #{"phoneNumber":=GroupPhoneBin,"userId":=UserId,"callTime":=_}=maps:from_list(CallPlist),
    ?assertEqual(<<"test_op">>,GroupPhoneBin),
    ?assertEqual(UserId,list_to_binary(pid_to_list(MockUA))),

    % assert rbt
    ?assert(opr_rbt:has_media(MediaPid)),

    % simu opr pickup
%    ?assertMatch({ok,#{"phoneNumber":="test_op"}},board:pickup_call({?SeatNo,1})),
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"pickup_call","seatId"=>?SeatNo,"boardIndex"=>"1"}),

    ?assertMatch({failed,board_seized},board:pickup_call({?SeatNo,1})),
    ?assertMatch({failed,no_call},board:pickup_call({?SeatNo,2})),
    T=oprgroup:get_queues(GroupPid),
    ?assertEqual(MediaPid, board:get_a_media({?SeatNo,1})),
    ?assertEqual(From,board:get_a_ua({?SeatNo,1})),
    ?assertMatch(#{status:=tpring},board:get_sidea({?SeatNo,1})),

    % simu opr answer
    %board:sidea(Board1),
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"sidea","seatId"=>?SeatNo,"boardIndex"=>"1"}),

    ?assertMatch(#{status:=hook_off},board:get_sidea({?SeatNo,1})),
    {p2p_answer,Board1}=?REC_MatchMsg({p2p_answer,_}),
    ?assertEqual(Mixer,sip_media:get_media(OprMedia)),
    ?assertEqual(Mixer,sip_media:get_media(MediaPid)),
  
    ?assert(not opr_rbt:has_media(MediaPid)),


    {p2p_wcg_ack,GroupPid,_}=?REC_MatchMsg({p2p_wcg_ack, _, _}),
    ok.
incoming_ua_quit_test()->
    oprgroup:stop(?GroupNo),
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    TestClientHost=self(), % for test
    {ok,OprPid}=opr_sup:login(?SeatNo,TestClientHost),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    GroupPid=oprgroup_sup:get_group_pid(?GroupNo),
    ?assert(is_pid(GroupPid) andalso is_process_alive(GroupPid)),
    [OprPid]=oprgroup:get_oprs(GroupPid),
    SDP0=sdp_sample(),

    Shell=self(),
    F=fun(G)-> receive E-> Shell ! E, G(G) end end,
    MockUA=spawn(fun()-> F(F) end),
    R=rpc:call(node_conf:get_voice_node(),callopr,invite2opr,["test_op",?GroupPhone,SDP0,MockUA]),
    ?assert(is_pid(GroupPid) andalso is_process_alive(GroupPid)),
    [#{caller:="test_op",callee:=?GroupPhone,peersdp:=SDP0,mediaPid:=MediaPid,ua:=From}|T]=oprgroup:get_queues(GroupPid),
    ?assertMatch({ok,GroupPid},R),
    {p2p_wcg_ack,GroupPid,_}=?REC_MatchMsg({p2p_wcg_ack, _, _}),

    {broadcast,Jsonbin}=?REC_MatchMsg({broadcast,_Jsonbin}),
    #{"calls":=Calls,"msgType":=<<"broadcast">>}=utility1:jsonbin2map(Jsonbin),


    exit(MockUA,kill),
    utility1:delay(50),
    ?assert(not is_process_alive(MediaPid)),
    CallQueues=oprgroup:get_queues(GroupPid),
    ?assertEqual([],[Item||Item=#{ua:=UA}<-CallQueues,UA==MockUA]),
    ok.
add_oprgroup_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    [#oprgroup_t{key=?GroupNo}|_]=oprgroup:get_by_phone(?GroupPhone),
    [#oprgroup_t{key=_GroupNo,item=#{phone:=?GroupPhone}}]=oprgroup_sup:get_oprgroup(?GroupNo),
    GroupPid=oprgroup_sup:get_group_pid(?GroupNo),
    GroupPid=oprgroup:get_group_pid_by_phone(?GroupPhone),
    ?assert(is_pid(GroupPid) andalso is_process_alive(GroupPid)),
    ok.
get_board_status_test()->
    ab_sample(),
    ?assertMatch(#{boardstatus:=ab,                   
              detail:=#{a:=#{phone:="8",               
                     talkstatus:=_,
                     starttime:=_st},
                   b:=#{phone:="9",
                     talkstatus:=_,
                     starttime:=_st}
                }},board:get_all_status({?SeatNo,1})),
    ok.
get_opr_status_test()->
    ab_sample(),
    ?assertMatch(
      #{oprstatus:=logined,callstatus:=_,activedBoard:=1,boards:=[
      #{boardstatus:=ab,                   
              detail:=#{a:=#{phone:="8",               
                     talkstatus:=_,
                     starttime:=_st},
                   b:=#{phone:="9",
                     talkstatus:=_,
                     starttime:=_st}
                }}|_]},opr:get_all_status(?SeatNo)),
    ok.
oprstatus_to_jso_test()->
    ?assertMatch({obj,_},utility1:map2jso(opr:get_all_status(?SeatNo))),
    ok.


sdp_sample()->
    "v=0
o=yate 1514602552 1514602552 IN IP4 192.168.1.14
s=SIP Call
c=IN IP4 192.168.1.14
t=0 0
m=audio 30182 RTP/AVP 0 8 3 11 98 97 102 103 104 105 106 101
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:3 GSM/8000
a=rtpmap:11 L16/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:97 iLBC/8000
a=fmtp:97 mode=30
a=rtpmap:102 SPEEX/8000
a=rtpmap:103 SPEEX/16000
a=rtpmap:104 SPEEX/32000
a=rtpmap:105 iSAC/16000
a=rtpmap:106 iSAC/32000
a=rtpmap:101 telephone-event/8000
a=ptime:30".

fprof_()->
    fprof:apply(?MODULE, transfer_opr_test, []),
    fprof:profile(),
    fprof:analyse({dest, "bar.analysis"}),
    file:consult("bar.analysis").

opr_rbt_media_exit_test()->
    if_mixer_no_rec_audio_frame_and_timeout_120s__then_kickout_it,
    todo.
% for http interface for client
seatgroup_config_test()->
    oprgroup_sup:del_oprgroup(?GroupNo),
    []=oprgroup_sup:get_oprgroup(?GroupNo),
    undefined=oprgroup_sup:get_group_pid(?GroupNo),
    {ok,Res1=#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"seatgroup_config","groupPhone"=>"52300112","seatGroupNo"=>"912"}),
    [_]=oprgroup_sup:get_oprgroup(?GroupNo),
    GroupPid=oprgroup_sup:get_group_pid(?GroupNo),
    ?assert(is_pid(GroupPid)),
    ok.
seat_register_test_1()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    [_]=oprgroup_sup:get_oprgroup(?GroupNo),
    ?assert(is_pid(oprgroup_sup:get_group_pid(?GroupNo))),
    {ok,Res1=#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"seat_register","seatId"=>?SeatNo,"seatGroupNo"=>?GroupNo,"seatPhone"=>?SeatPhone,pwd=>?Pwd}),
    [_Opr=#seat_t{seat_no=SeatNo,item=#{user:=?SeatPhone,group_no:=?GroupNo}}]=opr_sup:get_by_seatno(?SeatNo),
    {atomic, [_]}=opr_sup:get_user(?SeatPhone),
    ok.
opr_login_test()->
    seat_register_test_1(),
    {ok,Res1=#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"opr_login","seatId"=>?SeatNo,"operatorId"=>?OPRID}),
    OprPid=opr_sup:get_oprpid_by_oprid(?OPRID),
    ?assert(is_pid(OprPid) andalso is_process_alive(OprPid)),
    ?assert(whereis(opr_sup)=/=undefined),
    ?assertEqual(OprPid,opr_sup:get_opr_pid(?SeatNo)),
    ?assertEqual({127,0,0,1},opr:get_client_host(OprPid)),
    UA=opr:get_ua(OprPid),
    UANode=node(UA),
    ?assert(is_pid(UA) andalso rpc:call(UANode,erlang,is_process_alive,[UA])),
    MediaPid=opr:get_mediaPid(OprPid),
    ?assert(is_pid(MediaPid) andalso rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
    %Boards=opr:get_boards(OprPid),
    ok.

opr_logout_test()->
    opr_login_test(),
    {ok,Res1=#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"opr_logout","seatId"=>?SeatNo,"operatorId"=>?OPRID}),
    utility1:delay(200),
    undefined=opr_sup:get_oprpid_by_oprid(?OPRID),
    ?assert(whereis(opr_sup)=/=undefined),
    ?assertEqual(undefined,opr_sup:get_opr_pid(?SeatNo)),
    %Boards=opr:get_boards(OprPid),
    ok.

pickup_call_test_notrun()->
    has_test_in_incoming_pickup_and_sidea_test, %simu opr pickup
    ok.

sidea_sideb_inserta_insertb_splita_splitb_third_monitor_ab_clean_board_releasea_releaseb_test_notrun()->
    has_test_before,
    ok.

board_switch_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    Board2=opr:get_board(OprPid,2),
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
% board_switch    
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"board_switch","curBoardIndex"=>1,"nextBoardIndex"=>"2","seatId"=>?SeatNo}),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assertEqual(1,maps:size(mixer:get_sides(Mixer))),
    ?assert(mixer:has_media(Mixer,BMedia)),
    ?assert(not mixer:has_media(Mixer,OprMedia)),

    % test sidea
    board:calla(Board2,"8"),    
    Mixer2=board:get_mixer(Board2),
    #{ua:=AUA2,mediaPid:=AMedia2}=board:get_sidea(Board2),
    ?assertEqual(sidea,board:get_status({"6",2})),
    ?assertEqual(Mixer2,sip_media:get_media(AMedia2)),
    ?assert(mixer:has_media(Mixer2,OprMedia)),
    ?assert(mixer:has_media(Mixer2,AMedia2)),    
    opr_sup:logout("6"),
    ok.
cross_board_api_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    board:release({?SeatNo,1}),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    Board2=opr:get_board(OprPid,2),
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
    % cross_board    
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"cross_board","curBoardIndex"=>"1","nextBoardIndex"=>"2","seatId"=>?SeatNo}),
    utility1:delay(20),
    ?assertEqual(null,board:get_status({"6",1})),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sideb(Board1),
    ?assert(not board:focused({"6",1})),
    ?assertEqual(0,maps:size(mixer:get_sides(Mixer))),

    ?assertEqual(sidea,board:get_status({"6",2})),
    ?assert(is_process_alive(BMedia)),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sidea({"6",2}),
    Mixer2=board:get_mixer({"6",2}),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer2))),
    ?assert(mixer:has_media(Mixer2,BMedia)),
    ?assert(mixer:has_media(Mixer2,OprMedia)),
    % % test sidea
    % board:calla(Board2,"8"),    
    % Mixer2=board:get_mixer(Board2),
    % #{ua:=AUA2,mediaPid:=AMedia2}=board:get_sidea(Board2),
    % ?assertEqual(sidea,board:get_status({"6",2})),
    % ?assertEqual(Mixer2,sip_media:get_media(AMedia2)),
    % ?assert(mixer:has_media(Mixer2,OprMedia)),
    % ?assert(mixer:has_media(Mixer2,AMedia2)),    
    % opr_sup:logout("6"),
    ok.
transfer_opr_test()->
    oprgroup_sup:add_oprgroup(?GroupNo,?GroupPhone),
    opr_sup:add_opr(?GroupNo,?SeatNo,?User,?Pwd),
    opr_sup:logout(?SeatNo),
    {ok,OprPid}=opr_sup:login(?SeatNo),
    OprMedia=opr:get_mediaPid(OprPid),
    Board1=opr:get_board(OprPid,1),
    Board2=opr:get_board(OprPid,2),
    board:focus(Board1),    
    Mixer=board:get_mixer(Board1),

    %callb
    board:callb(Board1,"9"),
    ?assertEqual(sideb,board:get_status({"6",1})),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sideb(Board1),
    ?assert(is_pid(BUA) andalso is_pid(BMedia)),
    ?assertEqual(Mixer,sip_media:get_media(BMedia)),
    ?assertEqual(undefined,sip_media:get_media(OprMedia)),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer))),
    ?assert(mixer:has_media(Mixer,BMedia)),
    ?assert(mixer:has_media(Mixer,OprMedia)),
    % transfer_opr    
    opr_sup:add_opr(?GroupNo,?SeatNo1,?User1,?Pwd1),
    opr_sup:logout(?SeatNo1),
    {ok,OprPid1}=opr_sup:login(?SeatNo1,self(),?OPRID1),
    OprMedia1=opr:get_mediaPid(OprPid1),
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"transfer_opr","boardIndex"=>"1","targetSeat"=>?SeatNo1,"seatId"=>?SeatNo}),
    utility1:delay(20),
    ?assertEqual(null,board:get_status({"6",1})),
    #{ua:=undefined,mediaPid:=undefined}=board:get_sideb(Board1),
    ?assert(not board:focused({"6",1})),
    ?assertEqual(0,maps:size(mixer:get_sides(Mixer))),

    UserId=(pid_to_list(BUA)),
    {push_transfer_to_opr,Jsonbin}=?REC_MatchMsg({push_transfer_to_opr,_Jsonbin}),
    #{"phone":=<<"9">>,"msgType":=<<"push_transfer_to_opr">>,"FromSeatId":=FromSeatId,"ToSeatId":=ToSeatId,"userId":=UserIdBin}=utility1:jsonbin2map(Jsonbin),
    ?assertEqual(?SeatNo,binary_to_list(FromSeatId)),
    ?assertEqual(?SeatNo1,binary_to_list(ToSeatId)),
    ?assertEqual(UserId,binary_to_list(UserIdBin)),
    ?assertMatch(#{UserId:=#{ua:=BUA,mediaPid:=BMedia}},opr:get_transfer_sides(?SeatNo1)),

    % client rec_transfer_opr
    {ok,#{"status":=<<"ok">>}}=
       utility1:json_http("http://127.0.0.1:8082/api",#{"msgType"=>"accept_transfer_opr","boardIndex"=>"2","userId"=>UserId,"seatId"=>?SeatNo1}),
     ?assertEqual(sidea,board:get_status({?SeatNo1,2})),
    ?assert(is_process_alive(BMedia)),
    #{ua:=BUA,mediaPid:=BMedia}=board:get_sidea({?SeatNo1,2}),
    Mixer1=board:get_mixer({?SeatNo1,2}),
    ?assertEqual(2,maps:size(mixer:get_sides(Mixer1))),
    ?assert(mixer:has_media(Mixer1,BMedia)),
    ?assert(mixer:has_media(Mixer1,OprMedia1)),
    ok.
