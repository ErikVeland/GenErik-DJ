#ifndef TDJ_BASS_ASSIST_INTERNAL_H
#define TDJ_BASS_ASSIST_INTERNAL_H

typedef struct {
    double low[2][2], power[2][2], full_power[2], covariance;
    double coefficient, envelope, applied[2];
    ramp gain[2];
    uint64_t generation[2];
    unsigned interval, until_update, settled, settling, attack, release;
    int mode, leader;
    bool running, available;
} bass_assist;

/**
 * Prepares fixed-cost stereo analysis and bounded bass gain ramps.
 */
static void bass_assist_init(bass_assist *b, double rate) {
    b->coefficient = 1 - exp(-2 * M_PI * 120 / rate);
    b->envelope = 1 - exp(-1 / (rate * 0.05));
    b->interval = (unsigned)fmax(1, rate * 0.01);
    b->settling = (unsigned)fmax(1, rate * 0.1);
    b->attack = (unsigned)fmax(1, rate * 0.12);
    b->release = (unsigned)fmax(1, rate * 0.25);
    b->leader = -1;
    ramp_set(&b->gain[0], 1, 0);
    ramp_set(&b->gain[1], 1, 0);
    b->applied[0] = b->applied[1] = 1;
}

/**
 * Changes targets without restarting a ramp whose target is unchanged.
 */
static void bass_assist_target(bass_assist *b, unsigned index, double value) {
    ramp *g = &b->gain[index];
    if (fabs(value - g->target) > 1e-6 || (value == 1 && g->target != 1))
        ramp_set(g, value, value < g->value ? b->attack : b->release);
}

/**
 * Releases assistance when the deck pair cannot support a handover.
 */
static void bass_assist_suspend(bass_assist *b) {
    b->available = false;
    b->settled = 0;
    b->leader = -1;
    b->until_update = 0;
    bass_assist_target(b, 0, 1);
    bass_assist_target(b, 1, 1);
}

/**
 * Invalidates source-specific evidence while keeping the audio filter continuous.
 */
static bool bass_assist_begin(bass_assist *b, int mode, uint64_t a, uint64_t c) {
    bool changed = b->generation[0] != a || b->generation[1] != c;
    if (changed || !b->running) {
        memset(b->power, 0, sizeof(b->power));
        memset(b->full_power, 0, sizeof(b->full_power));
        b->covariance = 0;
        b->settled = 0;
        b->available = false;
        b->leader = -1;
        b->until_update = 0;
        b->generation[0] = a;
        b->generation[1] = c;
    }
    b->mode = mode;
    if (changed || mode != TDJ_BASS_HANDOVER) {
        bass_assist_target(b, 0, 1);
        bass_assist_target(b, 1, 1);
    }
    b->running = mode != TDJ_BASS_OFF || b->gain[0].remaining || b->gain[1].remaining;
    return b->running;
}

/**
 * Measures corresponding stereo channels and returns only the master-bus correction.
 */
static bool bass_assist_sample(bass_assist *b, const double samples[2][2], const double levels[2], bool pair,
                               double cross, int preferred, double *left, double *right) {
    double product = 0;
    double full[2] = {0, 0};
    double low[2][2];
    pair = pair && levels[0] > 1e-5 && levels[1] > 1e-5;
    for (unsigned ch = 0; ch < 2; ++ch) {
        for (unsigned i = 0; i < 2; ++i) {
            double x = samples[i][ch];
            if (!isfinite(x))
                x = 0;
            full[i] += x * x * levels[i] * levels[i];
            b->low[i][ch] += b->coefficient * (x - b->low[i][ch]);
            if (fabs(b->low[i][ch]) < 1e-25)
                b->low[i][ch] = 0;
            low[i][ch] = b->low[i][ch] * levels[i];
            double energy = low[i][ch] * low[i][ch];
            b->power[i][ch] += b->envelope * (energy - b->power[i][ch]);
        }
        product += low[0][ch] * low[1][ch];
    }
    for (unsigned i = 0; i < 2; ++i)
        b->full_power[i] += b->envelope * (full[i] - b->full_power[i]);
    b->covariance += b->envelope * (product - b->covariance);
    if (!pair) {
        b->settled = 0;
        b->available = false;
        b->leader = -1;
    } else if (b->settled < b->settling)
        b->settled++;
    if (!b->until_update--) {
        b->until_update = b->interval - 1;
        double a = b->power[0][0] + b->power[0][1], c = b->power[1][0] + b->power[1][1];
        double overlap = fmin(b->power[0][0], b->power[1][0]) + fmin(b->power[0][1], b->power[1][1]);
        b->available = pair && b->settled >= b->settling && a > 1e-6 && c > 1e-6 && overlap > 1e-6 &&
                       overlap > 0.01 * fmax(a, c) && a > 0.03 * b->full_power[0] && c > 0.03 * b->full_power[1];
        double targets[2] = {1, 1};
        if (b->available && b->mode == TDJ_BASS_HANDOVER) {
            if (cross < 0.45)
                b->leader = 0;
            else if (cross > 0.55)
                b->leader = 1;
            else if (b->leader < 0)
                b->leader = preferred;
            double depth = fmin(1, 4 * overlap / fmax(a, c));
            targets[1 - b->leader] = 1 - (1 - 0.251188643150958) * depth;
        }
        bass_assist_target(b, 0, targets[0]);
        bass_assist_target(b, 1, targets[1]);
    }
    double maximum = fmax(levels[0], levels[1]);
    double weight = maximum > 0 ? fmin(1, 4 * fmin(levels[0], levels[1]) / maximum) : 0;
    double a = (ramp_next(&b->gain[0]) - 1) * weight, c = (ramp_next(&b->gain[1]) - 1) * weight;
    b->applied[0] = 1 + a;
    b->applied[1] = 1 + c;
    *left = a * low[0][0] + c * low[1][0];
    *right = a * low[0][1] + c * low[1][1];
    if (b->mode == TDJ_BASS_OFF && !b->gain[0].remaining && !b->gain[1].remaining) {
        b->running = false;
        b->available = false;
        memset(b->low, 0, sizeof(b->low));
    }
    return a != 0 || c != 0;
}

#endif
