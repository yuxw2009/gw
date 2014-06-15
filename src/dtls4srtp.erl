-module(dtls4srtp).

-compile(export_all).

-behaviour(gen_fsm).


-include_lib("ssl/src/ssl_internal.hrl").
-include_lib("ssl/src/ssl_cipher.hrl").
-include_lib("public_key/include/public_key.hrl"). 
-include("dtls4srtp_handshake.hrl").
-include("dtls4srtp_record.hrl").
-include("dtls4srtp.hrl"). 

%external api.
-export([new/5, start/1, start/5, shutdown/1, on_received/2, set_peer_cert_fingerprint/2, get_self_cert_fingerpirnt/1]).

% gen_fsm callbacks.
-export([init/1, hello/2, certify/2, connection/2,
	handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

-record(state, {
	  role,               % client | server
          owner,              % pid() or name of a registered process. 
          epoch = 0, 
  	  seq_no = 0,
  	  tmr,
  	  tmrV = 1,
      tmr_failed,
          flight_begin_epoch,
          flight_begin_seq_no,
          flight_begin_cs,
  	  msg_seq_s = 0,
  	  msg_seq_r = 0,
          srtp_params,         % #srtp_params from dtls4srtp.hrl.
          peer_cert_fingerprint, % {Algorithm, binary()}.
          self_cert_fingerprint, % {Algorithm, binary()}.
          file_ref_db,         % ets()
	  cert_db_ref,         % ref()
	  cert_db,
	  session_cache,
          connection_states,     % #connection_states{} from ssl_record.hrl
          flights_tosend = [],   % binary() buffer of incomplete records.
          retrans_timer,         % Ref() of timer.
          retrans_timerV = 1,    % time(unit:second) to retransmit the last flight.
          tls_handshake_history, % tls_handshake_history()
          session,             % #session{} from dtls4srtp_handshake.hrl
          client_certificate_requested = false,
	  key_algorithm,       % atom as defined by cipher_suite
	  hashsign_algorithm,  % atom as defined by cipher_suite
          public_key_info,     % PKIX: {Algorithm, PublicKey, PublicKeyParams}
          private_key,         % PKIX: #'RSAPrivateKey'{}
	  diffie_hellman_params, % PKIX: #'DHParameter'{} relevant for server side
	  diffie_hellman_keys, % {PublicKey, PrivateKey}
	  psk_identity,        % binary() - server psk identity hint
	  srp_params,          % #srp_user{}
	  srp_keys,            % {PublicKey, PrivateKey}
          premaster_secret,    %
	  client_ecc          % {Curves, PointFmt}
	}).

%% external Interfaces.
start(Role, Owner, PeerCertFingerP, CertFile, PKeyFile) ->
    {ok, Pid} = gen_fsm:start(?MODULE, {Role, Owner, PeerCertFingerP, CertFile, PKeyFile}, []),
    gen_fsm:send_event(Pid, start),
    Pid.

new(Role, Owner, PeerCertFingerP, CertFile, PKeyFile) ->
    {ok, Pid} = gen_fsm:start(?MODULE, {Role, Owner, PeerCertFingerP, CertFile, PKeyFile}, []),
    Pid.

set_owner(PRef, OwnerPid) ->
    gen_fsm:send_all_state_event(PRef, {set_owner, OwnerPid}).

start(PRef) ->
    gen_fsm:send_event(PRef, start).

shutdown(PRef) ->
    gen_fsm:send_all_state_event(PRef, shutdown).

on_received(PRef, Data) when is_binary(Data) ->
    ReceivedFlights = dtls4srtp_record:decode_flight(Data),
    lists:foreach(fun(R) -> gen_fsm:send_event(PRef, {received_peer_record, R}) end, ReceivedFlights).

set_peer_cert_fingerprint(PRef, FingerP) ->
    gen_fsm:send_all_state_event(PRef, {peer_cert_fingerprint, FingerP}).

get_self_cert_fingerpirnt(PRef) ->
    gen_fsm:sync_send_all_state_event(PRef, self_cert_fingerprint).

retrans_timer_expired(PRef) ->
    gen_fsm:send_all_state_event(PRef, retrans_timer_expired).




%% callbacks for gen_fsm.
init({Role, Owner, PeerCertFingerPrint, CertFile, KeyFile}) ->
    State0 = initial_state(Role, Owner, PeerCertFingerPrint),
    Handshake = tls_handshake:init_handshake_history(),
    TimeStamp = calendar:datetime_to_gregorian_seconds({date(), time()}),
    try make_secure_identities(Role, CertFile, KeyFile) of
    	{ok, Ref, CertDbHandle, FileRefHandle, CacheHandle, OwnCert, Key, DHParams} ->
	    Session = State0#state.session,
            OwnCertDigestAlgo = digest_algo(OwnCert),
	    State = State0#state{
				 tls_handshake_history = Handshake,
				 session = Session#session{own_certificate = OwnCert,
							   time_stamp = TimeStamp},
			         file_ref_db = FileRefHandle,
				 cert_db_ref = Ref,
				 cert_db = CertDbHandle,
				 session_cache = CacheHandle,
                                 self_cert_fingerprint = make_fingerprint(OwnCertDigestAlgo, OwnCert),
				 private_key = Key,
				 diffie_hellman_params = DHParams,
				 flights_tosend = []},
	    {ok,hello,State}
    catch
	throw:Error ->
	    {stop,Error}
    end.

