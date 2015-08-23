-module(fid).
-compile(export_all).
-include("db_op.hrl").
-include("lwdb.hrl").

-define(DIR,"/data/fid/").
-define(DEFAULT_QNODE,'qtest1@14.17.107.196').

%start_call(Node,Fid)->
start_call(Fid)->    
    Qnos=get_left_qnos(Fid),
    do_start_call(Fid,Qnos).
stop_call(Fid)->    
    rpc:call(get_node(Fid),qstart,stop,[Fid]),
    set_status(Fid,stop).
do_start_call(Fid,Qnos0)-> do_start_call(get_node(Fid),Fid,Qnos0).    
do_start_call(Node,Fid,Qnos0)-> 
    Cmd=if Node==?DEFAULT_QNODE-> add_www_qnos;true-> add_my_owncid_www_qnos end,
    Qnos=deduplicate(Qnos0),
    if length(Qnos) > 0->
        rpc:call(Node,qstart,Cmd,[{www,Fid,node(),Qnos}]),
        case get_status(Fid) of
        waiting_judge_restart-> set_status(Fid,reproceeding_failed);
        _->  set_status(Fid,queue)
        end;
    true-> void
    end.
start_only_failed(Fid)->
    Failed=get_only_failed(Fid),
    do_start_call(Fid,Failed).
deduplicate(L)-> lists:usort(L).    
%deduplicate(L)-> deduplicate(L,[]).
deduplicate([],Res)-> lists:reverse(Res);
deduplicate([H|Rest],Res)->
    case lists:member(H,Res) of
    true->  deduplicate(Rest,Res);
    _-> deduplicate(Rest,[H|Res])
    end.

filter_dup(L0)->
    L1=deduplicate(L0),
    L2= L0--L1,
    lists:usort(L0)--lists:usort(L2).
all_dup_itms(L0,0)-> L0;
all_dup_itms(L0,N) when is_integer(N) andalso N>0 ->
    Dups=L0--lists:usort(L0),
    all_dup_itms(Dups,N-1).
    
auto_restart(Fid)->
    case get_left_qnos(Fid) of
    Qnos0 when length(Qnos0)>0 -> 
        Qnos=deduplicate(Qnos0),
        if length(Qnos) > 0->
            rpc:call(get_node(Fid),qstart,add_www_qnos_2_head,[{www,Fid,node(),Qnos}]),
            set_status(Fid,reproceeding_failed);
        true-> void
        end;
    _-> set_status(Fid,finished)
    end.
    
restart_redial1(Fid)->
    case get_status(Fid) of
    finished->
        case filter_dup(get_redial1_qnos(Fid))--get_raw_qno(Fid,"_ok.txt") of
        Lefts when length(Lefts)>0 -> 
            do_start_call(Fid,Lefts),
            "ok, restart proceeding";
        _-> 
            set_status(Fid,finished),
            "no more needed to proceed"
        end;
    _->
        "still proceeding,please wait..."
    end.

dir()-> ?DIR.

do_once()->
    mnesia:stop(),
    mnesia:create_schema([node()]),
    create_table().
create_table()->
    mnesia:start(),
    mnesia:create_table(qfileinfo,[{attributes,record_info(fields,qfileinfo)},{disc_copies,[node()]}]),
    mnesia:create_table(qfiles,[{attributes,record_info(fields,qfiles)},{disc_copies,[node()]}]),
    mnesia:create_table(id_table, [{disc_copies, [node()]},{attributes, record_info(fields, id_table)}]),               
    ok.
    
start()->
    create_table().
    
id()->
    Fid=mnesia:dirty_update_counter(id_table, fid, 1),
    integer_to_list(Fid).

