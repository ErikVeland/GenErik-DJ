#ifndef TDJ_CALLBACK_METRICS_H
#define TDJ_CALLBACK_METRICS_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct tdj_callback_metrics tdj_callback_metrics;
typedef struct {
    uint64_t callbacks, frames, deadline_overruns, timestamp_gaps, invalid_timestamps, render_failures;
    double maximum_microseconds;
    uint32_t minimum_frames, maximum_frames;
} tdj_callback_summary;
tdj_callback_metrics *tdj_callback_metrics_create(double sample_rate);
void tdj_callback_metrics_destroy(tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_begin(void);
void tdj_callback_metrics_end(tdj_callback_metrics *metrics, uint64_t began,
                             uint32_t frames, double sample_time, bool valid_time);
void tdj_callback_metrics_failure(tdj_callback_metrics *metrics);
tdj_callback_summary tdj_callback_metrics_summary(const tdj_callback_metrics *metrics);

enum { TDJ_CALLBACK_TIMING_ANOMALY_CAPACITY = 64 };
#define TDJ_CALLBACK_TIMING_SAMPLE_GAP ((uint32_t)1u)
#define TDJ_CALLBACK_TIMING_DEADLINE ((uint32_t)2u)
#define TDJ_CALLBACK_TIMING_INVALID_TIME ((uint32_t)4u)
typedef struct {
    uint64_t callback_index, began_ticks, ended_ticks;
    uint64_t previous_began_ticks, previous_ended_ticks;
    uint32_t previous_frames;
    bool previous_callback_valid;
    uint32_t frames, flags;
    double duration_microseconds, sample_time, expected_sample_time;
    bool sample_time_valid, expected_sample_time_valid;
} tdj_callback_timing_anomaly;
// One serial callback writer. Published event slots are immutable and never overwritten.
uint32_t tdj_callback_metrics_anomaly_count(const tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_anomalies_dropped(const tdj_callback_metrics *metrics);
bool tdj_callback_metrics_anomaly(const tdj_callback_metrics *metrics, uint32_t index,
                                  tdj_callback_timing_anomaly *event);

// Opt-in diagnostic CPU clocks can perturb scheduling. Not timing acceptance.
typedef struct {
    uint64_t measured_callbacks, clock_failures, maximum_cpu_nanoseconds;
    double maximum_clock_read_microseconds;
} tdj_callback_cpu_summary;
typedef struct {
    uint64_t callback_index;
    double cpu_microseconds, clock_read_microseconds;
    bool cpu_time_valid;
    double wall_microseconds;
    uint64_t arm_fpcr;
    uint32_t mach_thread;
    bool thread_context_valid, is_main_thread, arm_fpcr_valid;
} tdj_callback_cpu_event;
uint64_t tdj_callback_metrics_begin_cpu(tdj_callback_metrics *metrics);
void tdj_callback_metrics_end_cpu(tdj_callback_metrics *metrics, uint64_t began,
                                 uint32_t frames, double sample_time, bool valid_time);
tdj_callback_cpu_summary tdj_callback_metrics_cpu_summary(const tdj_callback_metrics *metrics);
uint32_t tdj_callback_metrics_cpu_event_count(const tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_cpu_events_dropped(const tdj_callback_metrics *metrics);
bool tdj_callback_metrics_cpu_event(const tdj_callback_metrics *metrics, uint32_t index,
                                    tdj_callback_cpu_event *event);


enum { TDJ_KEYLOCK_PRIME_EVENT_CAPACITY = 512 };
typedef struct {
    uint64_t began_ticks, reset_done_ticks, history_done_ticks, preroll_done_ticks;
    uint64_t cpu_began_nanoseconds, cpu_ended_nanoseconds, cpu_clock_ticks;
    uint32_t deck;
    double source_frame, speed;
    bool cpu_valid;
} tdj_keylock_prime_measurement;

typedef struct {
    uint64_t callback_index, began_ticks, reset_done_ticks, history_done_ticks, ended_ticks;
    uint32_t deck;
    double source_frame, speed;
    double reset_microseconds, history_microseconds, preroll_microseconds, total_microseconds;
    double cpu_microseconds, cpu_clock_microseconds;
    bool cpu_time_valid;
    uint64_t arm_fpcr;
    uint32_t mach_thread;
    bool thread_context_valid, is_main_thread, arm_fpcr_valid;
} tdj_keylock_prime_event;
// Called only by the serial source consumer; published events are immutable.
bool tdj_callback_metrics_thread_cpu_nanoseconds(uint64_t *nanoseconds);
void tdj_callback_metrics_keylock_prime(tdj_callback_metrics *metrics,
                                      const tdj_keylock_prime_measurement *measurement);
uint32_t tdj_callback_metrics_keylock_prime_count(const tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_keylock_prime_dropped(const tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_keylock_prime_invalid(const tdj_callback_metrics *metrics);
uint64_t tdj_callback_metrics_keylock_prime_cpu_unavailable(const tdj_callback_metrics *metrics);
bool tdj_callback_metrics_keylock_prime_event(const tdj_callback_metrics *metrics,uint32_t index,
                                             tdj_keylock_prime_event *event);

#ifdef __cplusplus
}
#endif
#endif
