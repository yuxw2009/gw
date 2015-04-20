-module(token_keeper).
-export([start/0, get_tokens/0, check_token/1,delay/1,gen_one_token/1]).

-define(EXPIRED_THRESH, 12*60*60).  %%   12 hours
-define(CLEAN_TIME,     13*60*60*1000). %%  13 hours
-define(GET_TOKENS_INTERVAL,     2000).
-define(MAX_REJ_PROTECT_NUM, 100).    

-record(state, {tabpair,status=not_ready,rejnum=0}).

get_tokens() ->
    ?MODULE ! {get_tokens, 500, self()},
    receive
        V -> 
            delay(100),
            V
        after
            2000 -> {error, timeout}        
    end.
    
check_token(Token) ->
   ?MODULE ! {check_token, Token, self()},
    receive
        R -> R
        after
            2000 -> {error, timeout}        
    end.
    
start() ->
    Pid = spawn(fun() -> init() end),
    register(?MODULE, Pid),
    Pid.

init() ->
    OldUsedTab = ets:new(old_used_tab, [public, {read_concurrency,true},{write_concurrency,true}]),
    NewUsedTab = ets:new(new_used_tab, [public, {read_concurrency,true},{write_concurrency,true}]),    
    timer:send_interval(?CLEAN_TIME, clean_used_tab),
    timer:send_interval(?GET_TOKENS_INTERVAL, tokens_interval),
    loop(0, #state{tabpair={OldUsedTab, NewUsedTab}}).
    
loop(Salt, State=#state{tabpair=TabPair,status=Status,rejnum=RejNum}) ->
    receive
        {get_tokens, Num, From} ->
            {NewSalt,NewState} = 
                if Status == ready;RejNum>100->
                    {Salt2, Tokens} = gen_tokens(Salt, Num, []),
                    From ! {value, Tokens},
                    {Salt2, State#state{status=not_ready,rejnum=0}};
                true->
                    From ! {value, []},
                    {Salt,State#state{rejnum=RejNum+1}}
                end,
            loop(NewSalt, NewState);
        {check_token, Token, From} ->
            spawn(fun() ->
                    R = do_check_token(Token, TabPair),
                    From ! R
                  end),
            loop(Salt, State);
        clean_used_tab ->
            {OldUsedTab, NewUsedTab} = TabPair,
            ets:delete_all_objects(OldUsedTab),
            loop(Salt, State#state{tabpair={NewUsedTab, OldUsedTab}});
        tokens_interval ->
            loop(Salt, State#state{status=ready});
        _ ->
            loop(Salt, State)
    end.        
        
gen_tokens(Salt, 0, Tokens) -> 
    {Salt, Tokens};    
gen_tokens(Salt, Num, Tokens) when Salt > 5000000-> 
    gen_tokens(0, Num-1, [gen_one_token(Salt)|Tokens]);
gen_tokens(Salt, Num, Tokens) -> 
    gen_tokens(Salt+1, Num-1, [gen_one_token(Salt)|Tokens]).

secret() ->
    "!@#$qwerasdfzxcv1234".
    
gen_fingerprint(SecStr, SaltStr) ->
    Secret = secret(),
    integer_to_list(lists:sum(binary_to_list(crypto:hash(md5, [SecStr, SaltStr, Secret])))).
    
gen_one_token(Salt) ->
    {_,Sec,_} = os:timestamp(),
    SecStr = integer_to_list(Sec),
    SaltStr = integer_to_list(Salt),    
    FingerPrint = gen_fingerprint(SecStr, SaltStr),
    list_to_binary(SecStr ++ "-" ++ SaltStr ++"-" ++ FingerPrint).
    
check_expired(Sec) ->
    {_,Sec2,_} = os:timestamp(),
    Delta = Sec2 - Sec,
    Expired = if
                  Delta < 0 ->
                      1000000+Delta;
                  true -> 
                      Delta
              end,
    Expired < ?EXPIRED_THRESH.          

check_token_new(Token, {OldUsedTab, NewUsedTab}) ->
    case ets:lookup(NewUsedTab, Token) of
        []  ->
            case ets:lookup(OldUsedTab, Token) of
                []  -> true;
                [_] ->
                    false
            end;
        [_] -> false
    end.

check_token_fingerprint(SecStr, SaltStr, FingerPrint) ->
    gen_fingerprint(SecStr, SaltStr) == FingerPrint.
    
mark_token_used(Token, NewUsedTab) ->
    ets:insert(NewUsedTab, {Token}).
    
do_check_token(Token, TabPair={_, NewUsedTab}) ->
    [SecStr, SaltStr, FingerPrint] = string:tokens(Token, "-"),
    Sec = list_to_integer(SecStr),
    case check_expired(Sec) of
        false -> 
            {error, token_expired};
        true ->
            case check_token_new(Token, TabPair) of
                false -> 
                    {error, token_used};
                true ->
                    case check_token_fingerprint(SecStr, SaltStr, FingerPrint) of
                        false -> 
                            {error, wrong_fingerprint};
                        true  ->
                            mark_token_used(Token, NewUsedTab),
                            pass
                    end
            end
    end.
    

delay(T)->
    receive
        impossible_msg_for_token->    void
    after T-> ok
    end.
