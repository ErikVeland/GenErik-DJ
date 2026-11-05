import Foundation
import TDJCore

final class NativeMusicAnalysisQueue: Sendable {
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
            case .managed(let track): track.analysis.duration
            case .native(let item, _): item.duration
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
    }

    private let value: BackgroundWorkValue<State>
    init(
        catalog: MusicLibraryCatalog, tracks: [Track], loaded: Set<String>, mediaDirectory: URL,
        worker: BackgroundFileWork
    ) {
        value = BackgroundWorkValue(
            State(catalog: catalog, tracks: tracks, loaded: loaded, mediaDirectory: mediaDirectory), worker: worker)
    }

    func prepare() async -> Int {
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
                let loadedA = a.element.trackID.map(state.loaded.contains) ?? false
                let loadedB = b.element.trackID.map(state.loaded.contains) ?? false
                if loadedA != loadedB { return loadedA }
                if a.element.duration != b.element.duration { return a.element.duration < b.element.duration }
                return a.offset < b.offset
            }.map(\.element)
            return state.items.count
        } ?? 0
    }

    func next() async -> Job? {
        await value.update {
            guard $0.position < $0.items.count else { return nil as Job? }
            let item = $0.items[$0.position]
            $0.position += 1
            return item
        } ?? nil
    }

    @MainActor func finish() async { await value.clear() }
}
