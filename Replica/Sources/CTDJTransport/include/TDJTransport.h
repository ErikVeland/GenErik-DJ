#ifndef TDJ_TRANSPORT_H
#define TDJ_TRANSPORT_H
#include <stdint.h>
#include <stdbool.h>
#include "TDJRecording.h"
#include "TDJCallbackMetrics.h"
#include "TDJStreaming.h"
#ifdef __cplusplus
extern "C" {
#endif

typedef struct tdj_asset tdj_asset;
typedef struct tdj_engine tdj_engine;

#define TDJ_DECK_COUNT 4
#define TDJ_LOAD 1
#define TDJ_LOAD_RESET_IDLE_TEMPO 16
#define TDJ_PLAY 2
#define TDJ_PLAY_ALIGN_ENTRY 1
#define TDJ_TEMPO 3
#define TDJ_SYNC 4
#define TDJ_GRID 5
#define TDJ_PANIC 6
#define TDJ_SEEK 7
#define TDJ_KEYLOCK 8
#define TDJ_MIXER 9
#define TDJ_JUMP 10
#define TDJ_LOOP 11
#define TDJ_FLUX 12
#define TDJ_TOUCH 13
// Disabled touch commands can park the deck if release audio is unavailable.
#define TDJ_TOUCH_PARK_RELEASE -1
#define TDJ_TOUCH_CUE_PARK -2
#define TDJ_TOUCH_CUE_CONTINUE -3
#define TDJ_TOUCH_WITH_RATE 3
#define TDJ_TOUCH_FOLLOWS_POSITION 4
#define TDJ_RATE 14
#define TDJ_FX 15
#define TDJ_CUE_RECALL 16
#define TDJ_SYNC_RESTORE 17
#define TDJ_FREE_RATE 18
#define TDJ_ADAPTIVE_GRID 19
#define TDJ_RECOVERY_REPLAY 20
#define TDJ_RECOVERY_MIX 21
#define TDJ_RECOVERY_CANCEL 22
#define TDJ_BRAKE 23
#define TDJ_PAD_LOAD 24
#define TDJ_PAD_PLAY 25
#define TDJ_PAD_GAIN 26
#define TDJ_LOOP_ROLL 27
#define TDJ_EJECT 28
#define TDJ_GRID_METRONOME 29
#define TDJ_LOOP_RECORDER 30
#define TDJ_LOOP_REC_RECORD 0
#define TDJ_LOOP_REC_PLAY 1
#define TDJ_LOOP_REC_UNDO 2
#define TDJ_LOOP_REC_SIZE 3
#define TDJ_LOOP_REC_WET 4
#define TDJ_PAD_COUNT 16
#define TDJ_EFFECT_DELAY 0
#define TDJ_EFFECT_REVERB 1
#define TDJ_EFFECT_FLANGER 2
#define TDJ_EFFECT_GATER 3
#define TDJ_EFFECT_BEATMASHER 4
#define TDJ_EFFECT_DIGITAL_LOFI 5
#define TDJ_EFFECT_HIGH_PASS 6
#define TDJ_EFFECT_LOW_PASS 7
#define TDJ_EFFECT_ICEVERB 8
#define TDJ_EFFECT_TRANSPOSE_STRETCH 9
#define TDJ_EFFECT_REVERSE_GRAIN 10
#define TDJ_EFFECT_COUNT 11
#define TDJ_MIX_CROSSFADE 0
#define TDJ_MIX_MASTER 1
#define TDJ_MIX_MONITOR 2
#define TDJ_MIX_CUE_BLEND 3
#define TDJ_MIX_VOLUME 4
#define TDJ_MIX_GAIN 5
#define TDJ_MIX_LOW 6
#define TDJ_MIX_MID 7
#define TDJ_MIX_HIGH 8
#define TDJ_MIX_CUE 9
#define TDJ_MIX_FILTER_X 10
#define TDJ_MIX_FILTER_Y 11
#define TDJ_MIX_FILTER_ENABLED 12
#define TDJ_MIX_CROSSFADE_ASSIGNMENT 13

#define TDJ_EMPTY 0
#define TDJ_READY 1
#define TDJ_QUEUED 2
#define TDJ_PLAYING 3
#define TDJ_PAUSED 4
#define TDJ_ENDED 5

#define TDJ_OK 0
#define TDJ_STALE 1
#define TDJ_UNRESOLVED 2
#define TDJ_INVALID 3
#define TDJ_PROTECTED 4
#define TDJ_RETIRED 5
#define TDJ_KEYLOCK_RANGE 6
#define TDJ_SOURCE_COLD 7
#define TDJ_SOURCE_CAPACITY 8
#define TDJ_ALIGNMENT_UNAVAILABLE 9
#define TDJ_ACTIVE_PERFORMANCE 10

#define TDJ_MAX_GRID_ANCHORS 256
typedef struct {
    uint32_t count;
    int32_t downbeat;
    double sample_rate;
    double beats[TDJ_MAX_GRID_ANCHORS], frames[TDJ_MAX_GRID_ANCHORS];
} tdj_beatgrid_map;
bool tdj_beatgrid_validate(tdj_beatgrid_map map, uint64_t frame_count);
double tdj_beatgrid_frame(tdj_beatgrid_map map, double beat);
double tdj_beatgrid_beat(tdj_beatgrid_map map, double frame);

typedef struct {
    int32_t kind, deck, flag;
    uint64_t id, generation, reference_generation;
    double value, value2, value3;
    double touch_rate;
    tdj_asset *asset;
    tdj_beatgrid_map beatgrid;
    uint64_t preparation_ticket, preparation_ticket_b, preparation_generation_b;
    uint64_t preparation_ticket_c, preparation_generation_c, preparation_ticket_d, preparation_generation_d;
} tdj_command;

typedef struct {
    uint64_t command_id, generation;
    int32_t status;
} tdj_message;

typedef struct {
    uint64_t generation, last_start_frame;
    int32_t state, synced, keylock;
    double source_frame, source_bpm, local_bpm, target_beat, source_rate, lead_in_source_frame;
    double source_sample_rate, grid_anchor;
    tdj_beatgrid_map beatgrid;
    int32_t grid_downbeat;
    double volume, gain, low, mid, high, cue, filter_x, filter_y, peak;
    int32_t filter_enabled, crossfader_assignment;
    int32_t loop_enabled, flux_enabled, touch_active, jump_pending, loop_rolling;
    double loop_start, loop_end, continuing_frame, performance_rate;
    double free_rate, touch_start, touch_end, jump_frame, jump_beat, pending_touch_end, pending_loop_end;
    int32_t touch_was_playing, jump_loop;
    double pending_touch_rate;
    int32_t pending_touch_rate_valid;
    int32_t recovery_armed, recovery_active, recovery_mix;
    double recovery_start, recovery_end, recovery_mix_start;
    int32_t braking;
    double brake_rate;
} tdj_deck_snapshot;

typedef struct {
    uint64_t output_frame, paired_frames;
    double sample_rate, master_bpm, master_beat;
    double crossfader, master_gain, monitor_gain, cue_blend;
    int32_t clock_running;
    bool extra_decks;
    tdj_deck_snapshot a, b, c, d;
} tdj_snapshot;

tdj_asset *tdj_asset_create(const float *interleaved_stereo, uint64_t frames, double sample_rate);
// Map and prepare the first read of its pages on the loader, never the audio callback.
tdj_asset *tdj_asset_map(const char *path, uint64_t frames, double sample_rate);
void tdj_asset_destroy(tdj_asset *asset);

tdj_engine *tdj_engine_create(double sample_rate, double output_gain);
// The metrics owner must outlive the returned engine. No clocks are added to the ordinary factory.
tdj_engine *tdj_engine_create_keylock_traced(double sample_rate, double output_gain, tdj_callback_metrics *metrics);
void tdj_engine_destroy(tdj_engine *engine);
bool tdj_engine_prepare_extra_decks(tdj_engine *engine);
// Call only with device output stopped. This never waits for the render consumer.
int32_t tdj_engine_configure_maximum_output_frames(tdj_engine *engine, uint32_t frames);
// With device output stopped, check CURRENT minimum coverage for playing/queued
// decks, including pending targets and Flux. Does not adopt tables or change state.
// One guard attempt: OK, SOURCE_COLD or PROTECTED; null engine is INVALID.
int32_t tdj_engine_output_sources_ready(tdj_engine *engine);
// One serial producer. The audio callback is the sole consumer during output.
bool tdj_submit(tdj_engine *engine, tdj_command command);
uint32_t tdj_playing_pads(tdj_engine *engine);
void tdj_microphone_set_enabled(tdj_engine *engine, bool enabled);
void tdj_microphone_push(tdj_engine *engine, const float *samples, uint32_t count, uint32_t stride, double rate);
bool tdj_read_message(tdj_engine *engine, tdj_message *message);
uint64_t tdj_rendered_output_frame(const tdj_engine *engine);
bool tdj_read_snapshot(tdj_engine *engine, tdj_snapshot *snapshot);
// No allocation, file API calls, logging or explicit waiting occurs here.
// Clean mapped pages remain subject to host-managed reclamation and paging.
// A zero-frame call processes controls while device output is stopped.
bool tdj_render(tdj_engine *engine, uint32_t count, float *left, float *right);
// Same render pass, with a separate stereo headphone bus. Null monitor pointers discard that bus.
void tdj_external_input_push(tdj_engine *engine, const float *left, const float *right, uint32_t count,
                             uint32_t stride, double rate);
bool tdj_loop_recorder_prepare(tdj_engine *engine);
void tdj_loop_recorder_enable(tdj_engine *engine, bool enabled);
int32_t tdj_loop_recorder_state(tdj_engine *engine);
bool tdj_loop_recorder_request_export(tdj_engine *engine);
int32_t tdj_loop_recorder_export_frames(tdj_engine *engine);
bool tdj_loop_recorder_export(tdj_engine *engine, float *stereo, uint32_t count);
void tdj_loop_recorder_finish_export(tdj_engine *engine);
void tdj_s4_mk1_input_set_enabled(tdj_engine *engine, bool enabled);
void tdj_s4_input_set_channels(tdj_engine *engine, uint32_t channels);
void tdj_s4_mic_set_level(tdj_engine *engine, double level);
void tdj_s4_input_push(tdj_engine *engine, const float *const *input, const uint32_t *strides,
                       uint32_t count, uint32_t channels, double rate);
void tdj_external_input_mix(tdj_engine *engine, double level, double cue_gain);
typedef struct {
    double left, right;
    bool clip_left, clip_right;
} tdj_master_meter;
void tdj_master_meter_enable(tdj_engine *engine, bool enabled);
tdj_master_meter tdj_master_meter_read(tdj_engine *engine);
void tdj_preview_set_generation(tdj_engine *engine, uint64_t generation);
uint64_t tdj_preview_generation(tdj_engine *engine);
uint64_t tdj_preview_consumed(tdj_engine *engine);
bool tdj_preview_push(tdj_engine *engine, const float *stereo, uint32_t count, double rate, uint64_t generation);
bool tdj_render_buses(tdj_engine *engine, uint32_t count, float *left, float *right, float *cue_left, float *cue_right);
bool tdj_render_recorded_buses(tdj_engine *engine, tdj_recording *recording, uint32_t count, float *left, float *right,
                               float *cue_left, float *cue_right);
#ifdef __cplusplus
}
#endif
#endif
