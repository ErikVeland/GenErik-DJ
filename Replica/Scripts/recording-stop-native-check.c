// White-box model of a producer preempted after acquiring the capture gate.
// Only this test sees the private ring; production exposes no test hooks.
#include "../Sources/CTDJTransport/TDJRecording.c"
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <time.h>

typedef struct { tdj_recording *ring; _Atomic bool returned; } Stop;
static void *join_capture(void *argument) {
    Stop *stop = argument;
    tdj_recording_stop(stop->ring);
    atomic_store_explicit(&stop->returned, true, memory_order_release);
    return NULL;
}
static void await_closed_gate(tdj_recording *ring) {
    for (unsigned i = 0; i < 2000; ++i) {
        if (!(atomic_load_explicit(&ring->gate, memory_order_acquire) & 1u)) return;
        struct timespec delay = {0, 1000000}; nanosleep(&delay, NULL);
    }
    assert(!"stop did not close capture gate");
}
int main(void) {
    tdj_recording *ring = tdj_recording_create(7); assert(ring);
    tdj_recording_start(ring);
    unsigned expected = 1;
    assert(atomic_compare_exchange_strong(&ring->gate, &expected, 3));
#ifdef TDJ_TEST_REQUEST_STOP
    tdj_recording_request_stop(ring);
    assert(atomic_load(&ring->gate) == 2); // Request returned while producer remains held.
#endif
    Stop stop = {.ring = ring}; atomic_init(&stop.returned, false);
    pthread_t waiter; assert(!pthread_create(&waiter, NULL, join_capture, &stop));
    await_closed_gate(ring);
    assert(!atomic_load_explicit(&stop.returned, memory_order_acquire));
    // A new callback cannot enter after the request, even before the old copy finishes.
    float rejected[2] = {0.9f, 0.9f};
    tdj_recording_push(ring, 2, rejected, rejected);
    assert(tdj_recording_captured(ring) == 0);
    // Complete the accepted in-flight copy with the production publication order.
    for (unsigned i = 0; i < 3; ++i) { ring->samples[2*i] = 0.125f; ring->samples[2*i+1] = -0.25f; }
    atomic_store_explicit(&ring->write, 3, memory_order_release);
    atomic_fetch_and_explicit(&ring->gate, ~2u, memory_order_release);
    assert(!pthread_join(waiter, NULL));
    assert(atomic_load_explicit(&stop.returned, memory_order_acquire));
    float left[7], right[7];
    assert(tdj_recording_read(ring, 7, left, right) == 3);
    for (unsigned i = 0; i < 3; ++i) { assert(left[i] == 0.125f); assert(right[i] == -0.25f); }
    assert(tdj_recording_captured(ring) == 3 && !tdj_recording_dropped(ring));
    tdj_recording_start(ring);
    assert(tdj_recording_captured(ring) == 0 && !tdj_recording_failed(ring));
    tdj_recording_push(ring, 2, rejected, rejected);
    tdj_recording_stop(ring);
    assert(tdj_recording_read(ring, 7, left, right) == 2);
    assert(left[0] == 0.9f && right[1] == 0.9f);
    tdj_recording_destroy(ring);
#ifdef TDJ_TEST_REQUEST_STOP
    puts("PASS: stop request returns with held producer; writer joins; accepted frames retained; later callbacks rejected; restart clean.");
#else
    puts("REPRODUCED: blocking stop cannot return while accepted producer is held; accepted frames retained after release.");
#endif
}
