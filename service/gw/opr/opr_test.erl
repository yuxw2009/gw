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
    [#oprgroup_t{key=GroupNo,item=#{phone:=?GroupPhone}}]=opr_sup:get_oprgroup(?GroupNo),
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
    
    % exit(OprPid,kill),
    % utility1:delay(10),
    % ?assert(not rpc:call(UANode,erlang,is_process_alive,[UA])),
    % ?assert(not rpc:call(node(MediaPid),erlang,is_process_alive,[MediaPid])),
    % undefined=opr_sup:get_opr_pid(?SeatNo),

    %[]=opr_sup:get_oprs_by_group_no(?GroupNo),
    %siphelper:start_generate_request("REGISTER","a@1.1.1.1","b@2.2.2.2",[], []).
    ok.

opr_logout_test()->
    {ok,OprPid}=opr_sup:login(?SeatNo),
    opr_sup:logout(?SeatNo),
    utility1:delay(20),
    ?assert(not is_process_alive(OprPid)),
    ok.



