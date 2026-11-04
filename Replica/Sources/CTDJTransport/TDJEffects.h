#ifndef TDJ_EFFECTS_H
#define TDJ_EFFECTS_H
#include "TDJReverb.h"
// Independent processors; parameter laws do not reproduce proprietary NI algorithms.
typedef struct {
    float *buffer;
    unsigned capacity, cursor, written;
    int kind, cached_kind;
    bool enabled, free_delay, cached_free_delay;
    double x, y, phase;
    double cached_x, cached_bpm, frames_per_beat, gate_multiplier;
    unsigned distance;
    unsigned smoothing, transition;
    double previous[2], transition_from[2];
    ramp wet;
    stereo_reverb reverb;
    ramp reverb_feed, reverb_return;
    unsigned reverb_tail_frames, reverb_tail_limit, reverb_tail_fade;
    bool reverb_was_enabled, reverb_tail_active;
    unsigned tap_distance, tap_next, tap_fade, tap_length;
    double gate_envelope;
    state_filter filter;
    unsigned hold_frames, hold_remaining;
    double quantization, held[2];
    bool dormant;
    unsigned grain_frames, grain_written, capture_frames, captured;
    double grain_ratio, grain_phase, capture_position;
    bool capture_ready;
    // Grid-locked state. division is in beats; slices and reverse captures record while bypassed.
    double division, slice_beat, last_line;
    int slice_state;
    unsigned slice_start, idle_write, idle_filled;
} performance_fx;
static bool fx_init(performance_fx *f, double rate) {
    f->capacity = (unsigned)ceil(rate * 8) + 2;
    size_t bytes = (size_t)f->capacity * 2 * sizeof(float);
    f->buffer = calloc(1, bytes);
    if (!f->buffer)
        return false;
    // Fault writable pages on the allocating thread, not at first FX engagement.
    volatile unsigned char *pages = (volatile unsigned char *)f->buffer;
    for (size_t offset = 0; offset < bytes; offset += 4096)
        pages[offset] = 0;
    pages[bytes - 1] = 0;
    f->x = 0.5;
    f->y = 0.5;
    f->cached_x = NAN;
    f->cached_bpm = NAN;
    f->cached_kind = -1;
    if (!reverb_init(&f->reverb, rate)) {
        free(f->buffer);
        f->buffer = NULL;
        return false;
    }
    f->smoothing = (unsigned)fmax(1, rate * 0.005);
    f->reverb_tail_fade = (unsigned)fmax(1, rate * 0.020);
    f->tap_length = (unsigned)fmax(2, rate * 0.025);
    filter_parameters(&f->filter, rate, 0, 0, 0);
    f->dormant = true;
    return true;
}
static void fx_destroy(performance_fx *f) {
    free(f->buffer);
    free(f->reverb.storage);
}
static void fx_transition(performance_fx *f) {
    if (f->wet.value <= 0 && !(f->reverb_tail_active && f->reverb_return.value > 0))
        return;
    f->transition = f->smoothing;
    f->transition_from[0] = f->previous[0];
    f->transition_from[1] = f->previous[1];
}
static void fx_finish_output(performance_fx *f, double *l, double *r) {
    if (f->transition) {
        double previous_weight = (double)(f->transition - 1) / f->smoothing;
        *l += (f->transition_from[0] - *l) * previous_weight;
        *r += (f->transition_from[1] - *r) * previous_weight;
        f->transition--;
    }
    f->previous[0] = *l;
    f->previous[1] = *r;
}
static void fx_clear_processing_state(performance_fx *f) {
    memset(f->filter.integrator1, 0, sizeof(f->filter.integrator1));
    memset(f->filter.integrator2, 0, sizeof(f->filter.integrator2));
    f->hold_remaining = 0;
    f->dormant = true;
    f->held[0] = f->held[1] = 0;
    f->tap_distance = f->tap_next = f->tap_fade = 0;
    f->gate_envelope = 0;
    reverb_reset(&f->reverb);
    ramp_set(&f->reverb_feed, 0, 0);
    ramp_set(&f->reverb_return, 0, 0);
    f->reverb_tail_frames = 0;
    f->reverb_was_enabled = false;
    f->reverb_tail_active = false;
    f->grain_written = 0;
    f->grain_phase = 0;
    f->captured = 0;
    f->capture_frames = 0;
    f->capture_position = 0;
    f->capture_ready = false;
    f->cursor = 0;
    f->written = 0;
    f->slice_state = 0;
    f->idle_write = 0;
    f->idle_filled = 0;
}
static void fx_reset(performance_fx *f) {
    // Constant-time invalidation. Reads remain silent until their delay history exists.
    // Stale samples are overwritten incrementally as the ring advances.
    fx_transition(f);
    f->cursor = 0;
    f->written = 0;
    fx_clear_processing_state(f);
}
static void fx_prepare(performance_fx *f, double rate, double bpm) {
    if (f->cached_x == f->x && f->cached_bpm == bpm && f->cached_kind == f->kind &&
        f->cached_free_delay == f->free_delay)
        return;
    double previous_x = f->cached_x;
    int previous_kind = f->cached_kind;
    f->cached_x = f->x;
    f->cached_bpm = bpm;
    f->cached_kind = f->kind;
    f->cached_free_delay = f->free_delay;
    if (f->kind == TDJ_EFFECT_REVERB || f->kind == TDJ_EFFECT_ICEVERB) {
        if (previous_x != f->x || previous_kind != f->kind) {
            reverb_prepare(&f->reverb, f->x, f->kind == TDJ_EFFECT_ICEVERB, (unsigned)fmax(1, rate * 0.04));
            f->reverb_tail_limit = (unsigned)ceil(rate * fmin(30, 1.5 * f->reverb.decay_seconds + 0.12));
        }
        return;
    }
    f->frames_per_beat = rate * 60 / fmax(30, bpm);
    f->gate_multiplier = exp2(round(f->x * 4));
    // Flanger: 1-16 beat sweeps. Gater: 1/32-1/2 beat. Beatmasher: 1/8-1 beat slices.
    f->division = f->kind == TDJ_EFFECT_FLANGER      ? f->gate_multiplier
                  : f->kind == TDJ_EFFECT_GATER      ? exp2(round(f->x * 4) - 5)
                  : f->kind == TDJ_EFFECT_BEATMASHER ? exp2(round(f->x * 3) - 3)
                                                     : 1;
    double delay = f->kind == TDJ_EFFECT_DELAY && f->free_delay ? rate * 0.025 * pow(80, f->x)
                   : f->kind == TDJ_EFFECT_BEATMASHER           ? f->frames_per_beat * f->division
                                                                : f->frames_per_beat * f->gate_multiplier * 0.25;
    unsigned distance = (unsigned)fmax(1, fmin(f->capacity - 1, delay));
    if (distance != f->distance && f->kind == TDJ_EFFECT_BEATMASHER && f->slice_state) {
        f->slice_state = 1;
        f->last_line = NAN;
        fx_transition(f);
    }
    f->distance = distance;
    if (f->kind == TDJ_EFFECT_DIGITAL_LOFI) {
        f->hold_frames = (unsigned)fmax(1, round(pow(fmax(1, rate / 100), f->x)));
        f->quantization = exp2(23 - 22 * f->x);
        if (previous_x != f->x) {
            f->hold_remaining = 0;
            fx_transition(f);
        }
    } else if (f->kind == TDJ_EFFECT_HIGH_PASS || f->kind == TDJ_EFFECT_LOW_PASS) {
        double position = f->kind == TDJ_EFFECT_HIGH_PASS ? f->x : -fmax(1e-9, 1 - f->x);
        filter_parameters(&f->filter, rate, position, 0, f->smoothing);
    } else if (f->kind == TDJ_EFFECT_TRANSPOSE_STRETCH) {
        double semitones = (f->x - 0.5) * (f->x <= 0.5 ? 120 : 24);
        f->grain_ratio = exp2(semitones / 12);
        f->grain_frames = (unsigned)fmax(2, fmin(f->capacity - 4, fmax(32, rate * 0.08)));
        if (previous_x != f->x)
            fx_transition(f);
    } else if (f->kind == TDJ_EFFECT_REVERSE_GRAIN) {
        f->grain_frames = (unsigned)fmax(2, fmin(f->capacity - 1, rate * 0.005 * pow(64, f->x)));
        if (previous_x != f->x) {
            f->grain_phase = fmod(f->grain_phase, f->grain_frames);
            fx_transition(f);
        }
    }
}
#include "TDJDlcEffects.h"
// Slices and reverse captures keep recording while bypassed, so engagement never repeats silence.
static void fx_record_bypassed(performance_fx *f, double l, double r) {
    double dry[2] = {l, r};
    if (f->kind == TDJ_EFFECT_REVERSE_GRAIN)
        fx_reverse_record(f, dry);
    else if (f->kind == TDJ_EFFECT_BEATMASHER) {
        f->buffer[2 * f->cursor] = (float)l;
        f->buffer[2 * f->cursor + 1] = (float)r;
        f->cursor = (f->cursor + 1) % f->capacity;
        if (f->written < f->capacity)
            f->written++;
    }
}
static double fx_slice_read(const performance_fx *f, double position, int channel) {
    unsigned length = f->capture_frames, at = (unsigned)position;
    if (at >= length)
        at = length - 1;
    unsigned next = at + 1 < length ? at + 1 : 0;
    double t = position - at;
    double a = f->buffer[2 * ((f->slice_start + at) % f->capacity) + channel];
    double b = f->buffer[2 * ((f->slice_start + next) % f->capacity) + channel];
    return a + (b - a) * t;
}
static void fx_process_reverb(performance_fx *f, double *l, double *r) {
    double previous_wet = f->wet.value;
    if (f->enabled != f->reverb_was_enabled) {
        if (f->enabled) {
            if (f->reverb_tail_active) {
                ramp_set(&f->wet, f->reverb_return.value, 0);
                ramp_set(&f->wet, f->y, f->smoothing);
            }
            f->reverb_tail_active = false;
            f->reverb_tail_frames = 0;
            ramp_set(&f->reverb_feed, 1, f->smoothing);
        } else {
            ramp_set(&f->reverb_feed, 0, f->smoothing);
            if (previous_wet > 0 && f->y > 0) {
                ramp_set(&f->reverb_return, previous_wet, 0);
                f->reverb_tail_frames = f->reverb_tail_limit;
                f->reverb_tail_active = f->reverb_tail_frames > 0;
            }
        }
        f->reverb_was_enabled = f->enabled;
    }
    double wet = ramp_next(&f->wet);
    if (!f->enabled && wet == 0 && !f->reverb_tail_active) {
        if (!f->dormant)
            fx_clear_processing_state(f);
        fx_finish_output(f, l, r);
        return;
    }
    f->dormant = false;
    double amount = wet;
    if (f->reverb_tail_active) {
        if (f->y <= 0 && f->reverb_return.target > 0) {
            ramp_set(&f->reverb_return, 0, f->smoothing);
        } else if (f->reverb_tail_frames <= f->reverb_tail_fade && f->reverb_return.target > 0) {
            ramp_set(&f->reverb_return, 0, f->reverb_tail_frames);
        }
        amount = ramp_next(&f->reverb_return);
    }
    double feed = ramp_next(&f->reverb_feed);
    double input[2] = {*l * feed, *r * feed}, reverberated[2];
    reverb_process(&f->reverb, input, reverberated);
    *l += amount * reverberated[0];
    *r += amount * reverberated[1];
    fx_finish_output(f, l, r);
    if (f->reverb_tail_active) {
        if (f->reverb_tail_frames)
            f->reverb_tail_frames--;
        if (!f->reverb_tail_frames || f->reverb_return.value == 0) {
            fx_clear_processing_state(f);
        }
    }
}

