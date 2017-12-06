-module(config_intf).
-compile(export_all).
-include_lib("eunit/include/eunit.hrl").
-include("virtual.hrl").
-include("call.hrl").
-include("db_op.hrl").
-record(test_t,{key,val}).

setup()->
    io:format("setup!!!!!!!!!!!!~n"),
    mnesia:create_table(traffic_t,[{attributes,record_info(fields,traffic_t)},{disc_only_copies ,[node()]}]),
    mnesia:delete_table(test_t),
    mnesia:create_table(test_t,[{attributes,record_info(fields,test_t)},{ram_copies,[node()]}]).

start()-> start(<<"oam_config">>, fun oam_config_handler/2).
start(QueueName,Callback)->
    RegName=( list_to_atom(binary_to_list(<<QueueName/binary,"_amqp">>))),
    case whereis(RegName) of
    undefined->
        NewCb=fun(I,SendFunc)-> erlang:group_leader(whereis(user), self()), Callback(I,SendFunc) end,
        Pid=amqp_rcv:spawn_rcv(NewCb,QueueName),
        register(RegName,Pid);
    Pid-> Pid !{callback,Callback}
    end.

mnesia_all_items(T)->?DB_QUERY(T).
mnesia2plist(company)->
    ?MNESIA2PLIST(company_t).
send_oam_config(QueueName,CorrelationId,ReplyTo,Payload)->
    amqp_send:send(QueueName,Payload,CorrelationId,ReplyTo).
get_a_x(A)->
    mnesia:dirty_read(a_x_t,utility:value2binary(A)).
get_a_x_by_x(X)->
     sip_virtual:get_a_x_by_x(X).
