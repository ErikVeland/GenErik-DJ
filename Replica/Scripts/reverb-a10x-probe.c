#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <time.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846264338327950288
#endif
#include "TDJTransport.h"
#include "TDJMixer.h"

static unsigned audit_phase;
static uint64_t rt_allocations, rt_deallocations, render_expensive_math;
static size_t largest_rt_clear;

#ifdef AUDIT_OPERATIONS
static void *audit_malloc(size_t size) {
    if (audit_phase) rt_allocations++;
    return malloc(size);
}
static void *audit_calloc(size_t count, size_t size) {
    if (audit_phase) rt_allocations++;
    return calloc(count, size);
}
static void *audit_realloc(void *pointer, size_t size) {
    if (audit_phase) rt_allocations++;
    return realloc(pointer, size);
}
static void audit_free(void *pointer) {
    if (audit_phase && pointer) rt_deallocations++;
    free(pointer);
}
static void *audit_memset(void *pointer, int value, size_t size) {
    if (audit_phase && size > largest_rt_clear) largest_rt_clear = size;
    return memset(pointer, value, size);
}
static double audit_sqrt(double x) {
    if (audit_phase == 2) render_expensive_math++;
    return sqrt(x);
}
static double audit_pow(double x, double y) {
    if (audit_phase == 2) render_expensive_math++;
    return pow(x, y);
}
static double audit_exp(double x) {
    if (audit_phase == 2) render_expensive_math++;
    return exp(x);
}
static double audit_exp2(double x) {
    if (audit_phase == 2) render_expensive_math++;
    return exp2(x);
}
static double audit_sin(double x) {
    if (audit_phase == 2) render_expensive_math++;
    return sin(x);
}
static double audit_cos(double x) {
    if (audit_phase == 2) render_expensive_math++;
    return cos(x);
}
#define malloc audit_malloc
#define calloc audit_calloc
#define realloc audit_realloc
#define free audit_free
#define memset audit_memset
#define sqrt audit_sqrt
#define pow audit_pow
#define exp audit_exp
#define exp2 audit_exp2
#define sin audit_sin
#define cos audit_cos
#endif

#include "TDJEffects.h"

#ifdef AUDIT_OPERATIONS
#undef malloc
#undef calloc
#undef realloc
#undef free
#undef memset
#undef sqrt
#undef pow
#undef exp
#undef exp2
#undef sin
#undef cos
#endif

static double now_seconds(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value)) exit(3);
    return (double)value.tv_sec + (double)value.tv_nsec * 1e-9;
}

static double noise(unsigned frame, unsigned seed) {
    uint32_t value = frame + seed;
    value ^= value >> 16;
    value *= 0x7feb352du;
    value ^= value >> 15;
    value *= 0x846ca68bu;
    value ^= value >> 16;
    return (double)(value >> 8) / 8388608.0 - 1.0;
}

static void fixture(unsigned frame, double rate, int mode, double signal[2]) {
    double time = frame / rate;
    signal[0] = signal[1] = 0;
    if (time >= 4) return;
    double beat = fmod(time, 0.5);
    double kick = 0.25 * sin(2 * M_PI * (48 * beat + 2 * (1 - exp(-45 * beat)))) * exp(-24 * beat);
    double snare_time = fmod(time + 0.5, 1.0);
    double snare = 0.11 * noise(frame, 351) * exp(-48 * snare_time);
    double hat = 0.035 * noise(frame, 911) * exp(-140 * fmod(time, 0.25));
    double chord_left = 0, chord_right = 0;
    const double notes[3] = {220, 261.6255653, 329.6275569};
    double envelope = mode == 1 ? exp(-2.5 * fmod(time, 2.0)) : 0.7 + 0.3 * cos(2 * M_PI * 0.25 * time);
    for (unsigned i = 0; i < 3; i++) {
        double phase = 2 * M_PI * notes[i] * time;
        chord_left += 0.035 * envelope * (sin(phase) + 0.25 * sin(phase * 2));
        chord_right += 0.035 * envelope * (sin(phase + 0.07 * i) + 0.25 * sin(phase * 2 - 0.1));
    }
    if (mode == 0 || mode == 2) {
        signal[0] += kick + snare + hat;
        signal[1] += kick + snare + hat * 0.8;
    }
    if (mode == 1 || mode == 2) {
        signal[0] += chord_left;
        signal[1] += chord_right;
    }
}

