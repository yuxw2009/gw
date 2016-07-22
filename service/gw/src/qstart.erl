-module(qstart).
-compile(export_all).
-define(RESERVE_DAYS,5).
-record(st,{interval_ref,qnos=[],lastday=date(),status=active,interval_base=10000,interval=200,pls=[{cids,[]}]}).

add_my_owncid_www_qnos(Qnos={www,_Fid,_Node,_Qnos})->
    ensure_alive(),
    ?MODULE ! {add_myown_cid, [{first,Qnos}]}.
    
add_www_qnos(Qnos={www,_Fid,_Node,_Qnos})->
    ensure_alive(),
    ?MODULE ! {add, [{first,Qnos}]}.
    
add_www_qnos_2_head(Qnos={www,_Fid,_Node,_Qnos})->
    ensure_alive(),
    ?MODULE ! {add_head, {first,Qnos}}.
    
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
    [{wwwnode,Wwwnode}|make_info(Cid,Qno,Filename,Clidata)];
make_info(Qno) when is_list(Qno)->make_info(Qno,"test").
make_info(Qno,Filename)->
    make_info(opdn_rand(),Qno,Filename).
make_info(Cid,QQNo,Filename) ->  make_info(Cid,QQNo,Filename,"").
make_info(Cid,QQNo,Filename,Clidata) -> make_info(Cid,"75583765566",QQNo,Filename,Clidata).
make_info(Cid,PhNo,QQNo,Filename,Clidata) ->
    [{phone,PhNo},{qcall,true},
     {uuid,{qvoice,86}},
     {audit_info,[{uuid,Cid}]},{userclass, "fzd"},
     {cid,Cid},{qno,QQNo},{qfile,Filename},{clidata,Clidata}].
opdn_rand()->  integer_to_list(phone_prefxs()+random:uniform(999999999)).
phone_prefxs()->lists:nth(random:uniform(2),[18000000000,13000000000]).
    
