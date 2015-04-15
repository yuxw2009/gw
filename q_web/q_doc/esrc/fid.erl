-module(fid).
-compile(export_all).

-define(FIDFILE,"./fid.dat").
-define(UFFILE,"./uid.dat").

-define(SvrTimeout,2000).
-include("finfo.hrl").

-record(f_st, {
	last,
	tab,
	ufi,
	wkr
}).

init([]) ->
	Finfo=ets:new(finfo,[ordered_set,{keypos,2}]),
	initETS(Finfo,?FIDFILE),
	Uinfo=ets:new(uinfo,[ordered_set,{keypos,1}]),
	initUFI(Uinfo,?UFFILE),
	{ok,#f_st{last=lastFID(Finfo),tab=Finfo,ufi=Uinfo,wkr=[]}}.

handle_info({list_owner,Ref,From,Owner,FIDs},#f_st{tab=Finfo,ufi=Uinfo}=ST) ->
	{ok,My,Shrd} = listowner(Owner,FIDs,Uinfo,Finfo),
	List=lists:sort(fun(X1,X2)-> element(8,X1) > element(8,X2) end,My++Shrd),
	From ! {ok,Ref,Owner,List},
	{noreply,ST};
handle_info({share_file,Ref,From,Owner,FIDs,UIDs},#f_st{ufi=UFI}=ST) ->
%	case ismyfile(Owner,FIDs,UFI) of
%		true ->
%			Fwdts=makets(),
%			uu_add_shared(UFI,UIDs,[{Fid,Owner,Fwdts}||Fid<-lists:sort(FIDs)]),
%			recuinfo(UFI),
%			alert_share(Owner,UIDs,FIDs,Fwdts,ST#f_st.tab),
			From ! {ok,Ref},
%		false ->
%			From ! {error,security}
%	end,
	{noreply,ST};

handle_info({file_upload,Ref,From,_,Info},#f_st{last=LastId,wkr=Wkr}=ST) ->
	Wrkr = fwrkr:start(From,LastId,Info),
	From ! {ok,Ref,Wrkr,LastId},
	{noreply,ST#f_st{last=LastId+1,wkr=[{LastId,Wrkr}|Wkr]}};

handle_info({file_download,Ref,From,FID,_},#f_st{tab=Tab,wkr=Wkr}=ST) ->
	case ets:lookup(Tab,FID) of
		[] ->
			From ! {error,Ref,fid_not_found},
			{noreply,ST};
		[Fi] ->
			Wrkr = fwrkr:start(From,Ref,FID,[{owner,Fi#finfo.owner},{fname,Fi#finfo.fname}]),
			{noreply,ST#f_st{wkr=[{FID,Wrkr}|Wkr]}}
	end;
handle_info({delete_file, Ref,From,FID,_}, #f_st{tab=Finfo,ufi=Uinfo}=ST) ->
	case get_own(FID,Finfo) of
		notfound ->
			From ! {error, Ref,file_not_exist};
		Owner ->
			case fwrkr:deletefile(FID) of
				ok ->
					ets:delete(Finfo,FID),
					rmv_userfid(FID,Uinfo),
					recfinfo(Finfo),
					recuinfo(Uinfo),
					From ! {ok,Ref,Owner,[]};
				{error,Rea} ->
					From ! {error, Ref, Rea}
			end
	end,
	{noreply,ST}.

handle_cast({wrkr_down,Wrkr},#f_st{wkr=Wkr}=ST) ->
	NWkr =case lists:keysearch(Wrkr,2,Wkr) of
			false ->
				io:format("~p bu ke neng.~n",[Wrkr]),
				Wkr;
			{value,{Fid,_}} ->
				lists:delete({Fid,Wrkr},Wkr)
		end,
	{noreply,ST#f_st{wkr=NWkr}}.
	
handle_call(get_fid,_From,#f_st{last=LastId}=ST) ->
	{reply,{ok,LastId},ST#f_st{last=LastId+1}};
handle_call({ok_file,_Fid,NewFinfo},_From,#f_st{tab=Tab}=ST) ->
	ets:insert(Tab,NewFinfo),
	insfinfo(NewFinfo),
	{reply,ok,ST};
handle_call({end_svcs,Owner,FIDs,Share},_From,#f_st{tab=Tab,ufi=UFI}=ST) ->
	uu_add_file(UFI,Owner,FIDs),
%	uu_add_shared(UFI,Share,[{Fid,Owner,filets(Fid,Tab)}||Fid<-lists:sort(FIDs)]),
%	recuinfo(UFI),
%	alert_share(Owner,Share,FIDs,makets(),ST#f_st.tab),
	{reply,ok,ST};
handle_call(list,_From,ST) ->
	{reply,ST,ST}.

% ----------------------------------
listowner(UID,all,Uinfo,Finfo) ->
	case ets:lookup(Uinfo,UID) of
		[] ->
			{ok,[],[]};
		[{_,My,Shrd}] ->
			{ok,[getfinfo(Fid,Finfo,UID,copyts)||Fid<-My],
				[getfinfo(Fid,Finfo,Fwdby,Fwdts)||{Fid,Fwdby,Fwdts}<-Shrd]}
	end;
listowner(UID,FIDs,Uinfo,Finfo) ->
	case ets:lookup(Uinfo,UID) of
		[] ->
			{ok,[],[]};
		[{_,My,Shrd}] ->
			{ok,[getfinfo(Fid,Finfo,UID,copyts)||Fid<-My,lists:member(Fid,FIDs)],
				[getfinfo(Fid,Finfo,Fwdby,Fwdts)||{Fid,Fwdby,Fwdts}<-Shrd,lists:member(Fid,FIDs)]}
	end.

getfinfo(Fid,Finfo,Fwdby,Fwdts) ->
	case ets:lookup(Finfo,Fid) of
		[] -> io:format("bu ke neng!~n");
		[{_,DocId,Name,Length,Ts,Owner,_,Desc}] ->
			if
				Fwdts == copyts ->
					{Owner,Fwdby,Name,DocId,Desc,Length,Ts,Ts};
				true ->
					{Owner,Fwdby,Name,DocId,Desc,Length,Ts,Fwdts}
			end
	end.
get_own(FID,Finfo) ->
	case ets:lookup(Finfo,FID) of
		[] -> notfound;
		[#finfo{owner = Owr}] ->
			Owr
	end.
		
rmv_userfid(FID,Uinfo) ->
	rmv_userfid(FID,ets:first(Uinfo),Uinfo).
rmv_userfid(_,'$end_of_table',_Uinfo) ->
	ok;
rmv_userfid(FID, Key, Uinfo) ->
	[{Key,My,Shrd}] = ets:lookup(Uinfo,Key),
	ets:insert(Uinfo,{Key,[Fid||Fid<-My,Fid=/=FID],[{Fid,Fwd,Fts}||{Fid,Fwd,Fts}<-Shrd,Fid=/=FID]}),
	rmv_userfid(FID, ets:next(Uinfo,Key), Uinfo).

filets(Fid,Finfo) ->
	case ets:lookup(Finfo,Fid) of
		[] -> "bu ke neng!";
		[{_,_DocId,_Name,_Length,Ts,_Owner,_,_Desc}] -> Ts
	end.

ismyfile(Owner,FIDs,UFI) ->
	MyFils= case ets:lookup(UFI,Owner) of
			[] -> [];
			[{_,My,Shrs}] -> My++[Fid||{Fid,_Fwdby,_Fwdts}<-Shrs]
		end,
	ismyfile(MyFils,FIDs).
ismyfile(_Fils,[]) -> true;
ismyfile(Fils,[Fid|T]) ->
	case lists:member(Fid,Fils) of
		true ->
			ismyfile(Fils,T);
		false ->
			false
	end.
	
alert_share(Fwdby,UIDs,FIDs,Fwdts,Finfo) ->
	alert_share(Fwdby,UIDs,[getfinfo(Fid,Finfo,Fwdby,Fwdts)||Fid<-FIDs]).
	
alert_share(Own,UIDs,FIs) ->
	lw_document:send2UUs(Own,UIDs,{doc_service,share,FIs}).

uu_add_file(UFI,UU,FIDs) ->
	case ets:lookup(UFI,UU) of
		[] ->
			ets:insert(UFI,{UU,FIDs,[]});
		[{_,MyFile,Shared}] ->
			ets:insert(UFI,{UU,MyFile++FIDs,Shared})
	end.

uu_add_shared(_UFI,[],_FIDs) ->
	ok;
uu_add_shared(UFI,[UU|Rest],FIDs) ->
	case ets:lookup(UFI,UU) of
		[] ->
			ets:insert(UFI,{UU,[],FIDs});
		[{_,MyFile,Shared}] ->
			ets:insert(UFI,{UU,MyFile,lists:merge(Shared,FIDs)})
	end,
	uu_add_shared(UFI,Rest,FIDs).

initETS(Finfo,FILE1) ->
	case file:consult(FILE1) of
		{ok,Conts} ->
			ets:insert(Finfo,Conts);
		{error,_} ->
			ok
	end.
initUFI(Uinfo,FILE2) ->
	initETS(Uinfo,FILE2).
	
lastFID(Finfo) ->
	case ets:last(Finfo) of
		'$end_of_table' ->
			1;				% begin at 1, 0 standfor invalid
		Key ->
			Key+1
	end.

insfinfo(#finfo{fid=FId,fname=Fname,flength=Flen,ts=TS,owner=Owner,proc=Proc,desc=Desc}) ->
	{ok,FH}=file:open(?FIDFILE,[append]),
	ok=io:fwrite(FH,"{finfo,~p,~p,~p,~p,~p,~p,~p}.\n",[FId,Fname,Flen,TS,Owner,Proc,Desc]),
	file:close(FH).

recuinfo(UETS) ->
	List=ets:tab2list(UETS),
	{ok,FH}=file:open(?UFFILE,[write]),
	recuinfo(FH,List),
	file:close(FH).
recuinfo(_,[]) ->
	ok;
recuinfo(FH,[{UU,My,Shrd}|T]) ->
	io:fwrite(FH,"{~p,~p,~p}.\n",[UU,My,Shrd]),
	recuinfo(FH,T).

recfinfo(FETS) ->
	List=ets:tab2list(FETS),
	{ok,FH}=file:open(?FIDFILE,[write]),
	recfinfo(FH,List),
	file:close(FH).
recfinfo(_,[]) ->
	ok;
recfinfo(FH,[#finfo{fid=FId,fname=Fname,flength=Flen,ts=TS,owner=Owner,proc=Proc,desc=Desc}|T]) ->
	ok=io:fwrite(FH,"{finfo,~p,~p,~p,~p,~p,~p,~p}.\n",[FId,Fname,Flen,TS,Owner,Proc,Desc]),
	recfinfo(FH,T).

makets() ->
	dt2str({date(),time()}).

dt2str({D, T}) ->
	d2str(D) ++ " " ++ t2str(T).

t2str({H, M, S}) ->
	int2(H) ++ ":" ++ int2(M) ++ ":" ++ int2(S).
	
d2str({Y, M, D}) ->
	"20"++int2(Y) ++ "-" ++ int2(M) ++ "-" ++ int2(D).

int2(I) ->
	int2str(I,2).

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
% ----------------------------------
start() ->
	{ok,Pid} = my_server:start(fid,[],[]),
	register(sfid,Pid).

req_fsvcs({CC,ID,Params}) ->
    Ref=make_ref(),
    sfid ! {CC,Ref,self(),ID,Params},
    receive
        {ok,Ref,Who,Msg} ->
            {ok,Who,Msg};
        {error,Ref,Reason} ->
            {error,Reason}
    after ?SvrTimeout ->
        {error, timeout}
    end.
