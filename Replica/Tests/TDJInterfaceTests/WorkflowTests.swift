import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@Test(arguments: ["GenErik DJ.app", "GenErik DJ Development.app"])
func packagedAppDoesNotUseFindersWorkingDirectory(_ appName: String) {
    let bundle = URL(fileURLWithPath: "/tmp/project/Replica/Build/\(appName)")
    #expect(
        DevelopmentWorkspace.resolve(override: nil, bundleURL: bundle, currentDirectory: "/").path
            == "/tmp/project/Replica/.workspace")
    #expect(
        DevelopmentWorkspace.resolve(override: "/tmp/explicit", bundleURL: bundle, currentDirectory: "/").path
            == "/tmp/explicit")
    #expect(
        DevelopmentWorkspace.resolve(
            override: nil, bundleURL: URL(fileURLWithPath: "/tmp/binary"), currentDirectory: "/tmp/project"
        ).path == "/tmp/project/.workspace")
}

@MainActor private func makeModel(offline: Bool = true) async throws -> (ReplicaModel, URL) {
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: offline))
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")])
    return (model, root)
}

@Test @MainActor func playDoesNotWaitForUnrelatedPreparationPersistence() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    let stalled = AsyncStream<Void>.makeStream()
    model.preparationWrites = Task { for await _ in stalled.stream {} }
    model.pressPlay(deck: .a)
    for _ in 0..<100 {
        if model.playback.core.snapshot()?.a.phase == .playing { break }
        await Task.yield()
    }
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    stalled.continuation.finish()
    await model.flushWrites()
    await model.flushTransportRequests()
    model.stopAudio()
}

@Test @MainActor func waveformWaitsWhileAudioOwnsTheLaunchDeadline() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 48000)
    model.refreshPlayback()
    model.pressPlay(deck: .b)
    await model.flushTransportRequests()
    #expect(model.playbackSnapshot?.b.phase == .queued)
    #expect(model.viewport[.b] == 0)
    #expect(try #require(model.playbackSnapshot?.b.leadInSourceFrame) < 0)
    _ = model.playback.core.renderOffline(frames: 48000)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.b.phase == .queued)
    _ = model.playback.core.renderOffline(frames: 1)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.b.phase == .playing)
    #expect(model.playbackSnapshot?.b.lastStartOutputFrame == 96000)
    #expect(try #require(model.viewport[.b]) > 0)
    model.stopAudio()
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(model.playbackSnapshot?.b.phase == .paused)
}

@Test @MainActor func explicitSyncToggleRestoresAlignmentAndRetainsOffChoice() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer {
        model.stopAudio()
        try? FileManager.default.removeItem(at: root)
    }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 4800)
    model.refreshPlayback()
    let running = try #require(model.playbackSnapshot)
    let grid = try #require(running.a.grid)
    let aligned = try #require(
        grid.nearestPhaseAlignedFrame(
            to: track.analysis.sampleRate * 3, masterBeat: running.masterBeat,
            within: 0..<Double(track.analysis.frameCount)))
    model.toggleSync(deck: .a)
    try model.playback.perform(.jump, deck: .a, value: aligned + grid.framesPerBeat * 0.25)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let before = try #require(model.playbackSnapshot)
    #expect(!before.a.synced)
    #expect(abs(try #require(before.syncPhaseError(.a))) > 0.1)
    model.toggleSync(deck: .a)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    let restored = try #require(model.playbackSnapshot)
    #expect(restored.a.synced && !restored.syncNeedsAlignment(.a))
    #expect(abs(restored.a.sourceFrame - aligned) < 0.000001)
    #expect(restored.masterBeat == before.masterBeat && restored.outputFrame == before.outputFrame)
    model.toggleSync(deck: .a)
    model.refreshPlayback()
    #expect(model.playbackSnapshot?.a.synced == false)
    #expect(model.playbackSnapshot?.a.sourceFrame == restored.a.sourceFrame)
}

@Test @MainActor func developmentKeylockIsPerDeckAndSurvivesReloadWithoutChangingSync() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    #expect(model.playbackSnapshot?.a.keylock == true)
    #expect(model.playbackSnapshot?.b.keylock == true)
    model.toggleKeylock(deck: .a)
    #expect(model.playbackSnapshot?.a.keylock == false)
    #expect(model.playbackSnapshot?.a.synced == true)
    #expect(model.playbackSnapshot?.b.keylock == true)
    model.toggleSync(deck: .a)
    #expect(model.playbackSnapshot?.a.keylock == false)
    #expect(model.playbackSnapshot?.a.synced == false)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    #expect(model.playbackSnapshot?.a.keylock == false)
    #expect(model.playbackSnapshot?.b.keylock == true)
    #expect(model.playbackSnapshot?.a.phase == .ready)
}

