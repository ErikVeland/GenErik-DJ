extern "C" {
#include "TDJTransport.h"
}
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <new>
#include <time.h>
#include <vector>

static thread_local bool checking = false;
static thread_local size_t allocations = 0;
void *operator new(size_t size) {
    if (checking) ++allocations;
    if (void *p = std::malloc(size ? size : 1)) return p;
    throw std::bad_alloc();
}
void *operator new[](size_t size) { return ::operator new(size); }
void operator delete(void *p) noexcept { std::free(p); }
void operator delete[](void *p) noexcept { std::free(p); }
void operator delete(void *p, size_t) noexcept { std::free(p); }
void operator delete[](void *p, size_t) noexcept { std::free(p); }

int main() {
    constexpr int rate = 48000, block = 128, calls = 3000;
    std::vector<float> samples(rate*16*2), timings(calls);
    unsigned random = 61;
    for (size_t i = 0; i < samples.size()/2; ++i) {
        random = random*1664525u+1013904223u;
        float noise = (double(random)/4294967295.0-0.5)*0.01;
        samples[i*2] = 0.15*std::sin(i*2*3.141592653589793*440/rate)+noise;
        samples[i*2+1] = 0.15*std::sin(i*2*3.141592653589793*660/rate)-noise;
    }
    tdj_asset *asset = tdj_asset_create(samples.data(), rate*16, rate);
    tdj_engine *core = tdj_engine_create(rate, 0.5);
    if (!asset || !core) return 2;
    tdj_command load{}; load.kind=TDJ_LOAD; load.asset=asset; load.value2=120; load.flag=9;
    load.deck=0; load.generation=1; tdj_submit(core,load);
    load.deck=1; load.generation=2; tdj_submit(core,load);
    tdj_command tempo{}; tempo.kind=TDJ_TEMPO; tempo.value=150; tdj_submit(core,tempo);
    tdj_command play{}; play.kind=TDJ_PLAY; play.deck=0; play.generation=1; tdj_submit(core,play);
    float l[block], r[block];
    double maximum = 0, maximumCPU = 0, first = 0, queued = 0;
    int wallOverruns = 0;
    bool finite = true;
    for (int call = 0; call < calls; ++call) {
        if (call==200) { play.deck=1; play.generation=2; tdj_submit(core,play); }
        if (call==1200) { tempo.value=108; tdj_submit(core,tempo); }
        if (call==1800 || call==2100) {
            tdj_command lock{}; lock.kind=TDJ_KEYLOCK; lock.deck=0; lock.generation=1;
            lock.flag=(call==2100); tdj_submit(core,lock);
        }
        auto start = std::chrono::steady_clock::now();
        timespec cpuStart, cpuEnd;
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpuStart);
        checking = true;
        tdj_render(core,block,l,r);
        checking = false;
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpuEnd);
        double cpuMicros = (cpuEnd.tv_sec-cpuStart.tv_sec)*1000000.0+(cpuEnd.tv_nsec-cpuStart.tv_nsec)/1000.0;
        maximumCPU=std::max(maximumCPU,cpuMicros);
        double micros=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-start).count();
        timings[call]=micros; maximum=std::max(maximum,micros);
        if (micros > block*1000000.0/rate) ++wallOverruns;
        if (call==0) first=micros;
        if (call==600) queued=micros;
        for (int i=0;i<block;++i) finite=finite && std::isfinite(l[i]) && std::isfinite(r[i]);
        tdj_message message; while (tdj_read_message(core,&message)) {}
    }
    std::sort(timings.begin(),timings.end());
    std::printf("{\"kind\":\"local synthetic C++ allocation and render timing probe\",\"sampleRate\":48000,\"blockFrames\":128,\"calls\":3000,\"cppAllocationsDuringRender\":%zu,\"finite\":%s,\"deadlineMicroseconds\":%.3f,\"medianMicroseconds\":%.3f,\"p99Microseconds\":%.3f,\"maximumMicroseconds\":%.3f,\"maximumThreadCPUMicroseconds\":%.3f,\"wallDeadlineOverruns\":%d,\"firstPlayMicroseconds\":%.3f,\"queuedStartMicroseconds\":%.3f}\n",
        allocations,finite?"true":"false",block*1000000.0/rate,timings[calls/2],timings[calls*99/100],maximum,maximumCPU,wallOverruns,first,queued);
    tdj_engine_destroy(core); tdj_asset_destroy(asset);
    return allocations || !finite ? 1 : 0;
}