static void initialise(performance_fx *effect, double rate, int kind) {
    memset(effect, 0, sizeof(*effect));
    if (!fx_init(effect, rate)) exit(4);
    effect->kind = kind;
    effect->x = 0.65;
    effect->y = 0.5;
    effect->enabled = true;
    fx_prepare(effect, rate, 120);
    ramp_set(&effect->wet, effect->y, 0);
}

static void change(performance_fx *effect, double rate, int kind, double x, double wet, bool enabled) {
    if (kind != effect->kind) fx_reset(effect);
    effect->kind = kind;
    effect->x = x;
    effect->y = wet;
    effect->enabled = enabled;
    ramp_set(&effect->wet, enabled ? wet : 0, effect->smoothing);
    fx_prepare(effect, rate, 120);
}

static int layout_kind(unsigned layout, unsigned slot) {
    if (layout == 0) return TDJ_EFFECT_REVERB;
    if (layout == 1) return TDJ_EFFECT_ICEVERB;
    return slot & 1 ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB;
}

static uint64_t invariant_failures;
static double largest_gain_injection_norm, largest_motion_norm;

static void check_reverb_invariants(const stereo_reverb *v, bool initial) {
#ifdef A10X_REVERB_INVARIANTS
    for (unsigned i = 0; i < 8; i++) {
        double gain = v->coefficient[REVERB_MID_GAIN][i];
        double injection = v->coefficient[REVERB_INJECTION_GAIN][i];
        double norm = gain * gain + injection * injection;
        largest_gain_injection_norm = fmax(largest_gain_injection_norm, norm);
        invariant_failures += !isfinite(norm) || norm > 1 + 1e-11 || gain < 0 || gain >= 1 || injection < 0;
        if (initial) invariant_failures += gain != 0 || injection != 1;
        for (unsigned parameter = REVERB_BASS_RATIO; parameter <= REVERB_TREBLE_RATIO; parameter++) {
            double value = v->coefficient[parameter][i];
            invariant_failures += !isfinite(value) || value < 0 || value > 1 + 1e-11;
        }
        invariant_failures += v->tank[i].cursor >= v->tank[i].length || v->tank[i].valid > v->tank[i].length;
    }
    for (unsigned i = 0; i < 2; i++) {
        double norm = v->motion_cos[i] * v->motion_cos[i] + v->motion_sin[i] * v->motion_sin[i];
        largest_motion_norm = fmax(largest_motion_norm, norm);
        invariant_failures += !isfinite(norm) || norm > 1 + 1e-11;
    }
    if (v->prepared) {
        invariant_failures += !(v->bass_pole > 0 && v->bass_pole < 1 && v->treble_pole > 0 && v->treble_pole < 1);
    }
#else
    (void)v;
    (void)initial;
#endif
}

