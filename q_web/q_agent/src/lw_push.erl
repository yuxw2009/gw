%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork iphone push notification
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_push).
-compile(export_all).

%%-------------------------------------------------------------------------------------------------

start() ->
    F = fun() ->
    	    crypto:start(),
    	    application:start(public_key),
    	    application:start(ssl),
    	    TID = ets:new(push_server,[named_table,set,public,{keypos,1}]),
    	    loop(TID)
    	end,
    register(push_server,spawn(fun() -> F() end)).

%%-------------------------------------------------------------------------------------------------

loop(TID) ->
    receive
		{Command,From,Args} ->
    	    try
    	    	apply(lw_push,Command,[[TID|Args]]),
    	    	From ! ok
    	    catch
    	    	_:Reason ->
                    logger:log(error,"iphone push notification error cmd:~p~n arg:~p~n reason:~p~n",[Command, Args, Reason]),
                    From ! failed
    	    end,
    	    loop(TID)
    end.

%%---------------------------------------------------------------------------------------------

wait_for_result() ->
    receive
    	Value -> Value
    after 
    	5000 -> failed
    end.

%%---------------------------------------------------------------------------------------------

register_device_token(UUID,DeviceToken) ->
    push_server ! {register_device_token,self(),[UUID,DeviceToken]},
    wait_for_result().

register_device_token([TID,UUID,DeviceToken]) ->
    ets:insert(TID, {UUID,DeviceToken}).

%%---------------------------------------------------------------------------------------------

push_notification(UUIDs,Content) when is_list(UUIDs) ->
    push_server ! {push_notification,self(),[UUIDs,Content]},
    wait_for_result().

%%---------------------------------------------------------------------------------------------

push_notification([TID,UUIDs,Content]) when is_list(UUIDs) ->
    [spawn(fun() -> push_notification([TID,UUID,Content]) end)||UUID<-UUIDs];

%%---------------------------------------------------------------------------------------------

push_notification([TID,UUID,Content]) when is_integer(UUID)->
    case get_device_token(TID,UUID) of
    	no_device_token -> 
    	    ok;
    	DeviceToken ->
    	    send_notification(UUID,DeviceToken,Content)
    end.

%%---------------------------------------------------------------------------------------------

get_device_token(TID,UUID) ->
    case ets:lookup(TID, UUID) of
    	[] -> no_device_token;
    	[{UUID,DeviceToken}] -> DeviceToken
    end.

%%---------------------------------------------------------------------------------------------

send_notification(UUID,DeviceToken,Content) ->
    Address = "gateway.push.apple.com",
    Port    = 2195,
    Cert    = filename:absname("priv/lworkCert.pem"),
    Key     = filename:absname("priv/lworkKey.pem"),
    Options = [{certfile, Cert}, {keyfile, Key}, {password, "888888"}, {mode, binary}],
    Timeout = 30000,
    UnRead  = lw_instance:get_unread_num(UUID,topic) + lw_instance:get_unread_num(UUID,{reply,topic}) +
              lw_instance:get_unread_num(UUID,task)  + lw_instance:get_unread_num(UUID,{reply,task}) + 
              lw_router:get_messages_len(UUID),
    Badge   =
        case UnRead of
            0 -> "1";
            _ -> integer_to_list(UnRead)
        end,
    {ok, Socket} = ssl:connect(Address, Port, Options, Timeout),
    Payload = "{\"aps\":{\"alert\":\"" ++ Content ++ "\",\"badge\":" ++ Badge ++ ",\"sound\":\"" ++ "chime" ++ "\"}}",
    DeviceTokenBin  = hexstr_to_bin(DeviceToken),
    DeviceTokenSize = erlang:size(DeviceTokenBin),
    PayLoadBin  = list_to_binary(Payload),
    PayloadSize = byte_size(PayLoadBin),
    Packet = [<<0:8, DeviceTokenSize:16/big, DeviceTokenBin/binary, PayloadSize:16/big, PayLoadBin/binary>>],
    ssl:send(Socket, Packet),
    ssl:close(Socket).

%%---------------------------------------------------------------------------------------------

hexstr_to_bin(S) ->
  hexstr_to_bin(S, []).
hexstr_to_bin([], Acc) ->
  list_to_binary(lists:reverse(Acc));
hexstr_to_bin([$ |T], Acc) ->
    hexstr_to_bin(T, Acc);
hexstr_to_bin([X,Y|T], Acc) ->
  {ok, [V], []} = io_lib:fread("~16u", [X,Y]),
  hexstr_to_bin(T, [V | Acc]).

%%---------------------------------------------------------------------------------------------

test() ->
    crypto:start(),
    application:start(public_key),
    application:start(ssl),
    DeviceToken = "380c96d934c2e39b88e276058d4159712c030df23506d28efd6a2d9fa5e10fea",
    send_notification(84,DeviceToken,"test for product push").

%%---------------------------------------------------------------------------------------------