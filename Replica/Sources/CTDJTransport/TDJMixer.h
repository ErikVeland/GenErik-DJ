#ifndef TDJ_MIXER_INTERNAL_H
#define TDJ_MIXER_INTERNAL_H
#include <math.h>
#include <string.h>

// Development response curves. NI's gain laws and filter sound remain unmeasured.
typedef struct {
    double value, target, step;
    unsigned remaining;
} ramp;
static void ramp_set(ramp *r, double target, unsigned samples) {
    r->target = target;
    r->remaining = samples;
    r->step = samples ? (target - r->value) / samples : 0;
    if (!samples)
        r->value = target;
}
static double ramp_next(ramp *r) {
    if (r->remaining && !--r->remaining)
        r->value = r->target;
    else if (r->remaining)
        r->value += r->step;
    return r->value;
}
// Trapezoidal state-variable filter. Parameter ramps preserve stability during cutoff sweeps.
// Mathematical derivation: Andrew Simper, SvfLinearTrapOptimised2 (Cytomic).
typedef struct {
    ramp frequency, damping, highpass;
    double integrator1[2], integrator2[2], a1, a2, a3, k, hp;
} state_filter;
static void filter_parameters(state_filter *f, double rate, double position, double resonance, unsigned smoothing) {
    double limit = fmin(20000, rate * 0.45);
    double frequency = 20 * pow(limit / 20, position < 0 ? 1 + position : position);
    ramp_set(&f->frequency, tan(M_PI * frequency / rate), smoothing);
    ramp_set(&f->damping, 1 / (0.70710678 + resonance * 7.29289322), smoothing);
    ramp_set(&f->highpass, position < 0 ? 0 : 1, smoothing);
}
static void filter_step(state_filter *f) {
    double g = ramp_next(&f->frequency);
    f->k = ramp_next(&f->damping);
    f->hp = ramp_next(&f->highpass);
    f->a1 = 1 / (1 + g * (g + f->k));
    f->a2 = g * f->a1;
    f->a3 = g * f->a2;
}
static double filter_sample_state(const state_filter *f, double x, double *first, double *second) {
    double difference = x - *second;
    double band = f->a1 * *first + f->a2 * difference;
    double low = *second + f->a2 * *first + f->a3 * difference;
    *first = 2 * band - *first;
    *second = 2 * low - *second;
    if (fabs(*first) < 1e-25)
        *first = 0;
    if (fabs(*second) < 1e-25)
        *second = 0;
    return low + (x - f->k * band - 2 * low) * f->hp;
}

static double filter_sample(state_filter *f, double x, int channel) {
    return filter_sample_state(f, x, &f->integrator1[channel], &f->integrator2[channel]);
}
typedef struct {
    double low[2], high[2], integrator1[2], integrator2[2];
} mixer_bypass;
typedef struct {
    ramp volume, gain, low, mid, high, cue, filter_wet, crossfader_assignment;
    double filter_x, filter_y, low_state[2], high_state[2];
    bool filter_enabled;
    state_filter filter;
    mixer_bypass bypass;
    double peak;
} mixer_deck;
typedef struct {
    mixer_deck decks[TDJ_DECK_COUNT];
    ramp crossfader, master, monitor, cue_mix;
    double low_coefficient, high_coefficient;
    unsigned smoothing;
} mixer;
static void mixer_init(mixer *m, double rate, double gain) {
    m->smoothing = (unsigned)fmax(1, rate * 0.005);
    m->low_coefficient = 1 - exp(-2 * M_PI * 250 / rate);
    m->high_coefficient = 1 - exp(-2 * M_PI * 2500 / rate);
    ramp_set(&m->crossfader, 0.5, 0);
    ramp_set(&m->master, gain, 0);
    ramp_set(&m->monitor, 0.5, 0);
    ramp_set(&m->cue_mix, 0, 0);
    for (int i = 0; i < TDJ_DECK_COUNT; ++i) {
        mixer_deck *d = &m->decks[i];
        ramp_set(&d->volume, i < 2 ? 1 : 0, 0);
        ramp_set(&d->gain, 1, 0);
        ramp_set(&d->crossfader_assignment, (i & 1) == 0 ? -1 : 1, 0);
        ramp_set(&d->low, 1, 0);
        ramp_set(&d->mid, 1, 0);
        ramp_set(&d->high, 1, 0);
        filter_parameters(&d->filter, rate, 0, 0, 0);
    }
}
static void mixer_clear_track(mixer_deck *d) {
    memset(d->low_state, 0, sizeof(d->low_state));
    memset(d->high_state, 0, sizeof(d->high_state));
    memset(d->filter.integrator1, 0, sizeof(d->filter.integrator1));
    memset(d->filter.integrator2, 0, sizeof(d->filter.integrator2));
    d->bypass = (mixer_bypass){0};
}
static void mixer_process_split(mixer *m, int index, double *l, double *r, double *dry) {
    mixer_deck *d = &m->decks[index];
    double gain = ramp_next(&d->gain), low = ramp_next(&d->low), mid = ramp_next(&d->mid), high = ramp_next(&d->high);
    double wet = ramp_next(&d->filter_wet);
    double samples[2] = {*l * gain, *r * gain};
    filter_step(&d->filter);
    for (int ch = 0; ch < 2; ++ch) {
        double x = samples[ch];
        d->low_state[ch] += m->low_coefficient * (x - d->low_state[ch]);
        d->high_state[ch] += m->high_coefficient * (x - d->high_state[ch]);
        // Complementary bands sum to the exact dry signal at neutral settings.
        x += (low - 1) * d->low_state[ch] + (mid - 1) * (d->high_state[ch] - d->low_state[ch]) +
             (high - 1) * (x - d->high_state[ch]);
        double filtered = filter_sample(&d->filter, x, ch);
        samples[ch] = x + (filtered - x) * wet;
        if (dry) {
            mixer_bypass *b = &d->bypass;
            double y = dry[ch] * gain;
            b->low[ch] += m->low_coefficient * (y - b->low[ch]);
            b->high[ch] += m->high_coefficient * (y - b->high[ch]);
            y += (low - 1) * b->low[ch] + (mid - 1) * (b->high[ch] - b->low[ch]) +
                 (high - 1) * (y - b->high[ch]);
            double filtered_dry = filter_sample_state(&d->filter, y, &b->integrator1[ch], &b->integrator2[ch]);
            dry[ch] = y + (filtered_dry - y) * wet;
        }
    }
    *l = samples[0];
    *r = samples[1];
    d->peak = fmax(d->peak, fmax(fabs(*l), fabs(*r)));
}

static void mixer_process_deck(mixer *m, int index, double *l, double *r) {
    mixer_process_split(m, index, l, r, NULL);
}

static inline double mixer_crossfader_gain(mixer_deck *d, double cross) {
    double assignment = ramp_next(&d->crossfader_assignment);
    double attenuation = assignment < 0 ? fmax(0, 2 * cross - 1) : fmax(0, 1 - 2 * cross);
    return 1 - fabs(assignment) * attenuation;
}
#endif
