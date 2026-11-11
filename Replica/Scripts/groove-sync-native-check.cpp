extern "C" {
#include "TDJTransport.h"
#include "TDJStreaming.h"
}
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

static unsigned serial = 1;
static tdj_snapshot snapshot(tdj_engine *e) {
    tdj_snapshot value{};
    assert(tdj_read_snapshot(e, &value));
    return value;
}
static void command(tdj_engine *e, int kind, int deck = 0, double value = 0, int flag = 0, tdj_asset *asset = nullptr,
                    tdj_beatgrid_map map = {}, uint64_t ticket = 0) {
    tdj_command c{};
    c.kind = kind;
    c.deck = deck;
    c.id = serial++;
    c.generation = deck + 1;
    c.value = value;
    c.flag = flag;
    c.asset = asset;
    c.beatgrid = map;
    c.preparation_ticket = ticket;
    if (kind == TDJ_LOAD)
        c.value2 = 120;
    assert(tdj_submit(e, c));
    assert(tdj_render(e, 0, nullptr, nullptr));
    tdj_message m{};
    bool found = false;
    while (tdj_read_message(e, &m))
        if (m.command_id == c.id) {
            assert(m.status == TDJ_OK);
            found = true;
        }
    assert(found);
}
static void render(tdj_engine *e, int frames, int block = 127) {
    std::vector<float> left(block), right(block);
    for (int at = 0; at < frames; at += block) {
        const int n = std::min(block, frames - at);
        assert(tdj_render(e, n, left.data(), right.data()));
        for (int i = 0; i < n; ++i)
            assert(std::isfinite(left[i]) && std::isfinite(right[i]) && std::fabs(left[i]) <= .401);
    }
}
static tdj_beatgrid_map human_map(double drift = 1) {
    tdj_beatgrid_map map{};
    map.count = 65;
    map.sample_rate = 48000;
    const double within[] = {0, .28, .5, .78};
    for (unsigned i = 0; i < map.count; ++i) {
        map.beats[i] = i;
        map.frames[i] = ((i / 4) + within[i % 4]) * 96000 * drift;
    }
    return map;
}
static tdj_engine *rig(tdj_asset *asset, tdj_beatgrid_map map, int adaptive = 0, bool partner_sync = true) {
    auto e = tdj_engine_create(48000, 1);
    assert(e);
    command(e, TDJ_TEMPO, 0, 120);
    command(e, TDJ_LOAD, 0, 0, 1, asset, adaptive == 0 ? map : tdj_beatgrid_map{});
    command(e, TDJ_LOAD, 1, 0, partner_sync ? 1 : 0, asset, adaptive == 1 ? map : tdj_beatgrid_map{});
    return e;
}
static tdj_deck_snapshot lane(tdj_snapshot s, int index) {
    return index ? s.b : s.a;
}
static void solo_groove(tdj_asset *asset) {
    for (int deck : {0, 1}) {
        auto e = rig(asset, human_map(1.02), deck);
        command(e, TDJ_PLAY, deck);
        render(e, 192000);
        auto s = snapshot(e);
        assert(lane(s, deck).synced);
        assert(std::fabs(lane(s, deck).source_frame - 192000) < 1e-7);
        assert(std::fabs(lane(s, deck).source_rate - 1) < 1e-12);
        tdj_engine_destroy(e);
    }
    std::puts("Solo playback retains its source timing with another deck loaded and paused.");
}
static void natural_start(tdj_asset *asset) {
    auto e = tdj_engine_create(48000, 1);
    assert(e);
    command(e, TDJ_LOAD, 0, 0, 1, asset, human_map(1.02));
    command(e, TDJ_PLAY);
    render(e, 96000);
    const auto s = snapshot(e);
    assert(s.master_bpm == 120 && s.a.source_rate == 1);
    assert(std::fabs(s.a.source_frame - 96000) < 1e-7);
    tdj_engine_destroy(e);
    std::puts("The first solo track starts at its natural rate without selecting an internal beat's local tempo.");
}
static void bar_lock(tdj_asset *asset) {
    for (int deck : {0, 1})
        for (int block : {1, 127, 512}) {
            auto map = human_map(1.02);
            auto e = rig(asset, map, deck);
            command(e, TDJ_PLAY, deck);
            render(e, 192000, block);
            const auto before = snapshot(e);
            command(e, TDJ_PLAY, deck ^ 1, 0, TDJ_PLAY_ALIGN_ENTRY);
            auto s = snapshot(e);
            assert(s.master_bpm == before.master_bpm);
            assert(lane(s, deck).source_frame == lane(before, deck).source_frame);
            assert(lane(s, deck ^ 1).state == TDJ_QUEUED);
            const double first = lane(s, deck ^ 1).target_beat;
            render(e, (int)std::ceil((first - s.master_beat) * 24000 - 1e-7), block);
            s = snapshot(e);
            assert(std::fabs(lane(s, deck).source_frame - map.frames[8]) < 245);
            render(e, 1, block);
            assert(lane(snapshot(e), deck ^ 1).state == TDJ_PLAYING);
            for (int bar = 0; bar < 3; ++bar) {
                render(e, 23999, block);
                s = snapshot(e);
                const double source_beat = tdj_beatgrid_beat(map, lane(s, deck).source_frame);
                assert(std::fabs(source_beat - std::round(source_beat)) > .05);
                render(e, 72000, block);
                s = snapshot(e);
                assert(std::fabs(lane(s, deck).source_frame - map.frames[12 + bar * 4]) < 245);
                assert(std::fabs(lane(s, deck).source_rate - 1) <= .060001);
                render(e, 1, block);
            }
            const auto mixed = snapshot(e);
            command(e, TDJ_PLAY, deck ^ 1);
            const auto solo = snapshot(e);
            assert(lane(solo, deck).source_frame == lane(mixed, deck).source_frame);
            assert(std::fabs(lane(solo, deck).source_rate - lane(mixed, deck).source_rate) < 1e-12);
            render(e, 1000, block);
            assert(std::fabs(lane(snapshot(e), deck).source_frame - lane(solo, deck).source_frame -
                             1000 * lane(solo, deck).source_rate) < 1e-5);
            tdj_engine_destroy(e);
        }
    std::puts("Both start orders align bars, retain internal timing and release without a position or rate step.");
}
static void explicit_sync_off(tdj_asset *asset) {
    auto e = rig(asset, human_map(1.02), 0, false);
    command(e, TDJ_PLAY);
    render(e, 192000);
    command(e, TDJ_PLAY, 1);
    render(e, 96000);
    auto s = snapshot(e);
    assert(s.a.synced && !s.b.synced);
    assert(std::fabs(s.a.source_frame - 288000) < 1e-6);
    command(e, TDJ_SYNC, 0, 0, 0);
    assert(!snapshot(e).a.synced);
    tdj_engine_destroy(e);
    std::puts("An explicit Sync-off deck does not engage the bar lock or change saved Sync intent.");
}
static void correction_limits(tdj_asset *asset) {
    auto map = human_map(1.02);
    for (unsigned i = 8; i < map.count; ++i)
        map.frames[i] = map.frames[8] + (human_map(1.2).frames[i] - human_map(1.2).frames[8]);
    auto e = rig(asset, map);
    command(e, TDJ_PLAY);
    render(e, 48000);
    command(e, TDJ_PLAY, 1, 0, TDJ_PLAY_ALIGN_ENTRY);
    auto previous = snapshot(e);
    bool limited = false;
    for (int i = 0; i < 1600; ++i) {
        render(e, 127);
        auto s = snapshot(e);
        limited |= s.a.groove_sync == TDJ_GROOVE_LIMITED;
        assert(s.a.source_rate >= .939999 && s.a.source_rate <= 1.060001);
        assert(std::fabs(s.a.source_rate - previous.a.source_rate) <= .06 * 127 / 48000 + 1e-9);
        assert(s.a.source_frame > previous.a.source_frame);
        assert(s.a.source_frame - previous.a.source_frame <= 127 * 1.060001);
        previous = s;
    }
    assert(limited);
    tdj_engine_destroy(e);
    std::puts("An unsuitable later bar reports limited alignment and obeys speed and slew bounds without seeking.");
}
static void auxiliary_clock(tdj_asset *asset) {
    auto map = human_map(1.02);
    auto e = rig(asset, map);
    command(e, TDJ_PLAY);
    render(e, 192000);
    const auto before = snapshot(e);
    tdj_pattern_set(e, 0, UINT64_C(0x110000));
    command(e, TDJ_PLAY, 1, 0, TDJ_PLAY_ALIGN_ENTRY);
    const auto joining = snapshot(e);
    assert(joining.master_beat == before.master_beat);
    assert(joining.a.source_frame == before.a.source_frame);
    tdj_pattern_set(e, 0, 0);
    render(e, 192001);
    const auto aligned = snapshot(e);
    assert(aligned.a.groove_sync == TDJ_GROOVE_ALIGNED);
    assert(std::fabs(aligned.a.source_frame - map.frames[16]) < 245);
    tdj_engine_destroy(e);
    std::puts("An active Pattern Player keeps its clock phase; the deck acquires the correct later source bar.");
}
static int32_t read_source(void *context, uint64_t first, uint32_t count, float *stereo) {
    const auto &source = *static_cast<const std::vector<float> *>(context);
    assert((first + count) * 2 <= source.size());
    std::memcpy(stereo, source.data() + first * 2, count * 2 * sizeof(float));
    return TDJ_STREAM_READY;
}
static void release_source(void *) {}
static uint64_t prepare(tdj_asset *asset, double position, uint64_t generation, tdj_engine *engine) {
    tdj_stream_target target{};
    target.position = position;
    target.source_speed = 1.3;
    target.performance_rate = 1;
    target.keylock = true;
    tdj_stream_request request{};
    assert(tdj_asset_plan_target(asset, &target, serial++, generation, &request) == TDJ_STREAM_READY);
    uint64_t ticket = tdj_asset_request_prepare(asset, &request);
    assert(ticket);
    for (int n = 0; n < 1000 && tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_PENDING; ++n) {
        assert(tdj_asset_service(asset, 4) >= 0);
        assert(tdj_render(engine, 0, nullptr, nullptr));
    }
    if (tdj_asset_prepare_status(asset, ticket) != TDJ_STREAM_READY)
        std::fprintf(stderr, "prepare status %d at %.3f for generation %llu\n", tdj_asset_prepare_status(asset, ticket),
                     position, (unsigned long long)generation);
    assert(tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_READY);
    return ticket;
}
static void streamed_match(std::vector<float> &source, tdj_asset *memory) {
    tdj_stream_config config{48000, .5, .25, 512, TDJ_STREAM_COMPACT_POOL};
    int32_t error = 0;
    auto stream =
        tdj_asset_open_decoder(source.size() / 2, 48000, &config, read_source, release_source, &source, &error);
    assert(stream && error == TDJ_STREAM_READY);
    auto e = tdj_engine_create(48000, 1), reference = tdj_engine_create(48000, 1);
    assert(e && reference);
    for (auto engine : {e, reference})
        command(engine, TDJ_TEMPO, 0, 120);
    for (int deck : {0, 1}) {
        const auto map = deck ? tdj_beatgrid_map{} : human_map(1.02);
        uint64_t ticket = prepare(stream, 0, deck + 1, e);
        command(e, TDJ_LOAD, deck, 0, 9, stream, map, ticket);
        tdj_asset_release_preparation(stream, ticket);
        command(reference, TDJ_LOAD, deck, 0, 9, memory, map);
    }
    auto play = [&](int deck) {
        uint64_t ticket = prepare(stream, lane(snapshot(e), deck).source_frame, deck + 1, e);
        command(e, TDJ_PLAY, deck, 0, TDJ_PLAY_ALIGN_ENTRY, nullptr, {}, ticket);
        tdj_asset_release_preparation(stream, ticket);
        command(reference, TDJ_PLAY, deck, 0, TDJ_PLAY_ALIGN_ENTRY);
    };
    auto compare = [&](int blocks) {
        float l[512], r[512], rl[512], rr[512];
        bool had_signal = false;
        for (int b = 0; b < blocks; ++b) {
            assert(tdj_render(e, 512, l, r));
            assert(tdj_render(reference, 512, rl, rr));
            for (int i = 0; i < 512; ++i) {
                assert(l[i] == rl[i] && r[i] == rr[i]);
                had_signal |= std::fabs(l[i]) > .001;
            }
            assert(tdj_asset_service(stream, 4) >= 0);
        }
        assert(had_signal);
    };
    play(0);
    compare(100);
    play(1);
    compare(600);
    assert(snapshot(e).a.groove_sync == TDJ_GROOVE_ALIGNED);
    assert(snapshot(e).a.source_frame == snapshot(reference).a.source_frame);
    tdj_stream_telemetry telemetry{};
    tdj_asset_stream_telemetry(stream, &telemetry);
    assert(telemetry.source_read_misses == 0 && telemetry.missing_output_frames == 0);
    tdj_engine_destroy(e);
    tdj_engine_destroy(reference);
    tdj_asset_destroy(stream);
    std::puts("Streamed and resident bar-sync output matches exactly with zero source-read misses or missing frames.");
}
int main() {
    std::vector<float> source(48000 * 40 * 2, .2f);
    for (unsigned i = 0; i < source.size() / 2; ++i)
        source[i * 2] = source[i * 2 + 1] = .17f * std::sin(i * .011) + .025f * std::sin(i * .051);
    auto asset = tdj_asset_create(source.data(), source.size() / 2, 48000);
    assert(asset);
    solo_groove(asset);
    natural_start(asset);
    bar_lock(asset);
    explicit_sync_off(asset);
    correction_limits(asset);
    auxiliary_clock(asset);
    streamed_match(source, asset);
    tdj_asset_destroy(asset);
}
