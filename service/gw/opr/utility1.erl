-module(utility1).
-compile(export_all).
-include("yaws_api.hrl").

decode_json(Json, Spec)  when Json== <<>> orelse Json=="" ->
    decode({obj,[]}, Spec, []);
decode_json(Json, Spec) ->
    decode(Json, Spec, []).

decode(Bytes, Spec) ->
    {ok, Json, _} = rfc4627:decode(Bytes), 
    decode(Json, Spec, []).

decode(_Json, [], Acc) -> list_to_tuple(lists:reverse(Acc));
decode(Json, [{Name,Type}|Rest], Acc) ->
    StrName = atom_to_list(Name),
    case Type of
        r -> decode(Json, Rest, [get(Json, StrName)|Acc]);
        i -> decode(Json, Rest, [get_integer(Json, StrName)|Acc]);
        b  -> decode(Json, Rest, [get_binary(Json, StrName)|Acc]);
        s  -> decode(Json, Rest, [get_string(Json, StrName)|Acc]);
        a    -> decode(Json, Rest, [get_atom(Json, StrName)|Acc]);
        ai -> decode(Json, Rest, [get_array_integer(Json, StrName)|Acc]);
        as  -> decode(Json, Rest, [get_array(Json, StrName)|Acc]);
        aa    -> decode(Json, Rest, [get_array_atom(Json, StrName)|Acc]);
        ab  -> decode(Json, Rest, [get_array_binary(Json, StrName)|Acc])
    end;

decode(Json, [{Name,o, Spec}|Rest], Acc) ->
    StrName = atom_to_list(Name),
    decode(Json, Rest, [decode(get(Json, StrName), Spec, [])|Acc]);

decode(Json, [{Name,ao, Spec}|Rest], Acc) ->
    StrName = atom_to_list(Name),
    decode(Json, Rest, [get_array_object(Json, StrName, Spec)|Acc]).

get_array_object(JsonObj, Key, Spec) ->
    [decode(I, Spec, []) || I<-get(JsonObj, Key)].

get(JsonObj, Key) ->
     rfc4627:get_field(JsonObj, Key,undefined).

get_value(JsonObj, Key) ->
    case rfc4627:get_field(JsonObj, Key,undefined) of
    undefined-> undefined;
    Value-> value2list(Value)
    end.

value2list(V) when is_float(V) -> lists:flatten(io_lib:format("~p",[V]));
value2list(V) when is_integer(V) -> integer_to_list(V);
value2list(V) when is_list(V) -> V;
value2list(V) when is_atom(V) -> atom_to_list(V);
value2list(V) when is_binary(V) -> binary_to_list(V).

value2binary(V)->
    list_to_binary(?MODULE:value2list(V)).

get_binary(JsonObj, Key) ->
    get(JsonObj, Key).

get_array(JsonObj, Key) ->
    Value=rfc4627:get_field(JsonObj, Key),
    [value2list(I) || I<-Value].

get_array_integer(JsonObj, Key) ->
    Value = rfc4627:get_field(JsonObj, Key),
    [list_to_integer(value2list(I)) || I<-Value].

get_array_atom(JsonObj, Key) ->
    Value = rfc4627:get_field(JsonObj, Key),
    [atom(value2list(I)) || I<-Value].

get_array_binary(JsonObj, Key) ->
    Value = rfc4627:get_field(JsonObj, Key),
    [value2binary(I) || I<-Value].

get_integer(JsonObj, Key) ->
    R=get_string(JsonObj, Key),
   if is_list(R)->  list_to_integer(R); true-> R end.

get_atom(JsonObj, Key) ->
    atom(get_string(JsonObj, Key)).

get_string(JsonObj, Key) ->
    get_value(JsonObj, Key).
    
atom(A) when is_atom(A)-> A;
atom(A) ->
    case (catch list_to_existing_atom(A)) of
      {'EXIT',_} ->
        list_to_atom(A);
    S  ->
        S
  end.

decode(Json) ->
    {ok, Notify, _} = rfc4627:decode(Json),
    {obj, [{"uuid", UUID}, {"notify", Objs}]} = Notify,
    {list_to_integer(binary_to_list(UUID)), [o2pl(O) || O<-Objs]}.    

