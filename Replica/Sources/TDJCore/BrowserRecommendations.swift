import Foundation

/// Detail-pane recommendations: songs near the selected tempo with a compatible key.
/// Works on browser entries, so collection and first-minute values count before full preparation.
public enum BrowserRecommendations {
    public struct Match: Sendable, Identifiable {
        public let entry: LibraryBrowserEntry
        public let tempoCompatible: Bool
        public let keyCompatible: Bool
        public var id: String { entry.id }
    }
    /// Same Open Key number, or a neighbour number in the same mode, or the relative key.
    public static func keysCompatible(_ a: MusicalKey, _ b: MusicalKey) -> Bool {
        let na = openKeyNumber(a), nb = openKeyNumber(b)
        if na == nb { return true }
        guard a.mode == b.mode else { return false }
        let distance = abs(na - nb)
        return distance == 1 || distance == 11
    }
    static func openKeyNumber(_ key: MusicalKey) -> Int {
        let relativeMajor = key.mode == .major ? key.tonic : (key.tonic + 3) % 12
        return (relativeMajor * 7) % 12 + 1
    }
    /// Tempo within the tolerance, also at half or double time.
    public static func temposCompatible(_ a: Double, _ b: Double, tolerance: Double = 0.06) -> Bool {
        guard a > 0, b > 0, a.isFinite, b.isFinite else { return false }
        return [b, b * 2, b / 2].contains { abs($0 - a) / a <= tolerance }
    }
    /// Tempo within ±6 % (half and double time allowed), ranked compatible key first. A seed without
    /// a tempo falls back to key matches. Loaded tracks and the seed itself are excluded.
    public static func matches(for selected: LibraryBrowserEntry, in entries: [LibraryBrowserEntry],
                               excluding excluded: Set<String> = [], limit: Int = 12) -> [Match] {
        var results: [(Match, Double)] = []
        let skip = excluded.union([selected.id]).union(selected.track.map { [$0.id] } ?? [])
            .union(selected.nativeItem.map { [$0.id] } ?? [])
        for entry in entries where !skip.contains(entry.id) && !(entry.track.map { skip.contains($0.id) } ?? false) {
            let keyOK = selected.key.flatMap { a in entry.key.map { keysCompatible(a, $0) } } ?? false
            if let bpm = selected.bpm {
                guard let other = entry.bpm, temposCompatible(bpm, other) else { continue }
                let distance = min(abs(other - bpm), abs(other * 2 - bpm), abs(other / 2 - bpm)) / bpm
                results.append((Match(entry: entry, tempoCompatible: true, keyCompatible: keyOK), distance + (keyOK ? 0 : 1)))
            } else if keyOK {
                results.append((Match(entry: entry, tempoCompatible: false, keyCompatible: true), 0))
            }
            if results.count > limit * 40 { break }
        }
        return results.sorted { $0.1 < $1.1 }.prefix(limit).map(\.0)
    }
}