static unsigned safety(void) {
    const double rates[] = {8000, 44100, 48000, 96000, 192000};
    const unsigned blocks[] = {16, 128, 512};
    uint64_t frames = 0, invalid = 0, stale_reset = 0, bypass_mismatch = 0;
    double peak = 0, polarity_error = 0, linearity_error = 0;
    unsigned cases = 0;
    for (unsigned r = 0; r < 5; r++) {
        double rate = rates[r];
        for (unsigned b = 0; b < 3; b++) {
            for (unsigned layout = 0; layout < 3; layout++) {
                performance_fx effects[6];
                for (unsigned slot = 0; slot < 6; slot++) initialise(&effects[slot], rate, layout_kind(layout, slot));
                unsigned length = (unsigned)(rate * 0.36);
                audit_phase = 1;
                for (unsigned n = 0; n < length; n++) {
                    if (n % blocks[b] == 0) {
                        unsigned event = n / blocks[b];
                        double x = (double)(event % 17) / 16.0;
                        for (unsigned slot = 0; slot < 6; slot++) {
                            int kind = layout_kind(layout, slot);
                            if (event % 13 == 0) kind = kind == TDJ_EFFECT_REVERB ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB;
                            bool enabled = event % 19 != 0;
                            change(&effects[slot], rate, kind, x, 0.5, enabled);
                            if (event % 31 == 0) fx_reset(&effects[slot]);
                        }
                    }
                    double input[2];
                    audit_phase = 0;
                    fixture(n, rate, 2, input);
                    audit_phase = 2;
                    for (unsigned deck = 0; deck < 2; deck++) {
                        double left = input[deck], right = input[1 - deck];
                        for (unsigned slot = 0; slot < 3; slot++) fx_process(&effects[deck * 3 + slot], rate, 120, n * 2 / rate, &left, &right);
                        invalid += !isfinite(left) || !isfinite(right);
                        peak = fmax(peak, fmax(fabs(left), fabs(right)));
                    }
                    frames++;
                    audit_phase = 1;
                }
                for (unsigned slot = 0; slot < 6; slot++) {
                    change(&effects[slot], rate, layout_kind(layout, slot), 1, 1, true);
                    fx_reset(&effects[slot]);
                    effects[slot].transition = 0;
                }
                for (unsigned n = 0; n < (unsigned)(rate * 0.13); n++) {
                    for (unsigned slot = 0; slot < 6; slot++) {
                        double left = 0, right = 0;
                        audit_phase = 2;
                        fx_process(&effects[slot], rate, 120, n * 2 / rate, &left, &right);
                        audit_phase = 1;
                        stale_reset += left != 0 || right != 0;
                    }
                }
                for (unsigned slot = 0; slot < 6; slot++) {
                    fx_reset(&effects[slot]);
                    effects[slot].transition = 0;
                    ramp_set(&effects[slot].wet, 0, 0);
                    for (unsigned n = 0; n < 64; n++) {
                        double dry_left = 0.17 * noise(n, slot), dry_right = 0.12 * noise(n, slot + 31);
                        double left = dry_left, right = dry_right;
                        audit_phase = 2;
                        fx_process(&effects[slot], rate, 120, n * 2 / rate, &left, &right);
                        audit_phase = 1;
                        bypass_mismatch += left != dry_left || right != dry_right;
                    }
                }
                audit_phase = 0;
                for (unsigned slot = 0; slot < 6; slot++) fx_destroy(&effects[slot]);
                cases++;
            }
        }
        stereo_reverb positive = {0}, negative = {0}, scaled = {0};
        if (!reverb_init(&positive, rate) || !reverb_init(&negative, rate) || !reverb_init(&scaled, rate)) exit(4);
        check_reverb_invariants(&positive, true);
        audit_phase = 1;
        reverb_prepare(&positive, 1, true, 0);
        reverb_prepare(&negative, 1, true, 0);
        reverb_prepare(&scaled, 1, true, 0);
        for (unsigned n = 0; n < (unsigned)(rate * 0.6); n++) {
            if (n % 127 == 0) {
                double x = (double)((n / 127) % 11) / 10;
                reverb_prepare(&positive, x, n & 256, (unsigned)(rate * 0.04));
                reverb_prepare(&negative, x, n & 256, (unsigned)(rate * 0.04));
                reverb_prepare(&scaled, x, n & 256, (unsigned)(rate * 0.04));
            }
            double input[2] = {0.2 * noise(n, 71), 0.2 * noise(n, 113)};
            double inverse[2] = {-input[0], -input[1]}, amplified[2] = {input[0] * 64, input[1] * 64};
            double out[2], opposite[2], louder[2];
            audit_phase = 2;
            reverb_process(&positive, input, out);
            reverb_process(&negative, inverse, opposite);
            reverb_process(&scaled, amplified, louder);
            check_reverb_invariants(&positive, false);
            audit_phase = 1;
            polarity_error = fmax(polarity_error, fmax(fabs(out[0] + opposite[0]), fabs(out[1] + opposite[1])));
            linearity_error = fmax(linearity_error, fmax(fabs(out[0] - louder[0] / 64), fabs(out[1] - louder[1] / 64)));
        }
        audit_phase = 0;
        free(positive.storage);
        free(negative.storage);
        free(scaled.storage);
    }
    printf("{\"cases\":%u,\"six_slot_stereo_frames\":%llu,\"invalid_samples\":%llu,\"stale_after_reset\":%llu,\"zero_wet_mismatches\":%llu,\"polarity_error\":%.17g,\"amplitude_homogeneity_error\":%.17g,\"peak\":%.17g,\"rt_allocations\":%llu,\"rt_deallocations\":%llu,\"largest_rt_memset_bytes\":%zu,\"render_expensive_math_calls\":%llu,\"invariant_failures\":%llu,\"largest_gain_injection_squared_norm\":%.17g,\"largest_motion_squared_norm\":%.17g}\n", cases, (unsigned long long)frames, (unsigned long long)invalid, (unsigned long long)stale_reset, (unsigned long long)bypass_mismatch, polarity_error, linearity_error, peak, (unsigned long long)rt_allocations, (unsigned long long)rt_deallocations, largest_rt_clear, (unsigned long long)render_expensive_math, (unsigned long long)invariant_failures, largest_gain_injection_norm, largest_motion_norm);
    return invalid || stale_reset || bypass_mismatch || polarity_error > 1e-8 || linearity_error > 1e-8 || rt_allocations || rt_deallocations || invariant_failures;
}

