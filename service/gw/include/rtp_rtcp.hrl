

-record(src_info, {
	media
	ssrc,
	crypto,
	control_ssrc,
	control_crypto,
	cname,
	marker,
	pln,	% payload number(type)
	base_seq,
	base_timecode,
	base_wallclock,
	roc = 0,
	seq,
	timecode,
	wallclock,
	last_sr_seq,
	last_sr_wc,
	rtt,
	interarrival_jitter = 0,
	total_losts = 0,
	lost_seqs = [],
	tmp_rcvd_pkts = 0,
	tmp_lost_pkts = 0,
	total_snd_pkts = 0,
	total_snd_bytes= 0,
	pli,
	remb
}).

