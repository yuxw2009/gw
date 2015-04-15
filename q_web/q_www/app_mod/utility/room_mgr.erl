-module(room_mgr).
-compile(export_all).
-behaviour(gen_server).

-include("room.hrl").
-record(state, {rooms=[], dt=room:detect_timer()}).

-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).


start()->
    gen_server:start({local, ?MODULE}, ?MODULE, [],[]).

up_request({Event, Params})->
%    io:format("room_mgr up_request: event:~p params:~p~n", [Event, Params]),
    exc_call({up_request, Event, Params}).    

login_room(Client, CmdList)-> 
    Room=room:room_atom(CmdList),
    exc_call({login, Client,Room, CmdList}).
create_room(Client, CmdList)-> 
    Room=room:room_atom(CmdList),
    exc_call({create, Client,Room, CmdList}).
get_opr(Type,Params)-> exc_call( {get_opr, Type, Params}).
inservice(Room)-> exc_call({inservice, Room}).
empty(Room)->  %atom
%    Room=list_to_atom(binary_to_list(Room_bin)),
    exc_call({empty, Room}).

show()->
    exc_call( show_rooms).
%%   callback for gen_server
init([])->
    Rooms=[#room_info{no=list_to_atom(integer_to_list(I))}||I<-lists:seq(1000,1009)],
    {ok, #state{rooms=Rooms}}.

handle_call({up_request, <<"invite">>, Params}, _From, State=#state{rooms=Rooms})->
    Room = room:room_atom(Params),
    case room_status(Room, Rooms) of
    ?BUSY->
        room:invite(Room, self(), Params),
        Result=[{status,ok}, {room,Room}],
        {reply, Result, State};
    _->
        {reply, [{status,failed}, {reason, 'sorry, no free operator in service'}], State}
    end;

handle_call({up_request, <<"join">>, Params}, _From, State=#state{rooms=Rooms})->
    Room = room:room_atom(Params),
    case room_status(Room, Rooms) of
    ?BUSY->
         room:join(Room, self(), Params),
        Result=[{status,ok},{room,Room}],
        {reply, Result, State};
       _->
        {reply, [{status,failed}], State}
    end;


handle_call({up_request, <<"clt_leave">>, Params}, _From, State=#state{rooms=Rooms})->
    Room = room:room_atom(Params),
    room:clt_leave(Room, self(), Params),
    [#room_info{status=Status}]=get_room(Room, Rooms),
    NewStatus = case Status of
                            ?EMPTY-> ?EMPTY;
                            _-> ?INSERVICE
                      end,
    {reply, [{status,ok}], State#state{rooms=update_room(Room, NewStatus, Rooms)}};
%    [Rinfo]=get_room(Room, Rooms),
%    {reply, [{status,ok}, {src, clt_leave}], State#state{rooms=update_room(Rinfo#room_info{status=?INSERVICE}, Rooms)}};

handle_call({up_request, <<"opr_leave">>, Params}, _From, State=#state{rooms=Rooms})->
    Room = room:room_atom(Params),
    room:opr_leave(Room, self(), Params),
    [#room_info{status=Status}]=get_room(Room, Rooms),
    NewStatus = case Status of
                            ?EMPTY-> ?EMPTY;
                            _-> ?INSERVICE
                      end,
    {reply, [{status,ok}], State#state{rooms=update_room(Room, NewStatus, Rooms)}};

handle_call({up_request, <<"logout">>, Params}, _From, State=#state{rooms=Rooms})->
    Room = room:room_atom(Params),
    room:logout(Room, self(), Params),
    [Rinfo]=get_room(Room, Rooms),
    {reply, [{status,ok}, {src, logout}], State#state{rooms=update_room(Rinfo#room_info{status=?EMPTY, type=undefined}, Rooms)}};

handle_call({up_request, <<"shakehand_opr">>, Params}, _From, State)->
    Room = room:room_atom(Params),
    Result=room:shakehand_opr(Room, self(), Params),
    {reply, Result, State};

handle_call({up_request, Event, Params}, _From, State)->
    Room = room:room_atom(Params),
    room:on_event(Room, self(), Event, Params),
    {reply, [{result, ok}], State};


handle_call({inservice, Room}, _From, State=#state{rooms=Rooms})->
    [Rinfo=#room_info{status=Status}]=get_room(Room, Rooms),
    NewStatus = case Status of
                            ?EMPTY-> ?EMPTY;
                            _-> ?INSERVICE
                      end,
    {reply, [{status,ok}], State#state{rooms=update_room(Rinfo#room_info{status=NewStatus}, Rooms)}};
    
handle_call({empty, Room}, _From, State=#state{rooms=Rooms})->
    [R_info]=get_room(Room,Rooms),
    {reply, ok, State#state{rooms=update_room(R_info#room_info{status=?EMPTY,type=undefined}, Rooms)}};
    
handle_call({get_opr, Type, Params}, _From, State=#state{rooms=Rooms})->
    case proplists:get_value("room", Params) of
    undefined->
        case get_inservice_room(Rooms, Type) of
            R_info=#room_info{no=No}->   {reply, {ok, No}, State#state{rooms=update_room(R_info#room_info{status=?BUSY}, Rooms)}};
            _-> {reply, 'sorry, operator is busy', State}
        end;
    _->
        No = room:room_atom(Params),
        case get_room(No, Rooms) of
            [R_info=#room_info{status=?INSERVICE}]->   
                {reply, {ok, No}, State#state{rooms=update_room(R_info#room_info{status=?BUSY}, Rooms)}};
            _-> {reply, 'sorry, operator is busy', State}
        end
    end;

handle_call({login, Client,Room, CmdList}, _From, State=#state{rooms=Rooms})->
    F = fun(R_info=#room_info{status=Status,no=No}, P) when Status == ?EMPTY;not is_pid(P) ->
             room:login(Room, Client, CmdList),
             Type = proplists:get_value("media_type", CmdList),
            {reply, {ok, No}, State#state{rooms=update_room(R_info#room_info{status=?INSERVICE, type=Type}, Rooms)}};
         (_,_)-> {reply, 'seat seizied already', State}
         end,
    case get_room(Room,Rooms) of
    [R_info=#room_info{no=No}]->
        F(R_info, whereis(No));
    []->
        {reply, room_not_exist, State}
    end;

handle_call(get_dt, _From, State=#state{dt=Dt})->
    {reply, Dt, State};
handle_call({set_dt, Dt}, _From, State=#state{dt=Dt0})->
    {reply, {old_dt, Dt0}, State#state{dt=Dt}};
handle_call(show_rooms, _From, State=#state{rooms=Rooms})->
    {reply, Rooms, State};
handle_call(_Msg, _From, State)->    {reply, ok, State}.


handle_cast(_Msg, State)->
    {noreply, State}.

handle_info(_Info, State=#state{}) ->
    {noreply, State}.    
    
code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(Reason, #state{})->
    Reason.

%%  some internal function
get_inservice_room(Rooms,Type)->
    case [R||R=#room_info{status=?INSERVICE, type=Type0}<-Rooms, Type0==Type] of
    [H|_]-> H;
    _-> none
    end.
free_room(No, Rooms)->
    [Room] = get_room(No, Rooms),
    update_room(Room#room_info{status=?INSERVICE},Rooms).
get_room(No, Rooms)->
    [R||R=#room_info{no=N}<-Rooms, N==No].
del_room(No, Rooms)->
    [Room] = get_room(No, Rooms),
    Rooms--[Room].
update_room(Room=#room_info{no=No}, Rooms)->
    del_room(No, Rooms)++[Room].
update_room(No,Status, Rooms)->
    [Room] = get_room(No, Rooms),
    del_room(No, Rooms)++[Room#room_info{status=Status}].
exist(Room,Rooms)->
    lists:any(fun(#room_info{no=I})-> I==Room end, Rooms).

room_status(No, Rooms)->
   [Room] = get_room(No, Rooms),
   Room#room_info.status.

exc_call(Cmd)->
    case whereis(?MODULE) of
    undefined-> start();
    _-> void
    end,
    gen_server:call(?MODULE, Cmd).

%%  some maintain function
set_dt(T)-> gen_server:call(?MODULE, {set_dt, T}).
get_dt()-> gen_server:call(?MODULE, get_dt).
