#ifndef TDJ_REVERB_H
#define TDJ_REVERB_H

#include <limits.h>
#include <stdint.h>

enum { REVERB_MID_GAIN, REVERB_INJECTION_GAIN, REVERB_BASS_RATIO, REVERB_TREBLE_RATIO, REVERB_COEFFICIENT_COUNT };

typedef struct {
    float *data;
    unsigned length, cursor, valid;
} reverb_line;

typedef struct {
    float *storage;
    size_t storage_samples;
    reverb_line tank[8], diffuser[2][4], early[2];
    double coefficient[REVERB_COEFFICIENT_COUNT][8];
    double coefficient_target[REVERB_COEFFICIENT_COUNT][8];
    double coefficient_step[REVERB_COEFFICIENT_COUNT][8];
    unsigned coefficient_remaining;
    double damping[8], bass_state[8], input_low[2], input_high[2];
    double input_hp, input_lp, bass_pole, treble_pole, rate;
    double decay_seconds, bass_decay_seconds, treble_decay_seconds;
    double early_gain, early_target, early_step;
    double motion_phase[2], motion_velocity[2];
    double motion_cos[2], motion_sin[2];
    double motion_cos_target[2], motion_sin_target[2];
    double motion_cos_step[2], motion_sin_step[2];
    unsigned motion_remaining;
    unsigned predelay, early_taps[3];
    bool ice, prepared;
} stereo_reverb;

static unsigned reverb_prime(unsigned n) {
    if (n < 3)
        return 3;
    n |= 1;
    for (;;) {
        bool prime = true;
        for (unsigned d = 3; d <= n / d; d += 2) {
            if (n % d == 0) {
                prime = false;
                break;
            }
        }
        if (prime)
            return n;
        if (n > UINT_MAX - 2)
            return 0;
        n += 2;
    }
}

static bool reverb_reserve_line(stereo_reverb *v, reverb_line *line, double requested, bool prime) {
    if (!isfinite(requested) || requested < 0 || requested > UINT_MAX)
        return false;
    unsigned length = prime ? reverb_prime((unsigned)requested) : (unsigned)requested;
    if (!length || (size_t)length > SIZE_MAX / sizeof(float) - v->storage_samples)
        return false;
    line->length = length;
    v->storage_samples += length;
    return true;
}

static bool reverb_init(stereo_reverb *v, double rate) {
    static const double tank_seconds[8] = {0.0217, 0.0271, 0.0319, 0.0379, 0.0437, 0.0533, 0.0599, 0.0677};
    static const double diffusion_seconds[2][4] = {{0.00191, 0.00473, 0.00937, 0.01373},
                                                   {0.00217, 0.00511, 0.01003, 0.01459}};
    if (!v || !isfinite(rate) || rate <= 0)
        return false;
    v->rate = rate;
    v->storage_samples = 0;
    for (int i = 0; i < 8; i++) {
        if (!reverb_reserve_line(v, &v->tank[i], ceil(rate * tank_seconds[i]), true))
            return false;
        v->coefficient[REVERB_INJECTION_GAIN][i] = 1;
        v->coefficient[REVERB_BASS_RATIO][i] = 1;
        v->coefficient[REVERB_TREBLE_RATIO][i] = 1;
    }
    for (int ch = 0; ch < 2; ch++) {
        for (int i = 0; i < 4; i++) {
            if (!reverb_reserve_line(v, &v->diffuser[ch][i], ceil(rate * diffusion_seconds[ch][i]), true))
                return false;
        }
        if (!reverb_reserve_line(v, &v->early[ch], ceil(rate * 0.055) + 1, false))
            return false;
    }
    v->storage = calloc(v->storage_samples, sizeof(float));
    if (!v->storage)
        return false;
    volatile unsigned char *pages = (volatile unsigned char *)v->storage;
    size_t bytes = v->storage_samples * sizeof(float);
    for (size_t offset = 0; offset < bytes; offset += 4096)
        pages[offset] = 0;
    pages[bytes - 1] = 0;
    float *at = v->storage;
    for (int i = 0; i < 8; i++) {
        v->tank[i].data = at;
        at += v->tank[i].length;
    }
    for (int ch = 0; ch < 2; ch++) {
        for (int i = 0; i < 4; i++) {
            v->diffuser[ch][i].data = at;
            at += v->diffuser[ch][i].length;
        }
        v->early[ch].data = at;
        at += v->early[ch].length;
    }
    v->motion_phase[0] = -0.43;
    v->motion_phase[1] = 0.37;
    v->motion_velocity[0] = fmin(4 * 0.173 / rate, 1.0 / 64);
    v->motion_velocity[1] = -fmin(4 * 0.271 / rate, 1.0 / 64);
    v->motion_cos[0] = v->motion_cos[1] = 1;
    return true;
}

