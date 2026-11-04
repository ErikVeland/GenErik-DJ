extern "C" {
#include "TDJTransport.h"
}
#include <cassert>
#include <cmath>
#include <cstdio>
#include <thread>
#include <atomic>
#include <vector>

static void consume(tdj_engine *e) {
    assert(tdj_render(e, 0, nullptr, nullptr));
}
static tdj_snapshot snapshot(tdj_engine *e) {
    tdj_snapshot s{};
    assert(tdj_read_snapshot(e, &s));
    return s;
}
static void accepted(tdj_engine *e, tdj_command c) {
    assert(tdj_submit(e, c));
    consume(e);
    tdj_message m{};
    bool found = false;
    while (tdj_read_message(e, &m))
        if (m.command_id == c.id) {
            assert(m.status == TDJ_OK);
            found = true;
        }
    assert(found);
}
int main() {
    constexpr unsigned frames = 1600000;
    std::vector<float> source(frames * 2, 0.1f);
    auto asset = tdj_asset_create(source.data(), frames, 48000);
    assert(asset);
    auto e = tdj_engine_create(48000, 1);
    assert(e);
    tdj_beatgrid_map map{};
    map.count = 256;
    map.sample_rate = 48000;
    for (unsigned k = 0; k < 256; k++) {
        map.beats[k] = k * 0.25;
        map.frames[k] = k * 6000;
    }
    assert(tdj_beatgrid_validate(map, frames));
    for (double beat = -2; beat <= 66; beat += 0.125)
        assert(std::fabs(tdj_beatgrid_beat(map, tdj_beatgrid_frame(map, beat)) - beat) < 1e-10);
    tdj_command load{};
    load.kind = TDJ_LOAD;
    load.asset = asset;
    load.value2 = 120;
    load.generation = 1;
    load.id = 1;
    load.beatgrid = map;
    accepted(e, load);
    load.deck = 1;
    load.generation = 2;
    load.id = 2;
    load.beatgrid.count = 0;
    accepted(e, load);
    assert(snapshot(e).a.beatgrid.count == 256 && snapshot(e).b.beatgrid.count == 0);
    tdj_command edit{};
    edit.kind = TDJ_ADAPTIVE_GRID;
    edit.generation = 1;
    edit.id = 3;
    edit.beatgrid = map;
    edit.beatgrid.count = 257;
    assert(!tdj_submit(e, edit));
    edit.beatgrid = map;
    edit.beatgrid.frames[1] = 0;
    assert(!tdj_submit(e, edit));
    edit.beatgrid = map;
    edit.beatgrid.beats[1] = NAN;
    assert(!tdj_submit(e, edit));
    edit.beatgrid = map;
    // Snapshot readers and the render consumer run independently of the sole producer.
    std::atomic<bool> done{false};
    std::thread renderer([&] {
        while (!done.load()) {
            consume(e);
            tdj_message m;
            while (tdj_read_message(e, &m))
                assert(m.status == TDJ_OK);
        }
    });
    for (unsigned k = 0; k < 1000; k++) {
        edit.id = 10 + k;
        edit.beatgrid.count = (k % 2) ? 0 : 256;
        while (!tdj_submit(e, edit))
            std::this_thread::yield();
        tdj_snapshot s{};
        if (tdj_read_snapshot(e, &s)) {
            assert(s.a.beatgrid.count == 0 || s.a.beatgrid.count == 256);
            assert(s.b.beatgrid.count == 0);
            if (s.a.beatgrid.count)
                assert(tdj_beatgrid_validate(s.a.beatgrid, frames));
        }
    }
    done.store(true);
    renderer.join();
    consume(e);
    tdj_engine_destroy(e);
    tdj_asset_destroy(asset);
    std::puts("Adaptive map bounds, interpolation, deck isolation and concurrent publication/snapshots pass.");
}
