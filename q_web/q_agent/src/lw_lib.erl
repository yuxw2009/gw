%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork lw_lib
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_lib).
-compile(export_all).

-define(HTTP_TIMEOUT,10 * 1000).

trans_time_format({{Year,Month,Day},{Hour,Minute,_Second}}) ->
    integer_to_list(Year)   ++ "-" ++ 
    integer_to_list(Month)  ++ "-" ++ 
    integer_to_list(Day)    ++ " " ++
    integer_to_list(Hour)   ++ ":" ++
    if
    	Minute < 10 -> "0" ++ integer_to_list(Minute);
    	true -> integer_to_list(Minute)
    end.

get_sublist(Terms,Index,Num) ->
    Begin = (Index - 1) * Num + 1,
    Len   = Num,
    case Begin > length(Terms) of
    	true ->
    	    [];
    	false ->
    	    lists:sublist(Terms,Begin,Len)
    end.

%%--------------------------------------------------------------------------------------

build_url(IP,URL,[],[]) ->
    IP ++ URL;
build_url(IP,URL,Tags,Contents) ->
    F = fun({Tag,Content}) when is_list(Content) -> atom_to_list(Tag) ++ "=" ++ Content;
           ({Tag,Content}) when is_integer(Content) -> atom_to_list(Tag) ++ "=" ++ integer_to_list(Content)
        end,
    IP ++ URL ++ "?" ++ string:join(lists:map(F,lists:zip(Tags, Contents)),"&").

build_body(Tags,Contents,Acts) ->
    F = fun({r,Content}) -> Content;
           ({b,Content}) -> list_to_binary(Content)
        end,
    NewContents = lists:map(F,lists:zip(Acts,Contents)),
    utility:pl2jso(lists:zip(Tags,NewContents)).

build_body(Tags,Contents,Acts,{audit_info,UUID}) ->
    AuditInfo = build_user_audit_info(UUID),
    build_body([audit_info|Tags],[AuditInfo|Contents],[r|Acts]).

build_user_audit_info(UUID) ->
    Module    = lw_config:get_user_module(),
    AuditInfo = Module:get_user_audit_info(UUID),
    build_body([uuid,company,name,account,orgid],tuple_to_list(AuditInfo),[r,b,b,b,r]).

send_httpc(get,{URL}) ->
    httpc:request(get,{URL,[]},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(post,{URL,Body}) ->
    httpc:request(post, {URL,[],"application/json",Body},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(put,{URL,Body}) ->
    httpc:request(put, {URL,[],"application/json",Body},[{timeout,?HTTP_TIMEOUT}],[]);
send_httpc(delete,{URL}) ->
    httpc:request(delete,{URL,[]},[{timeout,?HTTP_TIMEOUT}],[]).

httpc_call(Type,Arg) ->
    case send_httpc(Type,Arg) of
        {ok,{_,_,Ack}} ->
            case rfc4627:decode(Ack) of
            {ok,Json,_}->            Json;
            R-> io:format("lw_lib httpc_call(~p,~p) Res:~p~n", [Type,Arg,R])
            end;
        Other ->
            logger:log(error,"httpc_call_failed Reason:~p~n",[Other]),
            httpc_failed
    end.

parse_json(Json,ParseSpec,Fail) ->
    Status = utility:get_string(Json,"status"),
    case Status of
        "ok" ->
            case ParseSpec of
                [] -> {ok};
                _  -> utility:decode_json(Json,ParseSpec)
            end;
        "failed" ->
            Reason = utility:get_string(Json,"reason"),
            Fail(Reason)
    end.

%%--------------------------------------------------------------------------------------

easyEncrypt(Key,Chip) ->
    SameLenKey = makeSameLengthKey(Key,Chip),
    doEasyEncrypt(SameLenKey,Chip,[]).

doEasyEncrypt([],[],Acc) ->
    lists:reverse(Acc);
doEasyEncrypt([H1|T1],[H2|T2],Acc) ->
    doEasyEncrypt(T1,T2,[H1 bxor H2|Acc]).

makeSameLengthKey(Key,Chip) when length(Key) > length(Chip) ->
    CLen = length(Chip),
    makeSameLengthKey(lists:sublist(Key,CLen),Chip);
makeSameLengthKey(Key,Chip) when length(Key) =< length(Chip) ->
    CLen = length(Chip),
    KLen = length(Key),
    Div = CLen div KLen,
    Rem = CLen rem KLen,
    lists:append(lists:duplicate(Div, Key)) ++ lists:sublist(Key,Rem).

%%--------------------------------------------------------------------------------------

log_in(UUID) ->
    case mnesia:dirty_read(lw_instance,UUID) of
        [] ->
            failed;
        _ ->
            case lw_router:is_user_alive(UUID) of
                false ->
                    OrgID = local_user_info:get_org_id_by_mark_name("zteict"),
                    lw_router:register_ua(OrgID,UUID,1);
                true ->
                    ok
            end
    end.

%%--------------------------------------------------------------------------------------

eval([]) ->
    fun(Arg) ->
        Arg
    end;

eval([{H,FalseRet}|T]) ->
    fun(Arg) ->
        case H(Arg) of
            {false,_F} ->
                FalseRet;
            {true,NextArg} -> 
                apply(eval(T),[NextArg])
        end
    end.

%%--------------------------------------------------------------------------------------
