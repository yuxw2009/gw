/* mix 7 streams of U-law 20ms 160samples audio */
#include "erl_nif.h"
#include "g711.h"

#define MAXSTREAM 7
#define SAMPLES 160
#define LSAMPLES 80
#define Linear_SAMPLE10 160
#define Linear_SAMPLE20 320

static ERL_NIF_TERM x(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ERL_NIF_TERM inhead, inext;
	uint16_t no, streams, i;
	ErlNifBinary inaudio[MAXSTREAM];
	int32_t sum,sum2;
	int32_t linear[MAXSTREAM];
	uint8_t *begin, *allch;
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
    
    begin = (uint8_t *)enif_make_new_binary(env, (streams+1) * SAMPLES, &rbin);		/* +1 for all_channel mix */
    allch = begin;
    for (no = 0; no < streams; no++)
      outbuf[no] = begin + (no+1) * SAMPLES;

    for (i = 0; i < SAMPLES; i++) {
      sum = 0;
      for (no = 0; no < streams; no++) {
      	sum2 = (int32_t)ulaw_to_linear(inaudio[no].data[i]);
        sum += sum2;
        linear[no] = sum2;
      }
      if (sum > 32767) allch[i] = max1;
      else if (sum < -32768) allch[i] = max2;
      else allch[i] = linear_to_ulaw((int16_t)sum);
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

static ERL_NIF_TERM lx(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ERL_NIF_TERM inhead, inext;
	uint16_t no, streams, i;
	uint16_t samples;
	ErlNifBinary inaudio[MAXSTREAM];
	int16_t *inbuf[MAXSTREAM];
	int32_t sum,sum2;
	int32_t linear[MAXSTREAM];
	int16_t *begin, *allch;
	int16_t *outbuf[MAXSTREAM];
	ERL_NIF_TERM rbin;
	int16_t res = 0;
	
    inext = argv[0];
    for (no = 0; no < MAXSTREAM; no++) {
      if (!enif_get_list_cell(env, inext, &inhead, &inext))
        {res = 1; break;}
      if (!enif_inspect_binary(env, inhead, &inaudio[no]) || (inaudio[no].size % (LSAMPLES*2) != 0))
        {res = 2; break;}
    }
    if ((res==2) || (res==1 && no==0))
      return enif_make_badarg(env);
    
    streams = no;
    samples = inaudio[0].size >> 1;
    
    begin = (int16_t *)enif_make_new_binary(env, (streams+1) * samples*2, &rbin);
    allch = begin;
    for (no = 0; no < streams; no++) {
      outbuf[no] = begin + (no+1) * samples;		/* outbuf[], begin all int16 type, offset=/=lsamples*2  */
      inbuf[no] = (int16_t *)inaudio[no].data;
      }

    for (i = 0; i < samples; i++) {
      sum = 0;
      for (no = 0; no < streams; no++) {
      	sum2 = (int32_t)(inbuf[no][i]);
        sum += sum2;
        linear[no] = sum2;
      }
      allch[i] = (int16_t)sum;
      for (no = 0; no < streams; no++) {
        sum2 = sum;
        sum2 -= linear[no];
        sum2 += (linear[no]>>4);
        *(outbuf[no]+i) = (int16_t)sum2;
      }
    }
    
  return enif_make_tuple2(env, enif_make_int(env,res), rbin);
}

static ERL_NIF_TERM phn(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary sigA,sigB;
	uint8_t *outbuf;
	ERL_NIF_TERM rbin;
	uint16_t i;
	int32_t sum;
	uint8_t max1,max2;
	int16_t res = 0;
	
	max1 = linear_to_ulaw(32767);
    max2 = linear_to_ulaw(-32768);

    if (!enif_inspect_binary(env, argv[0], &sigA) || (sigA.size != SAMPLES))
      return enif_make_badarg(env);
    if (!enif_inspect_binary(env, argv[1], &sigB) || (sigB.size != SAMPLES))
      return enif_make_badarg(env);

    outbuf = (uint8_t *)enif_make_new_binary(env, SAMPLES, &rbin);

    for (i = 0; i < SAMPLES; i++) {
      sum = (int32_t)ulaw_to_linear(sigA.data[i]) + (int32_t)ulaw_to_linear(sigB.data[i]);
      if (sum > 32767) outbuf[i] = max1;
      else if (sum < -32768) outbuf[i] = max2;
      else outbuf[i] = linear_to_ulaw((int16_t)sum);
    }
    
  return enif_make_tuple2(env, enif_make_int(env,res), rbin);
}

static ERL_NIF_TERM mix_2_linear(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary sigA,sigB;
	WebRtc_Word16 *outbuf;
	ERL_NIF_TERM rbin;
	uint16_t i;
	int32_t sum;
	uint8_t max1,max2;
	int16_t res = 0;
	WebRtc_Word16 * wava;
	WebRtc_Word16 * wavb;
	
	max1 = linear_to_ulaw(32767);
    max2 = linear_to_ulaw(-32768);

    if (!enif_inspect_binary(env, argv[0], &sigA) || (sigA.size != Linear_SAMPLE10 && sigA.size != Linear_SAMPLE20))
      return enif_make_int(env,1);
    if (!enif_inspect_binary(env, argv[1], &sigB) || (sigB.size != Linear_SAMPLE10 && sigA.size != Linear_SAMPLE20))
      return enif_make_int(env,2);
    if(sigA.size != sigB.size)
	return enif_make_tuple3(env,enif_make_int(env,3),enif_make_int(env,sigA.size),enif_make_int(env,sigB.size));
    
    outbuf = (WebRtc_Word16 *)enif_make_new_binary(env, sigA.size*2, &rbin);

    wava = (WebRtc_Word16 *)(sigA.data);
    wavb = (WebRtc_Word16 *)(sigB.data);
    for (i = 0; i < sigA.size; i++) {
      sum = (int32_t)wava[i] + (int32_t)wavb[i];
      if (sum > 32767) sum = 32767;
      else if (sum < -32768) sum = -32767;
      outbuf[i] = sum;
    }
    
  return enif_make_tuple2(env, enif_make_int(env,res), rbin);
}

static ErlNifFunc erl_amix_funcs[] =
{
    {"x",  1, x},
    {"lx", 1, lx},
    {"mix_2_linear", 2, mix_2_linear},
    {"phn",2, phn}
};

ERL_NIF_INIT(erl_amix,erl_amix_funcs,NULL,NULL,NULL,NULL)
