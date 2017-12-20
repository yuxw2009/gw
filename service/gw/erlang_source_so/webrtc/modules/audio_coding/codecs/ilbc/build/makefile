CC = gcc
CFLAGS = -fPIC -shared
INCLUDE = -I /usr/local/lib/erlang/usr/include \
		  -I ../interface \
		  -I ../../../../.. \
		  -I ../../../../../.. \
		  -I ../../../../../common_audio/signal_processing/include

SOURCES = $(wildcard ../*.c)
LOCALOBJS = $(wildcard *.o)
SP_SOURCES = $(wildcard ../../../../../common_audio/signal_processing/*.c)

compile_sp:
	$(CC) -O3 -DWEBRTC_POSIX $(CFLAGS) -c $(SP_SOURCES) $(INCLUDE)

compile:
	$(CC) -O3 -DWEBRTC_POSIX $(CFLAGS) -c $(SOURCES) $(INCLUDE)

compile_test:
	$(CC) -DWEBRTC_POSIX -c ../test/iLBC_test.c $(INCLUDE)

test:
	$(CC) -lm -lpthread  $(LOCALOBJS) -o iLBC_test

ilbc:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c erl_ilbc.c $(INCLUDE)

nif:
	$(CC) -lm -lpthread $(CFLAGS) $(LOCALOBJS) -o erl_ilbc.so
