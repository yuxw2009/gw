%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/im
%%%------------------------------------------------------------------------------------------
-module(im_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle create message session
handle(Arg, 'POST', ["sessions"]) ->
    {UUID, Members}  = utility:decode(Arg, [{uuid,i}, {members, ai}]),

    SID = im_router:create_session(UUID, Members),

    utility:pl2jso([{status,ok},{session_id, SID}]);

%% handle invite a new member
handle(Arg, 'POST', ["session", SessionID, "members"]) ->
    {FromUUID, Membes} = utility:decode(Arg, [{uuid,i},{members, ai}]),
    ok = im_router:invite(FromUUID, list_to_integer(SessionID), Membes),

    utility:pl2jso([{status,ok}]);

%% handle leave session 
handle(Arg, 'DELETE', ["session", SessionID, "members"]) ->
     UUID = utility:query_integer(Arg, "uuid"),

    ok = im_router:leave(UUID, list_to_integer(SessionID)),
    utility:pl2jso([{status,ok}]);

%% handle send message 
handle(Arg, 'POST', ["session", SessionID, "messages"]) ->
    {UUID, Content} = utility:decode(Arg, [{uuid,i},{content, b}]),

    Result = im_router:message(UUID, list_to_integer(SessionID), Content),
    utility:pl2jso([{status,Result}]).