@Test @MainActor func developmentStopClearsQueuedAudioEvenWhenControlRingsAreFull() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    model.load(trackID: track.id, deck: .b)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 24000)
    model.refreshPlayback()
    model.pressPlay(deck: .b)
    await model.flushTransportRequests()
    for _ in 0..<4 {
        for _ in 0..<127 { try? model.playback.core.setMasterBPM(129) }
        model.playback.core.processControlsWhileIdle()
    }
    var full = false
    for _ in 0..<128 {
        do { try model.playback.core.setMasterBPM(130) } catch {
            full = true
            break
        }
    }
    #expect(full)
    model.stopAudio()
    #expect(model.playbackSnapshot?.a.phase == .paused)
    #expect(model.playbackSnapshot?.b.phase == .paused)
    #expect(model.playbackSnapshot?.clockRunning == false)
    let stopped = model.playback.core.snapshot()
    let output = model.playback.core.renderOffline(frames: 256)
    #expect(output.left.allSatisfy(\.isFinite) && output.right.allSatisfy(\.isFinite))
    #expect(output.left.suffix(160).allSatisfy { $0 == 0 })
    #expect(output.right.suffix(160).allSatisfy { $0 == 0 })
    #expect(model.playback.core.snapshot()?.a.sourceFrame == stopped?.a.sourceFrame)
    #expect(model.playback.core.snapshot()?.b.sourceFrame == stopped?.b.sourceFrame)
    #expect(model.playback.core.snapshot()?.masterBeat == stopped?.masterBeat)
}

@Test @MainActor func rapidLoadsCommitOnlyTheLatestPreparedTrack() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    var base = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    await model.importFiles([base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-b-128.wav")])
    let first = model.library.tracks[0]
    let last = model.library.tracks[1]
    model.load(trackID: first.id, deck: .a)
    model.load(trackID: last.id, deck: .a)
    await model.flushWrites()
    #expect(model.loaded[.a] == last.id)
    #expect(model.preparingPlayback.isEmpty)
    #expect(model.playbackSnapshot?.a.sourceBPM == last.bpm)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 48000)
    model.refreshPlayback()
    #expect(abs(try #require(model.playbackSnapshot?.a.sourceFrame) - 44100) < 0.001)
    model.load(trackID: first.id, deck: .a)
    #expect(model.loaded[.a] == last.id)
    #expect(model.status == TransportError.protectedDeck.localizedDescription)
    model.stopAudio()
}

@Test @MainActor func selectionAndArtworkUsePerformerPolicyWithoutLoading() async throws {
    let (model, root) = try await makeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.showLibrary()
    model.selectedTrackID = track.id
    #expect(model.loaded.isEmpty)
    model.load(trackID: track.id, deck: .a)
    #expect(model.loaded[.a] == track.id)
    #expect(model.loaded[.b] == nil)
    #expect(model.browserVisible == false)
    model.showSuggestions(destination: .b)
    #expect(model.suggestionDestination == .b)
    #expect(model.browserVisible)
    #expect(model.suggestions.isEmpty)
    #expect(model.suggestionMessage == nil)
    await model.flushWrites()
    let stored = try model.store.load()
    #expect(stored.events.count == 1)
    #expect(stored.events.first?.kind == .load)
    #expect(stored.adaptiveMemory.revision == 0)
}

@Test @MainActor func gridEditsPersistWithoutChangingDeckIdentityOrDetectedTempo() async throws {
    let (model, root) = try await makeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .b)
    model.correctTempo(deck: .b, factor: 0.5)
    model.selectDownbeat(deck: .b, beat: 2)
    await model.flushWrites()
    let restored = try model.store.load()
    #expect(model.loaded[.b] == track.id)
    #expect(restored.tracks[0].bpm == 60)
    #expect(model.playback.core.snapshot()?.b.sourceBPM == 60)
    #expect(restored.tracks[0].analysis.bpm == 120)
    #expect(restored.tracks[0].grid?.downbeatOffset == 2)
    #expect(restored.tracks[0].preparation.gridIsManual)
}

@Test @MainActor func loadedTrackLookupRefreshesAfterLibraryEditsAndDeckChanges() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = try #require(model.library.tracks.first)
    model.loaded[.a] = original.id
    #expect(model.track(.a)?.artist == original.artist)
    let revision = model.library.revision
    model.library.tracks[0].artist = "Updated while loaded"
    #expect(model.library.revision == revision)
    #expect(model.track(.a)?.artist == "Updated while loaded")
    model.loaded[.a] = "missing"
    #expect(model.track(.a) == nil)
    model.loaded[.a] = original.id
    #expect(model.track(.a)?.artist == "Updated while loaded")
    model.library.tracks.removeAll()
    #expect(model.track(.a) == nil)
}

