/*
 *   patched for stereo by Miroslav Slugeň -
 *       https://lists.osmocom.org/pipermail/osmocom-sdr/2013-September/000964.html
 *       https://lists.osmocom.org/pipermail/osmocom-sdr/2013-September/000974.html
 */


/*
 * rtl-sdr, turns your Realtek RTL2832 based DVB dongle into a SDR receiver
 * Copyright (C) 2012 by Steve Markgraf <steve@steve-m.de>
 * Copyright (C) 2012 by Hoernchen <la@tfc-server.de>
 * Copyright (C) 2012 by Kyle Keen <keenerd@gmail.com>
 * Copyright (C) 2013 by Elias Oenal <EliasOenal@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


/*
 * written because people could not do real time
 * FM demod on Atom hardware with GNU radio
 * based on rtl_sdr.c and rtl_tcp.c
 * todo: realtime ARMv5
 *       remove float math (disqualifies complex.h)
 *       in-place array operations
 *       sanity checks
 *       scale squelch to other input parameters
 *       test all the demodulations
 *       pad output on hop
 *       nearest gain approx
 *       frequency ranges could be stored better
 */

#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include <emmintrin.h>

#ifndef _WIN32
#include <unistd.h>
#else
#include <Windows.h>
#include <fcntl.h>
#include <io.h>
#include "getopt/getopt.h"
#define usleep(x) Sleep(x/1000)
#define round(x) (x > 0.0 ? floor(x + 0.5): ceil(x - 0.5))
#endif

#include <pthread.h>
#include <libusb.h>

#include "rtl-sdr.h"

#define DEFAULT_SAMPLE_RATE		24000
#define DEFAULT_ASYNC_BUF_NUMBER	32
#define DEFAULT_BUF_LENGTH		(1 * 16384)
#define MAXIMUM_OVERSAMPLE		16
#define MAXIMUM_BUF_LENGTH		(MAXIMUM_OVERSAMPLE * DEFAULT_BUF_LENGTH)
#define AUTO_GAIN			-100

static pthread_t demod_thread;
static pthread_mutex_t data_ready;  /* locked when no fresh data available */
static pthread_mutex_t data_write;  /* locked when r/w buffer */
static int do_exit = 0;
static rtlsdr_dev_t *dev = NULL;
static int lcm_post[17] = {1,1,1,3,1,5,3,7,1,9,5,11,3,13,7,15,1};

static int *atan_lut = NULL;
static int atan_lut_size = 131072; /* 512 KB */
static int atan_lut_coef = 8;

struct lp_complex
{
	int16_t  *br;
	int16_t  *bi;
	int16_t  *fc;
	int16_t  **fc_lut;
	int      freq;
	int      pos;
	int      size;
	int      mode;
	int      sum;
};

struct lp_real
{
	int16_t  *br;
	int16_t  *bm;
	int16_t  *bs;
	int16_t  *fm;
	int16_t  *fp;
	int16_t  *fs;
	int16_t  **fm_lut;
	int16_t  **fp_lut;
	int16_t  **fs_lut;
	int      swf;
	int      pp;
	int      cwf;
	int      freq;
	int      pos;
	int      size;
	int      mode;
	int      sum;
};

struct fm_state
{
	int      now_r, now_j;
	int      pre_r, pre_j;
	int      prev_index;
	int      downsample;    /* min 1, max 256 */
	int      post_downsample;
	int      output_scale;
	int      squelch_level, conseq_squelch, squelch_hits, terminate_on_squelch;
	int      exit_flag;
	uint8_t  buf[MAXIMUM_BUF_LENGTH];
	uint32_t buf_len;
	int      signal[MAXIMUM_BUF_LENGTH];  /* 16 bit signed i/q pairs */
	int16_t  signal2[MAXIMUM_BUF_LENGTH]; /* signal has lowpass, signal2 has demod */
	int      signal_len;
	int      signal2_len;
	FILE     *file;
	int      edge;
	uint32_t freqs[1000];
	int      freq_len;
	int      freq_now;
	uint32_t sample_rate;
	int      output_rate;
	int      custom_atan;
	double   deemph;
	int      deemph_a;
	int      deemph_l;
	int      deemph_r;
	int      now_lpr;
	int      prev_lpr_index;
	int      dc_block, dc_avg;
	int      stereo;
	void     (*mode_demod)(struct fm_state*);
	struct lp_complex lpc;
	struct lp_real lpr;
};

void usage(void)
{
	fprintf(stderr,
		"rtl_fm, a simple narrow band FM demodulator for RTL2832 based DVB-T receivers\n\n"
		"Use:\trtl_fm -f freq [-options] [filename]\n"
		"\t-f frequency_to_tune_to [Hz]\n"
		"\t (use multiple -f for scanning, requires squelch)\n"
		"\t (ranges supported, -f 118M:137M:25k)\n"
		"\t[-s sample_rate (default: 24k)]\n"
		"\t[-d device_index (default: 0)]\n"
		"\t[-g tuner_gain (default: automatic)]\n"
		"\t[-a agc (default: 1/on)]\n"
		"\t[-l squelch_level (default: 0/off)]\n"
		"\t[-o oversampling (default: 1, 4 recommended)]\n"
		"\t[-p ppm_error (default: 0)]\n"
		"\t[-E sets lower edge tuning (default: center)]\n"
		"\t[-N enables NBFM mode (default: on)]\n"
		"\t[-W enables WBFM mode (default: off)]\n"
		"\t (-N -s 192k -o 1 -A fast -r 48k -l 0 -D -F 4 -H 96000 -I 32 -J 7 -K 17000 -O 64 -D 0.000075)\n"
		"\t[-X enables WBFM EU mode (default: off)]\n"
		"\t (-N -s 192k -o 1 -A fast -r 48k -l 0 -D -F 4 -H 96000 -I 32 -J 7 -K 17000 -O 64 -D 0.00005)\n"
		"\tfilename (a '-' dumps samples to stdout)\n"
		"\t (omitting the filename also uses stdout)\n\n"
		"Experimental options:\n"
		"\t[-r output_rate (default: same as -s)]\n"
		"\t[-t squelch_delay (default: 20)]\n"
		"\t (+values will mute/scan, -values will exit)\n"
		"\t[-M enables AM mode (default: off)]\n"
		"\t[-L enables LSB mode (default: off)]\n"
		"\t[-U enables USB mode (default: off)]\n"
		//"\t[-D enables DSB mode (default: off)]\n"
		"\t[-R enables raw mode (default: off, 2x16 bit output)]\n"
		"\t[-F complex low pass filter (default: off, 1: triangle, 2: hamming, 3: hamming lut, 4: hamming sse)]\n"
		"\t[-H complex low pass frequency (default: 96000)]\n"
		"\t[-I complex low pass size (default: 32)]\n"
		"\t[-J real low pass filter (default: 0/off, 1: reserved, 2: hamming, 3: hamming lut, 4: hamming sse, 5: hamming stereo, 6: hamming stereo lut, 7: hamming stereo sse)]\n"
		"\t[-K real low pass frequency (default: 17000)]\n"
		"\t[-O real low pass size (default: 64)]\n"
		"\t[-D de-emphasis value (default: off, 0.000075 for US FM, 0.00005 for EU FM)]\n"
		"\t[-C enables DC blocking of output (default: off)]\n"
		"\t[-A std/fast/lut choose atan math (default: std)]\n\n"
		"Produces signed 16 bit ints, use Sox or aplay to hear them.\n"
		"\trtl_fm ... - | play -t raw -r 24k -e signed-integer -b 16 -c 1 -V1 -\n"
		"\t             | aplay -r 24k -f S16_LE -t raw -c 1\n"
		"\t  -s 22.5k - | multimon -t raw /dev/stdin\n\n");
	exit(1);
}

#ifdef _WIN32
BOOL WINAPI
sighandler(int signum)
{
	if (CTRL_C_EVENT == signum) {
		fprintf(stderr, "Signal caught, exiting!\n");
		do_exit = 1;
		rtlsdr_cancel_async(dev);
		return TRUE;
	}
	return FALSE;
}
#else
static void sighandler(int signum)
{
	fprintf(stderr, "Signal caught, exiting!\n");
	do_exit = 1;
	rtlsdr_cancel_async(dev);
}
#endif

