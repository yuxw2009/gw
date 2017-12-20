CC = gcc
CFLAGS = -fPIC -shared
INCLUDE = -I /otp/erlang/lib/erlang/usr/include \
		  -I ../interface \
		  -I ../../../../../../.. \
		  -I ../../../../../.. \
		  -I ../../../../../../common_audio/signal_processing/include \
		  -I ../../../../../../system_wrappers/interface

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@ $(INCLUDE)

SOURCES = $(wildcard ../source/*.c ../processing/*.c ../test/*.c)
LOCALOBJS = $(wildcard *.o)
OBJS = $(patsubst %.c,%.o,$(SOURCES))

compile:
	$(CC) -O3 -DWEBRTC_POSIX $(CFLAGS) -c $(SOURCES) $(INCLUDE)

example:
	$(CC) -lm -lpthread $(LOCALOBJS) -o isacfix

isac:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c erl_isac_nb.c $(INCLUDE)

nif:
	$(CC) -lm -lpthread $(CFLAGS) $(LOCALOBJS) -o erl_isac.so

nb:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c erl_isac_nb.c $(INCLUDE) -I ../../../g711

nif_nb:
	$(CC) -lm -lpthread $(CFLAGS) $(LOCALOBJS) -o erl_isac_nb.so
