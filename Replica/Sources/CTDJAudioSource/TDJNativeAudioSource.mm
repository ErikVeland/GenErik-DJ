#import "TDJNativeAudioSource.h"
#if !__has_feature(objc_arc)
#error "TDJNativeAudioSource requires Objective-C ARC"
#endif
#include <atomic>
#include <new>
#include <cstring>
#include <sched.h>
#include <mach/mach_time.h>

static constexpr uint32_t closed_bit = uint32_t(1) << 31;
static constexpr uint32_t active_mask = closed_bit - 1;
static_assert(std::atomic<uint32_t>::is_always_lock_free);

struct NativeSourceContext {
    std::atomic<uint32_t> gate{0}, leases{0};
    tdj_engine *core;
    tdj_recording *recording;
    tdj_callback_metrics *metrics;
    uint32_t channels;
    bool traceCPU, validationSilence;
    NativeSourceContext(tdj_engine *e, tdj_recording *r, tdj_callback_metrics *m, uint32_t c, bool trace, bool silence)
        : core(e), recording(r), metrics(m), channels(c), traceCPU(trace), validationSilence(silence) {}
};
struct NativeSourceLease {
    NativeSourceContext *context;
    explicit NativeSourceLease(NativeSourceContext *value) : context(value) {
        context->leases.fetch_add(1, std::memory_order_relaxed);
    }
    NativeSourceLease(const NativeSourceLease &other) : context(other.context) {
        context->leases.fetch_add(1, std::memory_order_relaxed);
    }
    ~NativeSourceLease() {
        context->leases.fetch_sub(1, std::memory_order_release);
    }
};
static bool enter_source(NativeSourceContext *context) noexcept {
    // One serial consumer is the contract. A closed epoch or an unexpected
    // concurrent invocation is rejected without a software retry loop.
    // Strong CAS may use hardware retries; no wait-free guarantee is implied.
    uint32_t expected = 0;
    return context->gate.compare_exchange_strong(expected, 1, std::memory_order_acquire, std::memory_order_relaxed);
}
static void clear_output(AudioBufferList *output) noexcept {
    for (UInt32 i = 0; i < output->mNumberBuffers; i++)
        if (output->mBuffers[i].mData)
            std::memset(output->mBuffers[i].mData, 0, output->mBuffers[i].mDataByteSize);
}
extern "C" __attribute__((noinline)) OSStatus tdj_native_source_render(NativeSourceContext *context, BOOL *silence,
                                                                       const AudioTimeStamp *timestamp,
                                                                       AVAudioFrameCount count,
                                                                       AudioBufferList *output) {
    // The lease pins context, not the borrowed metrics object. Only inspect the
    // immutable pointer here; closed calls must never dereference retired owners.
    const auto metrics = context->metrics;
    const uint64_t began = metrics ? mach_absolute_time() : 0;
    if (!enter_source(context)) {
        clear_output(output);
        *silence = YES;
        return noErr;
    }
    // CPU timing begins after admission. Wall timing includes admission and both
    // CPU clock reads, using the earlier plain Mach timestamp at end[_cpu].
    if (metrics && context->traceCPU)
        (void)tdj_callback_metrics_begin_cpu(metrics);
    bool rendered = false, invalid = false;
    if (output->mNumberBuffers != context->channels || !output->mBuffers[0].mData || !output->mBuffers[1].mData)
        invalid = true;
    else if (context->channels == 4) {
        if (!output->mBuffers[2].mData || !output->mBuffers[3].mData)
            invalid = true;
        else
            rendered =
                tdj_render_recorded_buses(context->core, context->recording, count, (float *)output->mBuffers[0].mData,
                                          (float *)output->mBuffers[1].mData, (float *)output->mBuffers[2].mData,
                                          (float *)output->mBuffers[3].mData);
    } else if (context->channels == 2)
        rendered =
            tdj_render_recorded_buses(context->core, context->recording, count, (float *)output->mBuffers[0].mData,
                                      (float *)output->mBuffers[1].mData, nullptr, nullptr);
    else
        invalid = true;
    if (invalid) {
        if (metrics)
            tdj_callback_metrics_failure(metrics);
        clear_output(output);
        *silence = YES;
    } else {
        if (!rendered && metrics)
            tdj_callback_metrics_failure(metrics);
        if (context->validationSilence)
            clear_output(output);
        *silence = context->validationSilence ? YES : NO;
    }
    if (metrics) {
        const bool valid = (timestamp->mFlags & kAudioTimeStampSampleTimeValid) != 0;
        if (context->traceCPU)
            tdj_callback_metrics_end_cpu(metrics, began, count, timestamp->mSampleTime, valid);
        else
            tdj_callback_metrics_end(metrics, began, count, timestamp->mSampleTime, valid);
    }
    context->gate.fetch_sub(1, std::memory_order_release);
    return noErr;
}