void rotate_90(unsigned char *buf, uint32_t len)
/* 90 rotation is 1+0j, 0+1j, -1+0j, 0-1j
   or [0, 1, -3, 2, -4, -5, 7, -6] */
{
	uint32_t i;
	unsigned char tmp;
	for (i=0; i<len; i+=8) {
		/* uint8_t negation = 255 - x */
		tmp = 255 - buf[i+3];
		buf[i+3] = buf[i+2];
		buf[i+2] = tmp;

		buf[i+4] = 255 - buf[i+4];
		buf[i+5] = 255 - buf[i+5];

		tmp = 255 - buf[i+6];
		buf[i+6] = buf[i+7];
		buf[i+7] = tmp;
	}
}

void build_low_pass_complex(struct fm_state *fm)
{
	int i, j;
	double ft, fv, fi;
	switch (fm->lpc.mode) {
	case 0:
		fprintf(stderr, "LP Complex: sum\n");
		break;
	case 1:
/* for now, a simple triangle 
 * fancy FIRs are equally expensive, so use one */
/* point = sum(sample[i] * fir[i] * fir_len / fir_sum) */
		fm->lpc.size = fm->downsample;
		fprintf(stderr, "LP Complex: FIR triangle, size: %d\n",fm->lpc.size);
		fm->lpc.fc = malloc(fm->lpc.size << 1);
		for(i = 0; i < (fm->lpc.size/2); i++) {
			fm->lpc.fc[i] = i;
		}
		for(i = fm->lpc.size-1; i >= (fm->lpc.size/2); i--) {
			fm->lpc.fc[i] = fm->lpc.size - i;
		}
		fm->lpc.sum = 0;
		for(i = 0; i < fm->lpc.size; i++) {
			fm->lpc.sum += fm->lpc.fc[i];
		}
		break;
	case 2:
		fprintf(stderr, "LP Complex: FIR hamming, size: %d\n",fm->lpc.size);
		ft = (double) fm->lpc.freq / (double) (fm->downsample * fm->sample_rate);
		fm->lpc.br = malloc(fm->lpc.size << 1);
		fm->lpc.bi = malloc(fm->lpc.size << 1);
		fm->lpc.fc = malloc(fm->lpc.size << 1);
		fm->lpc.pos = 0;
		for(i = 0; i < fm->lpc.size; i++) {
			fm->lpc.br[i] = 0;
			fm->lpc.bi[i] = 0;
			fi = (double) i - ((double) (fm->lpc.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * ft : sin(2. * M_PI * ft * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpc.size - 1)));
			/* convert to int16, always below 1 */
			fm->lpc.fc[i] = (int16_t) lrint(fv * 32768.);
		}
		fm->lpc.sum = 32768;
		break;
	case 3:
		fprintf(stderr, "LP Complex: FIR hamming (LUT), size: %d\n",fm->lpc.size);
		ft = (double) fm->lpc.freq / (double) (fm->downsample * fm->sample_rate);
		fm->lpc.br = malloc(fm->lpc.size << 1);
		fm->lpc.bi = malloc(fm->lpc.size << 1);
		fm->lpc.fc_lut = malloc(fm->lpc.size * sizeof(*fm->lpc.fc_lut));
		fm->lpc.pos = 0;
		for(i = 0; i < fm->lpc.size; i++) {
			fm->lpc.br[i] = 0;
			fm->lpc.bi[i] = 0;
			fm->lpc.fc_lut[i] = malloc(256 * sizeof(**fm->lpc.fc_lut));
			fi = (double) i - ((double) (fm->lpc.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * ft : sin(2. * M_PI * ft * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpc.size - 1)));
			for (j = 0; j < 256; j++) {
				fm->lpc.fc_lut[i][j] = (int16_t) lrint(fv * ((double)j - 127.5) * 256.);
			}
		}
		fm->lpc.sum = 256;
		break;
	case 4:
		fprintf(stderr, "LP Complex: FIR hamming (SSE2), size: %d\n",fm->lpc.size);
		ft = (double) fm->lpc.freq / (double) (fm->downsample * fm->sample_rate);
		/* for SSE size must be multiple of 8 */
		j = fm->lpc.size;
		fm->lpc.size+= (fm->lpc.size % 8 == 0) ? 0 : 8 - (fm->lpc.size % 8);
		fm->lpc.br = malloc(fm->lpc.size << 1);
		fm->lpc.bi = malloc(fm->lpc.size << 1);
		fm->lpc.fc = malloc(fm->lpc.size << 1);
		fm->lpc.pos = 0;
		for(i = 0; i < j; i++) {
			fm->lpc.br[i] = 0;
			fm->lpc.bi[i] = 0;
			fi = (double) i - ((double) (fm->lpc.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * ft : sin(2. * M_PI * ft * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (j - 1)));
			/* convert to int16 */
			fm->lpc.fc[i] = (int16_t) lrint(fv * 32768.);
		}
		/* everything to multiply 8 set to zero */
		for(;i < fm->lpc.size; i++) {
			fm->lpc.br[i] = 0;
			fm->lpc.bi[i] = 0;
			fm->lpc.fc[i] = 0;
		}
		fm->lpc.sum = 32768;
		break;
	}
}

void low_pass_complex(struct fm_state *fm, unsigned char *buf, uint32_t len)
{
	int i=0, i2=0, i3=0;
	switch (fm->lpc.mode) {
	case 0:
/* simple square window FIR */
		while (i < (int)len) {
			fm->now_r += ((int)buf[i]   - 128);
			fm->now_j += ((int)buf[i+1] - 128);
			i += 2;
			if (++fm->prev_index < fm->downsample) continue;
			fm->signal[i2]   = fm->now_r * fm->output_scale;
			fm->signal[i2+1] = fm->now_j * fm->output_scale;
			fm->prev_index = 0;
			fm->now_r = 0;
			fm->now_j = 0;
			i2 += 2;
		}
		break;
	case 1:
/* perform an arbitrary FIR, doubles CPU use */
// possibly bugged, or overflowing
		while (i < (int)len) {
			i3 = fm->prev_index;
			fm->now_r += ((int)buf[i]   - 128) * fm->lpc.fc[i3] * fm->downsample / fm->lpc.sum;
			fm->now_j += ((int)buf[i+1] - 128) * fm->lpc.fc[i3] * fm->downsample / fm->lpc.sum;
			i += 2;
			if (++fm->prev_index < fm->downsample) continue;
			fm->signal[i2]   = fm->now_r * fm->output_scale;
			fm->signal[i2+1] = fm->now_j * fm->output_scale;
			fm->prev_index = 0;
			fm->now_r = 0;
			fm->now_j = 0;
			i2 += 2;
		}
		break;
/* Slow HQ FIR complex filter */
	case 2:
		while (i < (int)len) {
			fm->lpc.br[fm->lpc.pos] = ((int16_t)buf[i]   - 128);
			fm->lpc.bi[fm->lpc.pos] = ((int16_t)buf[i+1] - 128);
			fm->lpc.pos++;
			i += 2;
			if (++fm->prev_index < fm->downsample) continue;
			for (i3 = 0; i3 < fm->lpc.size; i3++) {
				fm->now_r += (int)(fm->lpc.br[i3] * fm->lpc.fc[i3]);
				fm->now_j += (int)(fm->lpc.bi[i3] * fm->lpc.fc[i3]);
			}
			fm->signal[i2]   = (fm->now_r * fm->output_scale) / fm->lpc.sum;
			fm->signal[i2+1] = (fm->now_j * fm->output_scale) / fm->lpc.sum;
			fm->prev_index = 0;
			fm->now_r = 0;
			fm->now_j = 0;
			i2 += 2;
			/* shift buffers, we can skip few samples at begining, but not big deal */
			if (fm->lpc.pos + fm->downsample >= fm->lpc.size) {
				fm->lpc.pos = fm->lpc.size - fm->downsample;
				memmove(fm->lpc.br, &fm->lpc.br[fm->downsample], fm->lpc.pos << 1);
				memmove(fm->lpc.bi, &fm->lpc.bi[fm->downsample], fm->lpc.pos << 1);
			}
		}
		break;
/* Slow HQ FIR LUT complex filter */
	case 3:
		while (i < (int)len) {
			fm->lpc.br[fm->lpc.pos] = buf[i];
			fm->lpc.bi[fm->lpc.pos] = buf[i+1];
			fm->lpc.pos++;
			i += 2;
			if (++fm->prev_index < fm->downsample) continue;
			for (i3 = 0; i3 < fm->lpc.size; i3++) {
				fm->now_r += fm->lpc.fc_lut[i3][fm->lpc.br[i3]];
				fm->now_j += fm->lpc.fc_lut[i3][fm->lpc.bi[i3]];
			}
			fm->signal[i2]   = (fm->now_r * fm->output_scale) / fm->lpc.sum;
			fm->signal[i2+1] = (fm->now_j * fm->output_scale) / fm->lpc.sum;
			fm->prev_index = 0;
			fm->now_r = 0;
			fm->now_j = 0;
			i2 += 2;
			/* shift buffers, we can skip few samples at begining, but not big deal */
			if (fm->lpc.pos + fm->downsample >= fm->lpc.size) {
				fm->lpc.pos = fm->lpc.size - fm->downsample;
				memmove(fm->lpc.br, &fm->lpc.br[fm->downsample], fm->lpc.pos << 1);
				memmove(fm->lpc.bi, &fm->lpc.bi[fm->downsample], fm->lpc.pos << 1);
			}
		}
		break;
/* Slow HQ FIR SSE complex filter */
	case 4:{
		/* all buffers has to be 16-bit aligned */
		__m128i m_r, m_i,
		        *m_br = (__m128i*) fm->lpc.br, *m_bi = (__m128i*) fm->lpc.bi,
		        *m_f = (__m128i*) fm->lpc.fc, m_255 = _mm_set1_epi16(255);
		int32_t *v_r = (int32_t*) &m_r, *v_i = (int32_t*) &m_i;
		const int i3_max = fm->lpc.size / 8;
		while (i < (int)len) {
			fm->lpc.br[fm->lpc.pos] = buf[i];
			fm->lpc.bi[fm->lpc.pos] = buf[i+1];
			fm->lpc.pos++;
			i += 2;
			if (++fm->prev_index < fm->downsample) continue;
			m_r = _mm_madd_epi16(_mm_sub_epi16(_mm_slli_epi16(m_br[0], 1), m_255), m_f[0]);
			m_i = _mm_madd_epi16(_mm_sub_epi16(_mm_slli_epi16(m_bi[0], 1), m_255), m_f[0]);
			for (i3 = 1; i3 < i3_max; i3++) {
				m_r = _mm_add_epi32(_mm_madd_epi16(_mm_sub_epi16(_mm_slli_epi16(m_br[i3], 1), m_255), m_f[i3]), m_r);
				m_i = _mm_add_epi32(_mm_madd_epi16(_mm_sub_epi16(_mm_slli_epi16(m_bi[i3], 1), m_255), m_f[i3]), m_i);
			}
			/* simple sum or use SSSE3 _mm_hadd_epi32 2 times, result is in v_r[0] */
			fm->signal[i2]   = ((v_r[0] + v_r[1] + v_r[2] + v_r[3]) * fm->output_scale) / fm->lpc.sum;
			fm->signal[i2+1] = ((v_i[0] + v_i[1] + v_i[2] + v_i[3]) * fm->output_scale) / fm->lpc.sum;
			fm->prev_index = 0;
			i2 += 2;
			/* shift buffers, we can skip few samples at begining, but not big deal */
			if (fm->lpc.pos + fm->downsample >= fm->lpc.size) {
				fm->lpc.pos = fm->lpc.size - fm->downsample;
				memmove(fm->lpc.br, &fm->lpc.br[fm->downsample], fm->lpc.pos << 1);
				memmove(fm->lpc.bi, &fm->lpc.bi[fm->downsample], fm->lpc.pos << 1);
			}
		}
		}break;
	}
	fm->signal_len = i2;
}

int low_pass_simple(int16_t *signal2, int len, int step)
// no wrap around, length must be multiple of step
{
	int i, i2, sum;
	for(i=0; i < len; i+=step) {
		sum = 0;
		for(i2=0; i2<step; i2++) {
			sum += (int)signal2[i + i2];
		}
		//signal2[i/step] = (int16_t)(sum / step);
		signal2[i/step] = (int16_t)(sum);
	}
	signal2[i/step + 1] = signal2[i/step];
	return len / step;
}

void build_low_pass_real(struct fm_state *fm)
{
	int i, j;
	double fmh, fpl, fph, fsl, fsh, fv, fi, fh, wf;
	switch (fm->lpr.mode) {
	case 0:
		fprintf(stderr, "LP Real: sum\n");
		break;
	case 1:
		fprintf(stderr, "LP Real: triangle not supported, using sum\n");
		break;
	case 2:
		fprintf(stderr, "LP Real: FIR hamming, size: %d\n",fm->lpr.size);
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.fm = malloc(fm->lpr.size << 1);
		fm->lpr.pos = 0;
		for(i = 0; i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fi = (double) i - ((double) (fm->lpr.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpr.size - 1)));
			/* convert to int16, always below 1 */
			fm->lpr.fm[i] = (int16_t) lrint(fv * 32768.);
		}
		fm->lpr.sum = 32768;
		break;
	case 3:
		fprintf(stderr, "LP Real: FIR hamming (LUT), size: %d\n",fm->lpr.size);
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.fm_lut = malloc(fm->lpr.size * sizeof(*fm->lpr.fm_lut));
		fm->lpr.pos = 0;
		for(i = 0; i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.fm_lut[i] = malloc(65536 * sizeof(**fm->lpr.fm_lut));
			fi = (double) i - ((double) (fm->lpr.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpr.size - 1)));
			for (j = 0; j < 32768; j++) fm->lpr.fm_lut[i][j] = (int16_t) lrint(fv * (double) j);
			for (;j < 65536; j++) fm->lpr.fm_lut[i][j] = (int16_t) lrint(fv * (double) (j - 65536));
		}
		fm->lpr.sum = 256;
		break;
	case 4:
		fprintf(stderr, "LP Real: FIR hamming (SSE2), size: %d\n",fm->lpr.size);
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		/* for SSE size must be multiple of 8 */
		j = fm->lpr.size;
		fm->lpr.size+= (fm->lpr.size % 8 == 0) ? 0 : 8 - (fm->lpr.size % 8);
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.fm = malloc(fm->lpr.size << 1);
		fm->lpr.pos = 0;
		for(i = 0; i < j; i++) {
			fm->lpr.br[i] = 0;
			fi = (double) i - ((double) (fm->lpr.size - 1) / 2.);
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			/* hamming window */
			fv*= (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (j - 1)));
			/* convert to int16 */
			fm->lpr.fm[i] = (int16_t) lrint(fv * 32768.);
		}
		/* everything to multiply 8 set to zero */
		for(;i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.fm[i] = 0;
		}
		fm->lpr.sum = 32768;
		break;
	case 5:
		fprintf(stderr, "LP Real: FIR hamming stereo, size: %d\n",fm->lpr.size);
		fm->stereo = 1;
		wf = 2.* M_PI * 19000. / (double) fm->sample_rate;
		fm->lpr.swf = lrint(32767. * sin(wf));
		fm->lpr.cwf = lrint(32767. * cos(wf));
		fm->lpr.pp = 0;
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		fpl = 18000. / (double) fm->sample_rate;
		fph = 20000. / (double) fm->sample_rate;
		fsl = 21000. / (double) fm->sample_rate;
		fsh = 55000. / (double) fm->sample_rate;
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.bm = malloc(fm->lpr.size << 1);
		fm->lpr.bs = malloc(fm->lpr.size << 1);
		fm->lpr.fm = malloc(fm->lpr.size << 1);
		fm->lpr.fp = malloc(fm->lpr.size << 1);
		fm->lpr.fs = malloc(fm->lpr.size << 1);
		fm->lpr.pos = 0;
		for(i = 0; i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.bm[i] = 0;
			fm->lpr.bs[i] = 0;
			fi = (double) i - ((double) (fm->lpr.size - 1) / 2.);
			/* hamming window */
			fh = (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpr.size - 1)));
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			fm->lpr.fm[i] = (int16_t) lrint(fv * fh * 32768.);
			/* pilot band pass */
			fv = (fi == 0) ? 2. * (fph - fpl) : (sin(2. * M_PI * fph * fi) - sin(2. * M_PI * fpl * fi)) / (M_PI * fi);
			fm->lpr.fp[i] = (int16_t) lrint(fv * fh * 32768.);
			/* stereo band pass */
			fv = (fi == 0) ? 2. * (fsh - fsl) : (sin(2. * M_PI * fsh * fi) - sin(2. * M_PI * fsl * fi)) / (M_PI * fi);
			fm->lpr.fs[i] = (int16_t) lrint(fv * fh * 32768.);
		}
		fm->lpr.sum = 32768;
		break;
	case 6:
		fprintf(stderr, "LP Real: FIR hamming stereo (LUT), size: %d\n",fm->lpr.size);
		fm->stereo = 1;
		wf = 2.* M_PI * 19000. / (double) fm->sample_rate;
		fm->lpr.swf = lrint(32767. * sin(wf));
		fm->lpr.cwf = lrint(32767. * cos(wf));
		fm->lpr.pp = 0;
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		fpl = 18000. / (double) fm->sample_rate;
		fph = 20000. / (double) fm->sample_rate;
		fsl = 21000. / (double) fm->sample_rate;
		fsh = 55000. / (double) fm->sample_rate;
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.bm = malloc(fm->lpr.size << 1);
		fm->lpr.bs = malloc(fm->lpr.size << 1);
		fm->lpr.fm_lut = malloc(fm->lpr.size * sizeof(*fm->lpr.fm_lut));
		fm->lpr.fp_lut = malloc(fm->lpr.size * sizeof(*fm->lpr.fp_lut));
		fm->lpr.fs_lut = malloc(fm->lpr.size * sizeof(*fm->lpr.fs_lut));
		fm->lpr.pos = 0;
		for(i = 0; i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.bm[i] = 0;
			fm->lpr.bs[i] = 0;
			fm->lpr.fm_lut[i] = malloc(65536 * sizeof(**fm->lpr.fm_lut));
			fm->lpr.fp_lut[i] = malloc(65536 * sizeof(**fm->lpr.fp_lut));
			fm->lpr.fs_lut[i] = malloc(65536 * sizeof(**fm->lpr.fs_lut));
			fi = (double) i - ((double) (fm->lpr.size - 1) / 2.);
			/* hamming window */
			fh = (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (fm->lpr.size - 1)));
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			for (j = 0; j < 32768; j++) fm->lpr.fm_lut[i][j] = (int16_t) lrint(fv * fh * (double) j);
			for (;j < 65536; j++) fm->lpr.fm_lut[i][j] = (int16_t) lrint(fv * fh * (double) (j - 65536));
			/* pilot band pass */
			fv = (fi == 0) ? 2. * (fph - fpl) : (sin(2. * M_PI * fph * fi) - sin(2. * M_PI * fpl * fi)) / (M_PI * fi);
			for (j = 0; j < 32768; j++) fm->lpr.fp_lut[i][j] = (int16_t) lrint(fv * fh * (double) j);
			for (;j < 65536; j++) fm->lpr.fp_lut[i][j] = (int16_t) lrint(fv * fh * (double) (j - 65536));
			/* stereo band pass */
			fv = (fi == 0) ? 2. * (fsh - fsl) : (sin(2. * M_PI * fsh * fi) - sin(2. * M_PI * fsl * fi)) / (M_PI * fi);
			for (j = 0; j < 32768; j++) fm->lpr.fs_lut[i][j] = (int16_t) lrint(fv * fh * (double) j);
			for (;j < 65536; j++) fm->lpr.fs_lut[i][j] = (int16_t) lrint(fv * fh * (double) (j - 65536));
		}
		fm->lpr.sum = 1;
		break;
	case 7:
		fprintf(stderr, "LP Real: FIR hamming stereo (SSE2), size: %d\n",fm->lpr.size);
		fm->stereo = 1;
		/* for SSE size must be multiple of 8 */
		wf = 2.* M_PI * 19000. / (double) fm->sample_rate;
		fm->lpr.swf = lrint(32767. * sin(wf));
		fm->lpr.cwf = lrint(32767. * cos(wf));
		fm->lpr.pp = 0;
		j = fm->lpr.size;
		fm->lpr.size+= (fm->lpr.size % 8 == 0) ? 0 : 8 - (fm->lpr.size % 8);
		fmh = (double) fm->lpr.freq / (double) fm->sample_rate;
		fpl = 18000. / (double) fm->sample_rate;
		fph = 20000. / (double) fm->sample_rate;
		fsl = 21000. / (double) fm->sample_rate;
		fsh = 55000. / (double) fm->sample_rate;
		fm->lpr.br = malloc(fm->lpr.size << 1);
		fm->lpr.bm = malloc(fm->lpr.size << 1);
		fm->lpr.bs = malloc(fm->lpr.size << 1);
		fm->lpr.fm = malloc(fm->lpr.size << 1);
		fm->lpr.fp = malloc(fm->lpr.size << 1);
		fm->lpr.fs = malloc(fm->lpr.size << 1);
		fm->lpr.pos = 0;
		for(i = 0; i < j; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.bm[i] = 0;
			fm->lpr.bs[i] = 0;
			fi = (double) i - ((double) (j - 1) / 2.);
			/* hamming window */
			fh = (0.54 - 0.46 * cos(2. * M_PI * (double) i / (double) (j - 1)));
			/* low pass */
			fv = (fi == 0) ? 2. * fmh : sin(2. * M_PI * fmh * fi) / (M_PI * fi);
			fm->lpr.fm[i] = (int16_t) lrint(fv * fh * 32768.);
			/* pilot band pass */
			fv = (fi == 0) ? 2. * (fph - fpl) : (sin(2. * M_PI * fph * fi) - sin(2. * M_PI * fpl * fi)) / (M_PI * fi);
			fm->lpr.fp[i] = (int16_t) lrint(fv * fh * 32768.);
			/* stereo band pass */
			fv = (fi == 0) ? 2. * (fsh - fsl) : (sin(2. * M_PI * fsh * fi) - sin(2. * M_PI * fsl * fi)) / (M_PI * fi);
			fm->lpr.fs[i] = (int16_t) lrint(fv * fh * 32768.);
		}
		/* everything to multiply 8 set to zero */
		for(;i < fm->lpr.size; i++) {
			fm->lpr.br[i] = 0;
			fm->lpr.bm[i] = 0;
			fm->lpr.bs[i] = 0;
			fm->lpr.fm[i] = 0;
			fm->lpr.fp[i] = 0;
			fm->lpr.fs[i] = 0;
		}
		fm->lpr.sum = 32768;
		break;
	}
}

