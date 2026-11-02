#ifndef TDJ_ASSET_INTERNAL_H
#define TDJ_ASSET_INTERNAL_H
#include "include/TDJTransport.h"
#include <stddef.h>
typedef struct tdj_stream tdj_stream;
struct tdj_asset {
    const float *samples;
    uint64_t frames;
    double rate;
    size_t bytes;
    bool mapped;
    tdj_stream *stream;
};
void tdj_stream_destroy(tdj_asset *);
int tdj_stream_attach(tdj_asset *, const void *engine);
void tdj_stream_detach(tdj_asset *, const void *engine);
void tdj_stream_render_begin(tdj_asset *, uint64_t output_frame);
bool tdj_stream_render_read_stereo(void *, uint64_t, float *, float *);
const float *tdj_stream_render_span(void *, uint64_t, uint32_t *);
void tdj_stream_render_request(tdj_asset *, const tdj_stream_request *);
void tdj_stream_render_require(tdj_asset *, const tdj_stream_request *);
void tdj_stream_render_end(tdj_asset *, uint64_t missing_output_frames);
bool tdj_stream_covers(tdj_asset *, const tdj_stream_request *);
int tdj_stream_check_ticket(tdj_asset *, uint64_t ticket, uint64_t generation);
void tdj_stream_claim(tdj_asset *, uint64_t ticket);
void tdj_stream_release_claim(tdj_asset *, uint64_t ticket);
uint64_t tdj_stream_acknowledged_request(tdj_asset *);
uint64_t tdj_stream_next_request(tdj_asset *);
uint64_t tdj_stream_latest_request(tdj_asset *);
bool tdj_stream_read_failed(tdj_asset *);
void tdj_stream_cold(tdj_asset *);
void tdj_stream_observe_reserve(tdj_asset *, double position, bool low);
void tdj_stream_missing_frame(tdj_asset *, uint64_t output_frame);
bool tdj_stream_can_render(tdj_asset *, uint32_t frames);
void tdj_stream_set_maximum_output_frames(tdj_asset *, uint32_t frames);
typedef struct {
    tdj_stream_target target;
    uint32_t moving, continuing_moves, timeline, continuing_timeline;
} tdj_stream_future;
int tdj_stream_future_capacity(tdj_asset *, const tdj_stream_future *, unsigned count, uint32_t maximum_override);

void tdj_stream_mark_started(tdj_asset *);
int tdj_stream_plan(tdj_asset *, const tdj_stream_target *, uint64_t, uint64_t,
    bool reserve, tdj_stream_request *);
bool tdj_keylock_limits(double rate, int *input, int *output, int *seek);
#endif
