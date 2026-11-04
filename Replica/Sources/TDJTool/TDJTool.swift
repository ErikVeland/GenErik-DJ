import Foundation
import TDJCore

@main struct TDJTool {
    static func main() async {
        do { try await run() } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
    static func emit<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        FileHandle.standardOutput.write(try encoder.encode(value))
        FileHandle.standardOutput.write(Data([10]))
    }
    static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            print(usage)
            return
        }
        if command == "inspect-traktor", arguments.count == 3 {
            let source = URL(fileURLWithPath: arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
            let destination = URL(fileURLWithPath: arguments[2]).standardizedFileURL.resolvingSymlinksInPath()
            guard source != destination else {
                throw CoreError.invalidAudio("The report must not overwrite the original collection.")
            }
            let catalog = try await TraktorPreparationStorage.readCollection(at: source)
            let report = TraktorInspection(
                summary: catalog.summary, records: catalog.records.count,
                reusableRecords: catalog.records.filter(\.canReuseMusicalPreparation).count,
                recordsWithWarnings: catalog.records.filter { !$0.warnings.isEmpty }.count,
                audioIdentityMatchesChecked: false,
                exampleReferences: Array(catalog.records.filter(\.canReuseMusicalPreparation).prefix(10)))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: destination, options: .atomic)
            try emit(report)
            return
        }
        if command == "transport-probe", arguments.count == 2 {
            try transportProbe(directory: URL(fileURLWithPath: arguments[1], isDirectory: true))
            return
        }
        if command == "keylock-probe", arguments.count == 2 {
            try keylockProbe(directory: URL(fileURLWithPath: arguments[1], isDirectory: true))
            return
        }
        if command == "analyze", arguments.count == 2 {
            try emit(AudioAnalyzer.analyze(url: URL(fileURLWithPath: arguments[1])))
            return
        }
        if command == "benchmark-analysis", arguments.count == 3 {
            let manifestURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
            let outputURL = URL(fileURLWithPath: arguments[2]).standardizedFileURL
            let directory = manifestURL.deletingLastPathComponent()
            let manifest = try JSONDecoder().decode(AnalysisBenchmarkManifest.self, from: Data(contentsOf: manifestURL))
            let sources =
                manifest.tracks.map {
                    URL(fileURLWithPath: $0.path, relativeTo: directory).standardizedFileURL.resolvingSymlinksInPath()
                } + [manifestURL.resolvingSymlinksInPath()]
            guard !sources.contains(outputURL.resolvingSymlinksInPath()) else {
                throw CoreError.invalidAudio("The benchmark report must not overwrite its manifest or source audio.")
            }
            let report = try await AnalysisBenchmark.run(manifest: manifest, relativeTo: directory)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(report).write(to: outputURL, options: .atomic)
            try emit(report)
            if !report.referenceCorpusPassed { exit(2) }
            return
        }
        guard arguments.count >= 3, arguments[1] == "--workspace" else {
            print(usage)
            return
        }
        let store = try WorkspaceStore(root: URL(fileURLWithPath: arguments[2], isDirectory: true))
        switch command {
        case "key-governance":
            let snapshot = try store.load(includeWaveforms: false)
            try emit(
                snapshot.tracks.map {
                    GovernedKeySummary(id: $0.id, title: $0.title, decision: $0.keyDecision, evidence: $0.keyGovernance)
                })
        case "preview-key-import", "apply-key-import":
            guard arguments.count == (command == "preview-key-import" ? 4 : 6) else {
                print(usage)
                return
            }
            let source = URL(fileURLWithPath: arguments[3])
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 2 * 1024 * 1024 + 1) ?? Data()
            let service = try LibraryService(store: store)
            let plan = try await service.previewKeyImport(data: data)
            if command == "apply-key-import" {
                guard Int(arguments[4]) == plan.expectedRevision, arguments[5] == plan.manifestSHA256 else {
                    throw CoreError.staleContext
                }
                _ = try await service.applyKeyImport(plan)
            }
            try emit(
                KeyImportPreview(
                    policyVersion: plan.policyVersion, manifestSHA256: plan.manifestSHA256,
                    expectedRevision: plan.expectedRevision, changes: plan.changes))
        case "import-traktor":
            guard arguments.count == 4 else {
                print(usage)
                return
            }
            let service = try LibraryService(store: store)
            try emit(try await service.importTraktorCollection(url: URL(fileURLWithPath: arguments[3])))
        case "import":
            let service = try LibraryService(store: store)
            for path in arguments.dropFirst(3) { _ = try await service.importAudio(url: URL(fileURLWithPath: path)) }
            let snapshot = await service.snapshot()
            try emit(snapshot.tracks.map { TrackSummary(id: $0.id, title: $0.title, bpm: $0.bpm, key: $0.key?.name) })
        case "reanalyze":
            let service = try LibraryService(store: store)
            let initial = await service.snapshot()
            let requested = Array(arguments.dropFirst(3))
            let identities = requested.isEmpty ? initial.tracks.map(\.id) : requested
            guard Set(identities).isSubset(of: Set(initial.tracks.map(\.id))) else { throw CoreError.staleContext }
            for identity in identities { _ = try await service.reanalyze(trackID: identity) }
            let snapshot = await service.snapshot()
            try emit(snapshot.tracks.map { TrackSummary(id: $0.id, title: $0.title, bpm: $0.bpm, key: $0.key?.name) })
        case "suggest", "suggest-calibrated":
            guard arguments.count == 5, let destination = DeckID(rawValue: arguments[4]) else {
                print(usage)
                return
            }
            let snapshot = try store.load(includeWaveforms: false)
            let context = SuggestionContext(
                referenceTrackID: arguments[3], destination: destination, usePerformanceBPM: false, loadedTrackIDs: [],
                libraryRevision: snapshot.revision, historyRevision: snapshot.adaptiveMemory.revision)
            if command == "suggest-calibrated" {
                try emit(SuggestionEngine.rank(library: snapshot, context: context, calibration: snapshot.calibration))
            } else {
                try emit(PerformerSuggestions.rank(library: snapshot, context: context))
            }
        case "record-event":
            guard arguments.count == 4 else {
                print(usage)
                return
            }
            let event = try JSONDecoder().decode(
                PerformanceEvent.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[3])))
            let service = try LibraryService(store: store)
            let result = try await service.record(event)
            try emit(["retainedEvents": result.events.count, "historyRevision": result.adaptiveMemory.revision])
        case "install-calibration":
            guard arguments.count == 4 else {
                print(usage)
                return
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: arguments[3]))
            let calibration = try JSONDecoder().decode(SuggestionCalibration.self, from: data)
            try calibration.validate()
            var snapshot = try store.load(includeWaveforms: false)
            snapshot.adaptiveMemory = try .rebuild(events: snapshot.events, calibration: calibration)
            snapshot.calibration = calibration
            try store.save(snapshot)
            try emit(["calibration": calibration.id, "basis": calibration.basis.rawValue])
        default: print(usage)
        }
    }
    struct TraktorInspection: Encodable {
        let summary: TraktorCollectionReferenceSummary
        let records: Int
        let reusableRecords: Int
        let recordsWithWarnings: Int
        let audioIdentityMatchesChecked: Bool
        let exampleReferences: [TraktorPreparationRecord]
    }
    struct TrackSummary: Encodable {
        let id: String
        let title: String
        let bpm: Double?
        let key: String?
    }
    struct GovernedKeySummary: Encodable {
        let id: String
        let title: String
        let decision: KeyDecision
        let evidence: KeyGovernanceState?
    }
    struct KeyImportPreview: Encodable {
        let policyVersion: String
        let manifestSHA256: String
        let expectedRevision: Int
        let changes: [KeyImportPlan.Change]
    }
    static let usage = """
        tdj-tool inspect-traktor COLLECTION_NML_OR_GZIP REPORT_JSON
        tdj-tool import-traktor --workspace DIRECTORY COLLECTION_NML_OR_GZIP
        tdj-tool key-governance --workspace DIRECTORY
        tdj-tool preview-key-import --workspace DIRECTORY MANIFEST_JSON
        tdj-tool apply-key-import --workspace DIRECTORY MANIFEST_JSON EXPECTED_REVISION MANIFEST_SHA256
        tdj-tool analyze AUDIO
        tdj-tool benchmark-analysis MANIFEST_JSON REPORT_JSON
        tdj-tool transport-probe OUTPUT_DIRECTORY
        tdj-tool keylock-probe OUTPUT_DIRECTORY
        tdj-tool import --workspace DIRECTORY AUDIO...
        tdj-tool reanalyze --workspace DIRECTORY [TRACK_ID...]
        tdj-tool suggest --workspace DIRECTORY REFERENCE_TRACK_ID a|b
        tdj-tool record-event --workspace DIRECTORY EVENT_JSON
        tdj-tool install-calibration --workspace DIRECTORY CALIBRATION_JSON

        Local development only. No device commands or acquisition helpers are used.
        Suggestions use the performer policy: key, ±8% BPM, similar energy, prior pairing.
        suggest-calibrated retains the separate experimental calibration route.
        """
}
