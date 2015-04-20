-module(reg_agent).
-compile(export_all).
-include("siprecords.hrl").
-record(state, {ssip="41.190.224.226", user="55010",pwd="ol55117", call_id, cseq=0, contact, last_register_request}).

start()->
    register(?MODULE, spawn(fun()-> init() end)).

init()->
    State0=#state{},
    State1=register(State0),
    loop(registering, State1).

loop(StateName, State=#state{ssip=Ssip, user=User,pwd=Pwd, call_id=Call_id, cseq=CSeq, contact=Contact})->
    receive
        Message -> 
		    case on_message(Message,StateName,State) of
	            {NewStateName,NewState} -> 
	                loop(NewStateName,NewState);
		        stop -> 
			        stop
			end
    end.

on_message({branch_result,_,_,_,#response{status=200}},registering, State)->
    loop(registered, State);


on_message({branch_result,_,_,_,Response=#response{status=401, header=Header}},registering, State=#state{last_register_request=Request})->
    {ok, Auths, _Changed} = siphelper:update_authentications(Response, lookup(), []),
    {ok, NewRequest} = siphelper:add_authorization(Request, Auths),
    do_send_register(NewRequest, State),
    loop(registering, State);

on_message(Mes,StateName,State)-> 
    io:format("message unhandled~p~n", [Mes]),
    loop(StateName, State).

register(State=#state{ssip=Ssip, user=User,pwd=Pwd, call_id=Call_id, cseq=CSeq, contact=Contact})->
    {ok, Request}=build_register(State),
    do_send_register(Request, State#state{last_register_request=Request}).

from(State)-> 
    [Addr] = contact:parse(["<sip:"++State#state.user++"@"++State#state.ssip++">"]),
    Addr.

to(State)-> from(State).

build_register(State=#state{})->
    From=from(State),
    To=to(State),
    {ok, Request, _CallId, _FromTag, _CSeqNo} =
	siphelper:start_generate_request("REGISTER",From,To,
	                                 [], []),
    {ok, Request}.

resend_register(Request,State) ->
    [Contact] = keylist:fetch('contact', Request#request.header),
    Header = Request#request.header,
    NewRequest = Request#request{header=Header},
    {ok, Pid, _Branch} = siphelper:send_request(NewRequest),
    State#state{contact=Contact}.    
do_send_register(Request,State) ->
    [Contact] = keylist:fetch('contact', Request#request.header),
    Header = Request#request.header,
    CSeq = State#state.cseq + 1,
    NewHeader = keylist:set("CSeq", [lists:concat([CSeq, " ", Request#request.method])], Header),
    NewRequest = Request#request{header=NewHeader},
    {ok, Pid, _Branch} = siphelper:send_request(NewRequest),
    State#state{cseq=CSeq,contact=Contact}.    

lookup()->
    fun(_Realm, _From, _To)-> {ok,"55010","ol55117"} end.


test_build_register()->     build_register(#state{}).

test_auths()->
    Response = {response,401,"Unauthorized",
                         {keylist,
                             [{keyelem,via,"Via",
                                  ["SIP/2.0/UDP 10.32.7.23:5060;branch=z9hG4bK-yxa-sha4uh+hjdv0dj4+ggxkig-oniwr4kvqtztp4zoagnx0eg"]},
                              {keyelem,from,"From",
                                  ["<sip:55010@sip.ringonet.info>;tag=yxa-0uza+lihj"]},
                              {keyelem,to,"To",
                                  ["<sip:55010@sip.ringonet.info>;tag=iSWTPHir6rcEVQGMKlzVBrHMwQ"]},
                              {keyelem,'call-id',"Call-ID",
                                  ["1367700650-561203@10.32.7.23"]},
                              {keyelem,cseq,"CSeq",["1 REGISTER"]},
                              {keyelem,'www-authenticate',"WWW-Authenticate",
                                  ["Digest realm=\"n-soft.com\", nonce=\"9af5431d10154aa9756cfe960e2cd933-1367821579-129\", opaque=\"4901cb29713e0c5943358e34269e21d9\""]},
                              {keyelem,'user-agent',"User-Agent",
                                  ["N-SOFT-UA-5.25.4 -RIN1-2939- www.n-soft.com"]},
                              {keyelem,allow,"Allow",
                                  ["ACK","BYE","CANCEL","INVITE","OPTIONS",
                                   "REGISTER","PRACK"]},
                              {keyelem,'content-length',"Content-Length",
                                  ["0"]}]},
                         <<>>},
    {ok, Auths, _Changed} = siphelper:update_authentications(Response, lookup(), []).
  %  {ok, NewRequest} = add_authorization(Request, Auths).

