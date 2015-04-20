-module(test).
-compile(export_all).
-include("nmsi_server.hrl").

login_binary() ->
    Cmd = "90000:1=\"kylintvboss\",2=\"13051506\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    list_to_binary([<<16#aa55aa55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]).

ss_login_binary() ->
    Cmd = "2100:1=\"root\",2=\"LIVECOMLAOSS\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    list_to_binary([<<16#aa55aa55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]).

logout_binary() ->
    NewCmd = "90001;",
    NewEID = <<0,0,0,0,0,0,0,$0>>,
    NewTID = 1,
    list_to_binary([<<16#aa55aa55:32>>,<<1:8>>,<<(39+length(NewCmd)):32>>,<<1:32>>,NewEID,<<NewTID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(NewCmd)]).

cmd_binary(Cmd) ->
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    list_to_binary([<<16#aa55aa55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]).

nmsi_login()->
    {ok,Socket} = gen_tcp:connect(nmsi_configure:ip(),nmsi_configure:port(),[binary,{packet,raw}]),
    put(socket,Socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,R1} ->
            io:format("nmsi login:~p~n",[R1]),
            {ok,Socket};
        {tcp_closed,Socket} ->
            tcp_closed
        after 2000->
            nmsi_login_timeout
    end.
ss_login()->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,ss_login_binary()),
    receive
        {tcp,Socket,R1} ->
            io:format("ss_login:~p~n",[R1]),
            {ok,Socket}
        after 2000->
            ss_login_timeout
    end.
create_sipreg_user() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,cmd_binary("CREATE_SIPREG_USER:CHECKBOX=0,NODEID=100,NUM=0,ISMODIFY=0,LATA=1,NET=1,SDN=\"1180662\",AHREALM=\"zte\",PASSWORD=\"Sqk2kiU5vk\",URL=\"sip:1180662@10.32.4.11\";")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

delete_sdn() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,_} ->
            ok
    end,
    ok = gen_tcp:send(Socket,cmd_binary("DELETE_SDN:NET=1,LATA=1,TAG=1,SDN1=\"1180662\";")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.
create_msn(Num,Subnum)->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,cmd_binary("CREATE_MSN:SUBNUM=\""++Subnum++"\";")), 
    receive
        {tcp,Socket,Bin} ->
            ok;
        {tcp_closed,Socket} ->
            tcp_closed
    end.

delete_msn(Subnum)->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,cmd_binary("DELETE_MSN:SUBNUM=\""++Subnum++"\";")), 
    receive
        {tcp,Socket,Bin} ->
            ok;
        {tcp_closed,Socket} ->
            tcp_closed
    end.
create_mixsub() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,_} ->
            ok
    end,
    ok = gen_tcp:send(Socket,cmd_binary("CREATE_MIXSUB:LATA=1,NET=1,DN=\"16505239912\",LRN=\"1180662\";")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

delete_mixsub() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,_} ->
            ok
    end,
    ok = gen_tcp:send(Socket,cmd_binary("DELETE_MIXSUB:DN=\"19173384397\";")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

modify_sub_attr_1() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,_} ->
            ok
    end,
    ok = gen_tcp:send(Socket,cmd_binary("MODIFY_SUB_ATTR:NET=1,LATA=1,SDN1=\"1180662\",NOTINUSE=1;")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

modify_sub_attr_0() ->
    Socket=get(socket),
    ok = gen_tcp:send(Socket,login_binary()),
    receive
        {tcp,Socket,_} ->
            ok
    end,
    ok = gen_tcp:send(Socket,cmd_binary("MODIFY_SUB_ATTR:NET=1,LATA=1,SDN1=\"1180662\",NOTINUSE=0;")), 
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,_:8/binary,_:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

wrong_msg_head() ->
    Socket=get(socket),
    Cmd = "90000:1=\"hangzhou\",2=\"xihu\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AAAAAA55:32>>,?MSG_MML_TYPE,<<(39+length(Cmd)):32>>,?MSG_VERSION,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90024:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

wrong_msg_type() ->
    Socket=get(socket),
    Cmd = "90000:1=\"hangzhou\",2=\"xihu\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<4:8>>,<<(39+length(Cmd)):32>>,?MSG_VERSION,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90023:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

wrong_msg_version() ->
    Socket=get(socket),
    Cmd = "90000:1=\"hangzhou\",2=\"xihu\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<3:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90021:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

login_wrong_pwd() ->
    Socket=get(socket),
    Cmd = "90000:1=\"hangzhou\",2=\"xihu\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90004:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

login() ->
    Socket=get(socket),
    Cmd = "90000:1=\"boss\",2=\"boss\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

relogin() ->
    Socket=get(socket),
    Cmd = "90000:1=\"boss\",2=\"boss\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,_} ->
            ok = gen_tcp:send(Socket,Msg),
            receive
                {tcp,Socket,Bin} ->
                    <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90002:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
                    ActLen = Len - 39,
                    ActLen = length(binary_to_list(Rest)),
                    <<Act:ActLen/binary>> = Rest,
                    Head     = ?MSG_HEAD,
                    Ack_Type = ?MSG_ACK_TYPE,
                    Version  = ?MSG_VERSION,
                    io:format("~p~n",[binary_to_list(Act)]);
                {tcp_closed,Socket} ->
                    ok
            end;
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

socket()-> get(socket).
quit_without_login() ->
    Socket=get(socket),
    Cmd = "90001;",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,Bin} ->
            <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,90001:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
            ActLen = Len - 39,
            ActLen = length(binary_to_list(Rest)),
            <<Act:ActLen/binary>> = Rest,
            Head     = ?MSG_HEAD,
            Ack_Type = ?MSG_ACK_TYPE,
            Version  = ?MSG_VERSION,
            io:format("~p~n",[binary_to_list(Act)]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

logout() ->
    Socket=get(socket),
    NewCmd = "90001;",
    NewEID = <<0,0,0,0,0,0,0,$0>>,
    NewTID = 1,
    NewMsg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(NewCmd)):32>>,<<1:32>>,NewEID,<<NewTID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(NewCmd)]),
    ok = gen_tcp:send(Socket,NewMsg),
    receive
        {tcp,Socket,Bin} ->
            io:format("~p~n",[Bin]);
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

