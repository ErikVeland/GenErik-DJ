import Foundation
import Testing
@testable import TDJCore

@Suite struct AdaptivePreparationTests {
    let map = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: 192_000)], sampleRate: 48_000)
    @Test func correctionRetainsOtherSectionsAndSupportsUndo() throws {
        var preparation = Preparation(grid: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000))
        try preparation.acceptAdaptive(map, frameCount: 480_000)
        let before = preparation
        try preparation.correctAnchor(beat: 4, frame: 97_000, frameCount: 480_000)
        #expect(preparation.adaptiveMap?.anchors.first == before.adaptiveMap?.anchors.first)
        #expect(preparation.adaptiveMap?.anchors.last == before.adaptiveMap?.anchors.last)
        #expect(preparation.adaptiveMap?.frame(atBeat: 4) == 97_000)
        preparation.gridLocked = true
        #expect(throws: (any Error).self) { try preparation.correctAnchor(beat: 4, frame: 99_000, frameCount: 480_000) }
        #expect(preparation.grid == before.grid)
        preparation = before
        #expect(preparation.adaptiveMap == map)
    }
    @Test func invalidWorkspaceMapFallsBackToFixed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try WorkspaceStore(root: root)
        var snapshot = LibrarySnapshot()
        var track = try syntheticTrack("a", bpm: 120)
        track.preparation.adaptiveMap = BeatGridMap(anchors: map.anchors, sampleRate: 1)
        snapshot.tracks = [track]
        try JSONEncoder().encode(snapshot).write(to: store.libraryURL)
        let loaded = try store.load()
        #expect(loaded.tracks[0].adaptiveMap == nil)
        #expect(loaded.tracks[0].grid == track.grid)
        #expect(loaded.tracks[0].analysis == track.analysis)
    }
}
