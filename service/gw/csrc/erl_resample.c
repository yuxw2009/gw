#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#include <stdlib.h>

static ERL_NIF_TERM down8k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary p;
  ERL_NIF_TERM r;
  int16_t *wav;
  int32_t tmp;
  int16_t *q;
  int i,samples,ds;

  if (!enif_inspect_binary(env, argv[0], &p) || p.size % 320 != 0)	// 20ms or 10ms samples
    return enif_make_badarg(env);

  samples = p.size >> 1;
  ds = samples >> 1;
  q = (int16_t *)enif_make_new_binary(env, samples, &r);
  wav = (int16_t *)p.data;
  for (i=0;i<ds;i++)
  {
    tmp = (wav[2*i] + wav[2*i+1]) >> 1;
    if (tmp > 32767)
      q[i] = 32767;
    else if (tmp < -32768)
      q[i] = -32768;
    else q[i] = (int16_t)tmp;
  }

  return r;
}

/* this is a 6-point DCT resample */
static void ud16k3(int16_t* q, ErlNifBinary* p, int16_t* cmpt_buf)
{
  int i,ci;
  int16_t *tmp;
  int samples;

  samples = p->size >> 1;
  tmp = (int16_t *)p->data;
  for (i=0,ci=5;i<samples;i++,ci++)	// p.size is samples count
  {
    cmpt_buf[ci%6] = tmp[i];
    
    q[2*i] = cmpt_buf[(ci+2)%6];
    q[2*i+1] = (150*(cmpt_buf[(ci+2)%6]+cmpt_buf[(ci+3)%6])
                -25*(cmpt_buf[(ci+1)%6]+cmpt_buf[(ci+4)%6])
                + 3*(cmpt_buf[ci%6]+cmpt_buf[(ci+5)%6])
                + 128) >> 8;
  }
}

static ERL_NIF_TERM up16k(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary passed;
  ErlNifBinary p;
  ERL_NIF_TERM r;
  int16_t *q;
  int16_t *tmp_buf;	// 6 points DCT
  unsigned int no;
  int i,ci;

  if (!enif_inspect_binary(env, argv[0], &p) || p.size % 160 != 0)
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &passed) || !(passed.size == 10))
    return enif_make_badarg(env);

  tmp_buf = (int16_t *)passed.data;	// 6 point DCT, use [0,1,2,3,4,_]

  q = (int16_t *) enif_make_new_binary(env, p.size << 1, &r);
  ud16k3(q,&p,tmp_buf);

  return r;
}

// ---------------------------------
static ErlNifFunc eRS_funcs[] =
{
    {"up16k",  2, up16k},
    {"down8k", 1, down8k}
};

ERL_NIF_INIT(erl_resample,eRS_funcs,NULL,NULL,NULL,NULL)
