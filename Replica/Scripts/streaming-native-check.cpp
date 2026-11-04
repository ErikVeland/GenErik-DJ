#include "TDJTransport.h"
extern "C" {
#include "../Sources/CTDJTransport/TDJAsset.h"
}
#include <set>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <unistd.h>
#include <thread>
#include <chrono>
#include <atomic>

static uint64_t serial=1;
static int command(tdj_engine *e,tdj_command c) {
    c.id=serial++;assert(tdj_submit(e,c));assert(tdj_render(e,0,nullptr,nullptr));
    tdj_message m{};int result=-100;
    while(tdj_read_message(e,&m))if(m.command_id==c.id)result=m.status;
    assert(result!=-100);return result;
}
static tdj_command action(int kind,int deck=0,uint64_t generation=1) {
    tdj_command c{};c.kind=kind;c.deck=deck;c.generation=generation;return c;
}
static uint64_t prepare(tdj_asset *a,tdj_engine *engine,double frame,uint64_t generation=1,
    double speed=1,bool keylock=false,double loopStart=0,double loopEnd=0,double continuing=-1,double rate=1) {
    tdj_stream_target t{};t.position=frame;t.source_speed=speed;t.performance_rate=rate;
    t.keylock=keylock;t.loop_start=loopStart;t.loop_end=loopEnd;
    t.continuing_position=continuing<0 ? frame:continuing;t.reserve_continuing=continuing>=0;
    tdj_stream_request r{};assert(tdj_asset_plan_target(a,&t,serial++,generation,&r)==TDJ_STREAM_READY);
    uint64_t ticket=tdj_asset_request_prepare(a,&r);assert(ticket);
    for(int n=0;n<1000 && tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_PENDING;n++) {
        assert(tdj_asset_service(a,4)>=0);if(engine)assert(tdj_render(engine,0,nullptr,nullptr));
    }
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_READY);return ticket;
}
static void equal(tdj_engine *stream,tdj_engine *reference,tdj_asset *a,int blocks) {
    float l[512],r[512],rl[512],rr[512];
    for(int b=0;b<blocks;b++) {
        assert(tdj_render(stream,512,l,r));assert(tdj_render(reference,512,rl,rr));
        for(int f=0;f<512;f++)if(l[f]!=rl[f] || r[f]!=rr[f]) {
            std::fprintf(stderr,"Mismatch block %d frame %d: %.9g %.9g / %.9g %.9g\n",b,f,l[f],r[f],rl[f],rr[f]);std::abort();
        }
        if(a)assert(tdj_asset_service(a,4)>=0);
    }
    if(a){tdj_stream_telemetry metrics{};tdj_asset_stream_telemetry(a,&metrics);
        assert(metrics.source_read_misses==0 && metrics.missing_output_frames==0);}
}
static void cue_recall_checks(const std::vector<float> &source,const char *path,const tdj_stream_config &config) {
    auto *memory=tdj_asset_create(source.data(),source.size()/2,48000);assert(memory);
    for(bool incoming:{false,true})for(bool loop:{false,true})for(bool paused:{false,true}) {
        auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(tested && reference);
        for(auto *e:{tested,reference}) {
            auto load=action(TDJ_LOAD);load.asset=memory;load.flag=15;load.value2=123.25;load.value3=137.25;
            assert(command(e,load)==TDJ_OK);load.deck=1;load.generation=2;load.value2=128;assert(command(e,load)==TDJ_OK);
            if(paused){auto tempo=action(TDJ_TEMPO);tempo.value=180;assert(command(e,tempo)==TDJ_OK);}
        }
        int deck=incoming ? 1:0;uint64_t generation=incoming ? 2:1;
        if(incoming) {
            if(paused)for(auto *e:{tested,reference}){auto seek=action(TDJ_SEEK,1,2);seek.value=400;assert(command(e,seek)==TDJ_OK);}
            for(auto *e:{tested,reference})assert(command(e,action(TDJ_PLAY))==TDJ_OK);
            equal(tested,reference,nullptr,3);
        } else if(paused) {
            for(auto *e:{tested,reference})assert(command(e,action(TDJ_PLAY))==TDJ_OK);
            equal(tested,reference,nullptr,3);
            for(auto *e:{tested,reference})assert(command(e,action(TDJ_PLAY))==TDJ_OK);
        }
        auto recall=action(TDJ_CUE_RECALL,deck,generation);recall.value=15000.25;
        recall.value2=loop ? recall.value+24000:0;recall.value3=0.5;
        assert(command(tested,recall)==TDJ_OK);
        auto legacy=action(loop ? TDJ_LOOP:TDJ_JUMP,deck,generation);legacy.value=recall.value;
        if(loop){legacy.flag=1;legacy.value2=recall.value2;legacy.value3=recall.value3;}
        else legacy.value2=recall.value3;
        assert(command(reference,legacy)==TDJ_OK);assert(command(reference,action(TDJ_PLAY,deck,generation))==TDJ_OK);
        tdj_snapshot actual{},expected{};assert(tdj_read_snapshot(tested,&actual));assert(tdj_read_snapshot(reference,&expected));
        assert(actual.master_bpm==expected.master_bpm && actual.master_beat==expected.master_beat);
        auto a=deck ? actual.b:actual.a,b=deck ? expected.b:expected.a;
        assert(a.state==b.state && a.source_frame==b.source_frame && a.target_beat==b.target_beat && a.loop_enabled==b.loop_enabled);
        equal(tested,reference,nullptr,200);
        assert(tdj_read_snapshot(tested,&actual));assert(command(tested,recall)==TDJ_UNRESOLVED);
        assert(tdj_read_snapshot(tested,&expected));assert(actual.master_beat==expected.master_beat);
        equal(tested,reference,nullptr,8);
        tdj_engine_destroy(tested);tdj_engine_destroy(reference);
    }
    int32_t error=0;auto *asset=tdj_asset_open_stream(path,source.size()/2,48000,&config,&error);assert(asset);
    uint64_t ticket=prepare(asset,nullptr,0,1,1,true);
    auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);
    for(int deck=0;deck<2;deck++) {
        auto load=action(TDJ_LOAD,deck,deck+1);load.asset=asset;load.flag=9;load.value2=120;
        load.preparation_ticket=deck==0 ? ticket:0;assert(command(tested,load)==TDJ_OK);
        load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    }
    tdj_asset_release_preparation(asset,ticket);
    assert(command(tested,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
    equal(tested,reference,asset,1);
    tdj_snapshot before{},after{};assert(tdj_read_snapshot(tested,&before));
    auto recall=action(TDJ_CUE_RECALL,1,2);recall.value=48000*80;recall.value3=0.5;
    assert(command(tested,recall)==TDJ_SOURCE_COLD);assert(tdj_read_snapshot(tested,&after));
    assert(before.a.source_frame==after.a.source_frame && before.b.source_frame==after.b.source_frame);
    assert(before.b.state==after.b.state && before.master_beat==after.master_beat && before.clock_running==after.clock_running);
    equal(tested,reference,asset,8); /* Rejected cue cannot start the old position. */
    ticket=prepare(asset,tested,recall.value,2,1,true);recall.preparation_ticket=ticket;
    assert(command(tested,recall)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
    auto jump=action(TDJ_JUMP,1,2);jump.value=recall.value;jump.value2=recall.value3;
    assert(command(reference,jump)==TDJ_OK);assert(command(reference,action(TDJ_PLAY,1,2))==TDJ_OK);
    equal(tested,reference,asset,200);
    tdj_engine_destroy(tested);tdj_engine_destroy(reference);tdj_asset_destroy(asset);tdj_asset_destroy(memory);
    puts("Atomic cue/loop start matches legacy warm playback, native tempo and synced bar wait; cold recall is inert.");
}
static void ended_stream_recall_checks(const std::vector<float> &source,const char *path,const tdj_stream_config &config) {
    const uint64_t frames=source.size()/2;
    auto *memory=tdj_asset_create(source.data(),frames,48000);assert(memory);
    for(bool flux:{false,true})for(bool incoming:{false,true}) {
        int32_t error=0;auto *asset=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(asset);
        auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(tested&&reference);
        if(incoming)for(auto *e:{tested,reference}) {
            auto load=action(TDJ_LOAD,1,2);load.asset=memory;load.flag=9;load.value2=120;
            assert(command(e,load)==TDJ_OK);assert(command(e,action(TDJ_PLAY,1,2))==TDJ_OK);
        }
        uint64_t ticket=prepare(asset,tested,frames-512,1,1,true);
        auto load=action(TDJ_LOAD);load.asset=asset;load.value=frames-512;load.flag=9;load.value2=120;load.preparation_ticket=ticket;
        assert(command(tested,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
        load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
        for(auto *e:{tested,reference}) {
            auto mode=action(TDJ_FLUX);mode.flag=flux;assert(command(e,mode)==TDJ_OK);
            assert(command(e,action(TDJ_PLAY))==TDJ_OK);
        }
        equal(tested,reference,asset,incoming ? 189:1);
        tdj_snapshot before{},after{};assert(tdj_read_snapshot(tested,&before));assert(before.a.state==TDJ_ENDED);
        auto recall=action(TDJ_CUE_RECALL);recall.value=20000;recall.value2=23000;recall.value3=.5;
        assert(command(tested,recall)==TDJ_SOURCE_COLD);assert(tdj_read_snapshot(tested,&after));
        assert(after.a.state==TDJ_ENDED&&!after.a.loop_enabled&&after.a.source_frame==frames);
        assert(after.a.continuing_frame==before.a.continuing_frame&&after.master_beat==before.master_beat&&after.clock_running==before.clock_running);
        assert(after.b.source_frame==before.b.source_frame&&after.b.state==before.b.state);
        equal(tested,reference,asset,4); // Cold recall must not start the old EOF position or disturb B.
        if(flux) {
            // A ready loop-only ticket cannot substitute for the restarted linear Flux path.
            ticket=prepare(asset,tested,20000,1,1,true,20000,23000);
            recall.preparation_ticket=ticket;assert(command(tested,recall)==TDJ_SOURCE_COLD);
            assert(tdj_read_snapshot(tested,&after));assert(after.a.state==TDJ_ENDED&&after.a.source_frame==frames);
            tdj_asset_release_preparation(asset,ticket);
        }
        ticket=prepare(asset,tested,20000,1,1,true,20000,23000,flux ? 20000:-1);
        recall.preparation_ticket=ticket;assert(command(tested,recall)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
        recall.preparation_ticket=0;assert(command(reference,recall)==TDJ_OK);
        assert(tdj_read_snapshot(tested,&after));assert(after.a.source_frame==20000&&after.a.continuing_frame==20000&&after.a.loop_enabled);
        assert(after.a.state==(incoming ? TDJ_QUEUED:TDJ_PLAYING));
        int blocks=0;
        while(after.a.state==TDJ_QUEUED&&blocks++<300){equal(tested,reference,asset,1);assert(tdj_read_snapshot(tested,&after));}
        assert(after.a.state==TDJ_PLAYING);equal(tested,reference,asset,8);
        assert(tdj_read_snapshot(tested,&before));assert(before.a.continuing_frame==20000+(before.output_frame-before.a.last_start_frame));
        auto exit=action(TDJ_LOOP);
        if(!flux) {
            // Loop-only preparation does not warm linear playback after leaving it.
            assert(command(tested,exit)==TDJ_SOURCE_COLD);assert(tdj_read_snapshot(tested,&after));
            assert(after.a.loop_enabled&&after.a.source_frame==before.a.source_frame&&after.master_beat==before.master_beat);
            equal(tested,reference,asset,4);assert(tdj_read_snapshot(tested,&before));
        }
        double returned=flux ? before.a.continuing_frame:before.a.source_frame;
        ticket=prepare(asset,tested,returned,1,1,true);exit.preparation_ticket=ticket;
        assert(command(tested,exit)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
        exit.preparation_ticket=0;assert(command(reference,exit)==TDJ_OK);
        assert(tdj_read_snapshot(tested,&after));assert(after.a.source_frame==returned);
        equal(tested,reference,asset,8);assert(tdj_read_snapshot(tested,&after));assert(after.a.state==TDJ_PLAYING);
        tdj_stream_telemetry telemetry{};tdj_asset_stream_telemetry(asset,&telemetry);
        assert(!telemetry.source_read_misses&&!telemetry.missing_output_frames&&!telemetry.io_errors);
        tdj_engine_destroy(tested);tdj_engine_destroy(reference);tdj_asset_destroy(asset);
    }
    tdj_asset_destroy(memory);
    puts("Four streamed EOF loop recalls reject cold/incomplete Flux coverage atomically, then resume exact fresh-source audio.");
}
static void rate_return_stream_checks(const std::vector<float> &source,const char *path,const tdj_stream_config &config) {
    const uint64_t frames=source.size()/2;
    auto *memory=tdj_asset_create(source.data(),frames,48000);assert(memory);
    for(bool compound:{false,true}) {
        int32_t error=0;auto *asset=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(asset);
        auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(tested&&reference);
        uint64_t ticket=prepare(asset,tested,10000,1,1.25,true);
        auto load=action(TDJ_LOAD);load.asset=asset;load.value=10000;load.flag=9;load.value2=120;load.preparation_ticket=ticket;
        assert(command(tested,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
        load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
        for(auto *e:{tested,reference}) {
            auto tempo=action(TDJ_TEMPO);tempo.value=150;assert(command(e,tempo)==TDJ_OK);
            auto flux=action(TDJ_FLUX);flux.flag=1;assert(command(e,flux)==TDJ_OK);
            assert(command(e,action(TDJ_PLAY))==TDJ_OK);
        }
        if(compound) {
            ticket=prepare(asset,tested,10000,1,1.25,true,10000,4000000,10000);
            auto touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.value=10000;touch.value2=4000000;touch.touch_rate=1;touch.preparation_ticket=ticket;
            assert(command(tested,touch)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
            touch.preparation_ticket=0;assert(command(reference,touch)==TDJ_OK);
        }
        equal(tested,reference,asset,8);
        auto rate=action(compound ? TDJ_TOUCH:TDJ_RATE);
        if(compound){rate.flag=TDJ_TOUCH_WITH_RATE;rate.value=10000;rate.value2=4000000;rate.touch_rate=4;}
        else rate.value=4;
        assert(command(tested,rate)==TDJ_OK);assert(command(reference,rate)==TDJ_OK);
        equal(tested,reference,asset,500); // Travel beyond the published pre-bypass source windows.
        tdj_snapshot before{},after{};assert(tdj_read_snapshot(tested,&before));assert(before.a.source_frame>1000000);
        if(compound)rate.touch_rate=1;else rate.value=1;
        assert(command(tested,rate)==TDJ_OK);assert(command(reference,rate)==TDJ_OK);
        assert(tdj_read_snapshot(tested,&after));
        assert(after.a.source_frame==before.a.source_frame&&after.a.touch_start==before.a.touch_start&&after.a.touch_end==before.a.touch_end);
        assert(after.master_beat==before.master_beat&&after.a.performance_rate==1&&!after.a.jump_pending);
        equal(tested,reference,asset,96);
        tdj_stream_telemetry telemetry{};tdj_asset_stream_telemetry(asset,&telemetry);
        assert(!telemetry.source_read_misses&&!telemetry.missing_output_frames&&!telemetry.io_errors);
        tdj_engine_destroy(tested);tdj_engine_destroy(reference);tdj_asset_destroy(asset);
    }
    tdj_asset_destroy(memory);
    puts("Direct and compound Keylock returns stay exact after far raw-rate travel, with no stale-window read or miss.");
}
static std::set<uint64_t> request_blocks(const tdj_stream_request &r) {
    std::set<uint64_t> blocks;
    for(unsigned n=0;n<r.count;n++)for(uint64_t b=r.ranges[n].first/8192;b<(r.ranges[n].end+8191)/8192;b++)blocks.insert(b);
    return blocks;
}
static void continuation_minimum_checks(const std::vector<float> &source,const char *path) {
    tdj_stream_config config{48000,0,0,512,0};int32_t error=0;
    auto *asset=tdj_asset_open_stream(path,source.size()/2,48000,&config,&error);assert(asset);
    tdj_stream_target target{};target.position=20000;target.source_speed=1.25;target.performance_rate=4;
    target.loop_start=20000;target.loop_end=20100;target.continuing_position=819216;target.reserve_continuing=1;target.keylock=1;
    tdj_stream_request reserved{},returned{};assert(tdj_asset_plan_minimum(asset,&target,serial++,1,&reserved)>0);
    auto normal=target;normal.position=target.continuing_position;normal.performance_rate=1;normal.loop_start=normal.loop_end=0;normal.reserve_continuing=0;
    assert(tdj_asset_plan_minimum(asset,&normal,serial++,1,&returned)>0);
    auto promised=request_blocks(reserved);for(auto b:request_blocks(returned))assert(promised.count(b));
    auto *memory=tdj_asset_create(source.data(),source.size()/2,48000);assert(memory);
    auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(tested&&reference);
    uint64_t ticket=prepare(asset,tested,819216,1,1.25,true);
    auto load=action(TDJ_LOAD);load.asset=asset;load.value=819216;load.value2=120;load.flag=9;load.preparation_ticket=ticket;
    assert(command(tested,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    for(auto *e:{tested,reference}){auto tempo=action(TDJ_TEMPO);tempo.value=150;assert(command(e,tempo)==TDJ_OK);assert(command(e,action(TDJ_PLAY))==TDJ_OK);}
    equal(tested,reference,asset,1);tdj_snapshot before{};assert(tdj_read_snapshot(tested,&before));
    auto flux=action(TDJ_FLUX);flux.flag=1;for(auto *e:{tested,reference})assert(command(e,flux)==TDJ_OK);
    ticket=prepare(asset,tested,20000,1,1.25,true,20000,20100,before.a.source_frame,4);
    auto touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.value=20000;touch.value2=20100;touch.touch_rate=4;touch.preparation_ticket=ticket;
    assert(command(tested,touch)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);touch.preparation_ticket=0;assert(command(reference,touch)==TDJ_OK);
    equal(tested,reference,asset,20);assert(tdj_read_snapshot(tested,&before));
    auto release=action(TDJ_TOUCH);assert(command(tested,release)==TDJ_OK);assert(command(reference,release)==TDJ_OK);
    tdj_snapshot after{};assert(tdj_read_snapshot(tested,&after));assert(after.a.source_frame==before.a.continuing_frame&&after.a.performance_rate==1);
    equal(tested,reference,asset,100);
    tdj_engine_destroy(tested);tdj_engine_destroy(reference);tdj_asset_destroy(memory);tdj_asset_destroy(asset);
    puts("Minimum-only Flux reservation covers native Keylock history/prime after raw-rate travel and returns without a miss.");
}
static void configured_frame_checks(const std::vector<float> &source,const char *path) {
    tdj_stream_config config{48000,2,1,512,0};int32_t error=0;
    auto *asset=tdj_asset_open_stream(path,source.size()/2,48000,&config,&error);assert(asset);
    auto *memory=tdj_asset_create(source.data(),source.size()/2,48000);assert(memory);
    auto *tested=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(tested&&reference);
    assert(tdj_engine_configure_maximum_output_frames(tested,0)==TDJ_INVALID);
    assert(tdj_engine_configure_maximum_output_frames(tested,65537)==TDJ_INVALID);
    uint64_t ticket=prepare(asset,nullptr,0);
    assert(tdj_engine_configure_maximum_output_frames(tested,8917)==TDJ_OK);
    assert(tdj_engine_configure_maximum_output_frames(reference,8917)==TDJ_OK);
    auto load=action(TDJ_LOAD);load.asset=asset;load.value2=120;load.preparation_ticket=ticket;
    assert(command(tested,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    tdj_stream_target target{};target.position=0;target.source_speed=target.performance_rate=1;
    tdj_stream_request before{},after{};assert(tdj_asset_plan_minimum(asset,&target,serial++,1,&before)>0);
    auto *other=tdj_engine_create(48000,1);assert(tdj_engine_configure_maximum_output_frames(other,16384)==TDJ_OK);
    load.asset=asset;assert(command(other,load)==TDJ_PROTECTED);assert(tdj_asset_plan_minimum(asset,&target,serial++,1,&after)>0);
    assert(before.count==after.count);for(unsigned i=0;i<before.count;i++)assert(before.ranges[i].first==after.ranges[i].first&&before.ranges[i].end==after.ranges[i].end);
    tdj_engine_destroy(other);
    for(auto *e:{tested,reference})assert(command(e,action(TDJ_PLAY))==TDJ_OK);
    std::vector<float> l(16384),r(16384),rl(16384),rr(16384);
    for(unsigned count:{8917u,16384u}) {
        if(count==16384){assert(tdj_engine_configure_maximum_output_frames(tested,count)==TDJ_OK);assert(tdj_engine_configure_maximum_output_frames(reference,count)==TDJ_OK);}
        assert(tdj_render(tested,count,l.data(),r.data()));assert(tdj_render(reference,count,rl.data(),rr.data()));
        for(unsigned i=0;i<count;i++)assert(l[i]==rl[i]&&r[i]==rr[i]);assert(tdj_asset_service(asset,4)>=0);
    }
    // A preparation worker sees one coherent atomic bound for both regions.
    tdj_stream_target probe{};probe.position=480000;probe.continuing_position=1440000;
    probe.source_speed=1.25;probe.performance_rate=4;probe.keylock=probe.reserve_continuing=1;
    tdj_stream_request small{},large{};
    assert(tdj_engine_configure_maximum_output_frames(tested,512)==TDJ_OK);
    assert(tdj_asset_plan_minimum(asset,&probe,serial++,1,&small)>0);
    assert(tdj_engine_configure_maximum_output_frames(tested,16384)==TDJ_OK);
    assert(tdj_asset_plan_minimum(asset,&probe,serial++,1,&large)>0);
    std::atomic<bool> running{true};std::atomic<unsigned> plans{0};
    auto same=[](const tdj_stream_request &a,const tdj_stream_request &b){return a.count==b.count&&!std::memcmp(a.ranges,b.ranges,a.count*sizeof(a.ranges[0]));};
    std::thread planner([&]{uint64_t id=1000000;while(running.load()){
        tdj_stream_request r{};assert(tdj_asset_plan_minimum(asset,&probe,id++,1,&r)>0);
        assert(same(r,small)||same(r,large));plans.fetch_add(1);
    }});
    while(!plans.load())std::this_thread::yield();
    for(int i=0;i<1000;i++)assert(tdj_engine_configure_maximum_output_frames(tested,i%2 ? 512:16384)==TDJ_OK);
    running=false;planner.join();assert(plans.load()>0);
    tdj_stream_telemetry telemetry{};tdj_asset_stream_telemetry(asset,&telemetry);assert(!telemetry.source_read_misses&&!telemetry.missing_output_frames);
    tdj_engine_destroy(tested);tdj_engine_destroy(reference);tdj_asset_destroy(asset);tdj_asset_destroy(memory);
    puts("Engine 8917/16384 frame configuration stays exact; attached/new assets update; invalid/second-engine changes are inert.");
}
static void future_capacity_checks(const char *path,uint64_t frames) {
    tdj_stream_config config{48000,2,1,8917,0};int32_t error=0;
    auto *asset=tdj_asset_open_stream(path,frames,384000,&config,&error);assert(asset);
    tdj_stream_target target{};target.position=target.continuing_position=819216;target.source_speed=8;
    target.performance_rate=2;target.keylock=target.reserve_continuing=1;
    tdj_stream_future future{target,1,1,0};
    tdj_stream_request initial{};assert(tdj_asset_plan_minimum(asset,&target,serial++,1,&initial)>0);
    assert(request_blocks(initial).size()<240);
    assert(tdj_stream_future_capacity(asset,&future,1,0)==TDJ_SOURCE_CAPACITY);
    auto *engine=tdj_engine_create(48000,1);assert(engine);
    auto tempo=action(TDJ_TEMPO);tempo.value=960;assert(command(engine,tempo)==TDJ_OK);
    uint64_t ticket=prepare(asset,engine,819216,1,8,true);
    auto load=action(TDJ_LOAD);load.asset=asset;load.value=819216;load.flag=9;load.value2=120;load.preparation_ticket=ticket;
    assert(command(engine,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);assert(command(engine,action(TDJ_PLAY))==TDJ_OK);
    float l[512],r[512];assert(tdj_render(engine,512,l,r));tdj_snapshot before{},after{};assert(tdj_read_snapshot(engine,&before));
    auto flux=action(TDJ_FLUX);flux.flag=1;assert(command(engine,flux)==TDJ_OK);
    ticket=prepare(asset,engine,before.a.source_frame,1,8,true,0,0,before.a.source_frame,2);
    auto touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.value=before.a.source_frame;touch.touch_rate=2;touch.preparation_ticket=ticket;
    assert(command(engine,touch)==TDJ_SOURCE_CAPACITY);tdj_asset_release_preparation(asset,ticket);
    assert(tdj_read_snapshot(engine,&after));assert(!after.a.touch_active&&after.a.performance_rate==1&&after.a.source_frame==before.a.source_frame&&after.master_beat==before.master_beat);
    // A short bounded loop makes the same raw-rate/Flux combination schedulable.
    auto loop=action(TDJ_LOOP);loop.flag=1;loop.value=before.a.source_frame;loop.value2=loop.value+1024;assert(command(engine,loop)==TDJ_OK);
    auto rate=action(TDJ_RATE);rate.value=2;assert(command(engine,rate)==TDJ_OK);assert(tdj_render(engine,512,l,r));
    tdj_stream_telemetry telemetry{};tdj_asset_stream_telemetry(asset,&telemetry);assert(!telemetry.source_read_misses);
    flux.flag=0;assert(command(engine,flux)==TDJ_OK);
    loop.value=before.a.source_frame-1024;loop.value2=before.a.source_frame+2000000;
    assert(command(engine,loop)==TDJ_OK);assert(tdj_read_snapshot(engine,&before));
    flux.flag=1;assert(command(engine,flux)==TDJ_SOURCE_CAPACITY);
    assert(tdj_read_snapshot(engine,&after));assert(!after.a.flux_enabled&&after.a.source_frame==before.a.source_frame&&after.master_beat==before.master_beat);
    loop.value=before.a.source_frame;loop.value2=loop.value+1024;assert(command(engine,loop)==TDJ_OK);
    assert(command(engine,flux)==TDJ_OK);
    auto exit=action(TDJ_LOOP);assert(command(engine,exit)==TDJ_OK);
    touch.preparation_ticket=0;touch.value=before.a.source_frame;touch.value3=1;
    assert(command(engine,touch)==TDJ_SOURCE_CAPACITY);assert(tdj_read_snapshot(engine,&after));assert(!after.a.jump_pending&&!after.a.touch_active);
    // A normal-rate unbounded touch is retained, but changing that active
    // gesture to an unsafe divergent rate is rejected without invalidating it.
    touch.value3=0;touch.touch_rate=1;assert(command(engine,touch)==TDJ_OK);
    assert(tdj_render(engine,512,l,r));assert(tdj_read_snapshot(engine,&before));
    touch.touch_rate=2;assert(command(engine,touch)==TDJ_SOURCE_CAPACITY);
    assert(tdj_read_snapshot(engine,&after));assert(after.a.touch_active&&after.a.performance_rate==1&&after.a.source_frame==before.a.source_frame&&after.master_beat==before.master_beat);
    tdj_engine_destroy(engine);
    // Equal unbounded normal-rate paths do not diverge or double the bank.
    future.target=target;future.target.performance_rate=1;
    assert(tdj_stream_future_capacity(asset,&future,1,0)==TDJ_OK);
    // Near EOF the audible lifetime ends before the two paths can separate.
    future.target=target;future.target.position=future.target.continuing_position=frames-1024;
    assert(tdj_stream_future_capacity(asset,&future,1,0)==TDJ_OK);
    tdj_asset_destroy(asset);
    puts("Initially overlapping but divergent Flux paths reject terminally; bounded loops, file clipping and identical normal paths stay supported.");
}
static void capacity_budget_matrix() {
    struct Row{double rate;uint32_t maximum;double performance;int expected;};
    Row rows[]={{48000,16384,4,TDJ_OK},{384000,4096,4,TDJ_OK},
        {384000,16384,1,TDJ_SOURCE_CAPACITY},{384000,16384,4,TDJ_SOURCE_CAPACITY}};
    for(auto row:rows) {
        char path[]="/tmp/tdj-capacity-matrix-XXXXXX";int fd=mkstemp(path);assert(fd>=0);
        uint64_t frames=(uint64_t)(row.rate*90);assert(ftruncate(fd,(off_t)(frames*8))==0);close(fd);
        tdj_stream_config config{48000,2,1,row.maximum,0};int32_t error=0;
        auto *asset=tdj_asset_open_stream(path,frames,row.rate,&config,&error);assert(asset);
        tdj_stream_target target{};target.position=row.rate*10;target.source_speed=8;target.performance_rate=row.performance;
        target.loop_start=row.rate;target.loop_end=row.rate*80;target.continuing_position=row.rate*50;target.keylock=target.reserve_continuing=1;
        tdj_stream_future future{target,1,1,0};assert(tdj_stream_future_capacity(asset,&future,1,0)==row.expected);
        if(row.expected==TDJ_OK) {
            auto travelled=target;double step=8*row.rate/48000;
            for(int tick=0;tick<512;tick++) {
                tdj_stream_request r{};assert(tdj_asset_plan_minimum(asset,&travelled,serial++,1,&r)>0);
                assert(request_blocks(r).size()<=240);
                double length=travelled.loop_end-travelled.loop_start;
                travelled.position=travelled.loop_start+std::fmod(travelled.position-travelled.loop_start+512*step*travelled.performance_rate,length);
                travelled.continuing_position+=512*step;
            }
        }
        if(row.rate==384000 && row.maximum==16384) {
            // Two equal, unbounded normal paths need one bank, even where
            // treating them as independent would exceed the published budget.
            auto same=target;same.loop_start=same.loop_end=0;same.performance_rate=1;
            same.continuing_position=same.position;future={same,1,1,0};
            assert(tdj_stream_future_capacity(asset,&future,1,0)==TDJ_OK);
            for(int tick=0;tick<512;tick++) {
                tdj_stream_request r{};assert(tdj_asset_plan_minimum(asset,&same,serial++,1,&r)>0);
                assert(request_blocks(r).size()<=240);
                same.position+=512*8*row.rate/48000;same.continuing_position=same.position;
                if(same.position>=frames)break;
            }
        }
        tdj_asset_destroy(asset);unlink(path);
    }
    puts("Future budget matrix retains 48k/16384 and 384k/4096 raw Flux; oversized profiles reject before playback changes.");
}
static void cooperative_reader_checks(const char *path,uint64_t frames,const tdj_stream_config &config) {
    for(bool cancel:{true,false}) {
        int32_t error=0;auto *asset=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(asset);
        tdj_stream_test_io io{20000,0,UINT64_MAX};assert(tdj_asset_set_test_io(asset,&io)>0);
        uint64_t first=prepare(asset,nullptr,0);auto *engine=tdj_engine_create(48000,1);assert(engine);
        auto load=action(TDJ_LOAD);load.asset=asset;load.value2=120;load.preparation_ticket=first;
        assert(command(engine,load)==TDJ_OK);tdj_asset_release_preparation(asset,first);
        assert(command(engine,action(TDJ_PLAY))==TDJ_OK);
        tdj_stream_target target{};target.position=48000*20;target.source_speed=target.performance_rate=1;
        tdj_stream_request minimum{},desired{};
        assert(tdj_asset_plan_minimum(asset,&target,serial++,1,&minimum)>0);
        assert(tdj_asset_plan_target(asset,&target,serial++,1,&desired)>0);
        for(unsigned n=0;n<desired.count;n++){desired.ranges[n].priority=1;minimum.ranges[minimum.count++]=desired.ranges[n];}
        uint64_t ticket=tdj_asset_request_prepare(asset,&minimum);assert(ticket);
        tdj_stream_telemetry before{},atChange{},after{};tdj_asset_stream_telemetry(asset,&before);
        int result=TDJ_STREAM_PENDING;std::thread worker([&]{result=tdj_asset_service(asset,16);});
        int polls=0;
        do{std::this_thread::sleep_for(std::chrono::microseconds(500));tdj_asset_stream_telemetry(asset,&atChange);}
        while(atChange.bytes_read==before.bytes_read && ++polls<10000);
        assert(atChange.bytes_read>before.bytes_read);
        auto started=std::chrono::steady_clock::now();
        if(cancel)tdj_asset_release_preparation(asset,ticket);
        else {float l[512],r[512];assert(tdj_render(engine,512,l,r));}
        worker.join();tdj_asset_stream_telemetry(asset,&after);
        auto extra=after.bytes_read-atChange.bytes_read;
        assert(result>=0 && extra<=2*TDJ_STREAM_BLOCK_FRAMES*8 && !after.source_read_misses);
        if(!cancel)tdj_asset_release_preparation(asset,ticket);
        auto millis=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-started).count();
        std::printf("Cooperative %s: %llu additional bytes, %.3f ms to yield after change.\n",cancel ? "ticket cancel":"live request",extra,millis);
        tdj_engine_destroy(engine);tdj_asset_destroy(asset);
    }
}
#include "streaming-handoff-check.h"

static void free_rate_coverage_checks(const std::vector<float> &source,const char *path) {
    tdj_stream_config config{48000,0,0,512,0};
    auto memory=tdj_asset_create(source.data(),source.size()/2,48000);assert(memory);
    unsigned cold=0;
    for(int offset=0;offset<8192;offset+=512) {
        int32_t error=0;auto a=tdj_asset_open_stream(path,source.size()/2,48000,&config,&error);assert(a);
        tdj_stream_target target{};target.position=48000+offset;target.source_speed=target.performance_rate=1;target.keylock=1;
        tdj_stream_request request{};assert(tdj_asset_plan_minimum(a,&target,serial++,1,&request)==TDJ_STREAM_READY);
        auto ticket=tdj_asset_request_prepare(a,&request);assert(ticket);
        for(int n=0;n<100 && tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_PENDING;n++)assert(tdj_asset_service(a,4)>=0);
        assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_READY);
        auto e=tdj_engine_create(48000,1),reference=tdj_engine_create(48000,1);assert(e&&reference);
        auto load=action(TDJ_LOAD);load.asset=a;load.value=target.position;load.value2=120;load.flag=8;load.preparation_ticket=ticket;
        assert(command(e,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
        load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
        assert(command(e,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
        target.source_speed=1.5;assert(tdj_asset_plan_minimum(a,&target,serial++,1,&request)==TDJ_STREAM_READY);
        bool ready=tdj_stream_covers(a,&request);
        auto rate=action(TDJ_FREE_RATE);rate.value=1.5;
        int status=command(e,rate);assert(status==(ready ? TDJ_OK:TDJ_SOURCE_COLD));
        if(ready)assert(command(reference,rate)==TDJ_OK);
        else {
            cold++;tdj_snapshot state{};assert(tdj_read_snapshot(e,&state));
            assert(state.a.free_rate==1&&state.a.source_frame==load.value&&state.a.state==TDJ_PLAYING);
        }
        // Rejected changes must leave every currently audible sample intact.
        equal(e,reference,a,1);
        if(!ready) {
            tdj_snapshot state{};assert(tdj_read_snapshot(e,&state));
            ticket=prepare(a,e,state.a.source_frame,1,1.5,true);
            rate.preparation_ticket=ticket;assert(command(e,rate)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
            rate.preparation_ticket=0;assert(command(reference,rate)==TDJ_OK);
        }
        equal(e,reference,a,4);
        tdj_engine_destroy(e);tdj_engine_destroy(reference);tdj_asset_destroy(a);
    }
    assert(cold>0);tdj_asset_destroy(memory);
    puts("Sixteen speed-change cache boundaries preserve current audio while cold and emit exact prepared samples with zero misses.");
}
struct DecodedReaderCheck {
    const std::vector<float> *samples;
    uint64_t requested=0;
    unsigned calls=0, releases=0;
    bool fail=false;
};
static int32_t decode_check(void *context,uint64_t first,uint32_t count,float *stereo) {
    auto *reader=static_cast<DecodedReaderCheck *>(context);
    reader->calls++;reader->requested+=count;
    if(reader->fail || (first+count)*2>reader->samples->size())return TDJ_STREAM_IO_ERROR;
    std::memcpy(stereo,reader->samples->data()+first*2,count*2*sizeof(float));
    return TDJ_STREAM_READY;
}
static void release_decode_check(void *context) { static_cast<DecodedReaderCheck *>(context)->releases++; }
static void decoded_reader_checks() {
    std::vector<float> source(48000*60*2);
    for(size_t n=0;n<source.size();n++)source[n]=(float)std::sin(n*0.003)*0.1f;
    tdj_stream_config config{48000,2,1,4096,0};int32_t status=0;
    DecodedReaderCheck reader{&source};
    auto *asset=tdj_asset_open_decoder(source.size()/2,48000,&config,decode_check,release_decode_check,&reader,&status);
    assert(asset && reader.calls==0 && reader.releases==0);
    auto ticket=prepare(asset,nullptr,0);
    assert(reader.requested<48000*4 && reader.calls>0);
    auto *engine=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);
    auto *memory=tdj_asset_create(source.data(),source.size()/2,48000);
    auto load=action(TDJ_LOAD);load.asset=asset;load.flag=0;load.preparation_ticket=ticket;
    assert(command(engine,load)==TDJ_OK);tdj_asset_release_preparation(asset,ticket);
    load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    assert(command(engine,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
    equal(engine,reference,asset,200);
    tdj_engine_destroy(engine);tdj_engine_destroy(reference);tdj_asset_destroy(memory);
    tdj_asset_cancel_service(asset);tdj_asset_destroy(asset);assert(reader.releases==1);
    reader={&source};reader.fail=true;
    asset=tdj_asset_open_decoder(source.size()/2,48000,&config,decode_check,release_decode_check,&reader,&status);
    tdj_stream_target target{};target.source_speed=1;target.performance_rate=1;
    tdj_stream_request request{};assert(tdj_asset_plan_target(asset,&target,1,1,&request)==TDJ_STREAM_READY);
    ticket=tdj_asset_request_prepare(asset,&request);assert(ticket);
    assert(tdj_asset_service(asset,16)==TDJ_STREAM_IO_ERROR);
    assert(tdj_asset_prepare_status(asset,ticket)==TDJ_STREAM_IO_ERROR);
    tdj_asset_release_preparation(asset,ticket);tdj_asset_destroy(asset);assert(reader.releases==1);
    config.max_output_frames=0;reader.releases=0;
    assert(!tdj_asset_open_decoder(source.size()/2,48000,&config,decode_check,release_decode_check,&reader,&status));
    assert(reader.releases==0);
    puts("Decoder stream: no opening reads, bounded priming, exact output, failure and single release passed.");
}
int main() {
    decoded_reader_checks();
    streaming_handoff_checks();
    constexpr uint64_t frames=48000*90;
    std::vector<float> source(frames*2);
    for(uint64_t f=0;f<frames;f++){source[2*f]=0.12f*std::sin(f*0.023);source[2*f+1]=0.1f*std::cos(f*0.031);}
    char path[]="/tmp/tdj-stream-native-XXXXXX";int fd=mkstemp(path);assert(fd>=0);
    size_t done=0,bytes=source.size()*sizeof(float);
    while(done<bytes){ssize_t n=write(fd,(char *)source.data()+done,bytes-done);assert(n>0);done+=(size_t)n;}close(fd);
    tdj_stream_config config{48000,2,1,512,0};int32_t error=0;
    auto *a=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(a && error==TDJ_STREAM_READY);
    assert(tdj_asset_service(a,4)==TDJ_STREAM_READY);
    tdj_stream_request bootstrap{};bootstrap.request_id=serial++;bootstrap.deck_generation=1;bootstrap.count=1;
    bootstrap.ranges[0]={0,8192*230,0,0};
    uint64_t bootTicket=tdj_asset_request_prepare(a,&bootstrap);assert(bootTicket);
    for(int n=0;n<1000 && tdj_asset_prepare_status(a,bootTicket)==TDJ_STREAM_PENDING;n++)assert(tdj_asset_service(a,4)>=0);
    assert(tdj_asset_prepare_status(a,bootTicket)==TDJ_STREAM_READY);tdj_asset_release_preparation(a,bootTicket);
    bootstrap.request_id=serial++;bootstrap.ranges[0]={8192*280,8192*510,0,0};
    bootTicket=tdj_asset_request_prepare(a,&bootstrap);assert(bootTicket);
    for(int n=0;n<1000 && tdj_asset_prepare_status(a,bootTicket)==TDJ_STREAM_PENDING;n++)assert(tdj_asset_service(a,4)>=0);
    assert(tdj_asset_prepare_status(a,bootTicket)==TDJ_STREAM_READY);tdj_asset_release_preparation(a,bootTicket);
    tdj_asset_destroy(a);a=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(a);
    puts("Service before request and changed full-size unattached target passed.");
    auto *memory=tdj_asset_create(source.data(),frames,48000);assert(memory);
    auto *stream=tdj_engine_create(48000,1),*reference=tdj_engine_create(48000,1);assert(stream && reference);
    uint64_t ticket=prepare(a,nullptr,0);
    auto load=action(TDJ_LOAD);load.asset=a;load.value2=120;load.flag=9;load.preparation_ticket=ticket;
    assert(command(stream,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    for(int n=0;n<3;n++){assert(tdj_asset_service(a,4)>=0);assert(tdj_render(stream,0,nullptr,nullptr));}
    ticket=prepare(a,stream,48000,1,1,true);
    auto idleSeek=action(TDJ_SEEK);idleSeek.value=48000;idleSeek.preparation_ticket=ticket;
    assert(command(stream,idleSeek)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    assert(tdj_asset_service(a,4)>=0);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_INVALID);
    assert(tdj_render(stream,0,nullptr,nullptr));assert(tdj_asset_service(a,4)>=0);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_INVALID);
    idleSeek.value=0;idleSeek.preparation_ticket=0;assert(command(stream,idleSeek)==TDJ_OK);
    assert(command(stream,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
    equal(stream,reference,a,6000); /* Cross many 8192-frame blocks. */
    auto tempo=action(TDJ_TEMPO);tempo.value=180;
    assert(command(stream,tempo)==TDJ_OK);assert(command(reference,tempo)==TDJ_OK);
    equal(stream,reference,a,400);
    auto flux=action(TDJ_FLUX);flux.flag=1;assert(command(stream,flux)==TDJ_OK);assert(command(reference,flux)==TDJ_OK);
    tdj_snapshot before{},after{};assert(tdj_read_snapshot(stream,&before));
    auto touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.touch_rate=-1;touch.value=48000*80;touch.value2=touch.value+8192;
    assert(command(stream,touch)==TDJ_SOURCE_COLD);assert(tdj_read_snapshot(stream,&after));
    assert(after.a.source_frame==before.a.source_frame && after.a.touch_active==before.a.touch_active);
    assert(after.a.performance_rate==before.a.performance_rate);
    tdj_stream_target cancelled{};cancelled.position=touch.value;cancelled.source_speed=1.5;
    cancelled.performance_rate=-1;cancelled.loop_start=touch.value;cancelled.loop_end=touch.value2;
    cancelled.continuing_position=before.a.source_frame;cancelled.reserve_continuing=1;cancelled.keylock=1;
    tdj_stream_request cancelledRequest{};
    assert(tdj_asset_plan_target(a,&cancelled,serial++,1,&cancelledRequest)>0);
    uint64_t cancelledTicket=tdj_asset_request_prepare(a,&cancelledRequest);assert(cancelledTicket);
    tdj_asset_release_preparation(a,cancelledTicket);
    assert(command(stream,action(TDJ_TOUCH))==TDJ_OK);
    equal(stream,reference,a,8); /* Reference receives no gesture at all. */
    assert(tdj_read_snapshot(stream,&before));
    ticket=prepare(a,stream,touch.value,1,1.5,true,touch.value,touch.value2,before.a.source_frame,-1);
    touch.preparation_ticket=ticket;assert(command(stream,touch)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    touch.preparation_ticket=0;assert(command(reference,touch)==TDJ_OK);equal(stream,reference,a,250);
    auto release=action(TDJ_TOUCH);assert(command(stream,release)==TDJ_OK);assert(command(reference,release)==TDJ_OK);
    equal(stream,reference,a,250);
    /* A distant quantised target keeps its ticket until execution and table handoff. */
    ticket=prepare(a,stream,48000*60,1,1.5,true);
    auto jump=action(TDJ_JUMP);jump.value=48000*60;jump.value2=4;jump.preparation_ticket=ticket;
    assert(command(stream,jump)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    jump.preparation_ticket=0;assert(command(reference,jump)==TDJ_OK);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_INVALID);
    equal(stream,reference,a,500);
    for(int n=0;n<8;n++){assert(tdj_asset_service(a,4)>=0);assert(tdj_render(stream,0,nullptr,nullptr));}
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_INVALID);
    /* Compound updates preserve active position and pending musical boundary. */
    assert(tdj_read_snapshot(stream,&before));
    double slice=48000*14;
    ticket=prepare(a,stream,slice,1,1.5,true,slice,slice+8192,before.a.source_frame,-1);
    touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.value=slice;touch.value2=slice+8192;
    touch.value3=4;touch.touch_rate=-1;touch.preparation_ticket=ticket;
    assert(command(stream,touch)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    assert(tdj_read_snapshot(stream,&before));assert(before.a.jump_pending && before.a.performance_rate==1);
    assert(tdj_engine_output_sources_ready(stream)==TDJ_OK);
    assert(before.a.jump_beat-before.master_beat>0.1);
    float pendingL[512],pendingR[512],untouchedL[512],untouchedR[512];
    assert(tdj_render(stream,512,pendingL,pendingR));assert(tdj_render(reference,512,untouchedL,untouchedR));
    for(int f=0;f<512;f++)assert(pendingL[f]==untouchedL[f] && pendingR[f]==untouchedR[f]);
    assert(tdj_asset_service(a,4)>=0);
    touch.preparation_ticket=0;assert(command(reference,touch)==TDJ_OK);
    assert(tdj_read_snapshot(stream,&before));
    touch.touch_rate=-0.5;
    assert(command(stream,touch)==TDJ_OK);assert(command(reference,touch)==TDJ_OK);
    assert(tdj_read_snapshot(stream,&after));
    assert(after.a.jump_beat==before.a.jump_beat && after.a.source_frame==before.a.source_frame);
    assert(after.a.performance_rate==1 && after.a.pending_touch_rate==-0.5);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_INVALID);
    equal(stream,reference,a,200);assert(tdj_read_snapshot(stream,&before));
    assert(!before.a.jump_pending && before.a.performance_rate==-0.5);
    touch.touch_rate=-0.75;
    assert(command(stream,touch)==TDJ_OK);assert(command(reference,touch)==TDJ_OK);
    assert(tdj_read_snapshot(stream,&after));assert(after.a.source_frame==before.a.source_frame && !after.a.jump_pending);
    equal(stream,reference,a,50);
    assert(command(stream,release)==TDJ_OK);assert(command(reference,release)==TDJ_OK);
    /* A loop straddles a cache boundary with Keylock active. */
    ticket=prepare(a,stream,8190,1,1.5,true,8190,8210);
    auto loop=action(TDJ_LOOP);loop.flag=1;loop.value=8190;loop.value2=8210;loop.value3=0.5;loop.preparation_ticket=ticket;
    assert(command(stream,loop)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    loop.preparation_ticket=0;assert(command(reference,loop)==TDJ_OK);equal(stream,reference,a,500);
    auto reverse=action(TDJ_RATE);reverse.value=-1;
    assert(command(stream,reverse)==TDJ_OK);assert(command(reference,reverse)==TDJ_OK);equal(stream,reference,a,100);
    /* A pending unbounded touch returns to the underlying loop, not the previous slice. */
    reverse.value=1;assert(command(stream,reverse)==TDJ_OK);assert(command(reference,reverse)==TDJ_OK);
    assert(tdj_read_snapshot(stream,&before));
    ticket=prepare(a,stream,48000*40,1,1.5,true,48000*40,48000*40+8192,before.a.continuing_frame);
    touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.touch_rate=1;
    touch.value=48000*40;touch.value2=touch.value+8192;touch.preparation_ticket=ticket;
    assert(command(stream,touch)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    touch.preparation_ticket=0;assert(command(reference,touch)==TDJ_OK);
    touch.value=48000;touch.value2=0;touch.value3=0.5;
    assert(command(stream,touch)==TDJ_OK);assert(command(reference,touch)==TDJ_OK);
    equal(stream,reference,a,80);assert(tdj_read_snapshot(stream,&after));
    assert(after.a.touch_active && after.a.touch_end==0 && after.a.loop_enabled && !after.a.jump_pending);
    assert(after.a.source_frame>=8190 && after.a.source_frame<8210);
    assert(command(stream,release)==TDJ_OK);assert(command(reference,release)==TDJ_OK);
    ticket=prepare(a,stream,48000*40,2,1.5,true);
    auto second=action(TDJ_LOAD,1,2);second.asset=a;second.value=48000*40;second.value2=120;second.flag=9;second.preparation_ticket=ticket;
    assert(command(stream,second)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    second.asset=memory;second.preparation_ticket=0;assert(command(reference,second)==TDJ_OK);
    assert(command(stream,action(TDJ_PLAY,1,2))==TDJ_OK);assert(command(reference,action(TDJ_PLAY,1,2))==TDJ_OK);
    assert(tdj_engine_output_sources_ready(stream)==TDJ_OK);
    equal(stream,reference,a,1000);
    assert(tdj_read_snapshot(stream,&before));assert(before.a.continuing_frame>=frames);
    auto exitLoop=action(TDJ_LOOP);
    assert(command(stream,exitLoop)==TDJ_OK);assert(command(reference,exitLoop)==TDJ_OK);
    equal(stream,reference,a,100);
    auto *otherEngine=tdj_engine_create(48000,1);load.asset=a;load.preparation_ticket=0;
    assert(command(otherEngine,load)==TDJ_PROTECTED);tdj_engine_destroy(otherEngine);
    tdj_engine_destroy(stream);tdj_engine_destroy(reference);tdj_asset_destroy(memory);
    tdj_stream_telemetry metrics{};tdj_asset_stream_telemetry(a,&metrics);
    assert(metrics.resident_pcm_bytes==TDJ_STREAM_BLOCK_COUNT*TDJ_STREAM_BLOCK_FRAMES*8ull && metrics.rejected_cold_commands>=1);
    std::printf("Exact streamed/reference reads, Keylock, cold target, Flux, quantised ownership, loop wrap and reverse passed; bytes read %llu.\n",metrics.bytes_read);
    tdj_asset_destroy(a);assert(tdj_stream_reserved_pcm_bytes()==0);
    free_rate_coverage_checks(source,path);
    cue_recall_checks(source,path,config);assert(tdj_stream_reserved_pcm_bytes()==0);
    ended_stream_recall_checks(source,path,config);assert(tdj_stream_reserved_pcm_bytes()==0);
    rate_return_stream_checks(source,path,config);assert(tdj_stream_reserved_pcm_bytes()==0);
    continuation_minimum_checks(source,path);assert(tdj_stream_reserved_pcm_bytes()==0);
    configured_frame_checks(source,path);assert(tdj_stream_reserved_pcm_bytes()==0);
    future_capacity_checks(path,frames);assert(tdj_stream_reserved_pcm_bytes()==0);
    capacity_budget_matrix();assert(tdj_stream_reserved_pcm_bytes()==0);
    cooperative_reader_checks(path,frames,config);assert(tdj_stream_reserved_pcm_bytes()==0);
    /* Hard budget includes cancelled assets until destruction. */
    tdj_asset *assets[4];for(auto &item:assets){item=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(item);}
    assert(!tdj_asset_open_stream(path,frames,48000,&config,&error) && error==TDJ_STREAM_CAPACITY);
    tdj_asset_cancel_service(assets[0]);assert(tdj_stream_reserved_pcm_bytes()==TDJ_STREAM_GLOBAL_PCM_BYTES);
    for(auto *item:assets)tdj_asset_destroy(item);assert(tdj_stream_reserved_pcm_bytes()==0);
    /* Short reads preserve exact PCM; an injected failure remains explicit. */
    a=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(a);
    tdj_stream_test_io io{0,4093,UINT64_MAX};assert(tdj_asset_set_test_io(a,&io)==TDJ_STREAM_READY);
    ticket=prepare(a,nullptr,0);tdj_asset_release_preparation(a,ticket);tdj_asset_destroy(a);
    a=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(a);io.fail_after_bytes=31;
    assert(tdj_asset_set_test_io(a,&io)==TDJ_STREAM_READY);
    tdj_stream_target target{};target.source_speed=target.performance_rate=1;
    tdj_stream_request request{};assert(tdj_asset_plan_target(a,&target,serial++,1,&request)>0);
    ticket=tdj_asset_request_prepare(a,&request);assert(ticket);
    assert(tdj_asset_service(a,4)==TDJ_STREAM_IO_ERROR && tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_IO_ERROR);
    tdj_asset_release_preparation(a,ticket);tdj_asset_destroy(a);
    /* A finite one-second worker read cannot hold the audio callback. */
    tdj_stream_config shortConfig{48000,0.01,0,512,0};
    a=tdj_asset_open_stream(path,frames,48000,&shortConfig,&error);assert(a);
    io={1000000,0,UINT64_MAX};assert(tdj_asset_set_test_io(a,&io)==TDJ_STREAM_READY);
    ticket=prepare(a,nullptr,0);stream=tdj_engine_create(48000,1);
    load=action(TDJ_LOAD);load.asset=a;load.value2=120;load.preparation_ticket=ticket;
    assert(command(stream,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    assert(command(stream,action(TDJ_PLAY))==TDJ_OK);
    target={};target.position=8192*40+4096;target.source_speed=target.performance_rate=1;
    assert(tdj_asset_plan_target(a,&target,serial++,1,&request)>0);
    ticket=tdj_asset_request_prepare(a,&request);assert(ticket);
    int workerResult=TDJ_STREAM_PENDING;
    std::thread worker([&]{workerResult=tdj_asset_service(a,1);});
    std::this_thread::sleep_for(std::chrono::milliseconds(30));
    float l[512],r[512];auto began=std::chrono::steady_clock::now();
    assert(tdj_render(stream,512,l,r));
    double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count();
    assert(seconds<0.25);tdj_asset_cancel_service(a);worker.join();
    assert(workerResult==TDJ_STREAM_CANCELLED && tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_CANCELLED);
    tdj_asset_stream_telemetry(a,&metrics);assert(metrics.source_read_misses==0 && metrics.io_errors==0);
    std::printf("Callback completed in %.3f ms during a one-second worker read.\n",seconds*1000);
    tdj_asset_release_preparation(a,ticket);tdj_engine_destroy(stream);tdj_asset_destroy(a);
    /* Concurrent publication/adoption retains exact samples. */
    a=tdj_asset_open_stream(path,frames,48000,&config,&error);assert(a);
    memory=tdj_asset_create(source.data(),frames,48000);assert(memory);
    ticket=prepare(a,nullptr,0);stream=tdj_engine_create(48000,1);reference=tdj_engine_create(48000,1);
    load=action(TDJ_LOAD);load.asset=a;load.value2=120;load.preparation_ticket=ticket;
    assert(command(stream,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    assert(command(stream,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
    std::atomic<bool> running{true};
    std::thread ongoing([&]{while(running.load()){assert(tdj_asset_service(a,1)>=0);std::this_thread::sleep_for(std::chrono::microseconds(50));}});
    float rl[512],rr[512];
    for(int block=0;block<500;block++) {
        assert(tdj_render(stream,512,l,r));assert(tdj_render(reference,512,rl,rr));
        for(int f=0;f<512;f++)assert(l[f]==rl[f] && r[f]==rr[f]);
        std::this_thread::sleep_for(std::chrono::microseconds(200));
    }
    running.store(false);ongoing.join();tdj_asset_stream_telemetry(a,&metrics);
    assert(!metrics.source_read_misses && !metrics.missing_output_frames);
    tdj_engine_destroy(stream);tdj_engine_destroy(reference);tdj_asset_destroy(memory);tdj_asset_destroy(a);
    /* Exhaustion is observable, even though bounded emergency output stays finite. */
    a=tdj_asset_open_stream(path,frames,48000,&shortConfig,&error);assert(a);ticket=prepare(a,nullptr,0);
    stream=tdj_engine_create(48000,1);load=action(TDJ_LOAD);load.asset=a;load.value2=120;load.preparation_ticket=ticket;
    assert(command(stream,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    assert(command(stream,action(TDJ_PLAY))==TDJ_OK);
    for(int b=0;b<32;b++){assert(tdj_render(stream,512,l,r));for(int f=0;f<512;f++)assert(std::isfinite(l[f]) && std::isfinite(r[f]));}
    tdj_asset_stream_telemetry(a,&metrics);
    assert(metrics.source_read_misses>0 && metrics.missing_output_frames>0 && metrics.first_missing_output_frame==8191);
    tdj_engine_destroy(stream);tdj_asset_destroy(a);
    /* Optional prefetch cannot stop mandatory playback when two wide reserves exceed the pool. */
    a=tdj_asset_open_stream(path,frames,384000,&config,&error);assert(a);
    memory=tdj_asset_create(source.data(),frames,384000);assert(memory);
    ticket=prepare(a,nullptr,384000,1,1,true);stream=tdj_engine_create(48000,1);reference=tdj_engine_create(48000,1);
    load=action(TDJ_LOAD);load.asset=a;load.value=384000;load.value2=120;load.flag=9;load.preparation_ticket=ticket;
    assert(command(stream,load)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    load.asset=memory;load.preparation_ticket=0;assert(command(reference,load)==TDJ_OK);
    assert(command(stream,action(TDJ_PLAY))==TDJ_OK);assert(command(reference,action(TDJ_PLAY))==TDJ_OK);
    equal(stream,reference,a,10);
    ticket=prepare(a,stream,384000*7,1,1,true);
    jump=action(TDJ_JUMP);jump.value=384000*7;jump.preparation_ticket=ticket;
    assert(command(stream,jump)==TDJ_OK);tdj_asset_release_preparation(a,ticket);
    jump.preparation_ticket=0;assert(command(reference,jump)==TDJ_OK);
    assert(command(stream,flux)==TDJ_OK);assert(command(reference,flux)==TDJ_OK);
    touch=action(TDJ_TOUCH);touch.flag=TDJ_TOUCH_WITH_RATE;touch.value=384000;touch.touch_rate=1;
    assert(command(stream,touch)==TDJ_OK);assert(command(reference,touch)==TDJ_OK);
    equal(stream,reference,a,200);
    assert(command(stream,release)==TDJ_OK);assert(command(reference,release)==TDJ_OK);
    equal(stream,reference,a,200);tdj_asset_stream_telemetry(a,&metrics);
    assert(!metrics.capacity_failures && !metrics.source_read_misses);
    tdj_engine_destroy(stream);tdj_engine_destroy(reference);tdj_asset_destroy(memory);tdj_asset_destroy(a);
    a=tdj_asset_open_stream(path,frames,384000,&config,&error);assert(a);
    target={};target.position=384000*7;target.continuing_position=384000;
    target.source_speed=8;target.performance_rate=1;target.keylock=target.reserve_continuing=1;
    tdj_stream_request full{},minimum{};
    assert(tdj_asset_plan_target(a,&target,serial++,1,&full)>0);
    ticket=tdj_asset_request_prepare(a,&full);assert(ticket);
    assert(tdj_asset_service(a,16)==TDJ_STREAM_READY || tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_CAPACITY);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_CAPACITY);tdj_asset_release_preparation(a,ticket);
    assert(tdj_asset_plan_minimum(a,&target,serial++,1,&minimum)>0);
    for(unsigned n=0;n<full.count;n++){full.ranges[n].priority=1;minimum.ranges[minimum.count++]=full.ranges[n];}
    ticket=tdj_asset_request_prepare(a,&minimum);assert(ticket);
    for(int n=0;n<100 && tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_PENDING;n++)assert(tdj_asset_service(a,16)>=0);
    assert(tdj_asset_prepare_status(a,ticket)==TDJ_STREAM_READY);tdj_asset_release_preparation(a,ticket);
    tdj_asset_destroy(a);unlink(path);
    puts("Minimum plus optional reserve fits 8x high-rate Flux where full mandatory reserve cannot.");
    puts("High-rate shared reserve pressure preserves exact audible and Flux-return reads.");
    puts("Concurrent table retirement and explicit starvation telemetry passed.");
    assert(tdj_stream_reserved_pcm_bytes()==0);puts("Budget, cancellation retention, short reads and injected I/O failure passed.");
}
