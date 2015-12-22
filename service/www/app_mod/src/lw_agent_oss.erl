-module(lw_agent_oss).
-compile(export_all).
-include("lwdb.hrl").
-include("db_op.hrl").

% from boss oam
create_sdn(Pls)->
    Sdn = proplists:get_value(sdn1,Pls),
    Das = proplists:get_value(das,Pls),
    ServNo=das2service_no(Das),
    case {Sdn,?DB_READ(agent_oss_item,Sdn)} of
    {undefined, _}->  [{"RETN","1"},{"DESC","sdn empty"}];
    {_,{atomic,[Item=#agent_oss_item{pls=Pls}]}}-> 
        ?DB_WRITE(Item#agent_oss_item{pls=lists:keystore(service_no,1, Pls,{service_no,ServNo})}),
        [{"RETN","0"}];
    _->
        SipItem=#agent_oss_item{sipdn=Sdn,pls=[{service_no,ServNo}]},
        ?DB_WRITE(SipItem),
        [{"RETN","0"}]
    end.
bind_sipdn(Pls)->
    Sdn = proplists:get_value(sdn,Pls),
    AuthCode = proplists:get_value(password,Pls),
    case {Sdn,?DB_READ(agent_oss_item,Sdn)} of
    {undefined, _}->  [{"RETN","1"},{"DESC","sdn empty"}];
    {_,{atomic,[Item]}}-> 
        ?DB_WRITE(Item#agent_oss_item{authcode=AuthCode}),
        [{"RETN","0"}];
    _->
        SipItem=#agent_oss_item{sipdn=Sdn,authcode=AuthCode},
        ?DB_WRITE(SipItem),
        [{"RETN","0"}]
    end.
test_bind(Phone,Pass)-> bind_sipdn([{sdn,Phone},{password,Pass}]).
unbind_sipdn(Pls)->
    Sdn = proplists:get_value(sdn1,Pls),
    case ?DB_READ(agent_oss_item,Sdn) of
    {atomic,[#agent_oss_item{}]}-> 
        lw_register:deregister(Sdn),
        ?DB_DELETE({agent_oss_item,Sdn}),
        [{"RETN","0"}];
    _->
        [{"RETN","1"},{"DESC","sipdn not binded"}]
    end.

modify_sub_attr(Pls)->    
    Sdn = proplists:get_value(sdn1,Pls),
    Status=
        case proplists:get_value(notinuse,Pls) of
        1-> ?UNACTIVED_STATUS;
        _-> ?ACTIVED_STATUS
        end,
    case ?DB_READ(agent_oss_item,Sdn) of
    {atomic,[Item=#agent_oss_item{}]}-> 
        login_processor:set_status(Sdn,Status),
        ?DB_WRITE(Item#agent_oss_item{status=Status}),
        [{"RETN","0"}];
    _->
        [{"RETN","1"},{"DESC","sipdn not binded"}]
    end.
test_modify(Phone,NotInuse)->     modify_sub_attr([{sdn,Phone},{notinuse,NotInuse}]).
test_create_did(Sdn,Did)-> create_did([{num,Sdn},{subnum,Did}]).
create_did(Pls)->
    Sdn = proplists:get_value(num,Pls),
    Did = proplists:get_value(subnum,Pls),
    case ?DB_READ(agent_did2sip,Did) of
    {atomic,[]}->
        lw_register:set_didno(Sdn, Did),
        ?DB_WRITE(#agent_did2sip{did=Did,sipdn=Sdn}),
        case ?DB_READ(agent_oss_item,Sdn) of
        {atomic,[Item=#agent_oss_item{}]}-> 
            ?DB_WRITE(Item#agent_oss_item{did=Did}),
            [{"RETN","0"}];
        _->
            
            [{"RETN","0"},{"DESC","sipdn not binded"}]
        end;
    {atomic,[DidItem=#agent_did2sip{}]}->
        [{"RETN","1"},{"DESC","did number already existed"}]
    end.
query_did_item(Did)->
    case ?DB_READ(agent_did2sip,Did) of
    {atomic,[Item]}->  Item;
    _-> undefined
    end.
    
test_destroy_did(Did)-> destroy_did([{subnum,Did}]).
destroy_did(Pls)->
    Did = proplists:get_value(subnum,Pls),
    case ?DB_READ(agent_did2sip,Did) of
    {atomic,[]}->void;
    {atomic,[DidItem=#agent_did2sip{sipdn=Sdn}]}->
        case ?DB_READ(agent_oss_item,Sdn) of
        {atomic,[Item=#agent_oss_item{}]}-> 
            lw_register:set_didno(Sdn, undefined),
            ?DB_WRITE(Item#agent_oss_item{did=undefined});
        _-> void
        end,
        ?DB_DELETE({agent_did2sip,Did})
    end,
    [{"RETN","0"}].
    
% for user app
authenticate(Sdn,AuthCode)->
    case ?DB_READ(agent_oss_item,Sdn) of
    {atomic,[#agent_oss_item{authcode=AuthCode,status=Status}]}-> 
        {ok,Status};
    _->
        failed
    end.

get_item(Phone)-> 
    io:format("get_item :~p~n",[Phone]),
    get_item1(Phone).
get_item1(Phone) when is_binary(Phone)-> get_item1(binary_to_list(Phone));
get_item1(Phone)-> 
    case ?DB_READ(agent_oss_item,Phone) of
        {atomic,[I]}-> I;
        _-> undefined
    end.

das2service_no(Das)->
    case Das rem 100 of
    I when I<10 -> "0"++integer_to_list(I);
    O-> integer_to_list(O)
    end.

