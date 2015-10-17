-module(config).
-compile(export_all).
-include("db_op.hrl").
-record(config,{key=active,value=false}).
-record(xm_acc,{phone,imsi,sim_id,sec,token}).
-record(fetion_acc,{phone,pwd,deviceid}).
-record(xmphones,{phone,sim_id}).  %sim_id就是xmid，就是user_id
-record(xm_month_num,{month=month_key(),sendnum=0,acknum=0}).

active()-> get_active().

month_key()->
    {Y,M,_}=date(),
    {Y,M}.

init()->
    mnesia:create_table(fetion_acc,[{attributes,record_info(fields,fetion_acc)},{disc_copies,[node()]}]),
    mnesia:create_table(xm_month_num,[{attributes,record_info(fields,xm_month_num)},{disc_copies,[node()]}]),
    mnesia:create_table(xmphones,[{attributes,record_info(fields,xmphones)},{disc_copies,[node()]}]),
    mnesia:create_table(xm_acc,[{attributes,record_info(fields,xm_acc)},{disc_copies,[node()]}]),
    mnesia:create_table(config,[{attributes,record_info(fields,config)},{disc_copies,[node()]}]).
set_active(V)->
    mnesia:dirty_write(#config{value=V}).

get_active()   ->
    case mnesia:dirty_read(config,active) of
    	[#config{value=R}]-> R;
    	_-> false
    end.

disable_after(N)->
    timer:apply_after(N,?MODULE,set_active,[false]).

enable_after(N)->
    timer:apply_after(N,?MODULE,set_active,[true]).    

set_active(Service,Status)-> mnesia:dirty_write(#config{key=Service,value=Status}).
get_active(Service)   ->
    case mnesia:dirty_read(config,Service) of
    	[#config{value=R}]-> R;
    	_-> false
    end.

xm_accs1([])-> void;
xm_accs1([[Imsi,Sim_id,Phone,Sec,Token]|T])->
    mnesia:write(#xm_acc{phone=Phone,imsi=Imsi,sim_id=Sim_id,sec=Sec,token=Token}),
    xm_accs1(T).
xm_accs(Accs)->
    mnesia:transaction(fun()-> (xm_accs1(Accs))  end).
get_xm_userid_by_phone(Phone)->
    case ?DB_READ(xm_acc,Phone) of
        {atomic,[#xm_acc{sim_id=SimId}]}->{ok,SimId};
        _-> undefined
    end.
    
get_xm_params_by_phone(Phone)->
    case ?DB_READ(xm_acc,Phone) of
        {atomic,[#xm_acc{phone=Phone,imsi=Imsi,sim_id=Sim_id,sec=Sec,token=Token}]}->{ok,[Imsi,Sim_id,Phone,Sec,Token]};
        _-> undefined
    end.

xmphones(ParamsList)->
    F0 = fun(Params)->
            Phone=proplists:get_value("phone",Params),
            Xmid=proplists:get_value("xmid",Params),
            mnesia:write(#xmphones{phone=Phone,sim_id=Xmid})
        end,
    F1=fun()-> [F0(I)||I<-ParamsList] end,
    mnesia:transaction(F1).

xm_month_num(SendNums,AckNums)->
    MK=month_key(),
    case ?DB_READ(xm_month_num,MK) of
        {atomic,[XmMonth=#xm_month_num{sendnum=SN0,acknum=AN0}]}->
            ?DB_WRITE(XmMonth#xm_month_num{sendnum=SN0+SendNums,acknum=AN0+AckNums});
        _->
            ?DB_WRITE(#xm_month_num{month=MK,sendnum=SendNums,acknum=AckNums})
    end.

fetion_acc(Phone,Pwd,DevId)-> ?DB_WRITE(#fetion_acc{phone=Phone,pwd=Pwd,deviceid=DevId}).

get_xm_month_num(Mon={_Y,_M})->  mnesia:dirty_read(xm_month_num,Mon).
