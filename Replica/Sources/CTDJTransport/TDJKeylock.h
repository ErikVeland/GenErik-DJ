#ifndef TDJ_KEYLOCK_H
#define TDJ_KEYLOCK_H
#include <stdint.h>
#include <stdbool.h>
#include "TDJCallbackMetrics.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef struct tdj_keylock tdj_keylock;
typedef struct {
    tdj_callback_metrics *metrics;
    uint64_t (*ticks)(void);
    bool (*cpu_now)(uint64_t *);
    void (*record)(tdj_callback_metrics *, const tdj_keylock_prime_measurement *);
} tdj_keylock_trace;
// Configure a fresh engine before publishing it to an audio consumer.
typedef struct tdj_engine tdj_engine;
void tdj_engine_attach_keylock_trace(tdj_engine *engine, const tdj_keylock_trace *trace);
void tdj_keylock_set_trace(tdj_keylock *processor, const tdj_keylock_trace *trace, uint32_t deck);

typedef bool (*tdj_source_reader)(void *, uint64_t, float *, float *);
// Immutable interleaved stereo, valid for the current render call. NULL uses the scalar reader.
typedef const float *(*tdj_source_span_reader)(void *, uint64_t, uint32_t *);
void tdj_keylock_sample_stream_spans(tdj_keylock *processor, void *context, tdj_source_reader reader,
                                     tdj_source_span_reader spans, uint64_t frames, double source_rate, double position,
                                     double speed, bool enabled, double loop_start, double loop_end, float *left,
                                     float *right);
bool tdj_keylock_limits(double rate, int *input, int *output, int *seek);
tdj_keylock *tdj_keylock_create(double output_rate);
void tdj_keylock_destroy(tdj_keylock *processor);
void tdj_keylock_reset(tdj_keylock *processor);
// Render-consumer query. Spectral overlap already joins source loop seams.
bool tdj_keylock_spectral(const tdj_keylock *processor);
void tdj_keylock_sample(tdj_keylock *processor, const float *stereo, uint64_t frames, double source_rate,
                        double position, double speed, bool enabled, float *left, float *right);
void tdj_keylock_sample_loop(tdj_keylock *processor, const float *stereo, uint64_t frames, double source_rate,
                             double position, double speed, bool enabled, double loop_start, double loop_end,
                             float *left, float *right);
void tdj_keylock_sample_stream(tdj_keylock *processor, void *context, tdj_source_reader reader, uint64_t frames,
                               double source_rate, double position, double speed, bool enabled, double loop_start,
                               double loop_end, float *left, float *right);
#ifdef __cplusplus
}
#endif
#endif
