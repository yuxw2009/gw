#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include "typedefs.h"
#include "isacfix.h"

#define MAXCHNO 15
#define FS 16000

typedef struct {
	WebRtc_UWord32 arrival_time;            /* samples */
	WebRtc_UWord32 sample_count;            /* samples */
	WebRtc_UWord16 rtp_number;
} BottleNeckModel;

typedef struct {
  int in_use;
  WebRtc_Word16 bitrt;
  WebRtc_UWord16 frameLen;
  WebRtc_Word16 mode;
  ISACFIX_MainStruct *ctx;
  BottleNeckModel BN_data;
} isac_codec_ctx_t;

static isac_codec_ctx_t isac[MAXCHNO+1];

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXCHNO;i++) isac[i].in_use = 0;
  
  return 0;
}

static ERL_NIF_TERM icdc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int codingMode, bitrt;
  unsigned int frameLen;
  int res;	// res = 0 is successful
  int i;

  if (!enif_get_int(env, argv[0], &codingMode))
    return enif_make_badarg(env);
  if (!enif_get_int(env, argv[1], &bitrt))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[2], &frameLen))
    return enif_make_badarg(env);

  res = 1;
  for (i=0;i<=MAXCHNO;i++) {
    if (isac[i].in_use == 0) {
      isac[i].in_use = 1;
      res = WebRtcIsacfix_Create(&isac[i].ctx);
      if (res != 0) {
        isac[i].in_use = 0;
        res = 2;
        }
      break;
    }
  }
  
  if (res != 0)
    return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));

  isac[i].bitrt = (WebRtc_Word16)bitrt;
  isac[i].frameLen = (WebRtc_UWord16)frameLen;
  isac[i].mode = (WebRtc_Word16)codingMode;
  isac[i].BN_data.arrival_time  = 0;
  isac[i].BN_data.sample_count  = 0;
  isac[i].BN_data.rtp_number    = 0;

  WebRtcIsacfix_EncoderInit(isac[i].ctx, (WebRtc_Word16)codingMode);
  WebRtcIsacfix_DecoderInit(isac[i].ctx);

  if (codingMode == 1)
    res = WebRtcIsacfix_Control(isac[i].ctx, (WebRtc_Word16)bitrt, ((WebRtc_UWord16)frameLen>>4));
  else
    res = WebRtcIsacfix_ControlBwe(isac[i].ctx, (WebRtc_Word16)bitrt, ((WebRtc_UWord16)frameLen>>4), 1);		/* fixed frame length */

  if (res < 0) {
    res=WebRtcIsacfix_GetErrorCode(isac[i].ctx);
    res = 3;
    return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
  }

  res = 0;
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static void get_arrival_time(unsigned int current_framesamples,   /* samples */
                             unsigned int tsDelta,                /* samples */
                             BottleNeckModel *BN_data)
{
	/* everything in samples */
	BN_data->sample_count += current_framesamples;
	BN_data->arrival_time += tsDelta;
	BN_data->rtp_number++;
}

static ERL_NIF_TERM xdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary enc;
  unsigned int samples,tsDelta;
  WebRtc_Word16 size, spType;
  ERL_NIF_TERM rbin;
  WebRtc_Word16 *sigOut;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[2], &samples))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[3], &tsDelta))
    return enif_make_badarg(env);

  get_arrival_time(samples, tsDelta, &isac[no].BN_data);
  res = WebRtcIsacfix_UpdateBwEstimate1(isac[no].ctx,
                                        (WebRtc_UWord16 *)enc.data,
                                        enc.size,
                                        isac[no].BN_data.rtp_number,
                                        isac[no].BN_data.arrival_time);
  if (res < 0) {
    res=WebRtcIsacfix_GetErrorCode(isac[no].ctx);
    res = 1;
  }
  else {
    sigOut = (WebRtc_Word16 *)enif_make_new_binary(env, samples*sizeof(WebRtc_Word16), &rbin);
    size = WebRtcIsacfix_Decode(isac[no].ctx, (WebRtc_UWord16 *)enc.data, enc.size, sigOut, &spType);
    if(size<=0){
      res=WebRtcIsacfix_GetErrorCode(isac[no].ctx);
      res = 2;
    }
    else if (size != samples)
      res = 3;
  }
  
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
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[1], &samples))
    return enif_make_badarg(env);
    
  if (samples == 480)
    noOfLostFrames = 1;
  else
    noOfLostFrames = 2;

  sigOut = (WebRtc_Word16 *)enif_make_new_binary(env, samples*sizeof(WebRtc_Word16), &rbin);
  size = WebRtcIsacfix_DecodePlc(isac[no].ctx, sigOut, noOfLostFrames );
  if(size<=0){
    res=WebRtcIsacfix_GetErrorCode(isac[no].ctx);
    res = 2;
  }
  else if (size != samples)
    res = 3;

  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  int noOfCalls, cdlen;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  WebRtc_UWord16 bitStream[500];	 /* double to 32 kbps for 60 ms */
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn))
    return enif_make_badarg(env);

  noOfCalls=0;
  cdlen=0;
  while (cdlen<=0) {
    cdlen=WebRtcIsacfix_Encode(isac[no].ctx,
                               (WebRtc_Word16 *)(sigIn.data+noOfCalls*160*sizeof(WebRtc_Word16)),
                               bitStream);
    if(cdlen==-1){
      res = WebRtcIsacfix_GetErrorCode(isac[no].ctx);
      res = 1;
      break;
    }
    noOfCalls++;
  }

  if (res == 0) {
    sigOut = enif_make_new_binary(env, cdlen, &rbin);
    memcpy(sigOut,(unsigned char *)bitStream,cdlen);
  }
  else {
    rbin = enif_make_atom(env, "null");
  }
  
  return enif_make_tuple3(env,enif_make_int(env,res),enif_make_int(env,noOfCalls),rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  if (isac[no].in_use == 1) {
    isac[no].in_use = 0;
    res = WebRtcIsacfix_Free(isac[no].ctx);
  }
  else
    res = 1;

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc eiSAC_funcs[] =
{
    {"icdc", 3, icdc},
    {"xdec", 4, xdec},
    {"xplc", 2, xplc},
    {"xenc", 2, xenc},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_isac,eiSAC_funcs,load,NULL,NULL,NULL)
