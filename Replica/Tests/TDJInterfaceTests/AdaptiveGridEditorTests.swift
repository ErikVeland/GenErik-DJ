import Foundation
import Testing
import TDJCore
@testable import TDJInterface

@Suite struct AdaptiveGridEditorTests {
    @Test @MainActor func candidateActivationCorrectionUndoAndLock() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
            .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        await model.importFiles([fixture])
        var track = try #require(model.library.tracks.first)
        let rate = track.analysis.sampleRate
        let map = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: rate * 4)], sampleRate: rate)
        track.analysis.adaptiveCandidate = map
        track.analysis.adaptiveConfidence = 0.95
        model.library.tracks[0] = track
        model.load(trackID: track.id, deck: .a); await model.flushWrites()
        model.selectGridMode(.adaptive, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        model.viewport[.a] = rate * 2 + 100
        model.correctLocalAnchor(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap?.frame(atBeat: 4) == rate * 2 + 100)
        model.undoGridCorrection(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        model.setGridLocked(true, deck: .a); await model.flushWrites()
        model.selectGridMode(.fixed, deck: .a)
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        model.setGridLocked(false, deck: .a); await model.flushWrites()
        model.selectGridMode(.fixed, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == nil)
        model.pressPlay(deck: .a); await model.flushTransportRequests()
        _ = model.playback.core.renderOffline(frames: 1000); model.refreshPlayback()
        let before = model.playbackSnapshot
        model.selectGridMode(.adaptive, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == nil)
        #expect(model.playbackSnapshot?.a.sourceFrame == before?.a.sourceFrame)
        await model.finishForShutdown()
    }
}
