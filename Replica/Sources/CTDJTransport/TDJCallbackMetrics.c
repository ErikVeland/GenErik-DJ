#include "TDJCallbackMetrics.h"
#include <mach/mach_time.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <limits.h>
#include <time.h>
#include <pthread.h>

_Static_assert(ATOMIC_LLONG_LOCK_FREE == 2 && ATOMIC_LONG_LOCK_FREE == 2 && ATOMIC_INT_LOCK_FREE == 2,
               "Audio diagnostics require lock-free atomics.");
struct tdj_callback_metrics {
    _Atomic uint64_t callbacks, frames, overruns, gaps, invalid, failures, maximum_ticks;
    _Atomic uint32_t minimum_frames, maximum_frames;
    double ticks_per_frame, microseconds_per_tick;
    // Owned only by the serial source callback.
    double next_sample_time;
    bool has_sample_time;
    uint64_t previous_began_ticks, previous_ended_ticks;
    uint32_t previous_frames;
    bool has_previous_callback;
    _Atomic uint32_t anomaly_count;
    _Atomic uint64_t anomalies_dropped;
    tdj_callback_timing_anomaly anomalies[TDJ_CALLBACK_TIMING_ANOMALY_CAPACITY];
    // Separate CPU events keep the existing published wall events immutable.
    _Atomic uint64_t cpu_measured, cpu_clock_failures, maximum_cpu_nanoseconds, maximum_cpu_clock_ticks;
    _Atomic uint32_t cpu_event_count;
    _Atomic uint64_t cpu_events_dropped;
    uint64_t cpu_began_nanoseconds, cpu_begin_clock_ticks;
    bool cpu_began_valid;
    uint64_t cpu_arm_fpcr;
    uint32_t cpu_mach_thread;
    bool cpu_thread_context_valid, cpu_is_main_thread, cpu_arm_fpcr_valid;
    tdj_callback_cpu_event cpu_events[TDJ_CALLBACK_TIMING_ANOMALY_CAPACITY];
    _Atomic uint32_t prime_count;
    _Atomic uint64_t prime_dropped, prime_invalid, prime_cpu_unavailable;
    tdj_keylock_prime_event prime_events[TDJ_KEYLOCK_PRIME_EVENT_CAPACITY];
};
tdj_callback_metrics *tdj_callback_metrics_create(double sample_rate) {
    if (!isfinite(sample_rate) || sample_rate <= 0) return NULL;
    tdj_callback_metrics *m = calloc(1, sizeof(*m));
    if (!m) return NULL;
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || !timebase.numer || !timebase.denom) { free(m); return NULL; }
    m->microseconds_per_tick = (double)timebase.numer / timebase.denom / 1000;
    m->ticks_per_frame = 1000000 / sample_rate / m->microseconds_per_tick;
    atomic_init(&m->callbacks,0); atomic_init(&m->frames,0); atomic_init(&m->overruns,0);
    atomic_init(&m->gaps,0); atomic_init(&m->invalid,0); atomic_init(&m->maximum_ticks,0);
    atomic_init(&m->failures,0);
    atomic_init(&m->minimum_frames,UINT32_MAX); atomic_init(&m->maximum_frames,0);
    atomic_init(&m->anomaly_count,0); atomic_init(&m->anomalies_dropped,0);
    atomic_init(&m->cpu_measured,0); atomic_init(&m->cpu_clock_failures,0);
    atomic_init(&m->maximum_cpu_nanoseconds,0); atomic_init(&m->maximum_cpu_clock_ticks,0);
    atomic_init(&m->cpu_event_count,0); atomic_init(&m->cpu_events_dropped,0);
    atomic_init(&m->prime_count,0); atomic_init(&m->prime_dropped,0);
    atomic_init(&m->prime_invalid,0); atomic_init(&m->prime_cpu_unavailable,0);
    // Fault in diagnostic storage before the source callback can use it.
    volatile unsigned char *pages=(volatile unsigned char *)m->anomalies;
    for (size_t i=0;i<sizeof(m->anomalies);i+=256) pages[i]=0;
    pages[sizeof(m->anomalies)-1]=0;
    volatile unsigned char *cpu_pages=(volatile unsigned char *)m->cpu_events;
    for (size_t i=0;i<sizeof(m->cpu_events);i+=256) cpu_pages[i]=0;
    cpu_pages[sizeof(m->cpu_events)-1]=0;
    volatile unsigned char *prime_pages=(volatile unsigned char *)m->prime_events;
    for (size_t i=0;i<sizeof(m->prime_events);i+=256) prime_pages[i]=0;
    prime_pages[sizeof(m->prime_events)-1]=0;
    return m;
}
void tdj_callback_metrics_destroy(tdj_callback_metrics *m) { free(m); }
uint64_t tdj_callback_metrics_begin(void) { return mach_absolute_time(); }
void tdj_callback_metrics_end(tdj_callback_metrics *m, uint64_t began, uint32_t frames, double sample_time, bool valid_time) {
    if (!frames) return;
    const uint64_t ended = mach_absolute_time(), elapsed = ended - began;
    uint32_t flags=0;
    const bool had_expected=m->has_sample_time;
    const double expected=m->next_sample_time;
    const uint64_t callback=atomic_fetch_add_explicit(&m->callbacks,1,memory_order_relaxed)+1;
    atomic_fetch_add_explicit(&m->frames,frames,memory_order_relaxed);
    if ((double)elapsed > frames * m->ticks_per_frame) {
        atomic_fetch_add_explicit(&m->overruns,1,memory_order_relaxed);
        flags|=TDJ_CALLBACK_TIMING_DEADLINE;
    }
    if (elapsed > atomic_load_explicit(&m->maximum_ticks,memory_order_relaxed))
        atomic_store_explicit(&m->maximum_ticks,elapsed,memory_order_relaxed);
    if (frames < atomic_load_explicit(&m->minimum_frames,memory_order_relaxed))
        atomic_store_explicit(&m->minimum_frames,frames,memory_order_relaxed);
    if (frames > atomic_load_explicit(&m->maximum_frames,memory_order_relaxed))
        atomic_store_explicit(&m->maximum_frames,frames,memory_order_relaxed);
    if (valid_time && isfinite(sample_time)) {
        if (m->has_sample_time && fabs(sample_time-m->next_sample_time) > 0.5) {
            atomic_fetch_add_explicit(&m->gaps,1,memory_order_relaxed);
            flags|=TDJ_CALLBACK_TIMING_SAMPLE_GAP;
        }
        m->next_sample_time = sample_time + frames;
        m->has_sample_time = true;
    } else {
        atomic_fetch_add_explicit(&m->invalid,1,memory_order_relaxed);
        m->has_sample_time = false;
        flags|=TDJ_CALLBACK_TIMING_INVALID_TIME;
    }
    if (flags) {
        const uint32_t index=atomic_load_explicit(&m->anomaly_count,memory_order_relaxed);
        if (index<TDJ_CALLBACK_TIMING_ANOMALY_CAPACITY) {
            m->anomalies[index]=(tdj_callback_timing_anomaly){
                .callback_index=callback,.began_ticks=began,.ended_ticks=ended,.frames=frames,.flags=flags,
                .duration_microseconds=elapsed*m->microseconds_per_tick,
                .sample_time=sample_time,.expected_sample_time=expected,
                .previous_began_ticks=m->previous_began_ticks,.previous_ended_ticks=m->previous_ended_ticks,
                .previous_frames=m->previous_frames,.previous_callback_valid=m->has_previous_callback,
                .sample_time_valid=valid_time && isfinite(sample_time),.expected_sample_time_valid=had_expected
            };
            atomic_store_explicit(&m->anomaly_count,index+1,memory_order_release);
        } else atomic_fetch_add_explicit(&m->anomalies_dropped,1,memory_order_relaxed);
    }
    m->previous_began_ticks=began; m->previous_ended_ticks=ended;
    m->previous_frames=frames; m->has_previous_callback=true;
}
void tdj_callback_metrics_failure(tdj_callback_metrics *m) { atomic_fetch_add_explicit(&m->failures,1,memory_order_relaxed); }
tdj_callback_summary tdj_callback_metrics_summary(const tdj_callback_metrics *m) {
    tdj_callback_summary s = {0};
    if (!m) return s;
    s.callbacks=atomic_load_explicit(&m->callbacks,memory_order_relaxed);
    s.frames=atomic_load_explicit(&m->frames,memory_order_relaxed);
    s.deadline_overruns=atomic_load_explicit(&m->overruns,memory_order_relaxed);
    s.timestamp_gaps=atomic_load_explicit(&m->gaps,memory_order_relaxed);
    s.invalid_timestamps=atomic_load_explicit(&m->invalid,memory_order_relaxed);
    s.render_failures=atomic_load_explicit(&m->failures,memory_order_relaxed);
    s.maximum_microseconds=atomic_load_explicit(&m->maximum_ticks,memory_order_relaxed)*m->microseconds_per_tick;
    s.minimum_frames=s.callbacks ? atomic_load_explicit(&m->minimum_frames,memory_order_relaxed) : 0;
    s.maximum_frames=atomic_load_explicit(&m->maximum_frames,memory_order_relaxed);
    return s;
}