add_db(UUID,Fid,Fn)->
    ?DB_WRITE(#qfileinfo{fid=Fid,fn=#fn_info{fnname=Fn,uuid=UUID}}),
    case ?DB_READ(qfiles,UUID) of
    {atomic,[Qfiles=#qfiles{files=Files}]}->
        ?DB_WRITE(Qfiles#qfiles{files=[Fid|Files]});
    _->
        ?DB_WRITE(#qfiles{uuid=UUID,files=[Fid]})
    end,
    Fid.

set_status(Fid,finish)->
    set_status(Fid, waiting_judge_restart),
    timer:apply_after(50*1000,?MODULE,auto_restart, [Fid]);
set_status(Fid,Status)->
    case ?DB_READ(qfileinfo,Fid) of
    {atomic,[Qfileinfo]}->
        ?DB_WRITE(Qfileinfo#qfileinfo{status=Status});
    _->
        io:format("fid.erl fid ~p ~p~n",[Fid,Status])
    end.

get_status(Fid)->
    case ?DB_READ(qfileinfo,Fid) of
    {atomic,[#qfileinfo{status=Status}]}->
        Status;
    _->
       undefined
    end.

writefile(Fn,Qno)->
    log1(fullname(Fn),"~s",[Qno]).
    
log1(Filename, Str, CmdList) ->
    {ok, IODev} = file:open(Filename, [append]),
    io:format(IODev,Str++"\r\n", CmdList),
    file:close(IODev).

fullname(Fid)-> ?DIR++Fid.


read_file(Fn)->
    case file:read_file(fullname(Fn)) of
    {ok,Bin}-> Bin;
    _-> <<>>
    end.

get_left_qnos(Filename)->
    Totle=deduplicate(get_raw_qno(Filename)),
    Oks=get_raw_qno(Filename,"_ok.txt"),
    Kj=get_raw_qno(Filename,"_kajie.txt"),
    Gm=get_raw_qno(Filename,"_gaimi.txt"),
    DupRdial=dup_redial_itms(Filename,10),
    DupFail=dup_failed_itms(Filename,2),
    Redial1=get_raw_qno(Filename,"_redial1.txt"),
    Other=Oks++Kj++Gm++Redial1,
    lists:reverse(((Totle--Other)--DupRdial)--DupFail).
get_left_qnos_len(Filename)->
    Totle=deduplicate(get_raw_qno(Filename)),
    Oks=get_raw_qno(Filename,"_ok.txt"),
    Kj=get_raw_qno(Filename,"_kajie.txt"),
    Gm=get_raw_qno(Filename,"_gaimi.txt"),
    DupRdial=dup_redial_itms(Filename,10),
    DupFail=dup_failed_itms(Filename,2),
    length(Totle)-length(Oks)-length(Kj)-length(Gm)-length(DupRdial)-length(DupFail).
    
get_only_failed(Filename)->
    Failed=deduplicate(get_raw_qno(Filename,"_redial.txt")),
    Oks=get_raw_qno(Filename,"_ok.txt"),
    Kj=get_raw_qno(Filename,"_kajie.txt"),
    Gm=get_raw_qno(Filename,"_gaimi.txt"),
    Redial1=get_raw_qno(Filename,"_redial1.txt"),
    Failed--(Oks++Kj++Gm++Redial1).

dup_redial_itms(Fid,N)->
    Redial=get_raw_qno(Fid,"_redial.txt"),
    all_dup_itms(Redial,N).
    
dup_failed_itms(Fid,N)->
    Redial=get_raw_qno(Fid,"_fail.txt"),
    all_dup_itms(Redial,N).
    
get_raw_qno(Fid,Ext) when is_integer(Fid)-> get_raw_qno(integer_to_list(Fid),Ext);
get_raw_qno(Fid,Ext)->get_raw_qno(Fid++Ext).

get_raw_qno(Fid) when is_integer(Fid)-> get_raw_qno(integer_to_list(Fid));
get_raw_qno(Fid)->
    case file:read_file(fullname(Fid)) of
    {ok,Bin}->
        Lines=string:tokens(binary_to_list(Bin),"\r\n"),
        F=fun(Line)->
          [Qno|_]=string:tokens(Line," -"),
          filter_num(Qno)
        end,
        [Item||Item<-[F(Line)||Line<-Lines], length(Item)>0];
    _-> []
    end.

filter_num(Phone)->  [I||I<-Phone, lists:member(I, "0123456789")].

get_ok_qnos(Fid)-> get_raw_qno(Fid,"_ok.txt").
get_kajie_qnos(Fid)-> get_raw_qno(Fid,"_kajie.txt").
get_gaimi_qnos(Fid)-> get_raw_qno(Fid,"_gaimi.txt").
get_redial1_qnos(Fid)-> get_raw_qno(Fid,"_redial1.txt").
get_perhaps_success(Fid)->
%    filter_dup(get_redial1_qnos(Fid))--get_raw_qno(Fid,"_ok.txt").
    Failed=dup_failed_itms(Fid,2),
    Failed.

totals(Fid)->length(get_raw_qno(Fid)).    
oks(Fid)-> length(get_ok_qnos(Fid)).
kajies(Fid)-> length(get_kajie_qnos(Fid)).
gaimis(Fid)-> length(get_gaimi_qnos(Fid)).

fileinfo(Fid) when is_integer(Fid)-> fileinfo(integer_to_list(Fid));
fileinfo(Fid)->    ?DB_READ(qfileinfo,Fid).

filename(Fid)->
    case fileinfo(Fid) of
    {atomic,[#qfileinfo{fn=#fn_info{fnname=Fn}}]}-> Fn;
    {atomic,[#qfileinfo{fn=Fn}]}-> Fn;
    _-> <<"">>
    end.
get_node_by_EmpId("gw1")-> 'gw1@119.29.62.190';
get_node_by_EmpId("ddd")-> 'gw@119.29.62.190';
get_node_by_EmpId(_)-> ?DEFAULT_QNODE.
get_node(Fid)->
    case fileinfo(Fid) of
    {atomic,[#qfileinfo{fn=#fn_info{uuid=UUID}}]}->
        [{_,EmployeeId,_,_}]=auth_handler:lookup_names([UUID]),
        get_node_by_EmpId(EmployeeId);
    _-> ?DEFAULT_QNODE
    end.
check(UUID,Fid)->
    case ?DB_READ(qfiles,UUID) of
    {atomic,[#qfiles{files=Files}]}->
        lists:member(Fid,Files);
    _-> false
    end.

delete(UUID,Fid)->
    ?DB_DELETE({qfileinfo,Fid}),
    case ?DB_READ(qfiles,UUID) of
    {atomic,[Qfiles=#qfiles{files=Files}]}->
        ?DB_WRITE(Qfiles#qfiles{files=Files--[Fid]});
    _->
        void
    end.