quit_after_login() ->
    Socket=get(socket),
    Cmd = "90000:1=\"kylintvboss\",2=\"13051506\";",
    EID = <<0,0,0,0,0,0,0,$0>>,
    TID = 1,
    Msg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(Cmd)):32>>,<<1:32>>,EID,<<TID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(Cmd)]),
    ok = gen_tcp:send(Socket,Msg),
    receive
        {tcp,Socket,_} ->
            NewCmd = "90001;",
            NewEID = <<0,0,0,0,0,0,0,$0>>,
            NewTID = 1,
            NewMsg = list_to_binary([<<16#AA55AA55:32>>,<<1:8>>,<<(39+length(NewCmd)):32>>,<<1:32>>,NewEID,<<NewTID:32>>,<<0:32>>,<<0:8>>,<<0:16>>,<<0:(16*8)>>,list_to_binary(NewCmd)]),
            ok = gen_tcp:send(Socket,NewMsg),
            receive
                {tcp,Socket,Bin} ->
                    <<Head:4/binary,Ack_Type:1/binary,Len:4/integer-unit:8,Version:4/binary,EID:8/binary,TID:4/integer-unit:8,0:4/integer-unit:8,0:1/integer-unit:8,1:2/integer-unit:8,_Rev:16/binary,Rest/binary>> = Bin,
                    ActLen = Len - 39,
                    ActLen = length(binary_to_list(Rest)),
                    <<Act:ActLen/binary>> = Rest,
                    Head     = ?MSG_HEAD,
                    Ack_Type = ?MSG_ACK_TYPE,
                    Version  = ?MSG_VERSION,
                    io:format("~p~n",[binary_to_list(Act)]);
                {tcp_closed,Socket} ->
                    ok
            end;
        {tcp_closed,Socket} ->
            ok
    end,
    ok.

keep_heart_alive_loop(Socket,HeartMML) ->
    receive
        {tcp,Socket,HeartMML} ->
            io:format("~p~n",[HeartMML]),
            ok = gen_tcp:send(Socket,HeartMML),
            keep_heart_alive_loop(Socket,HeartMML);
        {tcp_closed,Socket} ->
            ok
    end.

keep_heart_alive_loop_without_reply(Socket,HeartMML) ->
    receive
        {tcp,Socket,HeartMML} ->
            io:format("~p~n",[HeartMML]),
            keep_heart_alive_loop_without_reply(Socket,HeartMML);
        {tcp_closed,Socket} ->
            ok
    end.

keep_heart_alive() ->
    HeartMML = list_to_binary([?MSG_HEAD,?MSG_HEART_TYPE]),
    {ok,Pid} = nmsi:start(),
    {ok,Socket} = gen_tcp:connect(nmsi_configure:ip(),nmsi_configure:port(),[binary,{packet,4}]),
    keep_heart_alive_loop(Socket,HeartMML),
    nmsi:stop(Pid).

keep_heart_alive_without_reply() ->
    HeartMML = list_to_binary([?MSG_HEAD,?MSG_HEART_TYPE]),
    {ok,Pid} = nmsi:start(),
    {ok,Socket} = gen_tcp:connect(nmsi_configure:ip(),nmsi_configure:port(),[binary,{packet,4}]),
    keep_heart_alive_loop_without_reply(Socket,HeartMML),
    nmsi:stop(Pid).
