-module(browser_agent).

-export([send/2]).

send(PtPid,M)->
    xhr_poll:down(PtPid, M).
    