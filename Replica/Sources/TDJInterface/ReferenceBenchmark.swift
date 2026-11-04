import Foundation
import TDJCore

/// Clean-room comparison: our analyser on the opening minute of the user's own songs against the
/// tempo and key the DJ collection stores for them. Reads values only; no other app's code is used.
public struct ReferenceBenchmarkReport: Codable, Sendable, Equatable {
    public struct Row: Codable, Sendable, Equatable {
        public let title: String
        public let referenceBPM: Double?, ourBPM: Double?
        public let referenceKey: String?, ourKey: String?
        public let tempo: String, key: String
    }
    public var rows: [Row] = []
    public var analysed: Int { rows.count }
    public func count(tempo value: String) -> Int { rows.filter { $0.tempo == value }.count }
    public func count(key value: String) -> Int { rows.filter { $0.key == value }.count }

    /// exact: within 2 %; octave: half or double within 2 %; miss; none: we found no tempo.
    public static func tempoVerdict(ours: Double?, reference: Double?) -> String {
        guard let reference, reference > 0 else { return "no-reference" }
        guard let ours, ours > 0 else { return "none" }
        if abs(ours / reference - 1) <= 0.02 { return "exact" }
        if abs(ours * 2 / reference - 1) <= 0.02 || abs(ours / 2 / reference - 1) <= 0.02 { return "octave" }
        return "miss"
    }
    /// exact, compatible (neighbour or relative), miss, none.
    public static func keyVerdict(ours: MusicalKey?, reference: MusicalKey?) -> String {
        guard let reference else { return "no-reference" }
        guard let ours else { return "none" }
        if ours == reference { return "exact" }
        return BrowserRecommendations.keysCompatible(ours, reference) ? "compatible" : "miss"
    }
}

extension ReplicaModel {
    var referenceBenchmarkURL: URL { store.root.appendingPathComponent("reference-benchmark.json") }

    public func runReferenceBenchmark(count: Int) async -> ReferenceBenchmarkReport {
        cancelNativeMusicAnalysis()
        defer { startNativeMusicAnalysis() }
        var report = ReferenceBenchmarkReport()
        let hints = collectionHints
        let candidates = (musicLibraryCatalog?.items ?? []).filter { $0.isOnDevice && hints[$0.id]?.bpm != nil }
        // An even spread through the library, not just the first titles alphabetically.
        let step = max(1, candidates.count / max(1, count))
        for item in stride(from: 0, to: candidates.count, by: step).prefix(count).map({ candidates[$0] }) {
            guard !Task.isCancelled, let url = item.assetURL else { break }
            let directory = store.root.appendingPathComponent(".native-source-" + UUID().uuidString, isDirectory: true)
            await nativeMusic.files.run {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let excerpt = directory.appendingPathComponent("opening.caf")
            var analysis: AudioAnalysis?
            do {
                try await MusicLibraryAudio.decodeAsset(
                    url: url, destination: excerpt, maximumSeconds: NativeAnalysisPlan.excerptSeconds)
                analysis = try await AnalysisWorker.shared.analyze(url: excerpt)
            } catch { logAnalysis("Benchmark skipped \(item.title): \(error.localizedDescription)") }
            await nativeMusic.files.run { try? FileManager.default.removeItem(at: directory) }
            guard let analysis else { continue }
            let reference = hints[item.id]
            report.rows.append(
                .init(
                    title: item.title, referenceBPM: reference?.bpm, ourBPM: analysis.bpm,
                    referenceKey: reference?.key?.openKeyName, ourKey: analysis.key?.openKeyName,
                    tempo: ReferenceBenchmarkReport.tempoVerdict(ours: analysis.bpm, reference: reference?.bpm),
                    key: ReferenceBenchmarkReport.keyVerdict(ours: analysis.key, reference: reference?.key)))
            analysisProgress = .init(done: report.analysed, total: count, title: "Comparing")
        }
        analysisProgress = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try? encoder.encode(report)
        let url = referenceBenchmarkURL
        await nativeMusic.files.run { try? data?.write(to: url, options: .atomic) }
        logAnalysis(
            "Reference comparison: \(report.analysed) songs; tempo exact \(report.count(tempo: "exact")), octave \(report.count(tempo: "octave")), miss \(report.count(tempo: "miss")), none \(report.count(tempo: "none")); key exact \(report.count(key: "exact")), compatible \(report.count(key: "compatible")), miss \(report.count(key: "miss"))"
        )
        return report
    }
}
