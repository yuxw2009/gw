-module(utility).

-compile(export_all).

-include("yaws_api.hrl").

get_by_stringkey(Key,Arg)->
    {ok, {obj,Params},_}=rfc4627:decode(Arg#arg.clidata),
    proplists:get_value(Key, Params, <<"">>).
  
get_string_by_stringkey(Key,Arg)->
    binary_to_list(get_by_stringkey(Key,Arg)).
  
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
    {ok, Value}= rfc4627:get_field(JsonObj, Key),
    Value.

get_value(JsonObj, Key) ->
    case rfc4627:get_field(JsonObj, Key) of
    {ok, Value}-> value2list(Value);
    not_found-> "undefined"
    end.

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
   case yaws_api:queryvar(Arg, Key) of
   {ok, Value}->   Value;
   O-> O
   end.

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


client_ip(Arg) ->
    {Ip, _Port} = Arg#arg.client_ip_port,
    Ip.
    
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

is_string([]) -> true;
is_string([X|T]) -> is_integer(X) andalso X>=0 andalso is_string(T);
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
	
     
d2s({Date = {_Year, _Month, _Day}, Time = {_Hour, _Minute, _Second}}) ->    
    DateStr = string:join([integer_to_list(I) || I <- tuple_to_list(Date)], "-"),
    TimeStr = string:join([integer_to_list(I) || I <- tuple_to_list(Time)], ":"),
    DateStr ++" "++TimeStr.

delay(T)->
    receive
        impossible_msg_for_token->    void
    after T-> ok
    end.

httpc_call(Method,Url,Params) ->
    ssl:start(),
    inets:start(),
    {ok,{_,_,Ack}} = send_httpc(Method,{Url,Params}),
    {ok,Json,_} = rfc4627:decode(Ack),
    Json.

send_httpc(get,{URL,Params}) ->
    httpc:request(get,{build_url(URL,Params),[]},[{timeout,10 * 1000}],[]);
send_httpc(post,{URL,Params}) -> send_httpc(post,{URL,Params}, "application/json");
send_httpc(put,{URL,Params}) ->  send_httpc(put,{URL,Params}, "application/json");
send_httpc(delete,{URL,Params}) ->
    httpc:request(delete,{build_url(URL,Params),[]},[{timeout,10 * 1000}],[]).

send_httpc(Meth,{URL,Params},ContentType) ->
    Content = params2content(Params,ContentType),
    httpc:request(Meth, {URL,[{"Accept-Encoding","identity"}],ContentType,Content},[{timeout,10 * 1000}],[]).

params2content(Params,"application/json")->rfc4627:encode(utility:pl2jso(Params));
params2content(Params,"application/x-www-form-urlencoded")->
    KVs=[urlenc:escape_uri(K)++"="++urlenc:escape_uri(V)||{K,V}<-Params],
    string:join(KVs,"&");
params2content(Params,_)->Params.

build_url(Url,Params)->
    F = fun({Tag,Content}) when is_list(Content) -> to_list(Tag) ++ "=" ++ Content;
           ({Tag,Content}) when is_integer(Content) -> to_list(Tag) ++ "=" ++ integer_to_list(Content);
           ({Tag,Content}) when is_binary(Content) -> to_list(Tag) ++ "=" ++ binary_to_list(Content);
           ({Tag,Content}) when is_atom(Content) -> to_list(Tag) ++ "=" ++ atom_to_list(Content)
        end,
    Url ++ "?" ++ string:join(lists:map(F,Params),"&").

%% for xg
test()->
    Url = "http://openapi.xg.qq.com/v2/push/single_account",
    Content="account=123456&timestamp=1415535415&access_id=2100058848&multi_pkg=0&sign=591483476d0df8f4373f953821ef4598&environment=2&device_type=0&send_time=&expire_time=86400&message=%7B%22content%22%3A%22some+content%22%2C%22custom_content%22%3A%7B%22aaa%22%3A%22111%22%2C%22bbb%22%3A%22222%22%7D%2C%22title%22%3A%22some+title%22%7D&message_type=2",
    httpc:request(post, {Url,[{"Accept-Encoding","identity"}],"application/x-www-form-urlencoded",Content},[{timeout,10 * 1000}],[{header_as_is,true}]).
send_xg_httpc()->
    Method = "POST",
    Url = "openapi.xg.qq.com/v2/push/single_device",
    Params=[{access_id,2100058848},{timestamp,timestamp()},{device_token,0}],
    SortedParams = lists:keysort(1,Params),
    ParamsStr = lists:flatten([term_to_list(K)++"="++term_to_list(V) ||{K,V}<-SortedParams]),
    SecretKey = "a0bff10ef8cc64f8ee2fea320b83f279",
    Sign=hex:to(crypto:md5(Method++Url++ParamsStr++SecretKey)),
    NewParams = Params++[{sign,list_to_binary(Sign)}],
    io:format("~p~n", [NewParams]),
    send_httpc(post,{"http://"++Url,NewParams},"application/x-www-form-urlencoded").
%    NewParams.

timestamp()->    
    {Mego,Sec,_}=erlang:now(),
    Mego*1000000+Sec.

to_list(Url) when is_atom(Url)-> atom_to_list(Url);
to_list(Url)-> Url.

country(undefined)-> default;
country(Ip={_A,_B,_C,_D})->  i2c:findLocal(ip2uint(Ip)).
continent(Ip)-> c2s(country(Ip)).    

ip2uint({A,B,C,D}) ->
    A*256*256*256 + B*256*256 + C*256 + D.

c2s("EE") -> "Europe";
c2s("LV") -> "Europe";
c2s("LT") -> "Europe";
c2s("BY") -> "Europe";
c2s("RU") -> "Europe";
c2s("UA") -> "Europe";
c2s("MD") -> "Europe";
c2s("GB") -> "Europe";
c2s("IE") -> "Europe";
c2s("BE") -> "Europe";
c2s("LU") -> "Europe";
c2s("FR") -> "Europe";
c2s("MC") -> "Europe";
c2s("NL") -> "Europe";
c2s("PL") -> "Europe";
c2s("CZ") -> "Europe";
c2s("SK") -> "Europe";
c2s("HU") -> "Europe";
c2s("DE") -> "Europe";
c2s("AT") -> "Europe";
c2s("CH") -> "Europe";
c2s("LI") -> "Europe";
c2s("RO") -> "Europe";
c2s("BG") -> "Europe";
c2s("MK") -> "Europe";
c2s("AL") -> "Europe";
c2s("GR") -> "Europe";
c2s("SI") -> "Europe";
c2s("HR") -> "Europe";
c2s("BA") -> "Europe";
c2s("IT") -> "Europe";
c2s("VA") -> "Europe";
c2s("SM") -> "Europe";
c2s("MT") -> "Europe";
c2s("ES") -> "Europe";
c2s("PT") -> "Europe";
c2s("AD") -> "Europe";
c2s("FI") -> "Europe";
c2s("SE") -> "Europe";
c2s("NO") -> "Europe";
c2s("IS") -> "Europe";
c2s("DK") -> "Europe";
c2s("CN") -> "Mainland";
c2s("HK") -> "Asia";
c2s("TW") -> "Asia";
c2s("MN") -> "Asia";
c2s("KP") -> "Asia";
c2s("KR") -> "Asia";
c2s("JP") -> "Asia";
c2s("PH") -> "Asia";
c2s("VN") -> "Asia";
c2s("LA") -> "Asia";
c2s("KH") -> "Asia";
c2s("TH") -> "Asia";
c2s("MY") -> "Asia";
c2s("BN") -> "Asia";
c2s("SG") -> "Asia";
c2s("ID") -> "Asia";
c2s("MM") -> "Asia";
c2s("NP") -> "Asia";
c2s("BT") -> "Asia";
c2s("BI") -> "Asia";
c2s("IN") -> "Asia";
c2s("PK") -> "Asia";
c2s("LK") -> "Asia";
c2s("MV") -> "Asia";
c2s("KZ") -> "Asia";
c2s("KG") -> "Asia";
c2s("TJ") -> "Asia";
c2s("UZ") -> "Asia";
c2s("TM") -> "Asia";
c2s("AF") -> "Asia";
c2s("IQ") -> "Asia";
c2s("IR") -> "Asia";
c2s("SY") -> "Asia";
c2s("JO") -> "Asia";
c2s("LB") -> "Asia";
c2s("IL") -> "Asia";
c2s("SA") -> "Asia";
c2s("BH") -> "Asia";
c2s("QA") -> "Asia";
c2s("KW") -> "Asia";
c2s("AE") -> "Asia";
c2s("OM") -> "Asia";
c2s("YE") -> "Asia";
c2s("GE") -> "Asia";
c2s("AM") -> "Asia";
c2s("AZ") -> "Asia";
c2s("TR") -> "Asia";
c2s("CY") -> "Asia";
c2s("EG") -> "Africa";
c2s("LY") -> "Africa";
c2s("SD") -> "Africa";
c2s("TN") -> "Africa";
c2s("DZ") -> "Africa";
c2s("MA") -> "Africa";
c2s("ET") -> "Africa";
c2s("ER") -> "Africa";
c2s("SO") -> "Africa";
c2s("DJ") -> "Africa";
c2s("KE") -> "Africa";
c2s("TZ") -> "Africa";
c2s("UG") -> "Africa";
c2s("BD") -> "Africa";
c2s("SC") -> "Africa";
c2s("TD") -> "Africa";
c2s("CF") -> "Africa";
c2s("CM") -> "Africa";
c2s("GQ") -> "Africa";
c2s("GA") -> "Africa";
c2s("CG") -> "Africa";
c2s("CD") -> "Africa";
c2s("ST") -> "Africa";
c2s("RW") -> "Africa";
c2s("MR") -> "Africa";
c2s("GM") -> "Africa";
c2s("ML") -> "Africa";
c2s("BF") -> "Africa";
c2s("GN") -> "Africa";
c2s("GW") -> "Africa";
c2s("CV") -> "Africa";
c2s("SL") -> "Africa";
c2s("LR") -> "Africa";
c2s("CI") -> "Africa";
c2s("GH") -> "Africa";
c2s("TG") -> "Africa";
c2s("BJ") -> "Africa";
c2s("NE") -> "Africa";
c2s("NG") -> "Africa";
c2s("SN") -> "Africa";
c2s("ZM") -> "Africa";
c2s("AO") -> "Africa";
c2s("ZW") -> "Africa";
c2s("MW") -> "Africa";
c2s("MZ") -> "Africa";
c2s("BW") -> "Africa";
c2s("NA") -> "Africa";
c2s("ZA") -> "Africa";
c2s("SZ") -> "Africa";
c2s("LS") -> "Africa";
c2s("MG") -> "Africa";
c2s("KM") -> "Africa";
c2s("MU") -> "Africa";
c2s("CA") -> "NorthAmerica";
c2s("US") -> "NorthAmerica";
c2s("MX") -> "NorthAmerica";
c2s("GT") -> "NorthAmerica";
c2s("BZ") -> "NorthAmerica";
c2s("SV") -> "NorthAmerica";
c2s("HN") -> "NorthAmerica";
c2s("NI") -> "NorthAmerica";
c2s("CR") -> "NorthAmerica";
c2s("PN") -> "NorthAmerica";
c2s("BS") -> "NorthAmerica";
c2s("CU") -> "NorthAmerica";
c2s("JM") -> "NorthAmerica";
c2s("HT") -> "NorthAmerica";
c2s("DO") -> "NorthAmerica";
c2s("AG") -> "NorthAmerica";
c2s("KN") -> "NorthAmerica";
c2s("DM") -> "NorthAmerica";
c2s("LC") -> "NorthAmerica";
c2s("VC") -> "NorthAmerica";
c2s("BB") -> "NorthAmerica";
c2s("TT") -> "NorthAmerica";
c2s("GD") -> "NorthAmerica";
c2s("CO") -> "SouthAmerica";
c2s("VE") -> "SouthAmerica";
c2s("GY") -> "SouthAmerica";
c2s("SR") -> "SouthAmerica";
c2s("EC") -> "SouthAmerica";
c2s("PE") -> "SouthAmerica";
c2s("BO") -> "SouthAmerica";
c2s("BR") -> "SouthAmerica";
c2s("CL") -> "SouthAmerica";
c2s("AR") -> "SouthAmerica";
c2s("UY") -> "SouthAmerica";
c2s("PY") -> "SouthAmerica";
c2s("AU") -> "Oceania";
c2s("NZ") -> "Oceania";
c2s("PG") -> "Oceania";
c2s("SB") -> "Oceania";
c2s("VU") -> "Oceania";
c2s("FM") -> "Oceania";
c2s("MH") -> "Oceania";
c2s("PW") -> "Oceania";
c2s("NR") -> "Oceania";
c2s("KI") -> "Oceania";
c2s("TV") -> "Oceania";
c2s("WS") -> "Oceania";
c2s("FJ") -> "Oceania";
c2s("TO") -> "Oceania";
c2s("CK") -> "Oceania";
c2s(_)    -> "Asia".

