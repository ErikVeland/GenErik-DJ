import Foundation

/// One low-priority analysis job at a time across library services.
public final class AnalysisWorker: Sendable {
    public static let shared = AnalysisWorker()
    private let queue: DispatchQueue
    public convenience init() { self.init(label:"org.generikdj.analysis") }
    init(label: String) { queue=DispatchQueue(label:label,qos:.background) }
    public func analyze(url: URL) async throws -> AudioAnalysis {
        try await run { check in try AudioAnalyzer.analyze(url:url,checkCancellation:check) }
    }
    public func waveformOnly(url: URL) async throws -> AudioAnalysis {
        try await run { check in try AudioAnalyzer.waveformOnly(url: url, checkCancellation: check) }
    }
    public func rebuildWaveform(url: URL, matching analysis: AudioAnalysis) async throws -> AudioAnalysis {
        try await run { check in try AudioAnalyzer.rebuildWaveform(url: url, matching: analysis, checkCancellation: check) }
    }
    func run<T: Sendable>(checkAfterWork: Bool = true, _ work: @escaping @Sendable (@Sendable () throws -> Void) throws -> T) async throws -> T {
        let cancellation = AnalysisCancellation()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                queue.async(qos: .background, flags: .enforceQoS) {
                    do {
                        try cancellation.check()
                        let value=try work { try cancellation.check() }
                        if checkAfterWork { try cancellation.check() }
                        continuation.resume(returning:value)
                    } catch { continuation.resume(throwing:error) }
                }
            }
        } onCancel: { cancellation.cancel() }
    }
}

private final class AnalysisCancellation: @unchecked Sendable {
    private let lock=NSLock()
    private var cancelled=false
    func cancel() { lock.withLock { cancelled=true } }
    func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}