%%
hello(start, #state{role=client, owner=Owner, epoch=Epoch, seq_no=SeqNo, msg_seq_s=MsgSeqS, 
			connection_states=ConnectionStates0, tls_handshake_history=Handshake0} = State0) ->
    Pending = tls_record:pending_connection_state(ConnectionStates0, read),
    SecParams = Pending#connection_state.security_parameters,
    ClientHello = dtls4srtp_handshake:client_hello(MsgSeqS, SecParams#security_parameters.client_random),
    HS1 = tls_handshake:update_handshake_history(Handshake0, ClientHello),
    {ClientHelloBin, CS1} = encode_client_hello(ClientHello, ConnectionStates0, Epoch, SeqNo),
    Owner ! {dtls, flight, ClientHelloBin},
    {ok, Tref} = timer:apply_after(1000, ?MODULE, retrans_timer_expired, [self()]),
    {ok, TRef1} = timer:apply_after(60000, ?MODULE, fail_timer_expired, [self()]),
    State1 = State0#state{seq_no = SeqNo+1,
                          tmr = Tref,
                          tmrV = 1,
                          tmr_failed = TRef1,
                          msg_seq_s = MsgSeqS+1,
                          flights_tosend = [{?HANDSHAKE, ClientHello}],
                          flight_begin_epoch = Epoch,
                          flight_begin_seq_no = SeqNo+1,
                          flight_begin_cs = ConnectionStates0,
                          connection_states=CS1,
			  tls_handshake_history = HS1},
    {next_state, hello, State1};

hello({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?HELLO_VERIFY_REQUEST, fragment=HelloVerifyRequest}}, 
      #state{owner=Owner, role = client, tmr=Tmr, epoch=Epoch, seq_no=SeqNo, msg_seq_s=MsgSeqS, msg_seq_r=MsgSeqR, connection_states=CS0} = State0) ->
    #hello_verify_request{protocol_version = {16#fe, 16#ff}, cookie = Cookie} = dtls4srtp_handshake:dec_hs(?HELLO_VERIFY_REQUEST, HelloVerifyRequest),
    timer:cancel(Tmr),
    Handshake0 = tls_handshake:init_handshake_history(),
    Pending = tls_record:pending_connection_state(CS0, read),
    SecParams = Pending#connection_state.security_parameters,
    ClientHello = dtls4srtp_handshake:client_hello(MsgSeqS, SecParams#security_parameters.client_random, Cookie),
    HS1 = tls_handshake:update_handshake_history(Handshake0, ClientHello),
    {ClientHelloBin, CS1} = encode_client_hello(ClientHello, CS0, Epoch, SeqNo),
    Owner ! {dtls, flight, ClientHelloBin},
    {ok, Tref} = timer:apply_after(1000, ?MODULE, retrans_timer_expired, [self()]),
    State1 = State0#state{seq_no = SeqNo+1,
                          tmr = Tref,
                          tmrV = 1,
                          msg_seq_s=MsgSeqS+1,
                          msg_seq_r=MsgSeqR+1,
                          flights_tosend = [{?HANDSHAKE, ClientHello}],
                          flight_begin_epoch = Epoch,
                          flight_begin_seq_no = SeqNo+1,
                          flight_begin_cs = CS0,
                          connection_states=CS1,
                          tls_handshake_history = HS1},
    {next_state, hello, State1};

