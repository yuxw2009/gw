CC = gcc
CFLAGS = -O3 -fPIC -shared
INCLUDE = -I /otp/erlang/lib/erlang/usr/include \
		  -I ../include \
		  -I ../../.. \
		  -I ../../../.. \
		  -I ../../../common_audio/signal_processing/include

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@ $(INCLUDE)

SOURCES = $(wildcard ../*.c)
SP_SOURCES = ../../signal_processing/division_operations.c \
             ../../signal_processing/resample_48khz.c \
             ../../signal_processing/resample_by_2_internal.c \
             ../../signal_processing/resample_fractional.c \
             ../../signal_processing/energy.c \
             ../../signal_processing/get_scaling_square.c \
             ../../signal_processing/spl_init.c \
             ../../signal_processing/min_max_operations.c \
             ../../signal_processing/cross_correlation.c \
             ../../signal_processing/downsample_fast.c \
             ../../signal_processing/vector_scaling_operations.c \
             ../../signal_processing/real_fft.c \
             ../../signal_processing/complex_bit_reverse.c \
             ../../signal_processing/complex_fft.c

LOCALOBJS = $(wildcard *.o)
OBJS = $(patsubst %.c,%.o,$(SOURCES))

compile_sp:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c $(SP_SOURCES) $(INCLUDE)

compile:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c $(SOURCES) $(INCLUDE)

vad:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c erl_vad.c $(INCLUDE)

nif:
	$(CC) -lm -lpthread $(CFLAGS) $(LOCALOBJS) -o erl_vad.so