static void reverb_reset(stereo_reverb *v) {
    for (int i = 0; i < 8; i++) {
        v->tank[i].cursor = v->tank[i].valid = 0;
        v->damping[i] = v->bass_state[i] = 0;
    }
    for (int ch = 0; ch < 2; ch++) {
        for (int i = 0; i < 4; i++) {
            v->diffuser[ch][i].cursor = v->diffuser[ch][i].valid = 0;
        }
        v->early[ch].cursor = v->early[ch].valid = 0;
        v->input_low[ch] = v->input_high[ch] = 0;
    }
}

static void reverb_prepare(stereo_reverb *v, double x, bool ice, unsigned smoothing) {
    x = isfinite(x) ? fmax(0, fmin(1, x)) : 0.5;
    if (!v->prepared || v->ice != ice) {
        v->input_hp = exp(-2 * M_PI * (ice ? 190 : 110) / v->rate);
        v->input_lp = 1 - exp(-2 * M_PI * fmin(v->rate * 0.4, ice ? 15000 : 12000) / v->rate);
        double bass = tan(M_PI * fmin(v->rate * 0.35, ice ? 300 : 220) / v->rate);
        double treble = tan(M_PI * fmin(v->rate * 0.35, ice ? 9000 : 6500) / v->rate);
        v->bass_pole = bass / (1 + bass);
        v->treble_pole = treble / (1 + treble);
        v->predelay = (unsigned)fmax(1, round(v->rate * (ice ? 0.019 : 0.011)));
        static const double early_seconds[3] = {0.0031, 0.0089, 0.0173};
        for (int i = 0; i < 3; i++) {
            v->early_taps[i] = (unsigned)fmax(1, round(v->rate * early_seconds[i]));
        }
        v->prepared = true;
    }
    v->ice = ice;
    v->decay_seconds = ice ? 1.5 * pow(12, x) : 0.35 * pow(24, x);
    v->bass_decay_seconds = fmin(ice ? 2.6 : 1.8, v->decay_seconds * (ice ? 0.48 - 0.15 * x : 0.62 - 0.20 * x));
    v->treble_decay_seconds = fmin(ice ? 5.0 : 2.0, v->decay_seconds * (ice ? 0.48 - 0.10 * x : 0.40 - 0.12 * x));
    v->early_target = (ice ? 0.45 : 0.70) * (1 - 0.30 * x);
    v->early_step = smoothing ? (v->early_target - v->early_gain) / smoothing : 0;
    if (!smoothing)
        v->early_gain = v->early_target;
    for (int i = 0; i < 8; i++) {
        double delay = v->tank[i].length / v->rate;
        double attenuation = 6.907755278982137 * delay;
        double gain = exp(-attenuation / v->decay_seconds);
        v->coefficient_target[REVERB_MID_GAIN][i] = gain;
        v->coefficient_target[REVERB_INJECTION_GAIN][i] = sqrt(fmax(0, 1 - gain * gain));
        v->coefficient_target[REVERB_BASS_RATIO][i] =
            exp(-attenuation * (1 / v->bass_decay_seconds - 1 / v->decay_seconds));
        v->coefficient_target[REVERB_TREBLE_RATIO][i] =
            exp(-attenuation * (1 / v->treble_decay_seconds - 1 / v->decay_seconds));
    }
    for (int parameter = 0; parameter < REVERB_COEFFICIENT_COUNT; parameter++) {
        for (int i = 0; i < 8; i++) {
            double target = v->coefficient_target[parameter][i];
            v->coefficient_step[parameter][i] = smoothing ? (target - v->coefficient[parameter][i]) / smoothing : 0;
            if (!smoothing)
                v->coefficient[parameter][i] = target;
        }
    }
    v->coefficient_remaining = smoothing;
}

