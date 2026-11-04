#include "TDJTransport.h"
#include "TDJKeylock.h"

// Keep this bridge separate so standalone transport and metrics probes remain independent.
tdj_engine *tdj_engine_create_keylock_traced(double rate, double gain, tdj_callback_metrics *metrics) {
    tdj_engine *engine = tdj_engine_create(rate, gain);
    if (engine && metrics) {
        const tdj_keylock_trace trace = {.metrics = metrics,
                                         .ticks = tdj_callback_metrics_begin,
                                         .cpu_now = tdj_callback_metrics_thread_cpu_nanoseconds,
                                         .record = tdj_callback_metrics_keylock_prime};
        tdj_engine_attach_keylock_trace(engine, &trace);
    }
    return engine;
}
