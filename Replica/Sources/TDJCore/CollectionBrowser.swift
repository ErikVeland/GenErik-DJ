import Foundation

public enum CollectionSort: String, CaseIterable, Sendable { case title = "Title", artist = "Artist", album = "Album", key = "Key", bpm = "BPM" }
public enum CollectionBrowser {
    public static func tracks(_ tracks: [Track], search: String, sort: CollectionSort?) -> [Track] {
        let words=search.split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered=tracks.indices.filter { index in
            let track=tracks[index]
            let fields=[track.title,track.artist,track.album ?? "",track.genre ?? ""]
            return words.allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
        }
        guard let sort else { return filtered.map { tracks[$0] } }
        let ordered=filtered.sorted { a,b in
            let first=tracks[a], second=tracks[b]
            switch sort {
            case .title, .artist, .album:
                let left=sort == .title ? first.title : sort == .artist ? first.artist : (first.album ?? "")
                let right=sort == .title ? second.title : sort == .artist ? second.artist : (second.album ?? "")
                let order=left.localizedStandardCompare(right)
                if order != .orderedSame { return order == .orderedAscending }
            case .key:
                let left=first.key?.name, right=second.key?.name
                if left != right {
                    guard let left else { return false }; guard let right else { return true }
                    return left.localizedStandardCompare(right) == .orderedAscending
                }
            case .bpm:
                let left=first.bpm ?? .infinity, right=second.bpm ?? .infinity
                if left != right { return left<right }
            }
            return a<b
        }
        return ordered.map { tracks[$0] }
    }
}
