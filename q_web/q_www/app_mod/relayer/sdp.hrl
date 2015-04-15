-record(session_desc, {
  version = <<"0">>,
  originator,
  name,
  connect,
  time     = {0, 0}, %% {integer(), integer()},
  attrs    = []   %% [sdp_attr()]
}).

-record(media_desc, {
  type,
  connect,
  port,
  rtcp,
  candidates	 = [],  %% [#cdd{}]
  payloads       = [],  %% [#payload{}]
  track_control,
  pps,
  sps,
  config,
  attrs = [],
  ice,      %% {ufrag,password}
  crypto,
  ssrc_info = [],
  profile
}).

-record(sdp_o, {
  username = <<"-">>,
  sessionid,
  version,
  netaddrtype = inet4,  %% inet4 | inet6,
  address %% string()
}).

-record(payload, {
  num,
  codec,
  clock_map,
  ptime,   %% integer(),
  maxptime,
  config = []
}).

-record(cdd,{
  compon,     % integer
  founda,     % integer
  priori,     % integer
  proto,      % atom
  addr,     % string
  port,     % integer
  typ = "host",
  genera = 0
}).

-record(video_frame,{
	content        = undefined, %%frame_content(),
	dts            = undefined, %%number(),
	pts            = undefined, %%number(),
	stream_id      = 0,         %%non_neg_integer(),
	codec 	       = undefined, %%frame_codec()|undefined,
	flavor         = undefined, %%frame_flavor(),
	sound          = {undefined, undefined, undefined}, %%frame_sound(),
	pltype         = undefined, %% payload type
	body           = <<>>,      %%binary(),
	next_id        = undefined %%any()
}).

