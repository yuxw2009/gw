-define(APPLY(MOD,FUN,ARGS,Other), (fun()->   
               C_Node = avscfg:get_node(MOD),
               case node() ==C_Node  of
               true->  
                   case proplists:get_value(monitor,Other) of
                   undefined-> 
	                   apply(MOD,FUN,ARGS);
                   Mon when is_pid(Mon)->
	                   apply(MOD,FUN,ARGS)
	             end;
               _->
                   Ack=case rpc:call(C_Node,MOD,FUN,ARGS) of
		                   {badrpc,_}->    badrpc;
		                   R-> R
		               end,
                   case whereis(statistic) of
	                   undefined->void;
	                   P->
                             if Ack==badrpc   -> 
                                  P ! {ccalls, {llog:ts(),Ack,[MOD,FUN,ARGS, ?MODULE,?LINE,Other]} };
                             {MOD,FUN}=={erl_g729,xenc} orelse {MOD,FUN}=={erl_g729,xdec} ->
                                  void; %P ! {ccalls, {llog:ts(),not_ack,[MOD,FUN, ?MODULE,?LINE,Other]} };
                             {MOD,FUN}=={erl_g729,xdtr} orelse {MOD,FUN}=={erl_g729,icdc} ->
                                 P ! {ccalls, {llog:ts(),Ack,[MOD,FUN,ARGS, ?MODULE,?LINE,Other]} };
                             true-> void
                             end
                   end,
                   Ack
               end
               end)()
           ).
-define(APPLY(MOD,FUN,ARGS), ?APPLY(MOD,FUN,ARGS,[])).
           
           