static unsigned long_decay(void) {
    const double rates[] = {8000, 192000};
    uint64_t invalid = 0, increasing_late_bins = 0;
    double maximum_final_to_initial_energy = 0, peak = 0;
    printf("{\"cases\":[");
    for (unsigned r = 0; r < 2; r++) {
        for (unsigned scenario = 0; scenario < 2; scenario++) {
            double rate = rates[r], energy[6] = {0};
            stereo_reverb reverb = {0};
            if (!reverb_init(&reverb, rate)) exit(4);
            audit_phase = 1;
            reverb_prepare(&reverb, 1, true, 0);
            for (unsigned n = 0; n < (unsigned)(rate * 60); n++) {
                double value = scenario ? (n < (unsigned)(rate * 0.25) ? 0.25 : 0) : (n == 0 ? 0.5 : 0);
                double input[2] = {value, value}, out[2];
                audit_phase = 2;
                reverb_process(&reverb, input, out);
                invalid += !isfinite(out[0]) || !isfinite(out[1]);
                peak = fmax(peak, fmax(fabs(out[0]), fabs(out[1])));
                energy[(unsigned)(n / (rate * 10))] += out[0] * out[0] + out[1] * out[1];
                if (n % 32 == 0) check_reverb_invariants(&reverb, false);
            }
            for (unsigned bin = 2; bin < 6; bin++) increasing_late_bins += energy[bin] > energy[bin - 1];
            double ratio = energy[5] / fmax(energy[0], 1e-300);
            maximum_final_to_initial_energy = fmax(maximum_final_to_initial_energy, ratio);
            printf("%s{\"rate\":%.0f,\"excitation\":\"%s\",\"ten_second_energy_bins\":[%.17g,%.17g,%.17g,%.17g,%.17g,%.17g]}", r || scenario ? "," : "", rate, scenario ? "dc_250ms_then_silence" : "mono_impulse", energy[0], energy[1], energy[2], energy[3], energy[4], energy[5]);
            audit_phase = 0;
            free(reverb.storage);
        }
    }
    printf("],\"invalid_samples\":%llu,\"increasing_late_ten_second_bins\":%llu,\"maximum_last_to_first_energy_ratio\":%.17g,\"peak\":%.17g,\"invariant_failures\":%llu,\"largest_gain_injection_squared_norm\":%.17g,\"largest_motion_squared_norm\":%.17g,\"rt_allocations\":%llu,\"rt_deallocations\":%llu}\n", (unsigned long long)invalid, (unsigned long long)increasing_late_bins, maximum_final_to_initial_energy, peak, (unsigned long long)invariant_failures, largest_gain_injection_norm, largest_motion_norm, (unsigned long long)rt_allocations, (unsigned long long)rt_deallocations);
    return invalid || increasing_late_bins || invariant_failures || rt_allocations || rt_deallocations;
}

