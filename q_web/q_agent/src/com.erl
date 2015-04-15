-module(com).
-compile(export_all).
-include_lib("kernel/include/file.hrl").

start()->
    c:cd(app_mod), 
    case whereis(com) of
    undefined->    register(com, spawn(fun()-> loop() end));
    _->void
    end.
stop()-> exit(whereis(com),kill).    

loop()->
    case catch  ?MODULE:com_load_test() of
    {'EXIT', Reason}->
        io:format("exception:reason:~p~n", [Reason]);
    _-> void
    end,
    delay(5000),
    ?MODULE:loop().


delay(T)->
    receive
        impossible-> void
    after T->
        timeout
    end.
com_load_test()->
    case length(com_load()) > 0 of
    true->
        F=fun(M)->  M:test() end,
        [F(M)||M<-all_test_modules()];
    false-> void
    end.
     
com_load()->
    MS=out_of_date(), 
    com(),
    reload(MS),
    MS.
com()->
    make:all().
    

all_test_modules()-> [M||M<-all_modules(),lists:member({test,0},M:module_info(exports)) ==true].
all_modules()->
    {ok, Files}=file:list_dir("ebin"),
    Files1 = lists:filter(fun(F)-> suffix(F,".beam") end, Files),
    BaseFiles = lists:map(fun(F)-> lists:sublist(F,1, length(F)-length(".beam")) end, Files1),
    [list_to_atom(I)||I<-BaseFiles].
        
out_of_date()-> 
    [list_to_atom(I)||I<-lists:merge([out_of_date(I,O,".erl",".beam")||{I,O}<-in_out_dir()])].

in_out_dir()-> 
    {ok,Ls} = file:consult("Emakefile"),
    [{lists:sublist(Src,1,length(Src)-1),proplists:get_value(outdir,Ps)}||{Src,Ps}<-Ls].

out_of_date(InDir,OutDir, In, Out) ->
         case file:list_dir(InDir) of 
             {ok, Files0} ->
                 Files1 = lists:filter(fun(F) -> 
                                    suffix(F,In) 
                                end, Files0),
                 Files2 = lists:map(fun(F) -> 
                                  lists:sublist(F, 1, 
                                          length(F)-length(In)) 
                             end, Files1),
                 lists:filter(fun(F) -> update(InDir++F++In, OutDir++F++Out) end,Files2);
             _ ->
                 []
         end. 

suffix(F,In)-> filename:extension(F)==In.         
update(InFile, OutFile) ->
         case is_file(OutFile) of
             true ->
                 case writeable(OutFile) of
                     true ->
                         outofdate(InFile, OutFile);
                     false ->
                         %% can't write so we can't update
                         false
                 end;
             false ->
                 %% doesn't exist
                 true
         end.

is_file(File) ->
         case file:read_file_info(File) of
             {ok, _} ->
                 true;
             _ ->
                 false
         end.


writeable(F) -> 
         case file:read_file_info(F) of
             {ok, #file_info{access=read_write}} -> true;
             {ok, #file_info{access=write}} -> true;
             _ -> false
         end.

outofdate(In, Out) -> 
         case {last_modified(In), last_modified(Out)} of
             {T1, T2} when T1 > T2 ->
                 true;
             _ ->
                 false
         end.
         
last_modified(F) ->
         case file:read_file_info(F) of
             {ok, #file_info{mtime =Time}} ->
                 Time;
             _ ->
                 exit({last_modified, F})
         end.         

%%  utility tools
reload()-> reload(?MODULE).
reload(MODS)->
	make:all(),
	F= fun(I)-> 
		code:purge(I),
		code:load_file(I)
	end,
	MODS1 = case MODS of
			_ when is_list(MODS)->	MODS;
			_ when is_atom(MODS)-> [MODS]
		end,
	[F(I) || I<-MODS1].         
