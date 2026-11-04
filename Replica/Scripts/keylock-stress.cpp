extern "C" {
#include "TDJTransport.h"
}
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <new>
#include <string>
#include <thread>
#include <vector>
#include <sys/resource.h>
#include <time.h>

static thread_local bool inRender = false;
static thread_local uint64_t renderAllocations = 0;
void *operator new(size_t size) {
    if (inRender)
        ++renderAllocations;
    if (void *p = std::malloc(size ? size : 1))
        return p;
    throw std::bad_alloc();
}
void *operator new[](size_t n) {
    return ::operator new(n);
}
void operator delete(void *p) noexcept {
    std::free(p);
}
void operator delete[](void *p) noexcept {
    std::free(p);
}
void operator delete(void *p, size_t) noexcept {
    std::free(p);
}
void operator delete[](void *p, size_t) noexcept {
    std::free(p);
}
void *operator new(size_t n, std::align_val_t alignment) {
    if (inRender)
        ++renderAllocations;
    void *p = nullptr;
    if (posix_memalign(&p, static_cast<size_t>(alignment), n ? n : 1))
        throw std::bad_alloc();
    return p;
}
void *operator new[](size_t n, std::align_val_t a) {
    return ::operator new(n, a);
}
void operator delete(void *p, std::align_val_t) noexcept {
    std::free(p);
}
void operator delete[](void *p, std::align_val_t) noexcept {
    std::free(p);
}
void operator delete(void *p, size_t, std::align_val_t) noexcept {
    std::free(p);
}
void operator delete[](void *p, size_t, std::align_val_t) noexcept {
    std::free(p);
}

