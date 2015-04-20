-module(wwwcfg).

-compile(export_all).

get(test_node)-> 'gw_git_new@120.24.101.50';
get(monitor)->'monitor@120.24.101.50';
get(voice_node)->'voice@120.24.101.50'.

get_serid()-> "ml".

get_wcgnode(default)-> get_wcgnode("Mainland");
get_wcgnode("Mainland")->'gw_copy1@119.29.9.55';
get_wcgnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'gw_git@198.47.124.131';
get_wcgnode(_)->'gw_git@202.122.107.66'.

get_wwwnode(default)-> get_wwwnode("Mainland");
get_wwwnode("Mainland")->'gw_copy1@119.29.9.55';
get_wwwnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'gw_git@198.47.124.131';
get_wwwnode(_)->'www@fc2fc.com'.

get_internal_wcgnode(Continent) when Continent=="Europe" orelse Continent=="Africa" orelse Continent=="SouthAmerica"-> 'gw_git@198.47.124.131';
get_internal_wcgnode(_)->'gw_git@202.122.107.66'.

cluster()-> ['www_t@fc2fc.com','www_dth@lwork.hk'].