static double reverb_read(const reverb_line *line, unsigned back) {
    if (!back || back > line->length || line->valid < back)
        return 0;
    unsigned at = line->cursor >= back ? line->cursor - back : line->cursor + line->length - back;
    return line->data[at];
}

static void reverb_write(reverb_line *line, double value) {
    line->data[line->cursor] = (float)(fabs(value) < 1e-24 ? 0 : value);
    if (++line->cursor == line->length)
        line->cursor = 0;
    if (line->valid < line->length)
        line->valid++;
}

static double reverb_allpass(reverb_line *line, double input, double gain) {
    double delayed = reverb_read(line, line->length);
    double output = delayed - gain * input;
    reverb_write(line, input + gain * output);
    return output;
}

static void reverb_step_coefficients(stereo_reverb *v) {
    if (!v->coefficient_remaining)
        return;
    if (!--v->coefficient_remaining) {
        for (int parameter = 0; parameter < REVERB_COEFFICIENT_COUNT; parameter++) {
            for (int i = 0; i < 8; i++) {
                v->coefficient[parameter][i] = v->coefficient_target[parameter][i];
            }
        }
        v->early_gain = v->early_target;
    } else {
        for (int parameter = 0; parameter < REVERB_COEFFICIENT_COUNT; parameter++) {
            for (int i = 0; i < 8; i++) {
                v->coefficient[parameter][i] += v->coefficient_step[parameter][i];
            }
        }
        v->early_gain += v->early_step;
    }
}

static void reverb_step_motion(stereo_reverb *v) {
    if (!v->motion_remaining) {
        for (int i = 0; i < 8; i++) {
            if (fabs(v->damping[i]) < 1e-24)
                v->damping[i] = 0;
            if (fabs(v->bass_state[i]) < 1e-24)
                v->bass_state[i] = 0;
        }
        for (int ch = 0; ch < 2; ch++) {
            if (fabs(v->input_low[ch]) < 1e-24)
                v->input_low[ch] = 0;
            if (fabs(v->input_high[ch]) < 1e-24)
                v->input_high[ch] = 0;
        }
        for (int i = 0; i < 2; i++) {
            double phase = v->motion_phase[i] + v->motion_velocity[i] * 32;
            if (phase > 1) {
                phase = 2 - phase;
                v->motion_velocity[i] = -v->motion_velocity[i];
            } else if (phase < -1) {
                phase = -2 - phase;
                v->motion_velocity[i] = -v->motion_velocity[i];
            }
            v->motion_phase[i] = phase;
            double position = phase * (1.5 - 0.5 * phase * phase);
            double angle = position * (v->ice ? 0.09 : 0.055);
            double square = angle * angle;
            double scale = 1 / (1 + square);
            v->motion_cos_target[i] = (1 - square) * scale;
            v->motion_sin_target[i] = 2 * angle * scale;
            v->motion_cos_step[i] = (v->motion_cos_target[i] - v->motion_cos[i]) / 32;
            v->motion_sin_step[i] = (v->motion_sin_target[i] - v->motion_sin[i]) / 32;
        }
        v->motion_remaining = 32;
    }
    if (!--v->motion_remaining) {
        for (int i = 0; i < 2; i++) {
            v->motion_cos[i] = v->motion_cos_target[i];
            v->motion_sin[i] = v->motion_sin_target[i];
        }
    } else {
        for (int i = 0; i < 2; i++) {
            v->motion_cos[i] += v->motion_cos_step[i];
            v->motion_sin[i] += v->motion_sin_step[i];
        }
    }
}

