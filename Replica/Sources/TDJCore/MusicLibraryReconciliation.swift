import Foundation

public struct MusicLibraryReconciliation: Sendable {
    public struct Entry: Sendable {
        public let item: MusicLibraryItem
        public let track: Track?
    }

    public let entries: [Entry]
    public let analysisQueue: [MusicLibraryItem]

    public init(catalog: MusicLibraryCatalog, tracks: [Track]) {
        var matches: [MusicLibrarySource: Track] = [:]
        for track in tracks {
            for source in track.musicLibrarySources ?? [] where matches[source] == nil {
                matches[source] = track
            }
        }
        entries = catalog.items.map { Entry(item: $0, track: matches[$0.source]) }
        analysisQueue = entries.compactMap { entry in
            guard (entry.track == nil || entry.track?.analysis.musicalAnalysisDeferred == true),
                  entry.item.availability == .available else { return nil }
            return entry.item
        }
    }
}

extension MusicLibraryReconciliation {
    /// Analysis order: songs on a deck first, then shorter songs, then mixes. Mixes that already have
    /// a stored first-minute result are skipped.
    public func analysisOrder(loaded: Set<MusicLibrarySource>, analysedMixes: Set<String>) -> [MusicLibraryItem] {
        let candidates = analysisQueue.filter { !(NativeAnalysisPlan.isMix(duration: $0.duration) && analysedMixes.contains($0.id)) }
        return candidates.enumerated().sorted { a, b in
            let la = loaded.contains(a.element.source), lb = loaded.contains(b.element.source)
            if la != lb { return la }
            let ma = NativeAnalysisPlan.isMix(duration: a.element.duration), mb = NativeAnalysisPlan.isMix(duration: b.element.duration)
            if ma != mb { return !ma }
            if a.element.duration != b.element.duration { return a.element.duration < b.element.duration }
            return a.offset < b.offset
        }.map(\.element)
    }
}
