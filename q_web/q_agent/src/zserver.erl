%%---------------------------------------------------------------------------------------
%%% @author ZhangCongSong
%%% @copyright 2012-2014 LiveCom
%%% @doc My Server
%%% @end
%%---------------------------------------------------------------------------------------
-module(zserver).
-export([start/3,stop/1,cast/2,call/3]).

%%---------------------------------------------------------------------------------------

start(Name,Module,State) when is_atom(Name) andalso 
                              is_atom(Module) ->
    register(Name,spawn(fun() -> loop(Name,Module,State) end)).

%%---------------------------------------------------------------------------------------

loop(Name,Module,State) ->
    receive
    	{cast,Cast} ->
    	    {no_reply,{ok,NewState}} = do_apply(Module,cast,{Name,Cast},State),
    	    loop(Name,Module,NewState);
    	{call,From,Call} ->
    	    {NeedReply,{Result,NewState}} = do_apply(Module,call,{Name,From,Call},State),
            case NeedReply of
                reply -> send(From,{Name,Result});
                no_reply -> ok
            end,
    	    loop(Name,Module,NewState);
    	{stop} ->
    	    stop;
    	_Other ->
    	    %%spawn(fun() -> logger:log(error,"~p receive unknow msg ~p ~n",[ServerName,Other]) end),
    	    loop(Name,Module,State)
    end.

%%---------------------------------------------------------------------------------------
 
do_apply(Module,Request,Arg,State) ->
    case catch apply(Module,handle,[Request,Arg,State]) of
    	{'EXIT', _Reason} ->
    	    %%spawn(fun() -> logger:log(error,"~p apply ~p error!Arg is ~p State is ~p Reason is ~p~n",[Server,Request,Arg,State,Reason]) end),
    	    {reply,{failed,State}};
    	{NeedReply,{Result,NewState}} ->
    	    {NeedReply,{Result,NewState}}
    end.

%%---------------------------------------------------------------------------------------

send(PID,Msg) ->
    try PID ! Msg
    catch
        _:_ ->
            ok
            %%logger:log(error,"receive pid is not existed~n")
    end.

%%---------------------------------------------------------------------------------------

cast(Name,Cast) when is_atom(Name) andalso
                     is_tuple(Cast) ->
    Name ! {cast,Cast}.

%%---------------------------------------------------------------------------------------

call(Name,Call,Time) when is_atom(Name)  andalso 
                          is_tuple(Call) andalso 
                          is_integer(Time) ->
    Name ! {call,self(),Call},
    receive
        {Name,Result} -> Result
    after
        Time -> failed
    end.

%%---------------------------------------------------------------------------------------

stop(Name) when is_atom(Name) ->
    Name ! {stop}.

%%---------------------------------------------------------------------------------------