-record(qfileinfo,{fid,fn,uptime=erlang:localtime(),status=init}).

-record(qfiles, {uuid,files=[]}).

