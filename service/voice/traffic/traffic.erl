-module(traffic).
-compile(export_all).
-include("traffic.hrl").
-record(state,{uuid2trf=[]}).
-include("db_op.hrl").
-define(PAGE_NUM,30).
%% APIs
init_once() ->
    mnesia:create_schema([node()]),
    create_tables().

create_tables()->    
    mnesia:start(),
    mnesia:create_table(traffic, [{disc_copies,[node()]},
	                           {attributes, record_info(fields, traffic)}]),	
    mnesia:create_table(id_table, [{disc_copies,[node()]},
	                               {attributes, record_info(fields, id_table)}]),	
    mnesia:create_table(uuid2ids, [{disc_copies,[node()]},
	                               {attributes, record_info(fields, uuid2ids)}]),	
    ok.
create_table1()->
    mnesia:start(),
    mnesia:create_table(traffic1, [{disc_copies,[node()]},
                               {attributes, record_info(fields, traffic1)}]).

start() ->
    my_server:start({local,?MODULE},?MODULE,[],[]).

add(Pls)->
    Id=trffic_id(),
    UUID=proplists:get_value(uuid,Pls),
    Caller=proplists:get_value(caller,Pls,""),
    Callee=proplists:get_value(callee,Pls,""),
%    SipCaller=proplists:get_value(sip_caller,Pls),
%    SipCallee=proplists:get_value(sip_callee,Pls),
%    Calltime=proplists:get_value(calltime,Pls,""),
    Talktime=proplists:get_value(talktime,Pls),
    Endtime=proplists:get_value(endtime,Pls),
    SockIp=proplists:get_value(socket_ip,Pls),
    Caller_sip=proplists:get_value(caller_sip,Pls),
    Callee_sip=proplists:get_value(callee_sip,Pls),
    Direcion=proplists:get_value(direction,Pls,outgoing),
    case ?DB_READ(uuid2ids,UUID) of
    	{atomic,[UUID2Ids=#uuid2ids{ids=Ids}]}->
    	    ?DB_WRITE(UUID2Ids#uuid2ids{uuid=UUID,ids=[Id|Ids]});
    	_->?DB_WRITE(#uuid2ids{uuid=UUID,ids=[Id]})
    end,
    ?DB_WRITE(#traffic1{id=Id,uuid=UUID,caller=Caller,callee=Callee,talktime=Talktime,
    	 endtime=Endtime,socket_ip=SockIp,caller_sip=Caller_sip,callee_sip=Callee_sip,direction=Direcion}).

get_recent_traffic(UUID)-> get_recent_traffic(UUID,0).
get_recent_traffic(UUID,StartId)->
    R=get_page_by_uuid(UUID,StartId),
    handle_traffics(R).

get_by_uuid(UUID={_GroupId,_Uuid})-> get_by_uuid(UUID,0).
get_by_uuid(UUID={_GroupId,_Uuid},StartId)->
    case ?DB_READ(uuid2ids,UUID) of
    	{atomic,[#uuid2ids{ids=Ids}]}->
    	    ?DB_OP(qlc:e(qlc:q([X||Id<-Ids,X<-mnesia:table(traffic1),X#traffic1.id==Id,Id>StartId,X#traffic1.caller=/= undefined])));
    	_-> []
    end.
get_page_by_uuid(UUID)->get_page_by_uuid(UUID,0).    

get_page_by_uuid(UUID,StartId)->
    case ?DB_READ(uuid2ids,UUID) of
    	{atomic,[#uuid2ids{ids=Ids}]}-> 
            Ids1= if length(Ids)>?PAGE_NUM-> {Items,_}=lists:split(?PAGE_NUM,Ids),Items; true-> Ids end,
            Ids2=[X||{X,_date}<-Ids1,X>StartId],
            Ids3=[X||X<-Ids1,X>StartId],
    	    get_page_by_uuid(Ids2++Ids3,0,[]);%[||#traffic{caller=Caller}<-Trfs];
    	_-> []
    end.

get_page_by_uuid([],_,R)-> R;
get_page_by_uuid(_,N,R) when N>?PAGE_NUM-> R;
get_page_by_uuid([Id|Rest],N,R) when is_integer(Id)-> 
    case ?DB_READ(traffic1,Id) of
    {atomic,[Head=#traffic1{callee=Callee}]}-> 
%    SameCallees=[Itm||Itm=#traffic1{callee=C}<-Rest, C==Callee],
%    Rest1=Rest--SameCallees,
        Value0=proplists:get_value(Callee,R,[]),
        get_page_by_uuid(Rest,N+1,lists:keystore(Callee,1,R,{Callee,[Head|Value0]}));
    _-> get_page_by_uuid(Rest,N,R)
    end.

handle_traffics(R)-> handle_traffics(R,[]).
handle_traffics([],R)->utility:pl2jsos(lists:reverse(R));
handle_traffics([Head|Rest],Res)->
    Itm=handle_traffic(Head),
    handle_traffics(Rest,[Itm|Res]).

handle_traffic([])-> [];
handle_traffic({_Callee,All0})->
    All=lists:reverse(All0),
    [#traffic1{id=Id,endtime=EndT,callee=Callee0,caller=Caller0}|_] = All,
    LastTime=list_to_binary(utility:d2s(EndT)),
    Caller=if is_list(Caller0)-> list_to_binary(Caller0); true-> <<"">> end,
    Callee=if is_list(Callee0)-> list_to_binary(Callee0); true-> <<"">> end,
    Info=[{id,Id},{caller,Caller},{callee,Callee},{lasttime,LastTime},{times,length(All)}],
    handle_traffic(All,Info,[]).

handle_traffic([],Info,Details)->  Info++[{details,utility:pl2jsos_br(lists:reverse(Details))}];
handle_traffic([#traffic1{talktime=Ttime,endtime=Etime,direction=Direction}|Rest],Info,Res)->
    {Starttime,Dura}=if Ttime==undefined orelse Ttime==[]-> {Etime,0}; true-> 
                {D,{H,M,S}} =calendar:time_difference(Ttime,Etime),
                {Ttime,D*24*60*60+H*60*60+M*60+S}
        end,
    TimeStr=list_to_binary(utility:d2s(Starttime)),
    handle_traffic(Rest,Info,[[{starttime,TimeStr},{duration,Dura},{direction,Direction}]|Res]).

get_all()->
    ?DB_QUERY(traffic1).
%% callbacks
init([]) ->
    {ok,#state{}}.
	
	
handle_call(_Call, _From, State) ->
    {noreply,State}.
handle_cast(_Msg, State) ->
    {noreply, State}.
handle_info(_Msg,State) ->
    {noreply, State}.

terminate(_Reason, _State) -> 
    ok.	

trffic_id()-> mnesia:dirty_update_counter(id_table, traffic, 1).    


transform_tables()->  %% for mnesia database updating, very good 
    Transformer = fun(Itm0=#traffic{},_)->
                     Itm1=setelement(1, Itm0, traffic1),
                     Itm2=erlang:append_element(Itm1,outgoing),
                     Item3=erlang:append_element(Itm2,[]),
                     mnesia:write(Item3),
                     Item3
                     end,
    Fun= fun()-> mnesia:foldl(Transformer,[],traffic) end,
    mnesia:transaction(Fun).
    