float sin2atan2f(int x, int y) {
    /* y = 0 projde bez problémů dále */
    if (x == 0) return 0.f;

    float z = (float) y / (float) x;

    return (z + z) / (1.f + (z * z));
}

void low_pass_real(struct fm_state *fm)
{
	int i=0, i2=0, i3=0, i4=0;
	int fast = (int)fm->sample_rate / fm->post_downsample;
	int slow = fm->output_rate;
	switch (fm->lpr.mode) {
/* simple square window FIR */
// add support for upsampling?
	case 0:
	case 1:
		while (i < fm->signal2_len) {
			fm->now_lpr+= fm->signal2[i++];
			i3++;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			fm->signal2[i2++] = (int16_t)(fm->now_lpr / i3);
			fm->now_lpr = 0;
			i3 = 0;
		}
		break;
	case 2:
		while (i < fm->signal2_len) {
			fm->lpr.br[fm->lpr.pos] = fm->signal2[i++];
			/* circular buffer */
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			for (i3 = 0, i4 = fm->lpr.pos; i3 < fm->lpr.size; i3++) {
				fm->now_lpr += (int)(fm->lpr.br[i4] * fm->lpr.fm[i3]);
				if (++i4 == fm->lpr.size) i4 = 0;
			}
			fm->signal2[i2++] = (int16_t)(fm->now_lpr / fm->lpr.sum);
			fm->now_lpr = 0;
		}
		break;
	case 3:{
		uint16_t *br = (uint16_t*) fm->lpr.br;
		while (i < fm->signal2_len) {
			fm->lpr.br[fm->lpr.pos] = fm->signal2[i++];
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			for (i3 = 0, i4 = fm->lpr.pos; i3 < fm->lpr.size; i3++) {
				fm->now_lpr += (int)fm->lpr.fm_lut[i3][br[i4]];
				if (++i4 == fm->lpr.size) i4 = 0;
			}
			fm->signal2[i2++] = (int16_t)fm->now_lpr;
			fm->now_lpr = 0;
		}
		}break;
	case 4:{
		/* all buffers has to be 16-bit aligned */
		int16_t tb[fm->lpr.size];
		__m128i m_m, *m_br = (__m128i*) tb, *m_fm = (__m128i*) fm->lpr.fm;
		int32_t *v_m = (int32_t*) &m_m;
		const int i3_max = fm->lpr.size / 8;
		while (i < fm->signal2_len) {
			fm->lpr.br[fm->lpr.pos] = fm->signal2[i++];
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			/* align buffer */
			memcpy(tb, &fm->lpr.br[fm->lpr.pos], (fm->lpr.size - fm->lpr.pos) << 1);
			memcpy(&tb[(fm->lpr.size - fm->lpr.pos)], fm->lpr.br, fm->lpr.pos << 1);
			/* madd */
			m_m = _mm_madd_epi16(m_br[0], m_fm[0]);
			for (i3 = 1; i3 < i3_max; i3++) m_m = _mm_add_epi32(_mm_madd_epi16(m_br[i3], m_fm[i3]), m_m);
			/* simple sum or use SSSE3 _mm_hadd_epi32 2 times, result is in v_m[0] */
			fm->signal2[i2++] = (int16_t)((v_m[0] + v_m[1] + v_m[2] + v_m[3]) / fm->lpr.sum);
			fm->now_lpr = 0;
		}
		}break;
	case 5:{
		int vm, vs, vp;
		while (i < fm->signal2_len) {
			fm->lpr.br[fm->lpr.pos] = fm->signal2[i++];
			for (i3 = 0, i4 = fm->lpr.pos, vm = 0, vp = 0, vs = 0; i3 < fm->lpr.size; i3++) {
				if (++i4 == fm->lpr.size) i4 = 0;
				vm+= (int)(fm->lpr.br[i4] * fm->lpr.fm[i3]);
				vp+= (int)(fm->lpr.br[i4] * fm->lpr.fp[i3]);
				vs+= (int)(fm->lpr.br[i4] * fm->lpr.fs[i3]);
			}
			vp/= fm->lpr.sum;
			fm->lpr.bm[fm->lpr.pos] = (int16_t)(vm / fm->lpr.sum);
			fm->lpr.bs[fm->lpr.pos] = (int16_t)(lrintf((float) vs * sin2atan2f(vp * fm->lpr.swf, vp * fm->lpr.cwf - fm->lpr.pp * 32767)) / fm->lpr.sum);
			fm->lpr.pp = vp;
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			for (i3 = 0, i4 = fm->lpr.pos, vm = 0, vs = 0; i3 < fm->lpr.size; i3++) {
				vm+= (int)(fm->lpr.bm[i4] * fm->lpr.fm[i3]);
				vs+= (int)(fm->lpr.bs[i4] * fm->lpr.fm[i3]);
				if (++i4 == fm->lpr.size) i4 = 0;
			}
			fm->signal2[i2] = (int16_t)((vm + vs) / fm->lpr.sum);
			fm->signal2[i2 + 1] = (int16_t)((vm - vs) / fm->lpr.sum);
			i2+= 2;
		}
		}break;
	case 6:{
		int vm, vs, vp;
		uint16_t *br = (uint16_t*) fm->lpr.br, *bm = (uint16_t*) fm->lpr.bm, *bs = (uint16_t*) fm->lpr.bs;
		while (i < fm->signal2_len) {
			fm->lpr.br[fm->lpr.pos] = fm->signal2[i++];
			for (i3 = 0, i4 = fm->lpr.pos, vm = 0, vp = 0, vs = 0; i3 < fm->lpr.size; i3++) {
				if (++i4 == fm->lpr.size) i4 = 0;
				vm+= (int)fm->lpr.fm_lut[i3][br[i4]];
				vp+= (int)fm->lpr.fp_lut[i3][br[i4]];
				vs+= (int)fm->lpr.fs_lut[i3][br[i4]];
			}
			vp/= fm->lpr.sum;
			fm->lpr.bm[fm->lpr.pos] = (int16_t)(vm / fm->lpr.sum);
			fm->lpr.bs[fm->lpr.pos] = (int16_t)(lrintf((float) vs * sin2atan2f(vp * fm->lpr.swf, vp * fm->lpr.cwf - fm->lpr.pp * 32767)) / fm->lpr.sum);
			fm->lpr.pp = vp;
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			for (i3 = 0, i4 = fm->lpr.pos, vm = 0, vs = 0; i3 < fm->lpr.size; i3++) {
				vm+= (int)fm->lpr.fm_lut[i3][bm[i4]];
				vs+= (int)fm->lpr.fm_lut[i3][bs[i4]];
				if (++i4 == fm->lpr.size) i4 = 0;
			}
			fm->signal2[i2] = (int16_t)((vm + vs) / fm->lpr.sum);
			fm->signal2[i2 + 1] = (int16_t)((vm - vs) / fm->lpr.sum);
			i2+= 2;
		}
		}break;
/* Most complicated version of stereo demultiplexer */
	case 7:{
		int16_t tbm[fm->lpr.size], tbs[fm->lpr.size];
		__m128i m_m, m_p, m_s, *m_br = (__m128i*) fm->lpr.br, *m_fm = (__m128i*) fm->lpr.fm,
		        *m_fp = (__m128i*) fm->lpr.fp, *m_fs = (__m128i*) fm->lpr.fs,
		        *m_bm = (__m128i*) tbm, *m_bs = (__m128i*) tbs;
		int32_t *v_m = (int32_t*) &m_m, *v_p = (int32_t*) &m_p, *v_s = (int32_t*) &m_s;
		const int i3_max = fm->lpr.size / 8;
		int vm, vp, vs;
		while (i < fm->signal2_len) {
			/* permanent align */
			memmove(fm->lpr.br, &fm->lpr.br[1], (fm->lpr.size - 1) << 1);
			fm->lpr.br[fm->lpr.size - 1] = fm->signal2[i++];
			/* sum */
			m_m = _mm_madd_epi16(m_br[0], m_fm[0]);
			m_p = _mm_madd_epi16(m_br[0], m_fp[0]);
			m_s = _mm_madd_epi16(m_br[0], m_fs[0]);
			for (i3 = 1; i3 < i3_max; i3++) {
			    m_m = _mm_add_epi32(_mm_madd_epi16(m_br[i3], m_fm[i3]), m_m);
			    m_p = _mm_add_epi32(_mm_madd_epi16(m_br[i3], m_fp[i3]), m_p);
			    m_s = _mm_add_epi32(_mm_madd_epi16(m_br[i3], m_fs[i3]), m_s);
			}
			vm = v_m[0] + v_m[1] + v_m[2] + v_m[3];
			vp = (v_p[0] + v_p[1] + v_p[2] + v_p[3]) / fm->lpr.sum;
			vs = v_s[0] + v_s[1] + v_s[2] + v_s[3];
			fm->lpr.bm[fm->lpr.pos] = (int16_t)(vm / fm->lpr.sum);
			/* sin2atan2f is still slow */
			fm->lpr.bs[fm->lpr.pos] = (int16_t)(lrintf((float) vs * sin2atan2f(vp * fm->lpr.swf, vp * fm->lpr.cwf - fm->lpr.pp * 32767)) / fm->lpr.sum);
			fm->lpr.pp = vp;
			if (++fm->lpr.pos == fm->lpr.size) fm->lpr.pos = 0;
			if ((fm->prev_lpr_index+= slow) < fast) continue;
			fm->prev_lpr_index-= fast;
			/* align */
			memcpy(tbm, &fm->lpr.bm[fm->lpr.pos], (fm->lpr.size - fm->lpr.pos) << 1);
			memcpy(&tbm[(fm->lpr.size - fm->lpr.pos)], fm->lpr.bm, fm->lpr.pos << 1);
			memcpy(tbs, &fm->lpr.bs[fm->lpr.pos], (fm->lpr.size - fm->lpr.pos) << 1);
			memcpy(&tbs[(fm->lpr.size - fm->lpr.pos)], fm->lpr.bs, fm->lpr.pos << 1);
			/* sum */
			m_m = _mm_madd_epi16(m_bm[0], m_fm[0]);
			m_s = _mm_madd_epi16(m_bs[0], m_fm[0]);
			for (i3 = 1; i3 < i3_max; i3++) {
			    m_m = _mm_add_epi32(_mm_madd_epi16(m_bm[i3], m_fm[i3]), m_m);
			    m_s = _mm_add_epi32(_mm_madd_epi16(m_bs[i3], m_fm[i3]), m_s);
			}
			vm = v_m[0] + v_m[1] + v_m[2] + v_m[3];
			vs = v_s[0] + v_s[1] + v_s[2] + v_s[3];
			fm->signal2[i2] = (int16_t)((vm + vs) / fm->lpr.sum);
			fm->signal2[i2 + 1] = (int16_t)((vm - vs) / fm->lpr.sum);
			i2+= 2;
		}
		}break;
	}
	fm->signal2_len = i2;
}

