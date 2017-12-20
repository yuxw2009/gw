#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>
#include "typedefs.h"
#include "isac.h"
#include "g711.h"

#define MAXCHNO 1023

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
  ISACStruct *ctx;
  BottleNeckModel BN_data;
} isac_codec_ctx_t;

typedef struct {
  int in_use;
  unsigned char passed[5];
} pcm16k_codec_t;

static isac_codec_ctx_t isac[MAXCHNO+1];
static pcm16k_codec_t u16k[MAXCHNO+1];

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;

  for (i=0;i<=MAXCHNO;i++) isac[i].in_use = 0;
  for (i=0;i<=MAXCHNO;i++) u16k[i].in_use = 0;

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
      res = WebRtcIsac_Create(&isac[i].ctx);
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

  WebRtcIsac_EncoderInit(isac[i].ctx, (WebRtc_Word16)codingMode);
  WebRtcIsac_DecoderInit(isac[i].ctx);

  if (codingMode == 1)
    res = WebRtcIsac_Control(isac[i].ctx, (WebRtc_Word16)bitrt, ((WebRtc_UWord16)frameLen>>4));
  else
    res = WebRtcIsac_ControlBwe(isac[i].ctx, (WebRtc_Word16)bitrt, ((WebRtc_UWord16)frameLen>>4), 1);		/* fixed frame length */

  if (res < 0) {
    res=WebRtcIsac_GetErrorCode(isac[i].ctx);
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
  WebRtc_Word16 asize;
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

/*  get_arrival_time(samples, tsDelta, &isac[no].BN_data);
  if (enc.size>100) asize=100;
  else asize=enc.size;
  res = WebRtcIsac_UpdateBwEstimate(isac[no].ctx,
                                        (WebRtc_UWord16 *)enc.data,
                                        asize,
                                        isac[no].BN_data.rtp_number,
                                        isac[no].BN_data.sample_count,
                                        isac[no].BN_data.arrival_time);

  if (res < 0) {
    res=WebRtcIsac_GetErrorCode(isac[no].ctx);
    res = 1;
  }
  else {  */
    sigOut = (WebRtc_Word16 *)enif_make_new_binary(env, samples*sizeof(WebRtc_Word16), &rbin);
    size = WebRtcIsac_Decode(isac[no].ctx, (WebRtc_UWord16 *)enc.data, enc.size, sigOut, &spType);
    if(size<=0){
      res=WebRtcIsac_GetErrorCode(isac[no].ctx);
      res = 2;
    }
    else if (size != samples)
      res = size;
//  }
  
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
  size = WebRtcIsac_DecodePlc(isac[no].ctx, sigOut, noOfLostFrames );
  if(size<=0){
    res=WebRtcIsac_GetErrorCode(isac[no].ctx);
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
    cdlen=WebRtcIsac_Encode(isac[no].ctx,
                               (WebRtc_Word16 *)(sigIn.data+noOfCalls*160*sizeof(WebRtc_Word16)),
                               bitStream);
    if(cdlen==-1){
      res = WebRtcIsac_GetErrorCode(isac[no].ctx);
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
    res = WebRtcIsac_Free(isac[no].ctx);
  }
  else
    res = 1;

  return enif_make_int(env,res);
}

static ERL_NIF_TERM uenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary p;
  ERL_NIF_TERM r;
  WebRtc_Word16 *wav;
  unsigned char *q;
  int i,samples;

  if (!enif_inspect_binary(env, argv[0], &p) || !(p.size == 320 || p.size == 160))
    return enif_make_badarg(env);

  samples = p.size >> 1;
  q = enif_make_new_binary(env, samples, &r);
  wav = (WebRtc_Word16 *)p.data;
  for (i=0;i<samples;i++)
  {
    q[i] = linear_to_ulaw(wav[i]);
  }

  return r;
}

static ERL_NIF_TERM udec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary p;
  ERL_NIF_TERM r;
  WebRtc_Word16 *q;
  int i;

  if (!enif_inspect_binary(env, argv[0], &p) || !(p.size == 160 || p.size == 80))
    return enif_make_badarg(env);

  q = (WebRtc_Word16 *) enif_make_new_binary(env, p.size * 2, &r);
  for (i=0;i<p.size;i++)
  {
    q[i] = ulaw_to_linear(p.data[i]);
  }

  return r;
}

static ERL_NIF_TERM iu16k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int i,res;

  res = 1;
  for (i=0;i<=MAXCHNO;i++) {
    if (u16k[i].in_use == 0) {
      res = 0;
      u16k[i].in_use = 1;
      memset(u16k[i].passed,linear_to_ulaw(0),5);
      break;
    }
  }
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

