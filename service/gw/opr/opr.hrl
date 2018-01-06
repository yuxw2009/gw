-record(seat_t,{seat_no,item=#{user=>"",group_no=>""}}).
-record(opr_t,{oprId,item=#{msg_to_send=>[],vips=>[],msg_history=>[]}}). %msg:#{"msgType":= <<"message">>,"seat1Id":=Seat1Id,"seat2Id":=Seat2Id,"msg":=Msg}
-record(oprgroup_t,{key,item=#{phone=>"",mergeto=>[]}}).

-define(REC_MatchMsg(Exp),   (fun()-> receive  M=Exp-> M  after 200->         timeout    end end)()).
