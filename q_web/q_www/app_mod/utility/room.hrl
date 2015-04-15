-define(EMPTY, empty).
-define(INSERVICE, inservice).
-define(BUSY, busy).
-record(room_info, {no, status=?EMPTY, type}).  % type: <<"video">>   <<"audio">>

