#ifndef TDJ_AUXILIARY_H
#define TDJ_AUXILIARY_H

#define MIC_CAPACITY 8192u
#define PREVIEW_CAPACITY 16384u

typedef struct {
    tdj_asset *asset;
    uint64_t generation;
    double position;
    double last_l, last_r, tail_l, tail_r;
    unsigned tail_remaining;
    bool reading;
} pad_voice;

typedef struct {
    float left, right;
    uint64_t generation;
} preview_frame;

typedef struct {
    _Atomic uint64_t generation, consumed, consumed_generation;
    _Atomic uint32_t write, read;
    _Atomic double rate;
    atomic_flag producer;
    preview_frame frames[PREVIEW_CAPACITY];
    uint64_t rendering_generation;
    double fraction, gain, last_l, last_r;
} preview_ring;

typedef struct {
    uint32_t read, write;
    uint64_t generation;
    double step;
} preview_block;

static bool preview_push(preview_ring *preview, const float *samples, uint32_t count, double rate, uint64_t generation) {
    if (!generation || !samples || !count || count > PREVIEW_CAPACITY || !isfinite(rate) ||
        rate < 8000 || rate > 192000 || atomic_flag_test_and_set_explicit(&preview->producer, memory_order_acquire))
        return false;
    uint32_t write = atomic_load_explicit(&preview->write, memory_order_relaxed);
    uint32_t read = atomic_load_explicit(&preview->read, memory_order_acquire);
    bool accepted = atomic_load_explicit(&preview->generation, memory_order_acquire) == generation &&
                    count <= PREVIEW_CAPACITY - (write - read);
    if (accepted) {
        for (uint32_t i = 0; i < count; ++i)
            preview->frames[(write + i) & (PREVIEW_CAPACITY - 1)] =
                (preview_frame){samples[2 * i], samples[2 * i + 1], generation};
        atomic_store_explicit(&preview->rate, rate, memory_order_relaxed);
        atomic_store_explicit(&preview->write, write + count, memory_order_release);
    }
    atomic_flag_clear_explicit(&preview->producer, memory_order_release);
    return accepted;
}

static preview_block preview_begin(preview_ring *preview, double rate) {
    uint32_t write = atomic_load_explicit(&preview->write, memory_order_acquire);
    preview_block block = {
        .generation = atomic_load_explicit(&preview->generation, memory_order_acquire),
        .write = write,
        .read = atomic_load_explicit(&preview->read, memory_order_relaxed),
        .step = atomic_load_explicit(&preview->rate, memory_order_relaxed) / rate
    };
    if (preview->rendering_generation != block.generation) {
        preview->rendering_generation = block.generation;
        preview->fraction = preview->gain = 0;
        atomic_store_explicit(&preview->consumed, 0, memory_order_relaxed);
        atomic_store_explicit(&preview->consumed_generation, block.generation, memory_order_release);
    }
    if (!block.generation)
        block.read = block.write;
    while (block.read != block.write &&
           preview->frames[block.read & (PREVIEW_CAPACITY - 1)].generation != block.generation)
        ++block.read;
    return block;
}

static void preview_next(preview_ring *preview, preview_block *block, double *left, double *right) {
    if (block->write - block->read <= (uint32_t)fmax(1, ceil(preview->fraction + block->step))) {
        preview->gain = fmax(0, preview->gain - 1.0 / 256);
        *left += preview->last_l * preview->gain;
        *right += preview->last_r * preview->gain;
        return;
    }
    const preview_frame *a = &preview->frames[block->read & (PREVIEW_CAPACITY - 1)];
    const preview_frame *b = &preview->frames[(block->read + 1) & (PREVIEW_CAPACITY - 1)];
    preview->gain = fmin(0.5, preview->gain + 1.0 / 256);
    preview->last_l = a->left + (b->left - a->left) * preview->fraction;
    preview->last_r = a->right + (b->right - a->right) * preview->fraction;
    *left += preview->gain * preview->last_l;
    *right += preview->gain * preview->last_r;
    preview->fraction += block->step;
    uint32_t consumed = (uint32_t)preview->fraction;
    block->read += consumed;
    preview->fraction -= consumed;
}

typedef struct {
    pad_voice pads[TDJ_PAD_COUNT];
    preview_ring preview;
    uint32_t playing;
    _Atomic uint32_t published_playing;
    ramp pad_gain;
    _Atomic uint32_t mic_write, mic_read;
    _Atomic uint64_t mic_configuration;
    uint64_t rendering_mic_configuration;
    unsigned rendering_mic_channels;
    _Atomic double mic_rate;
    atomic_flag mic_producer;
    _Atomic double input_level;
    _Atomic double input_cue;
    _Atomic double s4_mic_level;
    ramp input_master_ramp, input_cue_ramp, s4_mic_ramp;
    float mic_samples[MIC_CAPACITY][6];
    double mic_fraction;
    float mic_last[6], mic_gain;
} auxiliary_mix;

typedef struct {
    uint32_t read, write;
    double step;
    unsigned channels;
} mic_block;

