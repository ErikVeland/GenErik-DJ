#ifndef TDJ_PATTERN_H
#define TDJ_PATTERN_H

#define TDJ_PATTERN_UNITS 4
#define PATTERN_KITS 24
#define PATTERN_SOUNDS 8
#define PATTERN_NOTES 16

typedef struct {
    float notes[PATTERN_NOTES];
    unsigned count;
} pattern_preset;

typedef struct {
    const float *pcm;
    uint32_t frames;
    pattern_preset presets[PATTERN_SOUNDS];
} pattern_sound;

typedef struct {
    pattern_sound sounds[PATTERN_SOUNDS];
    float pcm[];
} pattern_kit;

typedef struct {
    uint64_t settings;
    int64_t step;
    double phase, remaining;
    uint32_t noise;
    const pattern_sound *sound;
    const pattern_preset *preset;
    double position, limit, increment, next_beat, previous_beat;
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

static void pattern_prepare_pcm(pattern_voice *voice, const pattern_sound *sound, double rate) {
    unsigned choice = (voice->settings >> 59) & 15;
    const pattern_preset *preset = sound && choice >= 1 && choice <= 8 ? &sound->presets[choice - 1] : NULL;
    if (sound != voice->sound) {
        voice->sound = sound;
        voice->position = sound ? sound->frames : 0;
        voice->remaining = 0;
        voice->step = INT64_MIN;
    }
    if (preset != voice->preset) {
        voice->preset = preset;
        voice->next_beat = NAN;
    }
    if (!sound)
        return;
    int pitch = (voice->settings >> 27) & 255;
    unsigned decay = (voice->settings >> 35) & 255;
    voice->increment = 44100.0 / rate * exp2((pitch - 128) / 128.0);
    voice->limit = sound->frames * fmin(1, 0.10 + 1.80 * decay / 255.0);
}

static double pattern_next_beat(const pattern_preset *preset, double beat) {
    double bar = floor(beat / 4) * 4;
    for (unsigned i = 0; i < preset->count; ++i) {
        double at = bar + preset->notes[i];
        if (at >= beat)
            return at;
    }
    return bar + 4 + preset->notes[0];
}

static double pattern_sample_pcm(pattern_voice *voice, int64_t step, double beat) {
    bool trigger = false;
    if (voice->preset) {
        if (!isfinite(voice->next_beat) || beat < voice->previous_beat || beat - voice->previous_beat > 0.25)
            voice->next_beat = pattern_next_beat(voice->preset, beat - 1e-9);
        trigger = beat + 1e-9 >= voice->next_beat;
        if (trigger)
            voice->next_beat = pattern_next_beat(voice->preset, voice->next_beat + 1e-9);
        voice->previous_beat = beat;
    } else {
        trigger = step != voice->step && (voice->settings & (UINT64_C(1) << ((uint64_t)step & 15)));
    }
    voice->step = step;
    if (trigger)
        voice->position = 0;
    if (voice->position >= voice->limit)
        return 0;
    unsigned i = (unsigned)voice->position;
    unsigned next = i + 1 < voice->sound->frames ? i + 1 : i;
    const float *pcm = voice->sound->pcm;
    double sample = pcm[i] + (pcm[next] - pcm[i]) * (voice->position - i);
    double taper = fmin(1, (voice->limit - voice->position) / 220.5);
    voice->position += voice->increment;
    double level = (double)((voice->settings >> 43) & 255) / 255;
    return sample * taper * level * 0.28;
}

#endif