using Clock = std::chrono::steady_clock;
static double cpuTime() {
    timespec t{};
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t);
    return t.tv_sec * 1e6 + t.tv_nsec / 1e3;
}
static uint64_t nextID = 0;
static bool variedCues = false;
static bool send(tdj_engine *core, int kind, int deck = 0, uint64_t generation = 0, double value = 0, int flag = 0) {
    tdj_command c{};
    c.kind = kind;
    c.deck = deck;
    c.generation = generation;
    c.value = value;
    c.flag = flag;
    c.id = ++nextID;
    return tdj_submit(core, c);
}
static void load(tdj_engine *core, tdj_asset *asset, int deck) {
    tdj_command c{};
    c.kind = TDJ_LOAD;
    c.deck = deck;
    c.generation = deck + 1;
    c.asset = asset;
    c.value2 = 120;
    c.flag = 9;
    c.id = ++nextID;
    if (!tdj_submit(core, c))
        std::abort();
}
struct Result {
    std::string name;
    int rate = 48000, block = 128;
    double renderedSeconds = 0, wallSeconds = 0, maxWall = 0, maxCPU = 0, maxStep = 0, peak = 0, minRMS = 1,
           worstCents = 0;
    double median = 0, p99 = 0, maxWakeLateness = 0;
    uint64_t calls = 0, allocations = 0, nonfinite = 0, renderErrors = 0, ackErrors = 0, queueErrors = 0;
    uint64_t deadlineOverruns = 0, cpuOverruns = 0, starts = 0, scheduleErrors = 0, maximumScheduleError = 0;
    uint64_t sourceErrors = 0, pendingStateErrors = 0, dropoutWindows = 0, expectedGateRejections = 0;
    uint64_t highWaterBytes = 0;
    uint64_t acceptedControlCommands = 0, backpressureRejections = 0, snapshotReads = 0, snapshotRetries = 0,
             snapshotErrors = 0;
    bool tone = false, paced = false;
    std::vector<double> times;
    uint64_t hardFailures() const {
        return allocations + nonfinite + renderErrors + ackErrors + queueErrors + scheduleErrors + sourceErrors +
               pendingStateErrors + snapshotErrors + (tone ? dropoutWindows + (worstCents > 5) + (maxStep > 0.05) : 0);
    }
    void json(std::ostream &s) const {
        s << "{\"name\":\"" << name << "\",\"sampleRate\":" << rate << ",\"blockFrames\":" << block
          << ",\"renderedSeconds\":" << renderedSeconds << ",\"wallSeconds\":" << wallSeconds
          << ",\"paced\":" << (paced ? "true" : "false") << ",\"callbacks\":" << calls
          << ",\"medianWallMicroseconds\":" << median << ",\"p99WallMicroseconds\":" << p99
          << ",\"maximumWallMicroseconds\":" << maxWall << ",\"maximumThreadCPUMicroseconds\":" << maxCPU
          << ",\"deadlineMicroseconds\":" << block * 1e6 / rate << ",\"wallDeadlineOverruns\":" << deadlineOverruns
          << ",\"cpuDeadlineOverruns\":" << cpuOverruns << ",\"maximumWakeLatenessMicroseconds\":" << maxWakeLateness
          << ",\"cppAllocationsDuringRender\":" << allocations << ",\"nonfiniteSamples\":" << nonfinite
          << ",\"renderErrors\":" << renderErrors << ",\"unexpectedAcknowledgements\":" << ackErrors
          << ",\"queueSubmissionErrors\":" << queueErrors << ",\"queuedStarts\":" << starts
          << ",\"scheduleErrors\":" << scheduleErrors << ",\"maximumScheduleErrorFrames\":" << maximumScheduleError
          << ",\"sourceTimelineErrors\":" << sourceErrors << ",\"pendingStateErrors\":" << pendingStateErrors
          << ",\"expectedGateRejections\":" << expectedGateRejections << ",\"peak\":" << peak
          << ",\"maximumAdjacentSampleStep\":" << maxStep << ",\"minimumWindowRMS\":" << (tone ? minRMS : 0)
          << ",\"dropoutWindows\":" << dropoutWindows << ",\"worstHalfSecondPitchErrorCents\":" << worstCents
          << ",\"processHighWaterBytes\":" << highWaterBytes
          << ",\"acceptedControlCommands\":" << acceptedControlCommands
          << ",\"backpressureRejections\":" << backpressureRejections << ",\"snapshotReads\":" << snapshotReads
          << ",\"snapshotRetries\":" << snapshotRetries << ",\"invalidSnapshots\":" << snapshotErrors
          << ",\"hardFailures\":" << hardFailures() << "}";
    }
};
static void wav(const std::string &path, const std::vector<float> &samples, int rate) {
    std::ofstream f(path, std::ios::binary);
    auto u16 = [&](uint16_t v) {
        f.put(v & 255);
        f.put(v >> 8);
    };
    auto u32 = [&](uint32_t v) {
        u16(v & 65535);
        u16(v >> 16);
    };
    uint32_t bytes = static_cast<uint32_t>(samples.size() * 2);
    f.write("RIFF", 4);
    u32(36 + bytes);
    f.write("WAVEfmt ", 8);
    u32(16);
    u16(1);
    u16(2);
    u32(rate);
    u32(rate * 4);
    u16(4);
    u16(16);
    f.write("data", 4);
    u32(bytes);
    for (float v : samples)
        u16(static_cast<uint16_t>(static_cast<int16_t>(std::lround(std::clamp(v, -1.0f, 1.0f) * 32767))));
}
static Result run(const std::string &name, int rate, int block, double seconds, bool tone, bool paced, tdj_asset *asset,
                  const std::string &directory) {
    Result result;
    result.name = name;
    result.rate = rate;
    result.block = block;
    result.tone = tone;
    result.paced = paced;
    result.times.reserve(static_cast<size_t>(std::ceil(seconds * rate / block)));
    tdj_engine *core = tdj_engine_create(rate, 0.5);
    if (!core)
        std::abort();
    load(core, asset, 0);
    if (!tone)
        load(core, asset, 1);
    send(core, TDJ_PLAY, 0, 1);
    // Exact rational reference for integer-BPM automation. No shared clock helper.
    const uint64_t denominator = static_cast<uint64_t>(rate) * 60;
    uint64_t referenceTicks = 0, targetBeat = 0, expectedLaunch = UINT64_MAX, lastLaunch = 0;
    bool pending = false;
    double heldPosition = 0;
    int incoming = 1, lastStarted = 0;
    uint64_t frame = 0;
    int bpm = 120;
    float left[4096], right[4096], previous = 0;
    std::vector<float> recording;
    if (tone)
        recording.reserve(static_cast<size_t>(seconds * rate) * 2);
    double energy = 0;
    int windowCount = 0;
    std::vector<double> crossings;
    crossings.reserve(rate / 2);
    uint64_t pitchWindow = 0;
    uint64_t allocationStart = renderAllocations;
    uint64_t progressFrame = static_cast<uint64_t>(rate) * 30;
    auto start = Clock::now();
    while (frame < static_cast<uint64_t>(seconds * rate)) {
        int count = std::min<uint64_t>(block, static_cast<uint64_t>(seconds * rate) - frame);
        int phase = static_cast<int>(result.calls % 97);
        bpm =
            tone ? 108 + (phase <= 48 ? phase / 2 : (96 - phase) / 2) : 96 + static_cast<int>((result.calls / 5) % 61);
        if (!send(core, TDJ_TEMPO, 0, 0, bpm))
            ++result.queueErrors;
        tdj_snapshot before{};
        tdj_read_snapshot(core, &before);
        if (!tone && !pending &&
            (result.starts == 0 ? frame > uint64_t(rate / 2) : frame - lastLaunch > uint64_t(rate * 2))) {
            if (result.starts > 0) {
                incoming = 1 - lastStarted;
                heldPosition = variedCues ? ((result.starts * 7) % 48) * 48000 : 0;
                if (!send(core, TDJ_PLAY, incoming, incoming + 1))
                    ++result.queueErrors;
                if (!send(core, TDJ_SEEK, incoming, incoming + 1, heldPosition))
                    ++result.queueErrors;
            }
            if (!send(core, TDJ_PLAY, incoming, incoming + 1))
                ++result.queueErrors;
            targetBeat = (referenceTicks / (4 * denominator) + 1) * 4;
            pending = true;
            expectedLaunch = UINT64_MAX;
        }
        if (pending) {
            uint64_t remaining = targetBeat * denominator - referenceTicks;
            uint64_t offset = (remaining + bpm - 1) / bpm;
            expectedLaunch = frame + offset;
        }
        uint64_t gated = 0;
        if (pending && result.calls % 257 == 0 && expectedLaunch >= frame + count) {
            // These original policies remain unresolved. They must retain the queue.
            send(core, TDJ_PLAY, incoming, incoming + 1);
            send(core, TDJ_KEYLOCK, incoming, incoming + 1, 0, 0);
            gated = 2;
        }
        auto deadline = start + std::chrono::nanoseconds(static_cast<int64_t>(frame * 1e9 / rate));
        if (paced) {
            std::this_thread::sleep_until(deadline);
            result.maxWakeLateness = std::max(
                result.maxWakeLateness, std::chrono::duration<double, std::micro>(Clock::now() - deadline).count());
        }
        auto wallStart = Clock::now();
        double cpuStart = cpuTime();
        inRender = true;
        bool ok = tdj_render(core, count, left, right);
        inRender = false;
        double cpu = cpuTime() - cpuStart;
        double wall = std::chrono::duration<double, std::micro>(Clock::now() - wallStart).count();
        result.times.push_back(wall);
        result.maxWall = std::max(result.maxWall, wall);
        result.maxCPU = std::max(result.maxCPU, cpu);
        if (wall > count * 1e6 / rate)
            ++result.deadlineOverruns;
        if (cpu > count * 1e6 / rate)
            ++result.cpuOverruns;
        if (!ok)
            ++result.renderErrors;
        tdj_message ack{};
        uint64_t gateCount = 0;
        while (tdj_read_message(core, &ack)) {
            if (ack.status == TDJ_UNRESOLVED && gated)
                ++gateCount;
            else if (ack.status != TDJ_OK && ack.status != TDJ_RETIRED)
                ++result.ackErrors;
        }
        if (gateCount != gated)
            ++result.pendingStateErrors;
        result.expectedGateRejections += gateCount;
        tdj_snapshot after{};
        if (!tdj_read_snapshot(core, &after))
            ++result.sourceErrors;
        if (pending) {
            auto d = incoming ? after.b : after.a;
            if (expectedLaunch < frame + count) {
                ++result.starts;
                uint64_t error = d.last_start_frame > expectedLaunch ? d.last_start_frame - expectedLaunch
                                                                     : expectedLaunch - d.last_start_frame;
                if (d.state != TDJ_PLAYING || error) {
                    if (result.scheduleErrors < 8)
                        std::fprintf(
                            stderr,
                            "launch mismatch: callback=%llu expected=%llu actual=%llu bpm=%d target=%llu ticks=%llu\n",
                            frame, expectedLaunch, d.last_start_frame, bpm, targetBeat, referenceTicks);
                    ++result.scheduleErrors;
                }
                result.maximumScheduleError = std::max(result.maximumScheduleError, error);
                double expectedPosition = heldPosition + (frame + count - expectedLaunch) * 48000.0 / rate * bpm / 120;
                if (std::abs(d.source_frame - expectedPosition) > 0.001) {
                    if (result.sourceErrors < 8)
                        std::fprintf(stderr, "position mismatch: expected=%.9f actual=%.9f\n", expectedPosition,
                                     d.source_frame);
                    ++result.sourceErrors;
                }
                lastLaunch = d.last_start_frame;
                lastStarted = incoming;
                pending = false;
            } else if (d.state != TDJ_QUEUED || d.source_frame != heldPosition || d.target_beat != targetBeat)
                ++result.pendingStateErrors;
        }
        if (tone) {
            double expectedPosition = (referenceTicks + uint64_t(count) * bpm) * 48000.0 / (rate * 120);
            if (std::abs(after.a.source_frame - expectedPosition) > 0.1)
                ++result.sourceErrors;
        }
        for (int i = 0; i < count; ++i) {
            if (!std::isfinite(left[i]) || !std::isfinite(right[i]))
                ++result.nonfinite;
            result.peak = std::max(result.peak, double(std::max(std::abs(left[i]), std::abs(right[i]))));
            if (tone) {
                uint64_t at = frame + i;
                recording.push_back(left[i]);
                recording.push_back(right[i]);
                if (at > uint64_t(rate / 2)) {
                    result.maxStep = std::max(result.maxStep, double(std::abs(left[i] - previous)));
                    energy += left[i] * left[i];
                    ++windowCount;
                    if (previous <= 0 && left[i] > 0)
                        crossings.push_back(at - 1 + double(-previous) / (left[i] - previous));
                    if (windowCount == 256) {
                        double rms = std::sqrt(energy / windowCount);
                        result.minRMS = std::min(result.minRMS, rms);
                        if (rms < 0.01)
                            ++result.dropoutWindows;
                        energy = 0;
                        windowCount = 0;
                    }
                    uint64_t which = at / (rate / 2);
                    if (which != pitchWindow && crossings.size() > 2) {
                        double hz = (crossings.size() - 1) * rate / (crossings.back() - crossings.front());
                        result.worstCents = std::max(result.worstCents, std::abs(1200 * std::log2(hz / 440)));
                        crossings.clear();
                        pitchWindow = which;
                    }
                }
                previous = left[i];
            }
        }
        referenceTicks += uint64_t(count) * bpm;
        frame += count;
        ++result.calls;
        if (paced && frame >= progressFrame) {
            std::printf("paced %.0f seconds: %llu starts, %llu errors, %llu wall overruns\n", double(frame) / rate,
                        result.starts, result.hardFailures(), result.deadlineOverruns);
            std::fflush(stdout);
            progressFrame += static_cast<uint64_t>(rate) * 30;
        }
    }
    result.wallSeconds = std::chrono::duration<double>(Clock::now() - start).count();
    result.renderedSeconds = double(frame) / rate;
    result.allocations = renderAllocations - allocationStart;
    std::sort(result.times.begin(), result.times.end());
    result.median = result.times[result.times.size() / 2];
    result.p99 = result.times[result.times.size() * 99 / 100];
    rusage usage{};
    getrusage(RUSAGE_SELF, &usage);
    result.highWaterBytes = usage.ru_maxrss;
    if (tone)
        wav(directory + "/" + name + ".wav", recording, rate);
    tdj_engine_destroy(core);
    return result;
}
static Result concurrent(double seconds, tdj_asset *asset) {
    Result result;
    result.name = "concurrent-controls-and-snapshots";
    result.paced = true;
    const int rate = 48000, block = 128;
    result.times.reserve(static_cast<size_t>(seconds * rate / block) + 1);
    tdj_engine *core = tdj_engine_create(rate, 0.5);
    load(core, asset, 0);
    load(core, asset, 1);
    send(core, TDJ_PLAY, 0, 1);
    send(core, TDJ_PLAY, 1, 2);
    tdj_render(core, 0, nullptr, nullptr);
    tdj_message message{};
    while (tdj_read_message(core, &message)) {
    }
    std::atomic<bool> stop{false};
    uint64_t accepted = 0, rejected = 0, ackErrors = 0, reads = 0, retries = 0, snapshotErrors = 0;
    std::thread producer([&] {
        int cycle = 0;
        while (!stop.load(std::memory_order_relaxed)) {
            int burst = cycle % 37 == 0 ? 512 : 1;
            for (int i = 0; i < burst; ++i) {
                if (send(core, TDJ_TEMPO, 0, 0, 108 + (cycle + i) % 25))
                    ++accepted;
                else
                    ++rejected;
            }
            tdj_message ack{};
            while (tdj_read_message(core, &ack))
                if (ack.status != TDJ_OK)
                    ++ackErrors;
            ++cycle;
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
        tdj_message ack{};
        while (tdj_read_message(core, &ack))
            if (ack.status != TDJ_OK)
                ++ackErrors;
    });
    std::thread reader([&] {
        uint64_t previousFrame = 0;
        while (!stop.load(std::memory_order_relaxed)) {
            tdj_snapshot snapshot{};
            if (!tdj_read_snapshot(core, &snapshot))
                ++retries;
            else {
                ++reads;
                bool valid = snapshot.output_frame >= previousFrame && snapshot.sample_rate == rate &&
                             snapshot.master_bpm >= 108 && snapshot.master_bpm <= 132;
                // Initial state may precede the producer's first tempo command.
                valid = valid && snapshot.a.source_frame >= 0 && snapshot.b.source_frame >= 0;
                valid = valid && snapshot.a.keylock == 1 && snapshot.b.keylock == 1;
                valid = valid && std::abs(snapshot.a.source_rate - snapshot.master_bpm / 120) < 1e-12;
                if (!valid)
                    ++snapshotErrors;
                previousFrame = snapshot.output_frame;
            }
            std::this_thread::sleep_for(std::chrono::microseconds(250));
        }
    });
    uint64_t allocationStart = renderAllocations, frame = 0, ticks = 0;
    float left[block], right[block];
    auto start = Clock::now();
    while (frame < static_cast<uint64_t>(seconds * rate)) {
        int count = std::min<uint64_t>(block, static_cast<uint64_t>(seconds * rate) - frame);
        auto due = start + std::chrono::nanoseconds(static_cast<int64_t>(frame * 1e9 / rate));
        std::this_thread::sleep_until(due);
        result.maxWakeLateness =
            std::max(result.maxWakeLateness, std::chrono::duration<double, std::micro>(Clock::now() - due).count());
        tdj_snapshot before{};
        tdj_read_snapshot(core, &before);
        auto wallStart = Clock::now();
        double cpuStart = cpuTime();
        inRender = true;
        bool ok = tdj_render(core, count, left, right);
        inRender = false;
        double cpu = cpuTime() - cpuStart,
               wall = std::chrono::duration<double, std::micro>(Clock::now() - wallStart).count();
        result.times.push_back(wall);
        result.maxCPU = std::max(result.maxCPU, cpu);
        result.maxWall = std::max(result.maxWall, wall);
        if (wall > count * 1e6 / rate)
            ++result.deadlineOverruns;
        if (cpu > count * 1e6 / rate)
            ++result.cpuOverruns;
        if (!ok)
            ++result.renderErrors;
        tdj_snapshot after{};
        if (!tdj_read_snapshot(core, &after))
            ++result.snapshotErrors;
        int bpm = static_cast<int>(after.master_bpm);
        if (before.b.state == TDJ_QUEUED) {
            uint64_t remaining = 4 * uint64_t(rate) * 60 - ticks;
            uint64_t expected = frame + (remaining + bpm - 1) / bpm;
            if (expected < frame + count) {
                ++result.starts;
                uint64_t error = after.b.last_start_frame > expected ? after.b.last_start_frame - expected
                                                                     : expected - after.b.last_start_frame;
                if (after.b.state != TDJ_PLAYING || error)
                    ++result.scheduleErrors;
                result.maximumScheduleError = std::max(result.maximumScheduleError, error);
            } else if (after.b.state != TDJ_QUEUED)
                ++result.scheduleErrors;
        }
        ticks += uint64_t(count) * bpm;
        if (std::abs(after.a.source_frame - double(ticks) / 120) > 0.01)
            ++result.sourceErrors;
        for (int i = 0; i < count; ++i) {
            if (!std::isfinite(left[i]) || !std::isfinite(right[i]))
                ++result.nonfinite;
            result.peak = std::max(result.peak, double(std::max(std::abs(left[i]), std::abs(right[i]))));
        }
        frame += count;
        ++result.calls;
    }
    stop.store(true);
    producer.join();
    reader.join();
    result.acceptedControlCommands = accepted;
    result.backpressureRejections = rejected;
    result.ackErrors = ackErrors;
    result.snapshotReads = reads;
    result.snapshotRetries = retries;
    result.snapshotErrors += snapshotErrors;
    result.allocations = renderAllocations - allocationStart;
    result.wallSeconds = std::chrono::duration<double>(Clock::now() - start).count();
    result.renderedSeconds = double(frame) / rate;
    std::sort(result.times.begin(), result.times.end());
    result.median = result.times[result.times.size() / 2];
    result.p99 = result.times[result.times.size() * 99 / 100];
    rusage usage{};
    getrusage(RUSAGE_SELF, &usage);
    result.highWaterBytes = usage.ru_maxrss;
    tdj_engine_destroy(core);
    return result;
}
int main(int argc, char **argv) {
    std::string directory = "Validation/KeylockStress";
    double seconds = 1800, paced = 300, threaded = 0;
    int workers = 2;
    for (int i = 1; i + 1 < argc; i += 2) {
        std::string a = argv[i];
        if (a == "--output")
            directory = argv[i + 1];
        else if (a == "--seconds")
            seconds = std::stod(argv[i + 1]);
        else if (a == "--paced-seconds")
            paced = std::stod(argv[i + 1]);
        else if (a == "--workers")
            workers = std::stoi(argv[i + 1]);
        else if (a == "--concurrent-seconds")
            threaded = std::stod(argv[i + 1]);
        else if (a == "--varied-cues")
            variedCues = std::stoi(argv[i + 1]) != 0;
        else
            return 2;
    }
    if (seconds < 1 || seconds > 7200 || paced < 0 || paced > 1800 || threaded < 0 || threaded > 60 || workers < 0 ||
        workers > 4)
        return 2;
    std::filesystem::create_directories(directory);
    std::vector<float> samples(48000 * 64 * 2);
    for (size_t i = 0; i < samples.size() / 2; ++i) {
        samples[i * 2] = 0.2 * std::sin(i * 2 * 3.141592653589793 * 440 / 48000);
        samples[i * 2 + 1] = 0.2 * std::sin(i * 2 * 3.141592653589793 * 660 / 48000);
    }
    std::string source = directory + "/synthetic-stereo.f32";
    {
        std::ofstream f(source, std::ios::binary);
        f.write(reinterpret_cast<char *>(samples.data()), samples.size() * sizeof(float));
    }
    tdj_asset *asset = tdj_asset_map(source.c_str(), 48000 * 64, 48000);
    if (!asset)
        return 2;
    std::atomic<bool> stop{false};
    std::vector<std::thread> loadThreads;
    for (int i = 0; i < workers; ++i)
        loadThreads.emplace_back([&stop, i] {
            std::vector<double> memory(2097152, 0.01 * (i + 1));
            double sum = 1;
            while (!stop.load(std::memory_order_relaxed)) {
                for (size_t j = 0; j < memory.size(); j += 8) {
                    sum = std::sin(sum + memory[j]) + 1;
                    memory[j] = sum;
                }
                std::atomic_signal_fence(std::memory_order_seq_cst);
            }
        });
    std::vector<Result> results;
    for (int block : {127, 128, 511}) {
        results.push_back(run("rapid-tempo-" + std::to_string(block), 48000, block, 12, true, false, asset, directory));
        std::printf("%s: %llu failures, %.3f cents, step %.6f\n", results.back().name.c_str(),
                    results.back().hardFailures(), results.back().worstCents, results.back().maxStep);
        std::fflush(stdout);
    }
    results.push_back(run("sustained-handover", 48000, 128, seconds, false, false, asset, directory));
    std::printf("sustained: %llu starts, %llu failures\n", results.back().starts, results.back().hardFailures());
    std::fflush(stdout);
    if (paced > 0) {
        results.push_back(run("paced-under-load", 48000, 128, paced, false, true, asset, directory));
        std::printf("paced: %llu starts, %llu failures\n", results.back().starts, results.back().hardFailures());
        std::fflush(stdout);
    }
    if (threaded > 0) {
        results.push_back(concurrent(threaded, asset));
        std::printf("concurrent: %llu accepted controls, %llu backpressure rejections, %llu failures\n",
                    results.back().acceptedControlCommands, results.back().backpressureRejections,
                    results.back().hardFailures());
        std::fflush(stdout);
    }
    stop.store(true);
    for (auto &t : loadThreads)
        t.join();
    tdj_asset_destroy(asset);
    std::ofstream out(directory + "/stress.json");
    out << std::setprecision(12);
    out << "{\"format\":\"generik-dj.keylock-stress/v1\",\"backgroundWorkers\":" << workers
        << ",\"variedCuePositions\":" << (variedCues ? "true" : "false")
        << ",\"syntheticSource\":true,\"deviceAccess\":false,\"threadScheduling\":\"normal priority, no audio-device "
           "output\",\"scenarios\":[";
    uint64_t failures = 0;
    for (size_t i = 0; i < results.size(); ++i) {
        if (i)
            out << ',';
        results[i].json(out);
        failures += results[i].hardFailures();
    }
    out << "],\"hardFailures\":" << failures << "}\n";
    return failures ? 1 : 0;
}