/* encode 16k pcm 16-bit down-samples to PCMU */
static ERL_NIF_TERM ue16k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary p;
  ERL_NIF_TERM r;
  WebRtc_Word16 *wav;
  unsigned char *q;
  int tmp;
  int i,samples;

  if (!enif_inspect_binary(env, argv[1], &p) || !(p.size == 640 || p.size == 320))	// 20ms or 10ms samples
    return enif_make_badarg(env);

  samples = p.size >> 2;
  q = enif_make_new_binary(env, samples, &r);
  wav = (WebRtc_Word16 *)p.data;
  for (i=0;i<samples;i++)
  {
    tmp = wav[2*i] + wav[2*i+1],
    q[i] = linear_to_ulaw(tmp >> 1);
  }

  return r;
}

static void ud16k2(WebRtc_Word16* q, ErlNifBinary* p, WebRtc_Word16* cmpt_buf)
{
  int i,ci;

  for (i=0,ci=3;i<p->size;i++,ci++)	// p.size is samples count
  {
    cmpt_buf[ci&0x3] = ulaw_to_linear(p->data[i]);
    q[2*i] = cmpt_buf[(ci+2)&0x3];
    q[2*i+1] = (9*(cmpt_buf[(ci+2)&0x3]+cmpt_buf[(ci+3)&0x3])-(cmpt_buf[(ci+1)&0x3]+cmpt_buf[ci&0x3])+8) >> 4;
  }
}

/* this is a 6-point DCT resample */
static void ud16k3(WebRtc_Word16* q, ErlNifBinary* p, WebRtc_Word16* cmpt_buf)
{
  int i,ci;

  for (i=0,ci=5;i<p->size;i++,ci++)	// p.size is samples count
  {
    cmpt_buf[ci%6] = ulaw_to_linear(p->data[i]);
    
    q[2*i] = cmpt_buf[(ci+2)%6];
    q[2*i+1] = (150*(cmpt_buf[(ci+2)%6]+cmpt_buf[(ci+3)%6])
                -25*(cmpt_buf[(ci+1)%6]+cmpt_buf[(ci+4)%6])
                + 3*(cmpt_buf[ci%6]+cmpt_buf[(ci+5)%6])
                + 128) >> 8;
  }
}

/* decode PCMU upsample to 16k 16-bit linear samples */
static ERL_NIF_TERM ud16k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary passed;
  ErlNifBinary p;
  ERL_NIF_TERM r;
  WebRtc_Word16 *q;
  WebRtc_Word16 tmp_buf[6];	// 6 points DCT
  unsigned int no;
  int i,ci;

  if (enif_get_uint(env, argv[0], &no))
  {
    if (!enif_inspect_binary(env, argv[1], &p) || !(p.size == 160 || p.size == 80))
      return enif_make_badarg(env);
/*    for (ci=0;ci<3;ci++)
      tmp_buf[ci] = ulaw_to_linear(u16k[no].passed[ci+2]);	// 4 point upsamples, use [2,3,4,_]	*/
    for (ci=0;ci<5;ci++)
      tmp_buf[ci] = ulaw_to_linear(u16k[no].passed[ci]);	// 6 point DCT [0,1,2,3,4,_]	
    for (i=0,ci=5;i<5;i++,ci--)
      u16k[no].passed[i] = p.data[p.size-ci];
  }
  else if (enif_inspect_binary(env, argv[0], &p) && (p.size == 160 || p.size == 80))
  {
    if (!enif_inspect_binary(env, argv[1], &passed) || !(passed.size == 5))
      return enif_make_badarg(env);
/*    for (ci=0;ci<3;ci++)
      tmp_buf[ci] = ulaw_to_linear(passed.data[ci+2]);	// 4 point upsamples, use [2,3,4,_]	*/
      for (ci=0;ci<5;ci++)
      tmp_buf[ci] = ulaw_to_linear(passed.data[ci]);	// 6 point DCT, use [0,1,2,3,4,_]
  }
  else
    return enif_make_badarg(env);

  q = (WebRtc_Word16 *) enif_make_new_binary(env, p.size * 4, &r);
  ud16k3(q,&p,tmp_buf);

  return r;
}

static ERL_NIF_TERM du16k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  if (u16k[no].in_use == 1)
    u16k[no].in_use = 0;
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
    {"xdtr", 1, xdtr},
    {"uenc", 1, uenc},
    {"udec", 1, udec},
    {"iu16k", 0, iu16k},
    {"ue16k", 2, ue16k},
    {"ud16k", 2, ud16k},
    {"du16k", 1, du16k}
};

ERL_NIF_INIT(erl_isac_nb,eiSAC_funcs,load,NULL,NULL,NULL)
