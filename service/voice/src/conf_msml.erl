-module(conf_msml).
-compile(export_all).

%% external interface
build_conf(Name)->  xml(msml(create(Name))).
destroy_conf(Name)->  xml(msml(destroy(Name))).
join_conf(ConnName, ConfName)->  xml(msml(join(ConnName, ConfName))).
reset()-> xml(msml(reset_())).
send_dtmf(Id, Digits)-> xml(msml(dtmfgen(Id, Digits))).
play(Target, Filename)-> xml(msml(play_(Target, Filename))).
end_dialog(Id)-> xml(msml(dialogend_(Id))).
aec_conn(Connname, enable)-> xml(msml(aec_(Connname, enable))).


%%  internal function
xml(Cont)->
    "<?xml version=\"1.0\" encoding=\"US-ASCII\"?>\r\n"++Cont.
msml(Cont)->
    "<msml version=\"1.1\">\r\n"++Cont ++"\r\n</msml>\r\n".
create(Name)->
    lists:concat(["<createconference name=","\"",Name,"\"", " deletewhen=\"nomedia\">\r\n",
                           "<audiomix id=", "\"", Name,"\"",  " samplerate=\"8000\">\r\n",
                           "<n-loudest n=\"3\"/>\r\n",
                           "<asn ri=\"10s\"/>\r\n",
                           "</audiomix>\r\n",
                           "</createconference>"]).
destroy(Name)->
    lists:concat(["<destroyconference id=","\"conf:",Name,"\">", 
                           " </destroyconference>"]).
    
join(Conn, Conf)->
    lists:concat(["<join id1=\"conn:" ++ Conn ++ "\" ",  "id2=\"conf:"++Conf++"\">\r\n",
                              "<stream media=\"audio\" dir=\"to-id1\"/>\r\n",
                              "<stream media=\"audio\" dir=\"from-id1\"/>\r\n",
                        "</join>"]).

aec_(Conn, enable)->
    lists:concat(["<configureconnection id=\"conn:" ++ Conn ++ "\" ", ">\r\n",
                              "<aec enabled=\"true\" ri=\"5s\" active-mode=\"auto\"/>\r\n",
                        "</configureconnection>"]).
    
reset_()-> "<reset context=\"msml\"/>".

build_conf_name()->
    {H, Min, Sec} = time(),
    {_,_,Ms} = now(),
    lists:concat(["Conf","H",H,"M",Min,"S",Sec,"Ms",Ms]).

dialogstart(Target, Content)->
    lists:concat([
        "<dialogstart target=" ++ "\""++Target++"\"" ++" " ++ "type=\"application/moml+xml\"" ++">" ++ "\r\n",
%        "<!--MOML document begins here-->" ++ "\r\n",
        Content ++ "\r\n",
%        "<!--MOML document ends here-->" ++ "\r\n",
        "</dialogstart>"
    ]).

dialogend_(Id)->
    "<dialogend id=\""++Id ++"\"/>".

dtmfgen(Connname, Digits)->
    dialogstart("conn:"++Connname, dtmfgen(Digits)).
    
dtmfgen(Digits)->
    lists:concat(["<dtmfgen id=\"mydtmfgen\" digits="++"\""++Digits++"\"" ++ " dur=\"100ms\"" ++ ">\r\n",
                                "<dtmfgenexit>"++"\r\n",
                                "<send target=\"source\" event=\"app.dtmfgen_0_424\" namelist=\"dtmfgen.end\"> "++"\r\n",
                                "</send> "++"\r\n",
                                "</dtmfgenexit> "++"\r\n",
                        "</dtmfgen>"
    ]).

play_(Target, Filename)->
    dialogstart(Target, play_(Filename)).
    
play_(Filename)->
    lists:concat(["<play cvd:barge=\"true\" cvd:cleardb=\"true\">\r\n",
                        "<audio uri=\"" ++ Filename ++ "\"/>\r\n",
                        "<playexit>\r\n",
                        "<send target=\"source\" event=\"app.playDone\"\r\n",
                        "namelist=\"play.amt play.end\"/>\r\n",
                        "</playexit>\r\n",
                        "</play>"]).

