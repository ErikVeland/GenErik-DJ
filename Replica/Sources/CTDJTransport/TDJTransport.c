#include "TDJTransport.h"
#include "TDJKeylock.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "TDJMixer.h"
#include "TDJEffects.h"
#include "TDJAsset.h"
#include "TDJAuxiliary.h"

#define COMMAND_CAPACITY 128u
#define MESSAGE_CAPACITY 512u

typedef struct {
    tdj_asset *asset;
    uint64_t generation, last_start;
    int32_t state;
    bool synced, keylock;
    tdj_beatgrid_map map;
    bool map_dirty;
    double position, bpm, anchor, downbeat, target, queued_origin, free_rate;
    bool loop_enabled, flux_enabled, touch_active, jump_pending, touch_was_playing;
    double loop_start, loop_end, continuing, performance_rate, jump_frame, jump_beat;
    double touch_start, touch_end, pending_touch_end, pending_loop_end, pending_loop_position;
    bool jump_loop, loop_rolling;
    bool grid_click, grid_click_position_valid;
    double grid_click_offset, grid_click_next, grid_click_last;
    unsigned grid_click_age;
    double pending_touch_rate;
    bool pending_touch_rate_valid;
    double stream_fade;
    float stream_last_l, stream_last_r;
    bool stream_failed, stream_starved;
    bool recovery_armed, recovery_active, recovery_mix, recovery_mixing;
    double recovery_start, recovery_end, recovery_mix_start, recovery_incoming;
    uint64_t recovery_incoming_generation;
    bool braking, brake_primed;
    double brake_rate, brake_seconds, brake_strength, brake_target_strength;
    double brake_phase, brake_cursor;
    float brake_l[2], brake_r[2];
} deck;

// Atomic fields make the snapshot race-free under the C memory model.
typedef struct {
    _Atomic uint64_t generation, last_start;
    _Atomic int32_t state, synced, keylock;
    _Atomic double position, bpm, local_bpm, target, rate, lead;
    _Atomic double source_sample_rate, grid_anchor;
    _Atomic int32_t grid_downbeat;
    _Atomic uint32_t map_count;
    _Atomic int32_t map_downbeat;
    _Atomic double map_rate, map_beats[TDJ_MAX_GRID_ANCHORS], map_frames[TDJ_MAX_GRID_ANCHORS];
    _Atomic double volume, gain, low, mid, high, cue, filter_x, filter_y, peak;
    _Atomic int32_t filter_enabled, crossfader_assignment;
    _Atomic int32_t recovery_armed, recovery_active, recovery_mix;
    _Atomic double recovery_start, recovery_end, recovery_mix_start;
    _Atomic int32_t loop_enabled, flux_enabled, touch_active, jump_pending, loop_rolling;
    _Atomic double loop_start, loop_end, continuing, performance_rate;
    _Atomic double free_rate, touch_start, touch_end, jump_frame, jump_beat, pending_touch_end, pending_loop_end;
    _Atomic int32_t touch_was_playing, jump_loop;
    _Atomic double pending_touch_rate;
    _Atomic int32_t pending_touch_rate_valid;
    _Atomic int32_t braking;
    _Atomic double brake_rate;
} atomic_deck;

typedef struct {
    tdj_asset *asset;
    uint64_t ticket, serial;
    unsigned decks;
    bool pending;
} stream_claim;

// Output history survives source changes. Musical position remains in deck.
typedef struct {
    double last_l, last_r, from_l, from_r;
    unsigned length, remaining, requested;
    bool pending, playing;
} dry_transition;

struct tdj_engine {
    double rate, gain, bpm, epoch_ticks;
    mixer mix;
    performance_fx effects[TDJ_DECK_COUNT][3];
    _Atomic double published_crossfader, published_master, published_monitor, published_cue_blend;
    uint64_t frame, epoch_frame, paired_frames;
    _Atomic uint64_t published_paired_frames;
    bool running, master_chosen;
    uint32_t maximum_output_frames;
    int deck_count;
    _Atomic bool extra_prepared, published_extra;
    atomic_flag extra_allocating;
    deck decks[TDJ_DECK_COUNT];
    tdj_keylock *keylocks[TDJ_DECK_COUNT];
    dry_transition transitions[TDJ_DECK_COUNT];
    tdj_command commands[COMMAND_CAPACITY];
    _Atomic unsigned command_write, command_read;
    tdj_message messages[MESSAGE_CAPACITY];
    _Atomic unsigned message_write, message_read;
    atomic_flag render_busy;
    _Atomic uint64_t snapshot_sequence, published_frame;
    _Atomic double published_bpm, published_beat;
    _Atomic int32_t published_running;
    atomic_deck published[TDJ_DECK_COUNT];
    stream_claim claims[TDJ_STREAM_MAX_TICKETS * TDJ_DECK_COUNT];
    auxiliary_mix auxiliary;
    _Atomic bool master_meter_enabled;
    _Atomic double master_peak[2];
    _Atomic uint32_t master_clip[2];
};

static bool deck_active(const deck *d) { return d->state == TDJ_PLAYING || d->state == TDJ_QUEUED; }
static bool any_deck_active(const tdj_engine *e) {
    return deck_active(&e->decks[0]) || deck_active(&e->decks[1]) ||
           (e->deck_count > 2 && (deck_active(&e->decks[2]) || deck_active(&e->decks[3])));
}
static bool asset_is_used(const tdj_engine *e, const tdj_asset *asset, int first, int end, int excluding) {
    for (int i = first; i < end; ++i)
        if (i != excluding && e->decks[i].asset == asset)
            return true;
    return false;
}
static bool valid_deck_command(const tdj_engine *e, int index) {
    return index >= 0 && index < TDJ_DECK_COUNT &&
           (index < 2 || atomic_load_explicit(&e->extra_prepared, memory_order_acquire));
}

// Two milliseconds suppresses measured transport edges without delaying controls.
// Smoothstep is convex and has zero slope at both ends. It cannot add overshoot.
static void transition_request(tdj_engine *e, int index, unsigned limit) {
    dry_transition *t = &e->transitions[index];
    unsigned length = (unsigned)fmax(2, ceil(e->rate * 0.002));
    if (limit && length > limit)
        length = limit;
    if (length < 2)
        return;
    t->pending = true;
    t->requested = length;
}
static void transition_sample(dry_transition *t, double *l, double *r) {
    if (t->pending) {
        t->pending = false;
        t->from_l = t->last_l;
        t->from_r = t->last_r;
        t->length = t->remaining = t->requested;
        if (*l == t->last_l && *r == t->last_r)
            t->remaining = 0;
    }
    if (t->remaining) {
        if (t->remaining != 1) {
            double phase = (double)(t->length - t->remaining) / (t->length - 1);
            double mix = phase * phase * (3 - 2 * phase);
            *l = t->from_l * (1 - mix) + *l * mix;
            *r = t->from_r * (1 - mix) + *r * mix;
        }
        --t->remaining;
    }
    t->last_l = *l;
    t->last_r = *r;
}

static bool valid_rate(double rate) {
    return isfinite(rate) && rate > 0;
}

tdj_asset *tdj_asset_create(const float *samples, uint64_t frames, double rate) {
    if (!samples || !frames || frames > SIZE_MAX / (2 * sizeof(float)) || !valid_rate(rate))
        return NULL;
    tdj_asset *asset = calloc(1, sizeof(*asset));
    if (!asset)
        return NULL;
    asset->bytes = (size_t)frames * 2 * sizeof(float);
    float *copy = malloc(asset->bytes);
    if (!copy) {
        free(asset);
        return NULL;
    }
    memcpy(copy, samples, asset->bytes);
    asset->samples = copy;
    asset->frames = frames;
    asset->rate = rate;
    return asset;
}

