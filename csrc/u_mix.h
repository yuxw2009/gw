/*
 * g711.h - In line A-law and u-law conversion routines
 *
 * u_mix.h is rewrote for g711.h
 *
 */


#if !defined(_U_MIX_H_)
#define _U_MIX_H_

#include <stdint.h>

typedef int8_t              WebRtc_Word8;
typedef int16_t             WebRtc_Word16;
typedef int32_t             WebRtc_Word32;
typedef int64_t             WebRtc_Word64;
typedef uint8_t             WebRtc_UWord8;
typedef uint16_t            WebRtc_UWord16;
typedef uint32_t            WebRtc_UWord32;
typedef uint64_t            WebRtc_UWord64;

#if defined(__i386__)
/*! \brief Find the bit position of the highest set bit in a word
    \param bits The word to be searched
    \return The bit number of the highest set bit, or -1 if the word is zero. */
static __inline__ int top_bit(unsigned int bits)
{
    int res;

    __asm__ __volatile__(" movl $-1,%%edx;\n"
                         " bsrl %%eax,%%edx;\n"
                         : "=d" (res)
                         : "a" (bits));
    return res;
}
/*- End of function --------------------------------------------------------*/

/*! \brief Find the bit position of the lowest set bit in a word
    \param bits The word to be searched
    \return The bit number of the lowest set bit, or -1 if the word is zero. */
static __inline__ int bottom_bit(unsigned int bits)
{
    int res;

    __asm__ __volatile__(" movl $-1,%%edx;\n"
                         " bsfl %%eax,%%edx;\n"
                         : "=d" (res)
                         : "a" (bits));
    return res;
}
/*- End of function --------------------------------------------------------*/
#elif defined(__x86_64__)
static __inline__ int top_bit(unsigned int bits)
{
    int res;

    __asm__ __volatile__(" movq $-1,%%rdx;\n"
                         " bsrq %%rax,%%rdx;\n"
                         : "=d" (res)
                         : "a" (bits));
    return res;
}
/*- End of function --------------------------------------------------------*/

static __inline__ int bottom_bit(unsigned int bits)
{
    int res;

    __asm__ __volatile__(" movq $-1,%%rdx;\n"
                         " bsfq %%rax,%%rdx;\n"
                         : "=d" (res)
                         : "a" (bits));
    return res;
}
/*- End of function --------------------------------------------------------*/
#else
static __inline int top_bit(unsigned int bits)
{
    int i;
    
    if (bits == 0)
        return -1;
    i = 0;
    if (bits & 0xFFFF0000)
    {
        bits &= 0xFFFF0000;
        i += 16;
    }
    if (bits & 0xFF00FF00)
    {
        bits &= 0xFF00FF00;
        i += 8;
    }
    if (bits & 0xF0F0F0F0)
    {
        bits &= 0xF0F0F0F0;
        i += 4;
    }
    if (bits & 0xCCCCCCCC)
    {
        bits &= 0xCCCCCCCC;
        i += 2;
    }
    if (bits & 0xAAAAAAAA)
    {
        bits &= 0xAAAAAAAA;
        i += 1;
    }
    return i;
}
/*- End of function --------------------------------------------------------*/

static __inline int bottom_bit(unsigned int bits)
{
    int i;
    
    if (bits == 0)
        return -1;
    i = 32;
    if (bits & 0x0000FFFF)
    {
        bits &= 0x0000FFFF;
        i -= 16;
    }
    if (bits & 0x00FF00FF)
    {
        bits &= 0x00FF00FF;
        i -= 8;
    }
    if (bits & 0x0F0F0F0F)
    {
        bits &= 0x0F0F0F0F;
        i -= 4;
    }
    if (bits & 0x33333333)
    {
        bits &= 0x33333333;
        i -= 2;
    }
    if (bits & 0x55555555)
    {
        bits &= 0x55555555;
        i -= 1;
    }
    return i;
}
/*- End of function --------------------------------------------------------*/
#endif

/* N.B. It is tempting to use look-up tables for A-law and u-law conversion.
 *      However, you should consider the cache footprint.
 *
 *      A 64K byte table for linear to x-law and a 512 byte table for x-law to
 *      linear sound like peanuts these days, and shouldn't an array lookup be
 *      real fast? No! When the cache sloshes as badly as this one will, a tight
 *      calculation may be better. The messiest part is normally finding the
 *      segment, but a little inline assembly can fix that on an i386, x86_64 and
 *      many other modern processors.
 */
 
/*
 * Mu-law is basically as follows:
 *
 *      Biased Linear Input Code        Compressed Code
 *      ------------------------        ---------------
 *      00000001wxyza                   000wxyz
 *      0000001wxyzab                   001wxyz
 *      000001wxyzabc                   010wxyz
 *      00001wxyzabcd                   011wxyz
 *      0001wxyzabcde                   100wxyz
 *      001wxyzabcdef                   101wxyz
 *      01wxyzabcdefg                   110wxyz
 *      1wxyzabcdefgh                   111wxyz
 *
 * Each biased linear code has a leading 1 which identifies the segment
 * number. The value of the segment number is equal to 7 minus the number
 * of leading 0's. The quantization interval is directly available as the
 * four bits wxyz.  * The trailing bits (a - h) are ignored.
 *
 * Ordinarily the complement of the resulting code word is used for
 * transmission, and so the code word is complemented before it is returned.
 *
 * For further information see John C. Bellamy's Digital Telephony, 1982,
 * John Wiley & Sons, pps 98-111 and 472-476.
 */

