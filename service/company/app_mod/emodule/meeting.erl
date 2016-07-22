-module(meeting).
-compile(export_all).

-record(arg, {
          clisock,        %% the socket leading to the peer client
          client_ip_port, %% {ClientIp, ClientPort} tuple
          headers,        %% headers
          req,            %% request
          clidata,        %% The client data (as a binary in POST requests)
          server_path,    %% The normalized server path
                          %% (pre-querystring part of URI)
          querydata,      %% For URIs of the form ...?querydata
                          %%  equiv of cgi QUERY_STRING
          appmoddata,     %% (deprecated - use pathinfo instead) the remainder
                          %% of the path leading up to the query
          docroot,        %% Physical base location of data for this request
          docroot_mount,  %% virtual directory e.g /myapp/ that the docroot
                          %%  refers to.
          fullpath,       %% full deep path to yaws file
          cont,           %% Continuation for chunked multipart uploads
          state,          %% State for use by users of the out/1 callback
          pid,            %% pid of the yaws worker process
          opaque,         %% useful to pass static data
          appmod_prepath, %% (deprecated - use prepath instead) path in front
                          %%of: <appmod><appmoddata>
          prepath,        %% Path prior to 'dynamic' segment of URI.
                          %%  ie http://some.host/<prepath>/<script-point>/d/e
                          %% where <script-point> is an appmod mount point,
                          %% or .yaws,.php,.cgi,.fcgi etc script file.
          pathinfo        %% Set to '/d/e' when calling c.yaws for the request
                          %% http://some.host/a/b/c.yaws/d/e
                          %%  equiv of cgi PATH_INFO
         }).


-record(http_request, {method,
                       path,
                       version}).

-record(url,
        {scheme,          %% undefined means not set
         host,            %% undefined means not set
         port,            %% undefined means not set
         path = [],
         querypart = []}).

-define(MEETING_NODE, 'meeting@department3-svn.zte.com.cn').

