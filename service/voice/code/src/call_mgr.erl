-module(call_mgr).
-compile(export_all).
-include("sipsocket.hrl").
-include("virtual.hrl").
-include("db_op.hrl").
-include("call.hrl").
-record(call_t,{caller,oppid,callee,tppid,calltype,starttime="not_talking",endtime,reason,op_sip_ip,tp_sip_ip,op_media_ip,tp_media_ip}).
-record(st,{callers=[],interval_stats=#traffic_t{},other=[]}).
-define(STAT_INTERVAL, 60000).

start_monitor()->
    {_,Pid}=start(),
    erlang:monitor(process,Pid),
    Pid.
start()->
    case file:consult("conf/call_opt") of
    {ok,[CallOpt=#{}|_]}->
        R=?DB_WRITE(#call_opt_t{node=node(),value=CallOpt}),
        io:format("write call_opt_t R:~p ~p~n",[R,CallOpt]);
    _-> void
    end,
    my_server:start({local,?MODULE}, ?MODULE,[],[]).
x_prefix()-> "0086".    
get_cdr_data_from(X) when is_list(X)->get_cdr_data_from(list_to_binary(X));
get_cdr_data_from(X)->
    M1= case sip_virtual:get_a_x_by_x(X) of
               [#a_x_t{companyid=ComId,a=A,x=X}|_]-> #{companyid=>ComId,a=>A,x=>X};
               _-> #{x=>X}
           end,
    TransId=get_active_transid(X),
    case sip_virtual:get_by_x(X,TransId) of
    #a_x_b_t{a=A1,b=B,mode=Mode}-> M1#{a=>A1,b=>B,mode=>Mode,transid=>TransId};
    _->M1#{transid=>TransId}
    end.
get_active_transid(X)->
    case ?DB_READ(active_trans_t,X) of
    {atomic,[#active_trans_t{transid=TransId}]}-> TransId;
    _->  ?DEFAULT_TRANS
    end.
get_virtual_caller_callee(Caller,Callee)-> get_virtual_caller_callee(Caller,Callee,get_active_transid(Callee)).
get_virtual_caller_callee(Caller,Callee,Trans)-> 
    get_virtual_caller_callee1(utility:value2binary(Caller),utility:value2binary(Callee),Trans).
get_virtual_caller_callee1(Caller,Callee,Trans)-> 
   case {try_trans_caller_callee_in_dual(Caller,Callee,Trans), try_trans_caller_callee_in_single(Caller,Callee,Trans)} of
    {false,false}->try_trans_by_a_x_t(Caller,Callee);
    {false,R}->R;
    {call_failed,_}-> call_failed;
    {R,_}->R
    end.
try_trans_by_a_x_t(Caller,Callee)->
    case sip_virtual:get_a_x_by_x(Callee) of
    [#a_x_t{a=Caller}]-> call_failed;
    [#a_x_t{a=A}]-> {Caller,A};
    _-> {Caller,Callee}
    end.
    
try_trans_caller_callee_in_dual(Caller,Callee,Trans)->
    Item=sip_virtual:get_by_x(Callee,Trans,dual),
    %io:format("call_mgr.erl virtual Item:~p~n",[{Caller,Callee,Item}]),
    case Item of
        #a_x_b_t{a=Caller,x_t={Callee,_},b=B} when is_binary(B) andalso size(B)>0->  {Callee,B};
        #a_x_b_t{a=Caller,x_t={Callee,_}}-> {Caller,Caller};

        #a_x_b_t{a=A,x_t={Callee,_},mode=dual,b=Caller}->{Callee,A};
        #a_x_b_t{a=_A,x_t={Callee,_},mode=dual}-> call_failed;
        _-> false   %continue to judge single
    end.
try_trans_caller_callee_in_single(Caller,Callee,Trans)->  % for single-virtual
    Item=sip_virtual:get_by_x(Callee,Trans,single),
    %io:format("call_mgr.erl virtual Item:~p~n",[{Caller,Callee,Item}]),
    case Item of
        #a_x_b_t{a=Caller,x_t={Callee,_},b=B} when is_binary(B) andalso size(B)>0->  {Callee,B};
        #a_x_b_t{a=Caller,x_t={Callee,_}}-> {Caller,Caller};
        #a_x_b_t{a=A,x_t={Callee,_},b=Caller}->{Caller,A};
        #a_x_b_t{a=A,x_t={Callee,_}}-> {Caller,A};
        #a_x_b_t{}-> {Caller,Callee};
        _-> false
    end.
to_binary(#traffic_item{caller=Caller,callee=Callee,newcaller=NCaller,newcallee=NCallee})-> 
    #traffic_item{caller=utility:value2binary(Caller),callee=utility:value2binary(Callee),newcaller=utility:value2binary(NCaller),newcallee=utility:value2binary(NCallee)}.
sip_incoming(Caller,Callee,Origin=#siporigin{},SDP,OpPid,sip_virtual,Options)->
    Map0=?CdrTemplate#{caller:=Caller,callee:=Callee},
    case get_virtual_caller_callee(Caller,Callee) of
        {Caller1,Callee1}->
            %io:format("call_mgr.erl Caller,Callee,Caller1,Callee1:~p~n",[{Caller,Callee,Caller1,Callee1}]),
            Map1=Map0#{newcaller:=Caller1,newcallee:=Callee1},
            case call_tp(Caller1,Callee1,Origin,SDP,OpPid,Options) of
            Res_={ok,TpPid}-> 
                %traffic:add_call({Caller,Callee,OpPid,TpPid,Caller1,Callee1}),
                traffic:add_call(OpPid,maps:merge(Map1,get_cdr_data_from(Callee))),
                Res_;
            Res_={failed,Reason}->
                traffic:add_traffic(#traffic_item{caller=Caller,callee=Callee,newcaller=Caller1,newcallee=Callee1,status=list_to_atom(Reason)}),
                traffic:add_cdr(maps:merge(Map1,get_cdr_data_from(Callee))),
                Res_
            end;
        call_failed-> 
            Reason=?VirtualNumErr,
            traffic:add_traffic(#traffic_item{caller=Caller,callee=Callee,status=call_failed}),
            traffic:add_cdr(maps:merge(Map0#{reason:=Reason},get_cdr_data_from(Callee))),
            {failed,Reason}
    end;
%sip_incoming("anonymous",Callee,_,_SDP,_OpPid,_SM)->
%    utility:log("traffic.log","~p ~p ~p ~p",["anonymous",Callee,"prohibited",utility:ts()]),
%    {failed,"anonymous limitted"};
sip_incoming(Caller,"*0086"++Phone,Origin=#siporigin{},SDP,OpPid,_SM,Headers)->
    call_tp(Caller,"000999180086"++Phone,Origin,SDP,OpPid,Headers);
sip_incoming(Caller,Callee,Origin=#siporigin{},SDP,OpPid,_SM,Headers)->
    call_tp(Caller,Callee,Origin,SDP,OpPid,Headers).
    
call_tp(Caller,Callee,SipOrigin,SDP,OpPid,Headers)-> call_tp(Caller,Callee,SipOrigin,SDP,OpPid,dbmanager:is_need_antispy(),Headers).
call_tp(Caller,Callee,SipOrigin,SDP,OpPid,false,Headers)->
    %io:format("^"),
    Options=[{phone,Callee},{uuid,{"noantispy",Caller}},{cid,Caller},{siporigin,SipOrigin},{max_time,120*60*1000}]++Headers,
    TpPid=sip_tp:start_with_sdp(OpPid,Options,SDP),
    {ok,TpPid};
call_tp("anonymous",Callee,_SipOrigin,_SDP,_OpPid,true,_)->
    utility:log("traffic.log","~p ~p ~p ~p",["anonymous",Callee,"prohibited",utility:ts()]),
    {failed,?AnonymousLimited};
call_tp(Caller,Callee,SipOrigin,SDP,OpPid,true,Headers)->
    Act=fun(ST=#st{callers=Callers})->
%            io:format("sip_incoming callers:~p~n",[Callers]),
            case lists:keyfind(Caller,#call_t.caller,Callers) of
            false->
                io:format("."),
                Options=[{phone,Callee},{uuid,{"sipantispy",Caller}},{cid,Caller},{siporigin,SipOrigin}]++Headers,
                TpPid=sip_tp:start_with_sdp(OpPid,Options,SDP),
                erlang:monitor(process,OpPid),
                {{ok,TpPid},ST#st{callers=[#call_t{caller=Caller,callee=Callee,oppid=OpPid,tppid=TpPid}|Callers]}};
            OldCall=#call_t{}->
                spy_traffic(Caller,Callee,OldCall),
  %              io:format("########################################"),
                {{failed,?DuplicatCall},ST}
            end
          end,
    act(Act).

enter_talking(OpPid)->
    Act=fun(ST=#st{callers=Callers})->
            case lists:keyfind(OpPid,#call_t.oppid,Callers) of
            CallItem=#call_t{}->
                NCallers=lists:keyreplace(OpPid,#call_t.oppid,Callers,CallItem#call_t{starttime=utility:ts()}),
                {ok,ST#st{callers=NCallers}};
            _->
                {no_item,ST}
            end
          end,
    act(Act).

get_traffic()->
    Act=fun(ST=#st{interval_stats=Traffic})-> {Traffic,ST} end,
    act(Act).
show()->
    Act=fun(ST)-> {ST,ST} end,
    act(Act).
% callback for my_server
init([]) ->     
    %my_timer:send_interval(?STAT_INTERVAL, stats),
    {ok,#st{}}.

handle_info(stats,State=#st{interval_stats=Traffic=#traffic_t{items=Items}})->
     ?DB_WRITE(Traffic#traffic_t{items=lists:reverse(Items)}),
    {noreply,State#st{interval_stats=#traffic_t{}}};
handle_info({'DOWN',_,process,Pid,_},State=#st{callers=Callers})->
    {value,CallItem,NCallers} =lists:keytake(Pid,#call_t.oppid,Callers),
    io:format("x"),
    traffic(CallItem),
    {noreply,State#st{callers=NCallers}};
handle_info(Msg,State)-> 
    io:format("unhandled msg:~p~n",[Msg]),
    {noreply,State}.
handle_call({act,Act},_Frome, ST=#st{}) ->
    {Res,NST}=Act(ST),
    {reply,Res,NST}.
handle_cast({act,Act}, ST) ->
    {_,NST}=Act(ST),
    {noreply,NST};
handle_cast(stop, ST) ->
    {stop,normal,ST}.
terminate(R,_St=#st{callers=Callers})->  
    io:format("call_mgr terminate reason:~p~n",[R]),
    [sip_op:stop(OpPid)||#call_t{oppid=OpPid}<-Callers],
    stop.

% my utility function
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

% my log functiong
spy_traffic(Caller,Callee,#call_t{callee=Callee0,starttime=StartTime})->
    utility:log("spy.log","~p ~p ~p ~p ~p",[utility:ts(),Caller,Callee,Callee0,StartTime]).
traffic(#call_t{caller=Caller,callee=Callee,starttime=StartTime})->
    utility:log("traffic.log","~p ~p ~p",[Caller,Callee,StartTime]);
traffic(_)-> void.


test_caller_callee()->
    sip_virtual:add_a_x("a","x"),
    sip_virtual:bind_b("b","a",undefined,dual),
    {"x","b"}= get_virtual_caller_callee("a","x",undefined),
    {"x","a"}= get_virtual_caller_callee("b","x",undefined),
    sip_virtual:unbind_b("x",undefined,single),
    sip_virtual:unbind_b("x",undefined,dual),


     ok.
