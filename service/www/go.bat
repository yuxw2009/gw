ulimit -n 409600
yaws --name www@127.0.0.1 --conf yaws.conf  --erlarg "-setcookie sbxyz  +K true"  --runmod wcg_manager