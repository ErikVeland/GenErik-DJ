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
        model.load(trackID: track.id, deck: .a); await model.flushWrites()
        track.analysis.adaptiveCandidate = map
        track.analysis.adaptiveConfidence = 0.95
        model.library.tracks[0] = track
        model.selectGridMode(.adaptive, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        let replacement = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: rate * 4.1)], sampleRate: rate)
        model.library.tracks[0].analysis.adaptiveCandidate = replacement
        model.selectGridMode(.automatic, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == replacement)
        model.undoGridCorrection(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        model.viewport[.a] = rate * 2 + 100
        model.correctLocalAnchor(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap?.frame(atBeat: 4) == rate * 2 + 100)
        var updated = model.library
        updated.revision += 1
        let laterKey = MusicalKey(tonic: 2, mode: .minor)
        updated.tracks[0].preparation.correctedKey = laterKey
        model.adoptLibrary(updated)
        model.undoGridCorrection(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        #expect(model.gridPreparation(.a)?.correctedKey == laterKey)
        let correctionUndoCount = model.adaptiveUndo[track.id]?.count
        model.setGridLocked(true, deck: .a); await model.flushWrites()
        model.selectGridMode(.fixed, deck: .a)
        #expect(model.playbackSnapshot?.a.adaptiveMap == map)
        model.setGridLocked(false, deck: .a); await model.flushWrites()
        #expect(model.adaptiveUndo[track.id]?.count == correctionUndoCount)
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

extension AdaptiveGridEditorTests {
    @Test @MainActor func backgroundCandidatesLeaveEveryTransportStateUntouched() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
            .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        await model.importFiles([fixture])
        let track = try #require(model.library.tracks.first)
        for deck in DeckID.allCases { model.load(trackID: track.id, deck: deck); await model.flushWrites() }
        model.performance.cues[track.id] = [0: .init(frame: 12345)]
        for phase in ["paused", "playing", "loop", "flux", "queued"] {
            if phase == "playing" { model.pressPlay(deck: .a); await model.flushTransportRequests() }
            if phase == "loop" { model.setLoop(start: 0, end: track.analysis.sampleRate * 2, deck: .a) }
            if phase == "flux" { model.perform(.flux, deck: .a) }
            if phase == "queued" { model.pressPlay(deck: .b); await model.flushTransportRequests() }
            model.refreshPlayback()
            let before = try #require(model.playbackSnapshot)
            var changed = model.library
            changed.revision += 1
            changed.tracks[0].analysis.adaptiveCandidate = .init(anchors: [.init(beat: 0, frame: 0),
                .init(beat: 8, frame: track.analysis.sampleRate * 4.1)], sampleRate: track.analysis.sampleRate)
            changed.tracks[0].analysis.adaptiveConfidence = 0.9
            model.adoptLibrary(changed); model.refreshPlayback()
            #expect(model.playbackSnapshot == before)
            #expect(model.performance.cues[track.id]?[0]?.frame == 12345)
            #expect(model.track(.a)?.preparation == track.preparation)
        }
        await model.finishForShutdown()
    }
}

extension AdaptiveGridEditorTests {
    @Test @MainActor func rejectedMapDoesNotCommitPreparationOrUndo() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
            .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        await model.importFiles([fixture])
        let track = try #require(model.library.tracks.first)
        model.load(trackID: track.id, deck: .a); await model.flushWrites()
        let rate = track.analysis.sampleRate
        let slow = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: rate * 2),
                                         .init(beat: 5, frame: rate * 5)], sampleRate: rate)
        model.library.tracks[0].analysis.adaptiveCandidate = slow
        try model.playback.core.setMasterBPM(200); model.playback.core.processControlsWhileIdle(); model.refreshPlayback()
        model.selectGridMode(.adaptive, deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap == nil)
        #expect(model.track(.a)?.preparation.adaptiveMap == nil)
        #expect(model.adaptiveUndo[track.id]?.isEmpty != false)
        await model.finishForShutdown()
    }
    @Test @MainActor func downbeatAndTempoCorrectionsRetainAdaptiveSections() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent()
            .appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
        await model.importFiles([fixture])
        let track = try #require(model.library.tracks.first), rate = track.analysis.sampleRate
        model.load(trackID: track.id, deck: .a); await model.flushWrites()
        let map = BeatGridMap(anchors: [.init(beat: 0, frame: 0), .init(beat: 8, frame: rate * 4.1)], sampleRate: rate)
        model.library.tracks[0].analysis.adaptiveCandidate = map
        model.selectGridMode(.adaptive, deck: .a); await model.flushWrites()
        model.selectDownbeat(deck: .a, beat: 2); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap?.anchors == map.anchors)
        #expect(model.playbackSnapshot?.a.adaptiveMap?.downbeatOffset == 2)
        model.correctTempo(deck: .a, factor: 2); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.adaptiveMap?.anchors.last?.beat == 16)
        #expect(model.playbackSnapshot?.a.adaptiveMap?.anchors.last?.frame == map.anchors.last?.frame)
        model.selectGridMode(.fixed, deck: .a); await model.flushWrites()
        model.correctTempo(deck: .a, factor: 1.1); await model.flushWrites()
        model.undoGridCorrection(deck: .a); await model.flushWrites()
        #expect(model.playbackSnapshot?.a.grid == model.track(.a)?.grid)
        await model.finishForShutdown()
    }
}
