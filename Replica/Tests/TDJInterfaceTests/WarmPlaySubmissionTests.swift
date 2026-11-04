import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@MainActor private func warmPlayModel() async throws -> (ReplicaModel, URL) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    return (model, root)
}

@Test @MainActor func warmPlayReachesTheNextBarWithoutAnotherActorTurn() async throws {
    let (model, root) = try await warmPlayModel()
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    model.setMasterBPM(120)
    model.pressPlay(deck: .a)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    var remaining = 95872
    while remaining > 0 {
        let count = min(remaining, 512)
        _ = model.playback.core.renderOffline(frames: count)
        remaining -= count
    }
    model.refreshPlayback()
    model.pressPlay(deck: .b)
    #expect(model.playbackSnapshot?.b.phase == .queued)
    _ = model.playback.core.renderOffline(frames: 256)
    let started = try #require(model.playback.core.snapshot())
    #expect(started.b.phase == .playing)
    #expect(started.b.lastStartOutputFrame == 96000)
    #expect(started.outputFrame == 96128)
}

@Test @MainActor func warmSecondPlayCancelsPendingEntryBeforeYield() async throws {
    let (model, root) = try await warmPlayModel()
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    model.pressPlay(deck: .a)
    _ = model.playback.core.renderOffline(frames: 24000)
    model.refreshPlayback()
    model.pressPlay(deck: .b)
    #expect(model.playbackSnapshot?.b.phase == .queued)
    model.pressPlay(deck: .b)
    #expect(model.playbackSnapshot?.b.phase != .queued)
    for _ in 0..<200 { _ = model.playback.core.renderOffline(frames: 512) }
    await model.flushTransportRequests()
    #expect(model.playback.core.snapshot()?.b.phase != .playing)
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
}

@Test @MainActor func warmPlayThenStopCannotRestartAfterYield() async throws {
    let (model, root) = try await warmPlayModel()
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    model.pressPlay(deck: .a)
    #expect(model.playbackSnapshot?.a.phase == .playing)
    model.stopAudio()
    let stopped = try #require(model.playback.core.snapshot())
    await Task.yield()
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 256)
    let after = try #require(model.playback.core.snapshot())
    #expect(after.a.phase == .paused)
    #expect(after.a.sourceFrame == stopped.a.sourceFrame)
    #expect(after.masterBeat == stopped.masterBeat)
}