#ifdef A10X_REVERB_INVARIANTS
static unsigned constructors(void) {
    unsigned accepted_invalid = 0, rejected_valid = 0, nonfinite = 0, stale = 0;
    const double invalid_rates[] = {0, -1, NAN, INFINITY, DBL_MAX};
    const double valid_rates[] = {1, 1000, 384000};
    for (unsigned i = 0; i < 5; i++) {
        stereo_reverb reverb = {0};
        accepted_invalid += reverb_init(&reverb, invalid_rates[i]);
        free(reverb.storage);
    }
    for (unsigned i = 0; i < 3; i++) {
        stereo_reverb reverb = {0};
        bool accepted = reverb_init(&reverb, valid_rates[i]);
        rejected_valid += !accepted;
        if (!accepted) continue;
        check_reverb_invariants(&reverb, true);
        reverb_prepare(&reverb, 0.7, true, 64);
        for (unsigned n = 0; n < 4096; n++) {
            double input[2] = {n == 0 ? 0.5 : 0, n == 0 ? 0.5 : 0}, out[2];
            reverb_process(&reverb, input, out);
            nonfinite += !isfinite(out[0]) || !isfinite(out[1]);
            check_reverb_invariants(&reverb, false);
        }
        reverb_reset(&reverb);
        for (unsigned n = 0; n < 4096; n++) {
            double input[2] = {0, 0}, out[2];
            reverb_process(&reverb, input, out);
            stale += out[0] != 0 || out[1] != 0;
        }
        free(reverb.storage);
    }
    printf("{\"accepted_invalid_rate\":%u,\"rejected_finite_positive_test_rate\":%u,\"nonfinite\":%u,\"stale_after_reset\":%u,\"invariant_failures\":%llu,\"tested_valid_rates\":[1,1000,384000]}\n", accepted_invalid, rejected_valid, nonfinite, stale, (unsigned long long)invariant_failures);
    return accepted_invalid || rejected_valid || nonfinite || stale || invariant_failures;
}
#endif

#ifdef A10X_RELEASE_CONTRACT
static void excite_effect(performance_fx *effect, double rate, int kind) {
    change(effect, rate, kind, 0.45, 0.65, true);
    for (unsigned n = 0; n < (unsigned)(rate * 0.3); n++) {
        double left = 0.13 * noise(n, 197), right = 0.1 * noise(n, 311);
        fx_process(effect, rate, 120, 0, &left, &right);
    }
}

