%%% @author     Max Lapshin <max@maxidoors.ru> [http://erlyvideo.org]
%%% @copyright  2010 Max Lapshin
%%% @doc        logger module
%%% @end
%%% @reference  See <a href="http://erlyvideo.org/rtp" target="_top">http://erlyvideo.org</a> for common information.
%%% @end
%%%
%%% This file is part of erlang-rtp.
%%%
%%% erlang-rtp is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% erlang-rtp is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with erlang-rtp.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%---------------------------------------------------------------------------------------

-define(D(X), io:format("~p:~p ~p",[?MODULE, ?LINE, X])).
-define(DBG(F,A), io:format("(~w:~b): " ++ F, [?MODULE, ?LINE] ++ A)).

-define(PRINT(Format, Args),
    io:format("~n"++Format, Args)).