hello({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?SERVER_HELLO, content_raw=Raw, message_seq=MsgSeqR, fragment=ServerHello}}, 
      #state{role = client, tmr=Tmr, msg_seq_r = MsgSeqR, connection_states=CS0, session=Session0, tls_handshake_history=HS0} = State0) ->
    #dtls_server_hello{server_version = {16#fe, 16#ff} = Version,
                random = Random,
                session_id = SessionID,
                cipher_suite = CipherSuite,
                compression_method = CompMethod,
                renegotiation_info = _RenegotiationInfo,
                hash_signs = _HashSigns,
                elliptic_curves = _EllipticCurves,
                use_srtp=UseSrtp} = dtls4srtp_handshake:dec_hs(?SERVER_HELLO, ServerHello),
    State00 = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    CS00=tls_record:set_renegotiation_flag(true, CS0),
    CS1 = hello_pending_connection_states(client, {3, 2}, CipherSuite, Random, CompMethod, CS00),
    {KeyAlgorithm, _, _, _} = ssl_cipher:suite_definition(CipherSuite),
    PremasterSecret = make_premaster_secret(Version, KeyAlgorithm),
    HashsignAlgorithm = default_hashsign(Version, KeyAlgorithm),
    timer:cancel(Tmr),
    ProtectionProfileDetail = proplists:get_value(UseSrtp#use_srtp.protection_profile, ?PROTECTION_PROFILE_DETAILS),
    ProtectionProfileName = proplists:get_value(UseSrtp#use_srtp.protection_profile, ?PROTECTION_PROFILE_NAMES),
    SrtpParams = #srtp_params{protection_profile_name = ProtectionProfileName,
                              protection_profile_detail=ProtectionProfileDetail,
                              mki=UseSrtp#use_srtp.mki},
    State1 = State00#state{session=Session0#session{session_id=SessionID},
                        connection_states=CS1,
                        key_algorithm=KeyAlgorithm,
                        hashsign_algorithm=HashsignAlgorithm,
                        premaster_secret=PremasterSecret,
                        flights_tosend = [],
                        srtp_params=SrtpParams},
    {next_state, certify, State1#state{msg_seq_r=MsgSeqR+1}};

hello({received_peer_record, #dtls_record{}}, #state{}=St) ->
    io:format("receieved unexpected record at state[~p].~n", [hello]),
    {next_state, hello, St}.

certify({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?CERTIFICATE, content_raw=Raw, message_seq=MsgSeqR, fragment=Certificate}}, 
      #state{role = client, msg_seq_r = MsgSeqR, session=Session, tls_handshake_history=HS0} = State0) ->
    #certificate{asn1_certificates = ASN1Certs} = dtls4srtp_handshake:dec_hs(?CERTIFICATE, Certificate),
    State00 = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    [PeerCert | _] = ASN1Certs,
    case public_key:pkix_path_validation(selfsigned_peer, lists:reverse(ASN1Certs), [{max_path_length, 1}, {verify_fun, validate_fun_and_state()}]) of
        {ok, {PublicKeyInfo,_}} ->
            State1 = State00#state{session = 
			 Session#session{peer_certificate = PeerCert},
			 public_key_info=PublicKeyInfo},
            %io:format("PublicKeyInfo:~p~n", [PublicKeyInfo]),
	    State2 =
                case PublicKeyInfo of
                    {?'id-ecPublicKey',  #'ECPoint'{point = _ECPoint} = PublicKey, PublicKeyParams} ->
                        ECDHKey = public_key:generate_key(PublicKeyParams),
                        ec_dh_master_secret(ECDHKey, PublicKey, State1#state{diffie_hellman_keys=ECDHKey});
                     _ ->
                        State1
                end,
            {next_state, certify, State2#state{msg_seq_r=MsgSeqR+1}};
        {error, _Reason} ->
            io:format("Peer certificate validation failed.~n"),
            {next_state, certify, State00}
    end; 

certify({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?SERVER_KEY_EXCHANGE, content_raw=Raw, message_seq=MsgSeqR, fragment=ServerKeyChange}}, 
      #state{role = client, msg_seq_r = MsgSeqR, key_algorithm = KeyAlg, tls_handshake_history=HS0} = State0) ->
    #server_key_exchange{exchange_keys = Keys} = dtls4srtp_handshake:dec_hs(?SERVER_KEY_EXCHANGE, ServerKeyChange),
    State00 = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    Params = tls_handshake:decode_server_key(Keys, KeyAlg, {3, 2}),
    HashSign = connection_hashsign(Params#server_key_params.hashsign, State0),
    State1 = 
        case HashSign of
            {_, SignAlgo} when SignAlgo == anon; SignAlgo == ecdh_anon ->
                server_master_secret(Params#server_key_params.params, State00);
            _ ->
                verify_server_key(Params, HashSign, State00)
        end,
    {next_state, certify, State1#state{msg_seq_r=MsgSeqR+1}};

certify({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?CERTIFICATE_REQUEST, content_raw=Raw, message_seq=MsgSeqR, fragment=CertificateRequest}}, 
      #state{role = client, msg_seq_r = MsgSeqR, tls_handshake_history=HS0} = State0) ->
    #certificate_request{} = dtls4srtp_handshake:dec_hs(?CERTIFICATE_REQUEST, CertificateRequest), 
    State = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    {next_state, certify, State#state{msg_seq_r=MsgSeqR+1}};

certify({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?SERVER_HELLO_DONE, content_raw=Raw, message_seq=MsgSeqR, fragment=ServerHelloDone}}, 
      #state{session = #session{master_secret = MasterSecret} = Session,
	       connection_states = ConnectionStates0,
	       premaster_secret = undefined,
	       role = client,
               tls_handshake_history=HS0} = State0) ->
    #server_hello_done{} = dtls4srtp_handshake:dec_hs(?SERVER_HELLO_DONE, ServerHelloDone),
    State00 = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    
    %io:format("MasterSecret:~p~nVersion:~p~nSession:~p~nConnectionStates0:~p~n", [MasterSecret, Version, Session, ConnectionStates0]),
    {MasterSecret, ConnectionStates} = tls_handshake:master_secret({3, 2}, Session, ConnectionStates0, client),
    State1 = State00#state{connection_states = ConnectionStates},
    State = client_certify_and_key_exchange(State1),
    {next_state, cipher, State#state{msg_seq_r=MsgSeqR+1}};
certify({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?SERVER_HELLO_DONE, content_raw=Raw, message_seq=MsgSeqR, fragment=ServerHelloDone}}, 
      #state{session = Session0,
	       connection_states = ConnectionStates0,
	       premaster_secret = PremasterSecret,
	       role = client,
               tls_handshake_history = HS0} = State0) ->    
    #server_hello_done{} = dtls4srtp_handshake:dec_hs(?SERVER_HELLO_DONE, ServerHelloDone),
    State00 = State0#state{tls_handshake_history=tls_handshake:update_handshake_history(HS0, Raw)},
    {MasterSecret, ConnectionStates} = tls_handshake:master_secret({3, 2}, PremasterSecret, ConnectionStates0, client),
    Session = Session0#session{master_secret = MasterSecret},
    State1 = State00#state{connection_states = ConnectionStates, session = Session},
    State = client_certify_and_key_exchange(State1),
    {next_state, cipher, State#state{msg_seq_r=MsgSeqR+1}};

certify({received_peer_record, #dtls_record{}}, #state{}=St) ->
    io:format("receieved unexpected record at state[~p].~n", [certify]),
    {next_state, certify, St}.

cipher({received_peer_record, #dtls_record{type=?CHANGE_CIPHER_SPEC, content_raw=_Raw, fragment = <<1:8>>}}, 
      #state{connection_states = ConnectionStates0, role = client, tmr=Tmr} = State0) ->
    timer:cancel(Tmr),
    ConnectionStates1 = tls_record:activate_pending_connection_state(ConnectionStates0, read),
    {next_state, cipher, State0#state{connection_states = ConnectionStates1}};

cipher({received_peer_record, #dtls_record{type=?HANDSHAKE, content_type=?FINISHED, content_raw=Raw, fragment=CipheredFrag}}, 
      #state{connection_states = ConnectionStates0,
               tls_handshake_history = Handshake0,
               session = #session{master_secret = MasterSecret},
	       role = Role,
               srtp_params=SrtpParams,
               owner=Owner,
               tmr_failed = TRef} = State0) ->
    timer:cancel(TRef),
    {PlainFrag, ConnStates} = dtls4srtp_record:decipher_dtls_record(CipheredFrag, ConnectionStates0),
    <<?FINISHED:8, _PlLen:24, _MsgSeq:16, _FragOffset:24, FragLen:24, VerifyData:(FragLen)/binary>> = PlainFrag,
    Handshake1 = tls_handshake:update_handshake_history(Handshake0, Raw),
    Finished = #finished{verify_data = VerifyData},
    verified = tls_handshake:verify_connection({3, 2}, Finished, 
					 opposite_role(Role), 
					 get_current_connection_state_prf(ConnStates, read),
					 MasterSecret, Handshake1),
    %Session = register_session(Role, "Host", "Port", Session0),
    ConnectionStates1 = tls_record:set_server_verify_data(current_both, VerifyData, ConnStates),
    NewSrtpParams = gen_srtp_key_material(ConnectionStates1, SrtpParams),
    Owner ! {dtls, key_material, NewSrtpParams},
    {next_state, connection, State0#state{connection_states = ConnectionStates1,
                                          premaster_secret = undefined,
					  public_key_info = undefined,
                                          srtp_params = NewSrtpParams,
					  tls_handshake_history = tls_handshake:init_handshake_history()}};

cipher({received_peer_record, #dtls_record{}}, #state{}=St) ->
    io:format("receieved unexpected record at state[~p].~n", [cipher]),
    {next_state, cipher, St}.

connection(_Event, St) -> {next_state, connection, St}. 

%% problem remainning: different strategy should be adopted while state==hello or cipher.
handle_event(retrans_timer_expired, StateName, #state{role=client, owner=Owner, flight_begin_epoch=Epoch, flight_begin_seq_no=SeqNo, flight_begin_cs=CS0, tmrV=TmrV,
			flights_tosend=Flight}=State0) ->
    %{NewEpoch, NextTryBeginSeqNo, Bin} = dtls4srtp_record:encode_flight(Epoch, SeqNo, CS0, Flight),
    {NewEpoch, NextTryBeginSeqNo, PreEpochNextSeqNo, NextTryCS, Bin} =
        dtls4srtp_record:encode_flight(Epoch, SeqNo, CS0, Flight),
    Owner ! {dtls, flight, Bin},
    NewTmrV = update_timer_value(TmrV),
    {ok, Tref} = timer:apply_after(NewTmrV*1000, ?MODULE, retrans_timer_expired, [self()]),
    State1 = State0#state{flight_begin_seq_no = if NewEpoch == Epoch -> NextTryBeginSeqNo; true -> PreEpochNextSeqNo end,
                          epoch = NewEpoch,
                          seq_no = NextTryBeginSeqNo,
                          connection_states = NextTryCS,
                          tmr = Tref,
                          tmrV = NewTmrV},
    {next_state, StateName, State1};

handle_event(fail_timer_expired, StateName, #state{role=client, owner=Owner}=State0) ->
    Owner ! {dtls, handshake_timeout},
    {next_state, StateName, State0};

handle_event({set_owner, OwnerPid}, StateName, #state{}=St) ->
    {next_state, StateName, St#state{owner=OwnerPid}};

handle_event({peer_cert_fingerprint, FingerP}, StateName, #state{}=St) ->
    {next_state, StateName, St#state{peer_cert_fingerprint=FingerP}};

handle_event(errordown, _, #state{}=St) -> 
    {stop, {shutdown, error}, St};
handle_event(shutdown, _, #state{}=St) -> 
    {stop, {shutdown, normal}, St}.

handle_sync_event(expect2receive, _, StateName, #state{msg_seq_r=MsgSeqR}=St) ->
    {reply,MsgSeqR,StateName,St};
handle_sync_event(self_cert_fingerprint, _, StateName, #state{self_cert_fingerprint=SCFP}=St) ->
    {reply,SCFP,StateName,St}.

handle_info(_Info, StateName, StateData) -> 
    {next_state, StateName, StateData}.

terminate(_Reason, _StateName, _StateData) ->
    ok.

code_change(_OldVsn, StateName, StateData, _Extra) -> 
    {ok, StateName, StateData}.

%% internal functions.
initial_state(Role, Owner, PeerCertFingerP) ->
    ConnectionStates = tls_record:init_connection_states(Role),
    #state{session = #session{is_resumable = new},
	   role = Role,
           owner = Owner,
           peer_cert_fingerprint = PeerCertFingerP,
	   connection_states = ConnectionStates
	  }.

make_fingerprint(HashAlgo, Cert) ->
    {HashAlgo, crypto:hash(HashAlgo, Cert)}.

make_secure_identities(Role, CertFile, KeyFile) ->
    init_manager_name(false),
    {ok, CertDbRef, CertDbHandle, FileRefHandle, PemCacheHandle, CacheHandle, OwnCert} = init_certificates(Role, CertFile),
    PrivateKey = init_private_key(PemCacheHandle, KeyFile),
    {ok, CertDbRef, CertDbHandle, FileRefHandle, CacheHandle, OwnCert, PrivateKey, undefined}.

init_manager_name(false) ->
    put(ssl_manager, ssl_manager).

init_certificates(Role, CertFile) ->
    {ok, CertDbRef, CertDbHandle, FileRefHandle, PemCacheHandle, CacheHandle} =
	{ok, _, _, _, _, _} = ssl_manager:connection_init(<<>>, Role),
    init_certificates(CertDbRef, CertDbHandle, FileRefHandle, PemCacheHandle, CacheHandle, CertFile, Role).

init_certificates(CertDbRef, CertDbHandle, FileRefHandle, PemCacheHandle, CacheHandle, CertFile, client) ->
    [OwnCert|_] = ssl_certificate:file_to_certificats(CertFile, PemCacheHandle),
    {ok, CertDbRef, CertDbHandle, FileRefHandle, PemCacheHandle, CacheHandle, OwnCert}.

init_private_key(DbHandle, KeyFile) ->
    {ok, List} = ssl_manager:cache_pem_file(KeyFile, DbHandle),
    [PemEntry] = [PemEntry || PemEntry = {PKey, _ , _} <- List,
			  PKey =:= 'RSAPrivateKey' orelse
			      PKey =:= 'DSAPrivateKey' orelse
			      PKey =:= 'ECPrivateKey' orelse
			      PKey =:= 'PrivateKeyInfo'
	     ],
    private_key(public_key:pem_entry_decode(PemEntry)).

private_key(#'PrivateKeyInfo'{privateKeyAlgorithm =
				 #'PrivateKeyInfo_privateKeyAlgorithm'{algorithm = ?'rsaEncryption'},
			     privateKey = Key}) ->
    public_key:der_decode('RSAPrivateKey', iolist_to_binary(Key));

private_key(#'PrivateKeyInfo'{privateKeyAlgorithm =
				 #'PrivateKeyInfo_privateKeyAlgorithm'{algorithm = ?'id-dsa'},
			     privateKey = Key}) ->
    public_key:der_decode('DSAPrivateKey', iolist_to_binary(Key));

private_key(Key) ->
    Key.

digest_algo(CertBin) ->
    #'Certificate'{signatureAlgorithm=#'AlgorithmIdentifier'{algorithm=Algo}} = public_key:pem_entry_decode({'Certificate', CertBin, not_encrypted}),
    case Algo of
        ?'sha1WithRSAEncryption' -> sha;
        ?'sha512WithRSAEncryption' -> sha512;
        ?'sha384WithRSAEncryption' -> sha384;
        ?'sha256WithRSAEncryption' -> sha256;
        ?'md5WithRSAEncryption' -> md5  
    end.

hello_pending_connection_states(Role, Version, CipherSuite, Random, Compression,
				 ConnectionStates) ->    
    ReadState =  
	tls_record:pending_connection_state(ConnectionStates, read),
    WriteState = 
	tls_record:pending_connection_state(ConnectionStates, write),
    
    NewReadSecParams = 
	hello_security_parameters(Role, Version, ReadState, CipherSuite,
			    Random, Compression),
    
    NewWriteSecParams =
	hello_security_parameters(Role, Version, WriteState, CipherSuite,
			    Random, Compression),
 
    tls_record:update_security_params(NewReadSecParams,
				    NewWriteSecParams,
				    ConnectionStates).

hello_security_parameters(client, Version, ConnectionState, CipherSuite, Random,
			  Compression) ->   
    SecParams = ConnectionState#connection_state.security_parameters,
    NewSecParams = ssl_cipher:security_parameters(Version, CipherSuite, SecParams),
    NewSecParams#security_parameters{
      server_random = Random,
      compression_algorithm = Compression
     }.

gen_srtp_key_material(ConnectionStates, #srtp_params{protection_profile_detail=#protection_profile_detail{cipher_key_length=KeyLen, cipher_salt_length=SaltLen}}=SrtpParams) ->
    ConnectionState = tls_record:current_connection_state(ConnectionStates, read),
    SecParams = ConnectionState#connection_state.security_parameters,
    #security_parameters{master_secret = MasterSecret,
       client_random = ClientRandom,
       server_random = ServerRandom} = SecParams,
    <<ClntWrtMKey:KeyLen, SvrWrtMKey:KeyLen, ClntWrtSalt:SaltLen, SvrWrtSalt:SaltLen>> =
    ssl_tls1:prf(?MD5SHA, MasterSecret, "EXTRACTOR-dtls_srtp", [ClientRandom, ServerRandom], (2*(KeyLen+SaltLen)) div 8),
    %io:format("gen_srtp_key_material, KeyLen:~p,SaltLen:~p~nresult(~p):~p~n", [KeyLen, SaltLen, byte_size(Rslt), Rslt]),
    %SrtpParams.
    SrtpParams#srtp_params{client_write_SRTP_master_key= <<ClntWrtMKey:KeyLen>>,
                           server_write_SRTP_master_key= <<SvrWrtMKey:KeyLen>>,
                           client_write_SRTP_master_salt= <<ClntWrtSalt:SaltLen>>,
                           server_write_SRTP_master_salt= <<SvrWrtSalt:SaltLen>>}.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
update_timer_value(TmrV) when TmrV > 60 -> 1;
update_timer_value(TmrV) -> 2*TmrV.

make_premaster_secret({MajVer, MinVer}, rsa) ->
    Rand = ssl:random_bytes(48-2),
    <<?BYTE(MajVer), ?BYTE(MinVer), Rand/binary>>;
make_premaster_secret(_, _) ->
    undefined.

connection_hashsign(HashSign = {_, _}, _State) ->
    HashSign;
connection_hashsign(_, #state{hashsign_algorithm = HashSign}) ->
    HashSign.


verify_server_key(#server_key_params{params = Params,
		             params_bin = EncParams,
		             signature = Signature},
	           HashSign = {HashAlgo, _},
	           #state{public_key_info = PubKeyInfo,
			     connection_states = ConnectionStates} = State) ->
    ConnectionState = tls_record:pending_connection_state(ConnectionStates, read),
    SecParams = ConnectionState#connection_state.security_parameters,
    #security_parameters{client_random = ClientRandom,
			 server_random = ServerRandom} = SecParams, 
    Hash = tls_handshake:server_key_exchange_hash(HashAlgo,
						  <<ClientRandom/binary,
						    ServerRandom/binary,
						    EncParams/binary>>),
    case tls_handshake:verify_signature({3, 2}, Hash, HashSign, Signature, PubKeyInfo) of
    %case true of
	true ->
	    server_master_secret(Params, State);
	false ->
	    io:format("verify_server_key failed.~n"),
	    State
    end.


server_master_secret(#server_dh_params{dh_p = P, dh_g = G, dh_y = ServerPublicDhKey},
         St) ->
    dh_master_secret(P, G, ServerPublicDhKey, undefined, St);

server_master_secret(#server_ecdh_params{curve = ECCurve, public = ECServerPubKey},
         St) ->
    ECDHKeys = public_key:generate_key(ECCurve),
    ec_dh_master_secret(ECDHKeys, #'ECPoint'{point = ECServerPubKey}, St#state{diffie_hellman_keys = ECDHKeys});

server_master_secret(#server_psk_params{
      hint = IdentityHint},
         St) ->
    %% store for later use
    St#state{psk_identity = IdentityHint}.


dh_master_secret(#'DHParameter'{} = Params, OtherPublicDhKey, MyPrivateKey, St) ->
    PremasterSecret = public_key:compute_key(OtherPublicDhKey, MyPrivateKey, Params),
    master_from_premaster_secret(PremasterSecret, St).

dh_master_secret(Prime, Base, PublicDhKey, undefined, St) ->
    Keys = {_, PrivateDhKey} = crypto:generate_key(dh, [Prime, Base]),
    dh_master_secret(Prime, Base, PublicDhKey, PrivateDhKey, St#state{diffie_hellman_keys = Keys});

dh_master_secret(Prime, Base, PublicDhKey, PrivateDhKey, St) ->
    PremasterSecret = crypto:compute_key(dh, PublicDhKey, PrivateDhKey, [Prime, Base]),
    master_from_premaster_secret(PremasterSecret, St).


ec_dh_master_secret(ECDHKeys, ECPoint, St) ->
    PremasterSecret = public_key:compute_key(ECPoint, ECDHKeys),
    master_from_premaster_secret(PremasterSecret, St).


%% RFC 5246, Sect. 7.4.1.4.1.  Signature Algorithms
%% If the client does not send the signature_algorithms extension, the
%% server MUST do the following:
%%
%% -  If the negotiated key exchange algorithm is one of (RSA, DHE_RSA,
%%    DH_RSA, RSA_PSK, ECDH_RSA, ECDHE_RSA), behave as if client had
%%    sent the value {sha1,rsa}.
%%
%% -  If the negotiated key exchange algorithm is one of (DHE_DSS,
%%    DH_DSS), behave as if the client had sent the value {sha1,dsa}.
%%
%% -  If the negotiated key exchange algorithm is one of (ECDH_ECDSA,
%%    ECDHE_ECDSA), behave as if the client had sent value {sha1,ecdsa}.

default_hashsign({16#fe, 16#ff}, KeyExchange) ->
    default_hashsign({3, 2}, KeyExchange);
default_hashsign(_Version = {Major, Minor}, KeyExchange)
  when Major == 3 andalso Minor >= 3 andalso
       (KeyExchange == rsa orelse
  KeyExchange == dhe_rsa orelse
  KeyExchange == dh_rsa orelse
  KeyExchange == ecdhe_rsa orelse
  KeyExchange == srp_rsa) ->
    {sha, rsa};
default_hashsign(_Version, KeyExchange)
  when KeyExchange == rsa;
       KeyExchange == dhe_rsa;
       KeyExchange == dh_rsa;
       KeyExchange == ecdhe_rsa;
       KeyExchange == srp_rsa ->
    {md5sha, rsa};
default_hashsign(_Version, KeyExchange)
  when KeyExchange == ecdhe_ecdsa;
       KeyExchange == ecdh_ecdsa;
       KeyExchange == ecdh_rsa ->
    {sha, ecdsa};
default_hashsign(_Version, KeyExchange)
  when KeyExchange == dhe_dss;
       KeyExchange == dh_dss;
       KeyExchange == srp_dss ->
    {sha, dsa};
default_hashsign(_Version, KeyExchange)
  when KeyExchange == dh_anon;
       KeyExchange == ecdh_anon;
       KeyExchange == psk;
       KeyExchange == dhe_psk;
       KeyExchange == rsa_psk;
       KeyExchange == srp_anon ->
    {null, anon}.

validate_fun_and_state() ->
   {fun(_OtpCert, _ExtensionOrVerifyResult, _SslState) ->
       {valid, client}
     end, client}.


master_from_premaster_secret(PremasterSecret,
			     #state{session = Session,
				    role = Role,
				    connection_states = ConnectionStates0} = State) ->
    {MasterSecret, ConnectionStates} = tls_handshake:master_secret({3, 2}, PremasterSecret,
				     ConnectionStates0, Role),
    State#state{session = Session#session{master_secret = MasterSecret},
	        connection_states = ConnectionStates}.

client_certify_and_key_exchange(#state{epoch=Epoch, owner=Owner, connection_states=CS0} = State0) ->
    {State1, ClientCertificate, Bin1} = certify_client(State0),
    {State2, ClientKeyExchange, Bin2} = key_exchange(State1),
    {State3, CertificateVerify, Bin3} = verify_client_cert(State2),
    {State4, CipherSpec, Bin4} = cipher_protocol(State3),
    {State5, Finish, Bin5} = finished(State4),

    Flight = [{?HANDSHAKE, ClientCertificate}
               , {?HANDSHAKE, ClientKeyExchange}
               , {?HANDSHAKE, CertificateVerify}
               , {?CHANGE_CIPHER_SPEC, CipherSpec}
               , {?HANDSHAKE, Finish}
               ],
    Bin = iolist_to_binary([Bin1, Bin2, Bin3, Bin4, Bin5]),
    Owner ! {dtls, flight, Bin},
    {ok, Tref} = timer:apply_after(5000, ?MODULE, retrans_timer_expired, [self()]),
    State5#state{tmr = Tref,
                 tmrV = 5,
                 flight_begin_epoch = Epoch,
                 flight_begin_seq_no = State3#state.seq_no + 1,
                 flight_begin_cs = CS0,
                 flights_tosend = Flight}.


certify_client(#state{role = client,
                      epoch = Epoch,
                      seq_no = SeqNo,
                      connection_states = ConnectionStates0,
		      cert_db = CertDbHandle,
                      cert_db_ref = CertDbRef,
		      session = #session{own_certificate = OwnCert},
                      tls_handshake_history = Handshake0,
                      msg_seq_s=MsgSeqS} = State) ->
    Certificate = tls_handshake:certificate(OwnCert, CertDbHandle, CertDbRef, client),
    {BinCert, Frag, ConnectionStates, Handshake} =
        encode_handshake(Certificate, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                 connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinCert}.

key_exchange(#state{role = client, 
		    epoch = Epoch,
                    seq_no = SeqNo,
                    connection_states = ConnectionStates0,
		    key_algorithm = rsa,
		    public_key_info = PublicKeyInfo,
		    premaster_secret = PremasterSecret,
		    tls_handshake_history = Handshake0,
                      msg_seq_s=MsgSeqS} = State) ->
    Msg = rsa_key_exchange(PremasterSecret, PublicKeyInfo),
    {BinMsg, Frag, ConnectionStates, Handshake} =
        encode_handshake(Msg, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinMsg};
key_exchange(#state{role = client, 
                    epoch = Epoch,
                    seq_no = SeqNo,
                    connection_states = ConnectionStates0,
		    key_algorithm = Algorithm,
		    diffie_hellman_keys = {DhPubKey, _},
		    tls_handshake_history = Handshake0,
                      msg_seq_s=MsgSeqS} = State)
  when Algorithm == dhe_dss;
       Algorithm == dhe_rsa;
       Algorithm == dh_anon ->
    Msg =  tls_handshake:key_exchange(client, {3, 2}, {dh, DhPubKey}),
    {BinMsg, Frag, ConnectionStates, Handshake} =
        encode_handshake(Msg, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinMsg};

key_exchange(#state{role = client,
                    epoch = Epoch,
                    seq_no = SeqNo,
                    connection_states = ConnectionStates0,
		    key_algorithm = Algorithm,
		    diffie_hellman_keys = Keys,
		    tls_handshake_history = Handshake0,
                      msg_seq_s=MsgSeqS} = State)
  when Algorithm == ecdhe_ecdsa; Algorithm == ecdhe_rsa;
       Algorithm == ecdh_ecdsa; Algorithm == ecdh_rsa;
       Algorithm == ecdh_anon ->
    Msg = tls_handshake:key_exchange(client, {3, 2}, {ecdh, Keys}),
    %io:format("key_exchange, Keys:~p~nMsg:~p~n", [Keys, Msg]),
    {BinMsg, Frag, ConnectionStates, Handshake} =
        encode_handshake(Msg, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinMsg}.

rsa_key_exchange(PremasterSecret, PublicKeyInfo = {Algorithm, _, _})
  when Algorithm == ?rsaEncryption;
       Algorithm == ?md2WithRSAEncryption;
       Algorithm == ?md5WithRSAEncryption;
       Algorithm == ?sha1WithRSAEncryption;
       Algorithm == ?sha224WithRSAEncryption;
       Algorithm == ?sha256WithRSAEncryption;
       Algorithm == ?sha384WithRSAEncryption;
       Algorithm == ?sha512WithRSAEncryption
       ->
    tls_handshake:key_exchange(client, {3, 2},
			       {premaster_secret, PremasterSecret,
				PublicKeyInfo}).

verify_client_cert(#state{role = client,
                          epoch = Epoch,
                          seq_no = SeqNo,
                          connection_states = ConnectionStates0,
			  private_key = PrivateKey,
			  session = #session{master_secret = MasterSecret,
					     own_certificate = OwnCert},
        key_algorithm = _KeyAlgorithm,
			  hashsign_algorithm = HashSign,
			  tls_handshake_history = Handshake0,
			  msg_seq_s=MsgSeqS} = State) ->

    %io:format("KeyAlgorithm:~p,HashSign:~p~nPrivateKey:~p~n,Handshake0:~p~n", [KeyAlgorithm, HashSign, PrivateKey, Handshake0]),
    #certificate_verify{} = Verified = tls_handshake:client_certificate_verify(OwnCert, MasterSecret, 
						 {3, 2}, HashSign, PrivateKey, Handshake0),
    {BinVerified, Frag, ConnectionStates, Handshake} = 
        encode_handshake(Verified, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo),
    %io:format("CertificateVerify:~p~n",[BinVerified]),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinVerified}.

cipher_protocol(#state{epoch = Epoch,
                       seq_no = SeqNo,
                       connection_states = ConnectionStates0}=State) ->
    {BinChangeCipher, ConnectionStates1} =
        encode_change_cipher(#change_cipher_spec{}, ConnectionStates0, Epoch, SeqNo),
    ConnectionStates = tls_record:activate_pending_connection_state(ConnectionStates1, write),
    {State#state{connection_states=ConnectionStates, epoch=Epoch+1, seq_no=0}, <<1:8>>, BinChangeCipher}.
   
finished(#state{role = Role,
		session = Session,
                epoch = Epoch,
                seq_no = SeqNo,
                connection_states = ConnectionStates0,
                tls_handshake_history = Handshake0,
                msg_seq_s=MsgSeqS}=State) ->
    MasterSecret = Session#session.master_secret,
    Finished = tls_handshake:finished({3, 2}, Role,
				       get_current_connection_state_prf(ConnectionStates0, write),
				       MasterSecret, Handshake0),
    %Finished = #finished{verify_data=ssl:random_bytes(12)},
    ConnectionStates1 = save_verify_data(Role, Finished, ConnectionStates0, certify),
    {BinFinished, Frag, ConnectionStates, Handshake} =
        encode_handshake(Finished, MsgSeqS, ConnectionStates1, Handshake0, Epoch, SeqNo),
    {State#state{msg_seq_s=MsgSeqS+1, tls_handshake_history=Handshake,
                connection_states=ConnectionStates, seq_no=SeqNo+1}, Frag, BinFinished}.

save_verify_data(client, #finished{verify_data = Data}, ConnectionStates, certify) ->
    tls_record:set_client_verify_data(current_write, Data, ConnectionStates).

get_current_connection_state_prf(CStates, Direction) ->
	CS = tls_record:current_connection_state(CStates, Direction),
	CS#connection_state.security_parameters#security_parameters.prf_algorithm.

register_session(client, _Host, _Port, #session{is_resumable = new} = Session0) ->
    Session = Session0#session{is_resumable = true},
    %%ssl_manager:register_session(Host, Port, Session),
    Session.

%%%%%%%
encode_change_cipher(#change_cipher_spec{}, ConnectionStates, Epoch, SeqNo) ->
    dtls4srtp_record:encode_change_cipher_spec(ConnectionStates, Epoch, SeqNo).

encode_handshake(HandshakeRec, MsgSeqS, ConnectionStates0, Handshake0, Epoch, SeqNo) ->
    Frag = dtls4srtp_handshake:encode_handshake(HandshakeRec, MsgSeqS),
    %io:format("Handshake0:~p, Frag:~p~n", [Handshake0, Frag]),
    Handshake1 = tls_handshake:update_handshake_history(Handshake0, Frag),
    {E, ConnectionStates1} =
        dtls4srtp_record:encode_handshake(Frag, ConnectionStates0, Epoch, SeqNo),
    {E, Frag, ConnectionStates1, Handshake1}.

encode_client_hello(Frag, ConnectionStates0, Epoch, SeqNo) ->
    dtls4srtp_record:encode_handshake(Frag, ConnectionStates0, Epoch, SeqNo).


opposite_role(client) ->
    server;
opposite_role(server) ->
    client.

