/* mix 7 streams of U-law 20ms 160samples audio */
#include "erl_nif.h"
#include "g711.h"

#define MAXSTREAM 7
#define SAMPLES 160

static ERL_NIF_TERM x(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ERL_NIF_TERM inhead, inext;
	uint16_t no, streams, i;
	ErlNifBinary inaudio[MAXSTREAM];
	int32_t sum,sum2;
	int32_t linear[MAXSTREAM];
	uint8_t *begin;
	uint8_t *outbuf[MAXSTREAM];
	ERL_NIF_TERM rbin;
	int16_t res = 0;
	uint8_t max1,max2;
	
	max1 = linear_to_ulaw(32767);
    max2 = linear_to_ulaw(-32768);

    inext = argv[0];
    for (no = 0; no < MAXSTREAM; no++) {
      if (!enif_get_list_cell(env, inext, &inhead, &inext))
        {res = 1; break;}
      if (!enif_inspect_binary(env, inhead, &inaudio[no]) || (inaudio[no].size != SAMPLES))
        {res = 2; break;}
    }
    if ((res==2) || (res==1 && no==0))
      return enif_make_badarg(env);
    
    streams = no;
    
    begin = (uint8_t *)enif_make_new_binary(env, streams * SAMPLES, &rbin);
    for (no = 0; no < streams; no++) 
      outbuf[no] = begin + no * SAMPLES;

    for (i = 0; i < SAMPLES; i++) {
      sum = 0;
      for (no = 0; no < streams; no++) {
      	sum2 = (int32_t)ulaw_to_linear(inaudio[no].data[i]);
        sum += sum2;
        linear[no] = sum2;
      }
      for (no = 0; no < streams; no++) {
        sum2 = sum;
        sum2 -= linear[no];
      	if (sum2 > 32767) sum2 = 32767;
      	else if (sum2 < -32768) sum2 = -32768;
        *(outbuf[no]+i) = linear_to_ulaw((int16_t)sum2);
      }
    }
    
  return enif_make_tuple2(env, enif_make_int(env,res), rbin);
}

static ErlNifFunc u_mix_funcs[] =
{
    {"x", 1, x}
};

ERL_NIF_INIT(u_mix,u_mix_funcs,NULL,NULL,NULL,NULL)