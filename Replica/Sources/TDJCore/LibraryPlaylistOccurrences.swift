import Foundation

public struct LibraryPlaylistOccurrence: Sendable, Identifiable {
    public let id: String
    public let membershipID: String
}
public enum LibraryPlaylistOccurrences {
    public static func build(
        playlistID: String, itemIDs: [String],
        checkCancellation: @Sendable () throws -> Void = { try Task.checkCancellation() }
    ) throws -> [LibraryPlaylistOccurrence] {
        try checkCancellation()
        var counts: [String: Int] = [:]
        var result: [LibraryPlaylistOccurrence] = []
        result.reserveCapacity(itemIDs.count)
        for (index, id) in itemIDs.enumerated() {
            if index & 255 == 0 { try checkCancellation() }
            let ordinal = counts[id, default: 0]
            counts[id] = ordinal + 1
            let rowID = "playlist:\(playlistID.utf8.count):\(playlistID):\(id.utf8.count):\(id):\(ordinal)"
            result.append(.init(id: rowID, membershipID: id))
        }
        try checkCancellation()
        return result
    }
}
