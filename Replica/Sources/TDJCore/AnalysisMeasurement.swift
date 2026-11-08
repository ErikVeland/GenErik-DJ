import Darwin
import Foundation

/// Measurements describe one attempt. They do not change musical results or confidence.
public final class AnalysisMeasurement: @unchecked Sendable {
    @TaskLocal public static var current: AnalysisMeasurement?

    public struct Record: Codable, Sendable {
        public var format = "generik.analysis-measurement/v1"
        public var attemptID = UUID().uuidString
        public var runID: String
        public var jobID: String
        public var pass: String
        public var source = "unknown"
        public var outcome = "unknown"
        public var startedUTC = Date().ISO8601Format()
        public var deviceModel: String
        public var operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
        public var appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        public var requestedConfigurationID = AnalysisConfiguration().id
        public var configurationID: String?
        public var contentSHA256: String?
        public var sourceHashComputed = false
        public var modelID: String?
        public var structureVersion: Int?
        public var durationSeconds: Double?
        public var sourceSizeBytes: Int?
        public var wallSeconds = 0.0
        public var processCPUSeconds: Double?
        public var processLifetimePeakRSSBytes: Int64?
        public var cancellationResponseSeconds: Double?
        public var thermalStart: String
        public var thermalEnd: String?
        public var stageSeconds: [String: Double] = [:]
        public var stageCalls: [String: Int] = [:]
        public var counters: [String: Int64] = [:]
        public var cacheHits: [String] = []

        public var realTimeFactor: Double? {
            guard let durationSeconds, durationSeconds > 0 else { return nil }
            return wallSeconds / durationSeconds
        }
    }

    public struct Span: Sendable {
        private let measurement: AnalysisMeasurement
        private let stage: String
        private let start = DispatchTime.now().uptimeNanoseconds

        fileprivate init(_ measurement: AnalysisMeasurement, stage: String) {
            self.measurement = measurement
            self.stage = stage
        }

        public func finish() {
            let seconds = AnalysisMeasurement.seconds(since: start)
            measurement.update {
                $0.stageSeconds[stage, default: 0] += seconds
                $0.stageCalls[stage, default: 0] += 1
            }
        }
    }

    private let lock = NSLock()
    private let start = DispatchTime.now().uptimeNanoseconds
    private let startingCPU = AnalysisMeasurement.resources()?.cpu
    private var cancelledAt: UInt64?
    private var record: Record

    public init(runID: String, jobID: String, pass: String, duration: Double?) {
        record = Record(
            runID: runID, jobID: jobID, pass: pass, deviceModel: Self.deviceModel,
            durationSeconds: duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil },
            thermalStart: Self.thermalState)
    }

    public static func begin(_ stage: String) -> Span? { current.map { Span($0, stage: stage) } }

    public static func measure<T>(_ stage: String, _ work: () throws -> T) rethrows -> T {
        let span = begin(stage)
        defer { span?.finish() }
        return try work()
    }

    public func update(_ change: (inout Record) -> Void) { lock.withLock { change(&record) } }

    public func capture(_ analysis: AudioAnalysis) {
        update {
            $0.contentSHA256 = analysis.contentSHA256
            $0.configurationID = analysis.configurationID
            $0.durationSeconds = analysis.duration.isFinite && analysis.duration > 0 ? analysis.duration : nil
        }
    }

    public func count(_ name: String, _ value: Int64) {
        update { $0.counters[name, default: 0] += value }
    }

    public func cacheHit(_ name: String) {
        update { if !$0.cacheHits.contains(name) { $0.cacheHits.append(name) } }
    }

    public func requestCancellation() {
        lock.withLock { if cancelledAt == nil { cancelledAt = DispatchTime.now().uptimeNanoseconds } }
    }

    public func finish(outcome: String) -> Record {
        let resources = Self.resources()
        let thermal = Self.thermalState
        return lock.withLock {
            record.outcome = outcome
            record.wallSeconds = Self.seconds(since: start)
            record.thermalEnd = thermal
            record.processLifetimePeakRSSBytes = resources?.peakRSS
            if let resources, let startingCPU { record.processCPUSeconds = max(0, resources.cpu - startingCPU) }
            record.cancellationResponseSeconds = cancelledAt.map { Self.seconds(since: $0) }
            return record
        }
    }

    private static func seconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
    }

    private static func resources() -> (cpu: Double, peakRSS: Int64)? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        let cpu =
            Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
            + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
        return (cpu, Int64(usage.ru_maxrss))
    }

    private static let deviceModel: String = {
        var system = utsname()
        guard uname(&system) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()

    private static var thermalState: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}

/// Call from a file worker while idle. Existing evidence is never rotated or overwritten.
public enum AnalysisMeasurementLog {
    public static let maximumBytes: UInt64 = 32 * 1024 * 1024

    public static func append(_ records: [AnalysisMeasurement.Record], to url: URL) throws -> Bool {
        guard !records.isEmpty else { return true }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var batch = Data()
        for record in records {
            batch.append(try encoder.encode(record))
            batch.append(0x0a)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size + UInt64(batch.count) <= maximumBytes else { return false }
        try handle.write(contentsOf: batch)
        return true
    }
}
