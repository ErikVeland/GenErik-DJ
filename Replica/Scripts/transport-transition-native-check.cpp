extern "C" {
#include "TDJTransport.h"
#include "TDJKeylock.h"
}
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>
#include <atomic>
#include <thread>
#include <chrono>

static unsigned serial = 1;
static void command(tdj_engine *e, int kind, int deck = 0, double value = 0, double value2 = 0, double value3 = 0,
                    int flag = 0, tdj_asset *asset = nullptr, double touchRate = 0, int expected = TDJ_OK) {
    tdj_command c{};
    c.kind = kind;
    c.deck = deck;
    c.generation = deck + 1;
    c.id = serial++;
    c.value = value;
    c.value2 = value2;
    c.value3 = value3;
    c.flag = flag;
    c.asset = asset;
    c.touch_rate = touchRate;
    assert(tdj_submit(e, c));
    assert(tdj_render(e, 0, nullptr, nullptr));
    tdj_message m{};
    bool found = false;
    while (tdj_read_message(e, &m))
        if (m.command_id == c.id) {
            if (m.status != expected)
                std::fprintf(stderr, "command %d status %d expected %d\n", kind, m.status, expected);
            assert(m.status == expected);
            found = true;
        }
    assert(found);
}
static tdj_snapshot snapshot(tdj_engine *e) {
    tdj_snapshot s{};
    assert(tdj_read_snapshot(e, &s));
    return s;
}
struct Audio {
    std::vector<float> l, r, cl, cr;
};
static Audio render(tdj_engine *e, int frames, int block = 128, tdj_recording *recording = nullptr) {
    Audio out;
    out.l.resize(frames);
    out.r.resize(frames);
    out.cl.resize(frames);
    out.cr.resize(frames);
    for (int at = 0; at < frames; at += block) {
        int n = std::min(block, frames - at);
        assert(tdj_render_recorded_buses(e, recording, n, out.l.data() + at, out.r.data() + at, out.cl.data() + at,
                                         out.cr.data() + at));
    }
    return out;
}
static void bounded(const Audio &a, double bound) {
    for (float x : a.l)
        assert(std::isfinite(x) && fabs(x) <= bound);
    for (float x : a.r)
        assert(std::isfinite(x) && fabs(x) <= bound);
}
static tdj_engine *engine(double rate, tdj_asset *asset, bool sync = false, double start = 100) {
    auto e = tdj_engine_create(rate, 1);
    assert(e);
    command(e, TDJ_LOAD, 0, start, 120, 0, sync ? 1 : 0, asset);
    return e;
}
static void mixer(tdj_engine *e, int kind, double value, int deck = 0) {
    command(e, TDJ_MIXER, deck, value, 0, 0, kind);
}
static void exact_source(const Audio &a, const std::vector<float> &source, int first, int skip = 0) {
    for (int n = skip; n < (int)a.l.size(); ++n) {
        assert(a.l[n] == source[2 * (first + n)]);
        assert(a.r[n] == source[2 * (first + n) + 1]);
    }
}
static void keylock_reset_quality() {
    constexpr double rate = 48000, pi = 3.141592653589793;
    for (double hz : {55., 137., 440., 1000., 10000.})
        for (double speed : {.75, 1.25, 1.5, 2.}) {
            std::vector<float> source(48000 * 8 * 2);
            for (int i = 0; i < 48000 * 8; i++)
                source[2 * i] = source[2 * i + 1] = .7f * sin(2 * pi * hz * i / rate + .73);
            auto p = tdj_keylock_create(rate);
            assert(p);
            float l, r;
            for (int i = 0; i < 12000; i++)
                tdj_keylock_sample(p, source.data(), source.size() / 2, rate, 20000 + i * speed, speed, true, &l, &r);
            tdj_keylock_reset(p);
            double peak = 0;
            for (int i = 12000; i < 14400; i++) {
                tdj_keylock_sample(p, source.data(), source.size() / 2, rate, 20000 + i * speed, speed, true, &l, &r);
                peak = std::max(peak, (double)fabs(l));
                assert(std::isfinite(l) && std::isfinite(r));
            }
            // A 0.7 steady tone must not acquire the former reset spike (up to 1.95).
            assert(peak < .75);
            tdj_keylock_destroy(p);
        }
    for (double speed : {.5, 1.25, 2.})
        for (int offset : {0, 100, 1000}) {
            std::vector<float> source(48000 * 4 * 2);
            source[2 * (50000 + offset)] = source[2 * (50000 + offset) + 1] = .7f;
            auto p = tdj_keylock_create(rate);
            assert(p);
            float l, r;
            double peak = 0;
            int at = 0;
            for (int i = 0; i < 6000; i++) {
                tdj_keylock_sample(p, source.data(), source.size() / 2, rate, 50000 + i * speed, speed, true, &l, &r);
                if (fabs(l) > peak) {
                    peak = fabs(l);
                    at = i;
                }
            }
            assert(peak > .1 && fabs(at - offset / speed) <= 1);
            tdj_keylock_destroy(p);
        }
    puts("Keylock: 20 tone/reset cases have no gain spike; nine impulse onsets remain within one output sample.");
}
static void batched_transition_checks() {
    std::vector<float> source(48000 * 2);
    for (int i = 0; i < 48000; i++)
        source[2 * i] = source[2 * i + 1] = .7f * sin(i * .017 + .7);
    auto asset = tdj_asset_create(source.data(), 48000, 48000);
    assert(asset);
    for (int test = 0; test < 5; test++) {
        auto e = engine(48000, asset, false, 0);
        command(e, TDJ_PLAY);
        auto before = render(e, test == 1 ? 48000 : 10000);
        if (test != 1)
            command(e, TDJ_PLAY);
        if (test < 2)
            command(e, TDJ_CUE_RECALL, 0, 20000);
        else {
            if (test == 2)
                command(e, TDJ_JUMP, 0, 20000);
            if (test == 3)
                command(e, TDJ_SEEK, 0, 20000);
            if (test == 4)
                command(e, TDJ_LOOP, 0, 20000, 22000, 0, 1);
            command(e, TDJ_PLAY);
        }
        auto after = render(e, 128, 1);
        assert(after.l[0] == before.l.back() && after.r[0] == before.r.back());
        assert(snapshot(e).a.source_frame == 20128);
        bounded(after, .701);
        tdj_engine_destroy(e);
    }
    tdj_asset_destroy(asset);
    puts("Five same-batch pause/source/restart and immediate-EOF cue boundaries are exactly continuous.");
}
static void ended_loop_recall_checks() {
    std::vector<float> source(48000 * 8 * 2);
    for (int i = 0; i < 48000 * 8; i++) {
        source[2 * i] = .3f * sin(i * .023);
        source[2 * i + 1] = .2f * cos(i * .031);
    }
    auto shortAsset = tdj_asset_create(source.data(), 48000, 48000);
    auto longAsset = tdj_asset_create(source.data(), 48000 * 8, 48000);
    assert(shortAsset && longAsset);
    for (bool flux : {false, true})
        for (int other = 0; other < 4; other++) {
            auto e = engine(48000, shortAsset, true, 0), reference = engine(48000, shortAsset, true, 0);
            for (auto x : {e, reference}) {
                command(x, TDJ_FLUX, 0, 0, 0, 0, flux ? 1 : 0);
                if (other)
                    command(x, TDJ_LOAD, 1, 0, 120, 0, other == 2 ? 0 : 1, longAsset);
                command(x, TDJ_PLAY);
                render(x, 1000);
                if (other == 3) {
                    command(x, TDJ_LOOP, 0, 0, 40000, 0, 1);
                    command(x, TDJ_PLAY, 1);
                    command(x, TDJ_LOOP);
                    command(x, TDJ_JUMP, 0, 47999);
                    render(x, 1);
                } else {
                    if (other)
                        command(x, TDJ_PLAY, 1);
                    render(x, 47000);
                }
                assert(snapshot(x).a.state == TDJ_ENDED);
            }
            auto before = snapshot(e);
            if (other == 1)
                assert(before.b.state == TDJ_PLAYING && before.b.synced);
            // An unsynced reference does not queue this recall. The common checks
            // below verify immediate playback and preserve the other deck.
            if (other == 2)
                assert(before.b.state == TDJ_PLAYING && !before.b.synced);
            if (other == 3)
                assert(before.b.state == TDJ_QUEUED);
            before = snapshot(e);
            // Invalid loop bounds leave the ended deck, clock and other deck intact.
            command(e, TDJ_CUE_RECALL, 0, 20000, 48001, .5, 0, nullptr, 0, TDJ_INVALID);
            auto invalid = snapshot(e);
            assert(invalid.a.source_frame == before.a.source_frame && invalid.a.state == TDJ_ENDED &&
                   invalid.master_beat == before.master_beat);
            command(e, TDJ_CUE_RECALL, 0, 20000, 22000, .5);
            // Existing explicit seek/Flux capture/loop/Play is the fresh-start reference.
            command(reference, TDJ_SEEK, 0, 20000);
            command(reference, TDJ_FLUX, 0, 0, 0, 0, flux ? 1 : 0);
            command(reference, TDJ_LOOP, 0, 20000, 22000, .5, 1);
            command(reference, TDJ_PLAY);
            auto actual = snapshot(e), expected = snapshot(reference);
            assert(actual.a.source_frame == 20000 && actual.a.continuing_frame == 20000 && actual.a.loop_enabled);
            assert(actual.a.state == (other == 1 ? TDJ_QUEUED : TDJ_PLAYING));
            assert(actual.a.state == expected.a.state && actual.a.target_beat == expected.a.target_beat &&
                   actual.master_beat == expected.master_beat);
            assert(actual.b.source_frame == before.b.source_frame && actual.b.state == before.b.state &&
                   actual.b.target_beat == before.b.target_beat);
            if (other == 1) {
                int waiting = (int)ceil((actual.a.target_beat - actual.master_beat) * 24000 - 1e-7);
                auto a = render(e, waiting), b = render(reference, waiting);
                assert(a.l == b.l && a.r == b.r);
                assert(snapshot(e).a.source_frame == 20000);
            }
            auto audio = render(e, 4096), baseline = render(reference, 4096);
            assert(audio.l == baseline.l && audio.r == baseline.r);
            actual = snapshot(e);
            double returned = flux ? actual.a.continuing_frame : actual.a.source_frame;
            assert(actual.a.continuing_frame == 24096);
            command(e, TDJ_LOOP);
            command(reference, TDJ_LOOP);
            assert(snapshot(e).a.source_frame == returned);
            audio = render(e, 1024);
            baseline = render(reference, 1024);
            assert(audio.l == baseline.l && audio.r == baseline.r);
            assert(snapshot(e).a.state == TDJ_PLAYING); // Flux resumes the song, not old EOF.
            tdj_engine_destroy(e);
            tdj_engine_destroy(reference);
        }
    tdj_asset_destroy(shortAsset);
    tdj_asset_destroy(longAsset);
    puts("Eight ended-loop recalls preserve fresh Flux time, atomic rejection, reference policies and exact "
         "manual-start audio.");
}
static void performance_rate_return_checks() {
    constexpr double pi = 3.141592653589793;
    std::vector<float> source(48000 * 8 * 2);
    for (int i = 0; i < 48000 * 8; i++)
        source[2 * i] = source[2 * i + 1] = .2f * sin(i * 2 * pi * (i < 96000 ? 440 : 880) / 48000);
    auto asset = tdj_asset_create(source.data(), source.size() / 2, 48000);
    assert(asset);
    for (bool compound : {false, true})
        for (bool reverse : {false, true}) {
            double start = reverse ? 160000 : 10000;
            auto e = engine(48000, asset, true, start);
            command(e, TDJ_KEYLOCK, 0, 0, 0, 0, 1);
            command(e, TDJ_TEMPO, 0, 150);
            if (compound) {
                command(e, TDJ_TOUCH, 0, 10000, 350000, 0, TDJ_TOUCH_WITH_RATE, nullptr, 1);
                if (reverse)
                    command(e, TDJ_JUMP, 0, start);
            } else
                command(e, TDJ_PLAY);
            render(e, 4096);
            double rawRate = reverse ? -1 : 4;
            if (compound)
                command(e, TDJ_TOUCH, 0, 10000, 350000, 0, TDJ_TOUCH_WITH_RATE, nullptr, rawRate);
            else
                command(e, TDJ_RATE, 0, rawRate);
            auto raw = render(e, reverse ? 80000 : 20000);
            auto before = snapshot(e);
            if (compound)
                command(e, TDJ_TOUCH, 0, 10000, 350000, 0, TDJ_TOUCH_WITH_RATE, nullptr, 1);
            else
                command(e, TDJ_RATE, 0, 1);
            auto accepted = snapshot(e);
            assert(accepted.a.source_frame == before.a.source_frame && accepted.master_beat == before.master_beat);
            assert(accepted.a.touch_start == before.a.touch_start && accepted.a.touch_end == before.a.touch_end &&
                   accepted.a.touch_active == before.a.touch_active);
            assert(accepted.a.performance_rate == 1 && !accepted.a.jump_pending);
            // Stop before the reversed source reaches the genuine tone-change boundary.
            auto normal = render(e, 24000);
            assert(normal.l[0] == raw.l.back() && normal.r[0] == raw.r.back());
            std::vector<double> crossings;
            for (int i = 4801; i < 24000; i++)
                if (normal.l[i - 1] <= 0 && normal.l[i] > 0)
                    crossings.push_back(i - 1 - normal.l[i - 1] / (normal.l[i] - normal.l[i - 1]));
            assert(crossings.size() > 2);
            double hz = (crossings.size() - 1) * 48000 / (crossings.back() - crossings.front());
            assert(fabs(hz - (reverse ? 440 : 880)) < 1);
            double peak = 0;
            int peakAt = 0;
            for (int i = 0; i < 24000; i++)
                if (fabs(normal.l[i]) > peak) {
                    peak = fabs(normal.l[i]);
                    peakAt = i;
                }
            std::fprintf(stderr, "rate return compound=%d reverse=%d hz=%.3f peak=%.6f at=%d\n", compound, reverse, hz,
                         peak, peakAt);
            bounded(normal, .3);
            assert(snapshot(e).a.source_frame == before.a.source_frame + 30000);
            tdj_engine_destroy(e);
        }
    tdj_asset_destroy(asset);
    puts("Four direct/compound forward/reverse returns emit the current source tone, not stale pre-bypass Keylock "
         "audio.");
}
static void busy_configuration_check() {
    std::vector<float> source(200000 * 2);
    for (int i = 0; i < 200000; i++)
        source[2 * i] = source[2 * i + 1] = .1f * sin(i * .03);
    auto asset = tdj_asset_create(source.data(), 200000, 48000);
    assert(asset);
    bool protected_once = false;
    for (int attempt = 0; attempt < 3 && !protected_once; attempt++) {
        auto e = engine(48000, asset, true, 0);
        command(e, TDJ_KEYLOCK, 0, 0, 0, 0, 1);
        command(e, TDJ_TEMPO, 0, 150);
        command(e, TDJ_PLAY);
        command(e, TDJ_LOOP, 0, 0, 100000, 0, 1);
        std::vector<float> l(262144), r(262144);
        std::atomic<bool> started{false};
        bool rendered = false;
        std::thread consumer([&] {
            started = true;
            rendered = tdj_render(e, (uint32_t)l.size(), l.data(), r.data());
        });
        while (!started.load())
            std::this_thread::yield();
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
        int readiness = tdj_engine_output_sources_ready(e);
        assert(readiness == TDJ_PROTECTED || readiness == TDJ_OK);
        int result = tdj_engine_configure_maximum_output_frames(e, 16384);
        assert(result == TDJ_PROTECTED || result == TDJ_OK);
        consumer.join();
        if (result == TDJ_PROTECTED && readiness == TDJ_PROTECTED) {
            assert(rendered);
            protected_once = true;
        }
        tdj_engine_destroy(e);
    }
    assert(protected_once);
    tdj_asset_destroy(asset);
    puts("Frame configuration and output readiness return PROTECTED while rendering, without waiting or changing "
         "state.");
}
static void waveform_direct_checks(double rate, tdj_asset *asset) {
    for (bool playing : {false, true})
        for (bool flux : {false, true}) {
            auto e = engine(rate, asset, false, rate);
            if (playing)
                command(e, TDJ_PLAY);
            command(e, TDJ_FLUX, 0, 0, 0, 0, flux);
            // Flag 4 requests direct position and rate in one audio command.
            command(e, TDJ_TOUCH, 0, rate, 0, 0, 4, nullptr, 0);
            assert(snapshot(e).a.source_frame == rate);
            command(e, TDJ_TOUCH, 0, rate * .8, 0, 0, 4, nullptr, -.5);
            assert(snapshot(e).a.source_frame == rate * .8);
            auto moving = render(e, 256, 17);
            bounded(moving, .75);
            assert(fabs(snapshot(e).a.source_frame - (rate * .8 - 128)) < .001);
            command(e, TDJ_TOUCH, 0, rate * .7, 0, 0, 4, nullptr, 0);
            auto held = render(e, 256, 17);
            bounded(held, .75);
            assert(held.l[0] == moving.l.back() && held.r[0] == moving.r.back());
            assert(snapshot(e).a.source_frame == rate * .7);
            command(e, TDJ_TOUCH, 0, rate * .9, 0, 0, 4, nullptr, .5);
            auto reversed = render(e, 256, 17);
            bounded(reversed, .75);
            assert(reversed.l[0] == held.l.back() && reversed.r[0] == held.r.back());
            assert(fabs(snapshot(e).a.source_frame - (rate * .9 + 128)) < .001);
            command(e, TDJ_TOUCH);
            assert(!snapshot(e).a.touch_active);
            assert(snapshot(e).a.state == (playing ? TDJ_PLAYING : TDJ_PAUSED));
            if (flux)
                assert(snapshot(e).a.source_frame == rate + (playing ? 768 : 0));
            tdj_engine_destroy(e);
        }
    auto e = engine(rate, asset, false, rate);
    command(e, TDJ_TOUCH, 0, rate * 4 - 2, 0, 0, 4, nullptr, 2);
    render(e, 256, 17);
    assert(snapshot(e).a.state == TDJ_ENDED);
    command(e, TDJ_TOUCH, 0, rate, 0, 0, 4, nullptr, -.5);
    assert(snapshot(e).a.state == TDJ_PLAYING);
    render(e, 256, 17);
    assert(fabs(snapshot(e).a.source_frame - (rate - 128)) < .001);
    assert(snapshot(e).clock_running);
    command(e, TDJ_TOUCH);
    assert(snapshot(e).a.state == TDJ_PAUSED);
    tdj_engine_destroy(e);
}

