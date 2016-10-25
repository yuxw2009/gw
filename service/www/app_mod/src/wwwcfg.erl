-module(wwwcfg).

-compile(export_all).

get(test_node)-> 'gw_git_new@120.24.101.50';
get(monitor)->'monitor@120.24.101.50';
get(voice_node)-> 'voice@10.32.7.28';%'voice_ext@fc2fc.com'.%
get(sms_node)-> 'voice@10.32.3.52'.%'voice_ext@fc2fc.com'.%

get_serid()-> "ml".

get_ios_wcgnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'gw@10.32.2.4';
get_ios_wcgnode(_)->'gw1@119.29.62.190'.

%get_wcgnode(default)-> get_wcgnode("Mainland");
get_wcgnode("Mainland")-> 'gw1@112.74.96.171';%'gw1@10.31.203.1';%'gw_git@202.122.107.66';%'gw1@119.29.62.190';  %
get_wcgnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 
  'gw@10.32.2.4';
%  'gw_git@202.122.107.66';
get_wcgnode(_)->'gw_git@202.122.107.66'.

get_wwwnode(default)-> get_wwwnode("Mainland");
get_wwwnode("Mainland")->'wcgwww@119.29.62.190';
get_wwwnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'www_dth@10.32.3.52';
get_wwwnode(_)->'www_dth@10.32.3.52'.

get_www_url_list(default)-> get_www_url_list("Mainland");
get_www_url_list("Mainland")->[<<"https://lwork.hk">>,<<"http://202.122.107.66:8080">>];
get_www_url_list(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 
    [<<"http://202.122.107.66:8080">>,<<"https://lwork.hk">>];
get_www_url_list(_)->    [<<"http://202.122.107.66:8080">>,<<"https://lwork.hk">>].

get_internal_wcgnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'gw@10.32.2.4';
get_internal_wcgnode(_)->'gw_git@202.122.107.66'.

cluster()-> ['www_t@10.32.7.28','www_dth@10.32.3.52'].
