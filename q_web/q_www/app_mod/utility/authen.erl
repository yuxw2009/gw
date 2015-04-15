-module(authen).

-compile(export_all).

-define(TOKEN_PREFIX, "T1==").

shmac(Secret,Datastring)->
    <<Mac:160/integer>> = crypto:sha_mac(Secret, Datastring),
    iolist_to_binary(io_lib:format("~40.16.0b", [Mac])).

decode_token(Token) when is_list(Token)-> decode_token(list_to_binary(Token));
decode_token(Token)->  % TOKEN_PREFIX++base64(partner_id=(apikey)&sig=(signature):(datastring))
	<<?TOKEN_PREFIX, Bin/binary>> = Token,
	Token_str=base64:decode_to_string(Bin),
	Paras=re:split(Token_str, "&", [{parts,2}]),
	Pl = [list_to_tuple(re:split(P, "=",[{parts,2}])) || P<-Paras],
	ApiKey = proplists:get_value(<<"partner_id">>, Pl),
	Sig=proplists:get_value(<<"sig">>,Pl),
	[Signature,Datastring]=re:split(Sig, ":", [{parts,2}]),
	{ApiKey, Signature, Datastring}.

do(Token)->
	try decode_token(Token) of
		{Ak, Sig, D}->
			Scr=account:secret(Ak),
			shmac(Scr, D) == Sig
	catch
		_:_R->
			false
	end.
