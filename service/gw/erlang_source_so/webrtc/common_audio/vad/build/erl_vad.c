#include "erl_nif.h"
#include <stdio.h>
#include <stdlib.h>
#include "common_audio/vad/include/webrtc_vad.h"
#include "typedefs.h"

#define MAXCHNO 2047 

typedef struct {
  int in_use;
  VadInst *ctx;
} erl_vad_ctx_t;

static erl_vad_ctx_t vad[MAXCHNO+1];

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) {
    vad[i].in_use = 0;
    vad[i].ctx = 0;
  }

  return 0;
}

static ERL_NIF_TERM ivad(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int res;	// res = 0 is successful
  int i;

  res = 1;
  for (i=0;i<=MAXCHNO;i++) {
    if (vad[i].in_use == 0) {
      vad[i].in_use = 1;
      res = WebRtcVad_Create(&vad[i].ctx);
      if (res != 0) {
        vad[i].in_use = 0;
        res = 2;
        }
      break;
    }
  }

  if (res != 0)
    return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));

  if (WebRtcVad_Init(vad[i].ctx) != 0) {
    res = 3;
  } else {
    res = 0;
  }
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM xset(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int mode;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[1], &mode))
    return enif_make_badarg(env);

  if (WebRtcVad_set_mode(vad[no].ctx, mode) != 0) {
    res = 1;
  }

  return enif_make_int(env, res);
}

static ERL_NIF_TERM xprcs(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int kRate;
  ErlNifBinary sigIn;
  int active;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[2], &kRate))
    return enif_make_badarg(env);
    
  res = WebRtcVad_Process(vad[no].ctx, kRate, (int16_t *)sigIn.data, sigIn.size / sizeof(int16_t));
  if (res == 1) {
    res = 0;
    active = 1;
  }
  else if (res == 0) active = 0;
  else {
    res = 1;
    active = 0;
  }

  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, active));
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  if (vad[no].in_use == 1) {
    vad[no].in_use = 0;
    if (WebRtcVad_Free(vad[no].ctx) != 0)
      res = 2;
  }
  else
    res = 1;

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc eVAD_funcs[] =
{
    {"ivad", 0, ivad},
    {"xset", 2, xset},
    {"xprcs",3, xprcs},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_vad,eVAD_funcs,load,NULL,NULL,NULL)
