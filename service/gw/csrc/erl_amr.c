#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <pthread.h>
#include "interf_dec.h"
#include "interf_enc.h"

#define MAXCHNO 1023

/* From WmfDecBytesPerFrame in dec_input_format_tab.cpp */
const int sizes[] = { 12, 13, 15, 17, 19, 20, 26, 31, 5, 6, 5, 5, 0, 0, 0, 0 };

typedef struct {
  int in_use;
  int dtx;
  enum Mode mode;
  void *enc;
  void *dec;
} amr_codec_ctx_t;

static amr_codec_ctx_t ctx[MAXCHNO+1];

static pthread_mutex_t mutex_x = PTHREAD_MUTEX_INITIALIZER;

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) ctx[i].in_use = 0;
  
  return 0;
}

enum Mode findMode(int req_rate) {
	struct {
		enum Mode mode;
		int rate;
	} modes[] = {
		{ MR475,  4750 },
		{ MR515,  5150 },
		{ MR59,   5900 },
		{ MR67,   6700 },
		{ MR74,   7400 },
		{ MR795,  7950 },
		{ MR102, 10200 },
		{ MR122, 12200 }
	};
	int closest = -1;
	int closestdiff = 0;
	unsigned int i;
	for (i = 0; i < sizeof(modes)/sizeof(modes[0]); i++) {
		if (modes[i].rate == req_rate)
			return modes[i].mode;
		if (closest < 0 || closestdiff > abs(modes[i].rate - req_rate)) {
			closest = i;
			closestdiff = abs(modes[i].rate - req_rate);
		}
	}
	return modes[closest].mode;
}

static ERL_NIF_TERM icdc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int dtx, rate;
  int res;	// res = 0 is successful
  int i;

  if (!enif_get_int(env, argv[0], &dtx) || !(dtx == 0 || dtx == 1))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[1], &rate))
    return enif_make_badarg(env);

  res = 1;
  pthread_mutex_lock(&mutex_x);
  for (i=0;i<=MAXCHNO;i++) {
    if (ctx[i].in_use == 0) {
      ctx[i].in_use = 1;
      ctx[i].mode = findMode(rate);
      ctx[i].dec = Decoder_Interface_init();
      ctx[i].enc = Encoder_Interface_init(dtx);
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
  ERL_NIF_TERM rbin;
  int16_t *sigOut;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);

  sigOut = (int16_t *)enif_make_new_binary(env, 320, &rbin);	/* 160 samples 320 bytes */
  Decoder_Interface_Decode(ctx[no].dec, (uint8_t *)enc.data, sigOut, 0);

  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  int cdlen;
  ERL_NIF_TERM rbin;
  uint8_t *sigOut;
  uint8_t encoded_data[500];
  unsigned int no;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn) || (sigIn.size % 160 != 0))
    return enif_make_badarg(env);

  cdlen = Encoder_Interface_Encode(ctx[no].enc, ctx[no].mode, (int16_t *)sigIn.data, encoded_data, 0);
  sigOut = enif_make_new_binary(env, cdlen, &rbin);
  memcpy(sigOut,encoded_data,cdlen);

  return enif_make_tuple2(env,enif_make_int(env,0),rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  pthread_mutex_lock(&mutex_x);
  if (ctx[no].in_use == 1) {
    ctx[no].in_use = 0;
    Encoder_Interface_exit(ctx[no].enc);
    Decoder_Interface_exit(ctx[no].dec);
  }
  else
    res = 1;
  pthread_mutex_unlock(&mutex_x);

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc eAMR_funcs[] =
{
    {"icdc", 2, icdc},
    {"xdec", 2, xdec},
    {"xenc", 2, xenc},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_amr,eAMR_funcs,load,NULL,NULL,NULL)
