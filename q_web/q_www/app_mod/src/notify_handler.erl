%%%------------------------------------------------------------------------------------------
%%% @doc Yaws notify_handler AppMod for path: /notify
%%%------------------------------------------------------------------------------------------
-module(notify_handler).
-compile(export_all).

-include("yaws_api.hrl").

print(_, _, []) -> pass;
print(Pre, UUID, L)  -> io:format("~p: ~p ~n", [Pre, {UUID, L}]).

log(_UUID, [], []) -> pass;
log(UUID, CmdList, ResList) -> 
    {ok, IODev} = file:open("./log/webchat.log", [append]),
    io:format(IODev, "UUID: ~p ~p ~nCmdList: ~p~nResList: ~p~n~n~n", [UUID, erlang:localtime(), CmdList, ResList]),
    file:close(IODev).

handle(Method, Json) ->
    Method = 'POST',
    %%print("CmdList", uuid, Json),
	{UUID, CmdList} = utility:decode(Json),
	print("CmdList", UUID, CmdList),
	ResList = user_agent:notify(UUID, CmdList),
	print("ResList", UUID, ResList),
    
    log(UUID, CmdList, ResList),

    utility:encode(ResList).

%% yaws callback entry
out(Arg) ->
    Method = (Arg#arg.req)#http_request.method,
    Response = 
	    case catch handle(Method, Arg#arg.clidata) of
	    	{'EXIT', Reason} -> 
	    	    io:format("Error: ~p ********************* reason:~p ~n", [Arg#arg.clidata,Reason]),
	    	    utility:encode([]);
	    	ResList -> ResList  	    
	    end,

    {content, "application/json", Response}.
   
test() ->
    PLS = [[{type,session_open},
              {session_id,14},
              {member_ids,"VZ"},
              {history_message,
               [[{content,
                  <<232,175,180,233,131,189,229,152,142,232,190,190,228,184,
                    170>>},
                 {media_type,<<"chat">>},
                 {uuid,86},
                 {name,<<233,130,147,232,190,137>>},
                 {time,<<"2013-4-17 17:23:53">>}],
             
                 [{content,<<229,147,135,229,147,135,229,147,135>>},
                   {media_type,<<"chat">>},
                   {uuid,90},
                   {name,<<230,174,181,229,133,136,229,190,183>>},
                   {time,<<"2013-4-17 17:22:8">>}],
                   [{content,<<228,187,150,228,187,150,228,187,150>>},
                     {media_type,<<"chat">>},
                     {uuid,86},
                     {name,<<233,130,147,232,190,137>>},
                     {time,<<"2013-4-17 17:21:56">>}]]}],
                   
             [{type,session_message},
              {session_id,14},
              {media_type,chat},
              {payload,
               [{content,
                 <<115,229,185,178,230,146,146,231,154,132,233,152,191,230,
                   150,175,233,161,191,228,184,170,230,152,175,231,154,132>>},
                {media_type,<<"chat">>},
                {uuid,86},
                {name,<<233,130,147,232,190,137>>},
                {time,<<"2013-4-17 17:23:55">>}]}]],
    utility:encode(PLS).


test2() ->
   R = [[{type,session_message},
            {session_id,30},
            {payload,[{media_type,video_conf},
                      {action,create_success},
                      {conf_no,<<"room_1">>},
                      {conf_sdp,<<"v=0\r">>},
                      {members,[[{position,0},{uuid,4}],
                                [{position,1},{uuid,4}]]}]}]],
   utility:encode(R).

test3() ->
   R = [[{type,session_message},
            {session_id,30},
            {payload,[{media_type,video_conf},
                      {action,create_success},
                      {conf_no,<<"room_1">>},
                      {conf_sdp,<<"v=0\r">>},
                      {members,[1,2,3,4]}]}]],
   utility:encode(R).
                 