uint32_t tdj_callback_metrics_anomaly_count(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->anomaly_count,memory_order_acquire) : 0;
}
uint64_t tdj_callback_metrics_anomalies_dropped(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->anomalies_dropped,memory_order_relaxed) : 0;
}
bool tdj_callback_metrics_anomaly(const tdj_callback_metrics *m, uint32_t index, tdj_callback_timing_anomaly *event) {
    if (!m || !event || index>=tdj_callback_metrics_anomaly_count(m)) return false;
    *event=m->anomalies[index];
    return true;
}

// The override is used only by pure CPU-clock failure tests.
#ifndef TDJ_CALLBACK_CPU_CLOCK_GETTIME
#define TDJ_CALLBACK_CPU_CLOCK_GETTIME clock_gettime
#endif
static bool callback_cpu_clock(uint64_t *nanoseconds) {
    struct timespec value;
    if (TDJ_CALLBACK_CPU_CLOCK_GETTIME(CLOCK_THREAD_CPUTIME_ID,&value)!=0 ||
        value.tv_sec<0 || value.tv_nsec<0 || value.tv_nsec>=1000000000 ||
        (uint64_t)value.tv_sec>UINT64_MAX/1000000000) return false;
    const uint64_t seconds=(uint64_t)value.tv_sec*1000000000;
    if (UINT64_MAX-seconds<(uint64_t)value.tv_nsec) return false;
    *nanoseconds=seconds+(uint64_t)value.tv_nsec;
    return true;
}
uint64_t tdj_callback_metrics_begin_cpu(tdj_callback_metrics *m) {
    const uint64_t began=mach_absolute_time();
    // Explicit diagnostic mode only. Do not alter the render thread's FP state.
    m->cpu_mach_thread=pthread_mach_thread_np(pthread_self());
    m->cpu_thread_context_valid=m->cpu_mach_thread!=0;
    m->cpu_is_main_thread=pthread_main_np()!=0;
#if defined(__aarch64__) || defined(__arm64__)
    __asm__ volatile("mrs %0, fpcr" : "=r"(m->cpu_arm_fpcr));
    m->cpu_arm_fpcr_valid=true;
#endif
    m->cpu_began_valid=callback_cpu_clock(&m->cpu_began_nanoseconds);
    m->cpu_begin_clock_ticks=mach_absolute_time()-began;
    return began;
}
void tdj_callback_metrics_end_cpu(tdj_callback_metrics *m,uint64_t began,
                                 uint32_t frames,double sample_time,bool valid_time) {
    if (!frames) { m->cpu_began_valid=false; return; }
    const uint32_t events_before=atomic_load_explicit(&m->anomaly_count,memory_order_relaxed);
    const uint64_t drops_before=atomic_load_explicit(&m->anomalies_dropped,memory_order_relaxed);
    uint64_t cpu_ended=0;
    const uint64_t clock_began=mach_absolute_time();
    const bool cpu_end_valid=callback_cpu_clock(&cpu_ended);
    const uint64_t clock_ticks=m->cpu_begin_clock_ticks+mach_absolute_time()-clock_began;
    // Keep both diagnostic clock reads inside the measured callback wall time.
    tdj_callback_metrics_end(m,began,frames,sample_time,valid_time);
    const bool valid=m->cpu_began_valid && cpu_end_valid && cpu_ended>=m->cpu_began_nanoseconds;
    const uint64_t cpu_elapsed=valid ? cpu_ended-m->cpu_began_nanoseconds:0;
    if (valid) {
        atomic_fetch_add_explicit(&m->cpu_measured,1,memory_order_relaxed);
        if (cpu_elapsed>atomic_load_explicit(&m->maximum_cpu_nanoseconds,memory_order_relaxed))
            atomic_store_explicit(&m->maximum_cpu_nanoseconds,cpu_elapsed,memory_order_relaxed);
    } else {
        uint64_t failures=(!m->cpu_began_valid)+(!cpu_end_valid);
        if (!failures) failures=1; // A non-monotonic successful clock pair.
        atomic_fetch_add_explicit(&m->cpu_clock_failures,failures,memory_order_relaxed);
    }
    if (clock_ticks>atomic_load_explicit(&m->maximum_cpu_clock_ticks,memory_order_relaxed))
        atomic_store_explicit(&m->maximum_cpu_clock_ticks,clock_ticks,memory_order_relaxed);
    const bool anomaly=events_before!=atomic_load_explicit(&m->anomaly_count,memory_order_relaxed) ||
        drops_before!=atomic_load_explicit(&m->anomalies_dropped,memory_order_relaxed);
    // Keep the first invocation even when it meets the wall deadline.
    if (anomaly || atomic_load_explicit(&m->callbacks,memory_order_relaxed)==1) {
        const uint32_t index=atomic_load_explicit(&m->cpu_event_count,memory_order_relaxed);
        if (index<TDJ_CALLBACK_TIMING_ANOMALY_CAPACITY) {
            m->cpu_events[index]=(tdj_callback_cpu_event){
                .callback_index=atomic_load_explicit(&m->callbacks,memory_order_relaxed),
                .cpu_microseconds=cpu_elapsed/1000.0,
                .clock_read_microseconds=clock_ticks*m->microseconds_per_tick,
                .cpu_time_valid=valid,
                .wall_microseconds=(m->previous_ended_ticks-began)*m->microseconds_per_tick,
                .arm_fpcr=m->cpu_arm_fpcr,.mach_thread=m->cpu_mach_thread,
                .thread_context_valid=m->cpu_thread_context_valid,
                .is_main_thread=m->cpu_is_main_thread,.arm_fpcr_valid=m->cpu_arm_fpcr_valid
            };
            atomic_store_explicit(&m->cpu_event_count,index+1,memory_order_release);
        } else atomic_fetch_add_explicit(&m->cpu_events_dropped,1,memory_order_relaxed);
    }
    m->cpu_began_valid=false;
}
tdj_callback_cpu_summary tdj_callback_metrics_cpu_summary(const tdj_callback_metrics *m) {
    tdj_callback_cpu_summary s={0};
    if (!m) return s;
    s.measured_callbacks=atomic_load_explicit(&m->cpu_measured,memory_order_relaxed);
    s.clock_failures=atomic_load_explicit(&m->cpu_clock_failures,memory_order_relaxed);
    s.maximum_cpu_nanoseconds=atomic_load_explicit(&m->maximum_cpu_nanoseconds,memory_order_relaxed);
    s.maximum_clock_read_microseconds=atomic_load_explicit(&m->maximum_cpu_clock_ticks,memory_order_relaxed)*m->microseconds_per_tick;
    return s;
}
uint32_t tdj_callback_metrics_cpu_event_count(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->cpu_event_count,memory_order_acquire):0;
}
uint64_t tdj_callback_metrics_cpu_events_dropped(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->cpu_events_dropped,memory_order_relaxed):0;
}
bool tdj_callback_metrics_cpu_event(const tdj_callback_metrics *m,uint32_t index,tdj_callback_cpu_event *event) {
    if (!m || !event || index>=tdj_callback_metrics_cpu_event_count(m)) return false;
    *event=m->cpu_events[index];
    return true;
}