can_call(St=#st{qnos=[{first,Qnos={www,Fid,Wwwnode,_}}|RestQnos]})->
    rpc:call(Wwwnode,fid,set_status,[Fid,proceeding]),
    can_call(St#st{qnos=[Qnos|RestQnos]});
    
can_call(St=#st{qnos=[{www,Fid,Wwwnode,[]}|RestQnos]})->
    rpc:call(Wwwnode,fid,set_status,[Fid,finish]),
    can_call(St#st{qnos=RestQnos});

can_call(St=#st{qnos=Qnos=[{www,Fid,Wwwnode,[Qno|Others]}|RestQnos],status=active,pls=[{cids,myown}|_]})->
    CallInfo=make_info({Wwwnode,opdn_rand(),Qno,Fid,""}),
    {true,CallInfo,St#st{qnos=[{www,Fid,Wwwnode,Others}| RestQnos]}};

can_call(St=#st{qnos=Qnos=[{www,Fid,Wwwnode,[Qno|Others]}|RestQnos],status=active,pls=[{cids,[{Cid,Clidata}|RestCids]}|RestPls]})->
    CallInfo=make_info({Wwwnode,Cid,Qno,Fid,Clidata}),
    {true,CallInfo,St#st{qnos=[{www,Fid,Wwwnode,Others}| RestQnos],pls=[{cids,RestCids}|RestPls]}};

%not used following
can_call(St=#st{qnos=Qnos=[{Qno,Filename}|RestQnos],status=active,pls=[{cids,[{Cid,Clidata}|RestCids]}|RestPls]})->
    CallInfo=make_info(Cid,Qno,Filename,Clidata),
    {true,CallInfo,St#st{qnos=RestQnos,pls=[{cids,RestCids}|RestPls]}};
%can_call(St=#st{qnos=Qnos=[{Qno,Filename}|RestQnos],status=active,pls=[{cids,[]}|RestPls]})->
%    CallInfo=make_info(opdn_rand(),Qno,Filename),
%    {true,CallInfo,St#st{qnos=RestQnos}};
can_call(St)-> 
    {false,undefined,St}.

loop0(St=#st{interval=Interval})->
    erlang:group_leader(whereis(user), self()),
    timer:send_after(Interval,interval_call),
    io:format("1"),
    loop(St).
loop(St=#st{qnos=Qnos,lastday=Lastday,status=Status,interval_base=BaseInterval,interval_ref=Tref})->
    random:seed(os:timestamp()),
    YjNode='gw_yj@119.29.62.190', SbNode='gw@119.29.62.190', Me2Sb=1.5,  SelfNode=node(), 
    CountFun=fun()->
        Sb= case rpc:call(SbNode,app_manager,get_app_count,[]) of
                {value, Sb0}-> Sb0;
                _-> 0
            end,
        SbMax=rpc:call(SbNode,avscfg,get,[max_calls]),
        Yj= case rpc:call(YjNode,app_manager,get_app_count,[]) of
                {value, Yj0}-> Yj0;
                _-> 0
            end,
        YjMax=rpc:call(YjNode,avscfg,get,[max_calls]),
        {Sb,SbMax,Yj,YjMax}
    end,
    
    JudgeFun=fun() when SelfNode==YjNode -> 
                           {Sb,SbMax,Yj,YjMax}=CountFun(),
                           Sb>0 andalso Sb*Me2Sb>=Yj andalso Yj<YjMax;
                      () when SelfNode==SbNode ->
                           {Sb,SbMax,Yj,YjMax}=CountFun(),
                           Sb<SbMax andalso (Yj==0 orelse Sb*Me2Sb<Yj);
                      ()-> 
                          {value, CallNum}=app_manager:get_app_count(),
                          CallNum<avscfg:get(max_calls)
            end,
    receive
    	interval_call->
%            io:format("i"),
            my_timer:cancel(Tref),
            Rate=q_strategy:success_rate(),
            Interval=if is_float(Rate) andalso Rate>0.0-> BaseInterval+erlang:round(200/Rate); true-> 3600000 end,
            Today=date(),
            if Lastday =/=Today->   os:cmd("rm -rf "++n_days_ago_dir(?RESERVE_DAYS)); true-> void end,
            %Interval=Interval0,%+random:uniform(5)*1000,
    	    {ok,NTref}=my_timer:send_after(Interval,interval_call),
            case {JudgeFun(), can_call(St#st{lastday=Today})} of
                {true,{true,CallInfo,NewSt}}->
                    q_w2p:start_qcall(CallInfo),
                    loop(NewSt#st{interval=Interval,interval_ref=Tref});
                {_,{_,_,NSt}}->
                    loop(NSt#st{interval=Interval,interval_ref=Tref})
            end;
    	{add, NewQnos}-> loop(St#st{qnos=add_to_queue(Qnos,NewQnos)});
    	{add_myown_cid, NewQnos}-> loop(St#st{qnos=add_to_queue(Qnos,NewQnos),pls=[{cids,myown}]});
    	{add_head, NewQnosItem}-> loop(St#st{qnos=[NewQnosItem|Qnos]});
    	{pause}-> loop(St#st{status=deactive});
    	{restore}-> loop(St#st{status=active});
    	{set_interval, NewInterv}->loop(St#st{interval_base=NewInterv});
    	{show, From}->
%    	     io:format("****~p~n",[{St,From}]),
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

add_to_queue(Qnos0,NewQnos)->add_to_queue(Qnos0,NewQnos,Qnos0).
add_to_queue(Qnos0,NewQnos,[])->    Qnos0++NewQnos;
add_to_queue(Qnos0,NewQnos=[{first,{_,Fid,_,_}}],[{first,{_,Fid,_,_}}|Tail])->Qnos0;
add_to_queue(Qnos0,NewQnos=[{first,{_,Fid,_,_}}],[{_,Fid,_,_}|Tail])->Qnos0;
add_to_queue(Qnos0,NewQnos=[{first,{_,Fid,_,_}}],[_|Tail])->add_to_queue(Qnos0,NewQnos,Tail).
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
    	    	Ack-> 
    	    	  %  io:format("###~p~n",[Ack]),
    	    	    Ack
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
%    io:format("~p~n",[Cid]),
    Act = fun(St=#st{qnos=[]})->
                 {ok,St#st{pls=[{cids,[Cid]}]}};
             (St=#st{pls=[{cids,Cids}]})->
                 {ok,St#st{pls=[{cids,[Cid|Cids]}]}}
          end,
    do_act(Act);
add_cid(_) ->
    io:format("add_cid:error cid~n").    
ahead(Fid) ->
    Act = fun(St=#st{qnos=Qnos})->
             NQnos=do_ahead(Fid,Qnos),
             {"ok",St#st{qnos=NQnos}}
          end,
    do_act(Act).
do_ahead(Fid,Qnos)-> do_ahead(Fid,Qnos,[]).
do_ahead(Fid,[Item={www,Fid,_,_}|Tails],Res)-> [Item|lists:reverse(Res)]++Tails;
do_ahead(Fid,[Item={first,{www,Fid,_,_}}|Tails],Res)-> [Item|lists:reverse(Res)]++Tails;
do_ahead(Fid,[Item|Tails],Res)-> do_ahead(Fid,Tails,[Item|Res]).

get_qnos_num(Fid) ->
    Act = fun(St=#st{qnos=Qnos})->
             {qno_num(Fid,Qnos),St}
          end,
    do_act(Act).
qno_num(_,[])-> 0;    
qno_num(Fid,_Qnos=[{www,Fid,_Wwwnode,MyQnos}|_])->     length(MyQnos);
qno_num(Fid,_Qnos=[_|Rest])->     qno_num(Fid,Rest).
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

call_firstqq(Qno)-> call(Qno,undefined).
call(Qno)-> call(Qno,"test").
call(Qno,Qfile)->
    q_wkr:processVOIP(undefined,make_info(Qno,Qfile)).

call_n(QQ,0)->  void;
call_n(QQ,N)->  
    call(QQ),
    timer:sleep(20000),
    call_n(QQ,N-1).

n_days_ago_dir(N)->
    Nago=calendar:gregorian_days_to_date(calendar:date_to_gregorian_days(date())-N),
    vcr:vcr_path()++rrp:mkday_dir(Nago).
