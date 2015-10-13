%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork mobile voip AppMod for path: /lwork/mobile/voip
%%%------------------------------------------------------------------------------------------

-module(www_ft).
-compile(export_all).
-include("yaws_api.hrl").
-define(CALL,"./log/call.log").

handle(Arg, 'POST', ["send"]) ->
    { Id,  Phone,Sms} = utility:decode(Arg, [{id, s}, {phone,s},{sms,s}]),
    utility:pl2jso([{status, ok}]).    
    