tag_trans(Tag, Value) ->
    case tag_spec(Tag) of
        ints   -> {Tag, [list_to_integer(binary_to_list(V)) || V <- Value]};
        int    -> {Tag, list_to_integer(binary_to_list(Value))};
        atom   -> {Tag, atom(binary_to_list(Value))};
        objs   ->
            {Tag, [o2pl(V) || V<-Value]};
        pass -> {Tag, Value}
    end.

tag_spec(friend_ids)  -> ints;
tag_spec(new_members) -> ints;
tag_spec(members)     -> objs;

tag_spec(peer_id)    -> int;
tag_spec(group_id)    -> int;
tag_spec(session_id)  -> int;
tag_spec(inviter_id)  -> int;
tag_spec(invitee_id) -> int;
tag_spec(member_id)  -> int;
tag_spec(to_group_id)   -> int;
tag_spec(from_group_id) -> int;
tag_spec(host_id)    -> int;
tag_spec(position)    -> int;
tag_spec(guest_id)    -> int;
tag_spec(uuid)    -> int;
tag_spec(invitee)    -> int;

tag_spec(friend_add) -> atom;
tag_spec(action)     -> atom;
tag_spec(type)       -> atom;
tag_spec(media_type) -> atom;
tag_spec(attr_name)  -> atom;

tag_spec(_)          -> pass.


encode(PLS) ->
    rfc4627:encode([pl2jso(pl_trans(PL,[])) || PL <- PLS]).

pl_trans([], Acc) -> lists:reverse(Acc);
pl_trans([{Tag,Value}|T], Acc) when is_list(Value) -> 
    case Value of
        [{_,_}|_] -> 
            pl_trans(T, [{Tag,{obj,pl_trans(Value, [])}}|Acc]);
        [NL|_] when is_list(NL) -> 
            J = [{obj, I}|| I<-Value],
            pl_trans(T, [{Tag, J}|Acc]);
        _ -> 
            pl_trans(T, [{Tag,Value}|Acc])
    end;
pl_trans([{Tag,Value}|T], Acc) -> pl_trans(T, [{Tag,Value}|Acc]).

f2b(F,N)->list_to_binary(f2s(F,N)).
f2s(F) ->
    f2s(F,2).
f2s(F0,N) ->
    F=float_n(F0,N),
    N_bin=list_to_binary(integer_to_list(N)),
    [V] = io_lib:format(<<"~.",N_bin/binary,"f">>, [F*1.0]),
    V.
a()-> a.    


%%  utility tools

reload()-> reload(?MODULE).
reload(MODS)->
    make:all(),
    F= fun(I)-> 
        code:purge(I),
        code:load_file(I)
    end,
    MODS1 = case MODS of
            _ when is_list(MODS)->  MODS;
            _ when is_atom(MODS)-> [MODS]
        end,
    [F(I) || I<-MODS1].    
    
pls_f2b(Pls)->pls_f2b(Pls,1).
pls_f2b(Pls,N)->
    [{K, if is_float(V)-> f2b(V,N); true-> V end}||{K,V}<-Pls].   
%% [{a,1},{b,2}] => {obj, [{a,1}, {b,2}]} 
pl2jso(PL=[{obj,_}|_]) ->PL;
pl2jso(PList) ->
    pl2jso([], PList).

pl2jso(Trans, PList) ->
    {obj, lists:foldl(fun({Tag, Value}, Acc) ->
                          NewValue = case proplists:get_value(Tag, Trans) of
                                         undefined -> Value;
                                         TF        -> TF(Value)
                                     end,
                          Acc ++ [{Tag, NewValue}]
                      end,
                      [], PList)}.

%% [a, b], [1,2] => {obj, [{a,1}, {b,2}]}
a2jso(Tags, Values) when is_tuple(Values) ->
    a2jso(Tags, tuple_to_list(Values));    
a2jso(Tags, Values) ->
    PList = lists:zip(Tags, Values),
    {obj, lists:foldl(fun({{Tag, TF}, Value}, Acc) -> Acc ++ [{Tag, TF(Value)}];
                         ({Tag, Value}, Acc)       -> Acc ++ [{Tag, Value}]
                      end,    
                      [], PList)}.

