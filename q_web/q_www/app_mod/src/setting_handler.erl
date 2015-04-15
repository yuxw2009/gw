%%%------------------------------------------------------------------------------------------
%%% @doc Yaws lwork AppMod for path: /lwork/settings
%%%------------------------------------------------------------------------------------------
-module(setting_handler).
-compile(export_all).

-include("yaws_api.hrl").

%%% request handlers

%% handle change user profile request
handle(Arg, 'PUT', ["profile"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Department = utility:get_string(Json, "department"),
    Mail =  utility:get_string(Json, "mail"),
    Phone =  utility:get_binary(Json, "phone"),
    ok = change_user_info(UUID, Department, Mail, list_to_binary(rfc4627:encode(Phone)), utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);
%% handle change user photo request
handle(Arg, 'PUT', ["photo"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    PhotoURL = utility:get_binary(Json,"photo"),
    ok = change_user_photo(UUID, PhotoURL, utility:client_ip(Arg)),
    utility:pl2jso([{status, ok}]);   

%% handle change user photo request
handle(Arg, 'GET', ["salary"]) ->
    UUID = utility:query_integer(Arg, "uuid"),
    Year = utility:query_integer(Arg, "year"),
    Month = utility:query_integer(Arg, "month"),
    
    Info = get_salary_info(UUID, Year, Month, utility:client_ip(Arg)),
    
    utility:pl2jso([{status, ok}, {salary_info, Info}]);   


%% handle change user password request
handle(Arg, 'PUT', ["password"]) ->
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    UUID = utility:get_integer(Json, "uuid"),
    Company = utility:get_string(Json, "company"),
    Account = utility:get_string(Json, "account"),
    OldPass =  utility:get_string(Json, "old_pass"),
    NewPass =  utility:get_string(Json, "new_pass"),
    Res = change_user_password(UUID, Company, Account, OldPass, NewPass, utility:client_ip(Arg)),
    utility:pl2jso([{status, Res}]).


%%% rpc call
-include("snode.hrl").

change_user_info(UUID, Department, Mail, Phone, SessionIP) ->
    io:format("change_user_info ~p ~p ~p ~p ~nn",[UUID, Department, Mail, Phone]),
    %%rpc:call(snode:get_service_node(), lw_instance, modify_user_info, [UUID, Department,[Phone],[Mail]]).
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                       [UUID, lw_instance, modify_user_info, [UUID,Phone,[Mail]],SessionIP]),
    
    ok.

change_user_photo(UUID, PhotoURL, SessionIP) ->
   io:format("change_user_info ~p ~p ~nn",[UUID,PhotoURL]),
    %%rpc:call(snode:get_service_node(), lw_instance, modify_user_info, [UUID, Department,[Phone],[Mail]]).
    {value, ok} = rpc:call(snode:get_service_node(), lw_instance, request, 
                       [UUID, lw_instance, modify_user_photo, [UUID,  PhotoURL],SessionIP]),
    
    ok.

change_user_password(UUID, Company, Account, OldPass, NewPass,SessionIP) ->
    io:format("modify_password ~p ~p ~p ~p ~p~n",[UUID, Company, Account, OldPass, NewPass]),
    %%rpc:call(snode:get_service_node(), lw_auth, modify_password, [Company, Account, OldPass, NewPass]).
    rpc:call(snode:get_service_node(), lw_instance, request,
                      [UUID, lw_auth, modify_password, [UUID, Company, Account, OldPass, NewPass],SessionIP] ),
    ok.


 get_salary_info(UUID, Year, Month, SessionIP) ->
  %% io:format("get_salary_info ~p ~p ~p ~p ~n",[UUID, Year, Month, SessionIP]),
   {value, Info } =rpc:call(snode:get_service_node(), lw_instance, request,
                [UUID, lw_salary, get_salary_info, [UUID, Year, Month], SessionIP]),

   Info.