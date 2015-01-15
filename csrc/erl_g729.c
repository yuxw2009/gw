/* 
 * FreeSWITCH Modular Media Switching Software Library / Soft-Switch Application
 * Copyright (C) 2005/2006, Anthony Minessale II <anthmct@yahoo.com>
 *
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is FreeSWITCH Modular Media Switching Software Library / Soft-Switch Application
 *
 * The Initial Developer of the Original Code is
 * Anthony Minessale II <anthmct@yahoo.com>
 * Portions created by the Initial Developer are Copyright (C)
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 * 
 * Anthony Minessale II <anthmct@yahoo.com>
 * Michael Jerris <mike@jerris.com>
 *
 * The g729 codec itself is not distributed with this module.
 *
 * erl_g729.c -- G.729 Codec Module for erlang nif call
 *
 */

#include <pthread.h>
#include "erl_nif.h"
#include "g729.h"

#define MAXCHNO 1023

struct g729_context {
	struct dec_state decoder_object;
	struct cod_state encoder_object;
};

typedef struct {
  int in_use;
  struct g729_context ctx;
} g729_codec_t;

static g729_codec_t g729[MAXCHNO+1];

static pthread_mutex_t mutex_x = PTHREAD_MUTEX_INITIALIZER;

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;

  for (i=0;i<=MAXCHNO;i++) g729[i].in_use = 0;

  // Init IPP library
  g729_init_lib();

  return 0;
}

static ERL_NIF_TERM icdc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int res;	// res = 0 is successful
  int i;

  res = 1;
  pthread_mutex_lock(&mutex_x);
  for (i=0;i<=MAXCHNO;i++) {
    if (g729[i].in_use == 0) {
      res = 0;
      g729[i].in_use = 1;
      g729_init_coder( &(g729[i].ctx.encoder_object), 0);
      g729_init_decoder( &(g729[i].ctx.decoder_object));
      break;
    }
  }
  pthread_mutex_unlock(&mutex_x);

  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  pthread_mutex_lock(&mutex_x);
  if (g729[no].in_use == 1) {
    g729[no].in_use = 0;
    g729_release_coder( &(g729[no].ctx.encoder_object));
    g729_release_decoder( &(g729[no].ctx.decoder_object));
  }
  else
    res = 1;
  pthread_mutex_unlock(&mutex_x);

  return enif_make_int(env,res);
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary sigIn;
  ERL_NIF_TERM rbin;
  unsigned char *sigOut;
  unsigned int no;
  char *edp;
  int16_t *ddp;
  int cbret = 0;
  int x, loops;

  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &sigIn) || (sigIn.size % 160 != 0))
    return enif_make_badarg(env);
  
  pthread_mutex_lock(&mutex_x);
  if(g729[no].in_use == 0) return enif_make_int(env, 1);
  pthread_mutex_unlock(&mutex_x);
  
  loops = (int) sigIn.size / 160;
  sigOut = enif_make_new_binary(env, loops * 10, &rbin);
  
  ddp = (int16_t *)sigIn.data;
  edp = (char *)sigOut;
  for (x = 0; x < loops; x++) {
    g729_coder( &(g729[no].ctx.encoder_object), ddp, edp, &cbret);
    edp += 10;
    ddp += 80;
  }

  return enif_make_tuple3(env,enif_make_int(env,0),enif_make_int(env,loops),rbin);
}

static ERL_NIF_TERM xdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary enc;
  ERL_NIF_TERM rbin;
  int16_t *sigOut;
  unsigned int no;
  char *edp;
  int16_t *ddp;
  int framesize;
  int x;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);

  pthread_mutex_lock(&mutex_x);
  if(g729[no].in_use == 0) return enif_make_int(env, 1);
  pthread_mutex_unlock(&mutex_x);
  
  edp = (char *)enc.data;
  ddp = (int16_t *)enif_make_new_binary(env, 320, &rbin);	// 320 bytes (20ms) out always.

  for(x = 0; x < enc.size; x += framesize) {
    if(enc.size - x < 8)
      framesize = 2;  /* SID */
    else
      framesize = 10; /* regular 729a frame */
	g729_decoder( &(g729[no].ctx.decoder_object), ddp, edp, framesize);
	ddp += 80;
	edp += framesize;
  }

  return enif_make_tuple2(env, enif_make_int(env, 0), rbin);
}

// ---------------------------------
static ErlNifFunc eG729_funcs[] =
{
    {"icdc", 0, icdc},
    {"xdec", 2, xdec},
    {"xenc", 2, xenc},
    {"xdtr", 1, xdtr}
};

ERL_NIF_INIT(erl_g729,eG729_funcs,load,NULL,NULL,NULL)