@Test @MainActor func newlyPreparedDeckCanPlayBeforeLoadHistoryFinishesSaving() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    let blocked = AsyncStream<Void>.makeStream()
    model.historyWrites = Task { for await _ in blocked.stream {} }
    model.load(trackID: track.id, deck: .a)
    for _ in 0..<2000 {
        if !model.preparingPlayback.contains(.a) { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    let ready = !model.preparingPlayback.contains(.a)
    if ready {
        model.pressPlay(deck: .a)
        await model.flushTransportRequests()
    }
    let playing = model.playbackSnapshot?.a.phase == .playing
    blocked.continuation.finish()
    await model.flushWrites()
    #expect(ready)
    #expect(playing)
    #expect(model.library.events.contains { $0.kind == .load && $0.toTrackID == track.id })
    await model.finishForShutdown()
}

@Test @MainActor func olderLibraryCompletionsCannotReplaceNewerState() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    var newer = LibrarySnapshot()
    newer.revision = 2
    var older = LibrarySnapshot()
    older.revision = 1
    model.adoptLibrary(newer)
    model.adoptLibrary(older)
    #expect(model.library.revision == 2)
}

@Test @MainActor func snapshotWaveformsHydrateWithoutStartingAudio() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try #require(model.library.tracks.first?.id)
    #expect(model.library.tracks[0].analysis.waveform.isEmpty)
    model.loaded[.a] = id
    try await model.prepareLoadedWaveforms()
    #expect(model.track(.a)?.analysis.waveform.isEmpty == false)
    #expect(model.library.tracks[0].analysis.waveform.isEmpty)
    #expect(model.playback.core.snapshot()?.a.phase == .empty)
    #expect(!model.playback.outputActive)
}

@Test @MainActor func missingWaveformRecoveryCannotHoldIncomingAudioBehindAnalysis() async throws {
    let (model, root) = try await makeModel(offline: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    let store = try WorkspaceStore(root: root)
    let filename = try #require(track.analysis.waveformReference)
    try FileManager.default.removeItem(at: store.waveformDirectory.appendingPathComponent(filename))
    let entered = AsyncStream<Void>.makeStream()
    let release = DispatchSemaphore(value: 0)
    let blocker = Task {
        try await AnalysisWorker.shared.run { _ in
            entered.continuation.yield(())
            release.wait()
        }
    }
    defer {
        release.signal()
        blocker.cancel()
        entered.continuation.finish()
    }
    var start = entered.stream.makeAsyncIterator()
    _ = await start.next()
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    #expect(!model.preparingPlayback.contains(.a))
    #expect(model.preparingWaveforms.contains(track.id))
    #expect(model.track(.a)?.analysis.waveform.isEmpty == true)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    #expect(model.playback.core.snapshot()?.a.phase == .playing)
    release.signal()
    try await blocker.value
    await model.flushWaveforms()
    #expect(model.track(.a)?.analysis.waveform.isEmpty == false)
    model.stopAudio()
}

@Test @MainActor func recordingTracklistIncludesPlayingTrackOnce() async throws {
    let (model, root) = try await makeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 512)
    await model.toggleRecording()
    _ = model.playback.core.renderOffline(frames: 1024)
    model.refreshPlayback()
    model.refreshPlayback()
    await model.toggleRecording()
    let recording = try #require(model.recordings.first)
    let contents = try String(
        contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    let artist = track.artist.isEmpty ? "Unknown Artist" : track.artist
    #expect(contents == "00:00:00 - \(artist) - \(track.title)\n")
}

@Test @MainActor func recordingTracklistRetainsTrackHeardBetweenSnapshots() async throws {
    let (model, root) = try await makeModel()
    defer { try? FileManager.default.removeItem(at: root) }
    let track = try #require(model.library.tracks.first)
    model.load(trackID: track.id, deck: .a)
    await model.flushWrites()
    model.setMixer(.volume, value: 0, deck: .a)
    model.pressPlay(deck: .a)
    await model.flushTransportRequests()
    _ = model.playback.core.renderOffline(frames: 512)
    await model.toggleRecording()
    try model.playback.core.setMixer(.volume, value: 1, deck: .a)
    _ = model.playback.core.renderOffline(frames: 48000)
    try model.playback.core.setMixer(.volume, value: 0, deck: .a)
    _ = model.playback.core.renderOffline(frames: 512)
    model.refreshPlayback()
    await model.toggleRecording()
    let recording = try #require(model.recordings.first)
    let contents = try String(
        contentsOf: recording.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(contents.contains(track.title))
}
