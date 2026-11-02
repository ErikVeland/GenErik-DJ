#include "TDJRecording.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <sched.h>

struct tdj_recording {
    float *samples;
    uint32_t capacity;
    _Atomic uint64_t read, write, dropped;
    // Bit 0 permits capture; bit 1 identifies a callback already copying.
    _Atomic unsigned gate;
    _Atomic bool failed;
    tdj_recorded_track tracks[4096];
    uint32_t track_count;
    uint64_t last_generation[2];
    bool tracks_overflowed;
};
static void prepare_storage_pages(tdj_recording *r) {
    // Touch all capture storage before enabling the audio producer.
    volatile float *samples = r->samples;
    for (size_t i = 0; i < (size_t)r->capacity * 2; i += 256) samples[i] = 0;
    volatile tdj_recorded_track *tracks = r->tracks;
    for (uint32_t i = 0; i < 4096; ++i) tracks[i].generation = 0;
}
tdj_recording *tdj_recording_create(uint32_t capacity) {
    if (!capacity) return NULL;
    tdj_recording *r = calloc(1, sizeof(*r));
    if (!r) return NULL;
    r->samples = calloc((size_t)capacity * 2, sizeof(float));
    if (!r->samples) { free(r); return NULL; }
    r->capacity = capacity;
    atomic_init(&r->read, 0); atomic_init(&r->write, 0);
    atomic_init(&r->dropped, 0); atomic_init(&r->gate, 0); atomic_init(&r->failed, false);
    prepare_storage_pages(r);
    return r;
}
void tdj_recording_destroy(tdj_recording *r) { if (r) { free(r->samples); free(r); } }
void tdj_recording_start(tdj_recording *r) {
    prepare_storage_pages(r);
    atomic_store(&r->read, 0); atomic_store(&r->write, 0); atomic_store(&r->dropped, 0); atomic_store(&r->failed, false);
    r->track_count = 0; r->last_generation[0] = r->last_generation[1] = 0; r->tracks_overflowed = false;
    atomic_store_explicit(&r->gate, 1, memory_order_release);
}
void tdj_recording_request_stop(tdj_recording *r) {
    atomic_fetch_and_explicit(&r->gate, ~1u, memory_order_acq_rel);
}
void tdj_recording_stop(tdj_recording *r) {
    tdj_recording_request_stop(r);
    while (atomic_load_explicit(&r->gate, memory_order_acquire) & 2u) sched_yield();
}
void tdj_recording_push(tdj_recording *r, uint32_t frames, const float *left, const float *right) {
    tdj_recording_push_tracks(r, frames, left, right, NULL, NULL);
}
void tdj_recording_push_tracks(tdj_recording *r, uint32_t frames, const float *left, const float *right,
                               const uint64_t generations[2], const uint32_t offsets[2]) {
    unsigned expected = 1;
    if (!frames || !atomic_compare_exchange_strong_explicit(&r->gate, &expected, 3,
            memory_order_acquire, memory_order_relaxed)) return;
    uint64_t w = atomic_load_explicit(&r->write, memory_order_relaxed);
    uint64_t rd = atomic_load_explicit(&r->read, memory_order_acquire);
    if (frames > r->capacity - (w - rd)) {
        atomic_fetch_add_explicit(&r->dropped, frames, memory_order_relaxed);
    } else {
        // One division per block, never one per audio frame.
        size_t index = (size_t)(w % r->capacity) * 2;
        const size_t end = (size_t)r->capacity * 2;
        for (uint32_t i = 0; i < frames; ++i) {
            r->samples[index] = left[i]; r->samples[index + 1] = right[i];
            index += 2;
            if (index == end) index = 0;
        }
        if (generations && offsets) {
            for (unsigned i = 0; i < 2; ++i) {
                if (!generations[i] || offsets[i] >= frames || r->last_generation[i] == generations[i]) continue;
                r->last_generation[i] = generations[i];
                if (r->track_count == 4096) { r->tracks_overflowed = true; continue; }
                r->tracks[r->track_count++] = (tdj_recorded_track){ generations[i], w + offsets[i], i };
            }
        }
        atomic_store_explicit(&r->write, w + frames, memory_order_release);
    }
    atomic_fetch_and_explicit(&r->gate, ~2u, memory_order_release);
}
uint32_t tdj_recording_track_count(const tdj_recording *r) { return r->track_count; }
bool tdj_recording_track(const tdj_recording *r, uint32_t index, tdj_recorded_track *out) {
    if (!out || index >= r->track_count) return false;
    *out = r->tracks[index]; return true;
}
bool tdj_recording_tracks_overflowed(const tdj_recording *r) { return r->tracks_overflowed; }
uint32_t tdj_recording_read(tdj_recording *r, uint32_t capacity, float *left, float *right) {
    uint64_t rd = atomic_load_explicit(&r->read, memory_order_relaxed);
    uint64_t available = atomic_load_explicit(&r->write, memory_order_acquire) - rd;
    uint32_t count = available < capacity ? (uint32_t)available : capacity;
    size_t index = (size_t)(rd % r->capacity) * 2;
    const size_t end = (size_t)r->capacity * 2;
    for (uint32_t i = 0; i < count; ++i) {
        left[i] = r->samples[index]; right[i] = r->samples[index + 1];
        index += 2;
        if (index == end) index = 0;
    }
    atomic_store_explicit(&r->read, rd + count, memory_order_release);
    return count;
}
uint64_t tdj_recording_dropped(tdj_recording *r) { return atomic_load(&r->dropped); }

uint64_t tdj_recording_captured(const tdj_recording *r) { return atomic_load_explicit(&r->write, memory_order_acquire); }

void tdj_recording_mark_failed(tdj_recording *r) { atomic_store_explicit(&r->failed, true, memory_order_release); }
bool tdj_recording_failed(const tdj_recording *r) {
    return atomic_load_explicit(&r->failed, memory_order_acquire) || atomic_load_explicit(&r->dropped, memory_order_relaxed) != 0;
}
