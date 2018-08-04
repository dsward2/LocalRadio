/* FM stereo demuxer
 * Copyright (c) 2017 OH2EIQ. MIT license. */

#include <getopt.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <complex>

#include "../liquid_wrappers.h"

const int   kBuflen             = 1024;
const float kDefaultRate        = 171000.0f;
const float kPilotHz            = 19000.0f;
const float kPLLBandwidthHz     = 9.0f;
const float kPilotFIRHalfbandHz = 800.0f;
const float kAudioFIRCutoffHz   = 15000.0f;
const int   kDeEmphasisOrder    = 2;
const float kDeEmphasisCutoffHz = 5000.0f;
const float kStereoGain         = 2.0f;

struct StereoSample {
  int16_t l;
  int16_t r;
};

int main(int argc, char **argv) {
  float srate = kDefaultRate;

  int c;
  while ((c = getopt(argc, argv, "r:")) != -1)
    switch (c) {
      case 'r':
        srate = atof(optarg);
        break;
      case '?':
        fprintf(stderr, "Unknown option `-%c'.\n", optopt);
        fprintf(stderr, "usage: stereo -r <rate>\n");
        return EXIT_FAILURE;
      default:
        break;
    }

  if (srate < 106000.0f) {
    fprintf(stderr, "rate must be >= 106000\n");
    exit(EXIT_FAILURE);
  }

  int16_t inbuf[kBuflen];
  StereoSample outbuf[kBuflen];

  liquid::NCO nco_pilot_approx(kPilotHz * 2 * M_PI / srate);
  liquid::NCO nco_pilot_exact(kPilotHz * 2 * M_PI / srate);
  nco_pilot_exact.setPLLBandwidth(kPLLBandwidthHz / srate);
  liquid::NCO nco_stereo_subcarrier(2 * kPilotHz * 2 * M_PI / srate);
  liquid::FIRFilter fir_pilot(srate / 1350.0f, kPilotFIRHalfbandHz / srate);

  liquid::WDelay audio_delay(fir_pilot.getGroupDelayAt(100.0f / srate));

  liquid::FIRFilter fir_l_plus_r(srate / 1350.0f, kAudioFIRCutoffHz / srate);
  liquid::FIRFilter fir_l_minus_r(srate / 1350.0f, kAudioFIRCutoffHz / srate);

  unsigned int r = kDeEmphasisOrder % 2;     // odd/even order
  unsigned int L = (kDeEmphasisOrder-r)/2;   // filter semi-length

  float deemph_coeff_B[3*(L+r)];
  float deemph_coeff_A[3*(L+r)];

  liquid_iirdes(LIQUID_IIRDES_BUTTER, LIQUID_IIRDES_LOWPASS, LIQUID_IIRDES_SOS,
      kDeEmphasisOrder, kDeEmphasisCutoffHz / srate, 0.0f, 10.0f, 10.0f,
      deemph_coeff_B, deemph_coeff_A);
  iirfilt_crcf iir_deemph_l = iirfilt_crcf_create_sos(deemph_coeff_B,
      deemph_coeff_A, L+r);
  iirfilt_crcf iir_deemph_r = iirfilt_crcf_create_sos(deemph_coeff_B,
      deemph_coeff_A, L+r);

  int16_t dc_cancel_buffer[kBuflen] = {0};
  int dc_cancel_sum = 0;

  while (fread(&inbuf, sizeof(inbuf[0]), kBuflen, stdin)) {
    for (int n = 0; n < kBuflen; n++) {

      // Remove DC offset
      dc_cancel_sum -= dc_cancel_buffer[n];
      dc_cancel_buffer[n] = inbuf[n];
      dc_cancel_sum += dc_cancel_buffer[n];
      int16_t dc_cancel = dc_cancel_sum / kBuflen;
      std::complex<float> insample(1.0f*(inbuf[n] - dc_cancel), 0.0f);

      // Delay audio to match pilot filter delay
      audio_delay.push(insample);

      // Pilot bandpass (mix-down + lowpass + mix-up)
      fir_pilot.push(nco_pilot_approx.mixDown(insample));
      std::complex<float> pilot =
        nco_pilot_approx.mixUp(fir_pilot.execute());
      nco_pilot_approx.step();

      // Generate 38 kHz carrier
      nco_stereo_subcarrier.setPhase(2 * nco_pilot_exact.getPhase());

      // Pilot PLL
      float phase_error =
          std::arg(pilot * std::conj(nco_pilot_exact.getComplex()));
      nco_pilot_exact.stepPLL(phase_error);
      nco_pilot_exact.step();

      // Decode stereo
      fir_l_plus_r.push(audio_delay.read());
      fir_l_minus_r.push(nco_stereo_subcarrier.mixDown(audio_delay.read()));
      float l_plus_r  = fir_l_plus_r.execute().real();
      float l_minus_r = kStereoGain * fir_l_minus_r.execute().real();

      float left  = (l_plus_r + l_minus_r);
      float right = (l_plus_r - l_minus_r);

      // De-emphasis
      std::complex<float> l, r;
      iirfilt_crcf_execute(iir_deemph_l, std::complex<float>(left,  0.0f), &l);
      iirfilt_crcf_execute(iir_deemph_r, std::complex<float>(right, 0.0f), &r);

      outbuf[n].l = l.real();
      outbuf[n].r = r.real();
    }

    if (!fwrite(&outbuf, sizeof(outbuf[0]), kBuflen, stdout))
      return (EXIT_FAILURE);
    fflush(stdout);
  }
  iirfilt_crcf_destroy(iir_deemph_l);
  iirfilt_crcf_destroy(iir_deemph_r);
}
