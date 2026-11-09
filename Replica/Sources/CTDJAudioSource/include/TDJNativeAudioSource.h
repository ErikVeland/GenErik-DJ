#import <Foundation/Foundation.h>
#import <AVFAudio/AVFAudio.h>
#ifdef __cplusplus
extern "C" {
#endif
#include "TDJTransport.h"
#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(macos(14.0), ios(17.0))
@interface TDJNativeAudioSource : NSObject
@property(nonatomic, strong, readonly, nullable) AVAudioSourceNode *node;
@property(nonatomic, copy, readonly) AVAudioSourceNodeRenderBlock renderBlock;
@property(nonatomic, readonly) uint32_t activeCallbacks;
- (nullable instancetype)initWithChannels:(uint32_t)channels
                                     core:(tdj_engine *)core
                                recording:(tdj_recording *)recording
                                  metrics:(nullable tdj_callback_metrics *)metrics
                           traceThreadCPU:(BOOL)traceThreadCPU
                        validationSilence:(BOOL)validationSilence
                                keepAlive:(id)keepAlive
    NS_SWIFT_NAME(init(channels:core:recording:metrics:traceThreadCPU:validationSilence:keepAlive:));
- (instancetype)init NS_UNAVAILABLE;
- (nullable AVAudioSourceNode *)makeNodeWithFormat:(AVAudioFormat *)format NS_SWIFT_NAME(makeNode(format:));
- (nullable AVAudioSinkNode *)makeMicrophoneSinkWithFormat:(AVAudioFormat *)format NS_SWIFT_NAME(makeMicrophoneSink(format:));
- (BOOL)suspendIfIdle;
- (void)suspendAndWait;
- (BOOL)resume;
@end
NS_ASSUME_NONNULL_END
