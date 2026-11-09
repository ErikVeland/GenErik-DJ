import Foundation
import TDJCore

/// Run the production analysers without opening or changing a performance workspace.
enum MacAnalysisAudit {
    struct Row: Codable {
        var id: String
        var firstPass: AudioAnalysis?
        var firstPassPerformance: AnalysisMeasurement.Record?
        var deep: DeepBeatAnalysis?
        var deepPerformance: AnalysisMeasurement.Record?
        var reusePerformance: AnalysisMeasurement.Record?
        var reuseMatches: Bool?
        var acceptedOverFirstPass: Bool?
        var error: String?
    }

    struct Report: Codable {
        var format = "generik.mac-analysis-audit/v1"
        var runID = UUID().uuidString
        var startedUTC = Date().ISO8601Format()
        var completedUTC: String?
        var operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
        var automaticMacAccelerationEligible = AnalysisExecution.supportsAcceleration
        var deepProfile = DeepAnalysisProfile.current
        var manifest: AnalysisBenchmarkManifest
        var rows: [Row] = []
    }

    static func run(manifestURL: URL, output: URL) async throws {
        let manifest = try JSONDecoder().decode(
            AnalysisBenchmarkManifest.self, from: Data(contentsOf: manifestURL))
        try manifest.validate()
        guard !manifest.tracks.isEmpty else { throw CoreError.invalidAudio("The audit needs at least one track.") }
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw CoreError.invalidAudio("Choose a new audit output folder. Existing results were retained.")
        }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var report = Report(manifest: manifest)
        let checkpointRoot = output.appendingPathComponent("checkpoints", isDirectory: true)

        // Finish every first pass before running the deep tier, as the library queue does.
        for expected in manifest.tracks {
            try Task.checkCancellation()
            let source = URL(fileURLWithPath: expected.path, relativeTo: manifestURL.deletingLastPathComponent())
            var row = Row(id: expected.id)
            let measure = AnalysisMeasurement(runID: report.runID, jobID: expected.id, pass: "first-pass", duration: nil)
            measure.update { $0.source = "fresh-local-file" }
            do {
                let analysis = try await AnalysisMeasurement.$current.withValue(measure) {
                    try await AnalysisWorker.shared.analyze(url: source)
                }
                guard analysis.contentSHA256 == expected.sha256 else {
                    throw CoreError.invalidAudio("The source hash changed. This track cannot be scored.")
                }
                row.firstPass = analysis
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
            measure.update { $0.source = "fresh-local-file" }
            measure.capture(analysis)
            do {
                let result = try await AnalysisMeasurement.$current.withValue(measure) {
                    try await AnalysisWorker.shared.deepBeatAnalysis(
                        url: source, matching: analysis, root: checkpointRoot)
                }
                report.rows[index].deepPerformance = measure.finish(outcome: "success")
                report.rows[index].deep = result
                let track = try Track(title: expected.id, mediaFilename: source.lastPathComponent, analysis: analysis)
                report.rows[index].acceptedOverFirstPass = result.acceptedGrid(for: track) != nil
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

    private static func log(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
