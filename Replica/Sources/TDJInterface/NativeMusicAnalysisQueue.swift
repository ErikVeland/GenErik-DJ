import Foundation
import TDJCore

final class NativeMusicAnalysisQueue: Sendable {
    private struct State: Sendable {
        let catalog: MusicLibraryCatalog
        let tracks: [Track]
        let loaded: Set<MusicLibrarySource>
        let analysedMixes: Set<String>
        var items: [MusicLibraryItem] = []
        var position = 0
    }
    private let value: BackgroundWorkValue<State>
    init(
        catalog: MusicLibraryCatalog, tracks: [Track], loaded: Set<MusicLibrarySource> = [],
        analysedMixes: Set<String> = [], worker: BackgroundFileWork
    ) {
        value = BackgroundWorkValue(
            State(catalog: catalog, tracks: tracks, loaded: loaded, analysedMixes: analysedMixes), worker: worker)
    }
    func prepare() async -> Int {
        await value.update {
            $0.items = MusicLibraryReconciliation(catalog: $0.catalog, tracks: $0.tracks).analysisOrder(
                loaded: $0.loaded, analysedMixes: $0.analysedMixes)
            return $0.items.count
        } ?? 0
    }
    func next() async -> MusicLibraryItem? {
        await value.update {
            guard $0.position < $0.items.count else { return nil as MusicLibraryItem? }
            let item = $0.items[$0.position]
            $0.position += 1
            return item
        } ?? nil
    }
    @MainActor func finish() async { await value.clear() }
}
