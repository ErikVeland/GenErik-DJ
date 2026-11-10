#ifndef TDJ_MK2_POSITION_H
#define TDJ_MK2_POSITION_H

#include <pthread.h>

typedef struct { uint64_t low, high; } mk2_word;
typedef struct { mk2_word word; uint32_t position, end; } mk2_checkpoint;

enum { MK2_STRIDE = 64, MK2_MASK_BITS = 46, MK2_WORD_BITS = 110 };
#define MK2_HIGH_MASK ((UINT64_C(1) << MK2_MASK_BITS) - 1)
#define MK2_CHECKPOINT_COUNT (1800000 / MK2_STRIDE + 2550000 / MK2_STRIDE + 2)

static mk2_checkpoint *mk2_index;
static pthread_once_t mk2_index_once = PTHREAD_ONCE_INIT;
static _Atomic bool mk2_index_ready;

static unsigned mk2_parity(mk2_word word, bool forward) {
    const uint64_t low = UINT64_C(0x0000010800000001), high = UINT64_C(0x400000000040);
    uint64_t a = forward ? low : (low >> 1) | (high << 63);
    uint64_t b = forward ? high : (high >> 1) | (UINT64_C(1) << 45);
    return (__builtin_popcountll(word.low & a) + __builtin_popcountll(word.high & b)) & 1u;
}

static mk2_word mk2_shift(mk2_word word, unsigned bit, bool forward) {
    if (forward)
        return (mk2_word){(word.low >> 1) | (word.high << 63), (word.high >> 1) | ((uint64_t)bit << 45)};
    return (mk2_word){(word.low << 1) | bit, ((word.high << 1) | (word.low >> 63)) & MK2_HIGH_MASK};
}

static int mk2_compare(const void *left, const void *right) {
    const mk2_checkpoint *a = left, *b = right;
    if (a->word.high != b->word.high) return a->word.high < b->word.high ? -1 : 1;
    if (a->word.low != b->word.low) return a->word.low < b->word.low ? -1 : 1;
    return 0;
}

static void mk2_build_index(void) {
    mk2_index = malloc(MK2_CHECKPOINT_COUNT * sizeof(*mk2_index));
    if (!mk2_index)
        return;
    const mk2_word seeds[] = {{UINT64_C(0x03fc00c60f8c1f00), UINT64_C(0xc6007c63e)},
                              {UINT64_C(0xe73ff00f9fe0c7c1), UINT64_C(0x1ff9f00003)}};
    const uint32_t ends[] = {1800000, 2550000};
    unsigned count = 0;
    for (unsigned side = 0; side < 2; ++side) {
        mk2_word word = seeds[side];
        for (uint32_t i = 0; i <= ends[side]; ++i) {
            if (i % MK2_STRIDE == 0)
                mk2_index[count++] = (mk2_checkpoint){word, i, ends[side]};
            word = mk2_shift(word, mk2_parity(word, true), true);
        }
    }
    qsort(mk2_index, count, sizeof(*mk2_index), mk2_compare);
    atomic_store_explicit(&mk2_index_ready, true, memory_order_release);
}

typedef struct {
    mk2_word word;
    unsigned read, consecutive;
    int32_t position, end;
} mk2_lane;

static bool mk2_bit(mk2_lane *lane, unsigned bit, bool forward) {
    bool correct = lane->read >= MK2_WORD_BITS && mk2_parity(lane->word, forward) == bit;
    lane->word = mk2_shift(lane->word, bit, forward);
    if (lane->read < MK2_WORD_BITS)
        ++lane->read;
    if (!correct) {
        lane->consecutive = 0;
        lane->position = -1;
        return false;
    }
    if (lane->consecutive < 12 && ++lane->consecutive < 12)
        return false;
    if (lane->position >= 0) {
        lane->position += forward ? 1 : -1;
        if (lane->position >= 0 && lane->position <= lane->end)
            return true;
        lane->position = -1;
    }
    if (lane->word.low == 0 && lane->word.high == 0)
        return false;
    mk2_checkpoint target = {.word = lane->word};
    const mk2_checkpoint *hit = bsearch(&target, mk2_index, MK2_CHECKPOINT_COUNT, sizeof(*mk2_index), mk2_compare);
    if (!hit)
        return false;
    lane->position = (int32_t)hit->position;
    lane->end = (int32_t)hit->end;
    return true;
}

typedef struct {
    mk2_lane lanes[4];
    float previous, penultimate;
    unsigned read, bit;
    bool changed;
} mk2_peaks;

typedef struct {
    mk2_peaks peaks[2];
    float previous_sample, derivative, power;
    bool seeded;
    bool forward;
    int32_t position;
} mk2_decoder;

static void mk2_reset(mk2_decoder *decoder) {
    memset(decoder, 0, sizeof(*decoder));
    decoder->position = -1;
}

static void mk2_peak(mk2_decoder *decoder, unsigned polarity, float peak) {
    mk2_peaks *peaks = &decoder->peaks[polarity];
    if (peaks->read >= 2) {
        float threshold = sqrtf(decoder->power) * 0.60f;
        float delta = peak - peaks->previous, across = peak - peaks->penultimate;
        if (!peaks->changed && ((delta > threshold && across > threshold) || (delta < -threshold && across < -threshold))) {
            unsigned bit = delta > 0;
            peaks->changed = peaks->bit != bit;
            peaks->bit = bit;
        } else {
            peaks->changed = false;
        }
        for (unsigned i = 0; i < 4; ++i) {
            bool forward = i < 2;
            if (mk2_bit(&peaks->lanes[i], peaks->bit ^ (i & 1), forward)) {
                decoder->position = peaks->lanes[i].position;
                decoder->forward = forward;
            }
        }
    } else {
        ++peaks->read;
    }
    peaks->penultimate = peaks->previous;
    peaks->previous = peak;
}

static void mk2_scan(mk2_decoder *decoder, const float *left, unsigned stride, unsigned count) {
    decoder->position = -1;
    for (unsigned i = 0; i < count; ++i) {
        float value = left[i * stride];
        if (!decoder->seeded) {
            decoder->seeded = true;
            decoder->previous_sample = value;
            continue;
        }
        float derivative = value - decoder->previous_sample;
        decoder->power += (value * value - decoder->power) * 0.002f;
        if ((derivative > 0 && decoder->derivative < 0) || (derivative < 0 && decoder->derivative > 0)) {
            unsigned polarity = derivative > 0;
            mk2_peak(decoder, polarity, decoder->previous_sample);
        }
        decoder->previous_sample = value;
        decoder->derivative = derivative;
    }
}

#endif
