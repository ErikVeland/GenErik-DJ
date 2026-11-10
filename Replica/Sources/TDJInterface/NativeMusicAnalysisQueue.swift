import Foundation
import TDJCore

final class NativeMusicAnalysisQueue: Sendable {
    enum Pass: CaseIterable, Hashable, Sendable {
        case matching, deep, structure

        var title: String {
            switch self {
            case .matching: "Analysing beats and key"
            case .deep: "Deep beat and downbeat analysis"
            case .structure: "Analysing structure and cues"
            }
        }
    }

    struct Batch: Sendable {
        let pass: Pass
        let range: Range<Int>
        let isMix: Bool
        var includesDeep = false

        var title: String {
            let prefix = isMix ? "Mixes over 19 min · " : ""
            let number = pass == .matching ? 1 : pass == .deep ? 2 : includesDeep ? 3 : 2
            return "\(prefix)Pass \(number) of \(includesDeep ? 3 : 2) · \(pass.title)"
        }
    }

    enum Job: Sendable {
        case managed(Track)
        case native(MusicLibraryItem, Track?)

        var id: String {
            switch self {
            case .managed(let track): track.id
            case .native(let item, _): item.id
            }
        }

        var title: String {
            switch self {
            case .managed(let track): track.title
            case .native(let item, _): item.title
            }
        }

        var duration: Double {
            switch self {
            case .managed(let track):
                let measured = track.analysis.duration
                return measured.isFinite && measured > 0 ? measured : .infinity
            case .native(let item, let track):
                if let measured = track?.analysis.duration, measured.isFinite, measured > 0 { return measured }
                return item.duration.isFinite && item.duration > 0 ? item.duration : .infinity
            }
        }

        var isMix: Bool {
            switch self {
            case .managed(let track): NativeAnalysisPlan.isMix(duration: track.analysis.duration)
            case .native(let item, let track):
                NativeAnalysisPlan.isMix(duration: item.duration)
                    || NativeAnalysisPlan.isMix(duration: track?.analysis.duration)
            }
        }

        var trackID: String? {
            switch self {
            case .managed(let track): track.id
            case .native(_, let track): track?.id
            }
        }
    }

    private struct State: Sendable {
        let catalog: MusicLibraryCatalog
        let tracks: [Track]
        let loaded: Set<String>
        let mediaDirectory: URL
        var items: [Job] = []
        var position = 0
        var end = 0
        var completed = Set<String>()
    }

    private let includeDeep: Bool
    private let value: BackgroundWorkValue<State>
    init(
        catalog: MusicLibraryCatalog, tracks: [Track], loaded: Set<String>, mediaDirectory: URL,
        worker: BackgroundFileWork, includeDeep: Bool = false
    ) {
        self.includeDeep = includeDeep
        value = BackgroundWorkValue(
            State(catalog: catalog, tracks: tracks, loaded: loaded, mediaDirectory: mediaDirectory), worker: worker)
    }

    func prepare(progress: (@Sendable (Double) -> Void)? = nil) async -> [Batch] {
        await value.update { state in
            var fileProgress = AnalysisWorkProgress.Step(0...0.3, observer: progress)
            let managed = state.tracks.enumerated().compactMap { index, track -> Track? in
                let readable = track.nativeLibraryOnly != true
                    && FileManager.default.isReadableFile(
                        atPath: state.mediaDirectory.appendingPathComponent(track.mediaFilename).path)
                fileProgress.advance(Int64(index + 1), of: Int64(state.tracks.count))
                return readable ? track : nil
            }
            var seen = Set(managed.map(\.id))
            var jobs = managed.map(Job.managed)
            let reconciliationProgress: (@Sendable (Double) -> Void)? = progress.map { observer in
                { @Sendable fraction in observer(0.3 + 0.4 * fraction) }
            }
            let entries = MusicLibraryReconciliation(
                catalog: state.catalog, tracks: state.tracks, progress: reconciliationProgress).entries
            var jobProgress = AnalysisWorkProgress.Step(0.7...0.9, observer: progress)
            for (index, entry) in entries.enumerated() {
                if entry.item.isOnDevice, entry.track.map({ seen.insert($0.id).inserted }) ?? true {
                    jobs.append(.native(entry.item, entry.track))
                }
                jobProgress.advance(Int64(index + 1), of: Int64(entries.count))
            }
            state.items = jobs.enumerated().sorted { a, b in
                if a.element.isMix != b.element.isMix { return !a.element.isMix }
                let loadedA = a.element.trackID.map(state.loaded.contains) ?? false
                let loadedB = b.element.trackID.map(state.loaded.contains) ?? false
                if loadedA != loadedB { return loadedA }
                if a.element.duration != b.element.duration { return a.element.duration < b.element.duration }
                return a.offset < b.offset
            }.map(\.element)
            progress?(1)
            let split = state.items.firstIndex(where: \.isMix) ?? state.items.count
            let ranges = [0..<split, split..<state.items.count].filter { !$0.isEmpty }
            return Pass.allCases.filter { $0 != .deep || self.includeDeep }.flatMap { pass in
                ranges.map {
                    Batch(pass: pass, range: $0, isMix: $0.lowerBound == split, includesDeep: self.includeDeep)
                }
            }
        } ?? []
    }

    @discardableResult
    func begin(_ batch: Batch, completed: Set<String> = []) async -> Int {
        await value.update {
            $0.position = batch.range.lowerBound
            $0.end = batch.range.upperBound
            $0.completed = completed
            return $0.items[batch.range].filter { completed.contains($0.id) }.count
        } ?? 0
    }

    func next() async -> Job? {
        await value.update {
            while $0.position < $0.end {
                let item = $0.items[$0.position]
                $0.position += 1
                if !$0.completed.contains(item.id) { return item }
            }
            return nil as Job?
        } ?? nil
    }

    @MainActor func finish() async { await value.clear() }
}
