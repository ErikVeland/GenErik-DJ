#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
extern "C" {
#include "TDJTransport.h"
}
#include <atomic>
#include <array>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iomanip>
#include <thread>
#include <vector>
#include <mach/mach_time.h>
#include <time.h>
#include <csignal>
#include <unistd.h>
#include <cerrno>
#include <cstdlib>
#include <new>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <pthread.h>
#include <sys/mman.h>
#include <fcntl.h>
#include "native-residency-diagnostic.h"
#include "native-recording-probe.h"

static volatile sig_atomic_t stopRequested=0;
static void stopSignal(int) {stopRequested=1;}
static thread_local bool inRender=false;
static thread_local uint64_t renderAllocations=0;
static std::atomic<bool> allocationProfiling{false};
void *operator new(size_t n) {
    if(allocationProfiling.load(std::memory_order_relaxed) && inRender)++renderAllocations;
    if(void *p=std::malloc(n?n:1)){recordDSPAllocation(p,n?n:1);return p;}
    throw std::bad_alloc();
}
void *operator new[](size_t n){return ::operator new(n);}
void operator delete(void *p)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete[](void *p)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete(void *p,size_t)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete[](void *p,size_t)noexcept{forgetDSPAllocation(p);std::free(p);}
void *operator new(size_t n,std::align_val_t a) {
    if(allocationProfiling.load(std::memory_order_relaxed) && inRender)++renderAllocations;
    void *p=nullptr;if(posix_memalign(&p,size_t(a),n?n:1))throw std::bad_alloc();recordDSPAllocation(p,n?n:1);return p;
}
void *operator new[](size_t n,std::align_val_t a){return ::operator new(n,a);}
void operator delete(void *p,std::align_val_t)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete[](void *p,std::align_val_t)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete(void *p,size_t,std::align_val_t)noexcept{forgetDSPAllocation(p);std::free(p);}
void operator delete[](void *p,size_t,std::align_val_t)noexcept{forgetDSPAllocation(p);std::free(p);}

