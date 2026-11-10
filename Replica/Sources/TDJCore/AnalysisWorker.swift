import AVFoundation
import Foundation

/// One low-priority analysis job at a time across library services.
public final class AnalysisWorker: Sendable {
    public static let shared = AnalysisWorker()
    private let queue: DispatchQueue
    public convenience init() { self.init(label: "org.generikdj.analysis") }
    init(label: String) { queue = DispatchQueue(label: label, qos: .background) }
    public func analyze(url: URL) async throws -> AudioAnalysis {
        try await run { check in try AudioAnalyzer.analyze(url: url, checkCancellation: check) }
    }
    public func waveformOnly(url: URL) async throws -> AudioAnalysis {
        try await run { check in try AudioAnalyzer.waveformOnly(url: url, checkCancellation: check) }
    }
    public func audioIdentity(url: URL) async throws -> AnalysisAudioIdentity {
        try await run { check in
            let hash = try AudioAnalyzer.sha256(url: url, checkCancellation: check)
            let audio = try AVAudioFile(forReading: url)
            return AnalysisAudioIdentity(sha256: hash, sampleRate: audio.processingFormat.sampleRate,
                frameCount: audio.length, channels: Int(audio.processingFormat.channelCount))
        }
    }
    public func detectBeatGrid(pcm: URL, matching analysis: AudioAnalysis) async throws -> BeatGridDetection? {
        try await run { check in
            try AudioAnalyzer.detectBeatGrid(pcm: pcm, matching: analysis, checkCancellation: check)
        }
    }
    public func rebuildWaveform(url: URL, matching analysis: AudioAnalysis) async throws -> AudioAnalysis {
        try await run { check in
            try AudioAnalyzer.rebuildWaveform(url: url, matching: analysis, checkCancellation: check)
        }
    }
    func run<T: Sendable>(
        checkAfterWork: Bool = true, _ work: @escaping @Sendable (@Sendable () throws -> Void) throws -> T
    ) async throws -> T {
        let cancellation = AnalysisCancellation()
        let measurement = AnalysisMeasurement.current
        let foreground = AnalysisExecution.foregroundLibrary
        #if os(macOS)
            let offline = AnalysisExecution.offlineBatch
        #else
            let offline = false
        #endif
        let progress = AnalysisWorkProgress.observer
        let wait = AnalysisMeasurement.begin("analysisQueueWait")
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                queue.async(qos: offline ? .userInitiated : .background, flags: .enforceQoS) {
                    wait?.finish()
                    do {
                        try cancellation.check()
                        let value = try AnalysisMeasurement.$current.withValue(measurement) {
                            try AnalysisExecution.$foregroundLibrary.withValue(foreground) {
                                try AnalysisExecution.$offlineBatch.withValue(offline) {
                                    try AnalysisWorkProgress.$observer.withValue(progress) {
                                        try work { try cancellation.check() }
                                    }
                                }
                            }
                        }
                        if checkAfterWork { try cancellation.check() }
                        continuation.resume(returning: value)
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: {
            measurement?.requestCancellation()
            cancellation.cancel()
        }
    }
}

private final class AnalysisCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}