tdj_asset *tdj_asset_map(const char *path, uint64_t frames, double rate) {
    if (!path || !frames || frames > SIZE_MAX / (2 * sizeof(float)) || !valid_rate(rate))
        return NULL;
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return NULL;
    size_t bytes = (size_t)frames * 2 * sizeof(float);
    struct stat info;
    if (fstat(fd, &info) || info.st_size < 0 || (uint64_t)info.st_size != bytes) {
        close(fd);
        return NULL;
    }
    void *mapping = mmap(NULL, bytes, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (mapping == MAP_FAILED)
        return NULL;
    // Complete the first read of each mapped page on the loader, before a deck
    // becomes ready. A page-in must not be deferred to its first audio sample.
    // These clean pages remain reclaimable. This does not lock track-sized RAM.
    (void)madvise(mapping, bytes, MADV_WILLNEED);
    long system_page = sysconf(_SC_PAGESIZE);
    size_t page = system_page > 0 ? (size_t)system_page : 4096;
    const volatile unsigned char *source = mapping;
    for (size_t offset = 0; offset < bytes;) {
        (void)source[offset];
        if (bytes - offset <= page)
            break;
        offset += page;
    }
    tdj_asset *asset = calloc(1, sizeof(*asset));
    if (!asset) {
        munmap(mapping, bytes);
        return NULL;
    }
    asset->samples = mapping;
    asset->frames = frames;
    asset->rate = rate;
    asset->bytes = bytes;
    asset->mapped = true;
    return asset;
}

void tdj_asset_destroy(tdj_asset *asset) {
    if (!asset)
        return;
    if (asset->stream)
        tdj_stream_destroy(asset);
    else if (asset->mapped)
        munmap((void *)asset->samples, asset->bytes);
    else
        free((void *)asset->samples);
    free(asset);
}

bool tdj_beatgrid_validate(tdj_beatgrid_map m, uint64_t frames) {
    if (m.count < 2 || m.count > TDJ_MAX_GRID_ANCHORS || !valid_rate(m.sample_rate) || m.downbeat < 0 ||
        m.downbeat > 3 || !frames)
        return false;
    for (unsigned i = 0; i < m.count; i++) {
        if (!isfinite(m.beats[i]) || !isfinite(m.frames[i]) || m.frames[i] < 0 || m.frames[i] >= frames)
            return false;
        if (i) {
            double beats = m.beats[i] - m.beats[i - 1], delta = m.frames[i] - m.frames[i - 1];
            double bpm = 60 * m.sample_rate * beats / delta;
            if (!isfinite(beats) || !isfinite(delta) || beats <= 0 || delta <= 0 || !isfinite(bpm) || bpm < 20 ||
                bpm > 400)
                return false;
        }
    }
    return true;
}
static unsigned map_segment(const tdj_beatgrid_map *m, double value, bool inverse) {
    const double *x = inverse ? m->frames : m->beats;
    unsigned low = 0, high = m->count - 1;
    while (low + 1 < high) {
        unsigned mid = (low + high) / 2;
        if (x[mid] <= value)
            low = mid;
        else
            high = mid;
    }
    return low;
}
static double map_lookup(const tdj_beatgrid_map *m, double value, bool inverse) {
    if (m->count < 2 || m->count > TDJ_MAX_GRID_ANCHORS || !isfinite(value))
        return NAN;
    const double *x = inverse ? m->frames : m->beats, *y = inverse ? m->beats : m->frames;
    unsigned i = map_segment(m, value, inverse);
    return y[i] + (value - x[i]) * (y[i + 1] - y[i]) / (x[i + 1] - x[i]);
}
double tdj_beatgrid_frame(tdj_beatgrid_map m, double beat) {
    return map_lookup(&m, beat, false);
}
double tdj_beatgrid_beat(tdj_beatgrid_map m, double frame) {
    return map_lookup(&m, frame, true);
}
static double deck_beat(deck *d, double frame) {
    return d->map.count ? map_lookup(&d->map, frame, true) : (frame - d->anchor) * d->bpm / (60 * d->asset->rate);
}
static double deck_frame(deck *d, double beat) {
    return d->map.count ? map_lookup(&d->map, beat, false) : d->anchor + beat * 60 * d->asset->rate / d->bpm;
}
static double grid_click_sample(deck *d, double rate, double step) {
    double frame = d->position - d->grid_click_offset;
    if (!d->grid_click_position_valid || frame < d->grid_click_last ||
        frame - d->grid_click_last > 2 * fmax(1, fabs(step))) {
        d->grid_click_next = deck_frame(d, ceil(deck_beat(d, frame) - 1e-9));
        d->grid_click_position_valid = true;
        d->grid_click_age = 0;
    }
    d->grid_click_last = frame;
    if (frame >= d->grid_click_next - 1e-8) {
        d->grid_click_next = deck_frame(d, floor(deck_beat(d, frame) + 1e-9) + 1);
        d->grid_click_age = 1;
    }
    if (!d->grid_click_age)
        return 0;
    double seconds = (d->grid_click_age++ - 1) / rate;
    if (seconds >= 0.012) {
        d->grid_click_age = 0;
        return 0;
    }
    double envelope = fmin(seconds * 1000, 1) * (1 - seconds / 0.012);
    double phase = seconds * 1500;
    double triangle = 1 - 4 * fabs(phase - floor(phase) - 0.5);
    return 0.16 * envelope * triangle;
}
static double deck_bpm_at(deck *d, double frame) {
    if (!d->map.count)
        return d->bpm;
    unsigned i = map_segment(&d->map, frame, true);
    return 60 * d->map.sample_rate * (d->map.beats[i + 1] - d->map.beats[i]) /
           (d->map.frames[i + 1] - d->map.frames[i]);
}
static double deck_bpm(deck *d) {
    return deck_bpm_at(d, d->position);
}
static double ticks_now(tdj_engine *e) {
    return e->epoch_ticks + (e->running ? (double)(e->frame - e->epoch_frame) * e->bpm : 0);
}
static double beat_now(tdj_engine *e) {
    return ticks_now(e) / (60 * e->rate);
}
static double source_rate(tdj_engine *e, deck *d) {
    return !d->braking && d->synced && d->bpm > 0 ? e->bpm / deck_bpm(d) : d->free_rate;
}
// Effects follow the master clock when synced, otherwise the deck's own grid.
static void effect_clock(tdj_engine *e, int index, double *bpm, double *beat) {
    deck *d = &e->decks[index];
    double tempo = d->asset && !d->synced && d->bpm > 0 ? d->bpm * d->free_rate : 0;
    if (!(isfinite(tempo) && tempo > 0) || !isfinite(d->position)) {
        *bpm = e->bpm;
        *beat = beat_now(e);
        return;
    }
    *bpm = tempo;
    *beat = (d->position - d->anchor) * d->bpm / (60 * d->asset->rate) - d->downbeat;
}
// Raw performance playback does not consume the spectral cursor. Invalidate it
// when crossing that boundary so resumption reads the current source position.
static void set_performance_rate(tdj_engine *e, int index, double value) {
    deck *d = &e->decks[index];
    bool crossing = (d->performance_rate == 1) != (value == 1);
    bool silence_boundary = (d->performance_rate == 0) != (value == 0);
    if (crossing)
        tdj_keylock_reset(e->keylocks[index]);
    d->performance_rate = value;
    // Preserve emitted output across pipeline changes and held stops. Ordinary
    // nonzero raw-rate updates keep their continuous cursor and existing ramp.
    if (crossing || silence_boundary)
        transition_request(e, index, 0);
}
static void brake_clear(tdj_engine *e, int index) {
    deck *d = &e->decks[index];
    if (!d->braking)
        return;
    d->braking = false;
    d->brake_primed = false;
    d->brake_rate = 0;
    tdj_keylock_reset(e->keylocks[index]);
    transition_request(e, index, 0);
}
static void brake_input(tdj_engine *e, int index, double position, double start, double end, float *l, float *r) {
    deck *d = &e->decks[index];
    if (d->asset->stream)
        tdj_keylock_sample_stream_spans(e->keylocks[index], d->asset, tdj_stream_render_read_stereo,
                                        tdj_stream_render_span, d->asset->frames, d->asset->rate, position,
                                        d->free_rate, d->keylock, start, end, l, r);
    else
        tdj_keylock_sample_loop(e->keylocks[index], d->asset->samples, d->asset->frames, d->asset->rate, position,
                                d->free_rate, d->keylock, start, end, l, r);
}
static double brake_cursor_next(deck *d, double cursor, double step, double start, double end) {
    cursor += step;
    if (end > start)
        cursor = start + fmod(fmax(0, cursor - start), end - start);
    return fmax(0, fmin(d->asset->frames - 1, cursor));
}
static void brake_sample(tdj_engine *e, int index, double start, double end, float *l, float *r) {
    deck *d = &e->decks[index];
    double step = d->asset->rate / e->rate * d->free_rate;
    if (!d->brake_primed) {
        d->brake_cursor = d->position;
        d->brake_phase = 0;
        brake_input(e, index, d->brake_cursor, start, end, &d->brake_l[0], &d->brake_r[0]);
        d->brake_cursor = brake_cursor_next(d, d->brake_cursor, step, start, end);
        brake_input(e, index, d->brake_cursor, start, end, &d->brake_l[1], &d->brake_r[1]);
        d->brake_primed = true;
    }
    *l = d->brake_l[0] + (d->brake_l[1] - d->brake_l[0]) * d->brake_phase;
    *r = d->brake_r[0] + (d->brake_r[1] - d->brake_r[0]) * d->brake_phase;
    // A short source envelope reaches zero before the paused path takes over.
    double remaining = d->brake_rate * e->rate * d->brake_seconds / d->brake_strength;
    double gain = remaining <= 1.00001 ? 0 : fmin(1, (remaining - 1) / (e->rate * 0.002));
    *l *= gain;
    *r *= gain;
    d->brake_phase += d->brake_rate;
    if (d->brake_phase >= 1) {
        d->brake_phase -= 1;
        d->brake_l[0] = d->brake_l[1];
        d->brake_r[0] = d->brake_r[1];
        d->brake_cursor = brake_cursor_next(d, d->brake_cursor, step, start, end);
        brake_input(e, index, d->brake_cursor, start, end, &d->brake_l[1], &d->brake_r[1]);
    }
}
static double maximum_source_rate(deck *d, double master) {
    double rate = d->synced && d->bpm > 0 ? master / deck_bpm(d) : d->free_rate;
    if (d->synced && d->map.count)
        for (unsigned k = 1; k < d->map.count; k++) {
            double bpm = 60 * d->map.sample_rate * (d->map.beats[k] - d->map.beats[k - 1]) /
                         (d->map.frames[k] - d->map.frames[k - 1]);
            rate = fmax(rate, master / bpm);
        }
    if (d->braking)
        rate = fmax(rate, d->free_rate);
    return rate;
}
static tdj_stream_target stream_target(deck *d, double master) {
    double start = 0, end = 0;
    if (d->touch_active && d->touch_end > d->touch_start) {
        start = d->touch_start;
        end = d->touch_end;
    } else if (d->loop_enabled) {
        start = d->loop_start;
        end = d->loop_end;
    } else if (d->recovery_active) {
        start = d->recovery_start;
        end = d->recovery_end;
    }
    return (tdj_stream_target){.position = d->position,
                               .source_speed = maximum_source_rate(d, master),
                               .performance_rate = d->performance_rate,
                               .loop_start = start,
                               .loop_end = end,
                               .continuing_position = d->continuing,
                               .keylock = d->keylock,
                               .reserve_continuing = (d->flux_enabled || d->loop_rolling) && (d->loop_enabled || d->touch_active)};
}
static bool append_request(tdj_stream_request *r, const tdj_stream_request *extra) {
    if (r->count + extra->count > TDJ_STREAM_MAX_RANGES)
        return false;
    memcpy(r->ranges + r->count, extra->ranges, extra->count * sizeof(tdj_stream_range));
    r->count += extra->count;
    return true;
}
static int deck_request(tdj_engine *e, deck *d, double master, bool reserve, tdj_stream_request *r) {
    tdj_stream_target t = stream_target(d, master);
    int status = tdj_stream_plan(d->asset, &t, e->frame + 1, d->generation, reserve, r);
    if (status < 0)
        return status;
    if (d->recovery_armed && d->recovery_start >= 0) {
        tdj_stream_target replay = t;
        replay.position = d->recovery_start;
        replay.loop_start = d->recovery_start;
        replay.loop_end = d->recovery_end;
        replay.performance_rate = 1;
        replay.reserve_continuing = false;
        tdj_stream_request pending;
        status = tdj_stream_plan(d->asset, &replay, e->frame + 1, d->generation, reserve, &pending);
        if (status < 0 || !append_request(r, &pending))
            return TDJ_STREAM_CAPACITY;
    }
    if (d->jump_pending) {
        t.position = d->jump_frame;
        if (d->jump_loop) {
            t.position = d->pending_loop_position;
            t.loop_start = d->jump_frame;
            t.loop_end = d->pending_loop_end;
            t.reserve_continuing = d->flux_enabled;
            if (!d->loop_enabled && !d->touch_active)
                t.continuing_position = d->position;
        } else if (d->touch_active) {
            if (d->pending_touch_end > d->jump_frame) {
                t.loop_start = d->jump_frame;
                t.loop_end = d->pending_touch_end;
            } else if (d->loop_enabled) {
                t.loop_start = d->loop_start;
                t.loop_end = d->loop_end;
            } else {
                t.loop_start = 0;
                t.loop_end = 0;
            }
            if (d->pending_touch_rate_valid)
                t.performance_rate = d->pending_touch_rate;
        }
        tdj_stream_request pending;
        status = tdj_stream_plan(d->asset, &t, e->frame + 1, d->generation, reserve, &pending);
        if (status < 0 || !append_request(r, &pending))
            return TDJ_STREAM_CAPACITY;
    }
    return TDJ_STREAM_READY;
}
static unsigned future_targets(deck *d, double master, unsigned timeline, unsigned pending_timeline,
                               tdj_stream_future *out) {
    bool moving = d->state == TDJ_PLAYING || d->state == TDJ_QUEUED;
    bool continuing = moving && ((d->touch_active && d->touch_was_playing) || (d->loop_enabled && !d->touch_active));
    tdj_stream_target t = stream_target(d, master);
    out[0] = (tdj_stream_future){t, moving, continuing, timeline, timeline};
    if (d->recovery_armed && d->recovery_start >= 0) {
        t.position = d->recovery_start;
        t.loop_start = d->recovery_start;
        t.loop_end = d->recovery_end;
        t.reserve_continuing = false;
        t.performance_rate = 1;
        out[1] = (tdj_stream_future){t, 0, 0, pending_timeline, pending_timeline};
        return 2;
    }
    if (!d->jump_pending)
        return 1;
    t.position = d->jump_frame;
    if (d->jump_loop) {
        t.position = d->pending_loop_position;
        t.loop_start = d->jump_frame;
        t.loop_end = d->pending_loop_end;
        t.reserve_continuing = d->flux_enabled;
        if (!d->loop_enabled && !d->touch_active)
            t.continuing_position = d->position;
        continuing = moving;
    } else if (d->touch_active) {
        if (d->pending_touch_end > d->jump_frame) {
            t.loop_start = d->jump_frame;
            t.loop_end = d->pending_touch_end;
        } else {
            t.loop_start = d->loop_enabled ? d->loop_start : 0;
            t.loop_end = d->loop_enabled ? d->loop_end : 0;
        }
        if (d->pending_touch_rate_valid)
            t.performance_rate = d->pending_touch_rate;
    }
    // A pending audible jump starts later, while its continuing timeline can
    // remain coupled to the current native path. Unknown captures stay independent.
    unsigned continuing_timeline =
        (d->performance_rate == 1 || d->loop_enabled || d->touch_active) ? timeline : pending_timeline + 4;
    out[1] = (tdj_stream_future){t, moving ? 2u : 0u, continuing, pending_timeline, continuing_timeline};
    return 2;
}
static int future_capacity(tdj_engine *e, int replacement, deck *proposed, double master, uint32_t maximum) {
    int decks = replacement >= e->deck_count ? TDJ_DECK_COUNT : e->deck_count;
    tdj_asset *checked[TDJ_DECK_COUNT] = {0};
    unsigned unique = 0;
    for (int i = 0; i < decks; i++) {
        deck *candidate = i == replacement ? proposed : &e->decks[i];
        tdj_asset *asset = candidate->asset;
        if (!asset || !asset->stream)
            continue;
        unsigned match = 0;
        while (match < unique && checked[match] != asset)
            ++match;
        if (match < unique)
            continue;
        checked[unique++] = asset;
        tdj_stream_future targets[2 * TDJ_DECK_COUNT];
        unsigned count = 0;
        for (int j = 0; j < decks; j++) {
            deck *d = j == replacement ? proposed : &e->decks[j];
            if (d->asset == asset)
                count += future_targets(d, master, d->state == TDJ_QUEUED ? (unsigned)j + 1 : 0,
                                        (unsigned)j + TDJ_DECK_COUNT + 1, targets + count);
        }
        int status = tdj_stream_future_capacity(asset, targets, count, maximum);
        if (status != TDJ_OK)
            return status;
    }
    return TDJ_OK;
}
static int stream_validate(tdj_engine *e, int index, deck *d, double master, uint64_t ticket, uint64_t generation) {
    if (!d->asset || !d->asset->stream)
        return ticket ? TDJ_STALE : TDJ_OK;
    int status = tdj_stream_check_ticket(d->asset, ticket, generation);
    if (status == TDJ_STALE)
        return status;
    tdj_stream_request r;
    if (deck_request(e, d, master, false, &r) < 0)
        return TDJ_INVALID;
    int capacity = future_capacity(e, index, d, master, 0);
    if (capacity != TDJ_OK)
        return capacity;
    if (status != TDJ_OK)
        return status;
    if (!tdj_stream_covers(d->asset, &r)) {
        tdj_stream_cold(d->asset);
        return TDJ_SOURCE_COLD;
    }
    return TDJ_OK;
}
static void release_deck_claims(tdj_engine *e, unsigned deck_index) {
    for (unsigned n = 0; n < TDJ_STREAM_MAX_TICKETS * (unsigned)e->deck_count; n++) {
        stream_claim *c = &e->claims[n];
        if (!c->asset)
            continue;
        c->decks &= ~(1u << deck_index);
        if (!c->decks) {
            tdj_stream_release_claim(c->asset, c->ticket);
            memset(c, 0, sizeof(*c));
        }
    }
}
static void add_claim(tdj_engine *e, tdj_asset *asset, uint64_t ticket, unsigned deck_index, bool pending) {
    if (!ticket || !asset || !asset->stream)
        return;
    stream_claim *slot = NULL;
    for (unsigned n = 0; n < TDJ_STREAM_MAX_TICKETS * (unsigned)e->deck_count; n++) {
        stream_claim *c = &e->claims[n];
        if (c->asset == asset && c->ticket == ticket) {
            slot = c;
            break;
        }
        if (!c->asset && !slot)
            slot = c;
    }
    if (!slot)
        return;
    if (!slot->asset) {
        tdj_stream_claim(asset, ticket);
        slot->asset = asset;
        slot->ticket = ticket;
    }
    slot->decks |= 1u << deck_index;
    slot->serial = tdj_stream_next_request(asset);
    slot->pending = pending;
}
static bool supported_keylock_rate(double speed) {
    return isfinite(speed) && speed >= 0.125 && speed <= 8;
}
static bool supported_deck_keylock(deck *d, double master) {
    if (!d->synced || !d->map.count)
        return supported_keylock_rate(d->synced && d->bpm > 0 ? master / deck_bpm(d) : d->free_rate);
    for (unsigned k = 1; k < d->map.count; k++) {
        double bpm = 60 * d->map.sample_rate * (d->map.beats[k] - d->map.beats[k - 1]) /
                     (d->map.frames[k] - d->map.frames[k - 1]);
        if (!supported_keylock_rate(master / bpm))
            return false;
    }
    return true;
}
static void anchor_clock(tdj_engine *e, double beat) {
    e->epoch_ticks = beat * (60 * e->rate);
    e->epoch_frame = e->frame;
}
static bool nearest_sync_position(deck *d, double beat, double *position);
static bool align_synced_position(deck *d, double beat);
static double reference_beats(deck *d, tdj_engine *e) {
    if (d->loop_enabled || (d->touch_active && d->touch_end > d->touch_start))
        return INFINITY;
    if (d->map.count)
        return deck_beat(d, d->asset->frames) - deck_beat(d, d->position);
    return (d->asset->frames - d->position) * e->bpm / (60 * d->asset->rate * source_rate(e, d));
}
static int start_deck(tdj_engine *e, deck *d, int index, uint64_t ticket, uint64_t generation) {
    double reference = -1;
    if (d->synced && d->bpm > 0)
        for (int i = 0; i < e->deck_count; ++i) {
            deck *candidate = &e->decks[i];
            if (i != index && candidate->state == TDJ_PLAYING && candidate->synced && candidate->bpm > 0)
                reference = fmax(reference, reference_beats(candidate, e));
        }
    double proposed_bpm = (!e->running && !e->master_chosen && d->bpm > 0) ? deck_bpm(d) : e->bpm;
    if (d->keylock && !supported_deck_keylock(d, proposed_bpm))
        return TDJ_KEYLOCK_RANGE;
    deck starting = *d;
    starting.state = reference >= 0 ? TDJ_QUEUED : TDJ_PLAYING;
    if ((starting.state == TDJ_QUEUED || e->running) &&
        !align_synced_position(&starting, starting.state == TDJ_QUEUED ? 0 : beat_now(e)))
        return TDJ_ALIGNMENT_UNAVAILABLE;
    int stream_status = stream_validate(e, index, &starting, proposed_bpm, ticket, generation);
    if (stream_status != TDJ_OK)
        return stream_status;
    if (starting.state == TDJ_QUEUED) {
        d->queued_origin = d->position;
        d->position = starting.position;
        double beat = beat_now(e);
        double bar = (floor(beat / 4) + 1) * 4;
        // Join on a bar if a reference can reach it. Otherwise use the next beat.
        d->target = bar - beat <= reference + 1e-9 ? bar : floor(beat) + 1;
        d->state = TDJ_QUEUED;
    } else {
        if (!e->running) {
            if (!e->master_chosen && d->bpm > 0) {
                e->bpm = deck_bpm(d);
                e->master_chosen = true;
            }
            double origin = d->bpm > 0 ? deck_beat(d, d->position) - (d->map.count ? d->map.downbeat : d->downbeat) : 0;
            anchor_clock(e, origin);
            e->running = true;
        }
        d->position = starting.position;
        d->state = TDJ_PLAYING;
        d->last_start = e->frame;
    }
    return TDJ_OK;
}
// Retain tempo-weighted samples between tempo segments. Do not repeatedly
// divide into beats and multiply back when a tempo control updates.
static void advance_clock_epoch(tdj_engine *e) {
    e->epoch_ticks = ticks_now(e);
    e->epoch_frame = e->frame;
}

static void publish(tdj_engine *e) {
    atomic_fetch_add(&e->snapshot_sequence, 1);
    double beat = beat_now(e);
    atomic_store(&e->published_frame, e->frame);
    atomic_store(&e->published_paired_frames, e->paired_frames);
    atomic_store(&e->published_bpm, e->bpm);
    atomic_store(&e->published_beat, beat);
    atomic_store(&e->published_running, e->running);
    int visible_decks = microphone_channels(&e->auxiliary) >= 4 ? TDJ_DECK_COUNT : e->deck_count;
    atomic_store(&e->published_extra, visible_decks > 2);
    atomic_store(&e->published_crossfader, e->mix.crossfader.target);
    atomic_store(&e->published_master, e->mix.master.target);
    atomic_store(&e->published_monitor, e->mix.monitor.target);
    atomic_store(&e->published_cue_blend, e->mix.cue_mix.target);
    for (int i = 0; i < visible_decks; ++i) {
        deck *d = &e->decks[i];
        atomic_deck *p = &e->published[i];
        mixer_deck *m = &e->mix.decks[i];
        atomic_store(&p->volume, m->volume.target);
        atomic_store(&p->gain, m->gain.target);
        atomic_store(&p->low, m->low.target);
        atomic_store(&p->mid, m->mid.target);
        atomic_store(&p->high, m->high.target);
        atomic_store(&p->cue, m->cue.target);
        atomic_store(&p->filter_x, m->filter_x);
        atomic_store(&p->filter_y, m->filter_y);
        atomic_store(&p->filter_enabled, m->filter_enabled);
        atomic_store(&p->crossfader_assignment, (int32_t)m->crossfader_assignment.target);
        atomic_store(&p->peak, m->peak);
        atomic_store(&p->recovery_armed, d->recovery_armed);
        atomic_store(&p->recovery_active, d->recovery_active);
        atomic_store(&p->recovery_mix, d->recovery_mix);
        atomic_store(&p->recovery_start, d->recovery_start);
        atomic_store(&p->recovery_end, d->recovery_end);
        atomic_store(&p->recovery_mix_start, d->recovery_mix_start);
        atomic_store(&p->loop_enabled, d->loop_enabled);
        atomic_store(&p->flux_enabled, d->flux_enabled);
        atomic_store(&p->loop_rolling, d->loop_rolling);
        atomic_store(&p->touch_active, d->touch_active);
        atomic_store(&p->jump_pending, d->jump_pending);
        atomic_store(&p->loop_start, d->loop_start);
        atomic_store(&p->loop_end, d->loop_end);
        atomic_store(&p->continuing, d->continuing);
        atomic_store(&p->performance_rate, d->performance_rate);
        atomic_store(&p->free_rate, d->free_rate);
        atomic_store(&p->touch_start, d->touch_start);
        atomic_store(&p->touch_end, d->touch_end);
        atomic_store(&p->jump_frame, d->jump_frame);
        atomic_store(&p->jump_beat, d->jump_beat);
        atomic_store(&p->pending_touch_end, d->pending_touch_end);
        atomic_store(&p->pending_loop_end, d->pending_loop_end);
        atomic_store(&p->touch_was_playing, d->touch_was_playing);
        atomic_store(&p->jump_loop, d->jump_loop);
        atomic_store(&p->pending_touch_rate, d->pending_touch_rate);
        atomic_store(&p->pending_touch_rate_valid, d->pending_touch_rate_valid);
        atomic_store(&p->generation, d->generation);
        atomic_store(&p->last_start, d->last_start);
        atomic_store(&p->state, d->state);
        atomic_store(&p->synced, d->synced);
        atomic_store(&p->keylock, d->keylock);
        atomic_store(&p->braking, d->braking);
        atomic_store(&p->brake_rate, d->brake_rate);
        atomic_store(&p->position, d->position);
        atomic_store(&p->bpm, d->bpm);
        atomic_store(&p->local_bpm, deck_bpm(d));
        atomic_store(&p->source_sample_rate, d->asset ? d->asset->rate : 0);
        atomic_store(&p->grid_anchor, d->anchor);
        atomic_store(&p->grid_downbeat, (int32_t)d->downbeat);
        if (d->map_dirty) {
            atomic_store(&p->map_count, d->map.count);
            atomic_store(&p->map_rate, d->map.sample_rate);
            atomic_store(&p->map_downbeat, d->map.downbeat);
            for (unsigned k = 0; k < d->map.count; k++) {
                atomic_store(&p->map_beats[k], d->map.beats[k]);
                atomic_store(&p->map_frames[k], d->map.frames[k]);
            }
            d->map_dirty = false;
        }
        atomic_store(&p->target, d->target);
        atomic_store(&p->rate, source_rate(e, d));
        double lead = d->position;
        if (d->state == TDJ_QUEUED && d->asset && d->bpm > 0)
            lead = d->map.count ? deck_frame(d, deck_beat(d, d->position) - fmax(0, d->target - beat))
                                : lead - fmax(0, d->target - beat) * 60 * d->asset->rate / d->bpm;
        atomic_store(&p->lead, lead);
    }
    atomic_fetch_add(&e->snapshot_sequence, 1);
}

tdj_engine *tdj_engine_create(double rate, double gain) {
    if (!valid_rate(rate) || !isfinite(gain) || gain < 0 || gain > 1)
        return NULL;
    tdj_engine *e = calloc(1, sizeof(*e));
    if (!e)
        return NULL;
    e->rate = rate;
    e->deck_count = 2;
    atomic_init(&e->extra_prepared, false);
    atomic_flag_clear(&e->extra_allocating);
    atomic_init(&e->published_extra, false);
    e->gain = gain;
    e->bpm = 120;
    mixer_init(&e->mix, rate, gain);
    auxiliary_init(&e->auxiliary, rate);
    atomic_init(&e->published_paired_frames, 0);
    atomic_init(&e->master_meter_enabled, false);
    for (unsigned i = 0; i < 2; ++i) {
        atomic_init(&e->master_peak[i], 0);
        atomic_init(&e->master_clip[i], 0);
    }
    atomic_init(&e->published_crossfader, 0.5);
    atomic_init(&e->published_master, gain);
    atomic_init(&e->published_monitor, 0.5);
    atomic_init(&e->published_cue_blend, 0);
    atomic_init(&e->command_write, 0);
    atomic_init(&e->command_read, 0);
    atomic_init(&e->message_write, 0);
    atomic_init(&e->message_read, 0);
    atomic_init(&e->snapshot_sequence, 0);
    atomic_init(&e->published_frame, 0);
    atomic_init(&e->published_bpm, 120);
    atomic_init(&e->published_beat, 0);
    atomic_init(&e->published_running, 0);
    for (int i = 0; i < TDJ_DECK_COUNT; ++i) {
        e->decks[i].free_rate = 1;
        e->decks[i].performance_rate = 1;
        atomic_deck *p = &e->published[i];
        atomic_init(&p->generation, 0);
        atomic_init(&p->last_start, 0);
        atomic_init(&p->state, 0);
        atomic_init(&p->synced, 0);
        atomic_init(&p->position, 0);
        atomic_init(&p->bpm, 0);
        atomic_init(&p->local_bpm, 0);
        atomic_init(&p->keylock, 0);
        atomic_init(&p->braking, 0);
        atomic_init(&p->brake_rate, 0);
        atomic_init(&p->map_count, 0);
        atomic_init(&p->map_downbeat, 0);
        atomic_init(&p->map_rate, 0);
        for (unsigned k = 0; k < TDJ_MAX_GRID_ANCHORS; k++) {
            atomic_init(&p->map_beats[k], 0);
            atomic_init(&p->map_frames[k], 0);
        }
        atomic_init(&p->source_sample_rate, 0);
        atomic_init(&p->grid_anchor, 0);
        atomic_init(&p->grid_downbeat, 0);
        atomic_init(&p->recovery_armed, 0);
        atomic_init(&p->recovery_active, 0);
        atomic_init(&p->recovery_mix, 0);
        atomic_init(&p->recovery_start, 0);
        atomic_init(&p->recovery_end, 0);
        atomic_init(&p->recovery_mix_start, 0);
        atomic_init(&p->loop_enabled, 0);
        atomic_init(&p->flux_enabled, 0);
        atomic_init(&p->loop_rolling, 0);
        atomic_init(&p->touch_active, 0);
        atomic_init(&p->jump_pending, 0);
        atomic_init(&p->loop_start, 0);
        atomic_init(&p->loop_end, 0);
        atomic_init(&p->continuing, 0);
        atomic_init(&p->performance_rate, 1);
        atomic_init(&p->volume, i < 2 ? 1 : 0);
        atomic_init(&p->gain, 1);
        atomic_init(&p->low, 1);
        atomic_init(&p->mid, 1);
        atomic_init(&p->high, 1);
        atomic_init(&p->cue, 0);
        atomic_init(&p->filter_x, 0);
        atomic_init(&p->filter_y, 0);
        atomic_init(&p->filter_enabled, 0);
        atomic_init(&p->crossfader_assignment, (i & 1) == 0 ? -1 : 1);
        atomic_init(&p->peak, 0);
        atomic_init(&p->target, 0);
        atomic_init(&p->rate, 1);
        atomic_init(&p->lead, 0);
    }
    atomic_flag_clear(&e->render_busy);
    for (int i = 0; i < 2; ++i) {
        e->keylocks[i] = tdj_keylock_create(rate);
        if (!e->keylocks[i]) {
            tdj_engine_destroy(e);
            return NULL;
        }
        for (int slot = 0; slot < 3; ++slot)
            if (!fx_init(&e->effects[i][slot], rate)) {
                tdj_engine_destroy(e);
                return NULL;
            }
    }
    publish(e);
    return e;
}

// The serial control producer prepares C/D before submitting any commands for them.
bool tdj_engine_prepare_extra_decks(tdj_engine *e) {
    if (atomic_load_explicit(&e->extra_prepared, memory_order_acquire))
        return true;
    if (atomic_flag_test_and_set_explicit(&e->extra_allocating, memory_order_acquire))
        return atomic_load_explicit(&e->extra_prepared, memory_order_acquire);
    if (atomic_load_explicit(&e->extra_prepared, memory_order_acquire)) {
        atomic_flag_clear_explicit(&e->extra_allocating, memory_order_release);
        return true;
    }
    for (int i = 2; i < TDJ_DECK_COUNT; ++i) {
        e->keylocks[i] = tdj_keylock_create(e->rate);
        if (!e->keylocks[i])
            goto failed;
        for (int slot = 0; slot < 3; ++slot)
            if (!fx_init(&e->effects[i][slot], e->rate))
                goto failed;
    }
    atomic_store_explicit(&e->extra_prepared, true, memory_order_release);
    atomic_flag_clear_explicit(&e->extra_allocating, memory_order_release);
    return true;
failed:
    for (int i = 2; i < TDJ_DECK_COUNT; ++i) {
        tdj_keylock_destroy(e->keylocks[i]);
        e->keylocks[i] = NULL;
        for (int slot = 0; slot < 3; ++slot) {
            fx_destroy(&e->effects[i][slot]);
            memset(&e->effects[i][slot], 0, sizeof(e->effects[i][slot]));
        }
    }
    atomic_flag_clear_explicit(&e->extra_allocating, memory_order_release);
    return false;
}
// Used only by the diagnostic factory before the engine is returned to its owner.
void tdj_engine_attach_keylock_trace(tdj_engine *e, const tdj_keylock_trace *trace) {
    if (!e || !trace)
        return;
    for (uint32_t i = 0; i < 2; ++i)
        tdj_keylock_set_trace(e->keylocks[i], trace, i);
}

void tdj_engine_destroy(tdj_engine *e) {
    if (!e)
        return;
    for (unsigned i = 0; i < TDJ_STREAM_MAX_TICKETS * TDJ_DECK_COUNT; i++)
        if (e->claims[i].asset)
            tdj_stream_release_claim(e->claims[i].asset, e->claims[i].ticket);
    for (int i = 0; i < e->deck_count; i++)
        tdj_stream_detach(e->decks[i].asset, e);
    for (int i = 0; i < TDJ_DECK_COUNT; ++i) {
        tdj_keylock_destroy(e->keylocks[i]);
        for (int k = 0; k < 3; k++)
            fx_destroy(&e->effects[i][k]);
    }
    free(e);
}

int32_t tdj_engine_configure_maximum_output_frames(tdj_engine *e, uint32_t frames) {
    if (!e || !frames || frames > 65536)
        return TDJ_INVALID;
    if (atomic_flag_test_and_set_explicit(&e->render_busy, memory_order_acquire))
        return TDJ_PROTECTED;
    int capacity = future_capacity(e, -1, NULL, e->bpm, frames);
    if (capacity != TDJ_OK) {
        atomic_flag_clear_explicit(&e->render_busy, memory_order_release);
        return capacity;
    }
    e->maximum_output_frames = frames;
    for (int i = 0; i < e->deck_count; i++)
        tdj_stream_set_maximum_output_frames(e->decks[i].asset, frames);
    atomic_flag_clear_explicit(&e->render_busy, memory_order_release);
    return TDJ_OK;
}

int32_t tdj_engine_output_sources_ready(tdj_engine *e) {
    if (!e)
        return TDJ_INVALID;
    if (atomic_flag_test_and_set_explicit(&e->render_busy, memory_order_acquire))
        return TDJ_PROTECTED;
    int result = TDJ_OK;
    for (int i = 0; i < e->deck_count; i++) {
        deck *d = &e->decks[i];
        if (!d->asset || !d->asset->stream || (d->state != TDJ_PLAYING && d->state != TDJ_QUEUED))
            continue;
        tdj_stream_request required;
        if (deck_request(e, d, e->bpm, false, &required) < 0 || !tdj_stream_covers(d->asset, &required)) {
            result = TDJ_SOURCE_COLD;
            break;
        }
    }
    atomic_flag_clear_explicit(&e->render_busy, memory_order_release);
    return result;
}

bool tdj_submit(tdj_engine *e, tdj_command command) {
    if ((command.kind == TDJ_ADAPTIVE_GRID || command.kind == TDJ_LOAD) && command.beatgrid.count &&
        !tdj_beatgrid_validate(command.beatgrid, UINT64_MAX))
        return false;
    unsigned write = atomic_load_explicit(&e->command_write, memory_order_relaxed);
    unsigned next = (write + 1) % COMMAND_CAPACITY;
    if (next == atomic_load_explicit(&e->command_read, memory_order_acquire))
        return false;
    e->commands[write] = command;
    atomic_store_explicit(&e->command_write, next, memory_order_release);
    return true;
}
static bool message(tdj_engine *e, uint64_t id, uint64_t generation, int status) {
    unsigned write = atomic_load_explicit(&e->message_write, memory_order_relaxed);
    unsigned next = (write + 1) % MESSAGE_CAPACITY;
    if (next == atomic_load_explicit(&e->message_read, memory_order_acquire))
        return false;
    e->messages[write] = (tdj_message){id, generation, status};
    atomic_store_explicit(&e->message_write, next, memory_order_release);
    return true;
}
bool tdj_read_message(tdj_engine *e, tdj_message *out) {
    unsigned read = atomic_load_explicit(&e->message_read, memory_order_relaxed);
    if (read == atomic_load_explicit(&e->message_write, memory_order_acquire))
        return false;
    *out = e->messages[read];
    atomic_store_explicit(&e->message_read, (read + 1) % MESSAGE_CAPACITY, memory_order_release);
    return true;
}

// Resolve the smallest beat-phase correction against the current render clock.
// The active loop and file are hard bounds. No command state changes on failure.
static bool nearest_sync_position(deck *d, double beat, double *position) {
    if (!d->asset || !isfinite(d->bpm) || d->bpm <= 0)
        return false;
    double period = 60 * d->asset->rate / d->bpm;
    double low = d->loop_enabled ? fmax(0, d->loop_start) : 0;
    double high = d->loop_enabled ? fmin(d->asset->frames, d->loop_end) : d->asset->frames;
    if (!isfinite(beat) || !isfinite(period) || period <= 0 || !(low < high))
        return false;
    double candidate;
    if (d->map.count) {
        double phase = d->map.downbeat + beat - floor(beat);
        double first = ceil(deck_beat(d, low) - phase), last = ceil(deck_beat(d, high) - phase) - 1;
        double nearest = floor(deck_beat(d, d->position) - phase + 0.5);
        if (first > last)
            return false;
        candidate = deck_frame(d, phase + fmax(first, fmin(last, nearest)));
        if (!isfinite(candidate) || candidate < low || candidate >= high)
            return false;
    } else {
        double origin = d->anchor + (d->downbeat + beat - floor(beat)) * period;
        double first = ceil((low - origin) / period), last = ceil((high - origin) / period) - 1;
        double nearest = floor((d->position - origin) / period + 0.5);
        if (!isfinite(origin) || !isfinite(first) || !isfinite(last) || !isfinite(nearest) || first > last)
            return false;
        double index = fmax(first, fmin(last, nearest));
        candidate = origin + index * period;
        if (candidate < low && index < last)
            candidate = origin + (++index) * period;
        if (candidate >= high && index > first)
            candidate = origin + (--index) * period;
        if (!isfinite(candidate) || candidate < low || candidate >= high)
            return false;
    }
    *position = candidate;
    return true;
}

// Manual effects retain Sync intent. Their release returns to the render clock.
static bool align_synced_position(deck *d, double beat) {
    if (!d->synced || d->bpm <= 0 || d->touch_active || d->braking || d->performance_rate != 1)
        return true;
    if (nearest_sync_position(d, beat, &d->position))
        return true;
    // A short active loop can span less than one beat. Align when that effect ends.
    return d->loop_enabled;
}

static bool can_park_starved_stream(const deck *d) {
    return d->state == TDJ_PLAYING && !d->touch_active && !d->braking && d->performance_rate == 1;
}

static void resume_starved_stream(tdj_engine *e, int index) {
    deck *d = &e->decks[index];
    if (!d->stream_starved)
        return;
    if (!can_park_starved_stream(d)) {
        d->stream_starved = false;
        return;
    }
    // Refill the missing position before considering a phase-aligned return.
    // This prevents replaying a cached fragment that ends at the same gap.
    tdj_stream_request required;
    if (deck_request(e, d, e->bpm, false, &required) <= 0 || !tdj_stream_covers(d->asset, &required))
        return;
    deck aligned = *d;
    if (!align_synced_position(&aligned, beat_now(e)))
        return;
    if (aligned.position != d->position &&
        (deck_request(e, &aligned, e->bpm, false, &required) <= 0 || !tdj_stream_covers(d->asset, &required)))
        return;
    d->position = aligned.position;
    if (!d->loop_enabled)
        d->continuing = d->position;
    d->stream_starved = false;
    // The stretcher may have consumed missing input before the hold.
    tdj_keylock_reset(e->keylocks[index]);
}

static void cancel_recovery(tdj_engine *e, int index) {
    deck *d = &e->decks[index];
    d->recovery_armed = false;
    d->recovery_active = false;
    d->recovery_mix = false;
    d->recovery_mixing = false;
    deck *other = &e->decks[(index ^ 1)];
    if (other->recovery_mix) {
        other->recovery_mix = false;
        other->recovery_mixing = false;
    }
}

static uint64_t tempo_ticket(tdj_command c, int i) {
    switch (i) {
    case 0: return c.preparation_ticket;
    case 1: return c.preparation_ticket_b;
    case 2: return c.preparation_ticket_c;
    default: return c.preparation_ticket_d;
    }
}
static uint64_t tempo_generation(tdj_command c, int i) {
    switch (i) {
    case 0: return c.generation;
    case 1: return c.preparation_generation_b;
    case 2: return c.preparation_generation_c;
    default: return c.preparation_generation_d;
    }
}
static int apply(tdj_engine *e, tdj_command c) {
    if (c.kind == TDJ_PAD_GAIN) {
        if (!isfinite(c.value) || c.value < 0 || c.value > 1)
            return TDJ_INVALID;
        ramp_set(&e->auxiliary.pad_gain, c.value, e->mix.smoothing);
        return TDJ_OK;
    }
    if (c.kind == TDJ_PAD_LOAD || c.kind == TDJ_PAD_PLAY) {
        if (c.deck < 0 || c.deck >= TDJ_PAD_COUNT)
            return TDJ_INVALID;
        pad_voice *pad = &e->auxiliary.pads[c.deck];
        uint32_t bit = UINT32_C(1) << c.deck;
        if (c.kind == TDJ_PAD_LOAD) {
            if (c.asset && (c.asset->stream || !c.asset->samples || !c.generation))
                return TDJ_INVALID;
            if (pad->asset)
                message(e, 0, pad->generation, TDJ_RETIRED);
            pad_transition(pad, e->rate);
            pad->asset = c.asset;
            pad->generation = c.generation;
            pad->reading = false;
            if (!pad->tail_remaining)
                e->auxiliary.playing &= ~bit;
        } else {
            if (!pad->asset || pad->generation != c.generation)
                return TDJ_STALE;
            pad_transition(pad, e->rate);
            pad->position = 0;
            pad->reading = c.flag != 0;
            if (pad->reading || pad->tail_remaining)
                e->auxiliary.playing |= bit;
            else
                e->auxiliary.playing &= ~bit;
        }
        return TDJ_OK;
    }
    if (c.kind == TDJ_FX) {
        int slot = c.flag >> 8, kind = c.flag & 127;
        if (!valid_deck_command(e, c.deck) || slot < 0 || slot > 2 || kind < 0 || kind >= TDJ_EFFECT_COUNT ||
            !isfinite(c.value) || c.value < 0 || c.value > 1 || !isfinite(c.value2) || c.value2 < 0 || c.value2 > 1 ||
            (c.value3 != 0 && c.value3 != 1))
            return TDJ_INVALID;
        performance_fx *f = &e->effects[c.deck][slot];
        bool reengaging = c.value3 != 0 && (!f->enabled || f->kind != kind);
        if (f->kind != kind)
            fx_reset(f);
        f->kind = kind;
        f->x = c.value;
        f->y = c.value2;
        f->enabled = c.value3 != 0;
        f->free_delay = (c.flag & 128) != 0;
        if (reengaging && kind == TDJ_EFFECT_REVERSE_GRAIN)
            fx_begin_capture(f);
        ramp_set(&f->wet, f->enabled ? f->y : 0, e->mix.smoothing);
        return TDJ_OK;
    }
    if (c.kind == TDJ_MIXER) {
        if (!isfinite(c.value) || !valid_deck_command(e, c.deck))
            return TDJ_INVALID;
        mixer *m = &e->mix;
        mixer_deck *d = &m->decks[c.deck];
        ramp *r = NULL;
        double lower = 0, upper = 1;
        switch (c.flag) {
        case TDJ_MIX_CROSSFADE:
            r = &m->crossfader;
            break;
        case TDJ_MIX_MASTER:
            r = &m->master;
            break;
        case TDJ_MIX_MONITOR:
            r = &m->monitor;
            break;
        case TDJ_MIX_CUE_BLEND:
            r = &m->cue_mix;
            break;
        case TDJ_MIX_VOLUME:
            r = &d->volume;
            break;
        case TDJ_MIX_GAIN:
            r = &d->gain;
            upper = 4;
            break;
        case TDJ_MIX_LOW:
            r = &d->low;
            upper = 2;
            break;
        case TDJ_MIX_MID:
            r = &d->mid;
            upper = 2;
            break;
        case TDJ_MIX_HIGH:
            r = &d->high;
            upper = 2;
            break;
        case TDJ_MIX_CUE:
            r = &d->cue;
            break;
        case TDJ_MIX_FILTER_X:
            lower = -1;
            break;
        case TDJ_MIX_FILTER_Y:
            break;
        case TDJ_MIX_FILTER_ENABLED:
            break;
        case TDJ_MIX_CROSSFADE_ASSIGNMENT:
            if (c.value != -1 && c.value != 0 && c.value != 1)
                return TDJ_INVALID;
            r = &d->crossfader_assignment;
            lower = -1;
            break;
        default:
            return TDJ_INVALID;
        }
        if (c.value < lower || c.value > upper)
            return TDJ_INVALID;
        if ((c.flag == TDJ_MIX_CUE || c.flag == TDJ_MIX_FILTER_ENABLED) && c.value != 0 && c.value != 1)
            return TDJ_INVALID;
        if (r)
            ramp_set(r, c.value, m->smoothing);
        else {
            if (c.flag == TDJ_MIX_FILTER_X)
                d->filter_x = c.value;
            if (c.flag == TDJ_MIX_FILTER_Y)
                d->filter_y = c.value;
            if (c.flag == TDJ_MIX_FILTER_ENABLED)
                d->filter_enabled = c.value != 0;
            filter_parameters(&d->filter, e->rate, d->filter_x, d->filter_y, m->smoothing);
            ramp_set(&d->filter_wet, d->filter_enabled && fabs(d->filter_x) > 0.001 ? 1 : 0, m->smoothing);
        }
        return TDJ_OK;
    }
    if (c.kind == TDJ_TEMPO) {
        if (!isfinite(c.value) || c.value <= 0 || c.value > 1000)
            return TDJ_INVALID;
        for (int i = 0; i < e->deck_count; ++i) {
            deck *d = &e->decks[i];
            if (d->asset && d->keylock && d->synced && d->bpm > 0 && !supported_deck_keylock(d, c.value))
                return TDJ_KEYLOCK_RANGE;
        }
        for (int i = 0; i < e->deck_count; i++)
            if (e->decks[i].asset) {
                uint64_t ticket = tempo_ticket(c, i);
                uint64_t generation = tempo_generation(c, i);
                if (ticket && generation != e->decks[i].generation)
                    return TDJ_STALE;
                int status = stream_validate(e, i, &e->decks[i], c.value, ticket, e->decks[i].generation);
                if (status != TDJ_OK)
                    return status;
            }
        advance_clock_epoch(e);
        e->bpm = c.value;
        e->master_chosen = true;
        return TDJ_OK;
    }
    if (c.kind == TDJ_PANIC) {
        e->auxiliary.playing = 0;
        tdj_preview_set_generation(e, 0);
        for (int i = 0; i < TDJ_PAD_COUNT; ++i) {
            pad_voice *pad = &e->auxiliary.pads[i];
            pad->reading = false;
            pad->tail_remaining = 0;
            pad->last_l = pad->last_r = 0;
        }
        e->auxiliary.mic_gain = 0;
        tdj_microphone_set_enabled(e, false);
        advance_clock_epoch(e);
        e->running = false;
        for (int i = 0; i < e->deck_count; ++i) {
            deck *d = &e->decks[i];
            if (d->state == TDJ_QUEUED)
                d->position = d->queued_origin;
            if (d->state == TDJ_PLAYING || d->state == TDJ_QUEUED)
                d->state = TDJ_PAUSED;
            brake_clear(e, i);
            if (d->loop_rolling)
                d->loop_enabled = d->loop_rolling = false;
            d->grid_click = false;
            d->touch_active = false;
            d->jump_pending = false;
            d->performance_rate = 1;
            release_deck_claims(e, (unsigned)i);
        }
        return TDJ_OK;
    }
    if (!valid_deck_command(e, c.deck))
        return TDJ_INVALID;
    deck *d = &e->decks[c.deck], *other = &e->decks[(c.deck ^ 1)];
    if (c.kind == TDJ_LOAD) {
        if (d->state == TDJ_PLAYING || d->state == TDJ_QUEUED)
            return TDJ_PROTECTED;
        if (!c.asset || c.flag < 0 || c.flag > (15 | TDJ_LOAD_RESET_IDLE_TEMPO) || !isfinite(c.value) || c.value < 0 ||
            c.value >= c.asset->frames || !isfinite(c.value2) || c.value2 < 0 || !isfinite(c.value3))
            return TDJ_INVALID;
        deck proposed = (deck){.asset = c.asset,
                               .generation = c.generation,
                               .state = TDJ_READY,
                               .synced = (c.flag & 1) != 0,
                               .keylock = (c.flag & 8) != 0,
                               .position = c.value,
                               .bpm = c.value2,
                               .anchor = c.value3,
                               .downbeat = (c.flag >> 1) & 3,
                               .free_rate = 1,
                               .performance_rate = 1,
                               .continuing = c.value,
                               .stream_fade = 1,
                               .map_dirty = true};
        if (c.beatgrid.count) {
            if (!tdj_beatgrid_validate(c.beatgrid, c.asset->frames) || c.beatgrid.sample_rate != c.asset->rate ||
                c.value2 <= 0)
                return TDJ_INVALID;
            proposed.map = c.beatgrid;
        }
        bool choose_on_play = !e->running && !e->master_chosen;
        bool reset_tempo = (c.flag & TDJ_LOAD_RESET_IDLE_TEMPO) && !e->running && !any_deck_active(e) &&
                           proposed.bpm > 0 && proposed.bpm <= 1000;
        for (int i = 0; reset_tempo && i < e->deck_count; ++i) {
            deck *existing = &e->decks[i];
            if (i != c.deck && existing->keylock && existing->synced && !supported_deck_keylock(existing, proposed.bpm))
                reset_tempo = false;
        }
        if (proposed.keylock) {
            double master = reset_tempo ? proposed.bpm : choose_on_play ? deck_bpm(&proposed) : e->bpm;
            if (!supported_deck_keylock(&proposed, master) ||
                (!reset_tempo && !choose_on_play && proposed.synced && proposed.bpm > 0 &&
                 !supported_keylock_rate(master / proposed.bpm)))
                return TDJ_KEYLOCK_RANGE;
        }
        bool already = asset_is_used(e, c.asset, 0, e->deck_count, -1);
        int attachment = tdj_stream_attach(c.asset, e);
        if (attachment != TDJ_OK)
            return attachment;
        if (e->maximum_output_frames)
            tdj_stream_set_maximum_output_frames(c.asset, e->maximum_output_frames);
        tdj_stream_render_begin(c.asset, e->frame);
        double master = reset_tempo || (choose_on_play && proposed.bpm > 0) ? proposed.bpm : e->bpm;
        int status = stream_validate(e, c.deck, &proposed, master, c.preparation_ticket, c.generation);
        if (status != TDJ_OK) {
            if (!already)
                tdj_stream_detach(c.asset, e);
            return status;
        }
        release_deck_claims(e, (unsigned)c.deck);
        if (d->asset) {
            if (c.asset != d->asset && !asset_is_used(e, d->asset, 0, e->deck_count, c.deck))
                tdj_stream_detach(d->asset, e);
            message(e, 0, d->generation, TDJ_RETIRED);
        }
        if (c.deck < 2)
            e->paired_frames = 0;
        *d = proposed;
        if (c.deck >= e->deck_count)
            e->deck_count = TDJ_DECK_COUNT;
        if (reset_tempo) {
            e->bpm = master;
            e->master_chosen = true;
        }
        tdj_stream_mark_started(c.asset);
        tdj_keylock_reset(e->keylocks[c.deck]);
        mixer_clear_track(&e->mix.decks[c.deck]);
        return TDJ_OK;
    }
    if (!d->asset || c.generation != d->generation)
        return TDJ_STALE;
    if (c.kind == TDJ_EJECT) {
        if (d->state == TDJ_PLAYING || d->state == TDJ_QUEUED)
            return TDJ_PROTECTED;
        release_deck_claims(e, (unsigned)c.deck);
        if (!asset_is_used(e, d->asset, 0, e->deck_count, c.deck))
            tdj_stream_detach(d->asset, e);
        message(e, 0, d->generation, TDJ_RETIRED);
        *d = (deck){.map_dirty = true};
        if (c.deck < 2)
            e->paired_frames = 0;
        tdj_keylock_reset(e->keylocks[c.deck]);
        mixer_clear_track(&e->mix.decks[c.deck]);
        return TDJ_OK;
    }
    if (c.kind == TDJ_GRID_METRONOME) {
        if ((c.flag != 0 && c.flag != 1) || (c.flag && (!isfinite(c.value) || d->bpm <= 0)))
            return TDJ_INVALID;
        d->grid_click = c.flag != 0;
        d->grid_click_offset = c.value;
        d->grid_click_position_valid = false;
        d->grid_click_age = 0;
        return TDJ_OK;
    }
    if (d->loop_rolling && (c.kind == TDJ_TOUCH || c.kind == TDJ_RATE || c.kind == TDJ_JUMP ||
                            c.kind == TDJ_LOOP || c.kind == TDJ_SEEK || c.kind == TDJ_BRAKE ||
                            c.kind == TDJ_CUE_RECALL || c.kind == TDJ_GRID))
        return TDJ_ACTIVE_PERFORMANCE;
    if (c.kind == TDJ_RECOVERY_CANCEL) {
        cancel_recovery(e, c.deck);
        return TDJ_OK;
    }
    if (c.kind == TDJ_RECOVERY_REPLAY) {
        if (d->state != TDJ_PLAYING || d->braking || d->loop_enabled || d->touch_active || d->jump_pending ||
            d->performance_rate != 1)
            return TDJ_PROTECTED;
        if (!isfinite(c.value) || !isfinite(c.value2) || c.value < 0 || c.value2 > d->asset->frames ||
            c.value2 - c.value < 1 || d->position >= c.value2 || d->bpm <= 0)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.recovery_armed = true;
        proposed.recovery_active = false;
        proposed.recovery_start = c.value;
        proposed.recovery_end = c.value2;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        *d = proposed;
        return TDJ_OK;
    }
    if (c.kind == TDJ_RECOVERY_MIX) {
        for (int i = 0; i < e->deck_count; ++i)
            if (i != c.deck && deck_active(&e->decks[i]))
                return TDJ_PROTECTED;
        if (!d->synced || d->bpm <= 0 || d->state != TDJ_PLAYING || d->braking || d->loop_enabled || d->touch_active ||
            d->jump_pending || d->performance_rate != 1)
            return TDJ_PROTECTED;
        if (!other->asset || other->generation != c.preparation_generation_b)
            return TDJ_STALE;
        if (!other->synced)
            return TDJ_PROTECTED;
        mixer_deck *channel = &e->mix.decks[(c.deck ^ 1)];
        double outgoing_side = (c.deck & 1) == 0 ? -1 : 1;
        if (e->mix.decks[c.deck].crossfader_assignment.target != outgoing_side ||
            channel->crossfader_assignment.target != -outgoing_side ||
            channel->volume.target <= 0.001 || channel->gain.target <= 0.001 ||
            (channel->filter_enabled && fabs(channel->filter_x) > 0.99))
            return TDJ_PROTECTED;
        if (other->state == TDJ_PLAYING || other->state == TDJ_QUEUED || other->loop_enabled || other->touch_active ||
            other->jump_pending || other->bpm <= 0)
            return TDJ_PROTECTED;
        if (!isfinite(c.value) || !isfinite(c.value2) || !isfinite(c.value3) || c.value <= d->position ||
            c.value >= c.value2 || c.value2 > d->asset->frames || (d->recovery_armed && c.value2 != d->recovery_end) ||
            c.value3 < 0 || c.value3 >= other->asset->frames)
            return TDJ_INVALID;
        deck proposed = *other;
        proposed.position = c.value3;
        proposed.continuing = c.value3;
        proposed.synced = true;
        proposed.performance_rate = 1;
        double beats = deck_beat(d, c.value2) - deck_beat(d, c.value);
        if (deck_frame(&proposed, deck_beat(&proposed, c.value3) + beats) >= other->asset->frames)
            return TDJ_INVALID;
        if (proposed.keylock && !supported_deck_keylock(&proposed, e->bpm))
            return TDJ_KEYLOCK_RANGE;
        int status = stream_validate(e, (c.deck ^ 1), &proposed, e->bpm, c.preparation_ticket_b, other->generation);
        if (status != TDJ_OK)
            return status;
        *other = proposed;
        tdj_keylock_reset(e->keylocks[(c.deck ^ 1)]);
        if (!d->recovery_armed)
            d->recovery_start = -1;
        d->recovery_armed = true;
        d->recovery_end = c.value2;
        d->recovery_mix = true;
        d->recovery_mix_start = c.value;
        d->recovery_incoming = c.value3;
        d->recovery_incoming_generation = other->generation;
        return TDJ_OK;
    }
    if (c.kind == TDJ_BRAKE) {
        if (c.flag == 1) {
            if (!isfinite(c.value) || c.value < 0.2 || c.value > 5)
                return TDJ_INVALID;
            if (d->state != TDJ_PLAYING)
                return TDJ_UNRESOLVED;
            if (d->touch_active || d->performance_rate != 1 || d->jump_pending)
                return TDJ_ACTIVE_PERFORMANCE;
            if (d->braking)
                return TDJ_OK;
            // Capture the audible speed without changing the user's Sync choice.
            d->free_rate = source_rate(e, d);
            d->braking = true;
            d->brake_primed = false;
            d->brake_rate = 1;
            d->brake_seconds = c.value;
            d->brake_strength = d->brake_target_strength = 1;
            return TDJ_OK;
        }
        if (c.flag == 2) {
            if (!isfinite(c.value) || c.value < 0.25 || c.value > 4)
                return TDJ_INVALID;
            if (d->braking)
                d->brake_target_strength = c.value;
            return TDJ_OK;
        }
        if (c.flag == 3) {
            if (!d->braking) {
                if (d->state == TDJ_PAUSED)
                    return start_deck(e, d, c.deck, c.preparation_ticket, c.generation);
                return TDJ_OK;
            }
            deck proposed = *d;
            proposed.braking = false;
            if (!align_synced_position(&proposed, beat_now(e)))
                return TDJ_ALIGNMENT_UNAVAILABLE;
            int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
            d->position = proposed.position;
            brake_clear(e, c.deck);
            return TDJ_OK;
        }
        return TDJ_INVALID;
    }
    // Waveform input cannot take the cursor away from an active brake.
    if (d->braking && (c.kind == TDJ_TOUCH || c.kind == TDJ_RATE || c.kind == TDJ_JUMP || c.kind == TDJ_LOOP ||
                       c.kind == TDJ_FLUX || c.kind == TDJ_FREE_RATE || c.kind == TDJ_KEYLOCK || c.kind == TDJ_GRID))
        return TDJ_ACTIVE_PERFORMANCE;
    if (c.kind == TDJ_CUE_RECALL) {
        if (d->state == TDJ_PLAYING || d->state == TDJ_QUEUED)
            return TDJ_UNRESOLVED;
        if (c.flag != 0 || !isfinite(c.value) || c.value < 0 || c.value >= d->asset->frames || !isfinite(c.value2) ||
            c.value2 < 0 || c.value2 > d->asset->frames || (c.value2 > 0 && c.value2 - c.value < 1) ||
            !isfinite(c.value3) || c.value3 < 0 || c.value3 > 32)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.jump_loop = false;
        proposed.jump_pending = false;
        bool restarting = d->state == TDJ_ENDED;
        if (restarting) {
            proposed.state = TDJ_PAUSED;
            proposed.continuing = c.value;
        }
        if (c.value2 > 0) {
            if (!restarting && !d->loop_enabled && !d->touch_active)
                proposed.continuing = d->position;
            proposed.loop_start = c.value;
            proposed.loop_end = c.value2;
            proposed.loop_enabled = true;
            if (c.value3 > 0 || proposed.position < c.value || proposed.position >= c.value2)
                proposed.position = c.value;
        } else {
            proposed.position = c.value;
        }
        int status = start_deck(e, &proposed, c.deck, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        *d = proposed;
        tdj_keylock_reset(e->keylocks[c.deck]);
        transition_request(e, c.deck, 0);
        return TDJ_OK;
    }
    if (c.kind == TDJ_PLAY) {
        if (d->state == TDJ_QUEUED) {
            d->position = d->queued_origin;
            d->state = TDJ_PAUSED;
            d->target = 0;
            if (!any_deck_active(e)) {
                advance_clock_epoch(e);
                e->running = false;
            }
            return TDJ_OK;
        }
        if (d->state == TDJ_PLAYING) {
            brake_clear(e, c.deck);
            d->state = TDJ_PAUSED;
            d->touch_active = false;
            d->touch_end = 0;
            d->jump_pending = false;
            d->pending_touch_rate_valid = false;
            set_performance_rate(e, c.deck, 1);
            double stopped_position = d->position;
            align_synced_position(d, 0);
            if (d->position != stopped_position) {
                tdj_keylock_reset(e->keylocks[c.deck]);
                transition_request(e, c.deck, 0);
            }
            if (!any_deck_active(e)) {
                advance_clock_epoch(e);
                e->running = false;
            }
            return TDJ_OK;
        }
        if (d->state == TDJ_ENDED) {
            deck restarting = *d;
            restarting.state = TDJ_PAUSED;
            restarting.position = 0;
            restarting.continuing = 0;
            restarting.jump_pending = false;
            restarting.jump_loop = false;
            int status = start_deck(e, &restarting, c.deck, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
            *d = restarting;
            tdj_keylock_reset(e->keylocks[c.deck]);
            transition_request(e, c.deck, 0);
            return TDJ_OK;
        }
        return start_deck(e, d, c.deck, c.preparation_ticket, c.generation);
    }
    if (c.kind == TDJ_TOUCH && c.flag == 0 && (c.value == TDJ_TOUCH_CUE_PARK || c.value == TDJ_TOUCH_CUE_CONTINUE)) {
        if (!isfinite(c.value2) || c.value2 < 0 || c.value2 >= d->asset->frames)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.touch_active = false;
        proposed.touch_end = 0;
        proposed.pending_touch_rate_valid = false;
        proposed.jump_pending = false;
        proposed.performance_rate = 1;
        if (c.value == TDJ_TOUCH_CUE_PARK) {
            proposed.state = TDJ_PAUSED;
            proposed.position = c.value2;
            align_synced_position(&proposed, 0);
            proposed.continuing = proposed.position;
        } else if (d->touch_active && d->state == TDJ_PLAYING) {
            if (!align_synced_position(&proposed, beat_now(e)))
                return TDJ_ALIGNMENT_UNAVAILABLE;
            int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
        } else if (!deck_active(d)) {
            proposed.position = c.value2;
            int status = start_deck(e, &proposed, c.deck, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
        }
        *d = proposed;
        if (!any_deck_active(e) && e->running) {
            advance_clock_epoch(e);
            e->running = false;
        }
        tdj_keylock_reset(e->keylocks[c.deck]);
        transition_request(e, c.deck, 0);
        return TDJ_OK;
    }
    if (d->state == TDJ_QUEUED)
        return TDJ_UNRESOLVED;
    // Performance policies are explicit development choices pending paired TDJ1 captures.
    if (c.kind == TDJ_JUMP) {
        if (!isfinite(c.value) || c.value < 0 || c.value >= d->asset->frames || !isfinite(c.value2) || c.value2 < 0 ||
            c.value2 > 32)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.position = c.value;
        proposed.jump_pending = false;
        proposed.jump_loop = false;
        double execution_beat = d->state == TDJ_PLAYING ? beat_now(e) : 0;
        if (c.value2 > 0 && d->state == TDJ_PLAYING && d->synced)
            execution_beat = (floor(beat_now(e) / c.value2) + 1) * c.value2;
        if (!align_synced_position(&proposed, execution_beat))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        double destination = proposed.position;
        if (c.value2 > 0 && d->state == TDJ_PLAYING && d->synced) {
            proposed.position = d->position;
            proposed.jump_frame = destination;
            proposed.jump_beat = (floor(beat_now(e) / c.value2) + 1) * c.value2;
            proposed.jump_pending = true;
        }
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->jump_loop = false;
        if (c.value2 > 0 && d->state == TDJ_PLAYING && d->synced) {
            d->jump_frame = destination;
            d->jump_beat = (floor(beat_now(e) / c.value2) + 1) * c.value2;
            d->jump_pending = true;
        } else {
            d->position = destination;
            d->jump_pending = false;
            if (d->state == TDJ_ENDED)
                d->state = TDJ_PAUSED;
            tdj_keylock_reset(e->keylocks[c.deck]);
            transition_request(e, c.deck, 0);
        }
        return TDJ_OK;
    }
    if (c.kind == TDJ_LOOP_ROLL) {
        if (c.flag != 0 && c.flag != 1)
            return TDJ_INVALID;
        deck proposed = *d;
        bool park = !c.flag && c.value == -1;
        if (c.flag) {
            if (d->state != TDJ_PLAYING || d->loop_enabled || d->touch_active || d->braking ||
                d->jump_pending || d->performance_rate != 1 || d->bpm <= 0)
                return TDJ_ACTIVE_PERFORMANCE;
            if (!isfinite(c.value) || !isfinite(c.value2) || c.value < 0 || c.value2 > d->asset->frames ||
                c.value2 - c.value < 1)
                return TDJ_INVALID;
            proposed.loop_start = c.value;
            proposed.loop_end = c.value2;
            proposed.continuing = d->position;
            if (d->position < c.value || d->position >= c.value2)
                proposed.position = c.value;
        } else {
            if (!d->loop_rolling)
                return TDJ_OK;
            if (d->continuing >= d->asset->frames) {
                proposed.position = d->asset->frames;
                proposed.state = TDJ_ENDED;
            } else {
                proposed.position = d->continuing;
                if (park)
                    proposed.state = TDJ_PAUSED;
            }
        }
        proposed.loop_enabled = proposed.loop_rolling = c.flag != 0;
        if (proposed.state != TDJ_ENDED) {
            if (!align_synced_position(&proposed, proposed.state == TDJ_PLAYING ? beat_now(e) : 0) && !park)
                return TDJ_ALIGNMENT_UNAVAILABLE;
            if (!park) {
                int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
                if (status != TDJ_OK)
                    return status;
            }
        }
        *d = proposed;
        tdj_keylock_reset(e->keylocks[c.deck]);
        transition_request(e, c.deck, 0);
        return TDJ_OK;
    }
    if (c.kind == TDJ_LOOP) {
        if ((c.flag != 0 && c.flag != 1) || !isfinite(c.value3) || c.value3 < 0 || c.value3 > 32)
            return TDJ_INVALID;
        if (c.flag && (!isfinite(c.value) || !isfinite(c.value2) || c.value < 0 || c.value2 > d->asset->frames ||
                       c.value2 - c.value < 1))
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.loop_enabled = c.flag != 0;
        proposed.jump_pending = false;
        if (c.flag) {
            proposed.loop_start = c.value;
            proposed.loop_end = c.value2;
            if (!d->loop_enabled && !d->touch_active)
                proposed.continuing = d->position;
            if (c.value3 > 0 || proposed.position < c.value || proposed.position >= c.value2)
                proposed.position = c.value;
        } else if (d->loop_enabled && d->flux_enabled && !d->touch_active)
            proposed.position = fmin(d->asset->frames - 1, d->continuing);
        double execution_beat = d->state == TDJ_PLAYING ? beat_now(e) : 0;
        if (c.flag && c.value3 > 0 && d->state == TDJ_PLAYING && d->synced)
            execution_beat = (floor(beat_now(e) / c.value3) + 1) * c.value3;
        if (!align_synced_position(&proposed, execution_beat))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        double destination = proposed.position;
        if (c.flag && c.value3 > 0 && d->state == TDJ_PLAYING && d->synced) {
            proposed = *d;
            proposed.jump_frame = c.value;
            proposed.pending_loop_end = c.value2;
            proposed.pending_loop_position = destination;
            proposed.jump_beat = (floor(beat_now(e) / c.value3) + 1) * c.value3;
            proposed.jump_pending = true;
            proposed.jump_loop = true;
        }
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        if (c.flag && c.value3 > 0 && d->state == TDJ_PLAYING && d->synced) {
            d->jump_frame = c.value;
            d->pending_loop_end = c.value2;
            d->pending_loop_position = destination;
            d->jump_beat = (floor(beat_now(e) / c.value3) + 1) * c.value3;
            d->jump_pending = true;
            d->jump_loop = true;
            return TDJ_OK;
        }
        bool reset_loop = d->loop_enabled != (c.flag != 0) ||
                          (c.flag && (d->loop_start != c.value || d->loop_end != c.value2)) ||
                          proposed.position != d->position;
        d->jump_loop = false;
        if (c.flag) {
            if (!d->loop_enabled && !d->touch_active)
                d->continuing = d->position;
            d->loop_start = c.value;
            d->loop_end = c.value2;
            // A saved-loop recall jumps to its start, including while paused or unsynced.
            // Ordinary loop edits retain an in-range source position.
            if (c.value3 > 0 || d->position < c.value || d->position >= c.value2)
                d->position = c.value;
        } else if (d->loop_enabled && d->flux_enabled && !d->touch_active) {
            d->position = fmin(d->asset->frames - 1, d->continuing);
        }
        d->position = proposed.position;
        d->loop_enabled = c.flag != 0;
        d->jump_pending = false;
        if (reset_loop) {
            tdj_keylock_reset(e->keylocks[c.deck]);
            transition_request(e, c.deck, 0);
        }
        return TDJ_OK;
    }
    if (c.kind == TDJ_FLUX) {
        if (c.flag != 0 && c.flag != 1)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.flux_enabled = c.flag != 0;
        if (!d->loop_rolling)
            proposed.continuing = d->position;
        if (c.flag && (d->loop_enabled || d->touch_active)) {
            int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
        }
        d->flux_enabled = proposed.flux_enabled;
        d->continuing = proposed.continuing;
        return TDJ_OK;
    }
    if (c.kind == TDJ_TOUCH) {
        if (c.flag != 0 && c.flag != 1 && c.flag != TDJ_TOUCH_WITH_RATE && c.flag != TDJ_TOUCH_FOLLOWS_POSITION)
            return TDJ_INVALID;
        bool follows_position = c.flag == TDJ_TOUCH_FOLLOWS_POSITION;
        bool with_rate = c.flag == TDJ_TOUCH_WITH_RATE || follows_position;
        if (with_rate && (!isfinite(c.touch_rate) || c.touch_rate < -4 || c.touch_rate > 4))
            return TDJ_INVALID;
        if (!c.flag && !d->touch_active) {
            d->pending_touch_rate_valid = false;
            return TDJ_OK;
        }
        if (c.flag) {
            if (!isfinite(c.value) || c.value < 0 || c.value >= d->asset->frames || !isfinite(c.value2) ||
                c.value2 < 0 || c.value2 > d->asset->frames || (c.value2 > 0 && c.value2 <= c.value) ||
                !isfinite(c.value3) || c.value3 < 0 || c.value3 > 32)
                return TDJ_INVALID;
            bool same_pending = with_rate && d->touch_active && d->jump_pending && !d->jump_loop &&
                                c.value == d->jump_frame && c.value2 == d->pending_touch_end;
            // A rate-bearing update belongs to the current scratch session. Keep
            // its sample cursor continuous; re-anchoring it at each finger event
            // resets the keylock stretcher and produces audible clicks.
            bool same_active = with_rate && d->touch_active && !d->jump_pending && c.value2 == d->touch_end;
            if (same_pending || same_active) {
                deck proposed = *d;
                if (same_pending) {
                    proposed.pending_touch_rate = c.touch_rate;
                    proposed.pending_touch_rate_valid = true;
                } else {
                    proposed.performance_rate = c.touch_rate;
                    if (follows_position) {
                        proposed.position = c.value;
                        proposed.state = TDJ_PLAYING;
                    }
                }
                int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
                if (status != TDJ_OK)
                    return status;
                if (same_pending) {
                    d->pending_touch_rate = c.touch_rate;
                    d->pending_touch_rate_valid = true;
                } else {
                    // Direct drags own position. Keep the existing output-edge ramp.
                    if (follows_position && d->position != c.value) {
                        d->position = c.value;
                        d->touch_start = c.value;
                        tdj_keylock_reset(e->keylocks[c.deck]);
                        transition_request(e, c.deck, 0);
                    }
                    if (follows_position) {
                        d->state = TDJ_PLAYING;
                        if (!e->running) {
                            anchor_clock(e, beat_now(e));
                            e->running = true;
                        }
                    }
                    set_performance_rate(e, c.deck, c.touch_rate);
                }
                return TDJ_OK;
            }
            deck proposed = *d;
            proposed.position = c.value;
            proposed.touch_active = true;
            proposed.touch_start = c.value;
            proposed.touch_end = c.value2;
            proposed.jump_pending = false;
            if (with_rate)
                proposed.performance_rate = c.touch_rate;
            if (!d->touch_active) {
                if (!d->loop_enabled)
                    proposed.continuing = d->position;
                proposed.touch_was_playing = d->state == TDJ_PLAYING;
            }
            proposed.state = TDJ_PLAYING;
            if (c.value3 > 0 && d->state == TDJ_PLAYING && d->synced) {
                proposed.position = d->position;
                proposed.touch_start = d->touch_start;
                proposed.touch_end = d->touch_end;
                proposed.performance_rate = d->performance_rate;
                proposed.jump_loop = false;
                proposed.jump_frame = c.value;
                proposed.jump_beat = (floor(beat_now(e) / c.value3) + 1) * c.value3;
                proposed.jump_pending = true;
                proposed.pending_touch_end = c.value2;
                proposed.pending_touch_rate_valid = with_rate;
                proposed.pending_touch_rate = c.touch_rate;
            }
            int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
            if (status != TDJ_OK)
                return status;
            if (!d->touch_active) {
                if (!d->loop_enabled)
                    d->continuing = d->position;
                d->touch_was_playing = d->state == TDJ_PLAYING;
            }
            d->touch_active = true;
            d->jump_loop = false;
            if (c.value3 > 0 && d->state == TDJ_PLAYING && d->synced) {
                d->jump_frame = c.value;
                d->jump_beat = (floor(beat_now(e) / c.value3) + 1) * c.value3;
                d->jump_pending = true;
                d->pending_touch_end = c.value2;
                d->pending_touch_rate_valid = with_rate;
                d->pending_touch_rate = c.touch_rate;
            } else {
                d->position = c.value;
                d->jump_pending = false;
                d->touch_start = c.value;
                d->touch_end = c.value2;
                if (with_rate)
                    d->performance_rate = c.touch_rate;
                d->pending_touch_rate_valid = false;
            }
            // A contact can relocate the source or switch its playback pipeline.
            // Keep the musical action immediate and correct only its output edge.
            if (!d->jump_pending)
                transition_request(e, c.deck, 0);
            // Audition a held slice even from a stopped deck.
            d->state = TDJ_PLAYING;
            if (!e->running) {
                anchor_clock(e, beat_now(e));
                e->running = true;
            }
        } else if (d->touch_active) {
            deck proposed = *d;
            proposed.touch_active = false;
            proposed.performance_rate = 1;
            proposed.touch_end = 0;
            proposed.jump_pending = false;
            proposed.pending_touch_rate_valid = false;
            if (d->flux_enabled && !d->loop_enabled)
                proposed.position = fmin(d->asset->frames - 1, d->continuing);
            if (!d->touch_was_playing || c.value == TDJ_TOUCH_PARK_RELEASE)
                proposed.state = TDJ_PAUSED;
            if (!align_synced_position(&proposed, proposed.state == TDJ_PLAYING ? beat_now(e) : 0)) {
                if (proposed.state == TDJ_PLAYING && align_synced_position(&proposed, 0)) {
                    proposed.state = TDJ_QUEUED;
                    proposed.queued_origin = proposed.position;
                    proposed.target = floor(beat_now(e)) + 1;
                } else {
                    proposed.state = TDJ_PAUSED;
                }
            }
            if (proposed.state == TDJ_PLAYING || proposed.state == TDJ_QUEUED) {
                int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
                if (status != TDJ_OK)
                    return status;
            }
            *d = proposed;
            transition_request(e, c.deck, 0);
        }
        if (!with_rate || !d->jump_pending)
            tdj_keylock_reset(e->keylocks[c.deck]);
        return TDJ_OK;
    }
    if (c.kind == TDJ_RATE) {
        if (!isfinite(c.value) || c.value < -4 || c.value > 4)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.performance_rate = c.value;
        if (c.value == 1 && !align_synced_position(&proposed, d->state == TDJ_PLAYING ? beat_now(e) : 0))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->position = proposed.position;
        set_performance_rate(e, c.deck, c.value);
        return TDJ_OK;
    }
    if (c.kind == TDJ_FREE_RATE) {
        // Unsynced tempo fader: value is the speed ratio, limited to ±50 %.
        if (!valid_deck_command(e, c.deck) || !isfinite(c.value) || c.value < 0.5 || c.value > 1.5)
            return TDJ_INVALID;
        deck *d = &e->decks[c.deck];
        if (d->keylock && !supported_keylock_rate(c.value))
            return TDJ_KEYLOCK_RANGE;
        deck proposed = *d;
        proposed.free_rate = c.value;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->free_rate = c.value;
        return TDJ_OK;
    }
    if (c.kind == TDJ_KEYLOCK) {
        if (c.flag != 0 && c.flag != 1)
            return TDJ_INVALID;
        if (c.flag && !supported_deck_keylock(d, e->bpm))
            return TDJ_KEYLOCK_RANGE;
        deck proposed = *d;
        proposed.keylock = c.flag != 0;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->keylock = c.flag != 0;
        return TDJ_OK;
    }
    if (c.kind == TDJ_SYNC_RESTORE) {
        if (d->state != TDJ_PLAYING || !e->running || d->bpm <= 0)
            return TDJ_INVALID;
        // An active waveform contact retains its ownership until release.
        if (d->braking || d->touch_active || d->performance_rate != 1)
            return TDJ_ACTIVE_PERFORMANCE;
        if (d->keylock && !supported_keylock_rate(e->bpm / deck_bpm(d)))
            return TDJ_KEYLOCK_RANGE;
        double position;
        if (!nearest_sync_position(d, beat_now(e), &position))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        deck proposed = *d;
        proposed.synced = true;
        proposed.position = position;
        if (proposed.keylock && !supported_deck_keylock(&proposed, e->bpm))
            return TDJ_KEYLOCK_RANGE;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->synced = true;
        d->position = position;
        tdj_keylock_reset(e->keylocks[c.deck]);
        transition_request(e, c.deck, 0);
        return TDJ_OK;
    }
    if (c.kind == TDJ_SYNC) {
        if (c.flag != 0 && c.flag != 1)
            return TDJ_INVALID;
        if (c.flag && d->bpm > 0 && d->keylock && !supported_keylock_rate(e->bpm / deck_bpm(d)))
            return TDJ_KEYLOCK_RANGE;
        deck proposed = *d;
        if (!c.flag && (d->state == TDJ_PLAYING || d->state == TDJ_PAUSED))
            proposed.free_rate = source_rate(e, d);
        proposed.synced = c.flag != 0;
        if (c.flag && d->state == TDJ_PLAYING && !align_synced_position(&proposed, beat_now(e)))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        if (proposed.keylock && !supported_deck_keylock(&proposed, e->bpm))
            return TDJ_KEYLOCK_RANGE;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        if (!c.flag && (d->state == TDJ_PLAYING || d->state == TDJ_PAUSED))
            d->free_rate = source_rate(e, d);
        if (d->position != proposed.position) {
            d->position = proposed.position;
            tdj_keylock_reset(e->keylocks[c.deck]);
            transition_request(e, c.deck, 0);
        }
        d->synced = c.flag != 0;
        return TDJ_OK;
    }
    if (c.kind == TDJ_ADAPTIVE_GRID) {
        if (d->state == TDJ_PLAYING || d->state == TDJ_QUEUED || d->touch_active || d->loop_enabled || d->jump_pending)
            return TDJ_PROTECTED;
        if (c.beatgrid.count &&
            (!tdj_beatgrid_validate(c.beatgrid, d->asset->frames) || c.beatgrid.sample_rate != d->asset->rate))
            return TDJ_INVALID;
        if (d->keylock && d->synced && c.beatgrid.count)
            for (unsigned k = 1; k < c.beatgrid.count; k++) {
                double bpm = 60 * c.beatgrid.sample_rate * (c.beatgrid.beats[k] - c.beatgrid.beats[k - 1]) /
                             (c.beatgrid.frames[k] - c.beatgrid.frames[k - 1]);
                if (!supported_keylock_rate(e->bpm / bpm))
                    return TDJ_KEYLOCK_RANGE;
            }
        d->grid_click_position_valid = false;
        d->map = c.beatgrid;
        d->map_dirty = true;
        return TDJ_OK;
    }
    if (c.kind == TDJ_GRID) {
        if (!isfinite(c.value) || c.value <= 0 || !isfinite(c.value2) || c.flag < 0 || c.flag > 3)
            return TDJ_INVALID;
        if (d->keylock && d->synced && !supported_keylock_rate(e->bpm / c.value))
            return TDJ_KEYLOCK_RANGE;
        deck proposed = *d;
        proposed.bpm = c.value;
        proposed.map.count = 0;
        proposed.anchor = c.value2;
        proposed.downbeat = c.flag;
        if (d->state == TDJ_PLAYING && !align_synced_position(&proposed, beat_now(e)))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        if (d->position != proposed.position) {
            d->position = proposed.position;
            tdj_keylock_reset(e->keylocks[c.deck]);
            transition_request(e, c.deck, 0);
        }
        d->grid_click_position_valid = false;
        d->map.count = 0;
        d->map_dirty = true;
        d->bpm = c.value;
        d->anchor = c.value2;
        d->downbeat = c.flag;
        return TDJ_OK;
    }
    if (c.kind == TDJ_SEEK) {
        if (d->state == TDJ_PLAYING)
            return TDJ_UNRESOLVED;
        if (!isfinite(c.value) || c.value < 0 || c.value >= d->asset->frames)
            return TDJ_INVALID;
        deck proposed = *d;
        proposed.position = c.value;
        if (!align_synced_position(&proposed, 0))
            return TDJ_ALIGNMENT_UNAVAILABLE;
        int status = stream_validate(e, c.deck, &proposed, e->bpm, c.preparation_ticket, c.generation);
        if (status != TDJ_OK)
            return status;
        d->position = proposed.position;
        d->state = TDJ_PAUSED;
        tdj_keylock_reset(e->keylocks[c.deck]);
        mixer_clear_track(&e->mix.decks[c.deck]);
        transition_request(e, c.deck, 0);
        return TDJ_OK;
    }
    return TDJ_INVALID;
}

static void controls(tdj_engine *e) {
    unsigned read = atomic_load_explicit(&e->command_read, memory_order_relaxed);
    unsigned handled = 0;
    while (handled++ < COMMAND_CAPACITY && read != atomic_load_explicit(&e->command_write, memory_order_acquire)) {
        // Leave room for both an acknowledgement and an asset retirement.
        unsigned mw = atomic_load_explicit(&e->message_write, memory_order_relaxed);
        unsigned mr = atomic_load_explicit(&e->message_read, memory_order_acquire);
        if ((mr + MESSAGE_CAPACITY - mw - 1) % MESSAGE_CAPACITY < 2)
            break;
        tdj_command c = e->commands[read];
        bool same_touch = false, touch_noop = false;
        if (c.kind == TDJ_TOUCH && c.flag == 0 && c.value > TDJ_TOUCH_CUE_PARK && valid_deck_command(e, c.deck))
            touch_noop = !e->decks[c.deck].touch_active;
        if (c.kind == TDJ_TOUCH && c.flag == TDJ_TOUCH_WITH_RATE && valid_deck_command(e, c.deck)) {
            deck *d = &e->decks[c.deck];
            same_touch =
                d->touch_active &&
                ((d->jump_pending && !d->jump_loop && c.value == d->jump_frame && c.value2 == d->pending_touch_end) ||
                 (!d->jump_pending && c.value == d->touch_start && c.value2 == d->touch_end));
        }
        int status = apply(e, c);
        if (status == TDJ_OK) {
            if (c.kind == TDJ_PANIC || c.kind == TDJ_PLAY ||
                (c.kind == TDJ_MIXER && (c.flag == TDJ_MIX_CROSSFADE || c.flag == TDJ_MIX_VOLUME))) {
                for (int i = 0; i < e->deck_count; ++i)
                    cancel_recovery(e, i);
            } else if (valid_deck_command(e, c.deck) &&
                       (c.kind == TDJ_LOAD || c.kind == TDJ_EJECT || c.kind == TDJ_SEEK || c.kind == TDJ_JUMP ||
                        c.kind == TDJ_LOOP || c.kind == TDJ_LOOP_ROLL ||
                        c.kind == TDJ_TOUCH || c.kind == TDJ_CUE_RECALL || c.kind == TDJ_GRID ||
                        (c.kind == TDJ_BRAKE && c.flag == 1) || c.kind == TDJ_ADAPTIVE_GRID || c.kind == TDJ_RATE ||
                        c.kind == TDJ_BRAKE || c.kind == TDJ_FREE_RATE || c.kind == TDJ_SYNC_RESTORE ||
                        c.kind == TDJ_SYNC)) {
                cancel_recovery(e, c.deck);
            }
            if (c.kind == TDJ_RECOVERY_MIX)
                add_claim(e, e->decks[(c.deck ^ 1)].asset, c.preparation_ticket_b, (unsigned)((c.deck ^ 1)), false);
            if (c.kind == TDJ_TEMPO) {
                for (int i = 0; i < e->deck_count; ++i)
                    add_claim(e, e->decks[i].asset, tempo_ticket(c, i), (unsigned)i, false);
            } else if (valid_deck_command(e, c.deck)) {
                bool source_action = c.kind == TDJ_JUMP || c.kind == TDJ_LOOP || c.kind == TDJ_LOOP_ROLL ||
                                     c.kind == TDJ_TOUCH ||
                                     c.kind == TDJ_SEEK || c.kind == TDJ_CUE_RECALL || c.kind == TDJ_SYNC_RESTORE;
                if (source_action && !same_touch && !touch_noop)
                    release_deck_claims(e, (unsigned)c.deck);
                add_claim(e, e->decks[c.deck].asset, c.preparation_ticket, (unsigned)c.deck,
                          source_action && e->decks[c.deck].jump_pending);
            }
        }
        message(e, c.id, c.generation, status);
        if ((c.kind == TDJ_LOAD || (c.kind == TDJ_PAD_LOAD && c.asset)) && status != TDJ_OK)
            message(e, 0, c.generation, TDJ_RETIRED);
        read = (read + 1) % COMMAND_CAPACITY;
        atomic_store_explicit(&e->command_read, read, memory_order_release);
    }
}

void tdj_master_meter_enable(tdj_engine *e, bool enabled) {
    atomic_store_explicit(&e->master_meter_enabled, enabled, memory_order_relaxed);
}
tdj_master_meter tdj_master_meter_read(tdj_engine *e) {
    if (!atomic_load_explicit(&e->master_meter_enabled, memory_order_relaxed))
        return (tdj_master_meter){0};
    return (tdj_master_meter){
        atomic_load_explicit(&e->master_peak[0], memory_order_relaxed),
        atomic_load_explicit(&e->master_peak[1], memory_order_relaxed),
        atomic_load_explicit(&e->master_clip[0], memory_order_relaxed) != 0,
        atomic_load_explicit(&e->master_clip[1], memory_order_relaxed) != 0,
    };
}
static void update_master_meter(tdj_engine *e, const float *left, const float *right, uint32_t count) {
    if (!count || !atomic_load_explicit(&e->master_meter_enabled, memory_order_relaxed))
        return;
    float peak[2] = {0, 0};
    for (uint32_t i = 0; i < count; ++i) {
        peak[0] = fmaxf(peak[0], fabsf(left[i]));
        peak[1] = fmaxf(peak[1], fabsf(right[i]));
    }
    double decay = exp(-5 * count / e->rate);
    for (unsigned i = 0; i < 2; ++i) {
        double previous = atomic_load_explicit(&e->master_peak[i], memory_order_relaxed);
        atomic_store_explicit(&e->master_peak[i], fmax(peak[i], previous * decay), memory_order_relaxed);
        uint32_t clip = atomic_load_explicit(&e->master_clip[i], memory_order_relaxed);
        clip = peak[i] >= 1 ? (uint32_t)(e->rate * 0.4) : clip > count ? clip - count : 0;
        atomic_store_explicit(&e->master_clip[i], clip, memory_order_relaxed);
    }
}
void tdj_preview_set_generation(tdj_engine *e, uint64_t generation) {
    atomic_store_explicit(&e->auxiliary.preview.generation, generation, memory_order_release);
}
uint64_t tdj_preview_generation(tdj_engine *e) {
    return atomic_load_explicit(&e->auxiliary.preview.generation, memory_order_acquire);
}
uint64_t tdj_preview_consumed(tdj_engine *e) {
    preview_ring *preview = &e->auxiliary.preview;
    uint64_t generation = atomic_load_explicit(&preview->consumed_generation, memory_order_acquire);
    return generation == tdj_preview_generation(e) ? atomic_load_explicit(&preview->consumed, memory_order_relaxed) : 0;
}
bool tdj_preview_push(tdj_engine *e, const float *stereo, uint32_t count, double rate, uint64_t generation) {
    return preview_push(&e->auxiliary.preview, stereo, count, rate, generation);
}
uint32_t tdj_playing_pads(tdj_engine *e) {
    return atomic_load_explicit(&e->auxiliary.published_playing, memory_order_acquire);
}

void tdj_microphone_set_enabled(tdj_engine *e, bool enabled) {
    microphone_configure(&e->auxiliary, enabled ? 2 : 0);
}

void tdj_microphone_push(tdj_engine *e, const float *samples, uint32_t count, uint32_t stride, double rate) {
    tdj_external_input_push(e, samples, samples, count, stride, rate);
}
void tdj_external_input_push(tdj_engine *e, const float *left, const float *right, uint32_t count, uint32_t stride,
                             double rate) {
    const float *input[] = {left, right};
    const uint32_t strides[] = {stride, stride};
    microphone_push(&e->auxiliary, input, strides, count, 2, rate);
}
void tdj_s4_input_set_channels(tdj_engine *e, uint32_t channels) {
    if (channels == 0 || ((channels == 4 || channels == 6) &&
                         atomic_load_explicit(&e->extra_prepared, memory_order_acquire)))
        microphone_configure(&e->auxiliary, channels);
}
void tdj_s4_mic_set_level(tdj_engine *e, double level) {
    if (isfinite(level) && level >= 0 && level <= 1)
        atomic_store_explicit(&e->auxiliary.s4_mic_level, level, memory_order_relaxed);
}
void tdj_s4_input_push(tdj_engine *e, const float *const *input, const uint32_t *strides, uint32_t count,
                       uint32_t channels, double rate) {
    if (input && strides && (channels == 4 || channels == 6))
        microphone_push(&e->auxiliary, input, strides, count, channels, rate);
}
void tdj_external_input_mix(tdj_engine *e, double level, double cue_gain) {
    if (isfinite(level) && level >= 0 && level <= 4)
        atomic_store_explicit(&e->auxiliary.input_level, level, memory_order_relaxed);
    if (isfinite(cue_gain) && cue_gain >= 0 && cue_gain <= 4)
        atomic_store_explicit(&e->auxiliary.input_cue, cue_gain, memory_order_relaxed);
}

bool tdj_render(tdj_engine *e, uint32_t count, float *left, float *right) {
    return tdj_render_buses(e, count, left, right, NULL, NULL);
}
static bool render_buses_internal(tdj_engine *e, tdj_recording *recording, uint32_t count, float *left, float *right,
                                  float *cue_left, float *cue_right);
bool tdj_render_buses(tdj_engine *e, uint32_t count, float *left, float *right, float *cue_left, float *cue_right) {
    return tdj_render_recorded_buses(e, NULL, count, left, right, cue_left, cue_right);
}
bool tdj_render_recorded_buses(tdj_engine *e, tdj_recording *recording, uint32_t count, float *left, float *right,
                               float *cue_left, float *cue_right) {
#if defined(__aarch64__) || defined(__arm64__)
    if (!count)
        return render_buses_internal(e, recording, count, left, right, cue_left, cue_right);
    uint64_t saved_fpcr;
    __asm__ volatile("mrs %0, fpcr" : "=r"(saved_fpcr));
    const uint64_t render_fpcr = saved_fpcr | (UINT64_C(1) << 24);
    if (render_fpcr != saved_fpcr)
        __asm__ volatile("msr fpcr, %0" ::"r"(render_fpcr) : "memory");
    const bool rendered = render_buses_internal(e, recording, count, left, right, cue_left, cue_right);
    if (render_fpcr != saved_fpcr)
        __asm__ volatile("msr fpcr, %0" ::"r"(saved_fpcr) : "memory");
    return rendered;
#else
    return render_buses_internal(e, recording, count, left, right, cue_left, cue_right);
#endif
}
static bool render_buses_internal(tdj_engine *e, tdj_recording *recording, uint32_t count, float *left, float *right,
                                  float *cue_left, float *cue_right) {
    if (count && (!left || !right || ((cue_left == NULL) != (cue_right == NULL))))
        return false;
    if (atomic_flag_test_and_set_explicit(&e->render_busy, memory_order_acquire)) {
        if (count) {
            memset(left, 0, count * sizeof(float));
            memset(right, 0, count * sizeof(float));
            if (cue_left) {
                memset(cue_left, 0, count * sizeof(float));
                memset(cue_right, 0, count * sizeof(float));
            }
        }
        return false;
    }
    for (int i = 0; i < e->deck_count; i++)
        if (e->decks[i].asset && !asset_is_used(e, e->decks[i].asset, 0, i, -1))
            tdj_stream_render_begin(e->decks[i].asset, e->frame);
    controls(e);
    auxiliary_mix *aux = &e->auxiliary;
    mic_block mic = microphone_begin(aux, e->rate);
    if (mic.channels == 2) {
        double input_level = atomic_load_explicit(&aux->input_level, memory_order_relaxed);
        double input_cue = atomic_load_explicit(&aux->input_cue, memory_order_relaxed);
        if (input_level != aux->input_master_ramp.target)
            ramp_set(&aux->input_master_ramp, input_level, e->mix.smoothing);
        if (input_cue != aux->input_cue_ramp.target)
            ramp_set(&aux->input_cue_ramp, input_cue, e->mix.smoothing);
    } else if (mic.channels == 6) {
        double level = atomic_load_explicit(&aux->s4_mic_level, memory_order_relaxed);
        if (level != aux->s4_mic_ramp.target)
            ramp_set(&aux->s4_mic_ramp, level, e->mix.smoothing);
    }
    preview_block preview = preview_begin(&aux->preview, e->rate);
    uint32_t preview_read = preview.read;
    bool capacity = !e->maximum_output_frames || count <= e->maximum_output_frames;
    for (int i = 0; capacity && i < e->deck_count; ++i)
        capacity = tdj_stream_can_render(e->decks[i].asset, count);
    if (!capacity) {
        if (count) {
            memset(left, 0, count * sizeof(float));
            memset(right, 0, count * sizeof(float));
            if (cue_left) {
                memset(cue_left, 0, count * sizeof(float));
                memset(cue_right, 0, count * sizeof(float));
            }
        }
        atomic_flag_clear_explicit(&e->render_busy, memory_order_release);
        return false;
    }
    if (count)
        for (int i = 0; i < e->deck_count; i++)
            resume_starved_stream(e, i);
    uint64_t missing[TDJ_DECK_COUNT] = {0};
    uint64_t recorded_generations[TDJ_DECK_COUNT] = {0};
    uint32_t recorded_offsets[TDJ_DECK_COUNT] = {UINT32_MAX, UINT32_MAX, UINT32_MAX, UINT32_MAX};
    for (int deck = 0; deck < e->deck_count; deck++) {
        double bpm, beat;
        effect_clock(e, deck, &bpm, &beat);
        for (int slot = 0; slot < 3; slot++)
            fx_prepare(&e->effects[deck][slot], e->rate, bpm);
    }
    uint64_t target_frames[TDJ_DECK_COUNT] = {UINT64_MAX, UINT64_MAX, UINT64_MAX, UINT64_MAX};
    for (int i = 0; i < e->deck_count; ++i) {
        if (e->decks[i].state == TDJ_QUEUED) {
            double offset = (e->decks[i].target * (60 * e->rate) - e->epoch_ticks) / e->bpm;
            if (offset <= 0)
                target_frames[i] = e->frame;
            else if (offset < (double)(UINT64_MAX - e->epoch_frame))
                target_frames[i] = e->epoch_frame + (uint64_t)ceil(offset);
        }
    }
    bool s4 = mic.channels >= 4;
    int mix_decks = s4 ? TDJ_DECK_COUNT : e->deck_count;
    for (int i = 0; i < mix_decks; ++i)
        e->mix.decks[i].peak = 0;
    for (uint32_t f = 0; f < count; ++f) {
        double l = 0, r = 0, cl = 0, cr = 0;
        double live[6];
        if (s4)
            microphone_next(aux, &mic, live);
        bool audible[TDJ_DECK_COUNT] = {false};
        for (int i = 0; i < e->deck_count; i++) {
            deck *d = &e->decks[i], *other = &e->decks[(i ^ 1)];
            if (!d->recovery_mix || d->state != TDJ_PLAYING || d->stream_starved)
                continue;
            if (other->generation != d->recovery_incoming_generation) {
                d->recovery_mix = false;
                continue;
            }
            if (d->position >= d->recovery_mix_start) {
                if (!d->recovery_mixing) {
                    mixer_deck *channel = &e->mix.decks[(i ^ 1)];
                    if (other->state == TDJ_PLAYING || other->state == TDJ_QUEUED || channel->volume.target <= 0.001 ||
                        channel->gain.target <= 0.001 || (channel->filter_enabled && fabs(channel->filter_x) > 0.99)) {
                        d->recovery_mix = false;
                        continue;
                    }
                    other->state = TDJ_PLAYING;
                    other->last_start = e->frame;
                    d->recovery_mixing = true;
                }
                double first = deck_beat(d, d->recovery_mix_start), last = deck_beat(d, d->recovery_end);
                double progress = fmax(0, fmin(1, (deck_beat(d, d->position) - first) / (last - first)));
                ramp_set(&e->mix.crossfader, (i & 1) == 0 ? progress : 1 - progress, 0);
            }
        }
        double cross = ramp_next(&e->mix.crossfader);
        double master = ramp_next(&e->mix.master), monitor = ramp_next(&e->mix.monitor),
               blend = ramp_next(&e->mix.cue_mix);
        for (int i = 0; i < mix_decks; ++i) {
            deck *d = &e->decks[i];
            bool line = s4 && i >= 2 && !d->asset;
            if (i >= 2 && !line && !d->asset && !e->transitions[i].playing && !e->transitions[i].remaining)
                continue;
            if (d->state == TDJ_QUEUED && e->frame >= target_frames[i]) {
                d->state = TDJ_PLAYING;
                d->last_start = e->frame;
            }
            double volume = ramp_next(&e->mix.decks[i].volume), cue = ramp_next(&e->mix.decks[i].cue);
            dry_transition *transition = &e->transitions[i];
            if (d->state == TDJ_PLAYING && (!isfinite(d->position) || d->position >= d->asset->frames))
                d->state = TDJ_ENDED;
            if (d->braking && d->state != TDJ_PLAYING)
                brake_clear(e, i);
            bool playing = d->state == TDJ_PLAYING;
            if (playing != transition->playing)
                transition_request(e, i, 0);
            transition->playing = playing;
            if (!playing) {
                d->grid_click_position_valid = false;
                double zero_l = line ? live[(i - 2) * 2] : 0;
                double zero_r = line ? live[(i - 2) * 2 + 1] : 0;
                transition_sample(transition, &zero_l, &zero_r);
                mixer_process_deck(&e->mix, i, &zero_l, &zero_r);
                double fx_bpm, fx_beat;
                effect_clock(e, i, &fx_bpm, &fx_beat);
                for (int k = 0; k < 3; k++)
                    fx_process(&e->effects[i][k], e->rate, fx_bpm, fx_beat, &zero_l, &zero_r);
                double level = volume * mixer_crossfader_gain(&e->mix.decks[i], cross);
                l += zero_l * level;
                r += zero_r * level;
                cl += zero_l * cue;
                cr += zero_r * cue;
                continue;
            }
            if (d->jump_pending && beat_now(e) >= d->jump_beat) {
                double destination = d->jump_loop ? d->pending_loop_position : d->jump_frame;
                if (d->jump_loop) {
                    if (!d->loop_enabled && !d->touch_active)
                        d->continuing = d->position;
                    d->loop_start = d->jump_frame;
                    d->loop_end = d->pending_loop_end;
                    d->loop_enabled = true;
                    d->jump_loop = false;
                }
                d->position = destination;
                d->jump_pending = false;
                if (d->touch_active) {
                    d->touch_start = d->jump_frame;
                    d->touch_end = d->pending_touch_end;
                }
                if (d->touch_active && d->pending_touch_rate_valid) {
                    d->performance_rate = d->pending_touch_rate;
                    d->pending_touch_rate_valid = false;
                }
                tdj_keylock_reset(e->keylocks[i]);
                transition_request(e, i, 0);
            }
            double wrap_start = 0, wrap_end = 0;
            if (d->touch_active && d->touch_end > d->touch_start) {
                wrap_start = d->touch_start;
                wrap_end = d->touch_end;
            } else if (d->loop_enabled) {
                wrap_start = d->loop_start;
                wrap_end = d->loop_end;
            } else if (d->recovery_armed && d->recovery_start >= 0 && !d->recovery_mixing &&
                       d->position >= d->recovery_start) {
                wrap_start = d->recovery_start;
                wrap_end = d->recovery_end;
            }
            float source_l, source_r;
            if (d->stream_starved)
                source_l = source_r = 0;
            else if (d->braking)
                brake_sample(e, i, wrap_start, wrap_end, &source_l, &source_r);
            else if (d->performance_rate != 1) {
                uint64_t at = (uint64_t)fmax(0, fmin(d->asset->frames - 1, floor(d->position)));
                uint64_t next = at + 1 < d->asset->frames ? at + 1 : at;
                double fraction = d->position - floor(d->position);
                if (wrap_end > wrap_start && next >= wrap_end)
                    next = (uint64_t)wrap_start;
                if (d->asset->stream) {
                    float al, ar, bl, br;
                    tdj_stream_render_read_stereo(d->asset, at, &al, &ar);
                    tdj_stream_render_read_stereo(d->asset, next, &bl, &br);
                    source_l = al * (1 - fraction) + bl * fraction;
                    source_r = ar * (1 - fraction) + br * fraction;
                } else {
                    source_l = d->asset->samples[2 * at] * (1 - fraction) + d->asset->samples[2 * next] * fraction;
                    source_r =
                        d->asset->samples[2 * at + 1] * (1 - fraction) + d->asset->samples[2 * next + 1] * fraction;
                }
                if (d->performance_rate == 0)
                    source_l = source_r = 0;
            } else if (d->asset->stream)
                tdj_keylock_sample_stream_spans(e->keylocks[i], d->asset, tdj_stream_render_read_stereo,
                                                tdj_stream_render_span, d->asset->frames, d->asset->rate, d->position,
                                                source_rate(e, d), d->keylock, wrap_start, wrap_end, &source_l,
                                                &source_r);
            else
                tdj_keylock_sample_loop(e->keylocks[i], d->asset->samples, d->asset->frames, d->asset->rate,
                                        d->position, source_rate(e, d), d->keylock, wrap_start, wrap_end, &source_l,
                                        &source_r);
            if (d->asset->stream) {
                bool failed = d->stream_starved || tdj_stream_read_failed(d->asset);
                if (failed) {
                    if (!missing[i])
                        tdj_stream_missing_frame(d->asset, e->frame);
                    missing[i]++;
                    d->stream_starved = can_park_starved_stream(d);
                    d->stream_failed = true;
                    d->stream_fade = fmax(0, d->stream_fade - 1 / (e->rate * 0.005));
                    source_l = d->stream_last_l * d->stream_fade;
                    source_r = d->stream_last_r * d->stream_fade;
                } else {
                    d->stream_last_l = source_l;
                    d->stream_last_r = source_r;
                    if (d->stream_failed) {
                        d->stream_fade = fmin(1, d->stream_fade + 1 / (e->rate * 0.005));
                        source_l *= d->stream_fade;
                        source_r *= d->stream_fade;
                    }
                    if (d->stream_fade == 1)
                        d->stream_failed = false;
                }
            }
            double dl = source_l, dr = source_r;
            transition_sample(transition, &dl, &dr);
            mixer_process_deck(&e->mix, i, &dl, &dr);
            double fx_bpm, fx_beat;
            effect_clock(e, i, &fx_bpm, &fx_beat);
            for (int k = 0; k < 3; k++)
                fx_process(&e->effects[i][k], e->rate, fx_bpm, fx_beat, &dl, &dr);
            double level = volume * mixer_crossfader_gain(&e->mix.decks[i], cross);
            l += dl * level;
            r += dr * level;
            cl += dl * cue;
            cr += dr * cue;
            audible[i] = level > 1e-7 && (fabs(dl) + fabs(dr)) > 1e-7;
            if (recording && recorded_offsets[i] == UINT32_MAX && audible[i] && master > 1e-7) {
                recorded_offsets[i] = f;
                recorded_generations[i] = d->generation;
            }
            double step = d->asset->rate / e->rate * source_rate(e, d);
            if ((d->touch_active && d->touch_was_playing) || (d->loop_enabled && !d->touch_active))
                d->continuing += d->map.count && d->synced
                                     ? d->asset->rate / e->rate * e->bpm / deck_bpm_at(d, d->continuing)
                                     : step;
            else if (!d->touch_active)
                d->continuing = d->position;
            if (d->stream_starved) {
                d->grid_click_position_valid = false;
                continue;
            }
            if (cue_left && d->grid_click && cue > 0 && d->performance_rate > 0) {
                double tick = grid_click_sample(d, e->rate, step) * cue;
                cl += tick;
                cr += tick;
            } else if (d->grid_click)
                d->grid_click_position_valid = false;
            d->position += step * d->performance_rate * (d->braking ? d->brake_rate : 1);
            if (d->braking) {
                double smoothing = fmin(1, 1 / (e->rate * 0.01));
                d->brake_strength += (d->brake_target_strength - d->brake_strength) * smoothing;
                d->brake_rate = fmax(0, d->brake_rate - d->brake_strength / (e->rate * d->brake_seconds));
                if (d->brake_rate < 1e-10) {
                    d->state = TDJ_PAUSED;
                    d->continuing = d->position;
                    brake_clear(e, i);
                }
            }
            if (d->touch_active && d->touch_end > d->touch_start) {
                double length = d->touch_end - d->touch_start;
                double offset = fmod(d->position - d->touch_start, length);
                d->position = d->touch_start + (offset < 0 ? offset + length : offset);
            } else if (d->loop_enabled) {
                double length = d->loop_end - d->loop_start;
                bool wrapped = d->position < d->loop_start || d->position >= d->loop_end;
                double offset = fmod(d->position - d->loop_start, length);
                d->position = d->loop_start + (offset < 0 ? offset + length : offset);
                // Spectral overlap already joins its loop. Granular and scratch
                // loops retain their own edges. Limit seam correction to a quarter loop.
                if (wrapped && d->performance_rate == 1 && !tdj_keylock_spectral(e->keylocks[i])) {
                    double period = length / fmax(1e-12, fabs(step));
                    unsigned limit = (unsigned)fmin(ceil(e->rate * 0.002), floor(period / 4));
                    if (limit >= 2)
                        transition_request(e, i, limit);
                }
            } else if (d->position < 0)
                d->position = 0;
            if (d->recovery_armed && d->position >= d->recovery_end) {
                if (d->recovery_mixing || d->recovery_start < 0) {
                    if (d->recovery_mixing)
                        ramp_set(&e->mix.crossfader, (i & 1) == 0 ? 1 : 0, 0);
                    d->position = d->recovery_end;
                    d->state = TDJ_ENDED;
                    d->recovery_armed = false;
                    d->recovery_mix = false;
                    d->recovery_mixing = false;
                } else {
                    double length = d->recovery_end - d->recovery_start;
                    d->position = d->recovery_start + fmod(d->position - d->recovery_end, length);
                    d->recovery_active = true;
                    transition_request(e, i, 0);
                }
            }
            if (d->position >= d->asset->frames) {
                d->position = d->asset->frames;
                d->state = TDJ_ENDED;
                brake_clear(e, i);
            }
        }
        if (audible[0] && audible[1] && master > 1e-7)
            e->paired_frames++;
        if (aux->playing || aux->pad_gain.remaining)
            mix_pads(aux, e->rate, &l, &r);
        if (mic.channels == 2) {
            double input[2];
            microphone_next(aux, &mic, input);
            double level = ramp_next(&aux->input_master_ramp), cue = ramp_next(&aux->input_cue_ramp);
            l += input[0] * level;
            r += input[1] * level;
            cl += input[0] * cue;
            cr += input[1] * cue;
        } else if (mic.channels == 6) {
            double mono = (live[4] + live[5]) * 0.5 * ramp_next(&aux->s4_mic_ramp);
            l += mono;
            r += mono;
        }
        left[f] = (float)(l * master);
        right[f] = (float)(r * master);
        if (cue_left) {
            double hl = cl * (1 - blend) + l * master * blend;
            double hr = cr * (1 - blend) + r * master * blend;
            if (preview.generation)
                preview_next(&aux->preview, &preview, &hl, &hr);
            cue_left[f] = (float)(hl * monitor);
            cue_right[f] = (float)(hr * monitor);
        }
        e->frame++;
        if (e->running && !any_deck_active(e)) {
            advance_clock_epoch(e);
            e->running = false;
        }
    }
    update_master_meter(e, left, right, count);
    if (preview.read != preview_read)
        atomic_fetch_add_explicit(&aux->preview.consumed, preview.read - preview_read, memory_order_relaxed);
    atomic_store_explicit(&aux->preview.read, preview.read, memory_order_release);
    atomic_store_explicit(&aux->mic_read, mic.read, memory_order_release);
    atomic_store_explicit(&aux->published_playing, aux->playing, memory_order_release);
    for (int i = 0; i < e->deck_count; i++) {
        deck *d = &e->decks[i];
        if (!d->asset || !d->asset->stream || asset_is_used(e, d->asset, 0, i, -1))
            continue;
        tdj_stream_request desired = {0}, required = {0};
        for (int j = i; j < e->deck_count; j++)
            if (e->decks[j].asset == d->asset) {
                tdj_stream_request part;
                if (deck_request(e, &e->decks[j], e->bpm, true, &part) > 0) {
                    if (!desired.count)
                        desired = part;
                    else
                        (void)append_request(&desired, &part);
                }
                if (deck_request(e, &e->decks[j], e->bpm, false, &part) > 0) {
                    if (!required.count)
                        required = part;
                    else
                        (void)append_request(&required, &part);
                }
            }
        for (unsigned r = 0; r < desired.count; r++)
            desired.ranges[r].priority = 1;
        (void)append_request(&desired, &required);
        tdj_stream_render_require(d->asset, &required);
        tdj_stream_render_request(d->asset, &desired);
        bool low = !tdj_stream_covers(d->asset, &required);
        tdj_stream_observe_reserve(d->asset, d->position, low);
        uint64_t missed = missing[i];
        for (int j = i + 1; j < e->deck_count; ++j)
            if (e->decks[j].asset == d->asset) {
                tdj_stream_observe_reserve(d->asset, e->decks[j].position, false);
                missed += missing[j];
            }
        tdj_stream_render_end(d->asset, missed);
    }
    for (unsigned n = 0; n < TDJ_STREAM_MAX_TICKETS * (unsigned)e->deck_count; n++) {
        stream_claim *c = &e->claims[n];
        if (!c->asset)
            continue;
        if (c->pending) {
            bool pending = false;
            for (int i = 0; i < e->deck_count; i++)
                if ((c->decks & (1u << i)) && e->decks[i].jump_pending)
                    pending = true;
            if (!pending) {
                c->pending = false;
                c->serial = tdj_stream_latest_request(c->asset);
            }
        }
        if (!c->pending && tdj_stream_acknowledged_request(c->asset) >= c->serial) {
            tdj_stream_release_claim(c->asset, c->ticket);
            memset(c, 0, sizeof(*c));
        }
    }
    if (recording && count)
        tdj_recording_push_decks(recording, count, left, right, recorded_generations, recorded_offsets, (unsigned)e->deck_count);
    publish(e);
    atomic_flag_clear_explicit(&e->render_busy, memory_order_release);
    return true;
}

static tdj_deck_snapshot read_deck(atomic_deck *p) {
    tdj_deck_snapshot result = {.recovery_armed = atomic_load(&p->recovery_armed),
                                .recovery_active = atomic_load(&p->recovery_active),
                                .recovery_mix = atomic_load(&p->recovery_mix),
                                .recovery_start = atomic_load(&p->recovery_start),
                                .recovery_end = atomic_load(&p->recovery_end),
                                .recovery_mix_start = atomic_load(&p->recovery_mix_start),
                                .loop_enabled = atomic_load(&p->loop_enabled),
                                .flux_enabled = atomic_load(&p->flux_enabled),
                                .loop_rolling = atomic_load(&p->loop_rolling),
                                .touch_active = atomic_load(&p->touch_active),
                                .jump_pending = atomic_load(&p->jump_pending),
                                .loop_start = atomic_load(&p->loop_start),
                                .loop_end = atomic_load(&p->loop_end),
                                .braking = atomic_load(&p->braking),
                                .brake_rate = atomic_load(&p->brake_rate),
                                .continuing_frame = atomic_load(&p->continuing),
                                .performance_rate = atomic_load(&p->performance_rate),
                                .free_rate = atomic_load(&p->free_rate),
                                .touch_start = atomic_load(&p->touch_start),
                                .touch_end = atomic_load(&p->touch_end),
                                .jump_frame = atomic_load(&p->jump_frame),
                                .jump_beat = atomic_load(&p->jump_beat),
                                .pending_touch_end = atomic_load(&p->pending_touch_end),
                                .pending_loop_end = atomic_load(&p->pending_loop_end),
                                .touch_was_playing = atomic_load(&p->touch_was_playing),
                                .jump_loop = atomic_load(&p->jump_loop),
                                .pending_touch_rate = atomic_load(&p->pending_touch_rate),
                                .pending_touch_rate_valid = atomic_load(&p->pending_touch_rate_valid),
                                .generation = atomic_load(&p->generation),
                                .last_start_frame = atomic_load(&p->last_start),
                                .state = atomic_load(&p->state),
                                .synced = atomic_load(&p->synced),
                                .keylock = atomic_load(&p->keylock),
                                .volume = atomic_load(&p->volume),
                                .gain = atomic_load(&p->gain),
                                .low = atomic_load(&p->low),
                                .mid = atomic_load(&p->mid),
                                .high = atomic_load(&p->high),
                                .cue = atomic_load(&p->cue),
                                .filter_x = atomic_load(&p->filter_x),
                                .filter_y = atomic_load(&p->filter_y),
                                .filter_enabled = atomic_load(&p->filter_enabled),
                                .crossfader_assignment = atomic_load(&p->crossfader_assignment),
                                .peak = atomic_load(&p->peak),
                                .source_frame = atomic_load(&p->position),
                                .source_bpm = atomic_load(&p->bpm),
                                .local_bpm = atomic_load(&p->local_bpm),
                                .source_sample_rate = atomic_load(&p->source_sample_rate),
                                .grid_anchor = atomic_load(&p->grid_anchor),
                                .grid_downbeat = atomic_load(&p->grid_downbeat),
                                .target_beat = atomic_load(&p->target),
                                .source_rate = atomic_load(&p->rate),
                                .lead_in_source_frame = atomic_load(&p->lead)};
    result.beatgrid.count = atomic_load(&p->map_count);
    result.beatgrid.sample_rate = atomic_load(&p->map_rate);
    result.beatgrid.downbeat = atomic_load(&p->map_downbeat);
    for (unsigned k = 0; k < result.beatgrid.count && k < TDJ_MAX_GRID_ANCHORS; k++) {
        result.beatgrid.beats[k] = atomic_load(&p->map_beats[k]);
        result.beatgrid.frames[k] = atomic_load(&p->map_frames[k]);
    }
    return result;
}
uint64_t tdj_rendered_output_frame(const tdj_engine *e) {
    return atomic_load_explicit(&e->published_frame, memory_order_relaxed);
}

bool tdj_read_snapshot(tdj_engine *e, tdj_snapshot *out) {
    for (int attempt = 0; attempt < 8; ++attempt) {
        uint64_t before = atomic_load(&e->snapshot_sequence);
        if (before & 1)
            continue;
        tdj_snapshot value = {.paired_frames = atomic_load(&e->published_paired_frames),
                              .sample_rate = e->rate,
                              .output_frame = atomic_load(&e->published_frame),
                              .crossfader = atomic_load(&e->published_crossfader),
                              .master_gain = atomic_load(&e->published_master),
                              .monitor_gain = atomic_load(&e->published_monitor),
                              .cue_blend = atomic_load(&e->published_cue_blend),
                              .master_bpm = atomic_load(&e->published_bpm),
                              .master_beat = atomic_load(&e->published_beat),
                              .clock_running = atomic_load(&e->published_running),
                              .a = read_deck(&e->published[0]),
                              .b = read_deck(&e->published[1])};
        value.extra_decks = atomic_load(&e->published_extra);
        if (value.extra_decks) {
            value.c = read_deck(&e->published[2]);
            value.d = read_deck(&e->published[3]);
        }
        if (before == atomic_load(&e->snapshot_sequence)) {
            *out = value;
            return true;
        }
    }
    return false;
}
