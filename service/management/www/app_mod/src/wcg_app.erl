%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork
%%%------------------------------------------------------------------------------------------

-module(wcg_app).
-compile(export_all).

-include("yaws_api.hrl").


%% yaws callback entry
out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,


    case catch handle(Arg, Method, Path) of
      {'EXIT', Reason} -> 
          io:format("Error: ~p~n", [Reason]),
          utility:pl2jso([{status, failed}, {reason, service_not_available}]);
      JsonObj -> 
          encode_to_json(JsonObj)
    end.

handle(Arg, 'POST', ["wcg", "nodes"]) ->
    {Node, Total} = utility:decode(Arg, [{node, a}, {total, i}]),
    rpc:call(ns:service_node(), wcg_disp, add_wcg, [Node, Total]),
    utility:pl2jso([{status, ok}]);

handle(Arg, 'DELETE', ["wcg"]) ->
   Node = utility:query_atom(Arg, "node"),
   rpc:call(ns:service_node(), wcg_disp, remove_wcg, [Node]),
   utility:pl2jso([{status, ok}]);

handle(_Arg, 'GET', ["wcg", "nodes"]) ->
    %% Nodes = [{'wcg@aaa', 1000},{'wcg@bbb', 2000}],
    Nodes = rpc:call(ns:service_node(), wcg_disp, get_all_wcgs, []),
    utility:pl2jso([{status, ok}, {nodes, utility:a2jsos([node, total],Nodes)}]);


handle(_Arg, 'GET', ["wcg", "net_stats"]) ->
  stats:start(),
  NetStats = stats:get_net_stats(),
  utility:pl2jso([{status, ok},  {stats, utility:pl2jsos(NetStats)}]);

handle(_Arg, 'GET', ["wcg", "stats"]) ->
  stats:start(),
  CallStats = stats:get_call_stats(),
  utility:pl2jso([{status, ok},  {stats, utility:pl2jsos(CallStats)}]);

handle(_Arg, 'GET', ["wcg", "ccalls"]) ->
  stats:start(),
  CallStats = stats:get_call_stats(),
  F=fun(Stat)-> 
%	      case proplists:get_value(status,Stat) of
%		      down-> 10000;
%		      up->
		      [_T,NCall]=proplists:get_value(calls, Stat,0), 
		      NCall 
%	      end
      end,
  Calls = lists:sum([F(Stat)||Stat<-CallStats ]),
  {NewCalls,Max} = if Calls >= 10000 ->  {Calls rem 10000, 0}; true-> {Calls, ns:get(max_calls)} end,
  utility:pl2jso([{status, ok},  {calls, NewCalls},{max, Max}]);

%% handle unknown request
handle(_Arg, _Method, _Params) -> 
    io:format("receive unknown ~p ~p ~n",[_Method,_Params]),
    [{status,405}].

%% encode to json format
encode_to_json(JsonObj) ->
    {content, "application/json", rfc4627:encode(JsonObj)}.

get_cpu_usage(Node) ->
   case rpc:call(Node, os, cmd, ["top -b -n 2 -d .5 | grep \"Cpu(s):\""]) of
       {badrpc, _} -> "0.0";
       C           ->
           scan_cpu_usage(lists:nth(2,string:tokens(C,"\n")))
   end.

scan_cpu_usage("Cpu(s):" ++ T) ->
    scan_cpu_usage(T, in, []).

scan_cpu_usage("%us"++_Rest, in, Acc) -> string:strip(Acc);
scan_cpu_usage([A|T], in, Acc) -> scan_cpu_usage(T, in, Acc++[A]).



