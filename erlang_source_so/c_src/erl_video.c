#include "erl_nif.h"
#include "memory.h"
#include "third_party/libyuv/include/libyuv/basic_types.h"
#include "third_party/libyuv/include/libyuv/scale.h"
#include "third_party/libyuv/include/libyuv/cpu_id.h"

static ERL_NIF_TERM xscl(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary s_yuv;
  unsigned int s_w, s_h, d_w, d_h;
  unsigned int sy_sz, suv_sz, dy_sz, duv_sz;
  unsigned char *out;
  ERL_NIF_TERM d_yuv;

  if (!enif_inspect_binary(env, argv[0], &s_yuv))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[1], &s_w))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[2], &s_h))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[3], &d_w))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[4], &d_h))
    return enif_make_badarg(env);

  sy_sz = s_w * s_h;
  suv_sz= sy_sz >> 2;
  dy_sz = d_w * d_h;
  duv_sz= dy_sz >> 2;
  
  out = enif_make_new_binary(env, dy_sz+(duv_sz<<1), &d_yuv);

  I420Scale(s_yuv.data, s_w,
            s_yuv.data+sy_sz, s_w>>1,
            s_yuv.data+sy_sz+suv_sz, s_w>>1,
            s_w, s_h,
            out, d_w,
            out+dy_sz, d_w>>1,
            out+dy_sz+duv_sz, d_w>>1,
            d_w, d_h, 1);

  return enif_make_tuple2(env, enif_make_int(env,0), d_yuv);
}

// ---------------------------------
static ErlNifFunc evideo_funcs[] =
{
    {"xscl", 5, xscl}
};

ERL_NIF_INIT(erl_video,evideo_funcs,NULL,NULL,NULL,NULL)