-module(qstart).
-compile(export_all).
-record(st,{qnos=[],status=active,interval=1000,pls=[{cids,[]}]}).

add(Filename)->
    case whereis(?MODULE) of
    	undefined->
    	    register(?MODULE, spawn(fun()-> loop0(#st{}) end));
    	_-> void
    end,
    ?MODULE ! {add, get_qno_FilePair(Filename)}.

add_left(Filename)->
    case whereis(?MODULE) of
        undefined->
            register(?MODULE, spawn(fun()-> loop0(#st{}) end));
        _-> void
    end,
    ?MODULE ! {add, get_left_pair(Filename)}.

get_raw_qno(Filename)->
    {ok,Bin} =  file:read_file(Filename),
    string:tokens(binary_to_list(Bin),"\r\n").

get_qno_FilePair(Filename)->
    Qnos=get_raw_qno(Filename),
    [{Qno,Filename}||Qno<-Qnos].

get_left_qnos(Filename)->
    Totle=qstart:get_raw_qno(Filename),
    Oks=qstart:get_raw_qno(Filename++"_ok1.txt"),
    Bkj=qstart:get_raw_qno(Filename++"_bkj.txt"),
    (Totle--Oks)--Bkj.
get_left_pair(Filename)->
    Qnos=get_left_qnos(Filename),
    [{Qno,Filename}||Qno<-Qnos].


make_info(Qno,Filename)->
    make_info(opdn_rand(),Qno,Filename).
make_info(Cid,QQNo,Filename) ->  make_info(Cid,"075583765566",QQNo,Filename).
make_info(Cid,PhNo,QQNo,Filename) ->
    [{phone,PhNo},{qcall,true},
     {uuid,{qvoice,86}},
     {audit_info,[{uuid,Cid}]},{userclass, "fzd"},
     {cid,Cid},{qno,QQNo},{qfile,Filename}].
opdn_rand()->  integer_to_list(18000000000+random:uniform(999999999)).

interval()->
    q_w2p:delay(1000).
    
can_call(St=#st{qnos=Qnos=[{Qno,Filename}|RestQnos],status=active,pls=[{cids,[Cid|RestCids]}|RestPls]})->
    CallInfo=make_info(Cid,Qno,Filename),
    {true,CallInfo,St#st{qnos=RestQnos,pls=[{cids,RestCids}|RestPls]}};
can_call(St)-> {false,undefined,St}.

loop0(St=#st{interval=Interval})->
    timer:send_after(Interval,interval_call),
    loop(St).
loop(St=#st{qnos=Qnos,status=Status,interval=Interval})->
    receive
    	interval_call->
    	    timer:send_after(Interval,interval_call),
            case can_call(St) of
                {true,CallInfo,NewSt}->
                    q_w2p:start_qcall(CallInfo),
                    loop(NewSt);
                {false,_,NewSt}->
                    loop(NewSt)
            end;
    	{add, NewQnos}-> loop(St#st{qnos=Qnos++NewQnos});
    	{pause}-> loop(St#st{status=deactive});
    	{restore}-> loop(St#st{status=active});
    	{set_interval, NewInterv}->loop(St#st{interval=NewInterv});
    	{show, From}->
            From ! St,
    	    loop(St);
        {do_act,Act,From}->
            {Res,NewSt} = Act(St),
            From ! Res,
            loop(NewSt);
    	Other->
    	    io:format("qstart unexpectd msg:~p~n",[Other]),
    	    loop(St)
    	end.

pause()->
    case whereis(?MODULE) of
    	P when is_pid(P)->   P ! {pause};
    	_-> void
    end.
restore()->
    case whereis(?MODULE) of
    	P when is_pid(P)->   P ! {restore};
    	_-> void
    end.
set_interval(Int_ms)->
    case whereis(?MODULE) of
    	P when is_pid(P)->   P ! {set_interval,Int_ms};
    	_-> void
    end.

show()->
    case whereis(?MODULE) of
    	P when is_pid(P)->   
    	    P ! {show,self()},
    	    receive
    	    	Ack-> Ack
    	    after 2000->
    	    	timeout
    	    end;
    	_-> void
    end.

do_act(Act)->
    case whereis(?MODULE) of
        P when is_pid(P)->   
            P ! {do_act,Act,self()},
            receive
                Ack-> Ack
            after 2000->
                timeout
            end;
        _-> void
    end.

add_ncid(0)-> finish;
add_ncid(N)->
    add_cid(),
    add_ncid(N-1).

add_cid()->add_cid(opdn_rand()).

add_cid(Cid) when is_list(Cid)->
    io:format("~p~n",[Cid]),
    Act = fun(St=#st{qnos=[]})->
                 {ok,St#st{pls=[{cids,[]}]}};
             (St=#st{pls=[{cids,Cids}]})->
                 {ok,St#st{pls=[{cids,[Cid|Cids]}]}}
          end,
    do_act(Act);
add_cid(_) ->
    io:format("add_cid:error cid~n").    
get_qnos() ->
    Act = fun(St=#st{qnos=Qnos})->
             {Qnos,St}
          end,
    do_act(Act).

collect(Filename)->
    {_,Fd}=file:open(Filename++"_totalres.txt",[append]),
    {_,Oks}=file:read_file(Filename++"_ok.txt"),
    {_,Kajies}=file:read_file(Filename++"_kaijie.txt"),
    {_,Gms}=file:read_file(Filename++"_gm.txt"),
    file:write(Fd,"å·²è\n"),
    file:write(Fd,Oks),
    file:write(Fd,"kajie\n"),
    file:write(Fd,Kajies),
    file:write(Fd,"gaimi\n"),
    file:write(Fd,Gms),
    file:close(Fd).

get_status()->
    Act = fun(St=#st{status=Status})->
             {Status,St}
          end,
    do_act(Act).