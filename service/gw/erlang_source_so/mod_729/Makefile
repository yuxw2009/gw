IPPARCH=em64t
LARCH=$(IPPARCH)
CC=gcc 
FSBASE=#path to the source code of FS
IPPBASE=/opt/intel/ipp/6.1.6.063/$(IPPARCH)
IPPCORE=u8

CC_OPT=-fPIC -O3 -DIPPCORE_STATIC_INIT -fomit-frame-pointer -march=nocona -fno-exceptions

INCLUDE=-I$(IPPBASE)/include -include "$(IPPBASE)/tools/staticlib/ipp_$(IPPCORE).h" -I /otp/erlang/lib/erlang/usr/include


LDFLAGS =-Wl,-static -L"$(IPPBASE)/lib" -avoid-version -module -lippscmerged$(LARCH) -lippsrmerged$(LARCH) -lippsmerged$(LARCH) -lippcore$(LARCH) -liomp5


all : decg729.o encg729.o owng729.o vadg729.o aux_tbls.o libg729.o erl_g729.o
	$(CC) $(INCLUDE) -shared -O2 -Wall -Xlinker -x -o erl_g729.so  \
	   	erl_g729.o libg729.o decg729.o encg729.o owng729.o vadg729.o aux_tbls.o \
	  	-lm $(LDFLAGS) -L/usr/local/lib -Wl,-Bdynamic -shared -pthread -lrt -luuid -lcrypt

decg729.o : decg729.c
	$(CC) $(CC_OPT) -c decg729.c $(INCLUDE)
encg729.o : encg729.c
	$(CC) $(CC_OPT) -c encg729.c $(INCLUDE)
owng729.o : owng729.c 
	$(CC) $(CC_OPT) -c owng729.c $(INCLUDE)
vadg729.o : vadg729.c
	$(CC) $(CC_OPT) -c vadg729.c $(INCLUDE)
aux_tbls.o : aux_tbls.c
	$(CC) $(CC_OPT) -c aux_tbls.c $(INCLUDE)

libg729.o: libg729.c
	$(CC) $(CC_OPT) -c libg729.c $(INCLUDE)
erl_g729.o: erl_g729.c
	$(CC) $(CC_OPT) -c erl_g729.c $(INCLUDE)

clean:
	rm *.o
