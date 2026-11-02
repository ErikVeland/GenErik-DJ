#if defined(__APPLE__) && !defined(TDJ_GENERIC_FFT)
#define SIGNALSMITH_USE_ACCELERATE
#endif
#include "TDJKeylock.h"
#include "Vendor/signalsmith-stretch/signalsmith-stretch.h"
#include <cmath>
#include <new>
#include <vector>
#include <array>
#include <algorithm>
#if defined(__aarch64__) || defined(__arm64__)
#include <arm_neon.h>
#endif

namespace {
constexpr int quantum = 64;

// Read the immutable source at its native pitch on the output-rate timeline.
// The same position is used for both channels, including their phase relationship.
struct Input {
    const float *samples;
    uint64_t frames;
    double start, step;
    bool midSide = false;
    double loopStart=0, loopEnd=0;
    void *context=nullptr;
    tdj_source_reader reader=nullptr;
    tdj_source_span_reader spanReader=nullptr;
    bool useSpans=false;
    mutable const float *span=nullptr;
    mutable uint64_t spanStart=0,spanEnd=0;
    void readFrame(uint64_t frame,float &left,float &right) const {
        if(useSpans && spanReader) {
            if(!span || frame<spanStart || frame>=spanEnd) {
                uint32_t count=0;
                const float *data=spanReader(context,frame,&count);
                if(data && count && count<=frames-frame) {
                    span=data;spanStart=frame;spanEnd=frame+count;
                } else span=nullptr;
            }
            if(span) {
                const uint64_t offset=(frame-spanStart)*2;
                left=span[offset];right=span[offset+1];return;
            }
        }
        reader(context,frame,&left,&right);
    }
    void stereo(int index, float &left, float &right) const {
        double position = start + index*step;
        if (loopEnd>loopStart && std::isfinite(position)) {
            double length=loopEnd-loopStart;
            double offset=std::fmod(position-loopStart,length);
            position=loopStart+(offset<0 ? offset+length : offset);
        }
        if (position < 0 || position >= frames || !std::isfinite(position)) {
            left=right=0; return;
        }
        uint64_t at=static_cast<uint64_t>(position);
        uint64_t next=at+1<frames ? at+1 : at;
        double fraction=position-at;
        if(loopEnd>loopStart && next>=loopEnd) next=static_cast<uint64_t>(loopStart);
        float al=0,ar=0,bl=0,br=0;
        if(reader) { readFrame(at,al,ar); readFrame(next,bl,br); }
        else { al=samples[at*2]; ar=samples[at*2+1]; bl=samples[next*2]; br=samples[next*2+1]; }
        if(midSide) {
            float am=0.5f*(al+ar), as=0.5f*(al-ar);
            float bm=0.5f*(bl+br), bs=0.5f*(bl-br);
            left=static_cast<float>(am+(bm-am)*fraction);
            right=static_cast<float>(as+(bs-as)*fraction);
        } else {
            left=static_cast<float>(al+(bl-al)*fraction);
            right=static_cast<float>(ar+(br-ar)*fraction);
        }
    }
    struct Channel {
        const Input &input;
        int channel;
        float operator[](int index) const {
            double position = input.start + index*input.step;
            if (input.loopEnd>input.loopStart && std::isfinite(position)) {
                double length=input.loopEnd-input.loopStart;
                double offset=std::fmod(position-input.loopStart,length);
                position=input.loopStart+(offset<0 ? offset+length : offset);
            }
            if (position < 0 || position >= input.frames || !std::isfinite(position)) return 0;
            uint64_t at = static_cast<uint64_t>(position);
            uint64_t next = at + 1 < input.frames ? at + 1 : at;
            double fraction = position - at;
            if(input.loopEnd>input.loopStart && next>=input.loopEnd)
                next=static_cast<uint64_t>(input.loopStart);
            auto sample = [&](uint64_t frame) {
                if(input.reader) {
                    float l=0,r=0;input.reader(input.context,frame,&l,&r);
                    return input.midSide ? 0.5f*(channel ? l-r:l+r):(channel ? r:l);
                }
                if (!input.midSide) return input.samples[frame*2 + channel];
                float l = input.samples[frame*2], r = input.samples[frame*2+1];
                return 0.5f*(channel ? l-r : l+r);
            };
            float a = sample(at), b = sample(next);
            return static_cast<float>(a + (b-a)*fraction);
        }
    };
    Channel operator[](int channel) const { return {*this, channel}; }
};
}