/* define our own complex math ops
   because ARMv5 has no hardware float */

void multiply(int ar, int aj, int br, int bj, int *cr, int *cj)
{
	*cr = ar*br - aj*bj;
	*cj = aj*br + ar*bj;
}

int polar_discriminant(int ar, int aj, int br, int bj)
{
	int cr, cj;
	double angle;
	multiply(ar, aj, br, -bj, &cr, &cj);
	angle = atan2((double)cj, (double)cr);
	return (int)(angle / 3.14159 * (1<<14));
}

int fast_atan2(int y, int x)
/* pre scaled for int16 */
{
	int yabs, angle;
	int pi4=(1<<12), pi34=3*(1<<12);  // note pi = 1<<14
	if (x==0 && y==0) {
		return 0;
	}
	yabs = y;
	if (yabs < 0) {
		yabs = -yabs;
	}
	if (x >= 0) {
		angle = pi4  - pi4 * (x-yabs) / (x+yabs);
	} else {
		angle = pi34 - pi4 * (x+yabs) / (yabs-x);
	}
	if (y < 0) {
		return -angle;
	}
	return angle;
}

int polar_disc_fast(int ar, int aj, int br, int bj)
{
	int cr, cj;
	multiply(ar, aj, br, -bj, &cr, &cj);
	return fast_atan2(cj, cr);
}

