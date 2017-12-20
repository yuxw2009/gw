CC = gcc
CFLAGS = -O3 -fPIC -shared
INCLUDE = -I /otp/erlang/lib/erlang/usr/include \
		  -I ../include \
		  -I ../../../../.. \
		  -I ../../../../../.. \
		  -I ../../../../../common_audio/signal_processing/include

SOURCES = $(wildcard ../*.c)
LOCALOBJS = $(wildcard *.o)
SP_SOURCES = ../../../../../common_audio/signal_processing/spl_init.c \
             ../../../../../common_audio/signal_processing/min_max_operations.c \
             ../../../../../common_audio/signal_processing/cross_correlation.c \
             ../../../../../common_audio/signal_processing/downsample_fast.c \
             ../../../../../common_audio/signal_processing/vector_scaling_operations.c \
             ../../../../../common_audio/signal_processing/real_fft.c \
             ../../../../../common_audio/signal_processing/complex_bit_reverse.c \
             ../../../../../common_audio/signal_processing/complex_fft.c \
             ../../../../../common_audio/signal_processing/energy.c \
             ../../../../../common_audio/signal_processing/get_scaling_square.c \
             ../../../../../common_audio/signal_processing/division_operations.c \
             ../../../../../common_audio/signal_processing/get_hanning_window.c \
             ../../../../../common_audio/signal_processing/ilbc_specific_functions.c \
             ../../../../../common_audio/signal_processing/auto_correlation.c \
             ../../../../../common_audio/signal_processing/levinson_durbin.c \
             ../../../../../common_audio/signal_processing/spl_sqrt.c \
             ../../../../../common_audio/signal_processing/randomization_functions.c \
             ../../../../../common_audio/signal_processing/filter_ar.c \
             ../../../../../common_audio/signal_processing/copy_set_operations.c

compile_sp:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c $(SP_SOURCES) $(INCLUDE)

compile:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c $(SOURCES) $(INCLUDE)

cng:
	$(CC) -DWEBRTC_POSIX $(CFLAGS) -c erl_cng.c $(INCLUDE)

nif:
	$(CC) -lm -lpthread $(CFLAGS) $(LOCALOBJS) -o erl_cng.so