struct tdj_keylock {
    signalsmith::stretch::SignalsmithStretch<float> stretch{0};
    double outputRate, cursor = 0, remainder = 0, lastSpeed = 1;
    float output[2][quantum] = {};
    int read = quantum;
    float mix = 0, mixStep;
    bool primed = false, seen = false;
    // Copy each stereo input frame once for spectral energy and history passes.
    // Storage is fixed before output starts. DSP and sample arithmetic are unchanged.
    std::vector<float> stagedInput;
    size_t stagedCapacity=0;
    tdj_keylock_trace trace{};
    uint32_t traceDeck=0;
    std::array<const float *,2> stage(Input input,int count) {
        float *left=stagedInput.data(), *right=left+stagedCapacity;
        input.useSpans=input.spanReader!=nullptr;
#if defined(__aarch64__) || defined(__arm64__)
        uint64_t arithmeticMode;
        __asm__ volatile("mrs %0, fpcr":"=r"(arithmeticMode));
        // Vector arithmetic assumes nearest rounding. Other caller modes retain scalar arithmetic.
        const bool roundToNearest=(arithmeticMode & (3ull<<22))==0;
        const bool loop=input.loopEnd>input.loopStart;
        const bool integralLoop=!loop || (input.loopStart>=0 && input.loopEnd<=input.frames
            && input.loopStart==std::floor(input.loopStart) && input.loopEnd==std::floor(input.loopEnd));
        if(roundToNearest && input.reader && input.spanReader && input.midSide && input.step==1 && integralLoop
            && std::isfinite(input.start) && input.start==std::floor(input.start)
            && std::abs(input.start)+count<4503599627370496.0 && input.frames<4503599627370496ULL) {
            int i=0;
            while(i<count) {
                double position=input.start+i;
                if(loop) {
                    const double length=input.loopEnd-input.loopStart;
                    const double offset=std::fmod(position-input.loopStart,length);
                    position=input.loopStart+(offset<0 ? offset+length:offset);
                }
                int advanced=0;
                if(position>=0 && position<input.frames && !std::signbit(position)) {
                    const uint64_t at=static_cast<uint64_t>(position);
                    uint32_t available=0;
                    const float *data=input.spanReader(input.context,at,&available);
                    if(data && available>1 && available<=input.frames-at) {
                        uint64_t extent=std::min<uint64_t>(available-1,static_cast<uint64_t>(count-i));
                        if(loop) extent=std::min<uint64_t>(extent,static_cast<uint64_t>(input.loopEnd)-at-1);
                        for(;advanced+4<=static_cast<int>(extent);advanced+=4) {
                            auto a=vld2q_f32(data+advanced*2);
                            auto b=vld2q_f32(data+(advanced+1)*2);
                            float32x4_t maximum=vmaxq_f32(vmaxq_f32(vabsq_f32(a.val[0]),vabsq_f32(a.val[1])),
                                vmaxq_f32(vabsq_f32(b.val[0]),vabsq_f32(b.val[1])));
                            if(vminvq_u32(vcleq_f32(maximum,vdupq_n_f32(1e10f)))!=UINT32_MAX) break;
                            auto am=vmulq_n_f32(vaddq_f32(a.val[0],a.val[1]),0.5f);
                            auto as=vmulq_n_f32(vsubq_f32(a.val[0],a.val[1]),0.5f);
                            auto bm=vmulq_n_f32(vaddq_f32(b.val[0],b.val[1]),0.5f);
                            auto bs=vmulq_n_f32(vsubq_f32(b.val[0],b.val[1]),0.5f);
                            // Retain the original zero-fraction arithmetic and signed-zero behavior.
                            vst1q_f32(left+i+advanced,vaddq_f32(am,vmulq_n_f32(vsubq_f32(bm,am),0)));
                            vst1q_f32(right+i+advanced,vaddq_f32(as,vmulq_n_f32(vsubq_f32(bs,as),0)));
                        }
                    }
                }
                if(advanced) { i+=advanced;continue; }
                input.stereo(i,left[i],right[i]);++i;
            }
            return {left,right};
        }

        if(roundToNearest && count>=4 && input.reader && input.spanReader && input.midSide
            && input.step>0 && input.step<=1 && std::isfinite(input.start)
            && std::abs(input.start)+count<4503599627370496.0 && input.frames<4503599627370496ULL
            && (!loop || (input.loopStart>=0 && input.loopEnd<=input.frames))) {
            int i=0;
            while(i<count) {
                const int width=std::min(4,count-i);
                bool valid=width==4;
                uint64_t at[4]={};
                double fractions[4]={};
                for(int lane=0;valid && lane<4;++lane) {
                    double position=input.start+(i+lane)*input.step;
                    if(loop) {
                        const double length=input.loopEnd-input.loopStart;
                        const double offset=std::fmod(position-input.loopStart,length);
                        position=input.loopStart+(offset<0 ? offset+length:offset);
                    }
                    if(!(position>=0 && position<input.frames)) { valid=false;break; }
                    at[lane]=static_cast<uint64_t>(position);
                    uint64_t next=at[lane]+1<input.frames ? at[lane]+1:at[lane];
                    if(loop && next>=input.loopEnd) next=static_cast<uint64_t>(input.loopStart);
                    valid=next==at[lane]+1 && at[lane]>=at[0] && at[lane]-at[0]<=3;
                    fractions[lane]=position-at[lane];
                }
                uint32_t available=0;
                const float *data=valid ? input.spanReader(input.context,at[0],&available):nullptr;
                if(data && available>=5 && available<=input.frames-at[0]) {
                    const uint32x4_t indices={0,static_cast<uint32_t>(at[1]-at[0]),
                        static_cast<uint32_t>(at[2]-at[0]),static_cast<uint32_t>(at[3]-at[0])};
                    const auto bytes=vreinterpretq_u8_u32(vaddq_u32(vmulq_n_u32(indices,0x04040404U),
                        vdupq_n_u32(0x03020100U)));
                    auto gather=[&](float32x4_t value) {
                        return vreinterpretq_f32_u8(vqtbl1q_u8(vreinterpretq_u8_f32(value),bytes));
                    };
                    const auto a=vld2q_f32(data),b=vld2q_f32(data+2);
                    const auto al=gather(a.val[0]),ar=gather(a.val[1]);
                    const auto bl=gather(b.val[0]),br=gather(b.val[1]);
                    const auto maximum=vmaxq_f32(vmaxq_f32(vabsq_f32(al),vabsq_f32(ar)),
                        vmaxq_f32(vabsq_f32(bl),vabsq_f32(br)));
                    if(vminvq_u32(vcleq_f32(maximum,vdupq_n_f32(1e10f)))==UINT32_MAX) {
                        const auto am=vmulq_n_f32(vaddq_f32(al,ar),0.5f);
                        const auto as=vmulq_n_f32(vsubq_f32(al,ar),0.5f);
                        const auto bm=vmulq_n_f32(vaddq_f32(bl,br),0.5f);
                        const auto bs=vmulq_n_f32(vsubq_f32(bl,br),0.5f);
                        auto interpolate=[&](float32x4_t first,float32x4_t second) {
                            const auto delta=vsubq_f32(second,first);
                            const auto low=vfmaq_f64(vcvt_f64_f32(vget_low_f32(first)),
                                vcvt_f64_f32(vget_low_f32(delta)),vld1q_f64(fractions));
                            const auto high=vfmaq_f64(vcvt_f64_f32(vget_high_f32(first)),
                                vcvt_f64_f32(vget_high_f32(delta)),vld1q_f64(fractions+2));
                            return vcombine_f32(vcvt_f32_f64(low),vcvt_f32_f64(high));
                        };
                        vst1q_f32(left+i,interpolate(am,bm));
                        vst1q_f32(right+i,interpolate(as,bs));
                        i+=4;continue;
                    }
                }
                for(int lane=0;lane<width;++lane) input.stereo(i+lane,left[i+lane],right[i+lane]);
                i+=width;
            }
            return {left,right};
        }
#endif
        for(int i=0;i<count;++i) input.stereo(i,left[i],right[i]);
        return {left,right};
    }
    void process(Input input,int count,float **outputs,int outputCount,int discardedRemaining=0) {
        if(count>=0 && static_cast<size_t>(count)<=stagedCapacity) {
            if(discardedRemaining>0) stretch.processDiscarded(stage(input,count),count,outputs,outputCount,discardedRemaining);
            else stretch.process(stage(input,count),count,outputs,outputCount);
        } else {
            if(discardedRemaining>0) stretch.processDiscarded(input,count,outputs,outputCount,discardedRemaining);
            else stretch.process(input,count,outputs,outputCount);
        }
    }
    bool canDiscardCompleteIntervals(double speed) const {
        if(!std::isfinite(speed) || speed<=0 || speed>8 || outputRate<8000 || outputRate>384000) return false;
        // Reset priming starts with silenceCounter zero. Leave one extra frame
        // at the bound so rounding cannot enter silence bypass during pre-roll.
        const double maximumInput=std::ceil(speed*stretch.outputLatency())+1;
        return maximumInput<2.0*stretch.blockSamples();
    }

