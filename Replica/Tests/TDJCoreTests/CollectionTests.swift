import Foundation
import Testing
@testable import TDJCore

@Test func collectionPlaylistsRetainOrderAvoidDuplicatesAndSurviveRestart() throws {
    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:url) }
    var collection=CollectionPlaylists()
    try collection.add(trackIDs:["b","a","b"],name:"  Opening set  ")
    let id=try #require(collection.playlists.first?.id)
    try collection.add(trackIDs:["a","c"],to:id)
    try collection.save(to:url)
    let restored=try CollectionPlaylists.load(from:url)
    #expect(restored.playlists.first?.name == "Opening set")
    #expect(restored.playlists.first?.trackIDs == ["b","a","c"])
    #expect(restored == collection)
    #expect(throws:CoreError.self) { try collection.add(trackIDs:[],name:"   ") }
    #expect(collection == restored)
    try Data("broken".utf8).write(to:url)
    #expect(throws:(any Error).self) { try CollectionPlaylists.load(from:url) }
    #expect(try String(contentsOf:url,encoding:.utf8) == "broken")
}
