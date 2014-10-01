-define(APPLY(MOD,FUN,ARGS,Other),  (fun()->
                                                            F = fun()-> apply(MOD,FUN,ARGS) end,
                                                            if(MOD == erl_g729 andalso FUN==xdtr) orelse(MOD==erl_g729 andalso FUN==icdc) ->
                                                                app_manager:exec_cmd(F);
                                                            true-> F()
                                                            end
                                                         end)()
                                                      ).
-define(APPLY(MOD,FUN,ARGS), ?APPLY(MOD,FUN,ARGS,[])).
           
           
