#include "erl_nif.h"
#include "memory.h"
#include <stdio.h>
#define VPX_CODEC_DISABLE_COMPAT 1
#include "vpx/vpx_encoder.h"
#include "vpx/vpx_decoder.h"
#include "vpx/vp8cx.h"
#include "vpx/vp8dx.h"
#define cx_inf (vpx_codec_vp8_cx())
#define dx_inf (vpx_codec_vp8_dx())
#define fourcc 0x30385056

#define MAXENCNO 15

typedef struct {
  int in_use;
  vpx_codec_ctx_t ctx;
} erl_decoder_ctx_t;

typedef struct {
  int in_use;
  vpx_codec_ctx_t ctx;
  vpx_image_t img;
} erl_encoder_ctx_t;

static erl_decoder_ctx_t dx_ctx[MAXENCNO+1];
static erl_encoder_ctx_t cx_ctx[MAXENCNO+1];

static int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  int i;
  
  for (i=0;i<=MAXENCNO;i++) {
    dx_ctx[i].in_use = 0;
    cx_ctx[i].in_use = 0;
  }
  
  return 0;
}

static ERL_NIF_TERM idec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int res;	// res = 0 is successful
  int i;

  res = 1;
  for (i=0;i<=MAXENCNO;i++) {
    if (dx_ctx[i].in_use == 0) {
      dx_ctx[i].in_use = 1;
      if(vpx_codec_dec_init(&(dx_ctx[i].ctx), dx_inf, NULL, 0)) {
      	res = 2;
        dx_ctx[i].in_use = 0;
        }
      else
        res = 0;	// successful
      break;
    }
  }
  
  return enif_make_tuple2(env, enif_make_int(env, res), enif_make_int(env, i));
}

static void mem_put_le16(char *mem, unsigned int val) {
    mem[0] = val;
    mem[1] = val>>8;
}

static void mem_put_le32(char *mem, unsigned int val) {
    mem[0] = val;
    mem[1] = val>>8;
    mem[2] = val>>16;
    mem[3] = val>>24;
}

static void write_ivf_file_header(unsigned char *header, const vpx_codec_enc_cfg_t *cfg, int frame_cnt)
{
    if(cfg->g_pass != VPX_RC_ONE_PASS && cfg->g_pass != VPX_RC_LAST_PASS)
        return;
    header[0] = 'D';
    header[1] = 'K';
    header[2] = 'I';
    header[3] = 'F';
    mem_put_le16(header+4,  0);                   /* version */
    mem_put_le16(header+6,  32);                  /* headersize */
    mem_put_le32(header+8,  fourcc);              /* headersize */
    mem_put_le16(header+12, cfg->g_w);            /* width */
    mem_put_le16(header+14, cfg->g_h);            /* height */
    mem_put_le32(header+16, cfg->g_timebase.den); /* rate */
    mem_put_le32(header+20, cfg->g_timebase.num); /* scale */
    mem_put_le32(header+24, frame_cnt);           /* length */
    mem_put_le32(header+28, 0);                   /* unused */
}

