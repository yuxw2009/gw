-module(conversation).
-compile(export_all).
-behaviour(gen_server).
-record(state, {name, clients=[]}).

-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).



handle(<<"create">>, ConnId, Params)->
    io:format("conversation create connid:~p Params:~p~n", [ConnId, Params]),
    Name=proplists:get_value("name", Params),
    create(Name),
    Result=join_room(Name, ConnId),
    utility:pl2jso([{status,Result},{name, Name}]);
handle(<<"join">>, ConnId, Params)->
    io:format("conversation join connid:~p Params:~p~n", [ConnId, Params]),
    Name=proplists:get_value("name", Params),
    Result=join_room(Name, ConnId),
    utility:pl2jso([{status,Result},{name, Name}]);
handle(<<"message">>, ConnId, Params)->
    Event=proplists:get_value("type", Params),
    handle_message(Event,ConnId, Params).

handle_message(Event, ConnId, Params)-> 
%    io:format("up msg: Event:~p  ConnId:~p  params:~p~n", [Event, ConnId, Params]),
    NewParams=[{from, ConnId}|Params],
    message(Event, ConnId, NewParams),
    utility:pl2jso([{status,ok}]).


message(Event, Client, Params)->
    Room_bin= proplists:get_value("to", Params),
    Room=list_to_atom(binary_to_list(Room_bin)),
    gen_server:call(Room, {message,Client, Params}).
    

create(Name) when is_binary(Name)-> create(list_to_atom(binary_to_list(Name)));
create(Name)->
    case whereis(Name) of
        undefined->
            {ok, Pid} = gen_server:start({local, Name}, ?MODULE, {Name},[]),
            Pid;
        P-> P
    end.
        
join_room(Room, Client) when is_binary(Room)-> join_room(list_to_atom(binary_to_list(Room)), Client);
join_room(Room, Client)->
    case whereis(Room) of
    undefined->
        fail;
    _->
        gen_server:call(Room, {join, Client,Room})
    end.

stop(Name)->
     case whereis(Name) of
        undefined-> 
            void;
        _->
         gen_server:call(Name, {stop})
    end.

%%   callback for gen_server
init({Name})->
    {ok, #state{name=Name}}.
handle_call({join, Client,Room}, From, State=#state{clients=Clients})->
    NewClients = [Client|Clients],
    [xhr_poll:down(Clt, [{event,joined},{room, Room},{id, Room}]) || Clt<-Clients],
    NewState = State#state{clients=NewClients},
    {reply, ok, NewState};

handle_call({message, Client, Params}, From, State=#state{clients=Clients})->
    OtherClients = Clients -- [Client],
    [xhr_poll:down(Clt, Params) || Clt<-OtherClients],
    {reply, ok, State};
    
handle_call({stop}, From, State)->
    {stop, {stop_from, From}, State};
handle_call(_Msg, _From, State)->
    {reply, ok, State}.
handle_cast(_Msg, State)->
    {noreply, State}.

handle_info(Info, State=#state{}) ->
    {noreply, State}.    
    
code_change(_Oldvsn, State, _Extra)->
    {ok, State}.
    
terminate(Reason, #state{})->
    Reason.



get_video_server_ip() ->
    "http://10.61.34.51/".

