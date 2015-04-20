-module(www_stats).

-compile(export_all).

-include("yaws_arg.hrl").
-include("call.hrl").


%% get call stats request handlers
handle(Arg, 'GET', []) ->
    Service_id=yaws_utility:query_string(Arg, "service_id"),
    Seq_no = yaws_utility:query_integer(Arg, "seq_no"),
%    UUID = yaws_utility:query_integer(Arg, "uuid"),
    Bill_id = yaws_utility:query_integer(Arg, "bill_id"),
%    Auth_code =yaws_utility:query_integer(Arg, "auth_code"),
%    io:format("cdr request received!~p ~p ~p ~n ", [Service_id, Seq_no, Bill_id]),
    Cdrs = rpc:call(?SNODE, cdrserver, get_cdr_from, [Service_id, Bill_id]),
    [{status, ok}, 
                {cdrs, trans_cdrs_to_rest(Cdrs)}];
    
handle(_Arg, Method,Content)->
    io:format("unhandled cdrs request, Method: ~p, Content:~p~n", [Method, Content]),
    [{status, unhandled}].

%% internal function
trans_cdrs_to_rest(Cdrs)-> 
    [yaws_utility:pl2jso(Trans, Plist) ||{Trans, Plist}<-[trans_cdr(Cdr) || Cdr<-Cdrs]].


add_names_handler(Names)-> [add_name_handler(Name) || Name<-Names].

%% for cdr and cdr details items
add_name_handler(bill_id)-> {bill_id, yaws_utility:to_binary()};
add_name_handler(charge)-> {charge, yaws_utility:to_binary()};
add_name_handler(details)-> {details, fun trans_details_to_rest/1};
add_name_handler(end_time)-> {end_time, fun time_readable/1};
add_name_handler(month)-> {month, yaws_utility:to_binary()};
add_name_handler(phone1)-> {phone1, yaws_utility:to_binary()};
add_name_handler(phone2)-> {phone2, yaws_utility:to_binary()};
add_name_handler(phone)-> {phone, yaws_utility:to_binary()};
add_name_handler(phones)-> {phones, fun(Phones)->[(yaws_utility:to_binary())(Phone) || Phone<-Phones] end};

add_name_handler(quantity)-> {quantity, yaws_utility:to_binary()};
add_name_handler(rate1)-> {rate1, yaws_utility:to_binary()};
add_name_handler(rate2)-> {rate2, yaws_utility:to_binary()};
add_name_handler(rate)-> {rate, yaws_utility:to_binary()};
add_name_handler(start_time)-> {start_time, fun time_readable/1};
add_name_handler(service_id)-> {service_id, yaws_utility:to_binary()};
add_name_handler(timestamp)-> {timestamp, fun time_readable/1};

add_name_handler(year)-> {year, yaws_utility:to_binary()};
add_name_handler(Name)-> {Name}.


trans_details_to_rest(Details) when is_tuple(Details)-> trans_detail_to_rest(Details);
trans_details_to_rest(Details) when is_list(Details)-> [trans_detail_to_rest(Detail) || Detail<-Details].

trans_detail_to_rest(Detail)->
    Names = record_names(Detail),
    Names1 = add_names_handler(Names),
    [_|Values] = tuple_to_list(Detail),
    yaws_utility:pl2jso(Names1, lists:zip(Names, Values)).

record_names(Detail)->
    case Detail of
        #call_back_detail_new{} ->record_info(fields, call_back_detail_new);
        #phone_meeting_item{}->record_info(fields, phone_meeting_item);
        #sms_detail{}-> record_info(fields, sms_detail);
        #voip_detail{}-> record_info(fields, voip_detail);
        _-> io:format("unknown detail: ~p~n", [Detail])
    end.
    
trans_cdr(Cdr)->
   [_Key|T]= record_info(fields, cdr),
   Names=[bill_id, service_id | T],
   Names1 = add_names_handler(Names),
   [_Record_name, {Bill_id, Service_id} | T1]= tuple_to_list(Cdr),
   Values = [Bill_id, Service_id | T1],
   {Names1, lists:zip(Names, Values)}.

cdr_test()-> #cdr{key={1,"123"}, type=meeting, quantity=3, charge=4,  
                    details=[#phone_meeting_item{phone="138", rate=0.1, start_time=calendar:local_time(), end_time=calendar:local_time()}]}.        

time_readable({Day,Time})-> 
    list_to_binary(string:join([integer_to_list(I)||I<-tuple_to_list(Day)], "-") ++" "++ string:join([integer_to_list(I)||I<-tuple_to_list(Time)], ":")).

    