static void config_temporal_scaling(vpx_codec_enc_cfg_t* cfg, unsigned int bitrate, unsigned int *layer_flags)
{
  unsigned int ids[4] = {0,2,1,2};

    cfg->g_timebase.den = 1000;
    cfg->g_timebase.num = 1;

    cfg->ts_target_bitrate[0] = (unsigned int)(0.4 * bitrate);
    cfg->ts_target_bitrate[1] = (unsigned int)(0.6 * bitrate);
    cfg->ts_target_bitrate[2] = bitrate;
    
    // Real time parameters
    cfg->rc_dropframe_thresh = 0;  // 30
    cfg->rc_end_usage        = VPX_CBR;
    cfg->rc_resize_allowed   = 0;
    cfg->rc_min_quantizer    = 8;
    cfg->rc_max_quantizer    = 56;
    cfg->rc_undershoot_pct   = 100;
    cfg->rc_overshoot_pct    = 15;
    cfg->rc_buf_initial_sz   = 500;
    cfg->rc_buf_optimal_sz   = 600;
    cfg->rc_buf_sz           = 1000;

    // Enable error resilient mode
    cfg->g_error_resilient = 1;
    cfg->g_lag_in_frames   = 0;
    cfg->kf_mode           = VPX_KF_DISABLED;

    // Disable automatic keyframe placement
    cfg->kf_min_dist = cfg->kf_max_dist = 3000;

    // Temporal scaling parameters:
    // NOTE: The 3 prediction frames cannot be used interchangeably due to
    // differences in the way they are handled throughout the code. The
    // frames should be allocated to layers in the order LAST, GF, ARF.
    // Other combinations work, but may produce slightly inferior results.
    
        // 3-layers
        cfg->ts_number_layers     = 3;
        cfg->ts_periodicity       = 4;
        cfg->ts_rate_decimator[0] = 4;
        cfg->ts_rate_decimator[1] = 2;
        cfg->ts_rate_decimator[2] = 1;
        memcpy(cfg->ts_layer_id, ids, sizeof(ids));

        // 0=L, 1=GF, 2=ARF
        layer_flags[0] = VPX_EFLAG_FORCE_KF  |
                         VP8_EFLAG_NO_REF_GF | VP8_EFLAG_NO_REF_ARF |
                         VP8_EFLAG_NO_UPD_GF | VP8_EFLAG_NO_UPD_ARF;
        layer_flags[1] = VP8_EFLAG_NO_REF_GF | VP8_EFLAG_NO_REF_ARF |
                         VP8_EFLAG_NO_UPD_LAST | VP8_EFLAG_NO_UPD_GF;
        layer_flags[2] = VP8_EFLAG_NO_REF_GF   | VP8_EFLAG_NO_REF_ARF |
                         VP8_EFLAG_NO_UPD_LAST | VP8_EFLAG_NO_UPD_ARF;
        layer_flags[3] =
        layer_flags[5] = VP8_EFLAG_NO_UPD_LAST | VP8_EFLAG_NO_UPD_GF;
        layer_flags[4] = VP8_EFLAG_NO_REF_GF | VP8_EFLAG_NO_REF_ARF |
                         VP8_EFLAG_NO_UPD_GF | VP8_EFLAG_NO_UPD_ARF;
        layer_flags[6] = VP8_EFLAG_NO_REF_ARF |
                         VP8_EFLAG_NO_UPD_LAST | VP8_EFLAG_NO_UPD_ARF;
        layer_flags[7] = VP8_EFLAG_NO_UPD_LAST | VP8_EFLAG_NO_UPD_GF |
                         VP8_EFLAG_NO_UPD_ARF |
                         VP8_EFLAG_NO_UPD_ENTROPY;
}

static void control_codec(vpx_codec_enc_cfg_t* cfg, vpx_codec_ctx_t* codec)
{
  int max_intra_size_pct;

    // Cap CPU & first I-frame size
    vpx_codec_control (codec, VP8E_SET_CPUUSED,                -6);
    vpx_codec_control (codec, VP8E_SET_STATIC_THRESHOLD,      800);
    vpx_codec_control (codec, VP8E_SET_NOISE_SENSITIVITY,       2);

    max_intra_size_pct = (int) (((double)cfg->rc_buf_optimal_sz * 0.5)
                         * ((double) cfg->g_timebase.den / cfg->g_timebase.num)
                         / 10.0);

    vpx_codec_control(codec, VP8E_SET_MAX_INTRA_BITRATE_PCT, max_intra_size_pct);
}