%% [[{a,1},{b,2}],[{a,3},{b,4}]] => [{obj, [{a, 1}, {b, 2}]}, {obj, [{a, 3}, {b, 4}]}]
pl2jsos_br(PLists) ->
    [pl2jso_br(I) || I<- PLists].
pl2jsos(PLists) ->
    [pl2jso(I) || I<- PLists].

pl2jsos(Trans, PLists) ->
    [pl2jso(Trans, I) || I<- PLists].

%% {a,b}, [{1,2}, {3,4}] => [{obj, [{a, 1}, {b, 2}]}, {obj, [{a, 3}, {b, 4}]}]
a2jsos(Tags, VLists) ->
    [a2jso(Tags, I) || I<- VLists].
pl2jso_r(Pls)-> pl2jso_r(Pls,[]).
pl2jso_r([],R)->pl2jso(lists:reverse(R));
pl2jso_r([{K,V=[{_,_}|_]}|T], R) when K=/=obj -> pl2jso_r(T, [{K,pl2jso_r(V)}|R]);
pl2jso_r([H|T], R)-> pl2jso_r(T, [H|R]).

v2b_r(Pls)->    v2b_r(Pls,[]).
v2b_r([],R)-> lists:reverse(R);
v2b_r([{obj,V}|T],R) -> v2b_r(T,[{obj,V}|R]);
v2b_r([{K,V}|T],R) when is_list(V)-> 
    case is_string(V) of
        true-> v2b_r(T, [{K,list_to_binary(V)}|R]);
        false-> v2b_r(T,[{K,v2b_r(V)}|R])
    end;
v2b_r([H|T],R)-> v2b_r(T, [H|R]).

pl2jso_br(Result)->
    ?MODULE:pl2jso_r(?MODULE:v2b_r(Result)).
%%    
o2pl({obj,PL}) ->
    o2pl(PL, []).

o2pl([], Acc) -> Acc; 
o2pl([{Tag, {obj, PL}}|T], Acc) -> 
    o2pl(T, [{atom(Tag), o2pl(PL, [])}| Acc]);

o2pl([{Tag, Value}|T], Acc) -> 
   o2pl(T, [tag_trans(atom(Tag),Value)|Acc]).

o2map({obj,PL}) ->
    o2map(PL, []).

o2map([], Acc) -> maps:from_list(Acc); 
o2map([{Tag, {obj, PL}}|T], Acc) -> 
    o2map(T, [{Tag, o2map(PL, [])}| Acc]);

o2map([{Tag, Value}|T], Acc) -> 
   o2map(T, [{Tag,Value}|Acc]).

json2pl(Clidata)->
    {ok, Json, _} = rfc4627:decode(Clidata),
    ?MODULE:o2pl(Json).

record2pl(Fields,Rec)->
    [_|Vl]=tuple_to_list(Rec),
    lists:zip(Fields,Vl).

is_string([]) -> false;
is_string([X]) -> is_integer(X) andalso X>=0 andalso X<255;
is_string([X|T]) -> is_integer(X) andalso X>=0 andalso X<255 andalso is_string(T);
is_string(_) -> false.

term_to_binary(Rsn) when is_binary(Rsn)-> Rsn;
term_to_binary(Rsn)->
    list_to_binary(lists:flatten(io_lib:format("~p",[Rsn]))).

term_to_list(T)->
    R = io_lib:format("~p", [T]),
    lists:flatten(R).

make_ip_bin(Ip) ->
    list_to_binary(make_ip_str(Ip)).
make_ip_str({A,B,C,D}) ->
    integer_to_list(A)++"."++integer_to_list(B)++"."++integer_to_list(C)++"."++integer_to_list(D);
make_ip_str(_)-> "unknown".

merge_proplists(Pls0, Pls) when is_list(Pls0),is_list(Pls)->
    D0=dict:from_list(Pls0),
    D1=dict:from_list(Pls),
    F=fun(_k,_V1,V2)-> V2 end,
    D=dict:merge(F, D0,D1),
    lists:ukeysort(1,dict:to_list(D));
merge_proplists( Pls0,_) when is_list(Pls0)->
    Pls0;
merge_proplists(_, Pls) when is_list(Pls)->
    Pls.