template <typename T> static OSStatus deviceProperty(AudioObjectID device,AudioObjectPropertySelector selector,T &value) {
    AudioObjectPropertyAddress address{selector,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
    UInt32 bytes=sizeof(value);
    return AudioObjectGetPropertyData(device,&address,0,nullptr,&bytes,&value);
}
static OSStatus setBufferFrames(AudioObjectID device,UInt32 frames) {
    AudioObjectPropertyAddress address{kAudioDevicePropertyBufferFrameSize,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
    return AudioObjectSetPropertyData(device,&address,0,nullptr,sizeof(frames),&frames);
}
struct BufferRequest {
    AudioObjectID device=0;
    UInt32 original=0,requested=0,observed=0,restored=0;
    OSStatus requestStatus=0,restoreStatus=0;
    bool changed=false;
    bool request(AudioObjectID id,UInt32 frames) {
        device=id;requested=frames;
        if(deviceProperty(device,kAudioDevicePropertyBufferFrameSize,original))return false;
        if(frames && original!=frames) {
            changed=true;requestStatus=setBufferFrames(device,frames);
            if(requestStatus)return false;
        }
        return !deviceProperty(device,kAudioDevicePropertyBufferFrameSize,observed) && (!frames || frames==observed);
    }
    bool restore() {
        if(changed)restoreStatus=setBufferFrames(device,original);
        bool ok=!deviceProperty(device,kAudioDevicePropertyBufferFrameSize,restored) && !restoreStatus && restored==original;
        if(ok)changed=false;
        return ok;
    }
    ~BufferRequest() {if(changed)restore();}
};

struct Telemetry {
    std::atomic<uint64_t> calls{0},frames{0},maxWallNS{0},maxCPUNS{0},wallOverruns{0},cpuOverruns{0},badBuffers{0},nonfinite{0};
    std::atomic<uint64_t> minimumFrames{UINT64_MAX},maximumFrames{0};
    std::atomic<uint64_t> overloadNotifications{0},timestampGaps{0},invalidSampleTimestamps{0},invalidHostTimestamps{0},allocations{0},scheduleErrors{0},sourceErrors{0},pendingErrors{0},checkedStarts{0};
    std::atomic<uint64_t> heldSource[2]{};
    std::atomic_flag callbackBusy=ATOMIC_FLAG_INIT;
    std::atomic<uint64_t> overlappingCallbacks{0},lastOverloadHostTick{0},frameSequenceErrors{0};
    struct Cycle {uint64_t frame,count,begin,end,host,graphBegin,graphEnd,renderEnd,flags,renderBegin,beforeProbe,afterProbe;double sampleTime,graphSample;};
    std::array<Cycle,64> recent{};
    struct Trace {std::array<Cycle,64> before{};Cycle gap{};};
    std::array<Trace,16> traces{};size_t recordedTraces=0,recentCount=0;
    std::atomic<uint64_t> graphBegin{0},lastGraphBegin{0},lastGraphEnd{0},graphCalls{0},maxGraphNS{0},graphOverruns{0},maxFullSourceNS{0},fullSourceOverruns{0};
    std::atomic<double> lastGraphSample{0};
    uint64_t referenceTicks=0,lastStart[2]={0,0},histogram[128]={};
    uint64_t expectedLaunch[2]={UINT64_MAX,UINT64_MAX};
    double nextSampleTime=0;bool haveTimestamp=false;
    struct Overrun {uint64_t frame,wall,cpu,core,beforeProbe,afterProbe;bool start;};
    std::array<Overrun,256> overruns{};size_t recordedOverruns=0;
    struct Event {uint64_t frame,count,ticks,bpm,target,expected,actual,wallTick;double sampleTime,expectedSampleTime,masterBeat;int kind,deck;};
    std::array<Event,256> events{};size_t recordedEvents=0;
    bool policyCaptured=false;int policyStatus=-1;boolean_t policyDefault=TRUE;
    thread_time_constraint_policy_data_t timePolicy{};
    void event(Event value) {if(recordedEvents<events.size())events[recordedEvents++]=value;}
};
static OSStatus overloadListener(AudioObjectID,UInt32,const AudioObjectPropertyAddress *,void *context) {
    auto *t=static_cast<Telemetry *>(context);t->overloadNotifications.fetch_add(1,std::memory_order_relaxed);t->lastOverloadHostTick.store(mach_absolute_time(),std::memory_order_relaxed);return noErr;
}
static_assert(std::atomic<uint64_t>::is_always_lock_free,"Audio telemetry must be lock-free");
static uint64_t cpuNS() {
    timespec t{};clock_gettime(CLOCK_THREAD_CPUTIME_ID,&t);
    return uint64_t(t.tv_sec)*1000000000+uint64_t(t.tv_nsec);
}
static void maximum(std::atomic<uint64_t> &value,uint64_t next) {
    // The audio callback is the sole writer.
    if(next>value.load(std::memory_order_relaxed)) value.store(next,std::memory_order_relaxed);
}
static constexpr uint64_t expectedStart(uint64_t frame,uint64_t ticks,uint64_t target,uint64_t bpm) {
    // A boundary after the previous buffer's final sample can be less than one
    // sample behind this buffer. Its first sample is the exact rounded-up start.
    uint64_t remaining=target>ticks ? target-ticks : 0;
    return frame+(remaining+bpm-1)/bpm;
}
static_assert(expectedStart(6676864,840960128,292ull*2880000,149)==6676864,"Captured cross-buffer boundary");
static_assert(expectedStart(100,200,200,149)==100,"Exact boundary");
static_assert(expectedStart(100,200,350,149)==102,"Fractional future boundary");
static constexpr uint64_t retimedStart(uint64_t frame,uint64_t ticks,uint64_t target,uint64_t bpm,uint64_t previous) {
    // Retain the previous prediction once the boundary has passed. Extrapolating
    // a new tempo backwards can move a boundary into an earlier buffer.
    return target>ticks ? expectedStart(frame,ticks,target,bpm) : previous;
}
static_assert(retimedStart(6676864,840960128,292ull*2880000,96,6676864)==6676864,"Tempo change after a fractional crossing");
static_assert(retimedStart(6676864,840960128,292ull*2880000,149,6676863)==6676863,"Retain a missed launch so lateness remains detectable");
static uint64_t commandID=0;
static bool command(tdj_engine *core,int kind,int deck=0,double value=0,int flag=0) {
    tdj_command c{};c.id=++commandID;c.kind=kind;c.deck=deck;c.generation=deck+1;c.value=value;c.flag=flag;
    return tdj_submit(core,c);
}
int main(int argc,char **argv) {
    @autoreleasepool {
        AVAudioEngine *engine=nil;
        AudioObjectID device=kAudioObjectUnknown;
        if(deviceProperty(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice,device) || !device)return 2;
        UInt32 current=0,transport=0;Float64 nominal=0;AudioValueRange range{};
        deviceProperty(device,kAudioDevicePropertyBufferFrameSize,current);
        deviceProperty(device,kAudioDevicePropertyTransportType,transport);
        deviceProperty(device,kAudioDevicePropertyNominalSampleRate,nominal);
        deviceProperty(device,kAudioDevicePropertyBufferFrameSizeRange,range);
        CFStringRef nameRef=nullptr;
        deviceProperty(device,kAudioObjectPropertyName,nameRef);
        NSString *deviceName=CFBridgingRelease(nameRef) ?: @"Unknown output";
        if(argc==2 && std::string(argv[1])=="--device-info") {
            NSDictionary *info=@{@"defaultOutputDeviceID":@(device),@"deviceName":deviceName,@"transportType":@(transport),@"builtIn":@(transport==kAudioDeviceTransportTypeBuiltIn),@"bufferFrames":@(current),@"sampleRate":@(nominal),@"minimumBufferFrames":@(range.mMinimum),@"maximumBufferFrames":@(range.mMaximum)};
            puts([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:info options:0 error:nil] encoding:NSUTF8StringEncoding].UTF8String);
            return 0;
        }
        if(argc<3) return 2;
        if(nominal!=48000) {std::fprintf(stderr,"This native timing protocol requires an existing 48 kHz output. No rate was changed.\n");return 2;}
        double seconds=std::stod(argv[2]);if(seconds<1 || seconds>600) return 2;
        UInt32 requested=argc>=4 ? std::stoul(argv[3]) : 0;
        bool dense=argc>=5 && std::string(argv[4])=="dense";
        if(argc>=5 && !dense)return 2;
        bool performanceFX=false, recording=false;
        bool profiling=false, keylock=true, vmCounters=false, locked=false, latencyActivity=false, silenceControl=false, lockDSP=false, lockText=false, lockCodeBacking=false;
        const int workerCount=2;
        size_t churnMiB=0;
        for(int i=5;i<argc;++i) {
            std::string option=argv[i];
            if(option=="performance-fx")performanceFX=true;
            else if(option=="recording")recording=true;
            else if(option=="profile")profiling=true;
            else if(option=="no-keylock")keylock=false;
            else if(option=="memory-churn-512")churnMiB=512;
            else if(option=="silence-control")silenceControl=true;
            else if(option=="no-vm")vmCounters=false;
            else if(option=="vm")vmCounters=true;
            else if(option=="lock-pcm")locked=true;
            else if(option=="lock-dsp")lockDSP=true;
            else if(option=="lock-text")lockText=true;
            else if(option=="lock-code-backing")lockCodeBacking=true;
            else if(option=="latency-activity")latencyActivity=true;
            else if(option=="no-activity")latencyActivity=false;
            else return 2;
        }
        if(churnMiB*1024*1024>NSProcessInfo.processInfo.physicalMemory/16)return 2;
        allocationProfiling.store(profiling,std::memory_order_relaxed);
        if([deviceName localizedCaseInsensitiveContainsString:@"iPad"]) {std::fprintf(stderr,"Refusing an iPad output route.\n");return 2;}
        if(requested && (requested<range.mMinimum || requested>range.mMaximum))return 2;
        std::signal(SIGINT,stopSignal);std::signal(SIGTERM,stopSignal);
        BufferRequest bufferRequest;
        const double rate=48000;
        std::vector<float> samples(48000*64*2);
        uint32_t noiseState=0x54444a31;
        auto noise=[&]() {noiseState^=noiseState<<13;noiseState^=noiseState>>17;noiseState^=noiseState<<5;return double(noiseState)/4294967295.0*2-1;};
        for(size_t i=0;i<samples.size()/2;++i) {
            samples[i*2]=0.2*std::sin(2*3.141592653589793*440*i/rate);
            samples[i*2+1]=0.2*std::sin(2*3.141592653589793*660*i/rate);
            if(dense) {
                double t=i/rate,beat=std::fmod(t*2,1),hat=std::fmod(t*8,1);
                double kick=0.12*std::exp(-beat*18)*std::sin(2*3.141592653589793*55*t);
                for(int channel=0;channel<2;++channel) {
                    double n=noise(),value=kick+(0.045+0.08*std::exp(-hat*35))*n;
                    for(int harmonic=1;harmonic<=12;++harmonic)
                        value+=0.025/std::sqrt(harmonic)*std::sin(2*3.141592653589793*(channel?277.182631:220)*harmonic*t+channel*0.2*harmonic);
                    samples[i*2+channel]=float(value);
                }
            }
        }
        char assetPath[]=".cache/keylock-native/source-XXXXXX";
        int assetFD=mkstemp(assetPath);if(assetFD<0)return 2;
        struct FileCleanup {const char *path;~FileCleanup(){unlink(path);}} fileCleanup{assetPath};
        const char *bytes=reinterpret_cast<const char *>(samples.data());size_t remaining=samples.size()*sizeof(float);
        while(remaining) {
            ssize_t count=write(assetFD,bytes,remaining);
            if(count<0 && errno==EINTR)continue;
            if(count<=0) {close(assetFD);unlink(assetPath);return 2;}
            remaining-=size_t(count);bytes+=count;
        }
        close(assetFD);
        void *lockedMapping=MAP_FAILED;int lockStatus=0,lockError=0;
        const size_t pcmBytes=samples.size()*sizeof(float);
        if(locked) {
            int fd=open(assetPath,O_RDONLY);
            if(fd>=0) {lockedMapping=mmap(nullptr,pcmBytes,PROT_READ,MAP_SHARED,fd,0);close(fd);}
            if(lockedMapping==MAP_FAILED) {lockStatus=-1;lockError=errno;}
            else {lockStatus=mlock(lockedMapping,pcmBytes);if(lockStatus)lockError=errno;}
        }
        struct LockedCleanup {void *mapping;size_t size;~LockedCleanup(){if(mapping!=MAP_FAILED){munlock(mapping,size);munmap(mapping,size);}}} lockedCleanup{lockedMapping,pcmBytes};
        tdj_asset *asset=tdj_asset_map(assetPath,48000*64,rate);
        std::vector<float>().swap(samples);
        captureDSPAllocations.store(lockDSP,std::memory_order_relaxed);
        tdj_engine *core=tdj_engine_create(rate,0.5);
        captureDSPAllocations.store(false,std::memory_order_relaxed);
        if(!asset || !core) return 2;
        DiagnosticResidency residency;
        if(lockDSP)residency.addDSP(core);
        if(lockText)residency.addText();
        if(lockCodeBacking)residency.addCodeBacking();
        if((lockDSP || lockText || lockCodeBacking) && !residency.lock()) {
            std::fprintf(stderr,"Diagnostic residency preparation failed: %d\n",residency.error);
            tdj_engine_destroy(core);tdj_asset_destroy(asset);return 2;
        }
        for(int deck=0;deck<2;++deck) {
            tdj_command c{};c.id=++commandID;c.kind=TDJ_LOAD;c.deck=deck;c.generation=deck+1;c.value2=120;c.flag=keylock?9:1;c.asset=asset;
            tdj_submit(core,c);
        }
        command(core,TDJ_TEMPO,0,129);command(core,TDJ_PLAY,0);
        Telemetry stats;Telemetry *telemetry=&stats;
        mach_timebase_info_data_t timebase{};mach_timebase_info(&timebase);
        const double tickNS=double(timebase.numer)/timebase.denom;
        AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:rate channels:2];
        NativeRecordingProbe capture;
        if(recording && !capture.open(std::string(argv[1])+".aiff",rate)) {fprintf(stderr,"Recording setup failed: %d\n",capture.status);return 2;}
        tdj_recording *recordingRing=capture.ring;
        AVAudioSourceNode *source=[[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent,const AudioTimeStamp *timestamp,AVAudioFrameCount count,AudioBufferList *buffers) {
            const uint64_t arrival=mach_absolute_time();
            if(telemetry->callbackBusy.test_and_set(std::memory_order_acquire)) {
                telemetry->overlappingCallbacks.fetch_add(1,std::memory_order_relaxed);
                for(UInt32 i=0;i<buffers->mNumberBuffers;++i)if(buffers->mBuffers[i].mData)memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);
                *silent=NO;return noErr;
            }
            if(buffers->mNumberBuffers!=2 || !buffers->mBuffers[0].mData || !buffers->mBuffers[1].mData || buffers->mBuffers[0].mDataByteSize<count*sizeof(float) || buffers->mBuffers[1].mDataByteSize<count*sizeof(float)) {
                telemetry->badBuffers.fetch_add(1,std::memory_order_relaxed);
                for(UInt32 i=0;i<buffers->mNumberBuffers;++i) if(buffers->mBuffers[i].mData) memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);
                telemetry->callbackBusy.clear(std::memory_order_release);*silent=NO;return noErr;
            }
            if(profiling && !telemetry->policyCaptured) {
                mach_msg_type_number_t size=THREAD_TIME_CONSTRAINT_POLICY_COUNT;boolean_t defaults=FALSE;
                telemetry->policyStatus=thread_policy_get(pthread_mach_thread_np(pthread_self()),THREAD_TIME_CONSTRAINT_POLICY,reinterpret_cast<thread_policy_t>(&telemetry->timePolicy),&size,&defaults);
                telemetry->policyDefault=defaults;telemetry->policyCaptured=true;
            }
            float *left=(float *)buffers->mBuffers[0].mData,*right=(float *)buffers->mBuffers[1].mData;
            uint64_t begin=mach_absolute_time();
            uint64_t cpu=profiling?cpuNS():0;
            uint64_t beforeProbe=mach_absolute_time()-begin;
            uint64_t allocationsBefore=0;
            if(profiling) {inRender=true;allocationsBefore=renderAllocations;}
            const uint64_t renderBegin=mach_absolute_time();
            bool ok=true;
            if(silenceControl) {memset(left,0,count*sizeof(float));memset(right,0,count*sizeof(float));}
            else ok=tdj_render(core,count,left,right);
            if(recordingRing)tdj_recording_push(recordingRing,count,left,right);
            const uint64_t renderEnd=mach_absolute_time();
            if(profiling) {inRender=false;telemetry->allocations.fetch_add(renderAllocations-allocationsBefore,std::memory_order_relaxed);}
            tdj_snapshot state{};
            if(silenceControl) {state.output_frame=telemetry->frames.load(std::memory_order_relaxed)+count;state.master_bpm=120;}
            else tdj_read_snapshot(core,&state);
            bool launched=false, timestampGap=false;
            // Independent integer clock reference for this integer-BPM replay.
            uint64_t bpm=uint64_t(state.master_bpm),denominator=48000*60;
            if(state.output_frame!=telemetry->frames.load(std::memory_order_relaxed)+count)telemetry->frameSequenceErrors.fetch_add(1,std::memory_order_relaxed);
            for(int deck=0;!silenceControl && deck<2;++deck) {
                auto d=deck ? state.b : state.a;
                uint64_t held=telemetry->heldSource[deck].load(std::memory_order_acquire);
                if(d.state==TDJ_QUEUED && d.source_frame!=held)telemetry->pendingErrors.fetch_add(1,std::memory_order_relaxed);
                bool newStart=d.last_start_frame!=telemetry->lastStart[deck];
                uint64_t expected=UINT64_MAX;
                if(d.state==TDJ_QUEUED || newStart) {
                    uint64_t target=uint64_t(d.target_beat)*denominator;
                    expected=retimedStart(state.output_frame-count,telemetry->referenceTicks,target,bpm,telemetry->expectedLaunch[deck]);
                    telemetry->expectedLaunch[deck]=expected;
                    if(d.state==TDJ_QUEUED && expected<state.output_frame) {
                        telemetry->scheduleErrors.fetch_add(1,std::memory_order_relaxed);
                        telemetry->event({state.output_frame-count,count,telemetry->referenceTicks,bpm,uint64_t(d.target_beat),expected,d.last_start_frame,begin,timestamp->mSampleTime,telemetry->nextSampleTime,state.master_beat,3,deck});
                    }
                } else telemetry->expectedLaunch[deck]=UINT64_MAX;
                if(newStart) {
                    if(d.last_start_frame!=expected) {
                        telemetry->scheduleErrors.fetch_add(1,std::memory_order_relaxed);
                        telemetry->event({state.output_frame-count,count,telemetry->referenceTicks,bpm,uint64_t(d.target_beat),expected,d.last_start_frame,begin,timestamp->mSampleTime,telemetry->nextSampleTime,state.master_beat,1,deck});
                    }
                    double expectedPosition=held+(state.output_frame-d.last_start_frame)*bpm/120.0;
                    if(std::abs(d.source_frame-expectedPosition)>0.001)telemetry->sourceErrors.fetch_add(1,std::memory_order_relaxed);
                    telemetry->lastStart[deck]=d.last_start_frame;telemetry->checkedStarts.fetch_add(1,std::memory_order_relaxed);launched=true;
                    telemetry->expectedLaunch[deck]=UINT64_MAX;
                }
            }
            telemetry->referenceTicks+=uint64_t(count)*bpm;
            if(!(timestamp->mFlags&kAudioTimeStampHostTimeValid))telemetry->invalidHostTimestamps.fetch_add(1,std::memory_order_relaxed);
            if(timestamp->mFlags&kAudioTimeStampSampleTimeValid) {
                if(telemetry->haveTimestamp && timestamp->mSampleTime!=telemetry->nextSampleTime) {
                    timestampGap=true;
                    telemetry->timestampGaps.fetch_add(1,std::memory_order_relaxed);
                    telemetry->event({state.output_frame-count,count,telemetry->referenceTicks-uint64_t(count)*bpm,bpm,0,0,0,begin,timestamp->mSampleTime,telemetry->nextSampleTime,state.master_beat,2,-1});
                }
                telemetry->nextSampleTime=timestamp->mSampleTime+count;telemetry->haveTimestamp=true;
            } else telemetry->invalidSampleTimestamps.fetch_add(1,std::memory_order_relaxed);
            uint64_t bad=0;
            for(uint32_t i=0;i<count;++i) if(!std::isfinite(left[i]) || !std::isfinite(right[i])) ++bad;
            // Run the complete playback DSP, then deliver silence to this client.
            // System volume, sample rate and output routing stay unchanged.
            memset(left,0,count*sizeof(float));memset(right,0,count*sizeof(float));
            uint64_t afterProbeBegin=mach_absolute_time();
            uint64_t elapsedCPU=profiling?cpuNS()-cpu:0;
            uint64_t afterProbe=mach_absolute_time()-afterProbeBegin;
            uint64_t elapsedWall=uint64_t((mach_absolute_time()-begin)*tickNS);
            uint64_t budget=uint64_t(count*1000000000.0/rate);
            maximum(telemetry->maxWallNS,elapsedWall);maximum(telemetry->maxCPUNS,elapsedCPU);
            if(elapsedWall>budget) telemetry->wallOverruns.fetch_add(1,std::memory_order_relaxed);
            if(elapsedCPU>budget) telemetry->cpuOverruns.fetch_add(1,std::memory_order_relaxed);
            ++telemetry->histogram[std::min<uint64_t>(127,elapsedWall/25000)];
            if(elapsedWall>budget && telemetry->recordedOverruns<telemetry->overruns.size())
                telemetry->overruns[telemetry->recordedOverruns++]={state.output_frame-count,elapsedWall,elapsedCPU,uint64_t((renderEnd-renderBegin)*tickNS),uint64_t(beforeProbe*tickNS),uint64_t(afterProbe*tickNS),launched};
            if(!ok) telemetry->badBuffers.fetch_add(1,std::memory_order_relaxed);
            if(bad) telemetry->nonfinite.fetch_add(bad,std::memory_order_relaxed);
            telemetry->calls.fetch_add(1,std::memory_order_relaxed);telemetry->frames.fetch_add(count,std::memory_order_relaxed);
            maximum(telemetry->maximumFrames,count);
            if(count<telemetry->minimumFrames.load(std::memory_order_relaxed)) telemetry->minimumFrames.store(count,std::memory_order_relaxed);
            Telemetry::Cycle cycle{state.output_frame-count,count,arrival,mach_absolute_time(),timestamp->mHostTime,
                telemetry->lastGraphBegin.load(std::memory_order_relaxed),telemetry->lastGraphEnd.load(std::memory_order_acquire),renderEnd,timestamp->mFlags,renderBegin,beforeProbe,afterProbe,
                timestamp->mSampleTime,telemetry->lastGraphSample.load(std::memory_order_relaxed)};
            size_t traceIndex=SIZE_MAX;
            if(timestampGap && telemetry->recordedTraces<telemetry->traces.size()) {
                traceIndex=telemetry->recordedTraces++;
                auto &trace=telemetry->traces[traceIndex];trace.gap=cycle;
                for(size_t i=0;i<telemetry->recent.size();++i)trace.before[i]=telemetry->recent[(telemetry->recentCount+i)%telemetry->recent.size()];
            }
            cycle.end=mach_absolute_time();
            if(traceIndex!=SIZE_MAX)telemetry->traces[traceIndex].gap.end=cycle.end;
            telemetry->recent[telemetry->recentCount++%telemetry->recent.size()]=cycle;
            uint64_t full=uint64_t((cycle.end-arrival)*tickNS);
            maximum(telemetry->maxFullSourceNS,full);
            if(full>budget)telemetry->fullSourceOverruns.fetch_add(1,std::memory_order_relaxed);
            telemetry->callbackBusy.clear(std::memory_order_release);*silent=NO;return noErr;
        }];
        if(!bufferRequest.request(device,requested)) {
            std::fprintf(stderr,"Requested native buffer unavailable (%d, observed %u).\n",bufferRequest.requestStatus,bufferRequest.observed);
            tdj_engine_destroy(core);tdj_asset_destroy(asset);return 2;
        }
        // Construct the graph against the selected size, after the device change.
        engine=[[AVAudioEngine alloc] init];
        if(engine.outputNode.AUAudioUnit.deviceID!=device) {
            std::fprintf(stderr,"Default output changed during test setup.\n");tdj_engine_destroy(core);tdj_asset_destroy(asset);return 2;
        }
        [engine attachNode:source];[engine connect:source to:engine.mainMixerNode format:format];
        AudioObjectPropertyAddress overloadAddress{kAudioDeviceProcessorOverload,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
        OSStatus listenerStatus=AudioObjectAddPropertyListener(device,&overloadAddress,overloadListener,&stats);
        if(listenerStatus) {std::fprintf(stderr,"Core Audio overload monitoring unavailable: %d\n",listenerStatus);tdj_engine_destroy(core);tdj_asset_destroy(asset);return 2;}
        AUAudioUnit *observedUnit=engine.mainMixerNode.AUAudioUnit;
        NSInteger observerToken=[observedUnit tokenByAddingRenderObserver:^(AudioUnitRenderActionFlags flags,const AudioTimeStamp *timestamp,AUAudioFrameCount count,NSInteger bus) {
            uint64_t tick=mach_absolute_time();
            if(flags&kAudioUnitRenderAction_PreRender)telemetry->graphBegin.store(tick,std::memory_order_relaxed);
            if(flags&kAudioUnitRenderAction_PostRender) {
                uint64_t begin=telemetry->graphBegin.load(std::memory_order_relaxed);
                telemetry->lastGraphBegin.store(begin,std::memory_order_relaxed);
                telemetry->lastGraphSample.store(timestamp->mSampleTime,std::memory_order_relaxed);
                telemetry->lastGraphEnd.store(tick,std::memory_order_release);
                telemetry->graphCalls.fetch_add(1,std::memory_order_relaxed);
                uint64_t wall=uint64_t((tick-begin)*tickNS);
                maximum(telemetry->maxGraphNS,wall);
                if(wall>uint64_t(count*1000000000.0/rate))telemetry->graphOverruns.fetch_add(1,std::memory_order_relaxed);
            }
        }];
        id<NSObject> activity=latencyActivity ? [NSProcessInfo.processInfo beginActivityWithOptions:(NSActivityUserInitiatedAllowingIdleSystemSleep|NSActivityLatencyCritical) reason:@"Native 128-frame DJ audio diagnosis"] : nil;
        NSError *error=nil;
        if(![engine startAndReturnError:&error]) {
            std::fprintf(stderr,"Mac audio start failed: %s\n",error.description.UTF8String);
            AudioObjectRemovePropertyListener(device,&overloadAddress,overloadListener,&stats);
            tdj_engine_destroy(core);tdj_asset_destroy(asset);return 2;
        }
        std::atomic<bool> pressureStop{false};std::vector<std::thread> workers;
        std::atomic<uint64_t> churnCycles{0},churnErrors{0};
        for(int worker=0;worker<workerCount;++worker) workers.emplace_back([&pressureStop,worker]{
            std::vector<double> memory(2097152,0.01*(worker+1));double sum=1;
            while(!pressureStop.load(std::memory_order_relaxed)) {
                for(size_t i=0;i<memory.size();i+=8) {sum=std::sin(sum+memory[i])+1;memory[i]=sum;}
                std::atomic_signal_fence(std::memory_order_seq_cst);
            }
        });
        if(churnMiB)workers.emplace_back([&]{
            while(!pressureStop.load(std::memory_order_relaxed)) {
                try {
                    std::vector<uint64_t> memory(churnMiB*1024*1024/sizeof(uint64_t),0x54444a31);
                    uint64_t sum=0;
                    volatile uint64_t *touch=memory.data();
                    for(size_t i=0;i<memory.size();i+=512) {touch[i]=touch[i]+i;sum^=touch[i];}
                    std::atomic_signal_fence(std::memory_order_seq_cst);
                    if(sum==UINT64_MAX)churnErrors.fetch_add(1);
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                } catch(...) {churnErrors.fetch_add(1);return;}
                churnCycles.fetch_add(1,std::memory_order_relaxed);
                std::this_thread::sleep_for(std::chrono::milliseconds(900));
            }
        });
        struct VMSample {uint64_t tick;int32_t faults,pageins,cow;};
        std::vector<VMSample> vmSamples;vmSamples.reserve(size_t(seconds*100)+256);
        int vmQueryErrors=0;
        auto start=std::chrono::steady_clock::now();uint64_t lastLaunch=0,starts=0,ackErrors=0,queueErrors=0;
        int lastStarted=0,cycle=0;bool pending=false;
        double nextProgress=30,nextStopCheck=1;
        const std::string stopPath=std::string(argv[1])+".stop";
        while(!stopRequested && !churnErrors.load() && std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()<seconds) {
            tdj_snapshot snapshot{};tdj_read_snapshot(core,&snapshot);
            // Sample process VM counters on the producer, never on the audio thread.
            task_events_info_data_t vm{};mach_msg_type_number_t vmSize=TASK_EVENTS_INFO_COUNT;
            if(vmCounters && task_info(mach_task_self(),TASK_EVENTS_INFO,reinterpret_cast<task_info_t>(&vm),&vmSize)==KERN_SUCCESS)
                vmSamples.push_back({mach_absolute_time(),vm.faults,vm.pageins,vm.cow_faults});
            else if(vmCounters) ++vmQueryErrors;
            int bpm=96+cycle%61;
            if(!silenceControl && !command(core,TDJ_TEMPO,0,bpm)) ++queueErrors;
            if(performanceFX && !silenceControl) {
                double x=0.5+0.48*std::sin(cycle*0.07);
                for(int deck=0;deck<2;deck++) {
                    if(!command(core,TDJ_MIXER,deck,x*2-1,TDJ_MIX_FILTER_X))++queueErrors;
                    if(!command(core,TDJ_MIXER,deck,0.9,TDJ_MIX_FILTER_Y))++queueErrors;
                    if(!command(core,TDJ_MIXER,deck,1,TDJ_MIX_FILTER_ENABLED))++queueErrors;
                    for(int slot=0;slot<3;slot++) {
                        tdj_command fx{};fx.kind=TDJ_FX;fx.id=++commandID;fx.deck=deck;
                        fx.flag=((cycle/120+slot)%TDJ_EFFECT_COUNT)|(slot<<8);fx.value=x;fx.value2=0.5;fx.value3=1;
                        if(!tdj_submit(core,fx))++queueErrors;
                    }
                }
            }
            if(!silenceControl && !pending && (starts==0 ? snapshot.output_frame>24000 : snapshot.output_frame-lastLaunch>96000)) {
                int next=1-lastStarted;
                if(starts>0) {
                    uint64_t position=((starts*7)%48)*48000;
                    stats.heldSource[next].store(position,std::memory_order_release);
                    if(!command(core,TDJ_PLAY,next))++queueErrors;if(!command(core,TDJ_SEEK,next,double(position)))++queueErrors;
                }
                if(!command(core,TDJ_PLAY,next))++queueErrors;pending=true;
            }
            if(pending) {
                int next=1-lastStarted;
                auto deck=next ? snapshot.b : snapshot.a;
                if(deck.state==TDJ_PLAYING && deck.last_start_frame>lastLaunch) {
                    lastLaunch=deck.last_start_frame;lastStarted=next;++starts;pending=false;
                }
            }
            tdj_message ack{};while(tdj_read_message(core,&ack))if(ack.status!=TDJ_OK && ack.status!=TDJ_RETIRED)++ackErrors;
            ++cycle;std::this_thread::sleep_for(std::chrono::milliseconds(16));
            double elapsed=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
            if(elapsed>=nextStopCheck) {
                if(access(stopPath.c_str(),F_OK)==0)stopRequested=1;
                nextStopCheck=elapsed+1;
            }
            if(elapsed>=nextProgress) {std::printf("native %.0fs: %llu callbacks, %llu checked starts, %llu wall overruns, %llu clock errors, %llu timestamp gaps, %llu HAL overloads; CPU profiling %s\n",elapsed,stats.calls.load(),stats.checkedStarts.load(),stats.wallOverruns.load(),stats.scheduleErrors.load(),stats.timestampGaps.load(),stats.overloadNotifications.load(),profiling?"on":"off");std::fflush(stdout);nextProgress+=30;}
        }
        [engine stop];
        if(recording)capture.finish();if(activity)[NSProcessInfo.processInfo endActivity:activity];[observedUnit removeRenderObserver:observerToken];[engine detachNode:source];
        if(!listenerStatus)AudioObjectRemovePropertyListener(device,&overloadAddress,overloadListener,&stats);
        pressureStop.store(true);for(auto &worker:workers)worker.join();
        bool bufferRestored=bufferRequest.restore();
        std::ofstream vmOut(std::string(argv[1])+".vm.csv");vmOut << "hostTick,faults,pageins,cowFaults\n";
        for(auto v:vmSamples)vmOut << v.tick << ',' << v.faults << ',' << v.pageins << ',' << v.cow << '\n';
        auto percentileUpperUS=[&](uint64_t numerator) {
            uint64_t accumulated=0,threshold=(stats.calls.load()*numerator+99)/100;
            for(size_t i=0;i<127;++i) {accumulated+=stats.histogram[i];if(accumulated>=threshold)return double(i+1)*25;}
            return stats.maxWallNS.load()/1000.0;
        };
        NSData *nameJSON=[NSJSONSerialization dataWithJSONObject:deviceName options:NSJSONWritingFragmentsAllowed error:nil];
        std::string encodedName([[NSString alloc] initWithData:nameJSON encoding:NSUTF8StringEncoding].UTF8String);
        std::ofstream out(argv[1]);out << std::setprecision(12);
        out << "{\"format\":\"generik-dj.native-audio-stress/v6\",\"backgroundCPUAndMemoryWorkers\":" << workerCount << ",\"performanceFXEnabled\":" << (performanceFX?"true":"false") << ",\"diagnosticDSPLockRequested\":" << (lockDSP?"true":"false") << ",\"diagnosticCodeBackingLockRequested\":" << (lockCodeBacking?"true":"false") << ",\"diagnosticCodeBackingBytes\":" << residency.codeBackingBytes << ",\"diagnosticTextLockRequested\":" << (lockText?"true":"false") << ",\"diagnosticResidencyErrno\":" << residency.error << ",\"diagnosticResidentBytes\":" << residency.lockedPages*residency.page << ",\"diagnosticLiveDSPBytes\":" << residency.liveBytes << ",\"diagnosticLiveDSPAllocations\":" << residency.liveAllocations << ",\"memoryChurnMiB\":" << churnMiB << ",\"memoryChurnCycles\":" << churnCycles.load() << ",\"memoryChurnErrors\":" << churnErrors.load() << ",\"diagnosticPCMLockRequested\":" << (locked?"true":"false") << ",\"diagnosticPCMLockStatus\":" << lockStatus << ",\"diagnosticPCMLockErrno\":" << lockError << ",\"latencyCriticalActivity\":" << (latencyActivity?"true":"false") << ",\"silenceOnlyHardwareControl\":" << (silenceControl?"true":"false") << ",\"transportChecksExecuted\":" << (silenceControl?"false":"true") << ",\"keylockEnabled\":" << (keylock?"true":"false") << ",\"VMCountersEnabled\":" << (vmCounters?"true":"false") << ",\"requestedWallSeconds\":" << seconds << ",\"nativeProcessPID\":" << getpid()
            << ",\"actualWallSeconds\":" << std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()
            << ",\"sampleRate\":48000,\"callbacks\":" << stats.calls.load() << ",\"renderedFrames\":" << stats.frames.load()
            << ",\"signal\":\"" << (dense?"Dense stereo harmonics, kick, noise hats and continuous broadband noise; seed 0x54444a31":"440 Hz left / 660 Hz right tones") << "\""
            << ",\"minimumCallbackFrames\":" << stats.minimumFrames.load() << ",\"maximumCallbackFrames\":" << stats.maximumFrames.load()
            << ",\"callbackProfilingEnabled\":" << (profiling?"true":"false")
            << ",\"maximumWallMicroseconds\":" << stats.maxWallNS.load()/1000.0 << ",\"maximumThreadCPUMicroseconds\":";
        if(profiling)out << stats.maxCPUNS.load()/1000.0;else out << "null";
        out << ",\"wallDeadlineOverruns\":" << stats.wallOverruns.load() << ",\"cpuDeadlineOverruns\":";
        if(profiling)out << stats.cpuOverruns.load();else out << "null";
        out
            << ",\"renderOrBufferErrors\":" << stats.badBuffers.load() << ",\"nonfiniteSamples\":" << stats.nonfinite.load()
            << ",\"queuedStarts\":" << starts << ",\"unexpectedAcknowledgements\":" << ackErrors << ",\"queueSubmissionErrors\":" << queueErrors
            << ",\"tempoCommands\":" << cycle << ",\"requestedBufferFrames\":" << requested
            << ",\"originalDeviceBufferFrames\":" << bufferRequest.original << ",\"observedDeviceBufferFrames\":" << bufferRequest.observed
            << ",\"restoredDeviceBufferFrames\":" << bufferRequest.restored << ",\"bufferRestored\":" << (bufferRestored?"true":"false")
            << ",\"deviceName\":" << encodedName << ",\"deviceNominalSampleRate\":" << nominal
            << ",\"bufferSelectedBeforeGraphConstruction\":true"
            << ",\"audioThreadTimeConstraintPolicy\":{\"queryRun\":" << (profiling?"true":"false") << ",\"queryStatus\":" << stats.policyStatus << ",\"defaultPolicy\":" << (stats.policyDefault?"true":"false")
            << ",\"periodNanoseconds\":" << stats.timePolicy.period*tickNS << ",\"computationNanoseconds\":" << stats.timePolicy.computation*tickNS << ",\"constraintNanoseconds\":" << stats.timePolicy.constraint*tickNS << ",\"preemptible\":" << (stats.timePolicy.preemptible?"true":"false") << "}"
            << ",\"bufferRequestStatus\":" << bufferRequest.requestStatus << ",\"bufferRestoreStatus\":" << bufferRequest.restoreStatus
            << ",\"overloadListenerStatus\":" << listenerStatus << ",\"deviceOverloadNotifications\":" << stats.overloadNotifications.load()
            << ",\"invalidSampleTimestamps\":" << stats.invalidSampleTimestamps.load() << ",\"invalidHostTimestamps\":" << stats.invalidHostTimestamps.load() << ",\"sampleTimestampGaps\":" << stats.timestampGaps.load() << ",\"cppAllocationsDuringRender\":";
        if(profiling)out << stats.allocations.load();else out << "null";
        out
            << ",\"overlappingCallbacks\":" << stats.overlappingCallbacks.load() << ",\"frameSequenceErrors\":" << stats.frameSequenceErrors.load() << ",\"lastOverloadHostTick\":" << stats.lastOverloadHostTick.load()
            << ",\"checkedQueuedStarts\":" << stats.checkedStarts.load() << ",\"scheduleErrors\":" << stats.scheduleErrors.load()
            << ",\"sourceTimelineErrors\":" << stats.sourceErrors.load() << ",\"heldSourceErrors\":" << stats.pendingErrors.load()
            << ",\"medianWallMicrosecondsUpperBound\":" << percentileUpperUS(50) << ",\"p99WallMicrosecondsUpperBound\":" << percentileUpperUS(99)
            << ",\"interrupted\":" << (stopRequested?"true":"false") << ",\"overrunEvents\":[";
        for(size_t i=0;i<stats.recordedOverruns;++i) {
            auto e=stats.overruns[i];if(i)out << ",";
            out << "{\"frame\":" << e.frame << ",\"wallMicroseconds\":" << e.wall/1000.0 << ",\"cpuMicroseconds\":";
            if(profiling)out << e.cpu/1000.0;else out << "null";
            out << ",\"coreRenderMicroseconds\":" << e.core/1000.0 << ",\"beginCPUProbeMicroseconds\":";
            if(profiling)out << e.beforeProbe/1000.0;else out << "null";
            out << ",\"endCPUProbeMicroseconds\":";
            if(profiling)out << e.afterProbe/1000.0;else out << "null";
            out << ",\"queuedStartInCallback\":" << (e.start?"true":"false") << "}";
        }
        out << "],\"diagnosticEvents\":[";
        for(size_t i=0;i<stats.recordedEvents;++i) {
            auto e=stats.events[i];if(i)out << ",";
            out << "{\"kind\":" << e.kind << ",\"deck\":" << e.deck << ",\"frame\":" << e.frame << ",\"count\":" << e.count << ",\"referenceTicks\":" << e.ticks << ",\"bpm\":" << e.bpm << ",\"targetBeat\":" << e.target << ",\"expectedStart\":" << e.expected << ",\"actualStart\":" << e.actual << ",\"wallHostTick\":" << e.wallTick << ",\"sampleTime\":" << e.sampleTime << ",\"expectedSampleTime\":" << e.expectedSampleTime << ",\"masterBeatAfter\":" << e.masterBeat << "}";
        }
        out << "],\"graphRenderCycles\":" << stats.graphCalls.load() << ",\"maximumGraphMicroseconds\":" << stats.maxGraphNS.load()/1000.0 << ",\"graphAndSourceCycleCountsMatch\":" << (stats.graphCalls.load()==stats.calls.load()?"true":"false") << ",\"graphDeadlineOverruns\":" << stats.graphOverruns.load() << ",\"maximumFullSourceMicroseconds\":" << stats.maxFullSourceNS.load()/1000.0 << ",\"fullSourceDeadlineOverruns\":" << stats.fullSourceOverruns.load() << ",\"gapTimingTraces\":[";
        auto writeCycle=[&](const Telemetry::Cycle &c) {
            out << "{\"frame\":" << c.frame << ",\"count\":" << c.count << ",\"arrivalHostTick\":" << c.begin << ",\"endHostTick\":" << c.end << ",\"renderEndHostTick\":" << c.renderEnd << ",\"renderBeginHostTick\":" << c.renderBegin << ",\"beginCPUProbeHostTicks\":" << c.beforeProbe << ",\"endCPUProbeHostTicks\":" << c.afterProbe << ",\"timestampFlags\":" << c.flags << ",\"presentationHostTick\":" << c.host << ",\"sampleTime\":" << c.sampleTime << ",\"previousGraphBegin\":" << c.graphBegin << ",\"previousGraphEnd\":" << c.graphEnd << ",\"previousGraphSampleTime\":" << c.graphSample << "}";
        };
        for(size_t i=0;i<stats.recordedTraces;++i) {
            if(i)out << ",";out << "{\"before\":[";
            for(size_t j=0;j<stats.traces[i].before.size();++j) {if(j)out << ",";writeCycle(stats.traces[i].before[j]);}
            out << "],\"gap\":";writeCycle(stats.traces[i].gap);out << "}";
        }
        out << "],\"recordingEnabled\":" << (recording?"true":"false") << ",\"recordedFrames\":" << capture.frames << ",\"recordingFileFrames\":" << capture.fileFrames << ",\"recordingDroppedFrames\":" << (recording?tdj_recording_dropped(capture.ring):0) << ",\"recordingStatus\":" << capture.status << ",\"recordingNonfiniteSamples\":" << capture.nonfinite << ",\"recordingPeak\":" << capture.peak << ",\"VMQueryErrors\":" << vmQueryErrors << ",\"VMCounterSamples\":" << vmSamples.size() << ",\"hostTickNanoseconds\":" << tickNS
            << ",\"sourceStorage\":\"" << "Read-only MAP_PRIVATE synthetic Float32 file, retained for asset lifetime" << "\",\"sourceCuePositions\":\"7-second steps modulo 48 seconds\",\"output\":\"" << (silenceControl?"Pure silence control; transport and Keylock not executed":"DSP rendered normally, client buffers zeroed before output") << "\",\"systemAudioBufferTemporarilyChanged\":" << (requested && bufferRequest.original!=requested?"true":"false") << ",\"iPadAccessed\":false}\n";
        vmOut.flush();out.flush();
        bool evidenceWritten=bool(vmOut)&&bool(out);
        if(!evidenceWritten)std::fprintf(stderr,"Failed to save complete native audio evidence.\n");
        tdj_engine_destroy(core);tdj_asset_destroy(asset);
        unlink(assetPath);
        return (recording && (capture.status || capture.nonfinite || tdj_recording_dropped(capture.ring) || capture.frames!=stats.frames.load() || capture.fileFrames!=SInt64(capture.frames) || capture.peak==0)) || !evidenceWritten || churnErrors.load() || stats.invalidSampleTimestamps.load() || stats.invalidHostTimestamps.load() || stats.graphCalls.load()!=stats.calls.load() || (locked && lockStatus) || stats.graphOverruns.load() || stats.fullSourceOverruns.load() || stopRequested || !bufferRestored || (requested && (stats.minimumFrames.load()!=requested || stats.maximumFrames.load()!=requested)) || !stats.calls.load() || stats.badBuffers.load() || stats.nonfinite.load() || ackErrors || queueErrors || stats.wallOverruns.load() || stats.overloadNotifications.load() || stats.timestampGaps.load() || stats.allocations.load() || stats.scheduleErrors.load() || stats.sourceErrors.load() || stats.pendingErrors.load() || stats.overlappingCallbacks.load() || stats.frameSequenceErrors.load() ? 1 : 0;
    }
}