int atan_lut_init()
{
	int i = 0;

	atan_lut = malloc(atan_lut_size * sizeof(int));

	for (i = 0; i < atan_lut_size; i++) {
		atan_lut[i] = (int) (atan((double) i / (1<<atan_lut_coef)) / 3.14159 * (1<<14));
	}

	return 0;
}

int polar_disc_lut(int ar, int aj, int br, int bj)
{
	int cr, cj, x, x_abs;

	multiply(ar, aj, br, -bj, &cr, &cj);

	/* special cases */
	if (cr == 0 || cj == 0) {
		if (cr == 0 && cj == 0)
			{return 0;}
		if (cr == 0 && cj > 0)
			{return 1 << 13;}
		if (cr == 0 && cj < 0)
			{return -(1 << 13);}
		if (cj == 0 && cr > 0)
			{return 0;}
		if (cj == 0 && cr < 0)
			{return 1 << 14;}
	}

	/* real range -32768 - 32768 use 64x range -> absolute maximum: 2097152 */
	x = (cj << atan_lut_coef) / cr;
	x_abs = abs(x);

	if (x_abs >= atan_lut_size) {
		/* we can use linear range, but it is not necessary */
		return (cj > 0) ? 1<<13 : -1<<13;
	}

	if (x > 0) {
		return (cj > 0) ? atan_lut[x] : atan_lut[x] - (1<<14);
	} else {
		return (cj > 0) ? (1<<14) - atan_lut[-x] : -atan_lut[-x];
	}

	return 0;
}

