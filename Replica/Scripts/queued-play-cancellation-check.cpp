#include "TDJTransport.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <vector>

static void send(tdj_engine *e, int kind, int deck, uint64_t generation, tdj_asset *asset = nullptr) {
    tdj_command c{};
    c.kind = kind;
    c.deck = deck;
    c.generation = generation;
    c.id = 1;
    if (asset) {
        c.asset = asset;
        c.value2 = 120;
        c.flag = 1;
    }
    assert(tdj_submit(e, c));
    assert(tdj_render(e, 0, nullptr, nullptr));
    tdj_message m{};
    bool accepted = false;
    while (tdj_read_message(e, &m))
        if (m.command_id) {
            assert(m.status == TDJ_OK);
            accepted = true;
        }
    assert(accepted);
}
int main() {
    constexpr int frames = 48000 * 8;
    std::vector<float> source(frames * 2);
    for (int f = 0; f < frames; f++)
        source[2 * f] = source[2 * f + 1] = 0.1f * std::sin(f * 0.03);
    auto *asset = tdj_asset_create(source.data(), frames, 48000);
    assert(asset);
    auto *tested = tdj_engine_create(48000, 1), *reference = tdj_engine_create(48000, 1);
    assert(tested && reference);
    for (auto *e : {tested, reference}) {
        send(e, TDJ_LOAD, 0, 1, asset);
        send(e, TDJ_LOAD, 1, 2, asset);
        send(e, TDJ_PLAY, 0, 1);
    }
    float l[512], r[512], rl[512], rr[512];
    for (auto *e : {tested, reference})
        assert(tdj_render(e, 512, l, r));
    send(tested, TDJ_PLAY, 1, 2);
    tdj_snapshot before{}, after{};
    assert(tdj_read_snapshot(tested, &before));
    assert(before.b.state == TDJ_QUEUED);
    send(tested, TDJ_PLAY, 1, 2);
    assert(tdj_read_snapshot(tested, &after));
    assert(after.b.state == TDJ_PAUSED && after.b.source_frame == before.b.source_frame);
    assert(after.b.last_start_frame == before.b.last_start_frame);
    assert(after.a.state == TDJ_PLAYING && after.a.source_frame == before.a.source_frame);
    assert(after.master_beat == before.master_beat && after.clock_running);
    for (int block = 0; block < 300; block++) {
        assert(tdj_render(tested, 512, l, r));
        assert(tdj_render(reference, 512, rl, rr));
        for (int f = 0; f < 512; f++)
            assert(l[f] == rl[f] && r[f] == rr[f]);
    }
    assert(tdj_read_snapshot(tested, &after));
    assert(after.b.state == TDJ_PAUSED);
    send(tested, TDJ_PLAY, 1, 2);
    assert(tdj_read_snapshot(tested, &after));
    assert(after.b.state == TDJ_QUEUED);
    tdj_engine_destroy(tested);
    tdj_engine_destroy(reference);
    tdj_asset_destroy(asset);
    puts("Queued second Play cancels; playing deck audio/clock unchanged; recontact queues anew.");
}
