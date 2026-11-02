import Foundation

public final class NativeAudioRenderOwnership: NSObject, @unchecked Sendable {
    public let engineHandle: OpaquePointer
    public let recordingHandle: OpaquePointer
    public let metricsHandle: OpaquePointer?
    public let tracesThreadCPU: Bool
    private let transport: SampleTransport
    private let metrics: AudioCallbackMetrics?

    init(transport: SampleTransport, engine: OpaquePointer, recording: OpaquePointer,
         metrics: AudioCallbackMetrics?) {
        self.transport = transport
        self.metrics = metrics
        engineHandle = engine
        recordingHandle = recording
        metricsHandle = metrics?.pointer
        tracesThreadCPU = metrics?.tracesThreadCPU ?? false
        super.init()
    }
}