out(Arg) ->
    Uri = yaws_api:request_url(Arg),
    Path = string:tokens(Uri#url.path, "/"), 
    Method = (Arg#arg.req)#http_request.method,
    handle(Arg, Method, Path).


%%--------------------------------------------------------------------------------
%% @doc  handle REST request
%% @end
%%--------------------------------------------------------------------------------

%% handle login request
handle(Arg, 'POST', ["lwork","login"]) ->
   {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
   {ok, UserName} = rfc4627:get_field(Json, "username"),
   {ok, Password} = rfc4627:get_field(Json, "password"),
   io:format("Login from ~p, password: ~p~n",[UserName, Password]),

   case UserName of
       <<"admin">> when Password == <<"123abc!">> ->
              UUID = "123456781",
              History = case rpc:call(?MEETING_NODE, meeting_api, get_history, [UUID]) of
                          {value, H}        -> H;
                          {failed, _Reason} -> []
                        end,
                           {content, "application/json", gen_meeting_history(UUID,History)};    
       <<"zhaotao">> when Password == <<"123abc!">> ->
              UUID = "123456791",
              History = case rpc:call(?MEETING_NODE, meeting_api, get_history, [UUID]) of
                          {value, H}        -> H;
                          {failed, _Reason} -> []
                        end,
                           {content, "application/json", gen_meeting_history(UUID,History)};  
      <<"leiyuxin">> when Password == <<"123abc!">> ->
              UUID = "123456771",
              History = case rpc:call(?MEETING_NODE, meeting_api, get_history, [UUID]) of
                          {value, H}        -> H;
                          {failed, _Reason} -> []
                        end,
                           {content, "application/json", gen_meeting_history(UUID,History)};  
       
     <<"tester">> when Password == <<"1234">> ->
              UUID = "1112221",
              History = case rpc:call(?MEETING_NODE, meeting_api, get_history, [UUID]) of
                          {value, H}        -> H;
                          {failed, _Reason} -> []
                        end,
                           {content, "application/json", gen_meeting_history(UUID,History)};    
  

    
      _->
             {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
   end;

%% handle meeting create request
handle(Arg, 'POST', ["lwork","meetings"]) ->
   
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    {ok, UUID} = rfc4627:get_field(Json, "uuid"),
    {ok, Subject} = rfc4627:get_field(Json, "subject"),
    {ok, Members} = rfc4627:get_field(Json, "members"),
    io:format("UUID, Memebers: ~p => ~p~n", [UUID, Members]),
    Phones = [{get_value(M, "name"), binary_to_list(get_value(M, "phone"))} || M <- Members],
    io:format("meeting create: ~p => ~p~n", [UUID, Phones]),

     Allows = ["123456781", "123456791","123456771", "1112221"],
     case lists:member(binary_to_list(UUID), Allows) of
          false ->{content, "application/json", rfc4627:encode({obj,[{status, failed}]})};

          true  ->
             case rpc:call(?MEETING_NODE,  meeting_api, create, [binary_to_list(UUID), Subject,Phones]) of
                {value,MID, MS} ->
                     io:format("~p ~p ~n",[MID, MS]),
                    [{status,201},{content,"application/json",meeting_to_json(MID, MS)}];
                    {failed, _Reason} ->
                {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
              end
     end;

    

%% handle get meeting history request
handle(Arg, 'GET', ["lwork","meetings"]) ->
    {ok,UUID} = yaws_api:queryvar(Arg, "uuid"),
    io:format("UUID ~p get meeting history ~n", [UUID]),
    History = case rpc:call(?MEETING_NODE, meeting_api, get_history, [UUID]) of
                 {value, H}        -> H;
                 {failed, _Reason} -> []
              end,
    io:format("~p  ~n",[History]),
   {content, "application/json", gen_meeting_history(UUID,History)};   


%% handle join new member request
handle(Arg, 'POST', ["lwork","meetings",MID, "members"]) ->
   {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
   {ok, UUID} = rfc4627:get_field(Json, "uuid"),
   {ok, Name} = rfc4627:get_field(Json, "name"),  
   {ok, Phone} = rfc4627:get_field(Json, "phone"),
   io:format("UUID: ~p ~p Add Memeber: ~p to Meeting: ~p ~n", [UUID, Name, Phone, MID]),
   
   case  rpc:call(?MEETING_NODE, meeting_api, join, [binary_to_list(UUID), MID,Name, binary_to_list(Phone)]) of
      {value, {MemberId, Status, NameBin, PhoneStr}} ->
           {content, "application/json", rfc4627:encode({obj,[{status,success},{member,{obj,[{member_id, MemberId},
                                                              {status, Status},
                                                              {name, NameBin},
                                                              {phone,list_to_binary(PhoneStr)}]}}]})};
      {failed, _Reason} ->
        io:format("Redail failed: ~p~n",[_Reason]),
         {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
   end;

%% handle get meeting details request
handle(Arg, 'GET', ["lwork","meetings", MeetingId, "members"]) ->
    {ok,UUID} = yaws_api:queryvar(Arg, "uuid"),
    io:format("UUID ~p get meeting ~p details ~n", [UUID, MeetingId]),
    case  rpc:call(?MEETING_NODE, meeting_api, get_details, [UUID, MeetingId]) of
        {value, MeetingStatus, MS} ->
            io:format("~p  ~n",[MS]),
            {content, "application/json", gen_meeting_detail(MeetingStatus, MS)};
        {failed, _Reason} ->
           {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
    end; 

%% handle finish meeting request
handle(Arg, 'PUT', ["lwork","meetings", MID]) ->
   {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
   {ok, UUID} = rfc4627:get_field(Json, "uuid"),
   io:format("UUID: ~p end Meeting: ~p ~n", [UUID, MID]),
   case rpc:call(?MEETING_NODE, meeting_api, end_meeting, [binary_to_list(UUID), MID]) of
      ok ->
           {content, "application/json", rfc4627:encode({obj,[{status, success}]})};
      {failed, _Reason} ->
            io:format("~p  ~n",[_Reason]),
           {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
   end;

%% handle delete meeting request
handle(Arg, 'DELETE', ["lwork","meetings", MID]) ->
   {ok,UUID} = yaws_api:queryvar(Arg, "uuid"),
   io:format("UUID: ~p delete Meeting: ~p ~n", [UUID, MID]),
   case rpc:call(?MEETING_NODE, meeting_api, delete_meeting, [UUID, MID]) of
      ok ->
           {content, "application/json", rfc4627:encode({obj,[{status, success}]})};
      {failed, _Reason} ->
            io:format("~p  ~n",[_Reason]),
           {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
   end;

%% handle redial  a offline member request
handle(Arg, 'PUT', ["lwork","meetings", MeetingID, "members", MemberID]) -> 
    {ok, Json, _} = rfc4627:decode(Arg#arg.clidata),
    {ok, UUID} = rfc4627:get_field(Json, "uuid"),
    io:format("UUID ~p redial Member ~p ~n ",[UUID, MemberID]),
    case rpc:call(?MEETING_NODE, meeting_api, redail, [binary_to_list(UUID), MeetingID,list_to_integer(MemberID)]) of
       ok ->
           {content, "application/json", rfc4627:encode({obj,[{status, success}]})};
      {failed, _Reason} ->
           {content, "application/json", rfc4627:encode({obj,[{status, failed}]})}
   end;

handle(_Arg,_Method,_Param) ->
    io:format("receive unknown ~p ~p ~n",[_Method,_Param]),
    [{status,405}].


get_value(Obj, Key) ->
    {ok,Value} = rfc4627:get_field(Obj, Key),
    Value.

%% Members = [{Id,Status,Name, Phone}]
meeting_to_json(MeetingId, Members) ->
    MemObj = [{obj,[{member_id, ID},
                    {status   , Status},
                    {name     , Name},
                    {phone    , list_to_binary(Phone)}]}
                || {ID, Status, Name, Phone} <- Members],
    rfc4627:encode({obj,[{status, success},{meeting_id,list_to_binary(MeetingId)},{members,MemObj}]}).

date2str(Y,M,D,H,Min) ->
    integer_to_list(Y) ++ "-" ++
    integer_to_list(M) ++ "-" ++
    integer_to_list(D) ++ "-" ++
    integer_to_list(H) ++ "-" ++
    integer_to_list(Min).

gen_meeting_history(UUID, MProfiles) ->
    MPObj= [{obj,[{meeting_id, list_to_binary(MID)},
                  {subject   , Subject},
                  {start_time, list_to_binary(date2str(Year, Month, Date,Hour,Minute))},
                  {status    , Status},
                  {members, gen_json_obj({member_id, name, {phone, fun erlang:list_to_binary/1}},Members)}
                  ]}   
                  || {MID,Subject,{{Year, Month, Date},{Hour,Minute,_}},Status,Members} <- MProfiles],
    rfc4627:encode({obj,[{status, success},{uuid, list_to_binary(UUID)}, 
                         {meeting_history, MPObj}]}).

gen_meeting_detail(MeetingStatus, MeetingDetails) ->
    MDObj= [{obj,[{member_id        , MID},
                  {status    , Status},
                  {name      , Name},
                  {phone     , list_to_binary(Phone)}]}   
                  || {MID, Status, Name, Phone} <- MeetingDetails],
    rfc4627:encode({obj,[{status, success}, {meeting_status, MeetingStatus},
                         {members, MDObj}]}).



gen_json_obj(Tags, Items) ->
    LTags = tuple_to_list(Tags),
    [gen_json_item(LTags, tuple_to_list(I)) || I <- Items].   

gen_json_item(Tags, Item) -> gen_json_item(Tags, Item, []).
gen_json_item([], [], Acc) -> {obj, Acc};
gen_json_item([{Tag, TransFun}|T], [I|T2], Acc) -> gen_json_item(T, T2, Acc ++ [{Tag, TransFun(I)}]);
gen_json_item([Tag|T], [I|T2], Acc) -> gen_json_item(T, T2, Acc ++ [{Tag, I}]).

