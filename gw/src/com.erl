-module(com).
-compile(export_all).
-include_lib("kernel/include/file.hrl").
-define(CODE_DIR, "../").

set_code_dir(D)-> put(com_code_dir, D).
get_code_dir()-> 
    case get(com_code_dir) of
        undefined-> ?CODE_DIR;
        D-> D
    end.
test()->
    com_load(),
    cndd:test(),
    id_generator:test(),
    peerconn:test(),
    room:test(),
    room_topo:test().
    
com_load()->
    MS=out_of_date(), 
    com(),
    io:format("MS:~p~n",[MS]),
    reload(MS).
com()->
    {ok,Pwd} = file:get_cwd(),
    c:cd(get_code_dir()), 
    make:all(),  
    c:cd(Pwd),
    reload(com). 

out_of_date()-> 
    [list_to_atom(I)||I<-lists:merge([out_of_date(I,O,".erl",".beam")||{I,O}<-in_out_dir()])].

in_out_dir()-> 
    {ok,Ls} = file:consult(get_code_dir()++"Emakefile"),
    OutF = fun(Dir=[$/|_])-> string:strip(Dir,right,$/);
           (Dir)-> get_code_dir()++string:strip(Dir,both,$/)
       end,
    InF = fun(Src=[$/|_])-> lists:sublist(Src,1,length(Src)-2);
           (Src)-> get_code_dir()++lists:sublist(Src,1,length(Src)-1)
       end,
    [{InF(Src),OutF(proplists:get_value(outdir,Ps))}||{Src,Ps}<-Ls].

out_of_date(InDir,OutDir, In, Out) ->
         case file:list_dir(InDir) of 
             {ok, Files0} ->
                 Files1 = lists:filter(fun(F) -> 
                                    com:suffix(F,In) 
                                end, Files0),
                 Files2 = lists:map(fun(F) -> 
                                  lists:sublist(F, 1, 
                                          length(F)-length(In)) 
                             end, Files1),
                 lists:filter(fun(F) -> com:update(InDir++"/"++F++In, OutDir++"/"++F++Out) end,Files2);
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
                 io:format("~p not exist~n",[OutFile]),
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
