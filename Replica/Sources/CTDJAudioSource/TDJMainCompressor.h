#ifndef TDJ_MAIN_COMPRESSOR_H
#define TDJ_MAIN_COMPRESSOR_H

#include <math.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float gain, blend, attack, release, blend_step;
} tdj_main_compressor;

static inline void tdj_main_compressor_init(tdj_main_compressor *s, double rate, bool enabled) {
    s->gain = 1.0f;
    s->blend = enabled ? 1.0f : 0.0f;
    s->attack = (float)(1.0 - exp(-1.0 / (rate * 0.008)));
    s->release = (float)(1.0 - exp(-1.0 / (rate * 0.140)));
    s->blend_step = (float)(1.0 / (rate * 0.025));
}

/* A soft knee starts near -18 dBFS. The gain does not increase. */
static inline void tdj_main_compressor_process(
    tdj_main_compressor *s, float *left, float *right, uint32_t count, bool enabled) {
    if (!enabled && s->blend <= 0) {
        s->gain = 1.0f;
        return;
    }
    for (uint32_t i = 0; i < count; ++i) {
        float l = left[i], r = right[i];
        if (!isfinite(l) || !isfinite(r)) {
            left[i] = right[i] = 0;
            continue;
        }
        float abs_l = fabsf(l), abs_r = fabsf(r);
        float peak = abs_l > abs_r ? abs_l : abs_r;
        float requested = 1.0f;
        if (peak > 0.126f) {
            float excess = peak - 0.126f;
            float compressed = peak < 0.200f ? excess * excess / 0.148f : peak - 0.163f;
            requested -= (0.30f * compressed) / peak;
        }
        s->gain += (requested - s->gain) * (requested < s->gain ? s->attack : s->release);
        if (enabled) {
            s->blend += s->blend_step;
            if (s->blend > 1.0f) s->blend = 1.0f;
        } else {
            s->blend -= s->blend_step;
            if (s->blend <= 0) {
                s->blend = 0;
                s->gain = 1.0f;
                break;
            }
        }
        float gain = s->gain;
        if (peak * gain > 0.98f)
            gain = 0.98f / peak;
        float effective = 1.0f + (gain - 1.0f) * s->blend;
        left[i] = l * effective;
        right[i] = r * effective;
    }
}

#endif
