-module(fate_service).
-define(FATE_DIRECTORY,"./fate").
-define(ERROR_LOG,"./error/log.dat").
-export([start/0,inquiry/1,lookup/3]).
start() ->
    register(?MODULE,spawn(fun() -> init() end)).
%% system init %%
init() ->
    FateService = build_fate_service(),
    case is_build_fail(FateService) of
	    true ->
		    io:format("fate service start fail!~n");
		false ->
		    io:format("fate service start succ!~n"),
			loop(FateService)
	end.
%% build fate service %%
build_fate_service() ->
 	{ok,FileNames} = file:list_dir(?FATE_DIRECTORY),
	dict:from_list([{filename:basename(FileName,".dat"),build_code_trie(FileName)}||FileName<-FileNames]).
%% build code tree %%
build_code_trie(FileName) ->
    io:format("building trie by ~p,please wait!~n",[FileName]),
	Items = disk_to_item(FileName),
	Trie  = prefix_trie:new(Items),
	case is_trie_error(Trie,Items) of
	    false ->
		    Trie;
		true ->
		    io:format("~p error!~n ",[FileName]),
			false
	end.
%% translate disk content to item
disk_to_item(FileName) ->
    AbsFileName  = filename:absname(FileName,?FATE_DIRECTORY),
    {ok,Binary} = file:read_file(AbsFileName),
	String      = binary_to_list(Binary),
	parse_str(String,",","/","\r\n").
parse_date(Date,DivChar) ->
    [Y,M,D] = string:tokens(Date,DivChar),
	{list_to_integer(Y),list_to_integer(M),list_to_integer(D)}.
parse_str(Str,EleDivChar,DateDivChar,SectionDivChar) ->
    F = fun(_Section,_EleDivChar,_DateDivChar) ->
	        [Prefix,Country,Fee,DateStr] = string:tokens(_Section,_EleDivChar),
			{Y,M,D} = parse_date(DateStr,_DateDivChar),
			{Prefix,{Country,Fee,{Y,M,D}}}
		end,
	[F(Section,EleDivChar,DateDivChar)||Section<-string:tokens(Str,SectionDivChar)].
%% check fate service build correct? %%	
is_build_fail(FateService) ->
    lists:any(fun({_Key,Value}) -> Value =:= false end,dict:to_list(FateService)).
%% check trie build succ or fail
is_trie_error(Trie,Items) ->
    lists:any(fun(X) -> X =:= false end,[check_one_item(Trie,Item)||Item<-Items]). 
check_one_item(Trie,{Prefix,_}) ->
	{SavePrefix,Values} = prefix_trie:find_max_prex(Prefix,Trie),
	case length(Values) =:= length(lists:ukeysort(3,Values)) of
	    true ->
			true;
		false ->
			io:format("error:~p~n",[{SavePrefix,Values}]),
			false
	end.
%% loop %%
loop(FateService) ->
    receive
	    Msg ->
		    dispatch_event(Msg,FateService),
			loop(FateService)
	end.
%% about handle msg %%
dispatch_event({From,{lookup,BillId,Phone1,Phone2}},FateService) ->
    worker_without_feedback(?MODULE,inquiry,{From,BillId,Phone1,Phone2,{2012,1,1},FateService});
%% about unknown msg %%
dispatch_event(UnExpectedMsg,_FateService) ->
    spawn(fun() -> write_error_log("receive unexpected msg",UnExpectedMsg) end).
%% write error log %%
write_error_log(Event,Content) ->
    {ok,S} = file:open(?ERROR_LOG,[append]),
	io:format(S,"Time:~p,Event:~p,Content:~p.~n",[calendar:local_time(),Event,Content]),
	file:close(S).
%% protocol with monitor process %%
worker_without_feedback(Module,Fun,{From,BillId,Phone1,Phone2,{2012,1,1},FateService}) ->
    {Pid,Ref} = spawn_monitor(Module,Fun,[{From,BillId,Phone1,Phone2,{2012,1,1},FateService}]),
	receive
	    {'DOWN',Ref,process,Pid,normal} ->
		    ok;
		{'DOWN',Ref,process,Pid,Other} ->
		    spawn(fun() -> write_error_log(Fun,{{From,BillId,Phone1,Phone2,{2012,1,1},FateService},Other}) end),
		    From ! {ok,{Phone1,""},{Phone2,""}}
	after 1000 ->
	    spawn(fun() -> write_error_log(Fun,timeout) end),
	    From ! {ok,{Phone1,""},{Phone2,""}}
	end.
%% inquiry fate %%
inquiry({From,BillId,Phone1,Phone2,Date,FateService}) ->
	FPhone1 = string:substr(Phone1,3),
	FPhone2 = string:substr(Phone2,3),
    Result = 
	    case dict:find(BillId,FateService) of
	        error ->
			    {ok,{Phone1,""},{Phone2,""}};
		    {ok,Trie} ->
		    	{_,Phone1Rate,_} = 
			        case prefix_trie:find_max_prex(FPhone1,Trie) of
						{"",[]} ->
							{"","",""};
						{_,Fees1} ->
							get_fee(Fees1,Date)
					end,
				{_,Phone2Rate,_} = 
			        case prefix_trie:find_max_prex(FPhone2,Trie) of
						{"",[]} ->
							{"","",""};
						{_,Fees2} ->
							get_fee(Fees2,Date)
					end,
				{ok,{Phone1,Phone1Rate},{Phone2,Phone2Rate}}
	    end,
	From ! Result.
%% get closet fee %%
get_fee(Fees,QDate) ->
    case [{Country,Fee,Date}||{Country,Fee,Date}<-Fees,Date =< QDate] of
	    [] ->
		    {"","",""};
		Less ->
		    lists:last(Less)
	end.

%% look up %%
lookup(BillId,Phone1,Phone2) ->
    ?MODULE ! {self(),{lookup,BillId,Phone1,Phone2}},
    receive
        X ->
            X
    end.