bool tdj_callback_metrics_thread_cpu_nanoseconds(uint64_t *nanoseconds) {
    return nanoseconds && callback_cpu_clock(nanoseconds);
}
void tdj_callback_metrics_keylock_prime(tdj_callback_metrics *m,const tdj_keylock_prime_measurement *p) {
    if (!m) return;
    if (!p || p->deck>1 || !isfinite(p->source_frame) || !isfinite(p->speed) || p->speed<=0 ||
        p->reset_done_ticks<p->began_ticks || p->history_done_ticks<p->reset_done_ticks ||
        p->preroll_done_ticks<p->history_done_ticks) {
        atomic_fetch_add_explicit(&m->prime_invalid,1,memory_order_relaxed);
        return;
    }
    const bool cpu_valid=p->cpu_valid && p->cpu_ended_nanoseconds>=p->cpu_began_nanoseconds;
    if (!cpu_valid) atomic_fetch_add_explicit(&m->prime_cpu_unavailable,1,memory_order_relaxed);
    const uint32_t index=atomic_load_explicit(&m->prime_count,memory_order_relaxed);
    if (index>=TDJ_KEYLOCK_PRIME_EVENT_CAPACITY) {
        atomic_fetch_add_explicit(&m->prime_dropped,1,memory_order_relaxed);
        return;
    }
    uint64_t processing_fpcr=m->cpu_arm_fpcr;
    bool processing_fpcr_valid=m->cpu_arm_fpcr_valid;
#if defined(__aarch64__) || defined(__arm64__)
    __asm__ volatile("mrs %0, fpcr" : "=r"(processing_fpcr));
    processing_fpcr_valid=true;
#endif
    m->prime_events[index]=(tdj_keylock_prime_event){
        .callback_index=atomic_load_explicit(&m->callbacks,memory_order_relaxed)+1,
        .began_ticks=p->began_ticks,.reset_done_ticks=p->reset_done_ticks,
        .history_done_ticks=p->history_done_ticks,.ended_ticks=p->preroll_done_ticks,
        .deck=p->deck,.source_frame=p->source_frame,.speed=p->speed,
        .arm_fpcr=processing_fpcr,.mach_thread=m->cpu_mach_thread,
        .thread_context_valid=m->cpu_thread_context_valid,
        .is_main_thread=m->cpu_is_main_thread,.arm_fpcr_valid=processing_fpcr_valid,
        .reset_microseconds=(p->reset_done_ticks-p->began_ticks)*m->microseconds_per_tick,
        .history_microseconds=(p->history_done_ticks-p->reset_done_ticks)*m->microseconds_per_tick,
        .preroll_microseconds=(p->preroll_done_ticks-p->history_done_ticks)*m->microseconds_per_tick,
        .total_microseconds=(p->preroll_done_ticks-p->began_ticks)*m->microseconds_per_tick,
        .cpu_microseconds=cpu_valid ? (p->cpu_ended_nanoseconds-p->cpu_began_nanoseconds)/1000.0:0,
        .cpu_clock_microseconds=p->cpu_clock_ticks*m->microseconds_per_tick,
        .cpu_time_valid=cpu_valid
    };
    atomic_store_explicit(&m->prime_count,index+1,memory_order_release);
}
uint32_t tdj_callback_metrics_keylock_prime_count(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->prime_count,memory_order_acquire):0;
}
uint64_t tdj_callback_metrics_keylock_prime_dropped(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->prime_dropped,memory_order_relaxed):0;
}
uint64_t tdj_callback_metrics_keylock_prime_invalid(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->prime_invalid,memory_order_relaxed):0;
}
uint64_t tdj_callback_metrics_keylock_prime_cpu_unavailable(const tdj_callback_metrics *m) {
    return m ? atomic_load_explicit(&m->prime_cpu_unavailable,memory_order_relaxed):0;
}
bool tdj_callback_metrics_keylock_prime_event(const tdj_callback_metrics *m,uint32_t index,tdj_keylock_prime_event *event) {
    if (!m || !event || index>=tdj_callback_metrics_keylock_prime_count(m)) return false;
    *event=m->prime_events[index];
    return true;
}
