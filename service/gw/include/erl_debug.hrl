% -define(APPLY(MOD,FUN,ARGS,Other),  (fun()->
%                                                             F = fun()-> apply(MOD,FUN,ARGS) end,
%                                                             Mod_for_warning=MOD,
%                                                             if(Mod_for_warning == erl_g729 andalso FUN==xdtr) orelse(Mod_for_warning==erl_g729 andalso FUN==icdc) ->
%                                                                 app_manager:exec_cmd(F);
%                                                             true-> F()
%                                                             end
%                                                          end)()
%                                                       ).
-define(APPLY(MOD,FUN,ARGS), ?APPLY(MOD,FUN,ARGS,[])).
-define(APPLY(MOD,FUN,ARGS,Other), apply(MOD,FUN,ARGS)).
           
           
