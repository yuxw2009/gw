-include_lib("stdlib/include/qlc.hrl").
-define(DB_OP(Operation),
      (mnesia:transaction(fun()-> (Operation)  end))).
-define(DB_READ(T,K), ?DB_OP(mnesia:read(T, K))).
-define(DB_WRITE(R), ?DB_OP(mnesia:write(R))).
-define(DB_DELETE(T_K), ?DB_OP(mnesia:delete(T_K))).
-define(DB_QUERY(T), ?DB_OP(qlc:e(qlc:q([X||X<-mnesia:table(T)])))).

