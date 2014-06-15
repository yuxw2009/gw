
# specify IPP location
ipproot=/opt/intel/ipp # 7.0 ipp 64-bit

o="-O3 -fomit-frame-pointer" # generic optimization
#o="-O -g"
o="$o -flto -fwhole-program"

# the defaults below are pretty reasonable choice for pentium4 class cpu
# running in 32-bit mode with static link

# choose the compiler
# GNU C Compiler
cc=gcc
#cc=i686-pc-linux-gnu-gcc-4.5.1
#o="$o -flto -fwhole-program"

# choose 32-bit or 64-bit
# 32-bit
  # gcc
    # core2 penryn with sse4
   #opt=-march=core2
   #ippcore=p8

    # core2
   #opt=-march=core2
   #ippcore=v8

    # pentium4 prescott with sse3 - check for PNI flag in /proc/cpuinfo
   #opt=-march=prescott
   #ippcore=t7

    # pentium4
   #opt=-march=pentium4
   #ippcore=w7

    # pentium4 but disable compiler generated sse
   #opt="-march=pentium4 -mno-sse -mno-sse2"
   #ippcore=w7

    # pentium-m
   #opt=-march=pentium-m
   #ippcore=w7

    # pentium3
   #opt=-march=pentium3
   #ippcore=a6

    # pentium3 but disable compiler generated sse
   #opt="-march=pentium3 -mno-sse"
   #ippcore=a6

    # pentium2
   #opt=-march=pentium2
   #ippcore=px
   #def2=-DIPPCORE_NO_SSE

    # pentium
   #opt=-march=pentium
   #ippcore=px
   #def2=-DIPPCORE_NO_SSE

    # opteron athlon64
   #opt=-march=k8
   #ippcore=w7

    # opteron athlon64 with sse3
   #opt=-march=k8
   #ippcore=t7

    # athlon with sse
   #opt=-march=athlon-xp
   #ippcore=a6

# 32-bit static link
#ippstatic_include="-include $ipproot/tools/staticlib/ipp_$ippcore.h"
#ipplibs="-L$ipproot/lib -lippscmerged -lippsrmerged -lippsmerged -lippcore"
#o="$o -static-intel" # if ICC is used

# 32-bit dynamic link
#ipplibs="-L$ipproot/sharedlib -lippsc -lippsr -lipps -lippcore"


# 64-bit
  # gcc
    # x86_64 core2 with sse4.1
    opt=-march=core2
    ippcore=y8

    # x86_64 core2
   #opt=-march=core2
   #ippcore=u8

    # x86_64 pentium4
   #opt=-march=nocona
   #ippcore=m7

# 64-bit static link for IPP 6.0+
#ippstatic_include="-include $ipproot/tools/staticlib/ipp_$ippcore.h"
#ipplibs="-L$ipproot/lib -lippscmergedem64t -lippsrmergedem64t -lippsmergedem64t -lippcoreem64t"

# 64-bit dynamic link
ipplibs="-L$ipproot/sharedlib -lippscem64t -lippsrem64t -lippsem64t -lippscem64t -lippsrem64t -lippsem64t -lippcoreem64t"


# end of configuration


src9="codec_g72x.c ipp/decg729fp.c ipp/encg729fp.c ipp/owng729fp.c ipp/vadg729fp.c" # floating-point codec

compile_cmd="$cc -Wall -shared -Xlinker -x \
    -D_GNU_SOURCE $def $def2 -Iipp -I"$inc" $incw -I"$ipproot"/include $ippstatic_include \
    $opt $o \
    -fPIC"
libs="$ipplibs $icclibs"

cmd="$compile_cmd -DG72X_9 -o codec_g729.so $src9 $libs"; echo $cmd; $cmd

strip codec_g729.so
