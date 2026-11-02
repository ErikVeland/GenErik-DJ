#ifndef TDJ_RECORDING_H
#define TDJ_RECORDING_H
#include <stdint.h>
#include <stdbool.h>

typedef struct tdj_recording tdj_recording;
typedef struct { uint64_t generation, frame; uint32_t deck; } tdj_recorded_track;
tdj_recording *tdj_recording_create(uint32_t capacity);
void tdj_recording_destroy(tdj_recording *ring);
// Start/reset on a worker, after stop and after the prior consumer has finished.
void tdj_recording_start(tdj_recording *ring);
// Close capture immediately; does not wait for an already accepted sample copy.
void tdj_recording_request_stop(tdj_recording *ring);
// Close capture and join an accepted copy before draining, resetting or destroying.
// Call from a worker; never from audio or UI control paths.
void tdj_recording_stop(tdj_recording *ring);
// Single audio producer. No allocation, locks, disk access or waits.
void tdj_recording_push(tdj_recording *ring, uint32_t frames, const float *left, const float *right);
void tdj_recording_push_tracks(tdj_recording *ring, uint32_t frames, const float *left, const float *right,
                               const uint64_t generations[2], const uint32_t offsets[2]);
// Read the track events only after tdj_recording_stop has joined the producer.
uint32_t tdj_recording_track_count(const tdj_recording *ring);
bool tdj_recording_track(const tdj_recording *ring, uint32_t index, tdj_recorded_track *out);
bool tdj_recording_tracks_overflowed(const tdj_recording *ring);
// Single file-writer consumer.
uint32_t tdj_recording_read(tdj_recording *ring, uint32_t capacity, float *left, float *right);
// Writer-side failure flag; capture never waits for file work.
void tdj_recording_mark_failed(tdj_recording *ring);
bool tdj_recording_failed(const tdj_recording *ring);
uint64_t tdj_recording_captured(const tdj_recording *recording);
uint64_t tdj_recording_dropped(tdj_recording *ring);
#endif