void fm_demod(struct fm_state *fm)
{
	int i, pcm;
	pcm = polar_discriminant(fm->signal[0], fm->signal[1],
		fm->pre_r, fm->pre_j);
	fm->signal2[0] = (int16_t)pcm;
	for (i = 2; i < (fm->signal_len); i += 2) {
		switch (fm->custom_atan) {
		case 0:
			pcm = polar_discriminant(fm->signal[i], fm->signal[i+1],
				fm->signal[i-2], fm->signal[i-1]);
			break;
		case 1:
			pcm = polar_disc_fast(fm->signal[i], fm->signal[i+1],
				fm->signal[i-2], fm->signal[i-1]);
			break;
		case 2:
			pcm = polar_disc_lut(fm->signal[i], fm->signal[i+1],
				fm->signal[i-2], fm->signal[i-1]);
			break;
		}
		fm->signal2[i/2] = (int16_t)pcm;
	}
	fm->pre_r = fm->signal[fm->signal_len - 2];
	fm->pre_j = fm->signal[fm->signal_len - 1];
	fm->signal2_len = fm->signal_len/2;
}

void am_demod(struct fm_state *fm)
// todo, fix this extreme laziness
{
	int i, pcm;
	for (i = 0; i < (fm->signal_len); i += 2) {
		// hypot uses floats but won't overflow
		//fm->signal2[i/2] = (int16_t)hypot(fm->signal[i], fm->signal[i+1]);
		pcm = fm->signal[i] * fm->signal[i];
		pcm += fm->signal[i+1] * fm->signal[i+1];
		fm->signal2[i/2] = (int16_t)sqrt(pcm); // * fm->output_scale;
	}
	fm->signal2_len = fm->signal_len/2;
	// lowpass? (3khz)  highpass?  (dc)
}

void usb_demod(struct fm_state *fm)
{
	int i, pcm;
	for (i = 0; i < (fm->signal_len); i += 2) {
		pcm = fm->signal[i] + fm->signal[i+1];
		fm->signal2[i/2] = (int16_t)pcm; // * fm->output_scale;
	}
	fm->signal2_len = fm->signal_len/2;
}

void lsb_demod(struct fm_state *fm)
{
	int i, pcm;
	for (i = 0; i < (fm->signal_len); i += 2) {
		pcm = fm->signal[i] - fm->signal[i+1];
		fm->signal2[i/2] = (int16_t)pcm; // * fm->output_scale;
	}
	fm->signal2_len = fm->signal_len/2;
}

void raw_demod(struct fm_state *fm)
{
	/* hacky and pointless code */
	int i;
	for (i = 0; i < (fm->signal_len); i++) {
		fm->signal2[i] = (int16_t)fm->signal[i];
	}
	fm->signal2_len = fm->signal_len;
}

void deemph_filter(struct fm_state *fm)
{
	int i, d;
	// de-emph IIR
	// avg = avg * (1 - alpha) + sample * alpha;
	if (fm->stereo) {
		for (i = 0; i < fm->signal2_len; i+= 2) {
			/* left */
			d = fm->signal2[i] - fm->deemph_l;
			if (d > 0) {
				fm->deemph_l += (d + fm->deemph_a/2) / fm->deemph_a;
			} else {
				fm->deemph_l += (d - fm->deemph_a/2) / fm->deemph_a;
			}
			fm->signal2[i] = (int16_t)fm->deemph_l;
			/* right */
			d = fm->signal2[i + 1] - fm->deemph_r;
			if (d > 0) {
				fm->deemph_r += (d + fm->deemph_a/2) / fm->deemph_a;
			} else {
				fm->deemph_r += (d - fm->deemph_a/2) / fm->deemph_a;
			}
			fm->signal2[i + 1] = (int16_t)fm->deemph_r;
		}
	} else {
		for (i = 0; i < fm->signal2_len; i++) {
			d = fm->signal2[i] - fm->deemph_l;
			if (d > 0) {
				fm->deemph_l += (d + fm->deemph_a/2) / fm->deemph_a;
			} else {
				fm->deemph_l += (d - fm->deemph_a/2) / fm->deemph_a;
			}
			fm->signal2[i] = (int16_t)fm->deemph_l;
		}
	}
}

void dc_block_filter(struct fm_state *fm)
{
	int i, avg;
	int64_t sum = 0;
	for (i=0; i < fm->signal2_len; i++) {
		sum += fm->signal2[i];
	}
	avg = sum / fm->signal2_len;
	avg = (avg + fm->dc_avg * 9) / 10;
	for (i=0; i < fm->signal2_len; i++) {
		fm->signal2[i] -= avg;
	}
	fm->dc_avg = avg;
}

int mad(int *samples, int len, int step)
/* mean average deviation */
{
	int i=0, sum=0, ave=0;
	if (len == 0)
		{return 0;}
	for (i=0; i<len; i+=step) {
		sum += samples[i];
	}
	ave = sum / (len * step);
	sum = 0;
	for (i=0; i<len; i+=step) {
		sum += abs(samples[i] - ave);
	}
	return sum / (len / step);
}

