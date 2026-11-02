#ifndef TDJ_STREAMING_H
#define TDJ_STREAMING_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif

typedef struct tdj_asset tdj_asset;
#define TDJ_STREAM_BLOCK_FRAMES 8192u
#define TDJ_STREAM_BLOCK_COUNT 512u
#define TDJ_STREAM_MAX_RANGES 64u
#define TDJ_STREAM_MAX_TICKETS 16u
#define TDJ_STREAM_GLOBAL_PCM_BYTES (128ull * 1024ull * 1024ull)

typedef struct {
    uint64_t first, end;
    uint32_t priority, reserved;
} tdj_stream_range;
typedef struct {
    uint64_t request_id, deck_generation;
    uint32_t count, reserved;
    tdj_stream_range ranges[TDJ_STREAM_MAX_RANGES];
} tdj_stream_request;
typedef struct {
    double position, source_speed, performance_rate, loop_start, loop_end, continuing_position;
    uint32_t keylock, reserve_continuing;
} tdj_stream_target;
typedef struct {
    double output_rate, forward_seconds, backward_seconds;
    uint32_t max_output_frames, reserved;
} tdj_stream_config;
enum tdj_stream_status {
    TDJ_STREAM_INVALID=-1, TDJ_STREAM_IO_ERROR=-2, TDJ_STREAM_CAPACITY=-3,
    TDJ_STREAM_CANCELLED=-4, TDJ_STREAM_UNSUPPORTED_ATOMICS=-5,
    TDJ_STREAM_PENDING=0, TDJ_STREAM_READY=1
};
typedef struct {
    /* Pool allocation, not a measurement or guarantee of OS page residency. */
    uint64_t resident_pcm_bytes, global_reserved_pcm_bytes, ready_table_serial;
    uint64_t source_read_misses, missing_output_frames, first_missing_output_frame, latest_missing_source_frame;
    uint64_t low_reserve_callbacks, rejected_cold_commands, io_errors, capacity_failures;
    uint64_t retirement_backpressure, request_backpressure, bytes_read, max_service_nanoseconds;
    uint64_t minimum_forward_ready_frames;
} tdj_stream_telemetry;
typedef struct {
    uint32_t delay_microseconds_per_read, maximum_bytes_per_read;
    uint64_t fail_after_bytes;
} tdj_stream_test_io;

/* Open/service/destroy run on the preparation or disposal queue. */
tdj_asset *tdj_asset_open_stream(const char *, uint64_t frames, double source_rate,
    const tdj_stream_config *, int32_t *error);
/* One serial control producer. A ticket is single-use after command acceptance;
   one command may share it across both decks. Release after acknowledgement even
   though native live handoff retires its ranges without producer polling.
   Unconsumed preparations may report CAPACITY if moving live ranges revoke their
   working-set reservation. Obtain a new ticket after any terminal status. */
uint64_t tdj_asset_request_prepare(tdj_asset *, const tdj_stream_request *);
int32_t tdj_asset_prepare_status(const tdj_asset *, uint64_t ticket);
void tdj_asset_release_preparation(tdj_asset *, uint64_t ticket);
int32_t tdj_asset_plan_target(const tdj_asset *, const tdj_stream_target *,
    uint64_t request_id, uint64_t deck_generation, tdj_stream_request *);
int32_t tdj_asset_plan_minimum(const tdj_asset *, const tdj_stream_target *,
    uint64_t request_id, uint64_t deck_generation, tdj_stream_request *);
/* One serial worker per asset. A pass reads at most maximum_blocks blocks. */
int32_t tdj_asset_service(tdj_asset *, uint32_t maximum_blocks);
void tdj_asset_cancel_service(tdj_asset *);
void tdj_asset_stream_telemetry(const tdj_asset *, tdj_stream_telemetry *);
uint64_t tdj_stream_reserved_pcm_bytes(void);
int32_t tdj_asset_set_test_io(tdj_asset *, const tdj_stream_test_io *);
#ifdef __cplusplus
}
#endif
#endif