// beat and bpm belong to the deck's grid; synced decks pass the master clock.
static void fx_process(performance_fx *f, double rate, double bpm, double beat, double *l, double *r) {
    if (f->kind == TDJ_EFFECT_REVERB || f->kind == TDJ_EFFECT_ICEVERB) {
        fx_process_reverb(f, l, r);
        return;
    }
    (void)bpm;
    double wet = ramp_next(&f->wet);
    if (!f->enabled && wet == 0) {
        if (!f->dormant)
            fx_clear_processing_state(f);
        fx_record_bypassed(f, *l, *r);
        fx_finish_output(f, l, r);
        return;
    }
    f->dormant = false;
    double samples[2] = {*l, *r};
    double dlc[2] = {0, 0};
    if (f->kind >= TDJ_EFFECT_ICEVERB)
        fx_dlc_process(f, rate, samples, dlc);
    unsigned distance = f->distance;
    if (f->kind == TDJ_EFFECT_DELAY) {
        if (!f->tap_distance)
            f->tap_distance = distance;
        if (!f->tap_fade && f->tap_distance != distance) {
            f->tap_next = distance;
            f->tap_fade = f->tap_length;
        }
    }
    double cycle = beat / f->division, phase = cycle - floor(cycle);
    if (f->kind == TDJ_EFFECT_GATER) {
        // Open for the first half of each grid division, with 64-sample edges.
        double gate = phase < 0.5 ? 1 : 0;
        f->gate_envelope += fmax(-1.0 / 64, fmin(1.0 / 64, gate - f->gate_envelope));
    }
    double flanger_back = 0;
    if (f->kind == TDJ_EFFECT_FLANGER)
        flanger_back = fmin(f->capacity - 3, fmax(3, (13 + 296 * (0.5 - 0.5 * cos(2 * M_PI * phase))) * rate / 44100));
    double slice_position = 0;
    if (f->kind == TDJ_EFFECT_BEATMASHER) {
        double line = floor(cycle);
        if (!f->slice_state || (f->slice_state == 1 && !isfinite(f->last_line))) {
            f->slice_state = 1;
            f->last_line = line;
        } else if (f->slice_state == 1 && line != f->last_line) {
            // Record the slice that starts on this grid line while live audio passes.
            f->slice_state = 2;
            f->slice_start = f->cursor;
            f->slice_beat = line * f->division;
            f->captured = 0;
            f->capture_frames = distance;
        }
        if (f->slice_state == 3) {
            double offset = beat - f->slice_beat, span = f->division;
            slice_position = (offset - floor(offset / span) * span) * f->frames_per_beat;
            if (slice_position >= f->capture_frames)
                slice_position = f->capture_frames - 1;
        }
    }
    if (f->kind == TDJ_EFFECT_DIGITAL_LOFI && !f->hold_remaining) {
        for (int ch = 0; ch < 2; ch++)
            f->held[ch] = round(samples[ch] * f->quantization) / f->quantization;
        f->hold_remaining = f->hold_frames;
    }
    if (f->kind == TDJ_EFFECT_HIGH_PASS || f->kind == TDJ_EFFECT_LOW_PASS)
        filter_step(&f->filter);
    for (int ch = 0; ch < 2; ch++) {
        double dry = samples[ch], past = 0, effect = 0, added = 0;
        bool additive = false;
        if (f->kind == TDJ_EFFECT_DELAY) {
            unsigned old_read = (f->cursor + f->capacity - f->tap_distance) % f->capacity;
            past = f->written >= f->tap_distance ? f->buffer[2 * old_read + ch] : 0;
            if (f->tap_fade) {
                unsigned next_read = (f->cursor + f->capacity - f->tap_next) % f->capacity;
                double next = f->written >= f->tap_next ? f->buffer[2 * next_read + ch] : 0;
                double t = 1 - (double)f->tap_fade / f->tap_length;
                t = t * t * (3 - 2 * t);
                past += (next - past) * t;
            }
            additive = true;
            added = past * 0.6;
            f->buffer[2 * f->cursor + ch] = (float)(dry + past * 0.5);
        } else if (f->kind == TDJ_EFFECT_FLANGER) {
            past = f->written >= (unsigned)ceil(flanger_back) + 2 ? fx_dlc_delay(f, flanger_back, ch) : 0;
            additive = true;
            added = past * 0.6;
            f->buffer[2 * f->cursor + ch] = (float)(dry + past * 0.7);
        } else if (f->kind == TDJ_EFFECT_GATER)
            effect = dry * f->gate_envelope;
        else if (f->kind == TDJ_EFFECT_BEATMASHER) {
            if (f->slice_state != 3) {
                f->buffer[2 * f->cursor + ch] = (float)dry;
                f->held[ch] = dry;
                effect = dry;
            } else {
                effect = fx_slice_read(f, slice_position, ch);
                unsigned edge = (unsigned)fmax(2, fmin(rate * 0.003, f->capture_frames * 0.125));
                if (slice_position < edge) {
                    double weight = slice_position / edge;
                    weight = weight * weight * (3 - 2 * weight);
                    effect = f->held[ch] * (1 - weight) + effect * weight;
                }
                f->held[ch] = effect;
            }
        } else if (f->kind == TDJ_EFFECT_DIGITAL_LOFI)
            effect = f->held[ch];
        else if (f->kind == TDJ_EFFECT_HIGH_PASS || f->kind == TDJ_EFFECT_LOW_PASS)
            effect = filter_sample(&f->filter, dry, ch);
        else if (f->kind >= TDJ_EFFECT_ICEVERB)
            effect = dlc[ch];
        // Echo and space effects add to an untouched dry track. Insert effects replace it by Y.
        samples[ch] = additive ? dry + added * wet : dry + (effect - dry) * wet;
    }
    *l = samples[0];
    *r = samples[1];
    fx_finish_output(f, l, r);
    if (f->tap_fade && !--f->tap_fade)
        f->tap_distance = f->tap_next;
    if (f->kind == TDJ_EFFECT_BEATMASHER && f->slice_state == 2 && ++f->captured >= f->capture_frames) {
        f->slice_state = 3;
        fx_transition(f);
    }
    if (f->kind == TDJ_EFFECT_DIGITAL_LOFI && f->hold_remaining)
        f->hold_remaining--;
    if (f->kind == TDJ_EFFECT_BEATMASHER && f->slice_state == 3)
        return;
    f->cursor = (f->cursor + 1) % f->capacity;
    if (f->written < f->capacity)
        f->written++;
}
#endif
