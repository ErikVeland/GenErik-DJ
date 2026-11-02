#include "TDJAsset.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <time.h>
#include <limits.h>

#define POOL_BYTES ((uint64_t)TDJ_STREAM_BLOCK_COUNT*TDJ_STREAM_BLOCK_FRAMES*8)
#define TABLE_BLOCKS 240u
#define HASH_SIZE 512u
#define WORKER_OWNER UINTPTR_MAX
typedef struct {
    _Atomic int state; /* 0 free, 1 worker draft, 2 published, 3 rendering, 4 retired. */
    uint64_t serial, request_id;
    unsigned count;
    uint64_t keys[HASH_SIZE];
    uint16_t slots[HASH_SIZE];
} stream_table;
typedef struct {
    _Atomic uint64_t identity;
    _Atomic unsigned refs;
    _Atomic uint64_t consume_serial;
    _Atomic int status;
    tdj_stream_request request;
} stream_ticket;
typedef struct { _Atomic int state; tdj_stream_request request; } request_mailbox;
struct tdj_stream {
    int fd, input_latency, output_latency, seek_length;
    tdj_stream_config config;
    _Atomic uint32_t maximum_output_frames;
    float *pool;
    uint64_t block_ids[TDJ_STREAM_BLOCK_COUNT];
    bool block_valid[TDJ_STREAM_BLOCK_COUNT];
    stream_table tables[3];
    _Atomic int pending, current;
    _Atomic bool cancelled, service_started, render_started;
    _Atomic uintptr_t engine;
    stream_ticket tickets[TDJ_STREAM_MAX_TICKETS];
    request_mailbox mailbox[3];
    tdj_stream_request live;
    tdj_stream_request render_need;
    uint64_t table_serial, bytes_read_worker;
    int bootstrap;
    tdj_stream_test_io test_io;
    /* Only the render consumer changes its current-block cache. */
    int reader_table;
    uint64_t reader_block, output_frame;
    uint64_t consumer_request_serial;
    const float *reader_data;
    bool read_failed;
    _Atomic uint64_t source_read_misses, missing_output_frames, first_missing_output_frame;
    _Atomic uint64_t latest_missing_source_frame, low_reserve_callbacks, rejected_cold_commands;
    _Atomic uint64_t io_errors, capacity_failures, retirement_backpressure, request_backpressure;
    _Atomic uint64_t bytes_read, max_service_nanoseconds, minimum_forward_ready_frames, ready_table_serial;
};
static _Atomic uint64_t global_bytes=0, global_ticket=1;
static uint64_t nanos(void) {
    struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
    return (uint64_t)t.tv_sec*1000000000ull+(uint64_t)t.tv_nsec;
}
static unsigned hash_block(uint64_t id) { return (unsigned)((id*11400714819323198485ull)>>55)&(HASH_SIZE-1); }
static int table_find(const stream_table *t,uint64_t id) {
    unsigned at=hash_block(id); uint64_t key=id+1;
    for(unsigned n=0;n<HASH_SIZE;n++,at=(at+1)&(HASH_SIZE-1)) {
        if(!t->keys[at]) return -1;
        if(t->keys[at]==key) return t->slots[at];
    }
    return -1;
}
static void table_add(stream_table *t,uint64_t id,unsigned slot) {
    unsigned at=hash_block(id);
    for(unsigned n=0;n<HASH_SIZE;n++,at=(at+1)&(HASH_SIZE-1)) {
        if(t->keys[at]==id+1) return;
        if(!t->keys[at]) { t->keys[at]=id+1;t->slots[at]=(uint16_t)slot;t->count++;return; }
    }
}
static bool valid_request(const tdj_asset *a,const tdj_stream_request *r) {
    if(!r || !r->request_id || !r->deck_generation || !r->count || r->count>TDJ_STREAM_MAX_RANGES) return false;
    for(unsigned i=0;i<r->count;i++) if(r->ranges[i].first>=r->ranges[i].end ||
        r->ranges[i].end>a->frames || r->ranges[i].priority>1) return false;
    return true;
}
static stream_ticket *ticket_find(tdj_stream *s,uint64_t id) {
    if(!id) return NULL;
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++)
        if(atomic_load_explicit(&s->tickets[i].identity,memory_order_acquire)==id) return &s->tickets[i];
    return NULL;
}
uint64_t tdj_stream_reserved_pcm_bytes(void) { return atomic_load(&global_bytes); }
tdj_asset *tdj_asset_open_stream(const char *path,uint64_t frames,double rate,
    const tdj_stream_config *config,int32_t *error) {
    int status=TDJ_STREAM_INVALID,fd=-1; tdj_asset *a=NULL; tdj_stream *s=NULL; bool reserved=false;
    if(!path || !frames || frames>INT64_MAX/8 || !isfinite(rate) || rate<8000 || rate>384000 ||
        !config || !isfinite(config->output_rate) || config->output_rate<8000 || config->output_rate>384000 ||
        !isfinite(config->forward_seconds) || config->forward_seconds<0 || config->forward_seconds>30 ||
        !isfinite(config->backward_seconds) || config->backward_seconds<0 || config->backward_seconds>30 ||
        !config->max_output_frames || config->max_output_frames>65536) goto fail;
    fd=open(path,O_RDONLY); if(fd<0) { status=TDJ_STREAM_IO_ERROR;goto fail; }
    struct stat info;
    if(fstat(fd,&info) || info.st_size<0 || (uint64_t)info.st_size!=frames*8) { status=TDJ_STREAM_IO_ERROR;goto fail; }
    uint64_t used=atomic_load(&global_bytes);
    do { if(used>TDJ_STREAM_GLOBAL_PCM_BYTES-POOL_BYTES) { status=TDJ_STREAM_CAPACITY;goto fail; } }
    while(!atomic_compare_exchange_weak(&global_bytes,&used,used+POOL_BYTES));
    reserved=true; a=calloc(1,sizeof(*a));s=calloc(1,sizeof(*s));
    if(!a || !s) { status=TDJ_STREAM_CAPACITY;goto fail; }
    s->fd=fd;s->config=*config;s->bootstrap=-1;s->reader_table=-1;s->reader_block=UINT64_MAX;
    atomic_init(&s->maximum_output_frames,config->max_output_frames);
    atomic_init(&s->pending,-1);atomic_init(&s->current,-1);
    atomic_init(&s->first_missing_output_frame,UINT64_MAX);
    atomic_init(&s->minimum_forward_ready_frames,UINT64_MAX);
    if(!atomic_is_lock_free(&s->maximum_output_frames) || !atomic_is_lock_free(&s->pending) || !atomic_is_lock_free(&s->engine) ||
        !atomic_is_lock_free(&s->cancelled) || !atomic_is_lock_free(&s->tickets[0].identity) ||
        !atomic_is_lock_free(&s->tickets[0].refs) || !atomic_is_lock_free(&s->source_read_misses)) {
        status=TDJ_STREAM_UNSUPPORTED_ATOMICS;goto fail;
    }
    if(!tdj_keylock_limits(config->output_rate,&s->input_latency,&s->output_latency,&s->seek_length)) goto fail;
    s->pool=malloc((size_t)POOL_BYTES);if(!s->pool) { status=TDJ_STREAM_CAPACITY;goto fail; }
    memset(s->pool,0,(size_t)POOL_BYTES);
    s->test_io.fail_after_bytes=UINT64_MAX;
    a->stream=s;a->frames=frames;a->rate=rate;a->bytes=(size_t)(frames*8);
    if(error)*error=TDJ_STREAM_READY;return a;
fail:
    if(fd>=0)close(fd);if(s){free(s->pool);free(s);}free(a);
    if(reserved)atomic_fetch_sub(&global_bytes,POOL_BYTES);
    if(error)*error=status;return NULL;
}
void tdj_stream_destroy(tdj_asset *a) {
    tdj_stream *s=a->stream;if(!s)return;
    close(s->fd);free(s->pool);free(s);a->stream=NULL;atomic_fetch_sub(&global_bytes,POOL_BYTES);
}
uint64_t tdj_asset_request_prepare(tdj_asset *a,const tdj_stream_request *r) {
    if(!a || !a->stream || !valid_request(a,r))return 0;
    tdj_stream *s=a->stream;if(atomic_load(&s->cancelled))return 0;
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++) {
        stream_ticket *t=&s->tickets[i];
        if(atomic_load_explicit(&t->identity,memory_order_acquire))continue;
        unsigned empty=0;
        if(!atomic_compare_exchange_strong(&t->refs,&empty,4))continue;
        uint64_t id=atomic_fetch_add(&global_ticket,1);
        if(!id){atomic_store(&t->refs,0);return 0;}
        atomic_store(&t->identity,id);
        t->request=*r;atomic_store(&t->consume_serial,0);atomic_store(&t->status,TDJ_STREAM_PENDING);
        atomic_store_explicit(&t->refs,1,memory_order_release);return id;
    }
    return 0;
}
int32_t tdj_asset_prepare_status(const tdj_asset *a,uint64_t id) {
    if(!a || !a->stream)return TDJ_STREAM_INVALID;
    stream_ticket *t=ticket_find(a->stream,id);if(!t)return TDJ_STREAM_INVALID;
    if(atomic_load(&a->stream->cancelled))return TDJ_STREAM_CANCELLED;
    if(atomic_load_explicit(&t->consume_serial,memory_order_acquire))return TDJ_STREAM_INVALID;
    int status=atomic_load_explicit(&t->status,memory_order_acquire);
    if(status==TDJ_STREAM_READY && (atomic_load_explicit(&a->stream->engine,memory_order_acquire)==WORKER_OWNER ||
        (atomic_load(&a->stream->current)<0 && atomic_load(&a->stream->pending)<0)))return TDJ_STREAM_PENDING;
    return status;
}
void tdj_asset_release_preparation(tdj_asset *a,uint64_t id) {
    if(!a || !a->stream)return;stream_ticket *t=ticket_find(a->stream,id);
    if(t)atomic_fetch_and_explicit(&t->refs,~1u,memory_order_release);
}
int tdj_stream_check_ticket(tdj_asset *a,uint64_t id,uint64_t generation) {
    if(a && a->stream && atomic_load_explicit(&a->stream->cancelled,memory_order_acquire))return TDJ_STALE;
    if(!id)return TDJ_OK;
    if(!a || !a->stream)return TDJ_STALE;
    stream_ticket *t=ticket_find(a->stream,id);
    if(!t || !atomic_load_explicit(&t->refs,memory_order_acquire) || t->request.deck_generation!=generation ||
        atomic_load_explicit(&t->consume_serial,memory_order_acquire))return TDJ_STALE;
    int status=atomic_load_explicit(&t->status,memory_order_acquire);
    return status==TDJ_STREAM_READY ? TDJ_OK:status==TDJ_STREAM_CAPACITY ? TDJ_SOURCE_CAPACITY:TDJ_SOURCE_COLD;
}
void tdj_stream_claim(tdj_asset *a,uint64_t id) {
    if(a && a->stream){stream_ticket *t=ticket_find(a->stream,id);if(t){
        atomic_fetch_or(&t->refs,2);uint64_t unused=0;
        atomic_compare_exchange_strong_explicit(&t->consume_serial,&unused,tdj_stream_next_request(a),memory_order_release,memory_order_relaxed);
    }}
}
void tdj_stream_release_claim(tdj_asset *a,uint64_t id) {
    if(a && a->stream){stream_ticket *t=ticket_find(a->stream,id);if(t)atomic_fetch_and_explicit(&t->refs,~2u,memory_order_release);}
}
static bool add_range(tdj_asset *a,tdj_stream_request *r,double first,double end) {
    first=fmax(0,floor(first));end=fmin((double)a->frames,ceil(end));
    if(end<=first)return true;
    if(r->count>=TDJ_STREAM_MAX_RANGES)return false;
    r->ranges[r->count++]=(tdj_stream_range){(uint64_t)first,(uint64_t)end,0,0};return true;
}
static bool target_region(tdj_asset *a,const tdj_stream_target *t,bool reserve,double position,
    bool wrap,uint32_t maximum_frames,tdj_stream_request *r) {
    tdj_stream *s=a->stream;double step=a->rate/s->config.output_rate;
    double speed=t->source_speed, travel=maximum_frames*step*speed*fmax(1,fabs(t->performance_rate));
    if(!isfinite(travel))return add_range(a,r,0,(double)a->frames);
    double history=t->keylock && t->performance_rate==1 ? s->seek_length*step:0;
    double ahead=t->keylock && t->performance_rate==1 ?
        (s->input_latency+speed*s->output_latency+64*speed+2)*step:2;
    double back=history+(t->performance_rate<0 ? travel:0)+2;
    ahead+=t->performance_rate>=0 ? travel:0;
    if(reserve){back=fmax(back,s->config.backward_seconds*a->rate);ahead=fmax(ahead,s->config.forward_seconds*a->rate);}
    double first=position-back,end=position+ahead+2;
    double lo=t->loop_start,hi=t->loop_end,length=hi-lo;
    if(!wrap || length<=0)return add_range(a,r,first,end);
    if(t->performance_rate!=1 && (position<lo || position>=hi) && !add_range(a,r,position,position+2))return false;
    if(end-first>=length)return add_range(a,r,lo,hi+1);
    double offset=fmod(first-lo,length);if(offset<0)offset+=length;
    first=lo+offset;double remaining=end-(position-back);
    if(first+remaining<=hi)return add_range(a,r,first,first+remaining+1);
    return add_range(a,r,first,hi) && add_range(a,r,lo,lo+first+remaining-hi+1);
}
int tdj_stream_plan(tdj_asset *a,const tdj_stream_target *t,uint64_t request,uint64_t gen,
    bool reserve,tdj_stream_request *r) {
    if(!a || !a->stream || !t || !r || !request || !gen || !isfinite(t->position) || t->position<0 ||
        t->position>a->frames || !isfinite(t->source_speed) || t->source_speed<=0 ||
        !isfinite(t->performance_rate) || fabs(t->performance_rate)>4 ||
        !isfinite(t->loop_start) || !isfinite(t->loop_end) || t->loop_start<0 || t->loop_end>a->frames ||
        !isfinite(t->continuing_position) || t->keylock>1 || t->reserve_continuing>1 ||
        (t->keylock && (t->source_speed<0.125 || t->source_speed>8)))return TDJ_STREAM_INVALID;
    memset(r,0,sizeof(*r));r->request_id=request;r->deck_generation=gen;
    uint32_t maximum_frames=atomic_load_explicit(&a->stream->maximum_output_frames,memory_order_acquire);
    if(!target_region(a,t,reserve,t->position,true,maximum_frames,r))return TDJ_STREAM_CAPACITY;
    if(t->reserve_continuing) {
        tdj_stream_target continuing=*t;continuing.performance_rate=1;
        if(!target_region(a,&continuing,reserve,fmax(0,fmin((double)a->frames-1,t->continuing_position)),false,maximum_frames,r))return TDJ_STREAM_CAPACITY;
    }
    return r->count ? TDJ_STREAM_READY:TDJ_STREAM_INVALID;
}
// Bound the published working set over unchanged future trajectories. No
// enumeration of track blocks, allocation, IO or worker access occurs here.
typedef struct {
    double first,end,velocity;
    uint64_t envelope_first,envelope_end,maximum;
    uint32_t timeline;
    bool translating;
    uint64_t fixed_first[3],fixed_end[3];unsigned fixed_count;
} future_region;
typedef struct { uint64_t first,end; } block_interval;
static uint64_t block_union(block_interval *ranges,unsigned count) {
    for(unsigned i=1;i<count;i++) {
        block_interval value=ranges[i];unsigned j=i;
        while(j && ranges[j-1].first>value.first){ranges[j]=ranges[j-1];--j;}ranges[j]=value;
    }
    uint64_t total=0,first=0,end=0;
    for(unsigned i=0;i<count;i++) {
        if(ranges[i].first>=ranges[i].end)continue;
        if(end && ranges[i].first>end){total+=end-first;first=ranges[i].first;end=ranges[i].end;}
        else {if(!end)first=ranges[i].first;if(ranges[i].end>end)end=ranges[i].end;}
    }
    return total+end-first;
}
static block_interval clipped_blocks(tdj_asset *a,double first,double end) {
    first=fmax(0,fmin((double)a->frames,floor(first)));
    end=fmax(first,fmin((double)a->frames,ceil(end)));
    if(end<=first)return (block_interval){0,0};
    return (block_interval){(uint64_t)first/TDJ_STREAM_BLOCK_FRAMES,
        ((uint64_t)end+TDJ_STREAM_BLOCK_FRAMES-1)/TDJ_STREAM_BLOCK_FRAMES};
}
static uint64_t span_blocks(tdj_asset *a,double span,unsigned margins) {
    uint64_t file_blocks=(a->frames+TDJ_STREAM_BLOCK_FRAMES-1)/TDJ_STREAM_BLOCK_FRAMES;
    if(!isfinite(span) || span>=a->frames)return file_blocks;
    double blocks=ceil(fmax(0,span)/TDJ_STREAM_BLOCK_FRAMES)+margins;
    return blocks>=file_blocks ? file_blocks:(uint64_t)blocks;
}
static future_region make_future_region(tdj_asset *a,const tdj_stream_target *target,
    double position,bool wrap,bool moving,double future_hi,uint32_t timeline,uint32_t frames) {
    tdj_stream *s=a->stream;
    double step=a->rate/s->config.output_rate,speed=target->source_speed;
    double travel=frames*step*speed*fmax(1,fabs(target->performance_rate));
    double history=target->keylock && target->performance_rate==1 ? s->seek_length*step:0;
    double ahead=target->keylock && target->performance_rate==1 ?
        (s->input_latency+speed*s->output_latency+64*speed+2)*step:2;
    double back=history+(target->performance_rate<0 ? travel:0)+2;
    ahead+=target->performance_rate>=0 ? travel:0;
    bool loop=wrap && target->loop_end>target->loop_start;
    double velocity=moving ? speed*step*target->performance_rate:0;
    future_region r={.first=position-back,.end=position+ahead+2,.velocity=velocity,.timeline=timeline};
    if(!moving || target->performance_rate==0) {
        tdj_stream_request fixed={0};target_region(a,target,false,position,wrap,frames,&fixed);
        block_interval intervals[TDJ_STREAM_MAX_RANGES];
        for(unsigned n=0;n<fixed.count;n++) {
            intervals[n]=clipped_blocks(a,fixed.ranges[n].first,fixed.ranges[n].end);
            if(n<3){r.fixed_first[n]=intervals[n].first;r.fixed_end[n]=intervals[n].end;r.fixed_count++;}
        }
        r.maximum=block_union(intervals,fixed.count);
        block_interval envelope=clipped_blocks(a,position-back,position+ahead+2);
        if(loop)envelope=clipped_blocks(a,fmin(target->loop_start,position),fmax(target->loop_end+1,position+2));
        r.envelope_first=envelope.first;r.envelope_end=envelope.end;
        return r;
    }
    double lo=velocity<0 ? 0:position,hi=velocity<0 ? position:fmin((double)a->frames-1,future_hi);
    block_interval envelope=clipped_blocks(a,lo-back,hi+ahead+2);
    if(loop) {
        envelope=clipped_blocks(a,target->loop_start,target->loop_end+1);
        uint64_t width=span_blocks(a,back+ahead+3,2);
        r.maximum=fmin(width,envelope.end-envelope.first);
        if(target->performance_rate!=1 && (position<target->loop_start || position>=target->loop_end)) {
            r.maximum+=2;
            envelope=clipped_blocks(a,fmin(target->loop_start,position),fmax(target->loop_end+1,position+2));
        }
    } else {
        r.translating=true;
        r.maximum=span_blocks(a,back+ahead+4,1);
        if(r.maximum>envelope.end-envelope.first)r.maximum=envelope.end-envelope.first;
    }
    r.envelope_first=envelope.first;r.envelope_end=envelope.end;
    return r;
}
int tdj_stream_future_capacity(tdj_asset *a,const tdj_stream_future *targets,unsigned count,uint32_t override) {
    if(!a || !a->stream)return TDJ_OK;
    if(count>4)return TDJ_SOURCE_CAPACITY;
    uint32_t frames=override ? override:atomic_load_explicit(&a->stream->maximum_output_frames,memory_order_acquire);
    future_region regions[8];unsigned n=0;
    for(unsigned i=0;i<count;i++) {
        const tdj_stream_future *future=&targets[i];const tdj_stream_target *t=&future->target;
        double hi=a->frames-1;
        regions[n++]=make_future_region(a,t,t->position,true,future->moving,hi,future->timeline,frames);
        if(t->reserve_continuing) {
            tdj_stream_target continuing=*t;continuing.performance_rate=1;
            double position=fmax(0,fmin((double)a->frames-1,t->continuing_position));
            if(future->moving==1 && t->loop_end<=t->loop_start && t->performance_rate>0)
                hi=fmin(hi,position+fmax(0,a->frames-t->position)/t->performance_rate);
            regions[n++]=make_future_region(a,&continuing,position,false,future->continuing_moves,hi,future->continuing_timeline,frames);
        }
    }
    block_interval envelopes[24];unsigned envelope_count=0;
    for(unsigned i=0;i<n;i++) {
        if(regions[i].fixed_count)for(unsigned j=0;j<regions[i].fixed_count;j++)
            envelopes[envelope_count++]=(block_interval){regions[i].fixed_first[j],regions[i].fixed_end[j]};
        else envelopes[envelope_count++]=(block_interval){regions[i].envelope_first,regions[i].envelope_end};
    }
    uint64_t envelope_blocks=block_union(envelopes,envelope_count),sum=0;bool consumed[8]={0};
    for(unsigned i=0;i<n;i++) {
        if(consumed[i])continue;consumed[i]=true;
        if(!regions[i].translating){sum+=regions[i].maximum;continue;}
        // Equal unbounded velocities preserve source offsets. Merge their
        // windows rather than assuming identical normal-rate paths diverge.
        double first[8],end[8];unsigned members=0;
        first[members]=regions[i].first;end[members++]=regions[i].end;
        uint64_t independent=regions[i].maximum;
        for(unsigned j=i+1;j<n;j++)if(!consumed[j] && regions[j].translating &&
            regions[j].velocity==regions[i].velocity && regions[j].timeline==regions[i].timeline) {
            consumed[j]=true;first[members]=regions[j].first;end[members++]=regions[j].end;independent+=regions[j].maximum;
        }
        for(unsigned j=1;j<members;j++){double f=first[j],e=end[j];unsigned k=j;while(k&&first[k-1]>f){first[k]=first[k-1];end[k]=end[k-1];--k;}first[k]=f;end[k]=e;}
        uint64_t merged=0;double lo=first[0],hi=end[0];
        for(unsigned j=1;j<members;j++) {
            if(first[j]>hi){merged+=span_blocks(a,hi-lo+2,1);lo=first[j];hi=end[j];}
            else hi=fmax(hi,end[j]);
        }
        merged+=span_blocks(a,hi-lo+2,1);sum+=fmin(merged,independent);
    }
    return fmin(sum,envelope_blocks)<=TABLE_BLOCKS ? TDJ_OK:TDJ_SOURCE_CAPACITY;
}

