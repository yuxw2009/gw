-record(seat_t,{seat_no,item=#{user=>"",group_no=>""}}).
-record(opr_t,{oprId,item=#{msg_rcv=>[],vips=>[]}}). %msg:#{"msgType":= <<"message">>,"seat1Id":=Seat1Id,"seat2Id":=Seat2Id,"msg":=Msg}
-record(oprgroup_t,{key,item=#{phone=>"",mergeto=>[]}}).

-define(REC_MatchMsg(Exp),   (fun()-> receive  M=Exp-> M  after 200->         timeout    end end)()).
