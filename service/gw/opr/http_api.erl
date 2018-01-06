-module(http_api).
-compile(export_all).
-include("db_op.hrl").
-include("yaws_api.hrl").
-include_lib("eunit/include/eunit.hrl").

 
out(Arg) ->
    %io:format("Arg:~p~n",[Arg]),
    Uri = yaws_api:request_url(Arg),    
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
    Arg1= 
    if is_binary(Arg#arg.clidata) andalso size(Arg#arg.clidata)>0 ->
        %utility:log("~p ~p clidata0:~p~n",[Method,Uri,Arg#arg.clidata]),
        case catch rfc4627:decode(Arg#arg.clidata) of
        {ok,{obj,[{"data_enc",<<_:7/binary,Base64_Json_bin/binary>>}]},_}->
            Json_bin=utility:fb_decode_base64(Base64_Json_bin),
            Arg#arg{clidata=Json_bin};
        _-> 
            %io:format("no encription:~p ~p~n",[Method,Uri]),
            Arg
        end;
    true-> Arg
    end,
    process_request(Path, Method, Arg1).

%process_request(["lwork", "mobile","paytest"|Params], Method, Arg) -> 
%    [{header, "Access-Control-Allow-Origin: *"},pay:handle(Arg,Method,Params)];
process_request(Path, Method, Arg) -> 
    check_orgin_request(Path,Method,Arg).
    
    
check_orgin_request(Path,Method,Arg)->  
 %   io:format("origin:~p~n",[{Origin,Path,Method}]),
    JsonObj = do_request(Arg, Method, Path),
    [{header, "Access-Control-Allow-Origin: *"}, encode_to_json(JsonObj)].

do_request(Arg, Method, Path) ->
    case catch handle(Arg, Method, Path) of
        {'EXIT', Reason} ->  
              err_log(Arg,Reason),
            utility:pl2jso([{status, failed}, {reason, service_not_available}]);
        Result -> 
            Result
    end.
            
handle(Arg, Method, ["api"|Params]) ->   %% remove old inteface
    %io:format("l_app.erl: method:~p. params:~p~n",[Method,Params]), 
    %io:format("clidata:~p~n",[Arg#arg.clidata]),
%    Pls=handle_wafa(Arg, Method, Params),
    utility1:pl2jso_br(handle_api(Arg,Method,Params));
handle(_Arg,Method,Params) ->   
    io:format("http_api.erl:unhandled method:~p. params:~p~n",[Method,Params]), 
    utility1:pl2jso_br([{status,failed},{reason,unhandled}]).

handle_api(Arg,'POST',_) -> 
    Clidata=Arg#arg.clidata,

    Map0=utility1:jsonbin2map(Clidata),
    Map1=maps:map(fun("msgType",V)->V;  
                     ("boardIndex",V)-> list_to_integer(binary_to_list(V));
                     (_,V) when is_binary(V)-> binary_to_list(V);  
                     (_,V)-> V end, Map0),
    Ip=utility1:make_ip_str(utility1:client_ip(Arg)),
    Map=Map1#{"ip"=>Ip},
    Res0 = handle_map(Map),
    utility1:log("log/http_api.log","req:~p",[Clidata]),
    Ack=
    case proplists:get_value(seatId,Res0) of
        undefined-> Res0;
        SeatId-> 
            AllBoardStatus=opr:get_all_status(SeatId),
            if is_map(AllBoardStatus)->
                [{boardState,utility1:map2jso(AllBoardStatus)}|Res0];
            true-> Res0
            end
    end,
    utility1:log("log/http_api.log","ack:~p",[Ack]),
    Ack.



handle_map(#{"msgType":= <<"seatgroup_config">>,"groupPhone":=Phone,"seatGroupNo":=GroupNo})-> 
    oprgroup_sup:add_oprgroup(GroupNo,Phone),
    [{status,ok}];
handle_map(#{"msgType":= <<"seat_register">>,"seatId":=SeatId,"seatPhone":=Phone,"seatGroupNo":=GroupNo,"pwd":=Pwd})-> 
    opr_sup:add_opr(GroupNo,SeatId,Phone,Pwd),
    [{status,ok}];

%curl -l -H "Content-type: application/json" -X POST -d '{"msgType":"opr_login","seatId":"6","operatorId":"001"}' http://127.0.0.1:8082/api    
handle_map(#{"msgType":= <<"opr_login">>,"seatId":=SeatId,"operatorId":=OprId,"ip":=Ip})-> 
    opr_sup:login(SeatId,Ip,OprId),
    [{status,ok},{seatId,SeatId}];
%curl -l -H "Content-type: application/json" -X POST -d '{"msgType":"opr_logout","seatId":"6"}' http://127.0.0.1:8082/api    
handle_map(#{"msgType":= <<"opr_logout">>,"seatId":=SeatId})-> 
    opr_sup:logout(SeatId),
    [{status,ok}];
%服务端到客户端handle_map(#{"msgType":= <<"call_broadcast">>,"groupPhone":=Phone,"seatGroupNo":=GroupNo})-> 
%    [{status,ok}];
handle_map(#{"msgType":= <<"pickup_call">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:pickup_call({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"sidea">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:sidea({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"sideb">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:sideb({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"inserta">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:inserta({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"insertb">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:insertb({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"splita">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:splita({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"splitb">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:splitb({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"third">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:third({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"monitor">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:monitor({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"ab">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:ab({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"clean_board">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:release({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"releasea">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:releasea({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"releaseb">>,"seatId":=SeatId,"boardIndex":=BI})-> 
    board:releaseb({SeatId,BI}),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"board_switch">>,"seatId":=SeatId,"curBoardIndex":=_CBI,"nextBoardIndex":=NBI_str})-> 
    NBI=list_to_integer(NBI_str),
    opr:focus(SeatId,NBI),
    [{status,ok},{seatId,SeatId}];
 handle_map(#{"msgType":= <<"cross_board">>,"seatId":=SeatId,"curBoardIndex":=CBI_str,"nextBoardIndex":=NBI_str,"seatId":=SeatId})-> 
     CBI=list_to_integer(CBI_str),
     NBI=list_to_integer(NBI_str),
     board:cross_board({SeatId,CBI},{SeatId,NBI}),  
    [{status,ok},{seatId,SeatId}];
 handle_map(#{"msgType":= <<"transfer_opr">>,"seatId":=SeatId,"boardIndex":=BI,"targetSeat":=TargetSeat})-> 
     board:transfer_opr({SeatId,BI},TargetSeat),
    [{status,ok},{seatId,SeatId}];
 handle_map(MsgMap=#{"msgType":= <<"talk_to_opr">>,"operator1Id":=OprId1,"operator2Id":=OprId2})-> 
     opr:talk_to_opr(OprId1,OprId2,MsgMap),
     [{status,ok}];
 handle_map(Message=#{"msgType":= <<"message">>,"source":=OprId1,"target":=OprId2,"msg":=_Msg})-> 
     opr:message(OprId1,{OprId2,Message});
 handle_map(Message=#{"msgType":= <<"queryhistorymsg">>,"operatorId":=OprId1,"number":=Number})-> 
     opr:queryhistorymsg(OprId1,list_to_integer(Number));
% handle_map(#{"msgType":= <<"user_subscribe">>,"seatId":=SeatId,"operatorId":=OperatorId,"phoneNumber":=Phone})-> 
%     board:inserta({SeatId,BI}),
%     [{status,ok}];
 handle_map(#{"msgType":= <<"getSeatState">>,"seatId":=SeatId,"operatorId":=OperatorId})-> 
     [{status,ok},{seatId,SeatId}];

%curl -l -H "Content-type: application/json" -X POST -d '{"msgType":"addSipUser","phones":["999"],"passwds":["999"]}' http://127.0.0.1:8082/api
handle_map(#{"msgType":= <<"addSipUser">>,"phones":=Phones,"passwds":=Pwds})-> 
    F=fun(G,[User|T1],[Pwd|T2])->
            io:format("addsipuser:~p~n",[{node_conf:get_voice_node(),phone,insert_user_or_password,[User,Pwd]}]),
            rpc:call(node_conf:get_voice_node(),phone,insert_user_or_password,[binary_to_list(User),binary_to_list(Pwd)]),
            G(G,T1,T2);
         (_,_,_)-> void
     end,
    F(F,Phones,Pwds),
    [{status,ok}];
handle_map(#{"msgType":= <<"handShake">>,"seatId":=SeatId,"boardIndex":=ClientActiveBI})->   %boardIndex为当前客户端的激活窗口号
    opr:handshake(SeatId,ClientActiveBI),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"calla">>,"seatId":=SeatId,"boardIndex":=BI,"phone":=Phone})-> 
    board:calla({SeatId,BI},Phone),
    [{status,ok},{seatId,SeatId}];
handle_map(#{"msgType":= <<"callb">>,"seatId":=SeatId,"boardIndex":=BI,"phone":=Phone})-> 
    board:callb({SeatId,BI},Phone),
    [{status,ok},{seatId,SeatId}];
% handle_map(#{"msgType":= <<"query_phone">>,"seatId":=SeatId,"boardIndex":=BI,"phoneNumber":=Phone,"isCall":=IsCall})-> 
%     [{status,ok}];
handle_map(O)->
    io:format("unhandled map ~p~n",[O]),
    [{status,failed},{reason,unhandled}].


%% encode to json format
encode_to_json([{status,405}]) -> [{status,405}];
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.
  
enc_json(Result)-> rfc4627:encode(utility:pl2jso_r(utility:v2b_r(Result))).   

err_log(Arg,Reason)->
    {ok, IODev} = file:open("./log/server_error.log", [append]),
    io:format(IODev, "~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
    io:format("~p:  Arg: ~p~n Reason: ~p~n", [erlang:localtime(), Arg, Reason]),
    file:close(IODev).

