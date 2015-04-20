-module(roomtopo).
-include("roomtopo.hrl").

-compile(export_all).

from_type_attr(Type, Attrs) when is_binary(Type)-> from_type_attr(list_to_atom(binary_to_list(Type)),Attrs);
from_type_attr(p2pav, [{"capacity", Cap}]) ->from_type_attr(p2pav, [{capacity, Cap}]);
from_type_attr(p2pav, [{capacity, Cap}]) ->
    #topo{roles=[{peer, Cap}], drcts=[{peer, {[peer], [peer]}}], tracks=[{peer, {[{peer, av}], [{peer, av}]}}]}.

capacity_of_role(Role, #topo{roles=Roles}) -> proplists:get_value(Role, Roles, 0).

stream_between(SelfRole, PeerRole, #topo{drcts=Streams}) ->
    connection_type(SelfRole, proplists:get_value(PeerRole, Streams)).


connection_type(PeerRole, {ToRoles, FromRoles}) ->
    connection_type({s_no, r_no}, PeerRole, {ToRoles, FromRoles}).

connection_type(Cur, _PeerRole, {[], []}) ->
    Cur;
connection_type({_S, R}, PeerRole, {[PeerRole|_], FromRoles}) ->
    connection_type({s_yes, R}, PeerRole, {[], FromRoles});
connection_type({S, R}, PeerRole, {[_OtherRole|F], FromRoles}) ->
    connection_type({S, R}, PeerRole, {F, FromRoles});
connection_type({S, _R}, PeerRole, {[], [PeerRole|_]}) ->
    connection_type({S, r_yes}, [], {[], []});
connection_type({S, R}, PeerRole, {[], [_OtherRole|T]}) ->
    connection_type({S, R}, PeerRole, {[], T}).

tracks_between(SelfRole, PeerRole, #topo{tracks=Tracks}) ->
    {ToRoles, FromRoles} = proplists:get_value(SelfRole, Tracks, {[],[]}),
    case {get_track(none, PeerRole, ToRoles), get_track(none, PeerRole, FromRoles)} of 
    	              %%{SelfTracks={Audio, Video}, PeerTracks={Audio, Video}}
    	{none, none} -> {{none, none},{none, none}};
    	{none, a} ->    {{receive_only, none},{send_only, none}};
    	{none, v} ->    {{none, receive_only},{none, send_only}};
    	{none, av} ->   {{receive_only, receive_only},{send_only, send_only}};
    	{a, none} ->    {{send_only, none},{receive_only, none}};
    	{a, a} ->       {{send_receive, none},{send_receive, none}};
        {a, v} ->       {{send_only, receive_only},{receive_only, send_only}};
    	{a, av} ->      {{send_receive, receive_only},{send_receive, send_only}};
    	{v, none} ->    {{none, send_only},{none, receive_only}};
    	{v, a} ->       {{receive_only, send_only},{send_only, receive_only}};
    	{v, v} ->       {{none, send_receive},{none, send_receive}};
    	{v, av} ->      {{receive_only, send_receive},{send_only, send_receive}};
        {av, none} ->   {{send_only, send_only},{receive_only, receive_only}};
        {av, a} ->      {{send_receive, send_only},{send_receive, receive_only}};
        {av, v} ->      {{send_only, send_receive},{receive_only, send_receive}};
        {av, av} ->     {{send_receive, send_receive},{send_receive, send_receive}}
    end.

get_track(Track, _PeerRole, []) -> Track;
get_track(_Track, PeerRole, [{PeerRole, AV}|_T]) -> AV;
get_track(Track, PeerRole, [{_AnotherRole, _}|T]) -> get_track(Track, PeerRole, T).


%%%test
test() ->
   test_connection_type_judgement(),
   test_tracks_between(),
   ok.

test_connection_type_judgement() ->
    {s_no, r_no} = connection_type(aa, {[], []}),
    {s_no, r_no} = connection_type(aa, {[], [bb, cc]}),
    {s_no, r_no} = connection_type(aa, {[bb, cc], []}),
    {s_no, r_no} = connection_type(aa, {[bb, cc], [dd, ee]}),

    {s_yes, r_no} = connection_type(slave, {[slave], []}),
    {s_yes, r_no} = connection_type(slave, {[slave, aa], []}),
    {s_yes, r_no} = connection_type(slave, {[slave, aa], [bb]}),

    {s_no, r_yes} = connection_type(master, {[], [master]}),
    {s_no, r_yes} = connection_type(master, {[], [master, aa]}),
    {s_no, r_yes} = connection_type(master, {[bb], [master, aa]}),

    {s_yes, r_yes} = connection_type(aa, {[aa], [aa]}),
    {s_yes, r_yes} = connection_type(aa, {[aa, bb], [aa, cc]}),
    ok.

test_tracks_between() ->
    Topo1=#topo{roles=[{peer, 2}], drcts=[{peer, {[peer], [peer]}}], tracks=[{peer, {[{peer, av}], [{peer, av}]}}]},
    {{send_receive, send_receive}, {send_receive, send_receive}} = tracks_between(peer, peer, Topo1),
    ok.

