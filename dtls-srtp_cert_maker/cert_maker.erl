-module(cert_maker).

-compile(export_all).



make(Period) ->
    application:start(crypto),
    application:start(asn1),
    application:start(public_key),
    application:start(ssl),

    DefFrom = calendar:gregorian_days_to_date(calendar:date_to_gregorian_days(date())-1),
    DefTo   = calendar:gregorian_days_to_date(calendar:date_to_gregorian_days(date())+Period),
    erl_make_certs:write_pem("./", "webRTCVoIP", erl_make_certs:make_cert([{digest, sha256}, {validity, {DefFrom, DefTo}}, {subject, [{name, "WebRTCWCG"}]}])).