int post_squelch(struct fm_state *fm)
/* returns 1 for active signal, 0 for no signal */
{
	int dev_r, dev_j, len, sq_l;
	/* only for small samples, big samples need chunk processing */
	len = fm->signal_len;
	sq_l = fm->squelch_level;
	dev_r = mad(&(fm->signal[0]), len, 2);
	dev_j = mad(&(fm->signal[1]), len, 2);
	if ((dev_r > sq_l) || (dev_j > sq_l)) {
		fm->squelch_hits = 0;
		return 1;
	}
	fm->squelch_hits++;
	return 0;
}

static void optimal_settings(struct fm_state *fm, int freq, int hopping)
{
	int r, capture_freq, capture_rate;
	fm->downsample = (1000000 / fm->sample_rate) + 1;
	fm->freq_now = freq;
	capture_rate = fm->downsample * fm->sample_rate;
	capture_freq = fm->freqs[freq] + capture_rate/4;
	capture_freq += fm->edge * fm->sample_rate / 2;
	fm->output_scale = (1<<15) / (128 * fm->downsample);
	if (fm->output_scale < 1) {
		fm->output_scale = 1;}
	fm->output_scale = 1;
	/* Set the frequency */
	r = rtlsdr_set_center_freq(dev, (uint32_t)capture_freq);
	if (hopping) {
		return;}
	fprintf(stderr, "Oversampling input by: %ix.\n", fm->downsample);
	fprintf(stderr, "Oversampling output by: %ix.\n", fm->post_downsample);
	fprintf(stderr, "Buffer size: %0.2fms\n",
		1000 * 0.5 * lcm_post[fm->post_downsample] * (float)DEFAULT_BUF_LENGTH / (float)capture_rate);
	if (r < 0) {
		fprintf(stderr, "WARNING: Failed to set center freq.\n");}
	else {
		fprintf(stderr, "Tuned to %u Hz.\n", capture_freq);}

	/* Set the sample rate */
	fprintf(stderr, "Sampling at %u Hz.\n", capture_rate);
	if (fm->output_rate > 0) {
		fprintf(stderr, "Output at %u Hz.\n", fm->output_rate);
	} else {
		fprintf(stderr, "Output at %u Hz.\n", fm->sample_rate/fm->post_downsample);}
	r = rtlsdr_set_sample_rate(dev, (uint32_t)capture_rate);
	if (r < 0) {
		fprintf(stderr, "WARNING: Failed to set sample rate.\n");}

}

void full_demod(struct fm_state *fm)
{
	int i, sr, freq_next, hop = 0;
	rotate_90(fm->buf, fm->buf_len);
	low_pass_complex(fm, fm->buf, fm->buf_len);
	pthread_mutex_unlock(&data_write);
	fm->mode_demod(fm);
        if (fm->mode_demod == &raw_demod) {
		fwrite(fm->signal2, 2, fm->signal2_len, fm->file);
		return;
	}
	sr = post_squelch(fm);
	if (!sr && fm->squelch_hits > fm->conseq_squelch) {
		if (fm->terminate_on_squelch) {
			fm->exit_flag = 1;}
		if (fm->freq_len == 1) {  /* mute */
			for (i=0; i<fm->signal_len; i++) {
				fm->signal2[i] = 0;}
		}
		else {
			hop = 1;}
	}
	if (fm->post_downsample > 1) {
		fm->signal2_len = low_pass_simple(fm->signal2, fm->signal2_len, fm->post_downsample);}
	if (fm->output_rate > 0) {
		low_pass_real(fm);
	}
	if (fm->deemph) deemph_filter(fm);
	if (fm->dc_block) dc_block_filter(fm);
	/* ignore under runs for now */
	fwrite(fm->signal2, 2, fm->signal2_len, fm->file);
	if (hop) {
		freq_next = (fm->freq_now + 1) % fm->freq_len;
		optimal_settings(fm, freq_next, 1);
		fm->squelch_hits = fm->conseq_squelch + 1;  /* hair trigger */
		/* wait for settling and flush buffer */
		usleep(5000);
		rtlsdr_read_sync(dev, NULL, 4096, NULL);
	}
}

static void rtlsdr_callback(unsigned char *buf, uint32_t len, void *ctx)
{
	struct fm_state *fm2 = ctx;
	if (do_exit) {
		return;}
	if (!ctx) {
		return;}
	pthread_mutex_lock(&data_write);
	memcpy(fm2->buf, buf, len);
	fm2->buf_len = len;
	pthread_mutex_unlock(&data_ready);
	/* single threaded uses 25% less CPU? */
	/* full_demod(fm2); */
}

static void *demod_thread_fn(void *arg)
{
	struct fm_state *fm2 = arg;
	while (!do_exit) {
		pthread_mutex_lock(&data_ready);
		full_demod(fm2);
		if (fm2->exit_flag) {
			do_exit = 1;
			rtlsdr_cancel_async(dev);}
	}
	return 0;
}

double atofs(char* f)
/* standard suffixes */
{
	char* chop;
        double suff = 1.0;
	chop = malloc((strlen(f)+1)*sizeof(char));
	strncpy(chop, f, strlen(f)-1);
	switch (f[strlen(f)-1]) {
		case 'G':
			suff *= 1e3;
		case 'M':
			suff *= 1e3;
		case 'k':
			suff *= 1e3;
                        suff *= atof(chop);}
	free(chop);
	if (suff != 1.0) {
		return suff;}
	return atof(f);
}

void frequency_range(struct fm_state *fm, char *arg)
{
	char *start, *stop, *step;
	int i;
	start = arg;
	stop = strchr(start, ':') + 1;
	stop[-1] = '\0';
	step = strchr(stop, ':') + 1;
	step[-1] = '\0';
	for(i=(int)atofs(start); i<=(int)atofs(stop); i+=(int)atofs(step))
	{
		fm->freqs[fm->freq_len] = (uint32_t)i;
		fm->freq_len++;
	}
	stop[-1] = ':';
	step[-1] = ':';
}

void fm_init(struct fm_state *fm)
{
	fm->freqs[0] = 100000000;
	fm->sample_rate = DEFAULT_SAMPLE_RATE;
	fm->squelch_level = 0;
	fm->conseq_squelch = 20;
	fm->terminate_on_squelch = 0;
	fm->squelch_hits = 0;
	fm->freq_len = 0;
	fm->edge = 0;
	fm->prev_index = 0;
	fm->post_downsample = 1;  // once this works, default = 4
	fm->custom_atan = 0;
	fm->deemph = 0;
	fm->output_rate = -1;  // flag for disabled
	fm->mode_demod = &fm_demod;
	fm->pre_j = fm->pre_r = fm->now_r = fm->now_j = 0;
	fm->prev_lpr_index = 0;
	fm->deemph_a = 0;
	fm->deemph_l = 0;
	fm->deemph_r = 0;
	fm->now_lpr = 0;
	fm->dc_block = 0;
	fm->dc_avg = 0;
	fm->lpc.mode = 0;
	fm->lpc.freq = 96000;
	fm->lpc.size = 32;
	fm->lpr.mode = 0;
	fm->lpr.freq = 17000;
	fm->lpr.size = 64;
	fm->stereo = 0;
}

