%%%--------------------------------------------------------------------------------------
%%% @author Zhangcongsong
%%% @copyright 2012-2013 livecom
%%% @doc Lwork test robot
%%% @end
%%%--------------------------------------------------------------------------------------
-module(lw_robot).
-compile(export_all).
-include("lw.hrl").

-define(URL,"http://10.60.108.141").
-define(LOGIN,"/lwork/auth/login").
-define(PROFILE,"/lwork/auth/profile?uuid=").
-define(MEMBERS,"/lwork/groups/93/members?owner_id=").
-define(UPDATE,"/lwork/updates?uuid=").
-define(CREATE,"/lwork/topics").

random_content(1) ->
    list_to_binary("Is Wechat innovative?  It's hard to call any of its features innovative.  But when integrated, it definitely offers an innovative and novel experience.  I walk around my company and see people talking to their phones pressed to their lips but not near their ears.  This is because they're in the push-to-talk mode.  Wechat is changing the way people communicate in China.");
random_content(2) ->
    list_to_binary("Allen is also a practitioner of the lean start-up.  He has tried many innovative experiments: Can Wechat become an open platform?  Can Wechat connect with offline stores, realizing the O2O (Online2Offline)?  Can Wechat become the first Chinese product to become a hit outside China?  These experiments are showing promising results.  More and more developers are using the Wechat platform.  More and more offline stores and restaurants are connecting to Wechat.  And Wechat has risen on the top charts of Egypt, UAR, Vietnam, and many other countries.");
random_content(3) ->
    list_to_binary("Wechat was created by Zhang Xiaolong (Allen Zhang), a low-profile veteran of the Chinese Internet.  Allen independently developed an email client Foxmail in 1996.  He has developed many products since, and also grew from a super developer into a super product manager.  He is now regarded as one of the finest product managers and innovators in China -- much like Jack Dorsey or Marissa Mayer in the US.").

create_robot_account(Num) when Num > 1 ->
    OrgID = local_user_info:create_org("robot","robot"),
    Dep   = local_user_info:create_department(OrgID, "robot"),
    Seqs  = lists:seq(1, Num),
    [local_user_info:add_user({
    	OrgID,
    	integer_to_list(Seq),
    	integer_to_list(Seq),
    	Dep,
    	[],
    	[],
    	"robot"})||Seq<-Seqs].

robot_to_uuid(I) ->
    (I - 1) * 2 + 96. 

start_robot(Begin,End,Max,PollInterval,CreateInterval) ->
    inets:start(),
    Seqs  = lists:seq(Begin, End),
    lists:foreach(fun(Seq)-> spawn(fun() -> robot_login(
	    						"robot",
	    						integer_to_list(Seq),
	    						"robot",
	    						PollInterval,
	    						CreateInterval,
                                Max)
                                 end),
                   timer:sleep(10)
				   end,Seqs).

single_login(MarkName,EmployeeID,Pwd) ->
    MD5  = list_to_binary(hex:to(crypto:md5(Pwd))),
    Body = rfc4627:encode(utility:a2jso([company,account,password],[list_to_binary(MarkName),list_to_binary(EmployeeID),MD5])),
    {ok,{_,_,NewBody}} = httpc:request(post,{?URL ++ ?LOGIN,[],"application/json",Body},[],[]),
    {ok,Json,_}        = rfc4627:decode(NewBody),
    UUID = list_to_binary(integer_to_list(utility:get(Json, "uuid"))),
    httpc:request(get,{?URL ++ ?PROFILE ++ binary_to_list(UUID),[]},[],[]),
    httpc:request(get,{?URL ++ ?MEMBERS ++ binary_to_list(UUID),[]},[],[]),
%    io:format("~p~n~p~n",[Res1,Res2]),
    UUID.

robot_login(MarkName,EmployeeID,Pwd,PollInterval,_CreateInterval,Max) ->
    UUID = single_login(MarkName,EmployeeID,Pwd),
    random:seed(now()),
    CreateInterval = 10 * random:uniform(30),
    PollTRef   = erlang:send_after(PollInterval * 1000, self(), start_poll),
    CreateTRef = erlang:send_after(CreateInterval * 1000, self(), create_topic),
    robot_loop(UUID,Max,PollInterval,PollTRef,CreateInterval,CreateTRef).

update_timer(Interval,TRef,Act) ->
    erlang:cancel_timer(TRef),
    erlang:send_after(Interval * 1000, self(), Act).

robot_loop(UUID,Max,PollInterval,PollTRef,CreateInterval,CreateTRef) ->
    receive
    	start_poll ->
            httpc:request(get,{?URL ++ ?UPDATE ++ binary_to_list(UUID),[]},[],[]),
    	    NewPollTRef = update_timer(PollInterval,PollTRef,start_poll),
    	    robot_loop(UUID,Max,PollInterval,NewPollTRef,CreateInterval,CreateTRef);
    	create_topic ->
            %MI = [random:uniform(1000)||_X<-lists:seq(1,10*random:uniform(100))],
            %Members = [list_to_binary(integer_to_list(robot_to_uuid(I)))||I<-MI],
            %Body = rfc4627:encode(utility:a2jso([uuid,content,members,image],[UUID,random_content(random:uniform(3)),Members,<<"">>])),
    	    %httpc:request(post,{?URL ++ ?CREATE,[],"application/json",Body},[],[]),
    	    NewCreateTRef = update_timer(CreateInterval,CreateTRef,create_topic),
    	    robot_loop(UUID,Max,PollInterval,PollTRef,CreateInterval,NewCreateTRef)
    end.