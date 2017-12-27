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
    [{status,failed},{reason,unhandled}].

handle_api(Arg,'POST',_) -> 
    Clidata=Arg#arg.clidata,

    Map0=utility1:jsonbin2map(Clidata),
    Ip=utility1:client_ip(Arg),
    Map=Map0#{"ip"=>Ip},
    case handle_map(Map) of
        {failed,Reason}->
            [{errorCode,2},{errorInfo,Reason}];
        Jso->
            [{errorCode,0},{ackdata,Jso}]
    end.


handle_map(#{"msgType":= <<"group_register">>,"groupPhone":=Phone,"seatGroupNo":=GroupNo})->
    todo;
handle_map(#{"msgType":= <<"login">>})->
    todo;
handle_map(_)->
    {failed,unhandled}.


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