//#define ULAW_ZEROTRAP                 /* turn on the trap as per the MIL-STD */
#define ULAW_BIAS        0x84           /* Bias for linear code. */

/*! \brief Encode a linear sample to u-law
    \param linear The sample to encode.
    \return The u-law value.
*/
static __inline WebRtc_UWord8 linear_to_ulaw(int linear)
{
    WebRtc_UWord8 u_val;
    int mask;
    int seg;

    /* Get the sign and the magnitude of the value. */
    if (linear < 0)
    {
        /* WebRtc, tlegrand: -1 added to get bitexact to reference implementation */
        linear = ULAW_BIAS - linear - 1;
        mask = 0x7F;
    }
    else
    {
        linear = ULAW_BIAS + linear;
        mask = 0xFF;
    }

    seg = top_bit(linear | 0xFF) - 7;

    /*
     * Combine the sign, segment, quantization bits,
     * and complement the code word.
     */
    if (seg >= 8)
        u_val = (WebRtc_UWord8) (0x7F ^ mask);
    else
        u_val = (WebRtc_UWord8) (((seg << 4) | ((linear >> (seg + 3)) & 0xF)) ^ mask);
#ifdef ULAW_ZEROTRAP
    /* Optional ITU trap */
    if (u_val == 0)
        u_val = 0x02;
#endif
    return  u_val;
}
/*- End of function --------------------------------------------------------*/

/*! \brief Decode an u-law sample to a linear value.
    \param ulaw The u-law sample to decode.
    \return The linear value.
*/
static __inline WebRtc_Word16 ulaw_to_linear(WebRtc_UWord8 ulaw)
{
    int t;
    
    /* Complement to obtain normal u-law value. */
    ulaw = ~ulaw;
    /*
     * Extract and bias the quantization bits. Then
     * shift up by the segment number and subtract out the bias.
     */
    t = (((ulaw & 0x0F) << 3) + ULAW_BIAS) << (((int) ulaw & 0x70) >> 4);
    return  (WebRtc_Word16) ((ulaw & 0x80)  ?  (ULAW_BIAS - t)  :  (t - ULAW_BIAS));
}
/*- End of function --------------------------------------------------------*/

/*
 * A-law is basically as follows:
 *
 *      Linear Input Code        Compressed Code
 *      -----------------        ---------------
 *      0000000wxyza             000wxyz
 *      0000001wxyza             001wxyz
 *      000001wxyzab             010wxyz
 *      00001wxyzabc             011wxyz
 *      0001wxyzabcd             100wxyz
 *      001wxyzabcde             101wxyz
 *      01wxyzabcdef             110wxyz
 *      1wxyzabcdefg             111wxyz
 *
 * For further information see John C. Bellamy's Digital Telephony, 1982,
 * John Wiley & Sons, pps 98-111 and 472-476.
 */

#define ALAW_AMI_MASK       0x55

/*! \brief Encode a linear sample to A-law
    \param linear The sample to encode.
    \return The A-law value.
*/
static __inline WebRtc_UWord8 linear_to_alaw(int linear)
{
    int mask;
    int seg;
    
    if (linear >= 0)
    {
        /* Sign (bit 7) bit = 1 */
        mask = ALAW_AMI_MASK | 0x80;
    }
    else
    {
        /* Sign (bit 7) bit = 0 */
        mask = ALAW_AMI_MASK;
        /* WebRtc, tlegrand: Changed from -8 to -1 to get bitexact to reference
         * implementation */
        linear = -linear - 1;
    }

    /* Convert the scaled magnitude to segment number. */
    seg = top_bit(linear | 0xFF) - 7;
    if (seg >= 8)
    {
        if (linear >= 0)
        {
            /* Out of range. Return maximum value. */
            return (WebRtc_UWord8) (0x7F ^ mask);
        }
        /* We must be just a tiny step below zero */
        return (WebRtc_UWord8) (0x00 ^ mask);
    }
    /* Combine the sign, segment, and quantization bits. */
    return (WebRtc_UWord8) (((seg << 4) | ((linear >> ((seg)  ?  (seg + 3)  :  4)) & 0x0F)) ^ mask);
}
/*- End of function --------------------------------------------------------*/

/*! \brief Decode an A-law sample to a linear value.
    \param alaw The A-law sample to decode.
    \return The linear value.
*/
static __inline WebRtc_Word16 alaw_to_linear(WebRtc_UWord8 alaw)
{
    int i;
    int seg;

    alaw ^= ALAW_AMI_MASK;
    i = ((alaw & 0x0F) << 4);
    seg = (((int) alaw & 0x70) >> 4);
    if (seg)
        i = (i + 0x108) << (seg - 1);
    else
        i += 8;
    return (WebRtc_Word16) ((alaw & 0x80)  ?  i  :  -i);
}
/*- End of function --------------------------------------------------------*/

/*! \brief Transcode from A-law to u-law, using the procedure defined in G.711.
    \param alaw The A-law sample to transcode.
    \return The best matching u-law value.
*/
WebRtc_UWord8 alaw_to_ulaw(WebRtc_UWord8 alaw);

/*! \brief Transcode from u-law to A-law, using the procedure defined in G.711.
    \param alaw The u-law sample to transcode.
    \return The best matching A-law value.
*/
WebRtc_UWord8 ulaw_to_alaw(WebRtc_UWord8 ulaw);

#ifdef __cplusplus
}
#endif

#endif
/*- End of file ------------------------------------------------------------*/
