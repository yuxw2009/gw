
-record(topo, {roles = [],      %%key:role_name, value:num,
               drcts = [],      %%key:role_name, value:{to_role, from_role}
               tracks = []      %%[{Role, {[{ToRole, a|v|av}], [{FromRole, a|v|av}]}}|]
               }).