    explicit tdj_keylock(double rate) : outputRate(rate), mixStep(static_cast<float>(1/(rate*0.005))) {
        stretch.presetDefault(2, static_cast<float>(rate), true);
        stagedCapacity=std::max(stretch.seekLength(),quantum*8+1);
        stagedInput.resize(stagedCapacity*2);
        volatile float *pages=stagedInput.data();
        for(size_t i=0;i<stagedInput.size();i+=256) pages[i]=0;
        pages[stagedInput.size()-1]=0;
        // Exercise all spectral paths and reserve their storage before output starts.
        float silence[2][quantum] = {};
        float *pointers[2] = {silence[0], silence[1]};
        Input zeros{silence[0], 0, 0, 1};
        stretch.outputSeek(zeros, stretch.outputSeekLength(1));
        for (int i = 0; i < stretch.blockSamples()*3; i += quantum)
            stretch.process(zeros, quantum, pointers, quantum);
        // Exercise the discarded path before the processor reaches audio output.
        // Zero input at unit speed consumes no random phase draws.
        if(canDiscardCompleteIntervals(1)) {
            stretch.reset();
            stretch.seek(stage(zeros,stretch.seekLength()),stretch.seekLength(),1);
            for(int remaining=stretch.outputLatency();remaining>0;) {
                const int block=std::min(remaining,quantum);
                process(zeros,block,pointers,block,remaining);
                remaining-=block;
            }
        }
        reset();
    }
    void reset() {
        // Clear lazily on the render consumer. No source data is read here.
        primed = false; seen = false; read = quantum; remainder = 0; mix = 0;
    }
    void prime(Input input, double speed) {
        // Warm from actual cached history. outputSeek's synthetic reversed
        // pre-roll can cause large gain spikes on continuous tones after resets.
        // The discarded output ends at the requested position. The input cursor
        // and maximum lookahead remain inputLatency + speed*outputLatency.
        const auto hooks=trace;
        const bool tracing=hooks.metrics && hooks.ticks && hooks.cpu_now && hooks.record;
        tdj_keylock_prime_measurement measurement{};
        if(tracing) {
            measurement.deck=traceDeck;measurement.source_frame=input.start;measurement.speed=speed;
            const auto clockStart=hooks.ticks();
            measurement.cpu_valid=hooks.cpu_now(&measurement.cpu_began_nanoseconds);
            measurement.cpu_clock_ticks=hooks.ticks()-clockStart;
            measurement.began_ticks=hooks.ticks();
        }
        stretch.reset();
        if(tracing) measurement.reset_done_ticks=hooks.ticks();
        Input history=input;
        history.start=input.start+(stretch.inputLatency()-stretch.seekLength())*input.step;
        stretch.seek(stage(history,stretch.seekLength()),stretch.seekLength(),speed);
        if(tracing) measurement.history_done_ticks=hooks.ticks();
        cursor=input.start+stretch.inputLatency()*input.step;
        remainder=0;
        const bool discardCompleteIntervals=canDiscardCompleteIntervals(speed);
        for(int remaining=stretch.outputLatency();remaining>0;) {
            int block=std::min(remaining,quantum);
            double exact=block*speed+remainder;
            int count=static_cast<int>(std::floor(exact));remainder=exact-count;
            input.start=cursor;
            float *pointers[2]={output[0],output[1]};
            process(input,count,pointers,block,discardCompleteIntervals ? remaining:0);
            cursor+=count*input.step;remaining-=block;
        }
        lastSpeed=speed;read=quantum;primed=true;
        if(tracing) {
            measurement.preroll_done_ticks=hooks.ticks();
            const auto clockStart=hooks.ticks();
            const bool endedValid=hooks.cpu_now(&measurement.cpu_ended_nanoseconds);
            measurement.cpu_clock_ticks+=hooks.ticks()-clockStart;
            measurement.cpu_valid=measurement.cpu_valid && endedValid;
            hooks.record(hooks.metrics,&measurement);
        }
    }
    void fill(Input input, double speed) {
        input.midSide = true;
        if (!primed) prime(input, speed);
        else if (speed != lastSpeed) {
            // Keep the spectral output state while moving the input look-ahead to
            // the new rate. Musical time remains owned by the transport clock.
            cursor = input.start + (stretch.inputLatency() + speed*stretch.outputLatency())*input.step;
            Input history = input;
            history.start = cursor - stretch.seekLength()*input.step;
            stretch.seek(stage(history,stretch.seekLength()), stretch.seekLength(), speed);
            remainder = 0; lastSpeed = speed; read = quantum;
        }
        double exact = quantum*speed + remainder;
        int count = static_cast<int>(std::floor(exact));
        remainder = exact - count;
        input.start = cursor;
        float *pointers[2] = {output[0], output[1]};
        process(input,count,pointers,quantum);
        cursor += count*input.step;
        read = 0;
    }
    void sample(Input input, double speed, bool enabled, float &left, float &right) {
        // A wheel pass through native speed must not repeatedly reset the
        // spectral phase. Initial native-speed playback still bypasses exactly.
        bool target = enabled && (primed || std::abs(speed-1) > 1e-12);
        if (!seen) { mix = target ? 1 : 0; seen = true; }
        if (mix == 0 && !target) { input.stereo(0,left,right); return; }
        // Consume every generated sample. Apply the latest rate at the next
        // quantum, while the transport continues its exact source timeline.
        if (!primed || read == quantum) fill(input, speed);
        float wetL = output[0][read]+output[1][read], wetR = output[0][read]-output[1][read]; ++read;
        mix = target ? std::min(1.0f, mix+mixStep) : std::max(0.0f, mix-mixStep);
        // The source table is immutable for this callback; reuse both dry samples.
        float dryL=0,dryR=0;input.stereo(0,dryL,dryR);
        left = dryL + (wetL-dryL)*mix;
        right = dryR + (wetR-dryR)*mix;
        if (!target && mix == 0) primed = false;
    }
};