static unsigned release_contract(void) {
    const double rates[] = {8000, 48000, 192000};
    uint64_t lost_release = 0, bad_capture = 0, extended_deadline = 0, bad_reengage = 0;
    uint64_t stale_after_zero = 0, stale_after_deadline = 0, abrupt_type_switch = 0, duplicated_state = 0, invalid = 0, stale_after_type_bridge = 0, bad_deadline_bound = 0;
    double maximum_capture_error = 0, maximum_reengage_error = 0;
    unsigned cases = 0;
    for (unsigned r = 0; r < 3; r++) {
        double rate = rates[r];
        for (unsigned kind_index = 0; kind_index < 2; kind_index++) {
            int kind = kind_index ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB;
            performance_fx effect;
            initialise(&effect, rate, kind);
            audit_phase = 1;
            excite_effect(&effect, rate, kind);
            float *allocation = effect.reverb.storage;
            double captured = effect.wet.value;
            change(&effect, rate, kind, effect.x, effect.y, false);
            double left = 0, right = 0;
            fx_process(&effect, rate, 120, 0, &left, &right);
            maximum_capture_error = fmax(maximum_capture_error, fabs(effect.reverb_return.value - captured));
            bad_capture += fabs(effect.reverb_return.value - captured) > 1e-12;
            double release_energy = 0;
            for (unsigned n = 0; n < (unsigned)(rate * 0.07); n++) {
                left = right = 0;
                fx_process(&effect, rate, 120, 0, &left, &right);
                if (n > effect.smoothing) release_energy += left * left + right * right;
                invalid += !isfinite(left) || !isfinite(right);
            }
            lost_release += release_energy <= 0 || !effect.reverb_tail_active;
            unsigned remaining = effect.reverb_tail_frames;
            change(&effect, rate, kind, 1, effect.y, false);
            extended_deadline += remaining != effect.reverb_tail_frames;
            double return_before = effect.reverb_return.value;
            change(&effect, rate, kind, effect.x, 0.4, true);
            left = right = 0;
            fx_process(&effect, rate, 120, 0, &left, &right);
            double expected_wet = return_before + (0.4 - return_before) / effect.smoothing;
            maximum_reengage_error = fmax(maximum_reengage_error, fabs(effect.wet.value - expected_wet));
            bad_reengage += fabs(effect.wet.value - expected_wet) > 1e-12 || effect.reverb_tail_active;
            duplicated_state += allocation != effect.reverb.storage;
            excite_effect(&effect, rate, kind);
            change(&effect, rate, kind, effect.x, effect.y, false);
            for (unsigned n = 0; n < effect.smoothing * 2; n++) {
                left = right = 0;
                fx_process(&effect, rate, 120, 0, &left, &right);
            }
            change(&effect, rate, kind, effect.x, 0, false);
            for (unsigned n = 0; n < effect.smoothing + 64; n++) {
                double dry_left = 0.2 * noise(n, 71), dry_right = 0.1 * noise(n, 97);
                left = dry_left; right = dry_right;
                fx_process(&effect, rate, 120, 0, &left, &right);
                if (n >= effect.smoothing) stale_after_zero += left != dry_left || right != dry_right;
            }
            stale_after_zero += effect.reverb_tail_active || !effect.dormant;
            excite_effect(&effect, rate, kind);
            change(&effect, rate, kind, effect.x, effect.y, false);
            unsigned limit = (unsigned)ceil(rate * fmin(30, 1.5 * effect.reverb.decay_seconds + 0.12));
            bad_deadline_bound += effect.reverb_tail_limit != limit;
            for (unsigned n = 0; n < limit + 64; n++) {
                double dry_left = n >= limit ? 0.2 * noise(n, 23) : 0;
                double dry_right = n >= limit ? 0.2 * noise(n, 51) : 0;
                left = dry_left; right = dry_right;
                fx_process(&effect, rate, 120, 0, &left, &right);
                if (n >= limit) stale_after_deadline += left != dry_left || right != dry_right;
                invalid += !isfinite(left) || !isfinite(right);
            }
            stale_after_deadline += effect.reverb_tail_active || !effect.dormant;
            const int replacements[] = {kind_index ? TDJ_EFFECT_REVERB : TDJ_EFFECT_ICEVERB, TDJ_EFFECT_DELAY, TDJ_EFFECT_HIGH_PASS};
            for (unsigned replacement = 0; replacement < 3; replacement++) {
                excite_effect(&effect, rate, kind);
                change(&effect, rate, kind, effect.x, effect.y, false);
                for (unsigned n = 0; n < effect.smoothing * 3; n++) {
                    left = right = 0;
                    fx_process(&effect, rate, 120, 0, &left, &right);
                }
                double previous_left = left, previous_right = right;
                change(&effect, rate, replacements[replacement], 0.5, effect.y, false);
                duplicated_state += effect.reverb_tail_active || allocation != effect.reverb.storage;
                for (unsigned i = 0; i < 8; i++) duplicated_state += effect.reverb.tank[i].valid != 0;
                left = right = 0;
                fx_process(&effect, rate, 120, 0, &left, &right);
                double expected_factor = (double)(effect.smoothing - 1) / effect.smoothing;
                abrupt_type_switch += fabs(left - previous_left * expected_factor) > 1e-10 || fabs(right - previous_right * expected_factor) > 1e-10;
                for (unsigned n = 0; n < effect.smoothing + 64; n++) {
                    left = right = 0;
                    fx_process(&effect, rate, 120, 0, &left, &right);
                    if (n >= effect.smoothing) stale_after_type_bridge += left != 0 || right != 0;
                }
            }
            audit_phase = 0;
            fx_destroy(&effect);
            cases++;
        }
    }
    printf("{\"cases\":%u,\"lost_release\":%llu,\"bad_disable_capture\":%llu,\"deadline_extended_by_x\":%llu,\"bad_deadline_bound\":%llu,\"bad_reengage\":%llu,\"stale_after_y_zero\":%llu,\"stale_after_deadline\":%llu,\"abrupt_type_switch\":%llu,\"stale_after_type_bridge\":%llu,\"duplicated_or_uncleared_state\":%llu,\"invalid_samples\":%llu,\"maximum_capture_error\":%.17g,\"maximum_reengage_error\":%.17g,\"rt_allocations\":%llu,\"rt_deallocations\":%llu}\n", cases, (unsigned long long)lost_release, (unsigned long long)bad_capture, (unsigned long long)extended_deadline, (unsigned long long)bad_deadline_bound, (unsigned long long)bad_reengage, (unsigned long long)stale_after_zero, (unsigned long long)stale_after_deadline, (unsigned long long)abrupt_type_switch, (unsigned long long)stale_after_type_bridge, (unsigned long long)duplicated_state, (unsigned long long)invalid, maximum_capture_error, maximum_reengage_error, (unsigned long long)rt_allocations, (unsigned long long)rt_deallocations);
    return lost_release || bad_capture || extended_deadline || bad_deadline_bound || bad_reengage || stale_after_zero || stale_after_deadline || abrupt_type_switch || stale_after_type_bridge || duplicated_state || invalid || rt_allocations || rt_deallocations;
}
#endif

