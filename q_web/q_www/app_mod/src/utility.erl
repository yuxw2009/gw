-module(utility).

-compile(export_all).

-include("yaws_api.hrl").
  
decode_json(Json, Spec) ->
    decode(Json, Spec, []).

decode(Arg, Spec) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata), 
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
    case rfc4627:get_field(JsonObj, Key) of
    {ok, Value}-> Value;
    _-> undefined
    end.

get_value(JsonObj, Key) ->
    case get(JsonObj, Key) of
    undefined-> undefined;
    V->    value2list(V)
    end.

value2list(V) when is_integer(V) -> integer_to_list(V);
value2list(V) when is_binary(V) -> binary_to_list(V).

get_binary(JsonObj, Key) ->
    get(JsonObj, Key).

get_array(JsonObj, Key) ->
    case get(JsonObj, Key) of
    undefined-> undefined;
    V->    [value2list(I) || I<-V]
    end.

get_array_integer(JsonObj, Key) ->
    case get(JsonObj, Key) of
    undefined-> undefined;
    V->    [list_to_integer(value2list(I)) || I<-V]
    end.
    
get_array_atom(JsonObj, Key) ->
    case get(JsonObj, Key) of
    undefined-> undefined;
    V->    [atom(value2list(I)) || I<-V]
    end.

get_array_binary(JsonObj, Key) ->
    [I || I<-get(JsonObj, Key)].

get_integer(JsonObj, Key) ->
    case get_string(JsonObj, Key) of
    undefined-> undefined;
    V->    list_to_integer(V)
    end.

get_atom(JsonObj, Key) ->
    atom(get_string(JsonObj, Key)).

get_string(JsonObj, Key) ->
    get_value(JsonObj, Key).
    
query_string(Arg, Key) ->    
   {ok, Value} = yaws_api:queryvar(Arg, Key),
   Value.

query_integer(Arg, Key) ->    
   {ok, Value} = yaws_api:queryvar(Arg, Key),
   list_to_integer(Value).

query_atom(Arg, Key) ->    
   {ok, Value} = yaws_api:queryvar(Arg, Key),
   atom(Value).

atom(A) ->
    case (catch list_to_existing_atom(A)) of
      {'EXIT',_} ->
        list_to_atom(A);
    S  ->
        S
  end.

%% [{a,1},{b,2}] => {obj, [{a,1}, {b,2}]} 
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
pl2jsos(PLists) ->
    [pl2jso(I) || I<- PLists].

pl2jsos(Trans, PLists) ->
    [pl2jso(Trans, I) || I<- PLists].

%% {a,b}, [{1,2}, {3,4}] => [{obj, [{a, 1}, {b, 2}]}, {obj, [{a, 3}, {b, 4}]}]
a2jsos(Tags, VLists) ->
    [a2jso(Tags, I) || I<- VLists].

client_ip(Arg) ->
    {Ip, _Port} = Arg#arg.client_ip_port,
    Ip.
    
decode(Json) ->
    {ok, Notify, _} = rfc4627:decode(Json),
    {obj, [{"uuid", UUID}, {"notify", Objs}]} = Notify,
    {list_to_integer(binary_to_list(UUID)), [o2pl(O) || O<-Objs]}.    

o2pl({obj,PL}) ->
    o2pl(PL, []).

o2pl([], Acc) -> Acc; 
o2pl([{Tag, {obj, PL}}|T], Acc) -> 
    o2pl(T, [{atom(Tag), o2pl(PL, [])}| Acc]);

o2pl([{Tag, Value}|T], Acc) -> 
   o2pl(T, [tag_trans(atom(Tag),Value)|Acc]).

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
    
pl2jso_r(Pls)-> pl2jso_r(Pls,[]).
pl2jso_r([],R)->pl2jso(lists:reverse(R));
pl2jso_r([{K,V=[{_,_}|_]}|T], R)-> pl2jso_r(T, [{K,pl2jso_r(V)}|R]);
pl2jso_r([H|T], R)-> pl2jso_r(T, [H|R]).

v2b_r(Pls)->    v2b_r(Pls,[]).
v2b_r([],R)-> lists:reverse(R);
v2b_r([{K,V}|T],R) when is_list(V)-> 
    case is_string(V) of
        true-> v2b_r(T, [{K,list_to_binary(V)}|R]);
        false-> v2b_r(T,[{K,v2b_r(V)}|R])
    end;
v2b_r([H|T],R)-> v2b_r(T, [H|R]).

pl2jso_br(Result)->
    utility:pl2jso_r(utility:v2b_r(Result)).    

is_string([]) -> true;
is_string([X|T]) -> is_integer(X) andalso X>=0 andalso is_string(T);
is_string(_) -> false.
    
date_after_n(N)->
    date_after_n(date(),N).

date_after_n(Date,N)->
    calendar:gregorian_days_to_date(calendar:date_to_gregorian_days(Date)+N).
d2s(Date={Year, _Month, _Day}) ->    
    DateStr = string:join([integer_to_list(I) || I <- tuple_to_list(Date)], "-").

term_to_binary(Rsn)->
    list_to_binary(lists:flatten(io_lib:format("~p",[Rsn]))).

term_to_list(T)->
    R = io_lib:format("~p", [T]),
    lists:flatten(R).

log(Filename, Str, CmdList) ->
    chkfilesize(Filename,5000000),
    log1(Filename,Str,CmdList).

log1(Filename, Str, CmdList) ->
    {ok, IODev} = file:open(Filename, [append]),
    io:format(IODev,Str++"\r\n", CmdList),
    file:close(IODev).

chkfilesize(Filename,Size) ->
    case file:read_file_info(Filename) of
        {ok, Finfo} ->
            if
                element(2, Finfo) > Size ->
                    file:rename(Filename, Filename++llog:ts()++".log");
                true ->
                    void
            end;
        {error, _} ->
            void
    end.

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
     
    
