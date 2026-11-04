#include "TDJTransport.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "TDJMixer.h"
#include "TDJEffects.h"

static performance_fx *make_fx(int kind, double rate, double x, double wet) {
    performance_fx *f = calloc(1, sizeof(*f));
    if (!f || !fx_init(f, rate))
        exit(3);
    f->kind = kind;
    f->x = x;
    f->enabled = true;
    fx_prepare(f, rate, 120);
    ramp_set(&f->wet, wet, 0);
    for (unsigned n = 0; n < (unsigned)(rate * 0.1); n++) {
        double l = 0, r = 0;
        fx_process(f, rate, 120, n * 2 / rate, &l, &r);
    }
    return f;
}

static void destroy_fx(performance_fx *f) {
    fx_destroy(f);
    free(f);
}

static FILE *open_output(const char *directory, const char *name) {
    char path[4096];
    snprintf(path, sizeof(path), "%s/%s.f32", directory, name);
    FILE *file = fopen(path, "wb");
    if (!file)
        exit(4);
    return file;
}

static void write_pair(FILE *file, double l, double r) {
    float pair[2] = {(float)l, (float)r};
    if (fwrite(pair, sizeof(float), 2, file) != 2)
        exit(4);
}

static double tone(unsigned n, double rate) {
    double t = n / rate;
    return 0.3 * sin(2 * M_PI * 173 * t) + 0.2 * sin(2 * M_PI * 791 * t) + 0.1 * sin(2 * M_PI * 2221 * t);
}

