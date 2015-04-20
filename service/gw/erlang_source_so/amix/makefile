CFLAGS = -fPIC -shared
INCLUDE = -I /usr/local/lib/erlang/usr/include

mix:
	gcc -fPIC -c erl_amix.c $(INCLUDE)

nif:
	gcc $(CFLAGS) erl_amix.o -o erl_amix.so