static void waveform_scratch_checks(double rate, tdj_asset *asset, const std::vector<float> &source) {
    const int N = (int)ceil(rate * .002);
    // Scratch entry, held stops, restarts and release must not cut the output.
    for (bool keylock : {false, true})
        for (bool wasPlaying : {false, true}) {
            auto e = engine(rate, asset, keylock);
            if (keylock) {
                command(e, TDJ_KEYLOCK, 0, 0, 0, 0, 1);
                command(e, TDJ_TEMPO, 0, 150);
            }
            const double step = snapshot(e).a.source_rate;
            float lastL = 0, lastR = 0;
            if (wasPlaying) {
                command(e, TDJ_PLAY);
                auto a = render(e, 512);
                lastL = a.l.back();
                lastR = a.r.back();
            }
            command(e, TDJ_TOUCH, 0, 20000, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, -1);
            auto scratch = render(e, N + 64, 17);
            assert(scratch.l[0] == lastL && scratch.r[0] == lastR);
            bounded(scratch, .75);
            for (int i = N; i < N + 64; i++) {
                double position = 20000 - i * step, fraction = position - floor(position);
                int at = (int)floor(position);
                assert(scratch.l[i] == (float)(source[2 * at] * (1 - fraction) + source[2 * (at + 1)] * fraction));
                assert(scratch.r[i] ==
                       (float)(source[2 * at + 1] * (1 - fraction) + source[2 * (at + 1) + 1] * fraction));
            }
            assert(snapshot(e).a.source_frame == 20000 - (N + 64) * step);
            // Repeated rate commands may arrive before the previous correction ends.
            for (double speed : {0., -1., 1., -1., 0., 1., 0., 2., 0., -2.}) {
                auto before = snapshot(e);
                lastL = scratch.l.back();
                lastR = scratch.r.back();
                command(e, TDJ_TOUCH, 0, 20000, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, speed);
                assert(snapshot(e).a.source_frame == before.a.source_frame);
                const int frames = speed == 0 ? N / 2 : N + 64;
                scratch = render(e, frames, 1);
                assert(scratch.l[0] == lastL && scratch.r[0] == lastR);
                bounded(scratch, .75);
                assert(snapshot(e).a.source_frame == before.a.source_frame + frames * speed * step);
            }
            command(e, TDJ_TOUCH, 0, 20000, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, 0);
            auto stopped = render(e, N + 32, 17);
            for (int i = N; i < N + 32; i++)
                assert(stopped.l[i] == 0 && stopped.r[i] == 0);
            auto held = snapshot(e);
            render(e, 256);
            assert(snapshot(e).a.source_frame == held.a.source_frame);
            command(e, TDJ_TOUCH, 0, 20000, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, -1);
            scratch = render(e, N + 37, 17);
            auto before = snapshot(e);
            command(e, TDJ_TOUCH, 0, 0, 0, 0, 0);
            assert(snapshot(e).a.source_frame == before.a.source_frame);
            auto released = render(e, N + 64, 17);
            assert(released.l[0] == scratch.l.back() && released.r[0] == scratch.r.back());
            bounded(released, .701);
            assert(snapshot(e).a.state == (wasPlaying ? TDJ_PLAYING : TDJ_PAUSED));
            if (wasPlaying)
                assert(snapshot(e).a.source_frame == before.a.source_frame + (N + 64) * step);
            if (!wasPlaying)
                for (int i = N; i < N + 64; i++)
                    assert(released.l[i] == 0 && released.r[i] == 0);
            tdj_engine_destroy(e);
        }
    // Timeline relocation and Flux return share the same output protection.
    for (bool flux : {false, true}) {
        auto e = engine(rate, asset);
        command(e, TDJ_PLAY);
        auto previous = render(e, 512);
        if (flux)
            command(e, TDJ_FLUX, 0, 0, 0, 0, 1);
        for (int target : {20000, 30000, 15000, 25000}) {
            command(e, TDJ_TOUCH, 0, target, 0, 0, 1);
            auto moved = render(e, N / 2, 1);
            assert(moved.l[0] == previous.l.back() && moved.r[0] == previous.r.back());
            bounded(moved, .701);
            assert(snapshot(e).a.source_frame == target + N / 2);
            previous = moved;
        }
        auto before = snapshot(e);
        command(e, TDJ_TOUCH, 0, 0, 0, 0, 0);
        assert(snapshot(e).a.source_frame == (flux ? before.a.continuing_frame : before.a.source_frame));
        auto released = render(e, N + 64, 17);
        assert(released.l[0] == previous.l.back() && released.r[0] == previous.r.back());
        bounded(released, .701);
        tdj_engine_destroy(e);
    }
}
static void continuous_manipulation_checks() {
    // Positive stereo witnesses expose inserted silence without confusing it
    // with a musical zero crossing or deliberate silence in the source.
    for (double rate : {44100., 48000., 96000.}) {
        std::vector<float> source((int)rate * 8 * 2);
        for (size_t f = 0; f < source.size() / 2; f++) {
            source[2 * f] = .25f;
            source[2 * f + 1] = .125f;
        }
        auto asset = tdj_asset_create(source.data(), source.size() / 2, rate);
        assert(asset);
        auto e = engine(rate, asset, true, rate * 2);
        mixer(e, TDJ_MIX_CUE, 1);
        mixer(e, TDJ_MIX_MONITOR, 1);
        command(e, TDJ_PLAY);
        render(e, 1024);
        auto recording = tdj_recording_create(32768);
        assert(recording);
        tdj_recording_start(recording);
        unsigned checked = 0;
        auto uninterrupted = [&](int frames = 512) {
            auto audio = render(e, frames, 128, recording);
            std::vector<float> capturedL(frames), capturedR(frames);
            assert(tdj_recording_read(recording, frames, capturedL.data(), capturedR.data()) == (unsigned)frames);
            assert(capturedL == audio.l && capturedR == audio.r);
            assert(tdj_recording_dropped(recording) == 0);
            for (int f = 0; f < frames; f++) {
                assert(std::isfinite(audio.l[f]) && std::isfinite(audio.r[f]));
                assert(audio.l[f] > .05f && audio.r[f] > .025f);
                assert(audio.l[f] == audio.cl[f] && audio.r[f] == audio.cr[f]);
            }
            checked += frames;
            assert(snapshot(e).a.state == TDJ_PLAYING);
        };
        for (int pass = 0; pass < 12; pass++) {
            command(e, TDJ_TEMPO, 0, pass % 2 ? 150 : 100);
            uninterrupted();
            command(e, TDJ_KEYLOCK, 0, 0, 0, 0, 1);
            uninterrupted();
            command(e, TDJ_KEYLOCK, 0, 0, 0, 0, 0);
            uninterrupted();
            command(e, TDJ_SYNC, 0, 0, 0, 0, 0);
            uninterrupted();
            command(e, TDJ_FREE_RATE, 0, pass % 2 ? .75 : 1.25);
            uninterrupted();
            command(e, TDJ_SEEK, 0, rate * 2, 0, 0, 0, nullptr, 0, TDJ_UNRESOLVED);
            uninterrupted();
            command(e, TDJ_JUMP, 0, rate * 3);
            uninterrupted();
            command(e, TDJ_LOOP, 0, rate * 2, rate * 4, 0, 1);
            uninterrupted();
            command(e, TDJ_FLUX, 0, 0, 0, 0, 1);
            uninterrupted();
            for (double speed : {-4., -.25, 1., 4., .25}) {
                command(e, TDJ_TOUCH, 0, rate * 2.5, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, speed);
                uninterrupted();
            }
            // No new input arrives while audio callbacks continue.
            uninterrupted((int)(rate * .25));
            command(e, TDJ_TOUCH, 0, 0, 0, 0, 0);
            uninterrupted();
            command(e, TDJ_LOOP);
            uninterrupted();
            command(e, TDJ_SYNC_RESTORE);
            uninterrupted();
        }
        tdj_recording_stop(recording);
        tdj_recording_destroy(recording);
        // Zero speed holds source motion without stopping the render transport.
        auto before = snapshot(e);
        command(e, TDJ_TOUCH, 0, rate * 2.5, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, 0);
        render(e, (int)rate / 4);
        auto held = snapshot(e);
        assert(held.a.state == TDJ_PLAYING && held.a.source_frame == rate * 2.5);
        assert(held.output_frame == before.output_frame + (int)rate / 4);
        assert(held.master_beat > before.master_beat && held.a.last_start_frame == before.a.last_start_frame);
        command(e, TDJ_TOUCH, 0, rate * 2.5, 0, 0, TDJ_TOUCH_WITH_RATE, nullptr, .05);
        auto spun = render(e, (int)ceil(rate * .002) + 128, 1);
        assert(spun.l[1] > 0 && spun.r[1] > 0);
        assert(snapshot(e).a.state == TDJ_PLAYING && snapshot(e).a.source_frame > held.a.source_frame);
        assert(snapshot(e).a.last_start_frame == held.a.last_start_frame);
        tdj_engine_destroy(e);
        tdj_asset_destroy(asset);
        std::printf("%.0f Hz: %u frames through tempo, Keylock, rate, seek, jump, loop, Flux, scratch, monitor and "
                    "recording without inserted silence.\n",
                    rate, checked);
    }
}
int main(int argc, char **argv) {
    if (argc > 1 && std::strcmp(argv[1], "--scratch-only") == 0) {
        for (double rate : {44100., 48000., 96000.}) {
            std::vector<float> source((int)rate * 4 * 2);
            for (int i = 0; i < (int)rate * 4; i++) {
                source[2 * i] = .7f * sin(2 * 3.141592653589793 * 137 * i / rate + .73);
                source[2 * i + 1] = .6f * cos(2 * 3.141592653589793 * 173 * i / rate + .21);
            }
            auto asset = tdj_asset_create(source.data(), source.size() / 2, rate);
            assert(asset);
            waveform_direct_checks(rate, asset);
            waveform_scratch_checks(rate, asset, source);
            tdj_asset_destroy(asset);
            std::printf("%.0f Hz direct drag position/hold/reversal/Flux and scratch continuity passed.\n", rate);
        }
        return 0;
    }
    continuous_manipulation_checks();
    keylock_reset_quality();
    batched_transition_checks();
    ended_loop_recall_checks();
    performance_rate_return_checks();
    busy_configuration_check();
    for (double rate : {44100., 48000., 96000.}) {
        const int frames = (int)rate * 4, N = (int)ceil(rate * .002);
        std::vector<float> source(frames * 2);
        for (int i = 0; i < frames; i++) {
            source[2 * i] = .7f * sin(2 * 3.141592653589793 * 137 * i / rate + .73);
            source[2 * i + 1] = .6f * cos(2 * 3.141592653589793 * 173 * i / rate + .21);
        }
        // A deliberate musical transient must pass exactly during continuous playback.
        source[12000] = .95f;
        source[12001] = -.95f;
        auto asset = tdj_asset_create(source.data(), frames, rate);
        assert(asset);
        auto e = engine(rate, asset);
        command(e, TDJ_PLAY);
        auto start = render(e, 7000, 17);
        assert(start.l[0] == 0 && start.r[0] == 0);
        exact_source(start, source, 100, N);
        double position = snapshot(e).a.source_frame;
        assert(position == 7100);
        float last = start.l.back(), lastR = start.r.back();
        command(e, TDJ_PLAY);
        assert(snapshot(e).a.state == TDJ_PAUSED);
        auto pause = render(e, N + 20, 1);
        assert(pause.l[0] == last && pause.r[0] == lastR);
        assert(snapshot(e).a.source_frame == position);
        for (int i = N - 1; i < N + 20; i++)
            assert(pause.l[i] == 0 && pause.r[i] == 0);
        command(e, TDJ_PLAY);
        auto resumed = render(e, N + 31, 31);
        assert(resumed.l[0] == 0);
        exact_source(resumed, source, (int)position, N);
        // Every overlapping jump starts from actual emitted output, not stale source history.
        last = resumed.l.back();
        lastR = resumed.r.back();
        for (int n : {1, 17, N / 2, 3, N + 8}) {
            command(e, TDJ_JUMP, 0, 20000 + n);
            auto a = render(e, n, 1);
            assert(a.l[0] == last && a.r[0] == lastR);
            bounded(a, .701);
            last = a.l.back();
            lastR = a.r.back();
        }
        auto settled = render(e, N + 64);
        auto s = snapshot(e);
        exact_source(settled, source, (int)s.a.source_frame - (N + 64), N);
        // Monitor receives the same corrected source. Recording stores those rendered samples exactly.
        mixer(e, TDJ_MIX_CUE, 1);
        mixer(e, TDJ_MIX_MONITOR, 1);
        render(e, 512);
        command(e, TDJ_JUMP, 0, 30000);
        auto buses = render(e, N + 128);
        for (int i = 0; i < N + 128; i++) {
            assert(buses.l[i] == buses.cl[i]);
            assert(buses.r[i] == buses.cr[i]);
        }
        auto ring = tdj_recording_create(1024);
        assert(ring);
        tdj_recording_start(ring);
        tdj_recording_push(ring, N + 128, buses.l.data(), buses.r.data());
        float readL[1024], readR[1024];
        assert(tdj_recording_read(ring, 1024, readL, readR) == (unsigned)(N + 128));
        for (int i = 0; i < N + 128; i++)
            assert(readL[i] == buses.l[i] && readR[i] == buses.r[i]);
        assert(!tdj_recording_dropped(ring));
        tdj_recording_stop(ring);
        tdj_recording_destroy(ring);
        // EOF freezes the source and finishes a bounded tail without cutting the last sample.
        command(e, TDJ_JUMP, 0, frames - 300);
        render(e, 299);
        auto edge = render(e, 1);
        auto ended = snapshot(e);
        assert(ended.a.state == TDJ_ENDED && ended.a.source_frame == frames);
        auto end = render(e, N + 12);
        assert(end.l[0] == edge.l[0] && end.r[0] == edge.r[0]);
        for (int i = N - 1; i < N + 12; i++)
            assert(end.l[i] == 0 && end.r[i] == 0);
        tdj_engine_destroy(e);
        waveform_scratch_checks(rate, asset, source);
        // Tiny loops retain their granular waveform; ordinary seams retain exact period.
        e = engine(rate, asset);
        command(e, TDJ_PLAY);
        render(e, 512);
        command(e, TDJ_LOOP, 0, 20000, 20002, 0, 1);
        render(e, N + 2);
        int p = (int)snapshot(e).a.source_frame;
        auto tiny = render(e, 256);
        for (int i = 0; i < 256; i++)
            assert(tiny.l[i] == source[2 * (20000 + (p - 20000 + i) % 2)]);
        tdj_engine_destroy(e);
        e = engine(rate, asset);
        command(e, TDJ_PLAY);
        render(e, 512);
        command(e, TDJ_LOOP, 0, 20000, 21000, 0, 1);
        render(e, 1000);
        auto previous = render(e, 1000);
        float boundary = previous.l.back();
        auto wrapped = render(e, 1000);
        assert(wrapped.l[0] == boundary);
        assert(snapshot(e).a.source_frame == 20000);
        bounded(wrapped, .701);
        tdj_engine_destroy(e);
        // Retiming one muted deck cannot alter the other deck's audio or shared clock.
        e = engine(rate, asset);
        auto reference = engine(rate, asset);
        for (auto x : {e, reference}) {
            mixer(x, TDJ_MIX_VOLUME, 0);
            command(x, TDJ_TEMPO, 0, 150);
            command(x, TDJ_LOAD, 1, 500, 120, 0, 9, asset);
            command(x, TDJ_PLAY, 1);
            command(x, TDJ_PLAY, 0);
            render(x, 2048);
        }
        for (int i = 0; i < 16; i++) {
            if (i % 4 == 0)
                command(e, TDJ_JUMP, 0, 20000 + i * 100);
            else if (i % 4 == 1)
                command(e, TDJ_RATE, 0, 4);
            else if (i % 4 == 2)
                command(e, TDJ_RATE, 0, 1);
            else
                command(e, TDJ_PLAY, 0);
            auto a = render(e, 137), b = render(reference, 137);
            assert(a.l == b.l && a.r == b.r);
            auto as = snapshot(e), bs = snapshot(reference);
            assert(as.b.source_frame == bs.b.source_frame && as.master_beat == bs.master_beat);
        }
        tdj_engine_destroy(e);
        tdj_engine_destroy(reference);
        tdj_asset_destroy(asset);
        std::printf("%.0f Hz: continuous/transient exact; bounded retriggers; pause/EOF; scratch; tiny/ordinary loops; "
                    "monitor/recording; independent deck passed.\n",
                    rate);
    }
    // Queued onset and quantised jumps keep their exact original coordinates.
    constexpr double rate = 48000;
    std::vector<float> source(48000 * 8 * 2);
    for (int i = 0; i < 48000 * 8; i++)
        source[2 * i] = source[2 * i + 1] = .7f * sin(i * .017 + .7);
    auto asset = tdj_asset_create(source.data(), source.size() / 2, rate);
    assert(asset);
    auto e = engine(rate, asset, true, 0);
    command(e, TDJ_LOAD, 1, 10000, 120, 0, 1, asset);
    mixer(e, TDJ_MIX_CUE, 1, 1);
    mixer(e, TDJ_MIX_MONITOR, 1);
    command(e, TDJ_PLAY, 0);
    render(e, 1024);
    command(e, TDJ_PLAY, 1);
    auto s = snapshot(e);
    assert(s.b.state == TDJ_QUEUED);
    int target = (int)ceil(s.b.target_beat * rate * 60 / s.master_bpm);
    auto wait = render(e, target - (int)s.output_frame, 17);
    for (float x : wait.cl)
        assert(x == 0);
    assert(snapshot(e).b.state == TDJ_QUEUED);
    auto onset = render(e, 1);
    s = snapshot(e);
    assert(s.b.state == TDJ_PLAYING && s.b.last_start_frame == (unsigned)target && s.b.source_frame == 10001 &&
           onset.cl[0] == 0);
    tdj_engine_destroy(e);
    e = engine(rate, asset, true, 0);
    auto reference = engine(rate, asset, true, 0);
    for (auto x : {e, reference}) {
        command(x, TDJ_PLAY);
        render(x, 1024);
    }
    command(e, TDJ_JUMP, 0, 30000, 1);
    s = snapshot(e);
    int until = (int)ceil((s.a.jump_beat - s.master_beat) * rate * 60 / s.master_bpm - 1e-7);
    auto old = render(e, until), same = render(reference, until);
    assert(old.l == same.l);
    auto jump = render(e, 1);
    assert(jump.l[0] == old.l.back());
    assert(snapshot(e).a.source_frame == 30001);
    tdj_engine_destroy(e);
    tdj_engine_destroy(reference);
    // Keylock's identical loop command retains spectral state exactly.
    e = engine(rate, asset, true);
    reference = engine(rate, asset, true);
    for (auto x : {e, reference}) {
        command(x, TDJ_KEYLOCK, 0, 0, 0, 0, 1);
        command(x, TDJ_TEMPO, 0, 150);
        command(x, TDJ_PLAY);
        command(x, TDJ_LOOP, 0, 0, 200000, 0, 1);
        render(x, 10000);
    }
    command(e, TDJ_LOOP, 0, 0, 200000, 0, 1);
    auto unchanged = render(e, 4096), expected = render(reference, 4096);
    assert(unchanged.l == expected.l && unchanged.r == expected.r);
    tdj_engine_destroy(e);
    tdj_engine_destroy(reference);
    // Pause keeps the delay's tail after the dry transition has finished.
    e = engine(rate, asset);
    command(e, TDJ_FX, 0, .5, .8, 1, TDJ_EFFECT_DELAY);
    command(e, TDJ_PLAY);
    render(e, 40000);
    command(e, TDJ_PLAY);
    auto tail = render(e, 24000);
    double energy = 0;
    for (int i = 128; i < 24000; i++)
        energy += fabs(tail.l[i]);
    assert(energy > 1);
    tdj_engine_destroy(e);
    tdj_asset_destroy(asset);
    puts("Queued and quantised timing exact; no pre-start audio; identical-loop Keylock state exact; paused FX tail "
         "preserved.");
}