extern "C" tdj_keylock *tdj_keylock_create(double rate) {
    if (!std::isfinite(rate) || rate < 8000 || rate > 384000) return nullptr;
    try { return new tdj_keylock(rate); } catch (...) { return nullptr; }
}
extern "C" void tdj_keylock_destroy(tdj_keylock *p) { delete p; }
extern "C" void tdj_keylock_set_trace(tdj_keylock *p,const tdj_keylock_trace *trace,uint32_t deck) {
    if(!p || !trace)return;
    p->trace=*trace;p->traceDeck=deck;
}
extern "C" void tdj_keylock_reset(tdj_keylock *p) { p->reset(); }
extern "C" bool tdj_keylock_spectral(const tdj_keylock *p) { return p->mix>0; }
extern "C" bool tdj_keylock_limits(double rate,int *input,int *output,int *seek) {
    tdj_keylock *p=tdj_keylock_create(rate);if(!p)return false;
    *input=p->stretch.inputLatency();*output=p->stretch.outputLatency();*seek=p->stretch.seekLength();
    delete p;return true;
}
extern "C" void tdj_keylock_sample(tdj_keylock *p, const float *samples, uint64_t frames,
    double rate, double position, double speed, bool enabled, float *left, float *right) {
    p->sample(Input{samples, frames, position, rate/p->outputRate}, speed, enabled, *left, *right);
}

