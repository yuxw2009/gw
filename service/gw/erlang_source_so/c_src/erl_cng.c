#include "erl_nif.h"
#include "webrtc_cng.h"
#include "memory.h"
#include <pthread.h>

#define MAXCHNO 1023 

typedef struct {
  int in_use;
  CNG_enc_inst* ctx;
} erl_cng_enc_t;

typedef struct {
  int in_use;
  CNG_dec_inst* ctx;
} erl_cng_dec_t;

static erl_cng_enc_t enc[MAXCHNO+1];
static erl_cng_dec_t dec[MAXCHNO+1];

static pthread_mutex_t mutex_x = PTHREAD_MUTEX_INITIALIZER;

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) {
    enc[i].in_use = 0;
    enc[i].ctx = 0;
    dec[i].in_use = 0;
    dec[i].ctx = 0;
  }

  return 0;
}

static ERL_NIF_TERM ienc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int sampleRate;
  int kSidUpdate, kCNGParams;
  int res = 0;	// res = 0 is successful
  int i;

  if (!enif_get_uint(env, argv[0], &sampleRate))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[1], &kSidUpdate))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[2], &kCNGParams))
    return enif_make_badarg(env);

  res = 1;
  pthread_mutex_lock(&mutex_x);
  for (i=0;i<=MAXCHNO;i++) {
    if (enc[i].in_use == 0) {
      enc[i].in_use = 1;
      res = WebRtcCng_CreateEnc(&enc[i].ctx);
      if (res != 0) {
        enc[i].in_use = 0;
        res = 2;
        }
      break;
    }
  }
  pthread_mutex_unlock(&mutex_x);

  if (res != 0)
    return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));

  res = WebRtcCng_InitEnc(enc[i].ctx, (uint16_t)sampleRate, (int16_t)kSidUpdate, (int16_t)kCNGParams);
  if (res != 0)
    res = 3;
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM idec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int res;	// res = 0 is successful
  int i;

  res = 1;
  pthread_mutex_lock(&mutex_x);
  for (i=0;i<=MAXCHNO;i++) {
    if (dec[i].in_use == 0) {
      dec[i].in_use = 1;
      res = WebRtcCng_CreateDec(&dec[i].ctx);
      if (res != 0) {
        dec[i].in_use = 0;
        res = 2;
        }
      break;
    }
  }
  pthread_mutex_unlock(&mutex_x);

  if (res != 0)
    return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));

  res = WebRtcCng_InitDec(dec[i].ctx);
  if (res != 0)
    res = 3;
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int kForceSid;
  ErlNifBinary sigIn;
  uint8_t sid_data[WEBRTC_CNG_MAX_LPC_ORDER + 1];
  int16_t number_bytes, encLen;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[2], &kForceSid))
    return enif_make_badarg(env);

  encLen = WebRtcCng_Encode(enc[no].ctx,
  							(int16_t *)sigIn.data,
  							(int16_t)(sigIn.size/sizeof(int16_t)),
  							sid_data,
  							&number_bytes,
  							(int16_t)kForceSid);

  if (encLen >= 0) {
    sigOut = enif_make_new_binary(env, (int)encLen, &rbin);
    memcpy(sigOut,(unsigned char *)sid_data,encLen);
  }
  else {
    res = 1;
    rbin = enif_make_atom(env, "null");
  }

  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xupd(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);

  if (WebRtcCng_UpdateSid(dec[no].ctx, sigIn.data, sigIn.size) != 0) {
    res = 1;
  }

  return enif_make_int(env, res);
}

static ERL_NIF_TERM xgen(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  int samples,new_period;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[1], &samples))
    return enif_make_badarg(env);

  sigOut = enif_make_new_binary(env, samples*sizeof(int16_t), &rbin);
  if (WebRtcCng_Generate(dec[no].ctx, (int16_t *)sigOut, (int16_t)samples, (int16_t)new_period) != 0)
    res = 1;

  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no,type;
  int res = 0;

  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[1], &type))
    return enif_make_badarg(env);
    
  pthread_mutex_lock(&mutex_x);
  if ((type == 0) && (enc[no].in_use == 1)) {  //is encoder
    if (WebRtcCng_FreeEnc(enc[no].ctx) != 0) res = 1;
    enc[no].in_use = 0;
  }
  else if ((type == 1) && (dec[no].in_use == 1)) {	// type == 1 is decoder
    if (WebRtcCng_FreeDec(dec[no].ctx) != 0) res = 1;
    dec[no].in_use = 0;
  }
  else
    res = 2;

  pthread_mutex_unlock(&mutex_x);

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc eCNG_funcs[] =
{
    {"ienc", 3, ienc},
    {"idec", 0, idec},
    {"xenc", 3, xenc},
    {"xupd", 2, xupd},
    {"xgen", 2, xgen},
    {"xdtr", 2, xdtr}
};

ERL_NIF_INIT(erl_cng,eCNG_funcs,load,NULL,NULL,NULL)
