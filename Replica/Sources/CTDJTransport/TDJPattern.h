#ifndef TDJ_PATTERN_H
#define TDJ_PATTERN_H

#define TDJ_PATTERN_UNITS 4

typedef struct {
    uint64_t settings;
    int64_t step;
    double phase, remaining;
    uint32_t noise;
} pattern_voice;

static double pattern_sample(pattern_voice *voice, int64_t step, double rate) {
    uint64_t settings = voice->settings;
    unsigned sound = (unsigned)(settings >> 24) & 7;
    double pitch = 0.5 + (double)((settings >> 27) & 255) / 170;
    double decay = 0.025 + (double)((settings >> 35) & 255) / 700;
    double level = (double)((settings >> 43) & 255) / 255;
    if (step != voice->step) {
        voice->step = step;
        if (settings & (UINT64_C(1) << ((uint64_t)step & 15))) {
            voice->phase = 0;
            voice->remaining = 1;
        }
    }
    if (voice->remaining <= 0)
        return 0;
    double envelope = voice->remaining;
    voice->remaining -= 1 / (rate * decay);
    static const double frequencies[] = {49, 170, 640, 230, 56, 200, 780, 310};
    double sweep = (sound & 3) == 0 ? 1 + 3 * envelope * envelope : 1;
    voice->phase += frequencies[sound] * pitch * sweep / rate;
    if (voice->phase >= 1)
        voice->phase -= 1;
    voice->noise = voice->noise * UINT32_C(1664525) + UINT32_C(1013904223);
    double noise = (double)(voice->noise >> 16) / 32768 - 1;
    double tone = (1 - 4 * fabs(voice->phase - 0.5));
    unsigned kind = sound & 3;
    double value = kind == 0 ? tone : kind == 2 ? noise : (tone + noise) * 0.5;
    return value * envelope * envelope * level * 0.28;
}

#endif
