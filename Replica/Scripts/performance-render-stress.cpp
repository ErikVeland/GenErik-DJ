extern "C" {
#include "TDJTransport.h"
}
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <thread>
#include <vector>
using Clock=std::chrono::steady_clock;
int main(int argc,char **argv) {
    if(argc!=5) { fprintf(stderr,"Usage: performance-render-stress output.json seconds paced workers\n"); return 2; }
    const char *path=argv[1]; double seconds=atof(argv[2]); bool paced=atoi(argv[3])!=0; int workers=atoi(argv[4]);
    if(seconds<=0 || seconds>14400 || workers<0 || workers>8) return 2;
    const double rate=48000; const unsigned block=128;
    std::vector<float> samples(48000*12*2);
    for(size_t frame=0;frame<samples.size()/2;frame++) {
        double t=double(frame)/rate;
        float value=float(0.03*sin(t*2*M_PI*173)+0.02*sin(t*2*M_PI*791)+0.01*sin(t*2*M_PI*2221));
        samples[2*frame]=value; samples[2*frame+1]=-value;
    }
    tdj_asset *asset=tdj_asset_create(samples.data(),samples.size()/2,rate);
    tdj_engine *engine=tdj_engine_create(rate,0.5);
    if(!asset || !engine) return 3;
    uint64_t commandID=0; unsigned rejected=0,invalidAudio=0,clockErrors=0,queueFull=0;
    auto send=[&](int kind,int deck,int flag,double value=0,double value2=0,double value3=0) {
        tdj_command c{}; c.kind=kind;c.deck=deck;c.flag=flag;c.id=++commandID;c.generation=deck+1;
        c.value=value;c.value2=value2;c.value3=value3;if(kind==TDJ_LOAD)c.asset=asset;
        if(!tdj_submit(engine,c))queueFull++;
    };
    auto drain=[&] { tdj_message message{};while(tdj_read_message(engine,&message))if(message.status!=TDJ_OK && message.status!=TDJ_RETIRED)rejected++; };
    for(int deck=0;deck<2;deck++) { send(TDJ_LOAD,deck,9,0,120,0);send(TDJ_LOOP,deck,1,48000,240000); }
    send(TDJ_TEMPO,0,0,132);send(TDJ_PLAY,0,0);send(TDJ_PLAY,1,0);
    tdj_render(engine,0,nullptr,nullptr);drain();
    std::atomic<bool> stop{false};std::atomic<uint64_t> work{0};std::vector<std::thread> load;
    for(int w=0;w<workers;w++)load.emplace_back([&] {
        std::vector<double> data(2*1024*1024,0.1);
        while(!stop.load(std::memory_order_relaxed)) {
            for(size_t i=1;i<data.size();i++)data[i]=fmod(data[i]+data[i-1]*1.00000001,1.0);
            work.fetch_add(1,std::memory_order_relaxed);
        }
    });
    unsigned long blocks=(unsigned long)ceil(seconds*rate/block);
    std::vector<double> timings;timings.reserve(blocks);
    float left[block],right[block],cueL[block],cueR[block];
    auto started=Clock::now();unsigned overruns=0;double peak=0;
    for(unsigned long n=0;n<blocks;n++) {
        tdj_snapshot state{};tdj_read_snapshot(engine,&state);
        if(n%6==0) {
            double x=0.5+0.49*sin(n*0.019);
            send(TDJ_TEMPO,0,0,120+35*sin(n*0.003));
            for(int deck=0;deck<2;deck++) {
                send(TDJ_MIXER,deck,TDJ_MIX_FILTER_X,2*x-1);
                send(TDJ_MIXER,deck,TDJ_MIX_FILTER_Y,0.95);
                send(TDJ_MIXER,deck,TDJ_MIX_FILTER_ENABLED,1);
                for(int slot=0;slot<3;slot++)send(TDJ_FX,deck,(((n/600+slot)%TDJ_EFFECT_COUNT)|(slot<<8)),x,0.5,1);
                const auto &d=deck==0?state.a:state.b;
                if(n%60==0 && d.state==TDJ_PLAYING)send(TDJ_LOOP,deck,1,48000+(n/60%4)*12000,240000+(n/60%4)*12000);
            }
        }
        auto before=Clock::now();
        if(!tdj_render_buses(engine,block,left,right,cueL,cueR))clockErrors++;
        double elapsed=std::chrono::duration<double>(Clock::now()-before).count();
        timings.push_back(elapsed);if(elapsed>block/rate)overruns++;
        drain();tdj_read_snapshot(engine,&state);
        if(state.output_frame!=(n+1)*block)clockErrors++;
        for(unsigned f=0;f<block;f++) {
            if(!std::isfinite(left[f]) || !std::isfinite(right[f]))invalidAudio++;
            peak=std::max(peak,std::max(std::abs(double(left[f])),std::abs(double(right[f]))));
        }
        if(paced)std::this_thread::sleep_until(started+std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>((n+1)*block/rate)));
    }
    double wall=std::chrono::duration<double>(Clock::now()-started).count();
    stop.store(true);for(auto &thread:load)thread.join();
    std::sort(timings.begin(),timings.end());
    bool passed=!rejected&&!invalidAudio&&!clockErrors&&!queueFull&&!overruns;
    std::ofstream output(path);output.precision(12);
    output<<"{\n\"scope\":\"C renderer; two keylocked looping decks, six FX, rapid FX/tempo/filter/loop controls; not hardware or iPad UI\",\n";
    output<<"\"passed\":"<<(passed?"true":"false")<<",\n\"paced\":"<<(paced?"true":"false")<<",\n\"workers\":"<<workers<<",\n\"workerPasses\":"<<work.load()<<",\n";
    output<<"\"musicalSeconds\":"<<blocks*block/rate<<",\n\"wallSeconds\":"<<wall<<",\n\"blocks\":"<<blocks<<",\n\"commands\":"<<commandID<<",\n";
    output<<"\"effectCatalogCount\":"<<TDJ_EFFECT_COUNT<<",\n\"bufferFrames\":128,\n\"sampleRate\":48000,\n\"deadlineMilliseconds\":"<<block/rate*1000<<",\n";
    output<<"\"p50Milliseconds\":"<<timings[timings.size()/2]*1000<<",\n\"p99Milliseconds\":"<<timings[(timings.size()-1)*99/100]*1000<<",\n";
    output<<"\"maxMilliseconds\":"<<timings.back()*1000<<",\n\"deadlineOverruns\":"<<overruns<<",\n\"rejectedCommands\":"<<rejected<<",\n\"queueFull\":"<<queueFull<<",\n\"invalidAudioSamples\":"<<invalidAudio<<",\n\"clockErrors\":"<<clockErrors<<",\n\"peak\":"<<peak<<"\n}\n";
    output.close();bool saved=bool(output);
    tdj_engine_destroy(engine);tdj_asset_destroy(asset);
    return !saved?4:passed?0:1;
}
