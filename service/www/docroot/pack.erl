-module(pack).
-compile(export_all).

do1()->
	B0=read_files(files()),
	B= <<";(function(){\r\n",B0/binary, "})();">>,
	io:format("ok! results saved to lw2fzd.130905.js"),
	file:write_file("lw2fzd.130905.js",B).

do2()->
	{ok,B1} = file:read_file("script/jquery-1.6.3.min.js"),
	{ok,B2} = file:read_file("lw2fzd.130905.js"),
	B= <<B1/binary,B2/binary>>,
	file:write_file("script/lw2fzd.130905.js",B),
	io:format("ok, javascript/lw2fzd.130905.js generated with jquery ahead").

files()->
	[
 "script/lworkVideoImport.js",
 "script/createwin.js",
 "script/webrtc.js",
  "script/api.js",
 "script/restchannel.js",
  "script/restconnection.js",
"script/voip.js"  ].

read_files(Fs)->
	read_files(Fs, <<>>).
read_files([], R)-> R;
read_files([H|Rest], R)->
	{ok, B} = file:read_file(H),
	B1 = <<B/binary, <<"\r\n">>/binary>>,
	read_files(Rest, <<R/binary, B1/binary>>).