int32_t tdj_asset_plan_target(const tdj_asset *a,const tdj_stream_target *t,uint64_t request,uint64_t gen,tdj_stream_request *r) {
    return tdj_stream_plan((tdj_asset *)a,t,request,gen,true,r);
}
int32_t tdj_asset_plan_minimum(const tdj_asset *a,const tdj_stream_target *t,uint64_t request,uint64_t gen,tdj_stream_request *r) {
    return tdj_stream_plan((tdj_asset *)a,t,request,gen,false,r);
}
int tdj_stream_attach(tdj_asset *a,const void *engine) {
    if(!a || !a->stream)return TDJ_OK;
    uintptr_t current=atomic_load(&a->stream->engine),value=(uintptr_t)engine;
    if(current==value || (!current && atomic_compare_exchange_strong(&a->stream->engine,&current,value)))return TDJ_OK;
    return current==WORKER_OWNER ? TDJ_SOURCE_COLD:TDJ_PROTECTED;
}
void tdj_stream_detach(tdj_asset *a,const void *engine) {
    if(a && a->stream && atomic_load(&a->stream->engine)==(uintptr_t)engine) {
        a->stream->render_need.count=0;uintptr_t expected=(uintptr_t)engine;
        atomic_store(&a->stream->render_started,false);
        atomic_compare_exchange_strong(&a->stream->engine,&expected,0);
    }
}
void tdj_stream_render_begin(tdj_asset *a,uint64_t output) {
    if(!a || !a->stream)return;tdj_stream *s=a->stream;
    int next=atomic_exchange_explicit(&s->pending,-1,memory_order_acquire);
    if(next>=0) {
        bool covered=true;stream_table *candidate=&s->tables[next];
        for(unsigned i=0;i<s->render_need.count && covered;i++) {
            tdj_stream_range *r=&s->render_need.ranges[i];
            uint64_t first=r->first/TDJ_STREAM_BLOCK_FRAMES,last=(r->end-1)/TDJ_STREAM_BLOCK_FRAMES;
            if(last-first>=TABLE_BLOCKS){covered=false;break;}
            for(uint64_t b=first;b<=last;b++)if(table_find(candidate,b)<0){covered=false;break;}
        }
        if(!covered){atomic_store_explicit(&candidate->state,4,memory_order_release);next=-1;}
    }
    if(next>=0) {
        int old=atomic_load_explicit(&s->current,memory_order_relaxed);
        atomic_store(&s->tables[next].state,3);atomic_store_explicit(&s->current,next,memory_order_release);
        if(old>=0)atomic_store_explicit(&s->tables[old].state,4,memory_order_release);
    }
    s->reader_table=atomic_load_explicit(&s->current,memory_order_relaxed);
    s->reader_data=NULL;s->reader_block=UINT64_MAX;s->read_failed=false;s->output_frame=output;
}
void tdj_stream_render_require(tdj_asset *a,const tdj_stream_request *r) {
    if(a && a->stream)a->stream->render_need=*r;
}
// The current callback pins its immutable source table until render_end.
// A missing span has no side effects. The scalar reader records each miss.
const float *tdj_stream_render_span(void *context,uint64_t frame,uint32_t *count) {
    tdj_asset *a=context;
    *count=0;
    if(!a || !a->stream || frame>=a->frames)return NULL;
    tdj_stream *s=a->stream;
    uint64_t block=frame/TDJ_STREAM_BLOCK_FRAMES;
    const float *data=NULL;
    if(s->reader_block==block && s->reader_data)data=s->reader_data;
    else {
        int slot=s->reader_table>=0 ? table_find(&s->tables[s->reader_table],block):-1;
        if(slot<0)return NULL;
        data=s->pool+(size_t)slot*TDJ_STREAM_BLOCK_FRAMES*2;
    }
    uint32_t offset=(uint32_t)(frame%TDJ_STREAM_BLOCK_FRAMES);
    uint64_t remaining=a->frames-frame;
    *count=(uint32_t)(remaining<TDJ_STREAM_BLOCK_FRAMES-offset ? remaining:TDJ_STREAM_BLOCK_FRAMES-offset);
    return data+(size_t)offset*2;
}
bool tdj_stream_render_read_stereo(void *context,uint64_t frame,float *l,float *r) {
    tdj_asset *a=context;tdj_stream *s=a->stream;
    if(frame>=a->frames){*l=*r=0;return true;}
    uint64_t block=frame/TDJ_STREAM_BLOCK_FRAMES;
    if(s->reader_block!=block || !s->reader_data) {
        int slot=s->reader_table>=0 ? table_find(&s->tables[s->reader_table],block):-1;
        if(slot<0) {
            *l=*r=0;s->read_failed=true;atomic_fetch_add_explicit(&s->source_read_misses,1,memory_order_relaxed);
            atomic_store_explicit(&s->latest_missing_source_frame,frame,memory_order_relaxed);return false;
        }
        s->reader_data=s->pool+(size_t)slot*TDJ_STREAM_BLOCK_FRAMES*2;s->reader_block=block;
    }
    unsigned offset=(unsigned)(frame%TDJ_STREAM_BLOCK_FRAMES)*2;
    *l=s->reader_data[offset];*r=s->reader_data[offset+1];return true;
}
bool tdj_stream_read_failed(tdj_asset *a){
    if(!a || !a->stream)return false;bool failed=a->stream->read_failed;a->stream->read_failed=false;return failed;
}
void tdj_stream_render_end(tdj_asset *a,uint64_t missing) {
    if(!a || !a->stream || !missing)return;tdj_stream *s=a->stream;
    atomic_fetch_add_explicit(&s->missing_output_frames,missing,memory_order_relaxed);
}
void tdj_stream_missing_frame(tdj_asset *a,uint64_t frame) {
    if(a && a->stream){uint64_t no=UINT64_MAX;atomic_compare_exchange_strong(&a->stream->first_missing_output_frame,&no,frame);}
}
void tdj_stream_mark_started(tdj_asset *a){if(a && a->stream)atomic_store_explicit(&a->stream->render_started,true,memory_order_release);}
bool tdj_stream_can_render(tdj_asset *a,uint32_t count) {
    return !a || !a->stream || count<=atomic_load_explicit(&a->stream->maximum_output_frames,memory_order_acquire);
}
void tdj_stream_set_maximum_output_frames(tdj_asset *a,uint32_t frames) {
    if(a && a->stream)atomic_store_explicit(&a->stream->maximum_output_frames,frames,memory_order_release);
}
void tdj_stream_observe_reserve(tdj_asset *a,double position,bool low) {
    if(!a || !a->stream || !isfinite(position) || position<0 || position>=a->frames)return;
    tdj_stream *s=a->stream;uint64_t frame=(uint64_t)position,block=frame/TDJ_STREAM_BLOCK_FRAMES,end=frame;
    int index=atomic_load_explicit(&s->current,memory_order_relaxed);
    if(index>=0)for(unsigned n=0;n<TABLE_BLOCKS;n++,block++) {
        if(table_find(&s->tables[index],block)<0)break;
        end=(block+1)*TDJ_STREAM_BLOCK_FRAMES;if(end>=a->frames){end=a->frames;break;}
    }
    uint64_t ready=end-frame,previous=atomic_load_explicit(&s->minimum_forward_ready_frames,memory_order_relaxed);
    if(ready<previous)atomic_store_explicit(&s->minimum_forward_ready_frames,ready,memory_order_relaxed);
    if(low)atomic_fetch_add_explicit(&s->low_reserve_callbacks,1,memory_order_relaxed);
}
void tdj_stream_render_request(tdj_asset *a,const tdj_stream_request *r) {
    if(!a || !a->stream)return;tdj_stream *s=a->stream;
    for(int i=0;i<3;i++) {
        int state=atomic_load_explicit(&s->mailbox[i].state,memory_order_acquire);
        if(state!=0 && state!=2)continue;
        if(!atomic_compare_exchange_strong_explicit(&s->mailbox[i].state,&state,1,memory_order_acquire,memory_order_relaxed))continue;
        s->mailbox[i].request=*r;s->mailbox[i].request.request_id=++s->consumer_request_serial;
        atomic_store_explicit(&s->mailbox[i].state,2,memory_order_release);return;
    }
    atomic_fetch_add_explicit(&s->request_backpressure,1,memory_order_relaxed);
}
bool tdj_stream_covers(tdj_asset *a,const tdj_stream_request *r) {
    if(!a || !a->stream)return true;tdj_stream *s=a->stream;
    int current=atomic_load_explicit(&s->current,memory_order_relaxed);
    if(current<0)return false;stream_table *t=&s->tables[current];
    for(unsigned i=0;i<r->count;i++) {
        if(r->ranges[i].priority)continue;
        uint64_t first=r->ranges[i].first/TDJ_STREAM_BLOCK_FRAMES,last=(r->ranges[i].end-1)/TDJ_STREAM_BLOCK_FRAMES;
        if(last-first>=TABLE_BLOCKS)return false;
        for(uint64_t b=first;b<=last;b++)if(table_find(t,b)<0)return false;
    }
    return true;
}
void tdj_stream_cold(tdj_asset *a){if(a && a->stream)atomic_fetch_add(&a->stream->rejected_cold_commands,1);}
uint64_t tdj_stream_acknowledged_request(tdj_asset *a) {
    if(!a || !a->stream)return UINT64_MAX;int i=atomic_load(&a->stream->current);
    return i>=0 ? a->stream->tables[i].request_id:0;
}
uint64_t tdj_stream_next_request(tdj_asset *a){return a && a->stream ? a->stream->consumer_request_serial+1:UINT64_MAX;}
uint64_t tdj_stream_latest_request(tdj_asset *a){return a && a->stream ? a->stream->consumer_request_serial:UINT64_MAX;}
static bool add_blocks(uint64_t *ids,unsigned *count,const tdj_stream_request *r,bool optional) {
    for(unsigned i=0;i<r->count;i++) {
        if((r->ranges[i].priority!=0)!=optional)continue;
        uint64_t first=r->ranges[i].first/TDJ_STREAM_BLOCK_FRAMES,last=(r->ranges[i].end-1)/TDJ_STREAM_BLOCK_FRAMES;
        if(last-first>=TABLE_BLOCKS)return false;
        for(uint64_t id=first;id<=last;id++) {
            bool found=false;for(unsigned n=0;n<*count;n++)if(ids[n]==id){found=true;break;}
            if(found)continue;if(*count>=TABLE_BLOCKS)return false;ids[(*count)++]=id;
        }
    }
    return true;
}
static int read_block(tdj_asset *a,unsigned slot,uint64_t id) {
    tdj_stream *s=a->stream;uint64_t first=id*TDJ_STREAM_BLOCK_FRAMES;
    size_t bytes=(size_t)fmin(TDJ_STREAM_BLOCK_FRAMES,a->frames-first)*8,done=0;
    char *destination=(char *)(s->pool+(size_t)slot*TDJ_STREAM_BLOCK_FRAMES*2);
    while(done<bytes) {
        if(atomic_load_explicit(&s->cancelled,memory_order_acquire))return TDJ_STREAM_CANCELLED;
        if(s->test_io.delay_microseconds_per_read)usleep(s->test_io.delay_microseconds_per_read);
        if(atomic_load_explicit(&s->cancelled,memory_order_acquire))return TDJ_STREAM_CANCELLED;
        size_t amount=bytes-done;
        if(s->test_io.maximum_bytes_per_read && amount>s->test_io.maximum_bytes_per_read)amount=s->test_io.maximum_bytes_per_read;
        if(s->bytes_read_worker>=s->test_io.fail_after_bytes)return TDJ_STREAM_IO_ERROR;
        uint64_t allowed=s->test_io.fail_after_bytes-s->bytes_read_worker;if(amount>allowed)amount=(size_t)allowed;
        if(!amount)return TDJ_STREAM_IO_ERROR;
        ssize_t got=pread(s->fd,destination+done,amount,(off_t)(first*8+done));
        if(got<=0)return TDJ_STREAM_IO_ERROR;
        done+=(size_t)got;s->bytes_read_worker+=(uint64_t)got;
    }
    for(size_t i=0;i<bytes/sizeof(float);i++)if(!isfinite(((float *)destination)[i]))return TDJ_STREAM_IO_ERROR;
    s->block_ids[slot]=id;s->block_valid[slot]=true;atomic_store(&s->bytes_read,s->bytes_read_worker);return TDJ_STREAM_READY;
}
static unsigned referenced_tickets(tdj_stream *s) {
    unsigned mask=0;
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++)
        if(atomic_load_explicit(&s->tickets[i].refs,memory_order_acquire)&3)mask|=1u<<i;
    return mask;
}
static bool service_has_new_work(tdj_stream *s,unsigned ticket_mask) {
    for(int i=0;i<3;i++)if(atomic_load_explicit(&s->mailbox[i].state,memory_order_acquire)==2)return true;
    return referenced_tickets(s)!=ticket_mask;
}
/* The live publication replaces an accepted ticket's ranges even when its
   producer has not collected the acknowledgement. Identity remains until release. */
