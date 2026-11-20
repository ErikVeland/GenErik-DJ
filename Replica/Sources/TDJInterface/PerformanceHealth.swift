import Darwin
import Foundation
import TDJCore

struct PerformanceHealthReport: Encodable, Sendable {
    struct Audio: Codable, Sendable {
        let callbacks: UInt64
        let deadlineOverruns: UInt64
        let timestampGaps: UInt64
        let renderFailures: UInt64
        let maximumMicroseconds: Double
        let minimumFrames: UInt32
        let maximumFrames: UInt32
        init(_ value: AudioCallbackSummary) {
            callbacks = value.callbacks
            deadlineOverruns = value.deadlineOverruns
            timestampGaps = value.timestampGaps
            renderFailures = value.renderFailures
            maximumMicroseconds = value.maximumMicroseconds
            minimumFrames = value.minimumFrames
            maximumFrames = value.maximumFrames
        }
    }
    struct Sample: Codable, Sendable {
        let elapsedSeconds: Double
        let footprintBytes: UInt64?
        let thermalState: Int
        let sampleRate: Double
        let audio: Audio?
        let streaming: PCMStreamingSummary
        let recordingCapturedFrames: UInt64
        let recordingDroppedFrames: UInt64
        let recording: Bool
        let output: String
        let controllers: [String]
    }
    let format = "generik-dj.performance-health/v1"
    let id: String
    let build: String
    let createdAt: Date
    let system: String
    let scope = "Process audio counters. Compare the first sample with later samples. Monitor gaps are not display-frame or touch measurements. Device listening and touch acceptance remain required."
    var totalSamples = 0
    var peakFootprintBytes: UInt64?
    var worstThermalState = 0
    var maximumMonitorGapSeconds = 0.0
    var firstSample: Sample?
    var samples: [Sample] = []

    func write(to url: URL) throws {
        var ordered = self
        ordered.samples.sort { $0.elapsedSeconds < $1.elapsedSeconds }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ordered).write(to: url, options: .atomic)
    }

    static func footprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }
}

@MainActor final class PerformanceHealthRecorder {
    private(set) var report: PerformanceHealthReport
    private let sampleLimit: Int
    private let interval: Double
    private var started: Double?
    private var lastTick: Double?
    private var nextSample = 0.0
    private var replacement = 0
    var filename: String { "performance-\(report.build)-\(report.id).json" }

    init(sampleLimit: Int = 720, interval: Double = 30) {
        self.sampleLimit = max(1, sampleLimit)
        self.interval = max(1, interval)
        report = .init(id: UUID().uuidString,
                       build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "host",
                       createdAt: Date(), system: ProcessInfo.processInfo.operatingSystemVersionString)
    }

    func resetMonitorClock() { lastTick = nil }

    func observe(at uptime: Double, force: Bool = false,
                 capture: (Double) -> PerformanceHealthReport.Sample) -> PerformanceHealthReport? {
        if let lastTick, uptime >= lastTick {
            report.maximumMonitorGapSeconds = max(report.maximumMonitorGapSeconds, uptime - lastTick)
        }
        lastTick = uptime
        guard force || uptime >= nextSample else { return nil }
        if started == nil { started = uptime }
        nextSample = uptime + interval
        let sample = capture(max(0, uptime - (started ?? uptime)))
        if report.firstSample == nil { report.firstSample = sample }
        report.totalSamples += 1
        if let bytes = sample.footprintBytes { report.peakFootprintBytes = max(report.peakFootprintBytes ?? 0, bytes) }
        report.worstThermalState = max(report.worstThermalState, sample.thermalState)
        if report.samples.count < sampleLimit {
            report.samples.append(sample)
        } else {
            report.samples[replacement] = sample
            replacement = (replacement + 1) % sampleLimit
        }
        return report
    }
}

extension ReplicaModel {
    public var performanceReportURL: URL {
        store.root.appendingPathComponent("PerformanceReports").appendingPathComponent(performanceHealth.filename)
    }

    func savePerformanceHealth(force: Bool = false) {
        guard !playback.offline, playback.core.performanceWorkGate.isProtected || force else { return }
        guard let report = performanceHealth.observe(at: ProcessInfo.processInfo.systemUptime, force: force, capture: { elapsed in
            .init(elapsedSeconds: elapsed, footprintBytes: PerformanceHealthReport.footprintBytes(),
                  thermalState: ProcessInfo.processInfo.thermalState.rawValue, sampleRate: playback.core.sampleRate,
                  audio: playback.callbackSummary.map(PerformanceHealthReport.Audio.init),
                  streaming: playback.core.streamingSummary(),
                  recordingCapturedFrames: playback.core.recording.capturedFrames,
                  recordingDroppedFrames: playback.core.recording.droppedFrames,
                  recording: playback.isRecording, output: playback.automaticOutputDevice ?? playback.outputRoute.rawValue,
                  controllers: connectedControllerLights())
        }) else { return }
        let url = performanceReportURL
        performanceHealthWriter.enqueue(report, write: { [weak self] report in
            try report.write(to: url)
            Task { @MainActor [weak self] in
                if self?.performanceReportAvailable == false { self?.performanceReportAvailable = true }
                if self?.performanceReportError.isEmpty == false { self?.performanceReportError = "" }
            }
        }, reportError: { [weak self] error in
            self?.performanceReportError = error
        })
    }
}