@interface NativeSourceRetirement : NSObject {
  @public
    NativeSourceContext *context;
    id keepAlive;
    AVAudioSourceNode *node;
    AVAudioSourceNodeRenderBlock block;
}
@end
@implementation NativeSourceRetirement
@end
static dispatch_queue_t retirement_queue() {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      auto attributes =
          dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL, QOS_CLASS_BACKGROUND, 0);
      queue = dispatch_queue_create("org.generikdj.native-source-retirement", attributes);
    });
    return queue;
}
static dispatch_block_t background_cleanup(dispatch_block_t work) {
    return dispatch_block_create_with_qos_class(DISPATCH_BLOCK_ENFORCE_QOS_CLASS, QOS_CLASS_BACKGROUND, 0, work);
}
static constexpr uint32_t maximum_reap_delay_ms = 1000;
static uint32_t next_reap_delay_ms(uint32_t delay) noexcept {
    return delay >= maximum_reap_delay_ms / 2 ? maximum_reap_delay_ms : delay * 2;
}
static void reap_source(NativeSourceRetirement *retirement, uint32_t delay_ms) {
    auto context = retirement->context;
    const bool quiet = (context->gate.load(std::memory_order_acquire) & active_mask) == 0;
    // Release owners at the first quiet observation, independently of leases.
    // A long-held external block retains only the closed context tombstone.
    if (quiet)
        retirement->keepAlive = nil;
    if (quiet && context->leases.load(std::memory_order_acquire) == 0) {
        retirement->context = nullptr;
        delete context;
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay_ms * NSEC_PER_MSEC), retirement_queue(),
                   background_cleanup(^{
                     reap_source(retirement, next_reap_delay_ms(delay_ms));
                   }));
}
@implementation TDJNativeAudioSource {
    NativeSourceContext *_context;
    id _keepAlive;
    AVAudioSourceNode *_node;
    AVAudioSourceNodeRenderBlock _renderBlock;
}
- (nullable instancetype)initWithChannels:(uint32_t)channels
                                     core:(tdj_engine *)core
                                recording:(tdj_recording *)recording
                                  metrics:(nullable tdj_callback_metrics *)metrics
                           traceThreadCPU:(BOOL)traceThreadCPU
                        validationSilence:(BOOL)validationSilence
                                keepAlive:(id)keepAlive {
    self = [super init];
    if (!self)
        return nil;
    if (!core || !recording || !keepAlive || (channels != 2 && channels != 4))
        return nil;
    (void)retirement_queue();
    _context =
        new (std::nothrow) NativeSourceContext(core, recording, metrics, channels, traceThreadCPU, validationSilence);
    if (!_context)
        return nil;
    _keepAlive = keepAlive;
    NativeSourceLease lease(_context);
    AVAudioSourceNodeRenderBlock render =
        ^(BOOL *silence, const AudioTimeStamp *timestamp, AVAudioFrameCount count, AudioBufferList *output) {
          return tdj_native_source_render(lease.context, silence, timestamp, count, output);
        };
    _renderBlock = render;
    return self;
}
- (nullable AVAudioSourceNode *)node {
    return _node;
}
- (nullable AVAudioSourceNode *)makeNodeWithFormat:(AVAudioFormat *)format {
    if (_node)
        return nil;
    _node = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:_renderBlock];
    return _node;
}
- (AVAudioSourceNodeRenderBlock)renderBlock {
    return _renderBlock;
}
- (uint32_t)activeCallbacks {
    return _context->gate.load(std::memory_order_acquire) & active_mask;
}
- (void)suspendAndWait {
    _context->gate.fetch_or(closed_bit, std::memory_order_acq_rel);
    while (_context->gate.load(std::memory_order_acquire) & active_mask)
        sched_yield();
}
- (BOOL)resume {
    uint32_t state = _context->gate.load(std::memory_order_acquire);
    if (!(state & closed_bit))
        return YES;
    if (state & active_mask)
        return NO;
    return _context->gate.compare_exchange_strong(state, 0, std::memory_order_release, std::memory_order_relaxed);
}
- (void)dealloc {
    if (!_context)
        return;
    _context->gate.fetch_or(closed_bit, std::memory_order_acq_rel);
    NativeSourceRetirement *retirement = [NativeSourceRetirement new];
    retirement->context = _context;
    retirement->keepAlive = _keepAlive;
    retirement->node = _node;
    retirement->block = _renderBlock;
    _context = nullptr;
    _keepAlive = nil;
    _node = nil;
    _renderBlock = nil;
    dispatch_async(retirement_queue(), background_cleanup(^{
                     retirement->node = nil;
                     retirement->block = nil;
                     reap_source(retirement, 1);
                   }));
}
@end
