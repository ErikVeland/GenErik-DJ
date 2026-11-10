import CryptoKit
import Foundation
import TDJCore

/// Run the production analysers without opening or changing a performance workspace.
enum MacAnalysisAudit {
    struct Row: Codable {
        var id: String
        var firstPass: AudioAnalysis?
        var firstPassTimeline: AnalysisBenchmarkTimeline?
        var firstPassPerformance: AnalysisMeasurement.Record?
        var deep: DeepBeatAnalysis?
        var deepPerformance: AnalysisMeasurement.Record?
        var reusePerformance: AnalysisMeasurement.Record?
        var reuseMatches: Bool?
        var acceptedOverFirstPass: Bool?
        var acceptedTempoOnly: Bool?
        var acceptedOpeningBar: Bool?
        var acceptedGuidedPhase: Bool?
        var finalAnalysis: AudioAnalysis?
        var finalTimeline: AnalysisBenchmarkTimeline?
        var reviewTimeline: AnalysisBenchmarkTimeline?
        var error: String?
    }

    struct Report: Codable {
        var format = "generik.mac-analysis-audit/v1"
        var runID = UUID().uuidString
        var startedUTC = Date().ISO8601Format()
        var completedUTC: String?
        var replayedRunID: String?
        var sourceReportSHA256: String?
        var operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
        var automaticMacAccelerationEligible = AnalysisExecution.supportsAcceleration
        var firstPassExecution: String?
        var deepProfile = DeepAnalysisProfile.current
        var manifest: AnalysisBenchmarkManifest
        var rows: [Row] = []
    }

