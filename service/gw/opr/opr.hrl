-record(opr,{seat_no,item=#{user=>"",group_no=>""}}).
-record(oprgroup_t,{key,item=#{phone=>"",mergeto=>[]}}).

-define(REC_MatchMsg(Exp),   (fun()-> receive  M=Exp-> M  after 200->         timeout    end end)()).