fb_decode_base64(Base64) when is_binary(Base64)-> fb_decode_base64(binary_to_list(Base64)) ;
fb_decode_base64(Base64) when is_list(Base64) ->
     try base64:decode(Base64)
     catch
         error:_ -> % could be missing =
                 try base64:decode(Base64 ++ "=")
                 catch
                         error:_ -> % could be missing ==
                                 base64:decode(Base64 ++ "==")
                 end
     end.

logbin(X)->logbin(X,[]).
logbin(X,Y)-> list_to_binary(?MODULE:logstr(X,Y)).

logstr(Str, CmdList)->
    lists:flatten(io_lib:format("~s: "++Str++"~n",[d2s()|CmdList])).
log(Filename, Str, CmdList) ->
    {ok, IODev} = file:open(Filename, [append]),
    io:format(IODev,logstr(Str, CmdList),[]),
    file:close(IODev).
    
     
log(Str, CmdList) ->log("log/debug.log",Str,CmdList).
    
ts() ->
    {Y, Mo, D} = date(),
    {H, Mi, S} = time(),
    {_,_,MS}=os:timestamp(),
    xt:int2(Y) ++ "-" ++ xt:int2(Mo) ++ "-" ++ xt:int2(D) ++ " " ++ xt:int2(H) ++ ":" ++ xt:int2(Mi) ++ ":" ++ xt:int2(S)++":"++xt:int2(MS).
d2b()->list_to_binary(d2s()).
d2b(I)->list_to_binary(d2s(I)).
d2s()->d2s(erlang:localtime()).     
d2s(Date) ->d2s(Date,"-",":"," ").
d2s(Date = {_Year, _Month, _Day},DayCut,_TimeCut,_DayTimeCut) ->
    [Year0,Mon0,Day0]=[integer_to_list(I)||I<-[_Year, _Month, _Day]],
    [Mon1,Day1]=[string:copies("0",2-length(I))++I||I<-[Mon0,Day0]],
    Year0++DayCut++Mon1++DayCut++Day1;
d2s({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}},DayCut,TimeCut,DayTimeCut) ->
    [Year0,Mon0,Day0,Hour0,Min0,Sec0]=[integer_to_list(I)||I<-[_Year, _Month, _Day,_Hour, _Minute, _Second]],
    [Mon1,Day1,Hour1,Min1,Sec1]=[string:copies("0",2-length(I))++I||I<-[Mon0,Day0,Hour0,Min0,Sec0]],
    Year0++DayCut++Mon1++DayCut++Day1++DayTimeCut++Hour1++TimeCut++Min1++TimeCut++Sec1.
s2d(Date_str)-> s2d(Date_str," -:/").    
s2d(Date_str,Tokens) when is_binary(Date_str)-> s2d(binary_to_list(Date_str),Tokens);
s2d(Date_str,Tokens)->
    case string:tokens(Date_str,Tokens) of
        [Ys,Ms,Ds]-> {list_to_integer(Ys),list_to_integer(Ms),list_to_integer(Ds)};
        [Ys,Ms,Ds,Hour_s,Min_s,Sec_s]-> 
            {{list_to_integer(Ys),list_to_integer(Ms),list_to_integer(Ds)},{list_to_integer(Hour_s),list_to_integer(Min_s),list_to_integer(Sec_s)}}
    end.
bin_to_num(Bin) ->
    N = binary_to_list(Bin),
    case string:to_float(N) of
        {error,no_float} -> list_to_integer(N);
        {F,_Rest} -> F
    end.

delay(T)->
    receive
        impossible_msg_for_token->    void
    after T-> ok
    end.

get_local_ips()->
    {ok,NetDrvNames}=inet:getiflist(),
     Ls=[ inet:ifget(If, [addr, flags])||If<-NetDrvNames],
    [proplists:get_value(addr,Pls)||{_,Pls}<-Ls,lists:member(running,proplists:get_value(flags,Pls)),lists:member(broadcast,proplists:get_value(flags,Pls))].

last_date(Date)->the_date_before(Date,1).
the_date_before(Date,N)->
    Days=calendar:date_to_gregorian_days(Date),
    calendar:gregorian_days_to_date(Days-N).