static ERL_NIF_TERM ienc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  vpx_codec_enc_cfg_t cfg;
  unsigned int layer_flags[8] = {0};
  unsigned char *ivf_hdr;
  unsigned int width, height;		// width * height == even
  unsigned int target_bitrate;
  int res;
  int i, j;
  ERL_NIF_TERM rbin;
  ERL_NIF_TERM rflags;

  if (!enif_get_uint(env, argv[0], &width))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[1], &height))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[2], &target_bitrate))
    return enif_make_badarg(env);

  res = 1;
  for (i=0;i<=MAXENCNO;i++) {
    if (cx_ctx[i].in_use == 0) {
      ivf_hdr = enif_make_new_binary(env, 32, &rbin);
      if (!vpx_img_alloc(&(cx_ctx[i].img), VPX_IMG_FMT_I420, width, height, 1))
        res = 2;
      else if(vpx_codec_enc_config_default(cx_inf, &cfg, 0))
        res = 3;
      else {
        cfg.rc_target_bitrate = target_bitrate;
        cfg.g_w = width;
        cfg.g_h = height;

        config_temporal_scaling(&cfg, target_bitrate, layer_flags);
        
        write_ivf_file_header(ivf_hdr, &cfg, 0);
    
        if(vpx_codec_enc_init(&(cx_ctx[i].ctx), cx_inf, &cfg, 0))
          res = 4;
        else {
          control_codec(&cfg,&(cx_ctx[i].ctx));
          res = 0;
          cx_ctx[i].in_use = 1;
          }
      }
      break;
    }
  }
  
  rflags = enif_make_list8(env, enif_make_int(env,layer_flags[0]),
                                enif_make_int(env,layer_flags[1]),
                                enif_make_int(env,layer_flags[2]),
                                enif_make_int(env,layer_flags[3]),
                                enif_make_int(env,layer_flags[4]),
                                enif_make_int(env,layer_flags[5]),
                                enif_make_int(env,layer_flags[6]),
                                enif_make_int(env,layer_flags[7]));

  return enif_make_tuple4(env,enif_make_int(env,res),enif_make_int(env,i),rflags,rbin);
}

static ERL_NIF_TERM xdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary enc;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &enc))
    return enif_make_badarg(env);

  if(vpx_codec_decode(&(dx_ctx[no].ctx), enc.data, enc.size, NULL, 0))
    res = 1;

  return enif_make_int(env,res);
}

static ERL_NIF_TERM gdec(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ERL_NIF_TERM rbin;
  unsigned int no;
  int res = 0;
  vpx_image_t *img;
  unsigned int plane, y, szh,szw;
  unsigned char *imgp,*dec;
  const void *iter = NULL;
  unsigned int more_than_once = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  
  res = 1;
  while ((img = vpx_codec_get_frame(&(dx_ctx[no].ctx), &iter))) {

    unsigned long sz;
  	sz = (img->d_w * img->d_h * 3) >> 1;
  	if (sz > 655360) {
      printf("Kao 1 %lu\n",sz);
      fflush(stdout);
    }

    if (more_than_once > 0) {
      printf("Kao 3\n");
      fflush(stdout);
      continue;
    }
    
    res = 0;
    dec = enif_make_new_binary(env, (img->d_w * img->d_h * 3) >> 1, &rbin);	// width x height == even num.
    for(plane=0; plane < 3; plane++) {
      imgp = img->planes[plane];
      szh = plane ? (img->d_h + 1) >> 1 : img->d_h;
      szw = plane ? (img->d_w + 1) >> 1 : img->d_w;
      for(y=0; y < szh; y++) {
        memcpy(dec,imgp,szw);
        imgp += img->stride[plane];
        dec += szw;
      }
    }
    more_than_once ++;
  }
  
  if (res != 0)
    rbin = enif_make_atom(env, "null");

  return enif_make_tuple2(env, enif_make_int(env, res), rbin);
}

static int read_frame(unsigned char *buf, size_t fsize, vpx_image_t *img)
{
  int res;

  if(fsize = (img->w*img->h*3) >> 1) {
    res = 0;
    memcpy(img->planes[0], buf, fsize);
  }
  else {
    res = 1;
  }
  
  return res;
}