    static func run(manifestURL: URL, output: URL, replayReport: Bool = false, foregroundLibrary: Bool = true) async throws {
        let input = try Data(contentsOf: manifestURL)
        let previous = replayReport ? try JSONDecoder().decode(Report.self, from: input) : nil
        let manifest = try previous?.manifest ?? JSONDecoder().decode(AnalysisBenchmarkManifest.self, from: input)
        try manifest.validate()
        if let previous {
            guard previous.completedUTC != nil,
                previous.deepProfile.inferenceID == DeepAnalysisProfile.current.inferenceID,
                previous.rows.count == manifest.tracks.count,
                zip(previous.rows, manifest.tracks).allSatisfy({ row, expected in
                    row.id == expected.id && row.error == nil && row.reuseMatches == true
                        && row.firstPass?.contentSHA256 == expected.sha256 && expected.path.hasPrefix("/")
                })
            else { throw CoreError.invalidAudio("Replay requires a complete, matching audit with absolute audio paths.") }
        }
        guard !manifest.tracks.isEmpty else { throw CoreError.invalidAudio("The audit needs at least one track.") }
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw CoreError.invalidAudio("Choose a new audit output folder. Existing results were retained.")
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var report = Report(manifest: manifest)
        report.firstPassExecution = replayReport ? "saved-first-pass" : (foregroundLibrary ? "foreground-library" : "cpu-comparison")
        let checkpointRoot = output.appendingPathComponent("checkpoints", isDirectory: true)
        if let previous {
            report.replayedRunID = previous.runID
            report.sourceReportSHA256 = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
            try FileManager.default.copyItem(
                at: manifestURL.deletingLastPathComponent().appendingPathComponent("checkpoints"),
                to: checkpointRoot)
        }

        // Finish every first pass before running the deep tier, as the library queue does.
        for (index, expected) in manifest.tracks.enumerated() {
            try Task.checkCancellation()
            let source = URL(fileURLWithPath: expected.path, relativeTo: manifestURL.deletingLastPathComponent())
            var row = Row(id: expected.id)
            let measure = AnalysisMeasurement(runID: report.runID, jobID: expected.id, pass: "first-pass", duration: nil)
            measure.update { $0.source = previous == nil ? "fresh-local-file" : "saved-first-pass" }
            do {
                let analysis: AudioAnalysis
                if let saved = previous?.rows[index].firstPass {
                    guard try digest(source) == expected.sha256 else {
                        throw CoreError.invalidAudio("The replay audio changed. Existing results were retained.")
                    }
                    analysis = saved.replacingWaveform([])
                } else {
                    analysis = try await AnalysisMeasurement.$current.withValue(measure) {
                        try await AnalysisExecution.$foregroundLibrary.withValue(foregroundLibrary) {
                            try await AnalysisWorker.shared.analyze(url: source)
                        }
                    }
                }
                guard analysis.contentSHA256 == expected.sha256 else {
                    throw CoreError.invalidAudio("The source hash changed. This track cannot be scored.")
                }
                row.firstPass = analysis
                row.firstPassTimeline = try AnalysisBenchmarkTimeline(
                    track: Track(title: expected.id, mediaFilename: source.lastPathComponent, analysis: analysis))
                measure.capture(analysis)
                row.firstPassPerformance = measure.finish(outcome: "success")
            } catch {
                row.error = error.localizedDescription
                row.firstPassPerformance = measure.finish(outcome: "failed")
            }
            report.rows.append(row)
            try save(report, to: output)
            log("First pass \(report.rows.count)/\(manifest.tracks.count): \(expected.id), \(row.firstPassPerformance!.wallSeconds) s")
        }

        for index in report.rows.indices {
            try Task.checkCancellation()
            guard let analysis = report.rows[index].firstPass else { continue }
            let expected = manifest.tracks[index]
            let source = URL(fileURLWithPath: expected.path, relativeTo: manifestURL.deletingLastPathComponent())
            let measure = AnalysisMeasurement(
                runID: report.runID, jobID: expected.id, pass: "deep-fresh", duration: analysis.duration)
            measure.update { $0.source = previous == nil ? "fresh-local-file" : "saved-prediction-windows" }
            measure.capture(analysis)
            do {
                let result = try await AnalysisMeasurement.$current.withValue(measure) {
                    try await AnalysisWorker.shared.deepBeatAnalysis(
                        url: source, matching: analysis, root: checkpointRoot)
                }
                report.rows[index].deepPerformance = measure.finish(outcome: "success")
                report.rows[index].deep = result
                let track = try Track(title: expected.id, mediaFilename: source.lastPathComponent, analysis: analysis)
                let adopted = try track.adoptingDeepAnalysis(result)
                let accepted = adopted.analysis.acceptedDeepBeatAnalysis == result
                report.rows[index].acceptedOverFirstPass = result.candidate != nil && accepted
                report.rows[index].acceptedOpeningBar = result.candidate?.openingPhaseCorrected == true && accepted
                report.rows[index].acceptedGuidedPhase = result.guidedPhase != nil && accepted
                report.rows[index].acceptedTempoOnly =
                    result.candidate == nil && result.guidedPhase == nil && accepted
                report.rows[index].finalAnalysis = adopted.analysis.replacingWaveform([])
                report.rows[index].finalTimeline = try AnalysisBenchmarkTimeline(track: adopted)
                if let map = adopted.analysis.adaptiveCandidate,
                    map == result.adaptiveCandidate?.map || (track.grid == nil && map == result.fixedReviewCandidate)
                {
                    var preview = adopted
                    try preview.preparation.acceptAdaptive(map, frameCount: adopted.analysis.frameCount)
                    report.rows[index].reviewTimeline = try AnalysisBenchmarkTimeline(track: preview)
                }
            } catch {
                report.rows[index].deepPerformance = measure.finish(outcome: "failed")
                report.rows[index].error = error.localizedDescription
            }
            try save(report, to: output)
            log("Deep pass \(index + 1)/\(manifest.tracks.count): \(expected.id), \(report.rows[index].deepPerformance!.wallSeconds) s")

            guard let result = report.rows[index].deep else { continue }
            let reuse = AnalysisMeasurement(
                runID: report.runID, jobID: expected.id, pass: "deep-reuse", duration: analysis.duration)
            reuse.capture(analysis)
            reuse.update { $0.source = "saved-deep-result" }
            do {
                let cached = try await AnalysisMeasurement.$current.withValue(reuse) {
                    try await AnalysisWorker.shared.deepBeatAnalysis(
                        url: source, matching: analysis, root: checkpointRoot)
                }
                report.rows[index].reuseMatches = cached == result
                report.rows[index].reusePerformance = reuse.finish(outcome: "success")
            } catch {
                report.rows[index].reusePerformance = reuse.finish(outcome: "failed")
                report.rows[index].error = error.localizedDescription
            }
            try save(report, to: output)
        }
        report.completedUTC = Date().ISO8601Format()
        try save(report, to: output)
        guard report.rows.allSatisfy({ $0.error == nil && $0.reuseMatches == true }) else {
            throw CoreError.invalidAudio("Some audit tracks failed. Read the saved report before using its results.")
        }
    }

    private static func save(_ report: Report, to output: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: output.appendingPathComponent("report.json"), options: .atomic)
    }

    static func digest(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hash = SHA256()
        while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty {
            try Task.checkCancellation()
            hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func log(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
