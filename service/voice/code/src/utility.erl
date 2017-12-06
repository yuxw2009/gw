-module(utility).
-compile(export_all).

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
    list_to_binary(utility:value2list(V)).

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


f2s(F) ->
    f2s(F,2).
f2s(F,N) ->
    [V] = io_lib:format("~."++integer_to_list(N)++"f", [F*1.0]),
    V.


%%  utility tools
reload()-> reload(?MODULE).
reload(MODS)->
	make:all(),
	F= fun(I)-> 
		code:purge(I),
		code:load_file(I)
	end,
	MODS1 = case MODS of
			_ when is_list(MODS)->	MODS;
			_ when is_atom(MODS)-> [MODS]
		end,
	[F(I) || I<-MODS1].    
	

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
    utility:pl2jso_r(utility:v2b_r(Result)).
%%    
o2pl({obj,PL}) ->
    o2pl(PL, []).

o2pl([], Acc) -> Acc; 
o2pl([{Tag, {obj, PL}}|T], Acc) -> 
    o2pl(T, [{atom(Tag), o2pl(PL, [])}| Acc]);

o2pl([{Tag, Value}|T], Acc) -> 
   o2pl(T, [tag_trans(atom(Tag),Value)|Acc]).

json2pl(Clidata)->
    {ok, Json, _} = rfc4627:decode(Clidata),
    utility:o2pl(Json).

record2pl(Fields,Rec)->
    [_|Vl]=tuple_to_list(Rec),
    lists:zip(Fields,Vl).

is_string([]) -> false;
is_string([X]) -> is_integer(X) andalso X>=0 andalso X<255;
is_string([X|T]) -> is_integer(X) andalso X>=0 andalso X<255 andalso is_string(T);
is_string(_) -> false.

term_to_binary(Rsn)->
    list_to_binary(lists:flatten(io_lib:format("~p",[Rsn]))).

term_to_list(T)->
    R = io_lib:format("~p", [T]),
    lists:flatten(R).

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
     
log(Filename, Str, CmdList) ->
    {ok, IODev} = file:open(Filename, [append]),
    io:format(IODev,"~s: "++Str++"~n",[d2s(erlang:localtime())|CmdList]),
    file:close(IODev).
	
     
log(Str, CmdList) ->log("log/debug.log",Str,CmdList).
	
ts() ->
	{Y, Mo, D} = date(),
	{H, Mi, S} = time(),
	{_,_,MS}=erlang:now(),
	xt:int2(Y) ++ "-" ++ xt:int2(Mo) ++ "-" ++ xt:int2(D) ++ " " ++ xt:int2(H) ++ ":" ++ xt:int2(Mi) ++ ":" ++ xt:int2(S)++":"++xt:int2(MS).
     
d2s(Date) ->d2s(Date,"-",":"," ").
d2s(Date = {_Year, _Month, _Day},DayCut,_TimeCut,_DayTimeCut) ->
    [Year0,Mon0,Day0]=[integer_to_list(I)||I<-[_Year, _Month, _Day]],
    [Mon1,Day1]=[string:copies("0",2-length(I))++I||I<-[Mon0,Day0]],
    Year0++DayCut++Mon1++DayCut++Day1;
d2s({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}},DayCut,TimeCut,DayTimeCut) ->
    [Year0,Mon0,Day0,Hour0,Min0,Sec0]=[integer_to_list(I)||I<-[_Year, _Month, _Day,_Hour, _Minute, _Second]],
    [Mon1,Day1,Hour1,Min1,Sec1]=[string:copies("0",2-length(I))++I||I<-[Mon0,Day0,Hour0,Min0,Sec0]],
    Year0++DayCut++Mon1++DayCut++Day1++DayTimeCut++Hour1++TimeCut++Min1++TimeCut++Sec1.

delay(T)->
    receive
        impossible_msg_for_token->    void
    after T-> ok
    end.

get_local_ips()->
    {ok,NetDrvNames}=inet:getiflist(),
     Ls=[ inet:ifget(If, [addr, flags])||If<-NetDrvNames],
    [proplists:get_value(addr,Pls)||{_,Pls}<-Ls,lists:member(running,proplists:get_value(flags,Pls)),lists:member(broadcast,proplists:get_value(flags,Pls))].
