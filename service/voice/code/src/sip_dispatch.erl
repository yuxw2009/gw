-module(sip_dispatch).
-compile(export_all).
-record(call_t,{callid,sipnode,ssip,ssport,localip,localport}).
-define(SIPNODES,['sip@10.32.3.234','sip@10.32.3.235','sip@10.32.3.236']).
-record(st,{nodeinfos=[{N,0}||N<-?SIPNODES],call_ts=[],other=[]}).
-include("virtual.hrl").
-include("db_op.hrl").
-include("call.hrl").

start()->
    case whereis(?MODULE) of
    undefined->    
        {ok,Pid}=my_server:start({local,?MODULE}, ?MODULE,[get_sip_nodes()],[]),
        Pid;
    P-> P
    end.

get_sip_nodes()->
    Node=node(),
    case mnesia:dirty_index_read(sip_nic_t,Node,#sip_nic_t.node) of
    [#sip_nic_t{nodes=Nodes}|_]->  
        Nodes;
    _->[]
    end.
show()->
    Act=fun(ST)-> {ST,ST} end,
    act(Act).
% callback for my_server
init([SipNodes]) ->     
    {ok,#st{nodeinfos=[{N,0}||N<-SipNodes]}}.

handle_info(refresh_sip_nodes,State=#st{})->
    {noreply,State#st{nodeinfos=[{N,0}||N<-get_sip_nodes()]}};
handle_info({add_sip_node,_Node},State=#st{})->
    {noreply,State#st{}};
handle_info({send_first_invite,CallId,SipNode},State=#st{call_ts=Calls,nodeinfos=Nodes})->
     logger:log(normal, "sip_dispatch:send_first_invite call-id ~s  SipNode:~p~n", [CallId, SipNode]),
    case lists:keyfind(CallId,#call_t.callid,Calls) of
    false->    
        F=fun({SipNode_,N})->   {SipNode_,N+1};
                 (Other)->  Other
             end,
        NewNodes=lists:map(F,Nodes),
    
        Call_t=#call_t{callid=CallId,sipnode=SipNode},
        {noreply,State#st{nodeinfos=NewNodes,call_ts=[Call_t|Calls]}};
    #call_t{sipnode=SipNode}->
        io:format("************************************************unbelievable~n"),
        %assert(false),
        {noreply,State}
    end;

handle_info({dispatch,Packet,Origin},State=#st{call_ts=_Calls,nodeinfos=Nodeinfos})->
    {FirstLine,{CallId,From}}=sippacket:parse_call_id(Packet),
    Summary= case Packet of
                     <<TT:20/binary,_/binary>> -> TT;
                     P_-> P_
                     end,
     logger:log(normal, "sip_dispatch: call-id ~s  rec:~p from:~p~n", [CallId, Summary,From]),
    case ?DB_READ(callid2node_t,CallId) of
    {atomic,[#callid2node_t{sipnode=SipNode_}]}->    
        rpc:call(SipNode_,sipserver,async_process,[Packet, Origin]),
        {noreply,State};
    _->
        case get_a_available_node(Nodeinfos) of
        {false,_}-> 
            sipserver:async_process(Packet,Origin),
            logger:log(error, "no available nodes,dispatch to local nic node"),
            {noreply,State};
        {{Node,Num},T}->
            NewNodes=if Num>10-> T++[{Node,0}]; true-> [{Node,Num+1}|T] end,
            rpc:call(Node,sipserver,async_process,[Packet, Origin]),
            case FirstLine of
            {request, {"INVITE", _URI}}->
                {noreply,State#st{nodeinfos=NewNodes}};
            _->
                {noreply,State}
            end
        end
    end;
handle_info({dispatch0,Packet,Origin},State=#st{call_ts=Calls,nodeinfos=[{Node,Num}|T]})->
    {FirstLine,{CallId,_}}=sippacket:parse_call_id(Packet),
    case lists:keyfind(CallId,#call_t.callid,Calls) of
    false->    
        NewNodes=lists:keysort(2,[{Node,Num+1}|T]),
        rpc:call(Node,sipserver,async_process,[Packet, Origin]),
        case FirstLine of
        {request, {"INVITE", _URI}}->
            Call_t=#call_t{callid=CallId,sipnode=Node},
            {noreply,State#st{nodeinfos=NewNodes,call_ts=[Call_t|Calls]}};
        _->
            {noreply,State}
        end;
    #call_t{sipnode=SipNode_}->
        rpc:call(SipNode_,sipserver,async_process,[Packet, Origin]),
        {noreply,State}
    end;

handle_info({close,CallId},State=#st{call_ts=Callers,nodeinfos=Nodes})->
    io:format("11111 callid ~p down!orginal nums:~p~n",[CallId,length(Callers)]),
    {value,CallItem=#call_t{sipnode=_SipNode},NCallers} =lists:keytake(CallId,#call_t.callid,Callers),
    io:format("22222 callid ~p down! ~p orginal nums:~p new nums:~p~n",[CallId,CallItem,length(Callers),length(NCallers)]),
    F=fun({SipNode_,N})->   {SipNode_,max(0,N-1)};
             (Other)->  Other
         end,
    NewNodes=lists:map(F,Nodes),
    {noreply,State#st{call_ts=NCallers,nodeinfos=NewNodes}};
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
terminate(R,_St=#st{})->  
    io:format("call_mgr terminate reason:~p~n",[R]),
    stop.

get_a_available_node(Nodeinfos)-> get_a_available_node(Nodeinfos,[node()|nodes()],[]).
get_a_available_node([],_,DownNodes)-> {false,DownNodes};
get_a_available_node([Head={Node,_}|T],Nodes,DownNodes)->
    case lists:member(Node,Nodes) of
    true->  {Head,T++DownNodes};
    false-> get_a_available_node(T,Nodes,DownNodes)
    end.
% my utility function
act(Act)->    act(whereis(?MODULE),Act).
act(Pid,Act)->    my_server:call(Pid,{act,Act}).

asyn_process(Packet, Origin)  ->
    ?MODULE ! {dispatch,Packet,Origin}.
sip_dispatch_test()->
    ok.