static void auxiliary_init(auxiliary_mix *aux, double rate) {
    atomic_init(&aux->published_playing, 0);
    atomic_init(&aux->preview.generation, 0);
    atomic_init(&aux->preview.consumed, 0);
    atomic_init(&aux->preview.consumed_generation, 0);
    atomic_init(&aux->preview.write, 0);
    atomic_init(&aux->preview.read, 0);
    atomic_init(&aux->preview.rate, rate);
    atomic_flag_clear(&aux->preview.producer);
    atomic_init(&aux->mic_read, 0);
    atomic_init(&aux->mic_write, 0);
    atomic_init(&aux->mic_configuration, 0);
    atomic_init(&aux->mic_rate, rate);
    atomic_init(&aux->input_level, 1);
    atomic_init(&aux->input_cue, 0);
    atomic_init(&aux->s4_mic_level, 0);
    ramp_set(&aux->input_master_ramp, 1, 0);
    atomic_flag_clear(&aux->mic_producer);
    ramp_set(&aux->pad_gain, 0.35, 0);
}

static unsigned microphone_channels(const auxiliary_mix *aux) {
    return atomic_load_explicit(&aux->mic_configuration, memory_order_acquire) & 7;
}

static void microphone_configure(auxiliary_mix *aux, unsigned channels) {
    uint64_t configuration = atomic_load_explicit(&aux->mic_configuration, memory_order_acquire);
    while ((configuration & 7) != channels) {
        uint64_t write = atomic_load_explicit(&aux->mic_write, memory_order_acquire);
        uint32_t revision = ((uint32_t)configuration & ~UINT32_C(7)) + 8;
        uint64_t next = (write << 32) | revision | channels;
        if (atomic_compare_exchange_weak_explicit(&aux->mic_configuration, &configuration, next,
                                                  memory_order_acq_rel, memory_order_acquire))
            return;
    }
}

// The sink publishes samples only after writing the entire block.
static void microphone_push(auxiliary_mix *aux, const float *const *input, const uint32_t *strides,
                            uint32_t count, unsigned channels, double rate) {
    uint64_t configuration = atomic_load_explicit(&aux->mic_configuration, memory_order_acquire);
    if ((configuration & 7) != channels || count > MIC_CAPACITY || !isfinite(rate) || rate < 8000 || rate > 192000)
        return;
    for (unsigned ch = 0; ch < channels; ++ch)
        if (!input[ch] || !strides[ch] || strides[ch] > 32)
            return;
    if (atomic_flag_test_and_set_explicit(&aux->mic_producer, memory_order_acquire))
        return;
    uint32_t write = atomic_load_explicit(&aux->mic_write, memory_order_relaxed);
    uint32_t read = atomic_load_explicit(&aux->mic_read, memory_order_acquire);
    if (count <= MIC_CAPACITY - (write - read)) {
        for (uint32_t i = 0; i < count; ++i) {
            float *destination = aux->mic_samples[(write + i) & (MIC_CAPACITY - 1)];
            for (unsigned ch = 0; ch < channels; ++ch) {
                float sample = input[ch][i * strides[ch]];
                destination[ch] = isfinite(sample) ? fmaxf(-1, fminf(1, sample)) : 0;
            }
        }
        if (configuration == atomic_load_explicit(&aux->mic_configuration, memory_order_acquire)) {
            atomic_store_explicit(&aux->mic_rate, rate, memory_order_relaxed);
            atomic_store_explicit(&aux->mic_write, write + count, memory_order_release);
        }
    }
    atomic_flag_clear_explicit(&aux->mic_producer, memory_order_release);
}

static mic_block microphone_begin(auxiliary_mix *aux, double rate) {
    uint64_t configuration = atomic_load_explicit(&aux->mic_configuration, memory_order_acquire);
    mic_block block;
    const unsigned active_channels = configuration & 7;
    block.channels = active_channels ? active_channels : aux->mic_gain > 0 ? aux->rendering_mic_channels : 0;
    block.write = atomic_load_explicit(&aux->mic_write, memory_order_acquire);
    block.read = atomic_load_explicit(&aux->mic_read, memory_order_relaxed);
    block.step = block.channels ? atomic_load_explicit(&aux->mic_rate, memory_order_relaxed) / rate : 1;
    if (configuration != aux->rendering_mic_configuration) {
        aux->rendering_mic_configuration = configuration;
        block.read = (uint32_t)(configuration >> 32);
        aux->mic_fraction = 0;
        if (active_channels) {
            aux->rendering_mic_channels = active_channels;
            aux->mic_gain = 0;
            if (active_channels == 6)
                ramp_set(&aux->s4_mic_ramp, atomic_load_explicit(&aux->s4_mic_level, memory_order_relaxed), 0);
        }
    }
    if (!active_channels)
        block.read = block.write;
    return block;
}

static void microphone_next(auxiliary_mix *aux, mic_block *block, double *output) {
    if (block->write - block->read > (uint32_t)fmax(1, ceil(aux->mic_fraction + block->step))) {
        const float *a = aux->mic_samples[block->read & (MIC_CAPACITY - 1)];
        const float *b = aux->mic_samples[(block->read + 1) & (MIC_CAPACITY - 1)];
        for (unsigned i = 0; i < block->channels; ++i)
            aux->mic_last[i] = (float)(a[i] + (b[i] - a[i]) * aux->mic_fraction);
        aux->mic_fraction += block->step;
        uint32_t consumed = (uint32_t)aux->mic_fraction;
        block->read += consumed;
        aux->mic_fraction -= consumed;
        aux->mic_gain = fminf(1, aux->mic_gain + 1.0f / 128);
    } else {
        aux->mic_gain = fmaxf(0, aux->mic_gain - 1.0f / 128);
    }
    for (unsigned i = 0; i < block->channels; ++i)
        output[i] = aux->mic_last[i] * aux->mic_gain;
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