int main(int argc, char **argv) {
    if (argc != 2)
        return 2;
    const char *directory = argv[1];
    const double rates[4] = {8000, 44100, 48000, 96000};
    unsigned invalid = 0, reset_failures = 0;
    double bypass_error = 0, maximum_peak = 0, maximum_change = 0;
    for (int effect = 0; effect < 2; effect++) {
        int kind = effect ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB;
        for (int size = 0; size < 3; size++) {
            double rate = 48000, x = size * 0.5;
            performance_fx *f = make_fx(kind, rate, x, 1);
            char name[64];
            snprintf(name, sizeof(name), "impulse-%d-%d", kind, size);
            FILE *file = open_output(directory, name);
            for (unsigned n = 0; n < (unsigned)(rate * 24); n++) {
                double l = n == 0 ? 0.5 : 0, r = l;
                fx_process(f, rate, 120, n * 2 / rate, &l, &r);
                write_pair(file, l, r);
            }
            fclose(file);
            destroy_fx(f);
        }
    }
    for (unsigned sample_rate = 0; sample_rate < 4; sample_rate++) {
        double rate = rates[sample_rate];
        for (int kind = 0; kind < TDJ_EFFECT_COUNT; kind++) {
            performance_fx *f = make_fx(kind, rate, 0.5, 0);
            for (unsigned n = 0; n < 2048; n++) {
                double dry = tone(n, rate), l = dry, r = -dry;
                fx_process(f, rate, 120, n * 2 / rate, &l, &r);
                bypass_error = fmax(bypass_error, fmax(fabs(l - dry), fabs(r + dry)));
            }
            ramp_set(&f->wet, 1, 0);
            double previous[2] = {0, 0};
            for (unsigned n = 0; n < (unsigned)(rate * 2); n++) {
                if (n % 128 == 0) {
                    f->x = (double)((n / 128) % 11) / 10;
                    fx_prepare(f, rate, 90 + ((n / 128) % 80));
                }
                double l = tone(n, rate), r = tone(n + 113, rate);
                fx_process(f, rate, 120, n * 2 / rate, &l, &r);
                invalid += !isfinite(l) || !isfinite(r);
                maximum_peak = fmax(maximum_peak, fmax(fabs(l), fabs(r)));
                if (kind == TDJ_EFFECT_REVERB || kind == TDJ_EFFECT_ICEVERB)
                    maximum_change = fmax(maximum_change, fmax(fabs(l - previous[0]), fabs(r - previous[1])));
                previous[0] = l;
                previous[1] = r;
            }
            fx_reset(f);
            f->transition = 0;
            for (unsigned n = 0; n < (unsigned)(rate * 0.3); n++) {
                double l = 0, r = 0;
                fx_process(f, rate, 120, n * 2 / rate, &l, &r);
                if (fabs(l) > 1e-10 || fabs(r) > 1e-10)
                    reset_failures++;
            }
            destroy_fx(f);
        }
    }
    double linearity_error = 0;
    for (int kind = 1; kind <= 8; kind += 7) {
        performance_fx *a = make_fx(kind, 48000, 0.7, 1), *b = make_fx(kind, 48000, 0.7, 1);
        for (unsigned n = 0; n < 96000; n++) {
            double l = tone(n, 48000) * 0.1, r = tone(n + 51, 48000) * 0.1;
            double ll = 2 * l, rr = 2 * r;
            fx_process(a, 48000, 120, n / 24000.0, &l, &r);
            fx_process(b, 48000, 120, n / 24000.0, &ll, &rr);
            linearity_error = fmax(linearity_error, fmax(fabs(ll - 2 * l), fabs(rr - 2 * r)));
        }
        destroy_fx(a);
        destroy_fx(b);
    }
    unsigned noise_state = 773;
    performance_fx *demo = make_fx(TDJ_EFFECT_REVERB, 48000, 0.75, 0.4);
    FILE *dry_file = open_output(directory, "demo-dry"), *wet_file = open_output(directory, "demo-reverb");
    for (unsigned n = 0; n < 48000 * 14; n++) {
        double t = n / 48000.0, l = 0, r = 0;
        if (t < 8) {
            double beat = fmod(t, 0.5);
            double kick = 0.38 * sin(2 * M_PI * (48 * beat + 3 * (1 - exp(-beat * 40)))) * exp(-beat * 22);
            noise_state = noise_state * 1664525u + 1013904223u;
            double noise = ((double)(noise_state >> 8) / 8388608 - 1);
            double snare = noise * 0.14 * exp(-fmod(t + 0.5, 1) * 45);
            double envelope = 0.6 + 0.4 * cos(2 * M_PI * 0.25 * t);
            l = kick + snare +
                envelope * (0.075 * sin(2 * M_PI * 220 * t) + 0.06 * sin(2 * M_PI * 261.6256 * t) +
                            0.05 * sin(2 * M_PI * 329.6276 * t));
            r = kick + snare +
                envelope * (0.075 * sin(2 * M_PI * 220 * t) + 0.06 * sin(2 * M_PI * 261.6256 * t + 0.3) +
                            0.05 * sin(2 * M_PI * 329.6276 * t - 0.2));
        }
        write_pair(dry_file, l, r);
        fx_process(demo, 48000, 120, t * 2, &l, &r);
        write_pair(wet_file, l, r);
    }
    fclose(dry_file);
    fclose(wet_file);
    destroy_fx(demo);
    performance_fx *chain[6];
    for (int i = 0; i < 6; i++)
        chain[i] = make_fx(i % 2 ? TDJ_EFFECT_ICEVERB : TDJ_EFFECT_REVERB, 48000, 1, 0.5);
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    double chain_peak = 0;
    for (unsigned n = 0; n < 48000 * 5; n++) {
        for (int deck = 0; deck < 2; deck++) {
            double l = tone(n, 48000), r = tone(n + 77, 48000);
            for (int slot = 0; slot < 3; slot++)
                fx_process(chain[deck * 3 + slot], 48000, 120, n / 24000.0, &l, &r);
            chain_peak = fmax(chain_peak, fmax(fabs(l), fabs(r)));
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    for (int i = 0; i < 6; i++)
        destroy_fx(chain[i]);
    double elapsed = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) * 1e-9;
    printf("{\"invalidSamples\":%u,\"resetFailures\":%u,\"zeroWetError\":%.12g,\"linearityError\":%.12g,"
           "\"rapidSweepPeak\":%.12g,\"reverbSweepMaxStep\":%.12g,\"sixReverbsPeak\":%.12g,"
           "\"sixReverbsFiveSecondsWallTime\":%.12g}\n",
           invalid, reset_failures, bypass_error, linearity_error, maximum_peak, maximum_change, chain_peak, elapsed);
    return invalid || reset_failures || bypass_error > 1e-10 || linearity_error > 1e-6 ? 1 : 0;
}