jsonbin2map(Bin)->
    maps:from_list(jsonbin2plist(Bin)).
jsonbin2plist(Bin)->
    case rfc4627:decode(Bin) of
        {ok,{obj,Str2Bin_pls},_}-> Str2Bin_pls;
        _-> []
    end.    
plist2json(Pls)-> rfc4627:encode(?MODULE:pl2jso_br(Pls)).
map2jsonbin(Map)->list_to_binary(map2json(Map)).
map2json(Map)->
    rfc4627:encode(map2jso(Map)).
map2jso(Map0)->    
    Map=maps:map(fun(_,V) when is_map(V)-> map2jso(V); (_,V=[H|_]) when is_map(H)->maps2jsos(V) ; (_,V)-> V end,Map0),
    pl2jso_br(maps:to_list(Map)).
maps2jsos(Maps)->
    [map2jso(Map)||Map<-Maps].

md5(S) ->
    Md5_bin =  erlang:md5(S),
    Md5_list = binary_to_list(Md5_bin),
    lists:flatten(list_to_hex(Md5_list)).

list_to_hex(L) ->
    lists:map(fun(X) -> int_to_hex(X) end, L).

int_to_hex(N) when N < 256 ->
    [hex(N div 16), hex(N rem 16)].

timestamp_ms()->
    {MegaSecs, Secs, MicroSecs}=os:timestamp(),
    MilliSecs=integer_to_list((MegaSecs*1000000+Secs)*1000+(MicroSecs div 1000)),
    MilliSecs.

timestamp()->timestamp(erlang:localtime()).
timestamp(LocalTime)->
    calendar:datetime_to_gregorian_seconds(LocalTime)-calendar:datetime_to_gregorian_seconds({{1970,1,1},{8,0,0}}).
timestamp2localtime(Ts)->    
    calendar:gregorian_seconds_to_datetime(calendar:datetime_to_gregorian_seconds({{1970,1,1},{8,0,0}})+Ts).
hex(N) when N < 10 ->
    $0+N;
hex(N) when N >= 10, N < 16 ->
    $a + (N-10).
%%-------------------------------------------------------------
client_ip(Arg) ->
    {Ip, _Port} = Arg#arg.client_ip_port,
    ForwardIps=Arg#arg.headers#headers.x_forwarded_for,
    Fun=fun()->
        if is_list(ForwardIps) andalso length(ForwardIps)>0 ->    string:tokens(ForwardIps,","); true-> [] end
    end,
    case Fun() of
    [H|_]-> list_to_tuple([list_to_integer(I)||I<-string:tokens(H,".")]);
    _->    Ip
    end.    

table2file(Tab)->    
    List=ets:tab2list(Tab),
    Fn=atom_to_list(Tab),
    file:delete(Fn),
    ?MODULE:log(Fn,"~p",[List]),
    ok.

float_minus(A,B)->float_minus(A,B,1).
float_minus(A,B,N)->
    round((A-B)*math:pow(10,N))/math:pow(10,N).

float_n(F,N)->    
    round(F*math:pow(10,N))/math:pow(10,N).

json_http(Url,Map) when is_map(Map)->json_http(Url,map2json(Map));
json_http(Url,JsonStr)->
    inets:start(),  
    case httpc:request(post,{Url,[],"application/json", JsonStr},[],[]) of   
        {ok, {_,_,JsonBin}}-> 
            Maps=?MODULE:jsonbin2map(JsonBin),
            {ok,Maps};
        {error, Reason}->
            io:format("json_http error cause ~p~n",[Reason]),
            {error,Reason}
    end.

map2form(Map)->
    List=maps:to_list(Map),
    string:join([value2list(K)++"="++value2list(V)||{K,V}<-List],"&").
form2map(Form)->
    KVs=re:split(Form,"&"),
    Kvs1=[re:split(Kv,"=")||Kv<-KVs],
    Kvs2=[{binary_to_list(K),V}||[K,V]<-Kvs1],
    maps:from_list(Kvs2).
form_http(Url,Map) when is_map(Map)-> form_http(Url,map2form(Map));
form_http(Url,Data) when is_list(Data)->send_http(Url,"application/x-www-form-urlencoded",Data).

