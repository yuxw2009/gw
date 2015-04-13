-module(qstart).
-compile(export_all).
-record(st,{qnos=[],status=active,interval=100,pls=[{cids,[]}]}).

add_www_qnos(Qnos={www,_Fid,_Node,_Qnos})->
    ensure_alive(),
    ?MODULE ! {add, [{first,Qnos}]}.
    
add(Filename)->add_left(Filename).

add_left(Filename)->
    ensure_alive(),
    ?MODULE ! {add, get_left_pair(Filename)}.

ensure_alive()->
    case whereis(?MODULE) of
        undefined->
            register(?MODULE, spawn(fun()-> loop0(#st{}) end));
        _-> void
    end.

get_raw_qno(Filename)->
    case file:read_file(Filename) of
    {ok,Bin}->
        Lines=string:tokens(binary_to_list(Bin),"\r\n"),
        F=fun(Line)->
          [Qno|_]=string:tokens(Line," "),
          Qno
        end,
        [F(Line)||Line<-Lines];
    _-> []
    end.

get_qno_FilePair(Filename)->
    Qnos=get_raw_qno(Filename),
    [{Qno,Filename}||Qno<-Qnos].

get_left_qnos(Filename)->
    Totle=qstart:get_raw_qno(Filename),
    Oks=qstart:get_raw_qno(Filename++"_ok.txt"),
    Kj=qstart:get_raw_qno(Filename++"_kajie.txt"),
    Gm=qstart:get_raw_qno(Filename++"_gaimi.txt"),
    Redial=qstart:get_raw_qno(Filename++"_redial.txt"),
    Redial1=qstart:get_raw_qno(Filename++"_redial1.txt"),
    Fail=qstart:get_raw_qno(Filename++"_fail.txt"),
    Other=Oks++Kj++Gm++Redial++Fail++Redial1,
    Totle--Other.
    
get_left_pair(Filename)->
    Qnos=get_left_qnos(Filename),
    [{Qno,Filename}||Qno<-Qnos].

make_info({Wwwnode,Cid,Qno,Filename,Clidata})->
    [{wwwnode,Wwwnode}|make_info(Cid,Qno,Filename,Clidata)].
make_info(Qno,Filename)->
    make_info(opdn_rand(),Qno,Filename).
make_info(Cid,QQNo,Filename) ->  make_info(Cid,QQNo,Filename,"").
make_info(Cid,QQNo,Filename,Clidata) -> make_info(Cid,"075583765566",QQNo,Filename,Clidata).
make_info(Cid,PhNo,QQNo,Filename,Clidata) ->
    [{phone,PhNo},{qcall,true},
     {uuid,{qvoice,86}},
     {audit_info,[{uuid,Cid}]},{userclass, "fzd"},
     {cid,Cid},{qno,QQNo},{qfile,Filename},{clidata,Clidata}].
opdn_rand()->  integer_to_list(18000000000+random:uniform(999999999)).

interval()->
    q_w2p:delay(1000).
    
can_call(St=#st{qnos=[{first,Qnos={www,Fid,Wwwnode,_}}|RestQnos]})->
    rpc:call(Wwwnode,fid,set_status,[Fid,proceeding]),
    can_call(St#st{qnos=[Qnos|RestQnos]});
    
can_call(St=#st{qnos=[{www,Fid,Wwwnode,[]}|RestQnos]})->
    io:format("fa"),
    rpc:call(Wwwnode,fid,set_status,[Fid,finish]),
    can_call(St#st{qnos=RestQnos});
can_call(St=#st{qnos=Qnos=[{www,Fid,Wwwnode,[Qno|Others]}|RestQnos],status=active,pls=[{cids,[{Cid,Clidata}|RestCids]}|RestPls]})->
    CallInfo=make_info({Wwwnode,Cid,Qno,Fid,Clidata}),
    {true,CallInfo,St#st{qnos=[{www,Fid,Wwwnode,Others}| RestQnos],pls=[{cids,RestCids}|RestPls]}};
can_call(St=#st{qnos=Qnos=[{Qno,Filename}|RestQnos],status=active,pls=[{cids,[{Cid,Clidata}|RestCids]}|RestPls]})->
    CallInfo=make_info(Cid,Qno,Filename,Clidata),
    {true,CallInfo,St#st{qnos=RestQnos,pls=[{cids,RestCids}|RestPls]}};
%can_call(St=#st{qnos=Qnos=[{Qno,Filename}|RestQnos],status=active,pls=[{cids,[]}|RestPls]})->
%    CallInfo=make_info(opdn_rand(),Qno,Filename),
%    {true,CallInfo,St#st{qnos=RestQnos}};
can_call(St)-> 
    {false,undefined,St}.

loop0(St=#st{interval=Interval})->
    timer:send_after(Interval,interval_call),
    io:format("1"),
    loop(St).
loop(St=#st{qnos=Qnos,status=Status,interval=Interval})->
    receive
    	interval_call->
    	    timer:send_after(Interval,interval_call),
    	    {value, CallNum}=app_manager:get_app_count(),
            case {CallNum<avscfg:get(max_calls), can_call(St)} of
                {true,{true,CallInfo,NewSt}}->
                    q_w2p:start_qcall(CallInfo),
                    loop(NewSt);
                {_,{_,_,NSt}}->
                    loop(NSt)
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

add_cid()->add_cid({opdn_rand(),""}).

add_cid(Cid) when is_list(Cid) orelse is_tuple(Cid)->
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
get_cids() ->
    Act = fun(St=#st{pls=Pls})->
             Cids=proplists:get_value(cids,Pls),
             {Cids,St}
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

restart()->
    case whereis(?MODULE) of
    undefined->void;
    P-> exit(P,kill)
    end,
    ensure_alive().

stop(Fid)->    
    Act = fun(St=#st{qnos=Qnos})->
                Item0=[Item||Item={first,{www,Fid1,_,_}}<-Qnos,Fid1==Fid],
                Item1=[Item||Item={www,Fid1,_,_}<-Qnos,Fid1==Fid],
                Deled=(Item0++Item1),
             {Deled,St#st{qnos=Qnos--Deled}}
          end,
    do_act(Act).

