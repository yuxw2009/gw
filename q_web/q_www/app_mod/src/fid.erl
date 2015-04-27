-module(fid).
-compile(export_all).
-include("db_op.hrl").
-include("lwdb.hrl").

-define(DIR,"/data/fid/").
-define(QNODE,'qtest1@14.17.107.196').

start_call(Fid)->    
    Qnos=get_left_qnos(Fid),
    do_start_call(Fid,Qnos).
do_start_call(Fid,Qnos0)-> 
    Qnos=deduplicate(Qnos0),
    if length(Qnos) > 0->
        rpc:call(?QNODE,qstart,add_www_qnos,[{www,Fid,node(),Qnos}]),
        set_status(Fid,queue);
    true-> void
    end.
    
deduplicate(L)-> deduplicate(L,[]).
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
all_dup_itms(L0)->
    Dups=L0--lists:usort(L0),
    lists:usort(Dups).
    
auto_restart(Fid)->
    case get_left_qnos(Fid) of
    Lefts when length(Lefts)>0 -> start_call(Fid);
    _-> set_status(Fid,finished)
    end.
    
restart_redial1(Fid)->
    case get_status(Fid) of
    finished->
        case filter_dup(get_redial1_qnos(Fid))--get_raw_qno(Fid++"_ok.txt") of
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
    ?DB_WRITE(#qfileinfo{fid=Fid,fn=Fn}),
    case ?DB_READ(qfiles,UUID) of
    {atomic,[Qfiles=#qfiles{files=Files}]}->
        ?DB_WRITE(Qfiles#qfiles{files=[Fid|Files]});
    _->
        ?DB_WRITE(#qfiles{uuid=UUID,files=[Fid]})
    end,
    Fid.

set_status(Fid,finish)->
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
    Oks=get_raw_qno(Filename++"_ok.txt"),
    Kj=get_raw_qno(Filename++"_kajie.txt"),
    Gm=get_raw_qno(Filename++"_gaimi.txt"),
    DupRdial=dup_redial_itms(Filename),
    Redial1=get_raw_qno(Filename++"_redial1.txt"),
%    Fail=get_raw_qno(Filename++"_fail.txt"),
    Other=Oks++Kj++Gm++Redial1,
    (Totle--Other)--DupRdial.

dup_redial_itms(Fid)->
    Redial=get_raw_qno(Fid++"_redial.txt"),
    all_dup_itms(Redial).
    
get_raw_qno(Fid,Ext) when is_integer(Fid)-> get_raw_qno(integer_to_list(Fid),Ext);
get_raw_qno(Fid,Ext)->get_raw_qno(Fid++Ext).

get_raw_qno(Fid) when is_integer(Fid)-> get_raw_qno(integer_to_list(Fid));
get_raw_qno(Fid)->
    case file:read_file(fullname(Fid)) of
    {ok,Bin}->
        Lines=string:tokens(binary_to_list(Bin),"\r\n"),
        F=fun(Line)->
          [Qno|_]=string:tokens(Line," "),
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

totals(Fid)->length(get_raw_qno(Fid)).    
oks(Fid)-> length(get_ok_qnos(Fid)).
kajies(Fid)-> length(get_kajie_qnos(Fid)).
gaimis(Fid)-> length(get_gaimi_qnos(Fid)).

fileinfo(Fid) when is_integer(Fid)-> fileinfo(integer_to_list(Fid));
fileinfo(Fid)->    ?DB_READ(qfileinfo,Fid).

filename(Fid)->
    case fileinfo(Fid) of
    {atomic,[#qfileinfo{fn=Fn}]}-> Fn;
    _-> ""
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
