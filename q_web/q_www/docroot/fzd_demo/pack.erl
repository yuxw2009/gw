-module(pack).
-compile(export_all).

do1()->
	B=read_files(files()),
	io:format("ok! please obfuscator lw2fzd.min.js, and save result to script/lw2fzd.min.js"),
	file:write_file("lw2fzd.min.js",B).

do2()->
	{ok,B1} = file:read_file("script/jquery-1.6.3.min.js"),
	{ok,B2} = file:read_file("script/lw2fzd.min.js"),
	B= <<B1/binary,B2/binary>>,
	file:write_file("script/lw2fzd.min.js",B),
	io:format("ok, javascript/lw2fzd.min.js generated with jquery ahead").

files()->
	[
 "script/lworkVideoImport.js",
 "script/createwin.js",
 "script/voip.js","script/lw_lang.js",
 "script/api.js","script/tipsplugin.js",
 "script/webrtc.js"].

read_files(Fs)->
	read_files(Fs, <<>>).
read_files([], R)-> R;
read_files([H|Rest], R)->
	{ok, B} = file:read_file(H),
	read_files(Rest, <<R/binary, B/binary>>).

