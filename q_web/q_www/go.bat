ulimit -n 409600
yaws --sname www --conf yaws.conf --runmod im_router --erlarg "-setcookie sbxyz"  