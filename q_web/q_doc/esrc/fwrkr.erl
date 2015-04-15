-module(fwrkr).
-compile(export_all).

-include("finfo.hrl").
-define(FPATH,"/data/fid/").

-define(WEBTIMEOUT,60000).

-record(fwk_st,{
	user,
	info,
	saved,
	fid,
	fh,
	tcount,
	fsize,
	rdpos,
	procid
}).

init([User,Fid,Info]) ->
	{ok,FH} = file:open(?FPATH++mkprefix(Fid),[write]),
	{ok,#fwk_st{user=User,fid=Fid,fh=FH,tcount=1,fsize=0,info=Info,saved=[]},?WEBTIMEOUT};
init([User,Ref,Fid,Info]) ->
	case file:open(?FPATH++mkprefix(Fid),[read,binary,raw]) of
		{ok,FH} ->
			User ! {ok,Ref,self(),Info},
			{ok,#fwk_st{user=User,info=Info,fid=Fid,fh=FH,rdpos=0,saved=[]},?WEBTIMEOUT};
		{error,_Reason} ->
			ignore
	end.

handle_info({file_read_chunk,Ref,From,Fid,{Pos,Nums}},#fwk_st{user=_U,fid=Fid,fh=FH}=ST) ->		% user is not available
	case file:pread(FH,Pos,Nums) of
		{ok,Bin} ->
			From ! {ok,Ref,self(),Bin},
			{noreply,ST#fwk_st{rdpos=Pos},?WEBTIMEOUT};
		eof ->
			From ! {ok,Ref,self(),eof},
			file:close(FH),
			{stop,normal,ST#fwk_st{fid=undefined,fh=undefined}};
		{error,_Reason} ->
			From ! {ok,Ref,self(),error},
			{stop,normal,ST#fwk_st{fh=undefined}}
	end;
	
handle_info({file_upload,Ref,From,_Fname,NInfo},#fwk_st{fid=undefined,info=Info}=ST) ->
	{ok,Fid} = my_server:call(sfid,get_fid),
	{ok,FH} = file:open(?FPATH++mkprefix(Fid),[write]),
	From ! {ok,Ref,self(),Fid},
	{noreply,ST#fwk_st{fid=Fid,fh=FH,tcount=1,fsize=0,info=Info++NInfo},?WEBTIMEOUT};
handle_info({file_chunk,Ref,From,Fid,{Tc,Bin}},#fwk_st{user=From,fid=Fid,fh=FH,tcount=Tc,fsize=Fsize}=ST) ->
	ok = file:write(FH,Bin),
	From ! {ok,Ref,self(),Fid},
	{noreply,ST#fwk_st{tcount=Tc+1,fsize=Fsize+size(Bin)},?WEBTIMEOUT};
handle_info({file_done,Ref,From,Fid,{Flen1,NInfo}},#fwk_st{user=From,fh=FH,fid=Fid,fsize=Flen2,saved=Saved,info=Info}=ST) ->
	if
		Flen1==Flen2 ->
			ok = file:close(FH),
			ProcId =if
					ST#fwk_st.procid==undefined -> Fid;
					true -> ST#fwk_st.procid
				end,
			Fname=get_key(fname,Info++NInfo,""),
			Owner=get_key(owner,NInfo,0),
			Desc =get_key(desc,NInfo,""),
			TS = get_key(fts,NInfo,"2012-12-22 0:0:0"),
			FInfo = #finfo{fid=Fid,fname=Fname,flength=Flen2,ts=TS,owner=Owner,proc=ProcId,desc=Desc},
			ok = my_server:call(sfid,{ok_file,Fid,FInfo}),
			From ! {ok,Ref,self(),Fid},
			{noreply,ST#fwk_st{fid=undefined,fh=undefined,procid=ProcId,saved=[FInfo|Saved],info=Info++NInfo},?WEBTIMEOUT};
		true ->
			ok = file:close(FH),
			file:delete(?FPATH++mkprefix(Fid)),
			From ! {error,Ref,bad_len},
			{noreply,ST#fwk_st{fid=undefined,fh=undefined},?WEBTIMEOUT}
	end;
handle_info({file_svcs_end,Ref,From,Owner,_Share},#fwk_st{user=From,fid=undefined,saved=[]}=ST) ->
	From ! {ok,Ref,self(),Owner},
	{stop,normal,ST#fwk_st{saved=[]}};
handle_info({file_svcs_end,Ref,From,Owner,Share},#fwk_st{user=From,fid=undefined,saved=Saved}=ST) ->
	my_server:call(sfid,{end_svcs,Owner,[Fid||#finfo{fid=Fid}<-Saved],Share}),
	From ! {ok,Ref,self(),Owner},
	{stop,normal,ST#fwk_st{saved=[]}};
handle_info({file_abort,Ref,From,Fid,_},#fwk_st{user=From,fid=Fid,fh=FH}=ST) ->
	ok = file:close(FH),
	file:delete(?FPATH++mkprefix(Fid)),
	From ! {ok,Ref,self(),Fid},
	{noreply,ST#fwk_st{fid=undefined,fh=undefined},?WEBTIMEOUT};
handle_info(timeout,ST) ->
	cleartmpfile(ST),
  	{stop,normal,ST#fwk_st{fh=undefined}}.

handle_call(list,_From,ST) ->
	{reply,ST,ST}.

terminate(normal,_) ->
	my_server:cast(sfid,{wrkr_down,self()}),
	ok.

% ----------------------------------
cleartmpfile(#fwk_st{fh=FH,fid=Fid}) ->
	if
		FH=/=undefined ->
			file:close(FH),
			file:delete(?FPATH++mkprefix(Fid));
		true ->
			ok
	end.

mkprefix(Fid) -> integer_to_list(Fid);
mkprefix(Fid) ->
	int6(Fid).
	
get_key(Key, KVs, Default) ->
    case lists:keysearch(Key, 1, KVs) of
        {value, {_, Val}} ->
            Val;
        _ ->
            Default
    end.
    
int2(I) ->
	int2str(I,2).
int6(I) ->
	int2str(I,6).
int8(I) ->
	int2str(I,8).

divwith(N, S) ->
	{S div N, S rem N}.

int2str(I, Len) when is_integer(Len) ->
	int2str(I, Len, "");
int2str(I, L) when is_list(L) ->
	int2str(I, length(L)).
	
int2str(_, 0, R) ->
	R;
int2str(I, Len, R) ->
	{I2, I1} = divwith(10, I),
	R2 = integer_to_list(I1) ++ R,
	int2str(I2, Len-1, R2).

iots() ->
	{H,M,S} = time(),
	int2(H)++":"++int2(M)++":"++int2(S).
% ----------------------------------
start(User,FID,Info) ->
	{ok,Pid} = my_server:start(fwrkr,[User,FID,Info],[]),
	Pid.
start(User,Ref,FID,Info) ->
	{ok,Pid} = my_server:start(fwrkr,[User,Ref,FID,Info],[]),
	Pid.
deletefile(Fid) ->
	file:delete(?FPATH++mkprefix(Fid)).
