#include "../Sources/CTDJAudioSource/TDJMainCompressor.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

#define CHUNK 256u

static void fill(float *l, float *r, float left, float right) {
    for (unsigned i = 0; i < CHUNK; ++i) {
        l[i] = left;
        r[i] = right;
    }
}

static void check_rate(double rate) {
    tdj_main_compressor s;
    float l[CHUNK], r[CHUNK];
    tdj_main_compressor_init(&s, rate, true);
    fill(l, r, 0.08f, -0.04f);
    tdj_main_compressor_process(&s, l, r, CHUNK, true);
    for (unsigned i = 0; i < CHUNK; ++i)
        assert(l[i] == 0.08f && r[i] == -0.04f);
    fill(l, r, 0.60f, -0.30f);
    tdj_main_compressor_process(&s, l, r, CHUNK, true);
    assert(l[0] > 0.599f);
    assert(l[CHUNK - 1] < l[0] && l[CHUNK - 1] > 0.45f);
    unsigned settle = (unsigned)ceil(rate * 0.25 / CHUNK);
    for (unsigned n = 0; n < settle; ++n) {
        fill(l, r, 0.60f, -0.30f);
        tdj_main_compressor_process(&s, l, r, CHUNK, true);
        for (unsigned i = 0; i < CHUNK; ++i)
            assert(r[i] * 2 == -l[i]);
    }
    assert(fabsf(l[CHUNK - 1] - 0.4689f) < 0.0005f);

    fill(l, r, 4.0f, -2.0f);
    tdj_main_compressor_process(&s, l, r, CHUNK, true);
    for (unsigned i = 0; i < CHUNK; ++i)
        assert(l[i] < 0.981f && r[i] * 2 == -l[i]);

    tdj_main_compressor_init(&s, rate, true);
    for (unsigned n = 0; n < settle; ++n) {
        fill(l, r, 0.60f, -0.30f);
        tdj_main_compressor_process(&s, l, r, CHUNK, true);
    }
    fill(l, r, 0.60f, -0.30f);
    tdj_main_compressor_process(&s, l, r, CHUNK, false);
    assert(l[0] < 0.470f && l[CHUNK - 1] > l[0]);
    unsigned ramp = (unsigned)ceil(rate * 0.030 / CHUNK);
    for (unsigned n = 0; n < ramp; ++n) {
        fill(l, r, 0.60f, -0.30f);
        tdj_main_compressor_process(&s, l, r, CHUNK, false);
    }
    assert(s.blend == 0 && s.gain == 1);
    float bypass_left[CHUNK], bypass_right[CHUNK];
    fill(bypass_left, bypass_right, 1.23f, -0.67f);
    memcpy(l, bypass_left, sizeof(l));
    memcpy(r, bypass_right, sizeof(r));
    tdj_main_compressor_process(&s, l, r, CHUNK, false);
    assert(memcmp(l, bypass_left, sizeof(l)) == 0);
    assert(memcmp(r, bypass_right, sizeof(r)) == 0);
    printf("PASS %.0f Hz quiet, attack, stereo, overload, bypass\n", rate);
}

int main(void) {
    check_rate(44100);
    check_rate(48000);
    check_rate(96000);
    return 0;
}
