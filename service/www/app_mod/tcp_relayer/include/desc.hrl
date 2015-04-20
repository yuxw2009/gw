-define(RTCP_SR, 200).
-define(RTCP_RR, 201).
-define(RTCP_SD, 202).
-define(RTCP_BYE,203).

-define(RTCP_RTPFB,205).
-define(FMT_NACK, 1).		% rfc4585
-define(FMT_TMMBR, 3).		% rfc5104
-define(FMT_TMMBN, 4).

-define(RTCP_PSFB, 206).
-define(FMT_PLI, 1).
-define(FMT_ALFB, 15).

-define(DESC_CNAME, 1).

-define(REMB, 16#52454D42).

-record(rtcp_sr, {
	ssrc,
	ts64,
	rtp_ts,
	packages = 0,
	bytes = 0,
	receptions = []
}).

-record(rtcp_rr, {
	ssrc,
	receptions = []
}).

-record(rtcp_bye, {
	ssrc
}).

-record(source_report, {
	ssrc,
	lost,
	eseq,
	jitter,
	sr_ts,
	sr_delay
}).

-record(rtcp_sd, {
	ssrc,
	cname
}).

-record(rtcp_pl, {
	ssrc,
	ms,
	pli = false,
	remb,
	nack = []
}).

-define(YEARS_70, 2208988800).  % RTP bases its timestamp on NTP. NTP counts from 1900. Shift it to 1970. This constant is not precise.

-record(audio_frame,{
	content        = audio, %%frame_content(),
	owner,
	stream_id      = 0,         %%non_neg_integer(),
	codec 	       = undefined, %%frame_codec()|undefined,
	marker         = false,
	samples,					%% number of samples in frame
	body           = <<>>       %%binary()
}).

-record(srtp_desc, {
	origid,
	ssrc,
	vssrc,
	ckey,		% crypto inline binary
	cname,
	label,
	ice			% {ufrag,pwd} 2 binary
}).

-record(cryp, {
	method,
	e_k,
	e_s,
	a_k
}).

-record(base_info, {
	ssrc,
	cssrc,
	cname,
	pln,	% payload number(type)
	roc = 0,
	seq,
	base_seq,
	timecode,
	base_timecode,
	%
	sr_ts_m32,
	sr_rcv_time,
	sr_pkgs,
	sr_byts,
	remb,
	jitter_buf = [],
	previous_ts,
	interarrival_jitter = 0,
	cumu_lost = 0,
	lost_seqs = [],
	pkts_rcvd = 0,
	pkts_lost = 0
}).

-record(base_rtp, {
	media,
	cname,
	ssrc,
	cssrc,
	roc = 0,
	seq = undefined,
	codec,
	marker, 		%%  :: undefined | true | false,
	wall_clock = undefined,
	timecode = undefined,
	base_timecode = undefined,
	packets = 0,	%%  :: integer(),
	bytes   = 0, 	%%  :: integer()
	bytes_btwn_sr=0,
	last_sr = 0,
	sr_ref,
	fb_pli = false,
	fb_remb = 0,
	rtt = 0,
	srpt_eseq,
	fraction_lost = 0.0
}).
