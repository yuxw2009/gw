-module(node_conf).
-compile(export_all).


register_self()-> 
    rpc:call(config_node(),node_reg,reg_wmg_node,[node()]).

config_node()->
    Str="node_manage@182.254.140.79", % interface.x9water.com",
    list_to_atom(Str).
get_voice_node()->'incomingproxy@127.0.0.1';
get_voice_node()->
    R=rpc:call(config_node(),node_reg,get_voice_node,[]),
    R.
get_wras_node()->
    R=rpc:call(config_node(),node_reg,get_wras_node,[]),
    R.
get_wmg_node()-> node();
get_wmg_node()->
    R=rpc:call(config_node(),node_reg,get_wmg_node,[]),
    R.    