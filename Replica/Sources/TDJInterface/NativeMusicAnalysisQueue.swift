import Foundation
import TDJCore

final class NativeMusicAnalysisQueue: Sendable {
    enum Pass: CaseIterable, Sendable {
        case matching, structure

        var title: String {
            switch self {
            case .matching: "Analysing beats and key"
            case .structure: "Analysing structure and cues"
            }
        }
    }

    struct Batch: Sendable {
        let pass: Pass
        let range: Range<Int>
        let isMix: Bool

        var title: String {
            let prefix = isMix ? "Mixes over 19 min · " : ""
            return "\(prefix)Pass \(pass == .matching ? 1 : 2) of 2 · \(pass.title)"
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
    }

    private let value: BackgroundWorkValue<State>
    init(
        catalog: MusicLibraryCatalog, tracks: [Track], loaded: Set<String>, mediaDirectory: URL,
        worker: BackgroundFileWork
    ) {
        value = BackgroundWorkValue(
            State(catalog: catalog, tracks: tracks, loaded: loaded, mediaDirectory: mediaDirectory), worker: worker)
    }

    func prepare() async -> [Batch] {
        await value.update { state in
            let managed = state.tracks.filter {
                $0.nativeLibraryOnly != true
                    && FileManager.default.isReadableFile(
                        atPath: state.mediaDirectory.appendingPathComponent($0.mediaFilename).path)
            }
            var seen = Set(managed.map(\.id))
            var jobs = managed.map(Job.managed)
            let entries = MusicLibraryReconciliation(catalog: state.catalog, tracks: state.tracks).entries
            for entry in entries where entry.item.isOnDevice {
                if let id = entry.track?.id, !seen.insert(id).inserted { continue }
                jobs.append(.native(entry.item, entry.track))
            }
            state.items = jobs.enumerated().sorted { a, b in
                if a.element.isMix != b.element.isMix { return !a.element.isMix }
                let loadedA = a.element.trackID.map(state.loaded.contains) ?? false
                let loadedB = b.element.trackID.map(state.loaded.contains) ?? false
                if loadedA != loadedB { return loadedA }
                if a.element.duration != b.element.duration { return a.element.duration < b.element.duration }
                return a.offset < b.offset
            }.map(\.element)
            let split = state.items.firstIndex(where: \.isMix) ?? state.items.count
            let ranges = [0..<split, split..<state.items.count].filter { !$0.isEmpty }
            return Pass.allCases.flatMap { pass in
                ranges.map { Batch(pass: pass, range: $0, isMix: $0.lowerBound == split) }
            }
        } ?? []
    }

    func begin(_ batch: Batch) async {
        await value.update {
            $0.position = batch.range.lowerBound
            $0.end = batch.range.upperBound
        }
    }

    func next() async -> Job? {
        await value.update {
            guard $0.position < $0.end else { return nil as Job? }
            let item = $0.items[$0.position]
            $0.position += 1
            return item
        } ?? nil
    }

    @MainActor func finish() async { await value.clear() }
}