send_http(Url,Type,Str)->
    inets:start(),  
    log("log/send_http.log","start send_http:~p",[{Url,Type,Str}]),
    Ack=case httpc:request(post,{Url,[],"application/x-www-form-urlencoded", Str},[{timeout,20000}],[]) of   
        {ok, {_,_,JsonBin}}-> 
            Maps=?MODULE:jsonbin2map(JsonBin),
            {ok,Maps};
        {error, Reason}->
            io:format("json_http error cause ~p~n",[Reason]),
            {error,Reason}
    end,
    log("log/send_http.log","end send_http:~p",[Ack]),
    Ack.

%%--------------mnesia related ---------------------------------------
-include("db_op.hrl").
db_query(T)-> db_query(T,fun(_)-> true end).
db_query(T,Cond)->
    QH1=(qlc:q([X||X<-mnesia:table(T),Cond(X)])),
    QH2 = qlc:keysort(2, QH1, [{order, ascending}]), 
    ?DB_OP(qlc:e(QH2)).    

mnesia_all_items(T=nhome_history)-> 
    {atomic,Rs}=?MODULE:db_query(nhome_history),
    F=fun(DevId,Item)->
        L0=maps:to_list(Item),
        L1=[{binary_to_integer(K),V}||{K,V}<-L0,is_binary(K) andalso size(K)>0],
        L2=lists:keysort(1,L1),
        [V#{key=>DevId}||{_,V}<-L2]
      end,
    Items=[{nhome_history,DevId,F(DevId,Item)}||{nhome_history,DevId,Item}<-Rs],
    {atomic,Items};
mnesia_all_items(T=nhome_pushf_t)-> 
    mnesia_all_items_with_sort(T,[{order, descending}]);
mnesia_all_items(T)-> 
    mnesia_all_items_with_sort(T,[{order, ascending}]).    
mnesia_all_items_with_sort(T,Sort)->
    ?DB_QUERY_4_Key_Item(T,true,Sort).    
mnesia_to_plist_withconditions(Table,Conds)->
    case ?DB_QUERY_4_Key_Item(Table,condition_fs(X,Conds)) of
        {atomic,Items0}->
            Items=[tuple_to_list(Item)||Item<-Items0],
            {ok,lists:concat([mnesia_to_plist1(Key,Item)||[_RecordName,Key,Item|_]<-Items])};
        Other->{false,Other}
    end.

mnesia_to_plist(Table)-> 
    case mnesia_all_items(Table) of
        {atomic,Items0}->
            Items=[tuple_to_list(Item)||Item<-Items0],
            {ok,lists:concat([mnesia_to_plist1(Key,Item)||[_RecordName,Key,Item|_]<-Items])};
        _->false
    end.

mnesia_to_plist(Table,Cond)-> 
    case mnesia_items(Table,Cond) of
        {atomic,Items0}->
            Items=[tuple_to_list(Item)||Item<-Items0],
            {ok,lists:concat([mnesia_to_plist1(Key,Item)||[_RecordName,Key,Item|_]<-Items])};
        _->false
    end.

mnesia_to_plist1(Key,Item=#{})->
    mnesia_to_plist1(Key,[Item]);
mnesia_to_plist1(Key,Items) when is_list(Items)->mnesia_to_plist1(Key,Items,[]).

mnesia_to_plist1(_Key,[],Res)->lists:reverse((Res));
%mnesia_to_plist1(Key,[#{capacity:=Capacity}|Tail],Res) when Capacity>?MAX_FLOW ->  mnesia_to_plist1(Key,Tail,Res);
%mnesia_to_plist1(Key,[#{use_flow:=Capacity}|Tail],Res) when Capacity>?MAX_FLOW ->  mnesia_to_plist1(Key,Tail,Res);
mnesia_to_plist1(Key,[Head=#{}|Tail],Res)-> 
    ResItem=mnesia_to_plist2(Key,Head),
    mnesia_to_plist1(Key,Tail,[ResItem|Res]).

mnesia_to_plist2(Key,Item=#{})->
    Item1=maps:map(fun(_,V) when is_float(V)-> ?MODULE:term_to_binary(?MODULE:f2b(V,1));
                      (date,Date={_A,_B,_C})-> ?MODULE:d2b(Date);
                      (time,Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      (<<"time">>,Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      (first_time,Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      (last_time,Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      ("updatetime",Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      ("time_reset",Date={{_A,_B,_C},_})-> ?MODULE:d2b(Date);
                      (_,V)-> ?MODULE:term_to_binary(V) 
                   end,Item),
    [{key,Key}|maps:to_list(Item1)].

get_mnesia_items(Table,Key)->    
    mnesia:dirty_read(Table,Key).

mnesia_items(T,Cond)->?MODULE:db_query(T,Cond).

compare(Val1,T) when is_atom(Val1)-> compare(list_to_binary(atom_to_list(Val1)),T);
compare(Val1,[<<"like">>,Val2]) -> re:run(Val1,Val2)=/=nomatch;
compare(Val1,[<<"==">>,Val2])-> Val1==Val2;
compare(Val1,[<<">">>,Val2])-> Val1>Val2;
compare(Val1,[<<"<">>,Val2])-> Val1<Val2;
compare(Val1,[<<">=">>,Val2])-> Val1>=Val2;
compare(Val1,[<<"=<">>,Val2])-> Val1=<Val2;
compare(Val1,[<<"between">>,Val2,Val3]) when is_binary(Val1)->  
    Val1>=Val2 andalso Val1=<Val3;
compare(Val1,[<<"between">>,Val2,Val3])-> 
    Val1>=?MODULE:s2d(Val2) andalso Val1=<?MODULE:s2d(Val3).

condition_f(X={_T,Key,_},[<<"key">>|T])-> compare(Key,T);
condition_f(X={_T,_,Item},Cond=[Key|T])-> 
    maps:is_key(binary_to_list(Key),Item) andalso compare(maps:get(binary_to_list(Key),Item),T);
condition_f({_T,_,_},_)-> false.

condition_fs(_,[])-> true;
condition_fs(X,[Head|T])->
    condition_f(X,Head) andalso condition_fs(X,T).


page_items(Items,PageNum,CurPage) when is_number(PageNum) andalso is_number(CurPage) ->
    Pages=(length(Items) div PageNum) +1,
    Items1=if CurPage>Pages-> []; true-> lists:sublist(Items,(CurPage-1)*PageNum+1,PageNum) end,
    {Items1,Pages};
page_items(Items,_PageNum,_CurPage)-> {Items,1}.

handle_all_data_by_table(Arg)->
    Clidata=Arg#arg.clidata,
    {Table,CurPage,PageNum}=?MODULE:decode(Clidata, [{table,a},{curpage,i},{page_num,i}]),
    if is_integer(CurPage) andalso is_integer(PageNum)->
        case ?MODULE:mnesia_to_plist(Table) of
            {ok,Plss0}->
                {Plss,Pages}= ?MODULE:page_items(Plss0,PageNum,CurPage),
                Res=?MODULE:pl2jsos(Plss),
                %io:format("~p~n",[Res]),
                [{status,ok},{pages,Pages},{result,Res}];
            _->
                [{status,failed},{reason,incorrect_table}]
        end;
    true->
        [{status,failed},{reason,invalid_param}]
    end.

flush()->
    receive 
        _-> 
            flush()
    after 0->
        void
    end.

copy({_Node,_SrcDir,[]},_DstDir) -> void;
copy({Node,SrcDir,[Head|T]},DstDir) when is_list(Head) andalso is_list(DstDir)->
    copy({Node,SrcDir++"/"++Head},DstDir++"/"++Head),
    copy({Node,SrcDir,T},DstDir);
copy({Node,Src},Dst)->
    {ok,Bin}=rpc:call(Node,file,read_file,[Src]),
    file:write_file(Dst,Bin);
copy({_SrcDir,[]},{_Node,_DstDir}) -> void;
copy({SrcDir,[Head|T]},{Node,DstDir}) when is_list(Head) andalso is_list(DstDir)->
    copy(SrcDir++"/"++Head,{Node,DstDir++"/"++Head}),
    copy({SrcDir,T},{Node,DstDir});
copy(Src,{Node,Dst})->
    {ok,Bin}=file:read_file(Src),
    rpc:call(Node,file,write_file,[Dst,Bin]).    