static ERL_NIF_TERM xenc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary dec;
  vpx_codec_pts_t pts;
  unsigned long duration;
  vpx_enc_frame_flags_t flags;
  unsigned int no;
  int res = 0;
 
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_inspect_binary(env, argv[1], &dec))
    return enif_make_badarg(env);
  if (!enif_get_uint64(env, argv[2], (ErlNifUInt64*) &pts))
    return enif_make_badarg(env);
  if (!enif_get_ulong(env, argv[3], &duration))
    return enif_make_badarg(env);
  if (!enif_get_long(env, argv[4], (long *) &flags))
    return enif_make_badarg(env);

  if (!(res = read_frame(dec.data,dec.size,&(cx_ctx[no].img)))) {
    if (vpx_codec_encode(&(cx_ctx[no].ctx), &(cx_ctx[no].img), pts, duration, flags, VPX_DL_REALTIME))
      res = 2;
  }
  else {
    if (vpx_codec_encode(&(cx_ctx[no].ctx), NULL, pts, duration, flags, VPX_DL_REALTIME))
      res = 0;
  }

  return enif_make_int(env,res);
}

static void write_ivf_frame_header(unsigned char *header,const vpx_codec_cx_pkt_t *pkt)
{
  vpx_codec_pts_t  pts;

    pts = pkt->data.frame.pts;
    mem_put_le32(header, pkt->data.frame.sz);
    mem_put_le32(header+4, pts&0xFFFFFFFF);
    mem_put_le32(header+8, pts >> 32);
}

static ERL_NIF_TERM genc(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ERL_NIF_TERM rbin;
  int res = 0;
  unsigned int no;
  int keyframe = 0;
  unsigned char *out;
  const void *iter = NULL;
  const vpx_codec_cx_pkt_t *pkt;
  unsigned int more_than_once = 0;

  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);

  res = 1;    
  while ( (pkt = vpx_codec_get_cx_data(&(cx_ctx[no].ctx), &iter)) ) {
    if (pkt->kind == VPX_CODEC_CX_FRAME_PKT) {
    	
      unsigned long sz;
      sz = 12 + pkt->data.frame.sz;
  	  if (sz > 655360) {
        printf("Kao 2 %lu\n",sz);
        fflush(stdout);
      }

      if (more_than_once > 0) {
        printf("Kao 4\n");
        fflush(stdout);
        continue;
      }

      res = 0;
	  out = enif_make_new_binary(env, 12 + pkt->data.frame.sz, &rbin);
      write_ivf_frame_header(out, pkt);
      memcpy(out+12, pkt->data.frame.buf, pkt->data.frame.sz);
      more_than_once ++;
    }

    if ((pkt->kind == VPX_CODEC_CX_FRAME_PKT)
        && (pkt->data.frame.flags & VPX_FRAME_IS_KEY)) keyframe |= 1;
  }
  
  if (res != 0)
    rbin = enif_make_atom(env, "null");
    
  return enif_make_tuple3(env, enif_make_int(env, res), enif_make_int(env,keyframe), rbin);
}

static ERL_NIF_TERM xdtr(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  unsigned int no;
  unsigned int type;
  int res = 0;
  
  if (!enif_get_uint(env, argv[0], &no))
    return enif_make_badarg(env);
  if (!enif_get_uint(env, argv[1], &type))
    return enif_make_badarg(env);
    
  if ((type == 0) && (cx_ctx[no].in_use == 1)) {  //is encoder
    if (vpx_codec_destroy(&(cx_ctx[no].ctx))) res = 1;
    vpx_img_free(&(cx_ctx[no].img));
    cx_ctx[no].in_use = 0;
  }
  else if ((type == 1) && (dx_ctx[no].in_use == 1)) {			// type == 1 is decoder
    if (vpx_codec_destroy(&(dx_ctx[no].ctx))) res = 1;
    dx_ctx[no].in_use = 0;
  }
  else
    res = 2;

  return enif_make_int(env,res);
}

// ---------------------------------
static ErlNifFunc evp8_funcs[] =
{
    {"idec", 0, idec},
    {"ienc", 3, ienc},
    {"xdec", 2, xdec},
    {"xenc", 5, xenc},
    {"gdec", 1, gdec},
    {"genc", 1, genc},
    {"xdtr", 2, xdtr}
};

ERL_NIF_INIT(erl_vp8,evp8_funcs,load,NULL,NULL,NULL)
