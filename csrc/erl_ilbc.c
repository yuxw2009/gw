#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include "ilbc.h"

#define MAXCHNO 1023
#define BLOCKL_MAX	240
#define ILBCNOOFWORDS_MAX	25

typedef struct {
  int in_use;
  int mode;
  iLBC_encinst_t *enc;
  iLBC_decinst_t *dec;
} ilbc_codec_ctx_t;

static ilbc_codec_ctx_t ilbc[MAXCHNO+1];

static pthread_mutex_t mutex_x = PTHREAD_MUTEX_INITIALIZER;

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) ilbc[i].in_use = 0;
  
  return 0;
}

static ERL_NIF_TERM icdc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int mode;
  int res;	// res = 0 is successful
  int i;

  if (!enif_get_int(env, argv[0], &mode) || !(mode == 20 || mode == 30))
    return enif_make_badarg(env);

  res = 1;
  pthread_mutex_lock(&mutex_x);
  for (i=0;i<=MAXCHNO;i++) {
    if (ilbc[i].in_use == 0) {
      ilbc[i].in_use = 1;
      ilbc[i].mode = mode;
      WebRtcIlbcfix_EncoderCreate(&ilbc[i].enc);
      WebRtcIlbcfix_DecoderCreate(&ilbc[i].dec);
      WebRtcIlbcfix_EncoderInit(ilbc[i].enc, mode);
      WebRtcIlbcfix_DecoderInit(ilbc[i].dec, mode);
      res = 0;
      break;
    }
  }
  pthread_mutex_unlock(&mutex_x);

  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM xdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary enc;
  WebRtc_Word16 spType;
  ERL_NIF_TERM rbin;
  WebRtc_Word16 *sigOut;
  unsigned int no;
  int len;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);

  if(ilbc[no].in_use == 0) return enif_make_int(env, 1);
  sigOut = (WebRtc_Word16 *)enif_make_new_binary(env, ilbc[no].mode<<4, &rbin);
  len=WebRtcIlbcfix_Decode(ilbc[no].dec,(WebRtc_Word16 *)enc.data,(WebRtc_Word16)enc.size,sigOut,&spType);

  if (len != ilbc[no].mode<<3)
    res = len;
  
  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xplc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int samples;
  WebRtc_Word16 size;
  WebRtc_Word16 noOfLostFrames;
  ERL_NIF_TERM rbin;
  WebRtc_Word16 *sigOut;
  unsigned int no;
  int len;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  if(ilbc[no].in_use == 0) return enif_make_int(env, 1);
  sigOut = (WebRtc_Word16 *)enif_make_new_binary(env, ilbc[no].mode<<4, &rbin);
  len=WebRtcIlbcfix_DecodePlc(ilbc[no].dec, sigOut, 1);

  if (len != ilbc[no].mode<<3)
    res = len;
  
  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  int cdlen;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  WebRtc_Word16 encoded_data[ILBCNOOFWORDS_MAX];
  unsigned int no;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);

  if(ilbc[no].in_use == 0) return enif_make_int(env, 1);
  cdlen=WebRtcIlbcfix_Encode(ilbc[no].enc,(WebRtc_Word16 *)sigIn.data,(WebRtc_Word16)(sigIn.size>>1),encoded_data);
  sigOut = enif_make_new_binary(env, cdlen, &rbin);
  memcpy(sigOut,(unsigned char *)encoded_data,cdlen);

  return enif_make_tuple2(env,enif_make_int(env,0),rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  pthread_mutex_lock(&mutex_x);
  if (ilbc[no].in_use == 1) {
    ilbc[no].in_use = 0;
    WebRtcIlbcfix_EncoderFree(ilbc[no].enc);
    WebRtcIlbcfix_DecoderFree(ilbc[no].dec);
  }
  else
    res = 1;
  pthread_mutex_unlock(&mutex_x);

  return enif_make_int(env,res);
}

static ERL_NIF_TERM cdcn(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int total=MAXCHNO+1;
  int num = 0,i=0;
  
  for (i=0;i<=MAXCHNO;i++) {
    if (ilbc[i].in_use == 0) {
		num+=1;
    }
  }

  return enif_make_tuple2(env,enif_make_int(env,num),enif_make_int(env,total));
}

// ---------------------------------
static ErlNifFunc eiLBC_funcs[] =
{
    {"cdcnum", 0, cdcn},
    {"icdc", 1, icdc},
    {"xdec", 2, xdec},
    {"xplc", 1, xplc},
    {"xenc", 2, xenc},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_ilbc,eiLBC_funcs,load,NULL,NULL,NULL)