static void reverb_process(stereo_reverb *v, const double input[2], double output[2]) {
    static const double diffusion[4] = {0.62, 0.60, 0.57, 0.53};
    static const double early_weight[3] = {0.065, 0.045, 0.035};
    static const double left_sign[8] = {1, 1, -1, -1, 1, -1, 1, -1};
    static const double right_sign[8] = {1, -1, 1, -1, -1, -1, 1, 1};
    double diffused[2], early[2], delayed[8], feedback[8];
    reverb_step_coefficients(v);
    reverb_step_motion(v);
    for (int ch = 0; ch < 2; ch++) {
        v->input_high[ch] = (1 - v->input_hp) * input[ch] + v->input_hp * v->input_high[ch];
        double high = input[ch] - v->input_high[ch];
        v->input_low[ch] += v->input_lp * (high - v->input_low[ch]);
        reverb_line *line = &v->early[ch];
        double predelayed = reverb_read(line, v->predelay);
        early[ch] = 0;
        for (int i = 0; i < 3; i++) {
            early[ch] += reverb_read(line, v->predelay + v->early_taps[i]) * early_weight[i];
        }
        reverb_write(line, v->input_low[ch]);
        for (int i = 0; i < 4; i++) {
            predelayed = reverb_allpass(&v->diffuser[ch][i], predelayed, diffusion[i]);
        }
        diffused[ch] = predelayed;
        early[ch] = (early[ch] + predelayed * 0.14) * v->early_gain;
    }
    for (int i = 0; i < 8; i++) {
        delayed[i] = reverb_read(&v->tank[i], v->tank[i].length);
        double change = (delayed[i] - v->damping[i]) * v->treble_pole;
        double low = v->damping[i] + change;
        v->damping[i] = low + change;
        double shaped = low + v->coefficient[REVERB_TREBLE_RATIO][i] * (delayed[i] - low);
        change = (shaped - v->bass_state[i]) * v->bass_pole;
        low = v->bass_state[i] + change;
        v->bass_state[i] = low + change;
        shaped += (v->coefficient[REVERB_BASS_RATIO][i] - 1) * low;
        feedback[i] = shaped * v->coefficient[REVERB_MID_GAIN][i];
    }
    for (unsigned stride = 1; stride < 8; stride *= 2) {
        for (unsigned base = 0; base < 8; base += stride * 2) {
            for (unsigned j = 0; j < stride; j++) {
                double a = feedback[base + j], b = feedback[base + j + stride];
                feedback[base + j] = a + b;
                feedback[base + j + stride] = a - b;
            }
        }
    }
    for (int i = 0; i < 2; i++) {
        int a_index = i * 2, b_index = i * 2 + 5;
        double a = feedback[a_index], b = feedback[b_index];
        feedback[a_index] = v->motion_cos[i] * a - v->motion_sin[i] * b;
        feedback[b_index] = v->motion_sin[i] * a + v->motion_cos[i] * b;
    }
    double left = 0, right = 0;
    for (int i = 0; i < 8; i++) {
        double excitation = (diffused[0] * left_sign[i] + diffused[1] * right_sign[i]) * 0.25 *
                            v->coefficient[REVERB_INJECTION_GAIN][i];
        reverb_write(&v->tank[i], feedback[i] * 0.3535533905932738 + excitation);
        left += delayed[i] * left_sign[i];
        right += delayed[i] * right_sign[i];
    }
    output[0] = left * 0.25 + early[0];
    output[1] = right * 0.25 + early[1];
}

#endif