unbind_by_a(A,Trans,Mode)-> 
    case get_a_x(A) of
    [#a_x_t{x=X}|_]->    sip_virtual:unbind_b(X,Trans,Mode);
    _-> void
    end.
add_x(ComId,Xs)->
    case config_intf:get_company(ComId) of
        []-> {false,utility:pl2jsos_br(x_plists()),"companyid "++binary_to_list(ComId)++" not existed"};
        [Xt=#company_t{available_xs=AX,used_xs=_UX}]->
            Xs1=[X||X<-Xs,mnesia:dirty_index_read(a_x_t,X,#a_x_t.x)==[]],
            ?DB_WRITE(Xt#company_t{available_xs=lists:umerge(AX,Xs1)}),
            {true,utility:pl2jsos_br(x_plists()),""}
    end.
plist2json(Pl)->
    rfc4627:encode(utility:pl2jso_br(Pl)).
oam_config_payload(Method,Module,Data)->
    list_to_binary(plist2json([{method,Method},{module,Module},{data,Data}])).

oam_config_handler(PayloadJsonBin)->    oam_config_handler(PayloadJsonBin,undefined).
oam_config_handler(PayloadJsonBin, SendFunc)->    
    io:format("oam_config_handler ~p~n",[PayloadJsonBin]),
%    io:format("8888888888888888888888888888888888888888~n"),
    {Method,Module,DataJson,BrowserAdmin,ClientIp}=utility:decode(PayloadJsonBin,[{method,a},{module,a},{data,r},{browser_admin,a},{clientIp,b}]),
    {Page,PageSize}=utility:decode_json(DataJson,[{page,i},{pageSize,i}]),
%    io:format("oam_config_handler res ~p~n",[{Method,Module,DataJson}]),
    if
        SendFunc==undefined->
            Res2=deal_oam_config_event([Method,Module,DataJson,Page,PageSize,ClientIp], SendFunc,BrowserAdmin),
            {need_ack,rfc4627:encode( utility:pl2jso_br(Res2))};
        true->
            F=fun()->
                Res2=deal_oam_config_event([Method,Module,DataJson,Page,PageSize,ClientIp], SendFunc,BrowserAdmin),
                SendFunc(rfc4627:encode( utility:pl2jso_br(Res2)))
            end,
            spawn(F)
        end.
deal_oam_config_event([Method,Module,DataJson,Page,PageSize,_ClientIp], SendFunc,true)->
    {IsSuccess,AckDataJO,Reason}=
    case {Method,Module} of
    {post,company}->
        {Id,Name,Passwd,Cdr_mode,Cdr_pushurl,NeedVoip,NeedPlaytone,NeedCompanyname}=utility:decode_json(DataJson,[{id,b},{name,b},{passwd,b},
              {cdr_mode,a},{cdr_pushurl,b},{needVoip,a},{needPlaytone,a},{needCompanyname,a}]),
        add_company(#company_t{id=Id,name=Name,passwd=Passwd,cdr_mode=Cdr_mode,cdr_pushurl=Cdr_pushurl,needVoip=NeedVoip,
                                              needPlaytone=NeedPlaytone,needCompanyname=NeedCompanyname});
    {get,company}->
        {true,utility:pl2jsos_br(all_company_plist()),""};
    {delete,company}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        delete_company(Id),
        {true,utility:pl2jsos_br(all_company_plist()),""};
    {post,x}->
        {ComId,NumStr}=utility:decode_json(DataJson,[{companyid,b},{num_str,b}]),
        Xs=config_intf:get_xs(NumStr),
        add_x(ComId,Xs);
    {get,x}->
        case utility:decode_json(DataJson,[{companyid,b}]) of
        {ComId} when ComId=/=undefined -> {true,utility:pl2jsos_br(x_plists(ComId)),""};
        _->{true,utility:pl2jsos_br(x_plists()),""}
        end;
    {delete,x}->
        {ComId,Xs}=utility:decode_json(DataJson,[{companyid,b},{xs,ab}]),
        %delete_x(Id,Xs),
        io:format("******************************delete x:~p~n",[{ComId,Xs}]),
        case ?DB_READ(company_t,ComId) of
        {atomic,[Xt=#company_t{available_xs=Xs0}]}->
            ?DB_WRITE(Xt#company_t{available_xs=Xs0--Xs});
        _-> void
        end,
        
        {true,utility:pl2jsos_br(x_plists()),""};
    {post,ax}->
        {ComId,A,X}=utility:decode_json(DataJson,[{companyid,b},{a,b},{x,b}]),
        case {get_a_x(A),get_a_x_by_x(X),get_company(ComId)} of
        {[],[],[#company_t{available_xs=AvailableXS}]} ->
            case lists:member(X,AvailableXS) of
            true->
                sip_virtual:add_a_x(ComId,A,X),
                {true,utility:pl2jsos_br(all_a_x()),""};
            _->
                {false,utility:pl2jsos_br(all_a_x()),"X is not belong to the company "++binary_to_list(ComId)}
            end;
        {[],[],[]} ->
            {false,utility:pl2jsos_br(all_a_x()),"not existed company "++binary_to_list(ComId)};
        {[_|_],_,_}-> 
            {false,utility:pl2jsos_br(all_a_x()),"a is seized"};
        {_,[_|_],_}-> 
            {false,utility:pl2jsos_br(all_a_x()),"x is seized"}
        end;
    {get,ax}->
        {A}=utility:decode_json(DataJson,[{a,s}]),
        Data_=
        if is_list(A)-> utility:pl2jsos_br( a_x_plist(A));
        true->  utility:pl2jsos_br(all_a_x())
        end,
        {true,Data_,""};
    {delete,ax}->
        {A}=utility:decode_json(DataJson,[{a,s}]),
        sip_virtual:delete_a_x(A),
        {true,utility:pl2jsos_br(all_a_x()),""};
    {post,axb}->   
    % PayloadJsonBin= <<"{\"method\":\"get\",\"module\":\"axb\",\"event\":\"config\",\"data\":{\"newItem\":{\"a\":\"1\",\"x\":\"2\",\"b\":\"3\",\"trans\":\"4\",\"mode\":\"5\"},\"oldItem\":{}}}">>
     %   {{A,B,Trans,Mode}}=utility:decode_json(DataJson,[{newItem,o,[{a,s},{b,s},{trans,s},{mode,a}]}]),
        {A,B,Trans,Mode}=utility:decode_json(DataJson,[{a,s},{b,s},{trans,s},{mode,a}]),
        {Status,FailReason}=sip_virtual:bind_b(B,A,Trans,Mode),
        {Status,utility:pl2jsos_br(all_a_x_b()),FailReason};
    {delete,axb}->
        {_A,Trans,Mode,X}=utility:decode_json(DataJson,[{a,b},{trans,b},{mode,a},{x,b}]),
        %unbind_by_a(A,Trans,Mode),
        sip_virtual:unbind_b(X,Trans,Mode),

        {true,utility:pl2jsos_br(all_a_x_b()),""};
    {get,axb}->
        {A}=utility:decode_json(DataJson,[{a,b}]),
        {atomic, Rds}=mnesia_all_items(a_x_b_t),
        Res=
        if is_binary(A)-> 
            [I||I=#a_x_b_t{a=A0}<-Rds,A=:=A0];
        true-> all_a_x_b()
        end,
        {true,utility:pl2jsos_br( Res),""};
    {post,sip_nic}->
        {Id,Name,LocalIp,RemoteIp,LocalPort,RemotePort,Das,Nodes}=utility:decode_json(DataJson,[{id,b},{name,b},{localip,b},{remoteip,b},{localport,i},{remoteport,i},{das,b},{nodes,aa}]),
        add_sip_nic({Id,Name,LocalIp,RemoteIp,LocalPort,RemotePort,Das,Nodes});
    {get,sip_nic}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        Data_=
        if Id==undefined->
		utility:pl2jsos_br(all_sip_nic_plist());
		true-> utility:pl2jso_br(sip_nic_plist(Id))
	end,
	{true,Data_,""};
    {delete,sip_nic}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        ?DB_DELETE({sip_nic_t,Id}),
        {true,utility:pl2jsos_br(all_sip_nic_plist()),""};
    {post,signaltrace}->
        {Id,Ip,Filter}=utility:decode_json(DataJson,[{id,b},{ip,b},{filter_str,b}]),
        add_signaltrace1({Id,Ip,Filter},SendFunc);
    {delete,signaltrace}->
        {Id,Ip}=utility:decode_json(DataJson,[{id,b},{ip,b}]),
        delete_signaltrace(Ip,Id);
    {post,transaction}->
        {X,Transid}=utility:decode_json(DataJson,[{x,b},{transid,b}]),
        activate_trans({X,Transid});
    {delete,transaction}->
        {X,Transid}=utility:decode_json(DataJson,[{x,b},{transid,b}]),
        deactivate_trans({X,Transid});
    {get,transaction}->
        {X}=utility:decode_json(DataJson,[{x,b}]),
        get_active_trans(X);
    {get,traffic}->
        {Period,From,To}=utility:decode_json(DataJson,[{period,b},{from,ai},{to,ai}]),
        io:format("~p~n",[{Period,From,To}]),
        oam_get_traffic(Period,From,To);        
    {get,topology}->
        get_topology();
    Msg-> 
        io:format("oam_config_handler ~p not handled~n",[Msg]),
        {false,[utility:pl2jso_br([])],"unhandled event"}
    end,
    result_plist(IsSuccess,AckDataJO,Reason,Page,PageSize);
deal_oam_config_event([Method,Module,DataJson,Page,PageSize,ClientIp], SendFunc,_)->
    {IsSuccess,AckDataJO,Reason}=
    case {Method,Module} of
    {post,company}->
        {Id,Name,Passwd,Cdr_mode,Cdr_pushurl,NeedVoip,NeedPlaytone,NeedCompanyname}=utility:decode_json(DataJson,[{id,b},{name,b},{passwd,b},
              {cdr_mode,a},{cdr_pushurl,b},{needVoip,a},{needPlaytone,a},{needCompanyname,a}]),
        add_company(#company_t{id=Id,name=Name,passwd=Passwd,cdr_mode=Cdr_mode,cdr_pushurl=Cdr_pushurl,needVoip=NeedVoip,
                                              needPlaytone=NeedPlaytone,needCompanyname=NeedCompanyname});
    {get,company}->
        {true,utility:pl2jsos_br(all_company_plist()),""};
    {delete,company}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        delete_company(Id),
        {true,utility:pl2jsos_br(all_company_plist()),""};
    {post,x}->
        {ComId,NumStr}=utility:decode_json(DataJson,[{companyid,b},{num_str,b}]),
        Xs=config_intf:get_xs(NumStr),
        add_x(ComId,Xs);
    {get,x}->
        case utility:decode_json(DataJson,[{companyid,b}]) of
        {ComId} when ComId=/=undefined -> {true,utility:pl2jsos_br(x_plists(ComId)),""};
        _->{false,[],""}
        end;
    {delete,x}->
        {ComId,Xs}=utility:decode_json(DataJson,[{companyid,b},{xs,ab}]),
        %delete_x(Id,Xs),
        io:format("******************************delete x:~p~n",[{ComId,Xs}]),
        Xs1=[X||X<-Xs,mnesia:dirty_index_read(a_x_t,X,#a_x_t.x)==[]],
        case ?DB_READ(company_t,ComId) of
        {atomic,[Xt=#company_t{available_xs=Xs0}]}->
            ?DB_WRITE(Xt#company_t{available_xs=Xs0--Xs1});
        _-> void
        end,
        
        {true,utility:pl2jsos_br(x_plists()),""};
    {post,ax}->
        {ComId,A,X}=utility:decode_json(DataJson,[{companyid,b},{a,b},{x,b}]),
        case {get_a_x(A),get_a_x_by_x(X),get_company(ComId)} of
        {[],[],[#company_t{available_xs=AvailableXS}]} ->
            case lists:member(X,AvailableXS) of
            true->
                sip_virtual:add_a_x(ComId,A,X),
                {true,utility:pl2jsos_br(all_a_x()),""};
            _->
                {false,utility:pl2jsos_br(all_a_x()),"X is not belong to the company "++binary_to_list(ComId)}
            end;
        {[],[],[]} ->
            {false,utility:pl2jsos_br(all_a_x()),"not existed company "++binary_to_list(ComId)};
        {[_|_],_,_}-> 
            {false,utility:pl2jsos_br(all_a_x()),"a is seized"};
        {_,[_|_],_}-> 
            {false,utility:pl2jsos_br(all_a_x()),"x is seized"}
        end;
    {get,ax}->
        {A}=utility:decode_json(DataJson,[{a,s}]),
        if is_list(A)-> {true,utility:pl2jsos_br( a_x_plist(A)),""};
        true->  {false,[],"a_not_found"}
        end;
    {delete,ax}->
        {A}=utility:decode_json(DataJson,[{a,s}]),
        sip_virtual:delete_a_x(A),
        {true,utility:pl2jsos_br(all_a_x()),""};
    {post,axb}->   
    % PayloadJsonBin= <<"{\"method\":\"get\",\"module\":\"axb\",\"event\":\"config\",\"data\":{\"newItem\":{\"a\":\"1\",\"x\":\"2\",\"b\":\"3\",\"trans\":\"4\",\"mode\":\"5\"},\"oldItem\":{}}}">>
     %   {{A,B,Trans,Mode}}=utility:decode_json(DataJson,[{newItem,o,[{a,s},{b,s},{trans,s},{mode,a}]}]),
        {A,B,Trans,Mode}=utility:decode_json(DataJson,[{a,s},{b,s},{trans,s},{mode,a}]),
        {Status,FailReason}=sip_virtual:bind_b(B,A,Trans,Mode),
        {Status,utility:pl2jsos_br(all_a_x_b()),FailReason};
    {delete,axb}->
        {_A,Trans,Mode,X}=utility:decode_json(DataJson,[{a,b},{trans,b},{mode,a},{x,b}]),
        %unbind_by_a(A,Trans,Mode),
        sip_virtual:unbind_b(X,Trans,Mode),

        {true,utility:pl2jsos_br(all_a_x_b()),""};
    {get,axb}->
        {A}=utility:decode_json(DataJson,[{a,b}]),
        {atomic, Rds}=mnesia_all_items(a_x_b_t),
        Res=
        if is_binary(A)-> 
            [I||I=#a_x_b_t{a=A0}<-Rds,A=:=A0];
        true-> []
        end,
        {true,utility:pl2jsos_br( Res),""};
    {post,sip_nic}->
        {Id,Name,LocalIp,RemoteIp,LocalPort,RemotePort,Das,Nodes}=utility:decode_json(DataJson,[{id,b},{name,b},{localip,b},{remoteip,b},{localport,i},{remoteport,i},{das,b},{nodes,aa}]),
        add_sip_nic({Id,Name,LocalIp,RemoteIp,LocalPort,RemotePort,Das,Nodes});
    {get,sip_nic}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        Data_=
        if Id==undefined->
		[];
		true-> utility:pl2jso_br(sip_nic_plist(Id))
	end,
	{true,Data_,""};
    {delete,sip_nic}->
        {Id}=utility:decode_json(DataJson,[{id,b}]),
        ?DB_DELETE({sip_nic_t,Id}),
        {true,utility:pl2jsos_br(all_sip_nic_plist()),""};
    {post,signaltrace}->
        {Id,Ip,Filter}=utility:decode_json(DataJson,[{id,b},{ip,b},{filter_str,b}]),
        add_signaltrace1({Id,Ip,Filter},SendFunc);
    {delete,signaltrace}->
        {Id,Ip}=utility:decode_json(DataJson,[{id,b},{ip,b}]),
        delete_signaltrace(Ip,Id);
    {post,transaction}->
        {X,Transid}=utility:decode_json(DataJson,[{x,b},{transid,b}]),
        activate_trans({X,Transid,ClientIp});
    {delete,transaction}->
        {X,Transid}=utility:decode_json(DataJson,[{x,b},{transid,b}]),
        deactivate_trans({X,Transid});
    {get,transaction}->
        {X}=utility:decode_json(DataJson,[{x,b}]),
        get_active_trans(X);
    {get,traffic}->
        {Period,From,To}=utility:decode_json(DataJson,[{period,b},{from,ai},{to,ai}]),
        io:format("~p~n",[{Period,From,To}]),
        oam_get_traffic(Period,From,To);        
    {get,topology}->
        get_topology();
    Msg-> 
        io:format("oam_config_handler ~p not handled~n",[Msg]),
        {false,[utility:pl2jso_br([])],"unhandled event"}
    end,
    AckDataJO1=if Method=/=get-> []; true-> AckDataJO end,
    result_plist(IsSuccess,AckDataJO1,Reason,Page,PageSize).
page_example()->    page_example(1,1,50).
page_example(Totals,Page1,PageSize1)-> {page,[{total,Totals},{current,Page1},{pageSize,PageSize1}]}.    
result_plist(IsSuccess,AckDataJO,Reason,Page,PageSize)->
    Page1=if is_integer(Page)-> Page; true-> 1 end,
    PageSize1=if is_integer(PageSize)-> PageSize; true-> 20 end,
    Totals=if is_list(AckDataJO)-> length(AckDataJO); true-> 1 end,
    Low=(Page1-1)*PageSize1+1,
    AckData1= lists:sublist(AckDataJO,Low,PageSize1),
    [{success,IsSuccess},{data,AckData1},{message,Reason},page_example(Totals,Page1,PageSize1)].
add_company(Com=#company_t{id=Id})->
    case get_company(Id) of
    []->    
        ?DB_WRITE(Com),
        {true,utility:pl2jsos_br(all_company_plist()),""};
    _-> {false,utility:pl2jsos_br(all_company_plist()),"id_existed"}
    end.
delete_company(Id)-> ?DB_DELETE({company_t,Id}).
delete_all_x(ComId)->
    case ?DB_READ({company_t,ComId}) of
    [Company=#company_t{available_xs=Xs0}]->
        ?DB_WRITE(Company#company_t{available_xs=[]});
    _-> void
    end.
get_all_x(Id)->
    case ?DB_READ(company_t,Id) of
    {atomic,Rlist}->
        Rlist;
    _-> []
    end.
x_plists()->
    {atomic, Rds}=?DB_QUERY(company_t),
    [[{companyid,Id},{companyname,Name},{xs,X}]||#company_t{id=Id,name=Name,available_xs=Xs}<-Rds,X<-Xs].
    %?MNESIA2PLIST(company_t).
x_plists(Id)->
    case ?DB_READ(company_t,Id) of
    {atomic,Rds}->
        [[{companyid,Id},{companyname,Name},{xs,X}]||#company_t{name=Name,available_xs=Xs}<-Rds,X<-Xs];
    _-> []
    end.
get_xs(NumStr) when is_binary(NumStr)-> get_xs(binary_to_list(NumStr));
get_xs(NumStr)->
    Xs0=string:tokens(NumStr,", "),
    F=fun(Range)->
            case re:run(Range,"(0*)(\\d+)-(\\d+)",[{capture,all_but_first,list}]) of
                {match,[Zeros,Low,High]}->
                    Ints=lists:seq(list_to_integer(Low),list_to_integer(High)),
                    [list_to_binary(Zeros++integer_to_list(Int))||Int<-Ints];
                _-> list_to_binary(Range)
            end end,
     lists:flatten([F(X)||X<-Xs0]).
get_companyname(Id)->
    case get_company(Id) of
    [#company_t{name=N}|_]->N;
    _-> ""
    end.
get_company(Id)->
    case ?DB_READ(company_t,Id) of
    {atomic,Rlist}->
        Rlist;
    _-> []
    end.
all_company_plist()->
    {atomic, Rds}=mnesia_all_items(company_t),
    [[{id,Id},{name,Name},{passwd,Passwd},{cdr_mode,Cdr_mode},{cdr_pushurl,Cdr_pushurl},{needVoip,NeedVoip},{needPlaytone,NeedPlaytone},{needCompanyname,NeedCompanyname}]||
        #company_t{id=Id,name=Name,passwd=Passwd,cdr_mode=Cdr_mode,cdr_pushurl=Cdr_pushurl,needVoip=NeedVoip,
                                              needPlaytone=NeedPlaytone,needCompanyname=NeedCompanyname}<-Rds].
all_sip_nic_plist()->
    {atomic, Rds}=mnesia_all_items(sip_nic_t),
    [[{id,Id},{name,Name},{localip,Lip},{remoteip,Rip},{localport,Lp},{remoteport,Rp},{das,Das},{nodes,Nodes}]||
        #sip_nic_t{id=Id,name=Name,addr_info={Lip,Lp,Rip,Rp},das=Das,nodes=Nodes}<-Rds].
sip_nic_plist(Id)->    
    case ?DB_READ(sip_nic_t,Id) of
    {atomic,[#sip_nic_t{id=Id,name=Name,addr_info={Lip,Lp,Rip,Rp},das=Das,nodes=Nodes}]}->
        [{id,Id},{name,Name},{localip,Lip},{remoteip,Rip},{localport,Lp},{remoteport,Rp},{das,Das},{nodes,Nodes}];
    _-> []
    end.
all_a_x()->
    {atomic, Rds}=mnesia_all_items(a_x_t),
    [[{a,A},{x,X},{companyid,C},{companyname,get_companyname(C)}]||#a_x_t{a=A,x=X,companyid=C}<-Rds].
all_a_x_b()->
    {atomic, Rds}=mnesia_all_items(a_x_b_t),
    GetCompanyInfoList=fun(A)->
                            case get_a_x(A) of
                            [#a_x_t{companyid=Ci}]->                      
                                [{companyid,Ci},{companyname,get_companyname(Ci)}];
                            _-> []
                            end
                        end,
    [[{a,A},{x,X},{b,B},{trans,Trans},{mode,Mode}]++GetCompanyInfoList(A)||#a_x_b_t{x_t={X,Trans},b=B,a=A,mode=Mode}<-Rds].
a_x_plist(A)->    
    case get_a_x(A) of
    [#a_x_t{a=A1,x=X}]-> [[{a,A1},{x,X}]];
    _-> []
    end.
a_x_b_plist(A)->    
    case get_a_x(A) of
    [#a_x_t{a=A,x=X}]-> [{a,A},{x,X}];
    _-> []
    end.
get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort) when is_list(LocalIp)->
    get_sip_nic(list_to_binary(LocalIp),LocalPort,RemoteIp,RemotePort);
get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort) when is_list(RemoteIp)->    
    get_sip_nic(LocalIp,LocalPort,list_to_binary(RemoteIp),RemotePort);
get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort) ->
    mnesia:dirty_index_read(sip_nic_t,{LocalIp,LocalPort,RemoteIp,RemotePort},#sip_nic_t.addr_info).
get_sip_nic_by_id(Id)->
    {atomic,R}=?DB_READ({sip_nic_t,Id}),
    R.
get_sip_nic_by_node(Node)->
    mnesia:dirty_index_read(sip_nic_t,Node,#sip_nic_t.node).
delete_sip_nic(Id)-> ?DB_DELETE({sip_nic_t,Id}).    
add_sip_nic({Id,Name,LocalIp,RemoteIp,LocalPort,RemotePort,Das,Nodes})->
    Node=list_to_atom(binary_to_list(<<Name/binary,"@",LocalIp/binary>>)),
    case {get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort),get_sip_nic_by_id(Id),get_sip_nic_by_node(Node)} of
    {[],[],[]}-> 
        ?DB_WRITE(#sip_nic_t{id=Id,addr_info={LocalIp,LocalPort,RemoteIp,RemotePort},das=Das,nodes=Nodes,name=Name,node=Node}),
        {sip_dispatch,Node} ! refresh_sip_nodes,
        {true,utility:pl2jsos_br(all_sip_nic_plist()),""};
    {_,[],[]}-> 
        {false,utility:pl2jsos_br(all_sip_nic_plist()),"id existed already"};
    {[],_,[]}->
        {false,utility:pl2jsos_br(all_sip_nic_plist()),"sip addr existed already"};
    {[],[],_}->
        {false,utility:pl2jsos_br(all_sip_nic_plist()),"name existed already"};
    _-> {false,utility:pl2jsos_br(all_sip_nic_plist()),"id/addr/name existed already"}
    end.

add_signaltrace1({Id,Ip,Filter},SendFunc)->
    Func=fun({MyIp,SSIp,Message,Direction})->
            Time=utility:ts(),
            case signal_trace:need_traced(Ip,Message, Filter) of
            true->  
                Method=
                case sippacket:parse_firstline((Message),0) of
                {{response,{IStatus,Action_str}},_}-> integer_to_list(IStatus)++" "++Action_str;
                {{request,{Method_,Url}},_}-> Method_++" "++Url
                end,
                Signal=utility:pl2jso_br([{time,Time},{myip,MyIp},{ssip,SSIp},{direction,Direction},
                                                         {detail,Message},{method,Method}]);
            _ -> not_need
            end
        end,
    signal_trace:add_traced_func(Ip,{Id,Func,SendFunc}),
    {true,utility:pl2jsos_br([[{status,ok},{id,Id}]]),""}.
delete_signaltrace(Ip,Id)->
    signal_trace:delete_traced_func(Ip,Id),
    {true,utility:pl2jsos_br([[{status,ok},{id,Id}]]),""}.
activate_trans({X,Transid,ClientIp})->
    ?DB_WRITE(#active_trans_t{x=X,transid=Transid,clientip=ClientIp}),
    {true,utility:pl2jsos_br([[{status,ok},{transid,Transid}]]),""}.
get_active_trans(X)->
    case ?DB_READ(active_trans_t,X) of
    {atomic,[#active_trans_t{transid=Transid}]}->
        {true,utility:pl2jsos_br([[{transid,Transid}]]),""};
    _->
        {false,utility:pl2jsos_br([[{transid,<<>>}]]),"not_active"}
    end.
deactivate_trans({X,Transid})->
    case ?DB_READ(active_trans_t,X) of
    {atomic,[#active_trans_t{transid=Transid}]}->
        ?DB_DELETE(active_trans_t,X),
        {true,utility:pl2jsos_br([[{status,ok},{transid,Transid}]]),""};
     {atomic,[#active_trans_t{}]}->
         {false,utility:pl2jsos_br([[{status,failed},{transid,Transid}]]),"transid_incorrect"};
     _->
         {false,utility:pl2jsos_br([[{status,failed},{transid,Transid}]]),"x_not_activated"}
     end.
get_topology()->
     {atomic, Rds}=mnesia_all_items(sip_nic_t),
     OnlineNodes=[node()|nodes()],
     F=fun(Node_)->
             case lists:member(Node_,OnlineNodes) of
             true-> online;
             _-> offline
             end end,
             
     Nics=utility:pl2jsos([[{name,Node},{sip_node,SipNodes},{status,F(Node)}]||#sip_nic_t{node=Node,nodes=SipNodes}<-Rds]),
     {atomic, CallOpts}=mnesia_all_items(call_opt_t),
     Sips=utility:pl2jsos_br([[{name,Node},{in_sss,[list_to_binary(InSS)||InSS<-InSSs]},{out_ss,OutSS},{status,F(Node)}]||#call_opt_t{node=Node,value=#{in_ssips:=InSSs,out_ssip:=OutSS}}<-CallOpts]),
     {true,utility:pl2jsos([[{nics,Nics},{sips,Sips}]]),""}.
     
oam_get_traffic(Period,From,To)->
    {[Year1,Mon1,Day1,Hour1,Min1,Sec1|_],[Year2,Mon2,Day2,Hour2,Min2,Sec2|_]}={From,To},
    QH1=(qlc:q([X||X<-mnesia:table(traffic_t),X#traffic_t.key>={{Year1,Mon1,Day1},{Hour1,Min1,Sec1}},X#traffic_t.key<{{Year2,Mon2,Day2},{Hour2,Min2,Sec2}}])),
    QH2 = qlc:keysort(2, QH1, [{order, ascending}]), 
    {atomic,Res}=?DB_OP(qlc:e(QH2)),
    Lsts=split_by_period(Res,Period),
    F=fun({LocalTime,Traffics})->
                CallList=[length(Items)||#traffic_t{items=Items}<-Traffics],
                [{time,utility:d2s(LocalTime)},{calls,lists:sum(CallList)}]
            end,
    {true,utility:pl2jsos_br([[{period,Period},{data,utility:pl2jsos_br([F(Item_)||Item_<-Lsts])}]]),""}.
split_by_period([],Period)->[];
split_by_period(Traffic=[#traffic_t{key=FirstTime}|_],Period)-> 
    split_by_period(Traffic,Period,time_step(FirstTime,Period),[],[]).
split_by_period([],_Period,Dest1,CurSeg,Res)-> lists:reverse([{Dest1,CurSeg}|Res]);
split_by_period([H=#traffic_t{key=Time0}|T],Period,Dest1,Seg,Res) when Time0<Dest1 -> 
    split_by_period(T,Period,Dest1,[H|Seg],Res);
split_by_period(Traffic,Period,Dest1,Seg,Res) -> 
    split_by_period(Traffic,Period,time_step(Dest1,Period),[],[{Dest1,Seg}|Res]).
    
time_step(LocalTime,Seconds) when is_integer(Seconds)-> 
    calendar:gregorian_seconds_to_datetime(calendar:datetime_to_gregorian_seconds(LocalTime)+Seconds);
time_step(LocalTime,Period) when is_binary(Period)-> time_step(LocalTime,binary_to_list(Period));
time_step(LocalTime,Period) when is_list(Period)-> time_step(LocalTime,list_to_atom(Period));
time_step(LocalTime,hour)->time_step(LocalTime,3600);
time_step(LocalTime,second)->time_step(LocalTime,1);
time_step(LocalTime,minute)->time_step(LocalTime,60);
time_step(LocalTime,day)->time_step(LocalTime,3600*24);
time_step(LocalTime,week)->time_step(LocalTime,3600*24*7);
time_step(LocalTime,month)->time_step(LocalTime,3600*24*30).
%% -----------------  test  --------------------------------------------    
send_oam_config_fortest(QueueName,CorrelationId,ReplyTo,Payload)->
    send_oam_config(QueueName,CorrelationId,ReplyTo,Payload),
    utility:delay(50).
json_decode_test()->
    Spec=[{method,s},{module,s},{data,r}],
    Bytes= <<"{\"method\":\"post\",\"module\":\"company\",\"data\":{\"id\":\"livecom\",\"name\":\"livecom\",\"capacity\":\"100\"}}">>,
    ?assertMatch({"post","company",{obj,[{"id",<<"livecom">>},{"name",<<"livecom">>},{"capacity",<<"100">>}]}},utility:decode(Bytes,Spec)),
    ok.
plist2json_test()->
    Pl=[{a,b},{c,"d"}],
    Jstr=plist2json(Pl),
    ?assertEqual("{\"a\":\"b\",\"c\":\"d\"}", Jstr),
    ok.
oam_config_payload_test()->
    Jstr=oam_config_payload(post,company,[{id,"livecom"},{name,"livecom"},{capacity,"100"}]),
    Exp= <<"{\"method\":\"post\",\"module\":\"company\",\"data\":{\"id\":\"livecom\",\"name\":\"livecom\",\"capacity\":\"100\"}}">>,
    ?assertEqual(Exp, Jstr),
    ok.

recv_msg()->
    receive
        Msg-> Msg
    after 2000->
        timeout
    end.
        
recv_oam_msg_test()->
    QueueName= <<"oam_config_test">>,
    CorrelationId= undefined,%<<"8">>,
    Replyto= undefined,%<<"oam_ack">>,
    setup(),
    Payload= oam_config_payload(post,company,[{id,"livecom"},{name,"livecom"},{capacity,"100"}]),
    Key=os:timestamp(),
    Callback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    start(QueueName,Callback),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    [#test_t{val=Actual}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Payload,Actual),
    ok.

company_test()->    
    QueueName= <<"oam_config">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    Module= <<"company">>, 
    Id= <<"1">>,
    Das= <<"2">>,
    Name= <<"livecom">>,
    Passwd= <<"666666">>,
    CdrPushUrl= <<"www.livecom.hk">>,
    NeedVoip=true,
    NeedPlaytone=true,
    NeedCompanyname=true,
    Callback=fun oam_config_handler/1,
    config_intf:start(QueueName,Callback),

    delete_company(Id),
    []=get_company(Id),
    Key=os:timestamp(),
    GetAckCallback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),

    %add company
    Plist=[{id,Id},{name,Name},{passwd,Passwd},{cdr_mode,push},{cdr_pushurl,CdrPushUrl},{needVoip,NeedVoip},{needPlaytone,NeedPlaytone},
       {needCompanyname,NeedCompanyname}],
    Payload= oam_config_payload(post,company,Plist),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    ?assertMatch([#company_t{id=Id,name=Name,passwd=Passwd,cdr_pushurl=CdrPushUrl}],
        get_company(Id)),

    %get all
    Plist_get_all=[],
    Payload_getall= oam_config_payload(get,company,Plist_get_all),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_getall),
    Exp_getall=ack_packet_fortest(utility:pl2jsos_br(all_company_plist())),
    [#test_t{val=Actual_getall}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Exp_getall,Actual_getall),

    %delete sip_nic test
    Plist_del=[{id,Id}],
    Payload_del= oam_config_payload(delete,company,Plist_del),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_del),
    ?assertEqual([], get_company(Id)),
    ok.
x_distribute_test()->    
    QueueName= <<"oam_config">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    CompanyId= <<"1">>,
    NumStr= <<"2180246990,2180246992,2180247001-2180247100">>,
    Xs=get_xs(NumStr),
    ?assertEqual(102,length(Xs)),
    Callback=fun oam_config_handler/1,
    config_intf:start(QueueName,Callback),

    delete_all_x(CompanyId),
    %[]=get_all_x(CompanyId),
    Key=os:timestamp(),
    GetAckCallback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),


    %add x when company not existed
    delete_company(CompanyId),
    Plist=[{companyid,CompanyId},{num_str,NumStr}],
    Payload= oam_config_payload(post,x,Plist),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    []=get_all_x(CompanyId),
    Expected_add1=ack_packet_fortest(utility:pl2jsos_br(config_intf:x_plists(CompanyId)),false,"companyid 1 not existed"),
    [#test_t{val=Actual_add1}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Expected_add1,Actual_add1),
    
    %add x when company  existed
    add_company(#company_t{id=CompanyId,name= <<"livecom">>}),
    Plist=[{companyid,CompanyId},{num_str,NumStr}],
    Payload= oam_config_payload(post,x,Plist),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    [#company_t{id=CompanyId,available_xs=Xs}]=get_all_x(CompanyId),
    
    %get all
    Plist_get_all=[{companyid,CompanyId}],
    Payload_getall= oam_config_payload(get,x,Plist_get_all),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_getall),
    Exp_getall=config_intf:ack_packet_fortest(utility:pl2jsos_br(config_intf:x_plists(CompanyId))),
    [#test_t{val=Actual_getall}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Exp_getall,Actual_getall),

    %delete x test
    Plist_del=[{companyid,CompanyId},{xs,["2180247100"]}],
    Payload_del= oam_config_payload(delete,x,Plist_del),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_del),
    [#company_t{available_xs=Xs_del}]=config_intf:get_all_x(CompanyId),
    ?assertEqual(101, length(Xs_del)),
    ok.
    
a_x_test()->
    CompanyId= <<"1">>,
    QueueName= <<"oam_config">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    A= <<"18017888888">>, 
    A1= <<"18017888889">>, 
    X= <<"68898888">>,
    NumStr= <<"1-10">>,
    Callback=fun config_intf:oam_config_handler/1,
    config_intf:start(QueueName,Callback),
    Key=os:timestamp(),
    GetAckCallback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),
    CorrelationId1= <<"9">>,

    %add a_x when company or x not available
    delete_company(CompanyId),
    Plist=[{companyid,CompanyId},{num_str,NumStr}],
    Payloadx= oam_config_payload(post,x,Plist),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payloadx),
    []=get_all_x(CompanyId),
    Expected_add1=ack_packet_fortest(utility:pl2jsos_br(config_intf:x_plists(CompanyId)),false,"companyid 1 not existed"),
    [#test_t{val=Actual_add1}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Expected_add1,Actual_add1),
    

    % post a_x test
    sip_virtual:delete_a_x(A),
    %delete_company(CompanyId),
    add_company(#company_t{id=CompanyId,name= <<"livecom">>}),
    %add_x(CompanyId,[X]),
    %[#company_t{xs=}]=mnesia:dirty_read(company_t,CompanyId),
    Payload= config_intf:oam_config_payload(post,ax,[{companyid,CompanyId},{a,A},{x,X}]),
    config_intf:send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    Lists=config_intf:get_a_x(A),
    Lists=sip_virtual:get_a_x_by_x(X),
    ?assertMatch([#a_x_t{a=A,x=X,companyid=CompanyId}],Lists),

    % test repeat add X for another A1,should not change.
    Payload_rep= config_intf:oam_config_payload(post,ax,[{companyid,CompanyId},{a,A1},{x,X}]),
    config_intf:send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_rep),
    []=config_intf:get_a_x(A1),
    Lists=config_intf:get_a_x(A),
    Lists=sip_virtual:get_a_x_by_x(X),
    ?assertMatch([#a_x_t{a=A,x=X,companyid=CompanyId}],Lists),

    %get all a_x test
    Payload_get= config_intf:oam_config_payload(get,ax,[{unused,undefined}]),
    config_intf:send_oam_config_fortest(QueueName,CorrelationId1,Replyto,Payload_get),
    [#test_t{val=Actual_ack}]=mnesia:dirty_read(test_t,Key),
    Exp_ack=config_intf:ack_packet_fortest(utility:pl2jsos_br( config_intf:all_a_x())),
    ?assertEqual(Exp_ack,Actual_ack),
    
    %get one a_x test
    Payload_get1= config_intf:oam_config_payload(get,ax,[{a,A}]),
    config_intf:send_oam_config_fortest(QueueName,CorrelationId1,Replyto,Payload_get1),
    [#test_t{val=Actual_ack1}]=mnesia:dirty_read(test_t,Key),
    Exp_ack1=ack_packet_fortest(utility:pl2jsos_br( config_intf:a_x_plist(A))),
    ?assertEqual(Exp_ack1,Actual_ack1),

    % delete a_x test
    Payload_delete= oam_config_payload(delete,ax,[{a,A}]),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_delete),
    utility:delay(30),
    Exp_del= [],
    ?assertEqual(Exp_del,a_x_plist(A)),

    ok.
bind_b_test()->
    CompanyId= <<"222">>,
    QueueName= <<"oam_config_test">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    A= <<"18017888888">>, 
    B= <<"13816468888">>,
    Trans= <<"888">>,
    Mode=single,
    X= <<"68891234">>,
    sip_virtual:add_a_x(CompanyId,A,X),
    sip_virtual:unbind_b(X,Trans,Mode),
    Callback=fun oam_config_handler/2,
    config_intf:start(QueueName,Callback),
    Key=os:timestamp(),
    GetAckCallback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),
    CorrelationId1= <<"9">>,

    % bind_b test
%    Payload= oam_config_payload(post,axb,[{newItem,[{a,A},{b,B},{trans,Trans},{mode,Mode}]},{oldItem,[]}]),
    Payload= oam_config_payload(post,axb,[{a,A},{b,B},{trans,Trans},{mode,Mode}]),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    Res=sip_virtual:get_by_x(X,Trans,Mode),
    ?assertEqual(#a_x_b_t{x_t={X,Trans},a=A,b=B,mode=Mode},Res),

    % unbind_b test
    % <<"{\"method\":\"delete\",\"module\":\"axb\",\"data\":{\"a\":\"18017888888\",\"b\":\"13816468888\",\"trans\":\"888\",\"mode\":\"single\",\"x\":\"68891234\"}}">>
    Payload_unbind= oam_config_payload(delete,axb,[{a,A},{b,B},{trans,Trans},{mode,Mode},{x,X}]),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_unbind),
    Res_unbind=sip_virtual:get_by_x(X,Trans,Mode),
    ?assertMatch([],Res_unbind),

    %get all bind_b test
    Payload_get= oam_config_payload(get,axb,[{u,u}]),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_get),
    %Res_unbind=sip_virtual:get_by_x(X,Trans,Mode),
    AckDataJO=utility:pl2jsos_br( all_a_x_b()),
    Expect_get=ack_packet_fortest(AckDataJO),
    [#test_t{val=Actual_get}]=mnesia:dirty_read(test_t,Key),
    ?assertMatch(Expect_get,Actual_get),
    
    ok.

ack_packet_fortest(AckDataJO)->ack_packet_fortest(AckDataJO,true,"").
ack_packet_fortest(AckDataJO,IsSuccess,Message)->
    list_to_binary(rfc4627:encode(utility:pl2jso_br(result_plist(IsSuccess,AckDataJO,Message,undefined,undefined)))).
    
traffic_test()->
    QueueName= <<"oam_config">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    setup(),
    Key=os:timestamp(),
    GetAckCallback=fun(Body,_)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),

    Payload_get= oam_config_payload(get,traffic,[{period,minute},{from,[2017,7,20,18,0,0]},{to,[2017,7,21,18,0,0]}]),
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_get),
    %Res_unbind=sip_virtual:get_by_x(X,Trans,Mode),

    [#test_t{val=Actual_get}]=mnesia:dirty_read(test_t,Key),
    ?assertMatch("",Actual_get),
    % test interface
    
    ok.

sip_nic_test()->
%1 判断是否存在sip_nic@ip节点，如果不存在，通过ct_ssh创建节点;(linux的用户名密码要一致,创建节点的脚本要写好,通过scp copy过去)
%2 ping该节点,如果ping通, rpc:call，调用spawn socket_udp进程,带上ip/port/remoteip/remoteport,name/das，进程名用name,进程和ip/port关联
%3 
    QueueName= <<"oam_config">>,
    CorrelationId= <<"8">>,
    Replyto= <<"oam_ack">>,
    Name= <<"sipnic1">>, 
    Id= <<"1">>,
    LocalIp= <<"10.1.1.1">>,
    RemoteIp= <<"10.1.1.2">>,
    LocalPort=5060,
    RemotePort=5061,
    Das= <<"2">>,
    Nodes=['a@t','b@t'],
    Callback=fun oam_config_handler/1,
    config_intf:start(QueueName,Callback),
    delete_sip_nic(Id),
    []=get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort),
    Key=os:timestamp(),
    GetAckCallback=fun(Body)-> 
                       mnesia:dirty_write(#test_t{key=Key,val=Body})
                  end,
    config_intf:start(Replyto,GetAckCallback),

    % post sip_nic test
    Plist=[{id,Id},{name,Name},{localip,LocalIp},{remoteip,RemoteIp},{localport,LocalPort},{remoteport,RemotePort},{das,Das},{nodes,Nodes}],
    Payload= oam_config_payload(post,sip_nic,Plist),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload),
    ?assertEqual([#sip_nic_t{id=(Id),name=(Name),das=Das,nodes=Nodes,addr_info=
        {(LocalIp),LocalPort,(RemoteIp),RemotePort}}],
        get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort)),
    
    %get sip_nic test
    %get one
    Plist_get=[{id,Id}],
    Payload_get= oam_config_payload(get,sip_nic,Plist_get),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_get),
    Exp=ack_packet_fortest(Plist),
    [#test_t{val=Actual_get}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Exp,Actual_get),
    %get all
    Plist_get_all=[],
    Payload_getall= oam_config_payload(get,sip_nic,Plist_get_all),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_getall),
    Exp_getall=ack_packet_fortest(utility:pl2jsos_br(all_sip_nic_plist())),
    [#test_t{val=Actual_getall}]=mnesia:dirty_read(test_t,Key),
    ?assertEqual(Exp_getall,Actual_getall),

    %delete sip_nic test
    Plist_del=[{id,Id}],
    Payload_del= oam_config_payload(delete,sip_nic,Plist_del),    
    send_oam_config_fortest(QueueName,CorrelationId,Replyto,Payload_del),
    ?assertEqual([],        get_sip_nic(LocalIp,LocalPort,RemoteIp,RemotePort)),

    ok.


test_rpc_pid(Rpid)->
    io:format("rpid:~p  alive:~p~n",[Rpid,node(Rpid)]),
    Rpid.
