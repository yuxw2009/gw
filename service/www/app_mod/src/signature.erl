-module(signature).
-compile(export_all).
 
% Looking at using Open SSH public and private keys
% for signing and verifying hashed data.
 
load_private_key(Filename) ->
  {ok, Pem} = file:read_file(Filename),
  [Entry] = public_key:pem_decode(Pem),
  public_key:pem_entry_decode(Entry).
 
sign_verify(PublicKey, PrivateKey, Digest) ->
  Signature = public_key:sign(Digest, sha, PrivateKey),
  true = public_key:verify(Digest, sha, Signature, PublicKey).
 
test() ->
  Msg = "This is the message",
  Digest = crypto:sha(Msg),
  PublicKey = load_private_key("rsa_public_key.pem"),
  PrivateKey = load_private_key("rsa_private_key.pem"),
  sign_verify(PublicKey, PrivateKey, Digest).