static bool ticket_needs_ranges(tdj_stream *s,stream_ticket *t) {
    if(!(atomic_load_explicit(&t->refs,memory_order_acquire)&3))return false;
    uint64_t consumed=atomic_load_explicit(&t->consume_serial,memory_order_acquire);
    return !consumed || s->live.request_id<consumed;
}
static bool table_covers_required(const stream_table *table,const tdj_stream_request *request) {
    for(unsigned i=0;i<request->count;i++) {
        const tdj_stream_range *r=&request->ranges[i];if(r->priority)continue;
        uint64_t first=r->first/TDJ_STREAM_BLOCK_FRAMES,last=(r->end-1)/TDJ_STREAM_BLOCK_FRAMES;
        if(last-first>=TABLE_BLOCKS)return false;
        for(uint64_t b=first;b<=last;b++)if(table_find(table,b)<0)return false;
    }
    return true;
}
static int service_impl(tdj_asset *a,unsigned budget) {
    tdj_stream *s=a->stream;
    if(atomic_load(&s->cancelled))return TDJ_STREAM_CANCELLED;
    atomic_store(&s->service_started,true);
    for(int i=0;i<3;i++)if(atomic_load_explicit(&s->tables[i].state,memory_order_acquire)==4)
        atomic_store(&s->tables[i].state,0);
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++) {
        stream_ticket *t=&s->tickets[i];
        if(atomic_load_explicit(&t->identity,memory_order_acquire) && !atomic_load_explicit(&t->refs,memory_order_acquire))
            atomic_store_explicit(&t->identity,0,memory_order_release);
    }
    for(int i=0;i<3;i++) {
        int expected=2;if(!atomic_compare_exchange_strong_explicit(&s->mailbox[i].state,&expected,3,memory_order_acquire,memory_order_relaxed))continue;
        if(s->mailbox[i].request.request_id>=s->live.request_id)s->live=s->mailbox[i].request;
        atomic_store_explicit(&s->mailbox[i].state,0,memory_order_release);
    }
    if(!s->live.count) {
        bool any=false;for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++)if(atomic_load_explicit(&s->tickets[i].refs,memory_order_acquire)&3){any=true;break;}
        if(!any)return TDJ_STREAM_READY;
    }
    int pending=atomic_load_explicit(&s->pending,memory_order_acquire);
    if(pending>=0) {
        stream_table *candidate=&s->tables[pending];
        bool obsolete=candidate->request_id<s->live.request_id || !table_covers_required(candidate,&s->live);
        if(!obsolete || !atomic_compare_exchange_strong_explicit(&s->pending,&pending,-1,memory_order_acq_rel,memory_order_acquire))
            return TDJ_STREAM_READY;
        /* The successful exchange owns this unpublished candidate exclusively. */
        atomic_store_explicit(&candidate->state,0,memory_order_release);
    }
    uint64_t ids[TABLE_BLOCKS];unsigned count=0;
    if(!add_blocks(ids,&count,&s->live,false)){atomic_fetch_add(&s->capacity_failures,1);return TDJ_STREAM_CAPACITY;}
    /* READY tickets are mandatory before new requests. */
    for(int ready=1;ready>=0;ready--)for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++) {
        stream_ticket *t=&s->tickets[i];if(!ticket_needs_ranges(s,t))continue;
        int status=atomic_load(&t->status);if((status==TDJ_STREAM_READY)!=ready || status<0)continue;
        unsigned before=count;
        if(!add_blocks(ids,&count,&t->request,false)) {
            count=before;
            /* A producer-only preparation may lose admission as playback moves.
               Report the revoked reservation instead of blocking live audio. */
            if(atomic_load_explicit(&t->refs,memory_order_acquire)&2) {
                atomic_fetch_add(&s->capacity_failures,1);return TDJ_STREAM_CAPACITY;
            }
            atomic_store_explicit(&t->status,TDJ_STREAM_CAPACITY,memory_order_release);
            atomic_fetch_add(&s->capacity_failures,1);
        }
    }
    unsigned mandatory=count;
    (void)add_blocks(ids,&count,&s->live,true);
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++)if(ticket_needs_ranges(s,&s->tickets[i]) && atomic_load(&s->tickets[i].status)>=0)
        (void)add_blocks(ids,&count,&s->tickets[i].request,true);
    int table=s->bootstrap;
    if(table<0)for(int i=0;i<3;i++)if(atomic_load(&s->tables[i].state)==0){table=i;atomic_store(&s->tables[i].state,1);break;}
    if(table<0){atomic_fetch_add(&s->retirement_backpressure,1);return TDJ_STREAM_READY;}
    stream_table *draft=&s->tables[table];memset(draft->keys,0,sizeof(draft->keys));draft->count=0;
    bool used[TDJ_STREAM_BLOCK_COUNT]={false};
    for(int i=0;i<3;i++)if(i!=table && atomic_load_explicit(&s->tables[i].state,memory_order_acquire)!=0)
        for(unsigned h=0;h<HASH_SIZE;h++)if(s->tables[i].keys[h])used[s->tables[i].slots[h]]=true;
    for(unsigned b=0;b<TDJ_STREAM_BLOCK_COUNT;b++)if(s->block_valid[b])
        for(unsigned n=0;n<count;n++)if(s->block_ids[b]==ids[n]){used[b]=true;break;}
    unsigned reads=0,missing=0,mandatory_missing=0;
    unsigned ticket_mask=referenced_tickets(s);
    for(unsigned n=0;n<count;n++) {
        int slot=-1;
        for(unsigned b=0;b<TDJ_STREAM_BLOCK_COUNT;b++)if(s->block_valid[b] && s->block_ids[b]==ids[n]){slot=(int)b;break;}
        if(slot<0 && reads<budget) {
            for(unsigned b=0;b<TDJ_STREAM_BLOCK_COUNT;b++)if(!used[b]){slot=(int)b;break;}
            if(slot>=0) {
                s->block_valid[slot]=false;int result=read_block(a,(unsigned)slot,ids[n]);reads++;
                if(result<0){atomic_store(&draft->state,0);s->bootstrap=-1;
                    if(result==TDJ_STREAM_IO_ERROR)atomic_fetch_add(&s->io_errors,1);
                    for(unsigned t=0;t<TDJ_STREAM_MAX_TICKETS;t++)if(atomic_load(&s->tickets[t].refs)&3)atomic_store(&s->tickets[t].status,result);
                    return result;}
                // Finish describing cached data, then coalesce before another read.
                if(service_has_new_work(s,ticket_mask))budget=reads;
            }
        }
        if(slot>=0){used[slot]=true;table_add(draft,ids[n],(unsigned)slot);}
        else {missing++;if(n<mandatory)mandatory_missing++;}
    }
    if(!atomic_load_explicit(&s->render_started,memory_order_acquire) && mandatory_missing) {
        s->bootstrap=table;return TDJ_STREAM_PENDING;
    }
    s->bootstrap=-1;draft->serial=++s->table_serial;draft->request_id=s->live.request_id;
    atomic_store_explicit(&draft->state,2,memory_order_release);
    atomic_store_explicit(&s->pending,table,memory_order_release);
    atomic_store(&s->ready_table_serial,draft->serial);
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++) {
        stream_ticket *t=&s->tickets[i];if(!(atomic_load_explicit(&t->refs,memory_order_acquire)&3) || atomic_load(&t->status)<0)continue;
        bool complete=true;
        for(unsigned r=0;r<t->request.count && complete;r++)if(!t->request.ranges[r].priority)
            for(uint64_t b=t->request.ranges[r].first/TDJ_STREAM_BLOCK_FRAMES;b<=(t->request.ranges[r].end-1)/TDJ_STREAM_BLOCK_FRAMES;b++)
                if(table_find(draft,b)<0){complete=false;break;}
        if(complete)atomic_store_explicit(&t->status,TDJ_STREAM_READY,memory_order_release);
    }
    return missing ? TDJ_STREAM_PENDING:TDJ_STREAM_READY;
}
int32_t tdj_asset_service(tdj_asset *a,uint32_t blocks) {
    if(!a || !a->stream || !blocks || blocks>TDJ_STREAM_BLOCK_COUNT)return TDJ_STREAM_INVALID;
    tdj_stream *s=a->stream;bool work=s->bootstrap>=0;
    for(unsigned i=0;i<TDJ_STREAM_MAX_TICKETS;i++)if((atomic_load_explicit(&s->tickets[i].refs,memory_order_acquire)&3) &&
        atomic_load(&s->tickets[i].status)==TDJ_STREAM_PENDING){work=true;break;}
    uintptr_t expected=0;bool owns=work && atomic_compare_exchange_strong(&s->engine,&expected,WORKER_OWNER);
    if(owns) {
        int pending=atomic_exchange(&s->pending,-1),current=atomic_exchange(&s->current,-1);
        if(pending>=0)atomic_store(&s->tables[pending].state,0);
        if(current>=0)atomic_store(&s->tables[current].state,0);
        s->reader_table=-1;s->reader_data=NULL;
    }
    uint64_t start=nanos();int result=service_impl(a,blocks);uint64_t elapsed=nanos()-start;
    if(owns)atomic_store_explicit(&s->engine,0,memory_order_release);
    uint64_t previous=atomic_load(&a->stream->max_service_nanoseconds);
    if((uint64_t)elapsed>previous)atomic_store(&a->stream->max_service_nanoseconds,(uint64_t)elapsed);
    return result;
}
void tdj_asset_cancel_service(tdj_asset *a){if(a && a->stream)atomic_store(&a->stream->cancelled,true);}
int32_t tdj_asset_set_test_io(tdj_asset *a,const tdj_stream_test_io *io) {
    if(!a || !a->stream || !io || io->delay_microseconds_per_read>1000000 || atomic_load(&a->stream->service_started))return TDJ_STREAM_INVALID;
    a->stream->test_io=*io;return TDJ_STREAM_READY;
}
void tdj_asset_stream_telemetry(const tdj_asset *a,tdj_stream_telemetry *out) {
    if(!out)return;memset(out,0,sizeof(*out));out->global_reserved_pcm_bytes=atomic_load(&global_bytes);
    if(!a || !a->stream)return;const tdj_stream *s=a->stream;out->resident_pcm_bytes=POOL_BYTES;
#define COPY_COUNTER(name) out->name=atomic_load_explicit(&s->name,memory_order_relaxed)
    COPY_COUNTER(ready_table_serial);COPY_COUNTER(source_read_misses);COPY_COUNTER(missing_output_frames);
    COPY_COUNTER(first_missing_output_frame);COPY_COUNTER(latest_missing_source_frame);COPY_COUNTER(low_reserve_callbacks);
    COPY_COUNTER(rejected_cold_commands);COPY_COUNTER(io_errors);COPY_COUNTER(capacity_failures);
    COPY_COUNTER(retirement_backpressure);COPY_COUNTER(request_backpressure);COPY_COUNTER(bytes_read);
    COPY_COUNTER(max_service_nanoseconds);COPY_COUNTER(minimum_forward_ready_frames);
#undef COPY_COUNTER
}
