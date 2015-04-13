gcc -fPIC -shared -c erl_amix.c -I /otp/erlang/lib/erlang/usr/include
gcc -fPIC -shared erl_amix.o -o erl_amix.so