-module(urlenc).
-compile(export_all).

escape_uri(S) when is_integer(S) ->   escape_uri(integer_to_list(S));
escape_uri(S) when is_atom(S) ->   escape_uri(atom_to_list(S));
escape_uri(S) when is_list(S) ->   escape_uri(list_to_binary(S));
escape_uri(Bin)-> escape_uri(Bin,[]).

escape_uri(<<>>,Reverse)-> lists:reverse(Reverse);
escape_uri(<<C:8, Cs/binary>>,Rev) when C >= $a, C =< $z ->  escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) when C >= $A, C =< $Z -> escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) when C >= $0, C =< $9 -> escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) when C == $. -> escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) when C == $- -> escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) when C == $_ -> escape_uri(Cs, [C|Rev]);
escape_uri(<<C:8, Cs/binary>>,Rev) -> escape_uri(Cs, [escape_byte(C)|Rev]).

escape_byte(C) ->
    "%" ++ hex_octet(C).

hex_octet(N) when N =< 9 ->
    [$0 + N];
hex_octet(N) when N > 15 ->
    hex_octet(N bsr 4) ++ hex_octet(N band 15);
hex_octet(N) ->
    [N - 10 + $a].

test()-> "你好".