static FILE *audio_file(const char *directory, const char *name) {
    char path[4096];
    if (snprintf(path, sizeof(path), "%s/%s.f32", directory, name) >= (int)sizeof(path)) exit(5);
    FILE *file = fopen(path, "wb");
    if (!file) exit(5);
    return file;
}

static void write_pair(FILE *file, const double pair[2]) {
    float output[2] = {(float)pair[0], (float)pair[1]};
    if (!isfinite(output[0]) || !isfinite(output[1])) exit(6);
    if (fwrite(output, sizeof(float), 2, file) != 2) exit(5);
}

static unsigned render(const char *directory, bool full_wet) {
    const double rate = 48000;
    const double sizes[] = {0.15, 0.55, 0.95, 0.55};
    const char *names[] = {"room-short", "room-medium", "room-long", "ice-medium"};
    for (unsigned scenario = 0; scenario < (full_wet ? 0u : 4u); scenario++) {
        stereo_reverb reverb = {0};
        if (!reverb_init(&reverb, rate)) exit(4);
        reverb_prepare(&reverb, sizes[scenario], scenario == 3, 0);
        FILE *file = audio_file(directory, names[scenario]);
        for (unsigned n = 0; n < (unsigned)(rate * 12); n++) {
            double input[2] = {n == 0 ? 0.5 : 0, n == 0 ? 0.5 : 0}, out[2];
            reverb_process(&reverb, input, out);
            write_pair(file, out);
        }
        fclose(file);
        free(reverb.storage);
    }
    const char *music[] = {"percussion", "chords", "mix"};
    for (unsigned scenario = 0; scenario < 3; scenario++) {
        performance_fx effect;
        initialise(&effect, rate, TDJ_EFFECT_REVERB);
        effect.x = 0.72;
        effect.y = full_wet ? 1 : 0.65;
        fx_prepare(&effect, rate, 120);
        ramp_set(&effect.wet, effect.y, 0);
        for (unsigned n = 0; n < 4800; n++) {
            double left = 0, right = 0;
            fx_process(&effect, rate, 120, n / 24000.0, &left, &right);
        }
        char dry_name[64];
        snprintf(dry_name, sizeof(dry_name), "%s-dry", music[scenario]);
        FILE *dry = audio_file(directory, dry_name), *wet = audio_file(directory, music[scenario]);
        for (unsigned n = 0; n < (unsigned)(rate * 8); n++) {
            double input[2];
            fixture(n, rate, (int)scenario, input);
            write_pair(dry, input);
            fx_process(&effect, rate, 120, n / 24000.0, &input[0], &input[1]);
            write_pair(wet, input);
        }
        fclose(dry);
        fclose(wet);
        fx_destroy(&effect);
    }
    printf("{\"rendered\":true,\"sample_rate\":48000,\"impulses\":%u,\"audition_scenarios\":3,\"wet_parameter\":%.2f}\n", full_wet ? 0u : 4u, full_wet ? 1.0 : 0.65);
    return 0;
}