int main(int argc, char **argv)
{
#ifndef _WIN32
	struct sigaction sigact;
#endif
	struct fm_state fm; 
	char *filename = NULL;
	int n_read, r, opt, wb_mode = 0;
	int i, gain = AUTO_GAIN, agc = 1; // tenths of a dB
	uint8_t *buffer;
	uint32_t dev_index = 0;
	int device_count;
	int ppm_error = 0;
	char vendor[256], product[256], serial[256];
	fm_init(&fm);
	pthread_mutex_init(&data_ready, NULL);
	pthread_mutex_init(&data_write, NULL);

	while ((opt = getopt(argc, argv, "a:d:f:g:s:b:l:o:t:r:p:EF:G:H:I:J:K:O:A:NWXMULRD:C")) != -1) {
		switch (opt) {
		case 'a':
			agc = atoi(optarg);
			break;
		case 'd':
			dev_index = atoi(optarg);
			break;
		case 'f':
			if (strchr(optarg, ':'))
				{frequency_range(&fm, optarg);}
			else
			{
				fm.freqs[fm.freq_len] = (uint32_t)atofs(optarg);
				fm.freq_len++;
			}
			break;
		case 'g':
			gain = (int)(atof(optarg) * 10);
			break;
		case 'l':
			fm.squelch_level = (int)atof(optarg);
			break;
		case 's':
			fm.sample_rate = (uint32_t)atofs(optarg);
			break;
		case 'r':
			fm.output_rate = (int)atofs(optarg);
			break;
		case 'o':
			fm.post_downsample = (int)atof(optarg);
			if (fm.post_downsample < 1 || fm.post_downsample > MAXIMUM_OVERSAMPLE) {
				fprintf(stderr, "Oversample must be between 1 and %i\n", MAXIMUM_OVERSAMPLE);}
			break;
		case 't':
			fm.conseq_squelch = (int)atof(optarg);
			if (fm.conseq_squelch < 0) {
				fm.conseq_squelch = -fm.conseq_squelch;
				fm.terminate_on_squelch = 1;
			}
			break;
		case 'p':
			ppm_error = atoi(optarg);
			break;
		case 'E':
			fm.edge = 1;
			break;
		case 'F':
			fm.lpc.mode = atoi(optarg);
			break;
		case 'H':
			fm.lpc.freq = atoi(optarg);
			break;
		case 'I':
			fm.lpc.size = atoi(optarg);
			break;
		case 'J':
			fm.lpr.mode = atoi(optarg);
			break;
		case 'K':
			fm.lpr.freq = atoi(optarg);
			break;
		case 'O':
			fm.lpr.size = atoi(optarg);
			break;
		case 'A':
			if (strcmp("std",  optarg) == 0) {
				fm.custom_atan = 0;}
			if (strcmp("fast", optarg) == 0) {
				fm.custom_atan = 1;}
			if (strcmp("lut",  optarg) == 0) {
				atan_lut_init();
				fm.custom_atan = 2;}
			break;
		case 'D':
			fm.deemph = atof(optarg);
			break;
		case 'C':
			fm.dc_block = 1;
			break;
		case 'N':
			fm.mode_demod = &fm_demod;
			break;
		case 'W':
			wb_mode = 1;
			fm.mode_demod = &fm_demod;
			fm.sample_rate = 192000;
			fm.output_rate = 48000;
			fm.custom_atan = 1;
			fm.post_downsample = 1;
			fm.deemph = 0.000075;
			fm.squelch_level = 0;
			fm.lpc.mode = 4; /* SSE */
			fm.lpc.freq = 96000;
			fm.lpc.size = 32;
			fm.lpr.mode = 7; /* SSE stereo */
			fm.lpr.freq = 17000;
			fm.lpr.size = 64;
			agc = 1;
			break;
		case 'X':
			wb_mode = 1;
			fm.mode_demod = &fm_demod;
			fm.sample_rate = 192000;
			fm.output_rate = 48000;
			fm.custom_atan = 1;
			fm.post_downsample = 1;
			fm.deemph = 0.00005;
			fm.squelch_level = 0;
			fm.lpc.mode = 4; /* SSE */
			fm.lpc.freq = 96000;
			fm.lpc.size = 32;
			fm.lpr.mode = 7; /* SSE stereo */
			fm.lpr.freq = 17000;
			fm.lpr.size = 64;
			agc = 1;
			break;
		case 'M':
			fm.mode_demod = &am_demod;
			break;
		case 'U':
			fm.mode_demod = &usb_demod;
			break;
		case 'L':
			fm.mode_demod = &lsb_demod;
			break;
		case 'R':
			fm.mode_demod = &raw_demod;
			break;
		default:
			usage();
			break;
		}
	}
	/* quadruple sample_rate to limit to Δθ to ±π/2 */
	fm.sample_rate *= fm.post_downsample;

	if (fm.freq_len == 0) {
		fprintf(stderr, "Please specify a frequency.\n");
		exit(1);
	}

	if (fm.freq_len > 1) {
		fm.terminate_on_squelch = 0;
	}

	if (argc <= optind) {
		//usage();
		filename = "-";
	} else {
		filename = argv[optind];
	}

	buffer = malloc(lcm_post[fm.post_downsample] * DEFAULT_BUF_LENGTH * sizeof(uint8_t));

	device_count = rtlsdr_get_device_count();
	if (!device_count) {
		fprintf(stderr, "No supported devices found.\n");
		exit(1);
	}

	fprintf(stderr, "Found %d device(s):\n", device_count);
	for (i = 0; i < device_count; i++) {
		rtlsdr_get_device_usb_strings(i, vendor, product, serial);
		fprintf(stderr, "  %d:  %s, %s, SN: %s\n", i, vendor, product, serial);
	}
	fprintf(stderr, "\n");

	fprintf(stderr, "Using device %d: %s\n",
		dev_index, rtlsdr_get_device_name(dev_index));

	r = rtlsdr_open(&dev, dev_index);
	if (r < 0) {
		fprintf(stderr, "Failed to open rtlsdr device #%d.\n", dev_index);
		exit(1);
	}
#ifndef _WIN32
	sigact.sa_handler = sighandler;
	sigemptyset(&sigact.sa_mask);
	sigact.sa_flags = 0;
	sigaction(SIGINT, &sigact, NULL);
	sigaction(SIGTERM, &sigact, NULL);
	sigaction(SIGQUIT, &sigact, NULL);
	sigaction(SIGPIPE, &sigact, NULL);
#else
	SetConsoleCtrlHandler( (PHANDLER_ROUTINE) sighandler, TRUE );
#endif

	/* WBFM is special */
	if (wb_mode) {
		fm.freqs[0] += 16000;
	}


	optimal_settings(&fm, 0, 0);
	build_low_pass_complex(&fm);
	build_low_pass_real(&fm);

	/* Set the tuner gain */
	if (gain == AUTO_GAIN) {
		r = rtlsdr_set_tuner_gain_mode(dev, 0);
	} else {
		r = rtlsdr_set_tuner_gain_mode(dev, 1);
		r = rtlsdr_set_tuner_gain(dev, gain);
	}
	if (r != 0) {
		fprintf(stderr, "WARNING: Failed to set tuner gain.\n");
	} else if (gain == AUTO_GAIN) {
		fprintf(stderr, "Tuner gain set to automatic.\n");
	} else {
		fprintf(stderr, "Tuner gain set to %0.2f dB.\n", gain/10.0);
	}
	/* AGC */
	r = rtlsdr_set_agc_mode(dev, (agc) ? 1 : 0);
	if (r != 0) {
		fprintf(stderr, "WARNING: Failed to set tuner AGC.\n");
	} else if (agc) {
		fprintf(stderr, "Tuner AGC ON.\n");
	} else {
		fprintf(stderr, "Tuner AGC OFF.\n");
	}
	r = rtlsdr_set_freq_correction(dev, ppm_error);

	if (fm.deemph) {
		fprintf(stderr, "De-epmhasis IIR: %.1f us\n", fm.deemph * 1e6);
		fm.deemph_a = (int)lrint(1.0/((1.0-exp(-1.0/((double)fm.output_rate * fm.deemph)))));
	}

	if (strcmp(filename, "-") == 0) { /* Write samples to stdout */
		fm.file = stdout;
#ifdef _WIN32
		_setmode(_fileno(fm.file), _O_BINARY);
#endif
	} else {
		fm.file = fopen(filename, "wb");
		if (!fm.file) {
			fprintf(stderr, "Failed to open %s\n", filename);
			exit(1);
		}
	}

	/* Reset endpoint before we start reading from it (mandatory) */
	r = rtlsdr_reset_buffer(dev);
	if (r < 0) {
		fprintf(stderr, "WARNING: Failed to reset buffers.\n");}

	pthread_create(&demod_thread, NULL, demod_thread_fn, (void *)(&fm));
	rtlsdr_read_async(dev, rtlsdr_callback, (void *)(&fm),
			      DEFAULT_ASYNC_BUF_NUMBER,
			      lcm_post[fm.post_downsample] * DEFAULT_BUF_LENGTH);

	if (do_exit) {
		fprintf(stderr, "\nUser cancel, exiting...\n");}
	else {
		fprintf(stderr, "\nLibrary error %d, exiting...\n", r);}
	rtlsdr_cancel_async(dev);
	pthread_mutex_destroy(&data_ready);
	pthread_mutex_destroy(&data_write);

	if (fm.file != stdout) {
		fclose(fm.file);}

	rtlsdr_close(dev);
	free (buffer);
	return r >= 0 ? r : -r;
}
