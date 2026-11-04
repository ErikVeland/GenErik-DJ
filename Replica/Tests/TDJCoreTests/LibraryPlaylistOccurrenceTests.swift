import Foundation
import Testing

@testable import TDJCore

@Test func nativePlaylistOccurrencesPreserveEveryRepeatedSource() throws {
    let rows = try LibraryPlaylistOccurrences.build(playlistID: "p", itemIDs: ["B", "raw", "A", "B"])
    #expect(rows.map(\.membershipID) == ["B", "raw", "A", "B"])
    #expect(rows.count == 4 && Set(rows.map(\.id)).count == 4)
}
@Test func nativePlaylistOccurrenceIDsSurviveFilteringSortingAndOtherSourceInsertions() throws {
    let ids = ["B", "raw", "A", "B"]
    let original = try LibraryPlaylistOccurrences.build(playlistID: "p", itemIDs: ids)
    let inserted = try LibraryPlaylistOccurrences.build(playlistID: "p", itemIDs: ["new"] + ids)
    #expect(
        original.filter { $0.membershipID == "B" }.map(\.id) == inserted.filter { $0.membershipID == "B" }.map(\.id))
    let other = try LibraryPlaylistOccurrences.build(playlistID: "q", itemIDs: ids)
    #expect(Set(original.map(\.id)).isDisjoint(with: other.map(\.id)))
    #expect(Set(original.sorted { $0.membershipID < $1.membershipID }.map(\.id)) == Set(original.map(\.id)))
}