static int order_double(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static unsigned benchmark(unsigned layout, unsigned mode, unsigned block) {
    const double rate = 48000;
    const unsigned length = 144000;
    double *source = malloc((size_t)length * 2 * sizeof(double));
    unsigned count = (length + block - 1) / block;
    double *timings = malloc((size_t)count * sizeof(double));
    if (!source || !timings) exit(4);
    for (unsigned n = 0; n < length; n++) fixture(n, rate, 2, source + n * 2);
    performance_fx effects[6];
    for (unsigned slot = 0; slot < 6; slot++) initialise(&effects[slot], rate, layout_kind(layout, slot));
    for (unsigned n = 0; n < 4800; n++) {
        for (unsigned slot = 0; slot < 6; slot++) {
            double left = 0, right = 0;
            fx_process(&effects[slot], rate, 120, n / 24000.0, &left, &right);
        }
    }
    double checksum = 0, peak = 0;
    uint64_t invalid = 0;
    double start = now_seconds();
    for (unsigned index = 0; index < count; index++) {
        double before = now_seconds();
        for (unsigned slot = 0; slot < 6; slot++) {
            if (mode) {
                double x = (double)((index + slot * 7) % 101) / 100.0;
                int kind = layout_kind(layout, slot);
                if (mode == 2 && index % 23 == 0) kind = kind == TDJ_EFFECT_REVERB ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB;
                change(&effects[slot], rate, kind, x, 0.5, mode != 2 || index % 29 != 0);
            } else fx_prepare(&effects[slot], rate, 120);
        }
        unsigned end = (index + 1) * block;
        if (end > length) end = length;
        for (unsigned n = index * block; n < end; n++) {
            for (unsigned deck = 0; deck < 2; deck++) {
                double left = source[n * 2 + deck], right = source[n * 2 + 1 - deck];
                for (unsigned slot = 0; slot < 3; slot++) fx_process(&effects[deck * 3 + slot], rate, 120, n / 24000.0, &left, &right);
                checksum += left + right;
                peak = fmax(peak, fmax(fabs(left), fabs(right)));
                invalid += !isfinite(left) || !isfinite(right);
            }
        }
        timings[index] = now_seconds() - before;
    }
    double wall = now_seconds() - start;
    qsort(timings, count, sizeof(double), order_double);
    printf("{\"layout\":%u,\"mode\":%u,\"block_frames\":%u,\"sample_rate\":48000,\"musical_seconds\":3,\"wall_seconds\":%.12g,\"p50_microseconds\":%.12g,\"p99_microseconds\":%.12g,\"max_microseconds\":%.12g,\"invalid_samples\":%llu,\"peak\":%.12g,\"checksum\":%.17g}\n", layout, mode, block, wall, timings[count / 2] * 1e6, timings[(count - 1) * 99 / 100] * 1e6, timings[count - 1] * 1e6, (unsigned long long)invalid, peak, checksum);
    for (unsigned slot = 0; slot < 6; slot++) fx_destroy(&effects[slot]);
    free(source);
    free(timings);
    return invalid != 0;
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "safety") == 0) return (int)safety();
    if (argc == 2 && strcmp(argv[1], "long-decay") == 0) return (int)long_decay();
#ifdef A10X_REVERB_INVARIANTS
    if (argc == 2 && strcmp(argv[1], "constructors") == 0) return (int)constructors();
#endif
#ifdef A10X_RELEASE_CONTRACT
    if (argc == 2 && strcmp(argv[1], "release") == 0) return (int)release_contract();
#endif
    if (argc == 3 && strcmp(argv[1], "render") == 0) return (int)render(argv[2], false);
    if (argc == 3 && strcmp(argv[1], "render-full") == 0) return (int)render(argv[2], true);
    if (argc == 5 && strcmp(argv[1], "bench") == 0) {
        unsigned layout = (unsigned)strtoul(argv[2], NULL, 10);
        unsigned mode = (unsigned)strtoul(argv[3], NULL, 10);
        unsigned block = (unsigned)strtoul(argv[4], NULL, 10);
        if (layout > 2 || mode > 2 || block < 16 || block > 512) return 2;
        return (int)benchmark(layout, mode, block);
    }
    fprintf(stderr, "Usage: reverb-a10x-probe safety | render DIRECTORY | bench LAYOUT MODE BLOCK\n");
    return 2;
}
