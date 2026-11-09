#ifndef TDJ_AUXILIARY_H
#define TDJ_AUXILIARY_H

#define MIC_CAPACITY 8192u

typedef struct {
    tdj_asset *asset;
    uint64_t generation;
    double position;
    double last_l, last_r, tail_l, tail_r;
    unsigned tail_remaining;
    bool reading;
} pad_voice;

typedef struct {
    pad_voice pads[TDJ_PAD_COUNT];
    uint32_t playing;
    _Atomic uint32_t published_playing;
    ramp pad_gain;
    _Atomic uint32_t mic_write, mic_read;
    _Atomic bool mic_enabled;
    _Atomic double mic_rate;
    atomic_flag mic_producer;
    float mic_samples[MIC_CAPACITY];
    double mic_fraction;
    float mic_last, mic_gain;
} auxiliary_mix;

typedef struct {
    uint32_t read, write;
    double step;
    bool enabled;
} mic_block;

static void auxiliary_init(auxiliary_mix *aux, double rate) {
    atomic_init(&aux->published_playing, 0);
    atomic_init(&aux->mic_read, 0);
    atomic_init(&aux->mic_write, 0);
    atomic_init(&aux->mic_enabled, false);
    atomic_init(&aux->mic_rate, rate);
    atomic_flag_clear(&aux->mic_producer);
    ramp_set(&aux->pad_gain, 0.35, 0);
}

// The sink publishes samples only after writing the entire block.
static void microphone_push(auxiliary_mix *aux, const float *samples, uint32_t count, uint32_t stride, double rate) {
    if (!atomic_load_explicit(&aux->mic_enabled, memory_order_acquire) || !samples || !stride ||
        stride > 32 || count > MIC_CAPACITY || !isfinite(rate) || rate < 8000 || rate > 192000)
        return;
    if (atomic_flag_test_and_set_explicit(&aux->mic_producer, memory_order_acquire))
        return;
    uint32_t write = atomic_load_explicit(&aux->mic_write, memory_order_relaxed);
    uint32_t read = atomic_load_explicit(&aux->mic_read, memory_order_acquire);
    if (count <= MIC_CAPACITY - (write - read)) {
        for (uint32_t i = 0; i < count; ++i) {
            float value = samples[i * stride];
            aux->mic_samples[(write + i) & (MIC_CAPACITY - 1)] = isfinite(value) ? fmaxf(-1, fminf(1, value)) : 0;
        }
        atomic_store_explicit(&aux->mic_rate, rate, memory_order_relaxed);
        atomic_store_explicit(&aux->mic_write, write + count, memory_order_release);
    }
    atomic_flag_clear_explicit(&aux->mic_producer, memory_order_release);
}

static mic_block microphone_begin(auxiliary_mix *aux, double rate) {
    mic_block block;
    block.enabled = atomic_load_explicit(&aux->mic_enabled, memory_order_acquire);
    block.write = atomic_load_explicit(&aux->mic_write, memory_order_acquire);
    block.read = atomic_load_explicit(&aux->mic_read, memory_order_relaxed);
    block.step = block.enabled ? atomic_load_explicit(&aux->mic_rate, memory_order_relaxed) / rate : 1;
    if (!block.enabled) {
        block.read = block.write;
        aux->mic_fraction = 0;
    }
    return block;
}

static float microphone_next(auxiliary_mix *aux, mic_block *block) {
    if (block->enabled && block->write - block->read > (uint32_t)fmax(1, ceil(aux->mic_fraction + block->step))) {
        float a = aux->mic_samples[block->read & (MIC_CAPACITY - 1)];
        float b = aux->mic_samples[(block->read + 1) & (MIC_CAPACITY - 1)];
        aux->mic_last = (float)(a + (b - a) * aux->mic_fraction);
        aux->mic_fraction += block->step;
        uint32_t consumed = (uint32_t)aux->mic_fraction;
        block->read += consumed;
        aux->mic_fraction -= consumed;
        aux->mic_gain = fminf(1, aux->mic_gain + 1.0f / 128);
    } else {
        aux->mic_gain = fmaxf(0, aux->mic_gain - 1.0f / 128);
    }
    return aux->mic_last * aux->mic_gain;
}

static unsigned pad_fade_frames(double rate) {
    return (unsigned)fmax(2, ceil(rate * 0.002));
}

static void pad_transition(pad_voice *pad, double rate) {
    pad->tail_l = pad->last_l;
    pad->tail_r = pad->last_r;
    pad->tail_remaining = pad->last_l || pad->last_r ? pad_fade_frames(rate) : 0;
}

static void mix_pads(auxiliary_mix *aux, double rate, double *left, double *right) {
    double gain = ramp_next(&aux->pad_gain), l = 0, r = 0;
    uint32_t mask = aux->playing;
    while (mask) {
        unsigned slot = (unsigned)__builtin_ctz(mask);
        uint32_t bit = UINT32_C(1) << slot;
        mask &= ~bit;
        pad_voice *pad = &aux->pads[slot];
        double pl = 0, pr = 0;
        if (pad->reading) {
            tdj_asset *asset = pad->asset;
            uint64_t frame = (uint64_t)pad->position;
            uint64_t next = frame + 1 < asset->frames ? frame + 1 : frame;
            double fraction = pad->position - frame;
            double fade = fmax(0, fmin(1, fmin(pad->position, asset->frames - 1 - pad->position) / (asset->rate * 0.002)));
            pl = fade * (asset->samples[frame * 2] * (1 - fraction) + asset->samples[next * 2] * fraction);
            pr = fade * (asset->samples[frame * 2 + 1] * (1 - fraction) + asset->samples[next * 2 + 1] * fraction);
            pad->position += asset->rate / rate;
            pad->reading = pad->position < asset->frames;
        }
        if (pad->tail_remaining) {
            double tail = (double)pad->tail_remaining-- / pad_fade_frames(rate);
            pl += pad->tail_l * tail;
            pr += pad->tail_r * tail;
        }
        l += pl;
        r += pr;
        pad->last_l = pl;
        pad->last_r = pr;
        if (!pad->reading && !pad->tail_remaining) {
            aux->playing &= ~bit;
            pad->last_l = pad->last_r = 0;
        }
    }
    *left += fmax(-1, fmin(1, l)) * gain;
    *right += fmax(-1, fmin(1, r)) * gain;
}
#endif
