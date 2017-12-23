-ifndef(PACKET_H).
-define(PACKET_H, true).

-define(FS16K,16000).
-define(FS8K,8000).
-define(PTIME,20).
-define(PSIZE,160).
-define(ISACPTIME,30).

-define(LOSTAUDIO,1003).

-record(trans_packet, {
    codec,              %% pcmu | iSAC | iLBC | opus | g729 ... etc.,
    sample_rate,
    sample_count,
    body = <<>>         %%binary()
}).

-record(raw_packet, {
    format,             %% pcm16
    sample_rate,
    sample_count,
    body = <<>>         %%binary()
}).

-endif.
