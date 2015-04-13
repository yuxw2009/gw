#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "opus.h"
#include "opus_private.h"

#define MAXCHNO 1023
#define MAX_PACKET 1500

typedef struct {
  int in_use;
  opus_int32 skip;
  OpusEncoder *enc;
  OpusDecoder *dec;
} opus_codec_ctx_t;

static opus_codec_ctx_t opus[MAXCHNO+1];

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) {
    opus[i].in_use = 0;
    opus[i].enc=NULL;
    opus[i].dec=NULL;
  }
  
  return 0;
}

static ERL_NIF_TERM icdc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  opus_int32 bitrate_bps, skip=0;
  int arg_bitrate;
  int complexity;
  int err;
  int res;	// res = 0 is successful
  int i;

  if (!enif_get_int(env, argv[0], &arg_bitrate))
    return enif_make_badarg(env);
  bitrate_bps = (opus_int32) arg_bitrate;
  if (!enif_get_int(env, argv[1], &complexity) || complexity > 10 || complexity < 0)
    return enif_make_badarg(env);

  res = 1;
  for (i=0;i<=MAXCHNO;i++) {
    if (opus[i].in_use == 0) {
      opus[i].in_use = 1;
      opus[i].skip = skip;
      
      /* opus encoder initialize  */
      opus[i].enc = opus_encoder_create(8000, 1, OPUS_APPLICATION_VOIP, &err);
      if (err != OPUS_OK) {
        opus[i].in_use = 0;
        break;
      }
      opus_encoder_ctl(opus[i].enc, OPUS_SET_BITRATE(bitrate_bps));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_FORCE_MODE(MODE_SILK_ONLY));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_BANDWIDTH(OPUS_BANDWIDTH_NARROWBAND));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_VBR(1));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_VBR_CONSTRAINT(0));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_COMPLEXITY(complexity));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_INBAND_FEC(0));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_FORCE_CHANNELS(1));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_DTX(1));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_PACKET_LOSS_PERC(0));
      opus_encoder_ctl(opus[i].enc, OPUS_GET_LOOKAHEAD(&skip));
      opus_encoder_ctl(opus[i].enc, OPUS_SET_LSB_DEPTH(16));

      /* opus encoder initialize  */
      opus[i].dec = opus_decoder_create(8000, 1, &err);
      if (err != OPUS_OK)
      {
      	opus_encoder_destroy(opus[i].enc);
      	opus[i].in_use = 0;
        break;
      }

      res = 0;
      break;
    }
  }
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM xdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary enc;
  ERL_NIF_TERM rbin;
  opus_int16 decoded_data[960*6];
  unsigned char *sigOut;
  unsigned int no;
  int output_samples;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);

  output_samples = opus_decode(opus[no].dec, enc.data, (opus_int32)enc.size, decoded_data, 960*6, 0);
  
  sigOut = enif_make_new_binary(env, output_samples*2, &rbin);
  memcpy(sigOut, decoded_data, output_samples*2);
  
  return enif_make_tuple3(env, enif_make_int(env, 0), enif_make_int(env, output_samples), rbin);
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  int samples;
  int cdlen;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  unsigned char encoded_data[MAX_PACKET];
  unsigned int no;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);

  samples = sigIn.size / 2,
  cdlen = opus_encode(opus[no].enc, (opus_int16 *)sigIn.data, samples, encoded_data, MAX_PACKET);

  sigOut = enif_make_new_binary(env, cdlen, &rbin);
  memcpy(sigOut, encoded_data, cdlen);

  return enif_make_tuple2(env, enif_make_int(env,0), rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  if (opus[no].in_use == 1) {
    opus[no].in_use = 0;
    opus_encoder_destroy(opus[no].enc);
    opus_decoder_destroy(opus[no].dec);
    opus[no].enc=NULL;
    opus[no].dec=NULL;
  }
  else
    res = 1;

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc eopus_funcs[] =
{
    {"icdc", 2, icdc},
    {"xdec", 2, xdec},
    {"xenc", 2, xenc},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_opus,eopus_funcs,load,NULL,NULL,NULL)
