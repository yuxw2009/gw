-include_lib("stdlib/include/qlc.hrl").
-define(DB_OP(Operation),
      (mnesia:transaction(fun()-> (Operation)  end))).
-define(DB_READ(T,K), ?DB_READ({T,K})).
-define(DB_READ(T_K), ?DB_OP(mnesia:read(T_K))).
-define(DB_WRITE(R), ?DB_OP(mnesia:write(R))).
-define(DB_DELETE(T,K), ?DB_DELETE({T,K})).
-define(DB_DELETE(T_K), ?DB_OP(mnesia:delete(T_K))).
-define(DB_QUERY(T), (fun()-> 
                                           QH1=(qlc:q([X||X<-mnesia:table(T)])),
                                           QH2 = qlc:keysort(2, QH1, [{order, ascending}]), 
                                           ?DB_OP(qlc:e(QH2)) 
                                     end)()).
-define(DB_QUERY(T,Detail,Cond), (fun()-> 
                                           QH1=(qlc:q([X||X=#T Detail<-mnesia:table(T),Cond])),
                                           QH2 = qlc:keysort(2, QH1, [{order, ascending}]), 
                                           ?DB_OP(qlc:e(QH2)) 
                                     end)()).
-define(DB_QUERY_4_Key_Item(T,Cond), (fun()-> 
                                          ?DB_QUERY_4_Key_Item(T,Cond,[{order, ascending}])
                                     end)()).
-define(DB_QUERY_4_Key_Item(T,Cond,Sort), (fun()-> 
                                           QH1=(qlc:q([X||X<-mnesia:table(T),Cond])),
                                           QH2 = qlc:keysort(2, QH1, Sort), 
                                           ?DB_OP(qlc:e(QH2)) 
                                     end)()).
-define(TUPLES2PLIST(T,Rds),  (fun()-> Lists=[tuple_to_list(I)||I<-Rds], [lists:zip(record_info(fields,T),Tail)||[_|Tail]<-Lists] end)() ).
-define(MNESIA2PLIST(T),  (fun()-> {atomic, Rds}=?DB_QUERY(T),(?TUPLES2PLIST(T,Rds)) end)()).