extern "C" void tdj_keylock_sample_loop(tdj_keylock *p, const float *samples, uint64_t frames,
    double rate, double position, double speed, bool enabled, double loopStart, double loopEnd,
    float *left, float *right) {
    Input input{samples,frames,position,rate/p->outputRate};
    input.loopStart=loopStart; input.loopEnd=loopEnd;
    p->sample(input,speed,enabled,*left,*right);
}
extern "C" void tdj_keylock_sample_stream(tdj_keylock *p,void *context,tdj_source_reader reader,
    uint64_t frames,double rate,double position,double speed,bool enabled,double start,double end,float *left,float *right) {
    Input input{nullptr,frames,position,rate/p->outputRate};input.context=context;input.reader=reader;
    input.loopStart=start;input.loopEnd=end;p->sample(input,speed,enabled,*left,*right);
}

extern "C" void tdj_keylock_sample_stream_spans(tdj_keylock *p,void *context,
    tdj_source_reader reader,tdj_source_span_reader spans,uint64_t frames,double rate,
    double position,double speed,bool enabled,double start,double end,float *left,float *right) {
    Input input{nullptr,frames,position,rate/p->outputRate};input.context=context;input.reader=reader;
    input.spanReader=spans;input.loopStart=start;input.loopEnd=end;
    p->sample(input,speed,enabled,*left,*right);
}
