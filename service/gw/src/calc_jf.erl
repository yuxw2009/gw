-module(calc_jf).
-compile(export_all).
-include_lib("kernel/include/file.hrl").

jfnum(Date)->jfnum(Date,".").
jfnum(Date,Dir)->
	F=fun(Fn)->
	      {ok, Re} = re:compile("\"(\\d+)\",\"\\d+\",\"1\",\"\\d+\",.*",[ungreedy]),
	      {_,Value}=file:read_file(Fn),
	      Result=
	      case re:run(Value, Re, [global,{capture, all_but_first, binary}]) of
	      	{match,Res}-> Res;
	      	_-> []
	      end,
	      (lists:concat(Result))
	    end,
	{ok,Fns0}=file:list_dir(Dir),
	Fns=[Dir++"/"++Fn||Fn<-Fns0],
	Fns1=[Fn||Fn<-Fns,after_date(Fn,Date)],
	Res=[F(Fn)||Fn<-Fns1,filename:extension(Fn)==".log"],
	length(lists:usort(lists:concat(Res))).

mine_jfnum(Date)->
	F=fun(Fn)->
	      {_,Value}=file:read_file(Fn),
	      R=re:split(Value,"\r\n")
	    end,
	{ok,Fns}=file:list_dir("result"),
	Res=[F("result/"++Fn)||Fn<-Fns,filename:extension(Fn)==".txt",after_date("result/"++Fn,Date), string:str(Fn,"_ok.txt")>0],
	length(lists:usort(lists:concat(Res))).
 
after_date(Fn,Date)->
		      case file:read_file_info(Fn) of
		      	{ok,#file_info{mtime=CT}}-> CT>{Date,{0,0,0}};
		      	O->
		      	    io:format("file:~p notmatched~n~p~n~p~n",[Fn,O,#file_info{}])
		      	end.
