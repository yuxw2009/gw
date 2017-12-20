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
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    Value.

get_value(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    value2list(Value).

value2list(V) when is_integer(V) -> integer_to_list(V);
value2list(V) when is_binary(V) -> binary_to_list(V).

get_binary(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    Value.

get_array(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    [value2list(I) || I<-Value].

get_array_integer(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    [list_to_integer(value2list(I)) || I<-Value].

get_array_atom(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    [atom(value2list(I)) || I<-Value].

get_array_binary(JsonObj, Key) ->
    {ok, Value} = rfc4627:get_field(JsonObj, Key),
    [I || I<-Value].

get_integer(JsonObj, Key) ->
    list_to_integer(get_string(JsonObj, Key)).

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

f2s(F) ->
    f2s(F,2).
f2s(F,N) ->
    [V] = io_lib:format("~."++integer_to_list(N)++"f", [F*1.0]),
    V.

term_to_binary(Rsn)->
    list_to_binary(lists:flatten(io_lib:format("~p",[Rsn]))).

term_to_list(T)->
    R = io_lib:format("~p", [T]),
    lists:flatten(R).

d2s({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}}) ->    
    DateStr = string:join([integer_to_list(I) || I <- tuple_to_list(Date)], "-"),
    TimeStr = string:join([integer_to_list(I) || I <- tuple_to_list(Time)], ":"),
    DateStr ++" "++TimeStr.

log(Filename, Str, CmdList) ->
    chkfilesize(Filename,2000000),
    log1(Filename,"~s: "++Str,[d2s(erlang:localtime())|CmdList]).

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


delete_file_before(Fn, Local_time)->
    F = fun()->
             case file:read_file_info(Fn) of
             {ok,T}->
                 Day=element(5,T),
                 if Day<Local_time-> file:delete(Fn);            true-> void             end;
             _-> file_is_open
             end
         end,
    F().
delete_before_in_dir(Local_time,Dir)->
    {ok,Fns}=file:list_dir(Dir),
    Abs = [Dir++"/"++Fn || Fn<-Fns],
    [delete_file_before(AF,Local_time) || AF<-Abs].
my_print(_,_)-> pass;
my_print(Fmt,Args)->
    io:format("~s: "++Fmt++"~n",[utility:d2s(erlang:localtime())|Args]).
    
