import Foundation
import Testing
@testable import TDJCore
@testable import TDJInterface


private final class PinTestBarrier: @unchecked Sendable {
    private let entered = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let released = AsyncStream<Void>.makeStream()
    private let lock = NSLock()
    private var expired = false
    func hold() async {
        entered.continuation.yield(())
        for await _ in released.stream { }
    }
    func waitUntilEntered() async -> Bool {
        for await _ in entered.stream { return true }
        return false
    }
    func open(expired: Bool = false) {
        lock.withLock { self.expired = self.expired || expired }
        entered.continuation.finish()
        released.continuation.finish()
    }
    var timedOut: Bool { lock.withLock { expired } }
    func watchdog() -> Task<Void, Never> {
        Task.detached(priority: .background) {
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            self.open(expired: true)
        }
    }
}

private func pinTestWAV(_ file: URL, sample: UInt8) throws {
    var data = Data()
    func text(_ value: String) { data.append(contentsOf: value.utf8) }
    func word(_ value: UInt16) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    func long(_ value: UInt32) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
    text("RIFF"); long(36 + 192000); text("WAVEfmt "); long(16)
    word(1); word(2); long(48000); long(192000); word(4); word(16)
    text("data"); long(192000)
    data.append(Data(repeating: sample, count: 192000))
    try data.write(to: file)
}

@MainActor
private func pinTestFixture() throws -> (model: ReplicaModel, root: URL, a: Track, b: Track) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = try WorkspaceStore(root: root)
    func track(_ name: String, sample: UInt8, bpm: Double) throws -> Track {
        let file = store.mediaDirectory.appendingPathComponent(name + ".wav")
        try pinTestWAV(file, sample: sample)
        let analysis = AudioAnalysis(implementation: "Synthetic pin test", configurationID: "pin-synthetic",
            contentSHA256: try AudioAnalyzer.sha256(url: file), sampleRate: 48000, frameCount: 48000,
            channelCount: 2, waveformFramesPerBin: 512,
            waveform: (0..<94).map { _ in WaveformBin(minimum: 0, maximum: 0, rms: 0) },
            bpm: bpm, beatAnchorFrame: 0, tempoConfidence: 0, key: nil, keyConfidence: 0, chroma: [], timbre: [])
        return try Track(title: name, mediaFilename: name + ".wav", analysis: analysis)
    }
    var a = try track("pin-a", sample: 1, bpm: 110)
    a.musicLibrarySources = [.init(platform: .iosMusic, persistentID: "4660")]
    let b = try track("pin-b", sample: 2, bpm: 130)
    var library = LibrarySnapshot()
    library.tracks = [a, b]
    _ = try store.save(library)
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    return (model, root, a, b)
}

@MainActor
private func pinTestCatalogue(_ model: ReplicaModel) async throws {
    let xml = "<NML VERSION=\"17\"><HEAD PROGRAM=\"Traktor DJ\"/><COLLECTION ENTRIES=\"1\"><ENTRY><ITUNES PERSISTENT_ID=\"0000000000001234\" PLAYTIME=\"1000\"/><TEMPO BPM=\"120\"/><MUSICAL_KEY VALUE=\"0\"/><CUE_V2 TYPE=\"4\" START=\"0\" HOTCUE=\"-1\"/><CUE_V2 TYPE=\"0\" START=\"500\" HOTCUE=\"2\"/></ENTRY></COLLECTION></NML>"
    let file = model.store.root.appendingPathComponent("pin-reference.nml")
    try Data(xml.utf8).write(to: file)
    _ = try await model.service.importTraktorCollection(url: file)
}

@MainActor
private func pinTestLoad(_ model: ReplicaModel, _ track: Track, _ deck: DeckID = .a) async {
    model.load(trackID: track.id, deck: deck)
    await model.playbackLoads?.value
    model.refreshPlayback()
}

private func pinTestGrid(_ bpm: Double) throws -> BeatGrid {
    try BeatGrid(bpm: bpm, anchorFrame: 0, sampleRate: 48000)
}

@Test @MainActor
func preparationPinStaleProtectionCaptureCannotChangePlayingDeckAndReloadUsesReference() async throws {
    let f = try pinTestFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    try await pinTestCatalogue(f.model)
    let capturedProtection = Set(f.model.loaded.values)
    #expect(capturedProtection.isEmpty)
    await pinTestLoad(f.model, f.a)
    f.model.pressPlay(deck: .a)
    _ = f.model.playback.core.renderOffline(frames: 256)
    #expect(f.model.playback.core.snapshot()?.a.phase == .playing)
    let staged = try await f.model.service.reuseTraktorPreparationForExistingTracks(
        preservePreparationFor: capturedProtection)
    f.model.adoptLibrary(staged)
    #expect(staged.tracks.first { $0.id == f.a.id }?.preparation.grid?.bpm == 110)
    #expect(staged.tracks.first { $0.id == f.a.id }?.grid?.bpm == 120)
    #expect(staged.tracks.first { $0.id == f.a.id }?.traktorPreparation?.normalized.grid?.bpm == 120)
    #expect(f.model.grid(.a)?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    f.model.playback.stopAudio()
    f.model.refreshPlayback()
    await pinTestLoad(f.model, f.a)
    #expect(f.model.grid(.a)?.bpm == 120)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 120)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinQueuedLoadKeepsGridAfterItsSaveClearsTheDraft() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    f.model.playbackLoads = Task { await gate.hold() }
    try #require(await gate.waitUntilEntered())
    f.model.load(trackID: f.a.id, deck: .a)
    let edited = try pinTestGrid(137)
    f.model.saveGrid(edited, deck: .a)
    await f.model.preparationWrites?.value
    #expect(f.model.gridDraft[.a] == nil)
    #expect(f.model.preparingPlayback.contains(.a))
    gate.open()
    await f.model.playbackLoads?.value
    #expect(!gate.timedOut)
    #expect(f.model.grid(.a) == edited)
    #expect(f.model.playback.core.snapshot()?.a.grid == edited)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinDecodedLoadReconcilesAnEditWhosePersistenceAlreadyFinished() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .decoded = checkpoint { await gate.hold() }
    }
    f.model.load(trackID: f.a.id, deck: .a)
    try #require(await gate.waitUntilEntered())
    let edited = try pinTestGrid(137)
    f.model.saveGrid(edited, deck: .a)
    await f.model.preparationWrites?.value
    #expect(f.model.gridDraft[.a] == nil)
    #expect(f.model.preparingPlayback.contains(.a))
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    #expect(!gate.timedOut)
    #expect(f.model.grid(.a) == edited)
    #expect(f.model.playback.core.snapshot()?.a.grid == edited)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinGridQueueRejectionAfterAcceptanceKeepsActualNewIdentity() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    await pinTestLoad(f.model, f.a)
    let previousGeneration = f.model.playback.generations[.a]
    var acceptedGeneration: UInt64?
    var queueWasFull = false
    f.model.playback.loadCheckpoint = { checkpoint in
        switch checkpoint {
        case .decoded: await gate.hold()
        case .submitted: break
        case .accepted(let generation):
            acceptedGeneration = generation
            for _ in 0..<256 {
                do { try f.model.playback.core.setMasterBPM(120) }
                catch TransportError.queueFull { queueWasFull = true; break }
            }
        }
    }
    f.model.load(trackID: f.b.id, deck: .a)
    try #require(await gate.waitUntilEntered())
    f.model.saveGrid(try pinTestGrid(137), deck: .a)
    await f.model.preparationWrites?.value
    #expect(f.model.gridDraft[.a] == nil)
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    #expect(!gate.timedOut && queueWasFull)
    #expect(acceptedGeneration != nil && acceptedGeneration != previousGeneration)
    #expect(f.model.loaded[.a] == f.b.id)
    #expect(f.model.track(.a)?.id == f.b.id)
    #expect(f.model.playback.core.snapshot()?.a.generation == acceptedGeneration)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 130)
    #expect(f.model.grid(.a)?.bpm == 130)
    #expect(!f.model.preparingPlayback.contains(.a))
    #expect(!f.model.status.isEmpty)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinObsoleteAcceptedLoadIsRestoredWhenLatestReplacementFails() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    var acceptedGeneration: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .accepted(let generation) = checkpoint {
            acceptedGeneration = generation
            await gate.hold()
        }
    }
    f.model.load(trackID: f.a.id, deck: .a)
    try #require(await gate.waitUntilEntered())
    f.model.load(trackID: f.b.id, deck: .a)
    try FileManager.default.removeItem(at: f.model.store.mediaDirectory.appendingPathComponent(f.b.mediaFilename))
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    #expect(!gate.timedOut)
    #expect(f.model.loaded[.a] == f.a.id)
    #expect(f.model.track(.a)?.id == f.a.id)
    #expect(f.model.playback.core.snapshot()?.a.generation == acceptedGeneration)
    #expect(f.model.grid(.a)?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    #expect(!f.model.preparingPlayback.contains(.a))
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinTwoPlayingDecksKeepIndependentGridsAfterOneDeckEdit() async throws {
    let f = try pinTestFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    await pinTestLoad(f.model, f.a, .a)
    await pinTestLoad(f.model, f.a, .b)
    for deck in DeckID.allCases {
        try f.model.playback.setSync(false, deck: deck)
        f.model.pressPlay(deck: deck)
    }
    _ = f.model.playback.core.renderOffline(frames: 256)
    #expect(f.model.playback.core.snapshot()?.a.phase == .playing)
    #expect(f.model.playback.core.snapshot()?.b.phase == .playing)
    f.model.saveGrid(try pinTestGrid(117), deck: .a)
    await f.model.preparationWrites?.value
    #expect(f.model.grid(.a)?.bpm == 117)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 117)
    #expect(f.model.grid(.b)?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.b.grid?.bpm == 110)
    #expect(f.model.library.tracks.first { $0.id == f.a.id }?.grid?.bpm == 117)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinSameTrackPreparingDeckReceivesTheLatestManualGrid() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    await pinTestLoad(f.model, f.a, .a)
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .decoded = checkpoint { await gate.hold() }
    }
    f.model.load(trackID: f.a.id, deck: .b)
    try #require(await gate.waitUntilEntered())
    f.model.saveGrid(try pinTestGrid(117), deck: .a)
    await f.model.preparationWrites?.value
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    #expect(!gate.timedOut)
    for deck in DeckID.allCases {
        #expect(f.model.grid(deck)?.bpm == 117)
        #expect(f.model.playback.core.snapshot()?[deck].grid?.bpm == 117)
    }
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinCancellingHeldGridPreviewRevealsCommittedPreparation() async throws {
    let f = try pinTestFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    await pinTestLoad(f.model, f.a)
    let committed = try pinTestGrid(117)
    f.model.saveGrid(committed, deck: .a)
    await f.model.preparationWrites?.value
    f.model.editing.insert(.a)
    let session = WaveformGestureSession()
    let began = SurfacePoint(id: 1, x: 0.25, y: 0.5)
    let moved = SurfacePoint(id: 1, x: 0.35, y: 0.5)
    session.handle(.init(phase: .began, points: [began], ending: []), model: f.model, deck: .a, span: 48000)
    session.handle(.init(phase: .moved, points: [moved], ending: []), model: f.model, deck: .a, span: 48000)
    #expect(f.model.gridDraft[.a] != nil && f.model.grid(.a) != committed)
    try await pinTestCatalogue(f.model)
    f.model.adoptLibrary(try await f.model.service.reuseTraktorPreparationForExistingTracks())
    session.handle(.init(phase: .cancelled, points: [moved], ending: [1]), model: f.model, deck: .a, span: 48000)
    #expect(f.model.gridDraft[.a] == nil)
    #expect(f.model.grid(.a) == committed)
    #expect(f.model.playback.core.snapshot()?.a.grid == committed)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinPreparingKeyEditAndCueDeletionSurviveLoadAndReplay() async throws {
    let f = try pinTestFixture(), gate = PinTestBarrier()
    let watchdog = gate.watchdog()
    defer { gate.open(); watchdog.cancel(); try? FileManager.default.removeItem(at: f.root) }
    try await pinTestCatalogue(f.model)
    f.model.adoptLibrary(try await f.model.service.reuseTraktorPreparationForExistingTracks())
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .decoded = checkpoint { await gate.hold() }
    }
    f.model.load(trackID: f.a.id, deck: .a)
    try #require(await gate.waitUntilEntered())
    #expect(f.model.performance.cues[f.a.id]?[2] != nil)
    var preparation = try #require(f.model.track(.a)?.preparation)
    let editedKey = MusicalKey(tonic: 2, mode: .minor)
    preparation.correctedKey = editedKey
    f.model.adoptLibrary(try await f.model.service.updatePreparation(trackID: f.a.id, preparation: preparation))
    f.model.cue(slot: 2, deck: .a, delete: true)
    #expect(f.model.track(.a)?.key == editedKey)
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    await f.model.flushPerformanceWrites()
    #expect(!gate.timedOut)
    #expect(f.model.track(.a)?.key == editedKey)
    #expect(f.model.performance.cues[f.a.id]?[2] == nil)
    let saved = try PerformancePreparation.load(from: f.root.appendingPathComponent("performance.json"))
    #expect(saved.cues[f.a.id]?[2] == nil)
    #expect(saved.traktorCueHistory?[f.a.id]?.previouslyImportedSlots.contains(2) == true)
    await pinTestLoad(f.model, f.a)
    #expect(f.model.track(.a)?.key == editedKey)
    #expect(f.model.performance.cues[f.a.id]?[2] == nil)
    await f.model.finishForShutdown()
}


@Test @MainActor
func preparationPinCancelledWaitStillPublishesTheLaterNativeAcceptance() async throws {
    let f=try pinTestFixture()
    defer { try? FileManager.default.removeItem(at:f.root) }
    await pinTestLoad(f.model,f.a)
    let old=f.model.playback.core.snapshot()?.a.generation
    var submitted: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted(let generation)=checkpoint { submitted=generation;throw CancellationError() }
    }
    f.model.load(trackID:f.b.id,deck:.a)
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(submitted != nil && submitted != old)
    #expect(f.model.playback.core.snapshot()?.a.generation == submitted)
    #expect(f.model.playback.generations[.a] == submitted)
    #expect(f.model.loaded[.a] == f.b.id && f.model.track(.a)?.id == f.b.id)
    #expect(f.model.grid(.a)?.bpm == 130)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 130)
    #expect(!f.model.preparingPlayback.contains(.a))
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinLateObsoleteAcceptanceSurvivesTheLatestReplacementFailure() async throws {
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    var submitted: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted(let generation)=checkpoint {
            submitted=generation
            await gate.hold()
            throw CancellationError()
        }
    }
    f.model.load(trackID:f.a.id,deck:.a)
    try #require(await gate.waitUntilEntered())
    f.model.load(trackID:f.b.id,deck:.a)
    try FileManager.default.removeItem(at:f.model.store.mediaDirectory.appendingPathComponent(f.b.mediaFilename))
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(!gate.timedOut)
    #expect(f.model.playback.core.snapshot()?.a.generation == submitted)
    #expect(f.model.loaded[.a] == f.a.id && f.model.track(.a)?.id == f.a.id)
    #expect(f.model.grid(.a)?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    await f.model.finishForShutdown()
}


@Test @MainActor
func preparationPinHeldGridContactCannotWriteIntoASameTrackReload() async throws {
    let f=try pinTestFixture()
    defer { try? FileManager.default.removeItem(at:f.root) }
    await pinTestLoad(f.model,f.a)
    let old=f.model.playback.core.snapshot()?.a.generation
    let gesture=WaveformGestureSession()
    f.model.editing.insert(.a)
    let first=SurfacePoint(id:1,x:0.5,y:0.5),moved=SurfacePoint(id:1,x:0.7,y:0.5)
    gesture.handle(.init(phase:.began,points:[first],ending:[]),model:f.model,deck:.a,span:48000)
    gesture.handle(.init(phase:.moved,points:[moved],ending:[]),model:f.model,deck:.a,span:48000)
    try #require(f.model.gridDraft[.a] != nil)
    await pinTestLoad(f.model,f.a)
    #expect(f.model.playback.core.snapshot()?.a.generation != old)
    f.model.editing.insert(.a)
    let fresh=try pinTestGrid(137)
    f.model.gridDraft[.a]=fresh
    gesture.handle(.init(phase:.ended,points:[moved],ending:[1]),model:f.model,deck:.a,span:48000)
    #expect(f.model.gridDraft[.a] == fresh)
    #expect(f.model.track(.a)?.grid?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    await f.model.preparationWrites?.value
    #expect(try f.model.store.load(includeWaveforms:false).tracks.first { $0.id==f.a.id }?.preparation.grid?.bpm == 110)
    f.model.gridDraft[.a]=nil
    await f.model.finishForShutdown()
}

@Test(arguments: ["unchanged", "minor", "cleared"]) @MainActor
func preparationPinLateAcceptanceRetainsManualKeyEditedBeforeCancellation(_ mode: String) async throws {
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    try await pinTestCatalogue(f.model)
    f.model.adoptLibrary(try await f.model.service.reuseTraktorPreparationForExistingTracks())
    var submitted: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted(let generation)=checkpoint {
            submitted=generation
            await gate.hold()
            throw CancellationError()
        }
    }
    f.model.load(trackID:f.a.id,deck:.a)
    try #require(await gate.waitUntilEntered())
    var edited=try #require(f.model.track(.a)?.preparation)
    let key = mode == "minor" ? MusicalKey(tonic:2,mode:.minor) : MusicalKey(tonic:0,mode:.major)
    let correction: MusicalKey? = mode == "cleared" ? nil : key
    if mode != "unchanged" {
        edited.correctedKey=MusicalKey(tonic:2,mode:.minor)
        f.model.adoptLibrary(try await f.model.service.updatePreparation(trackID:f.a.id,preparation:edited))
        if mode == "cleared" {
            edited.correctedKey=nil
            f.model.adoptLibrary(try await f.model.service.updatePreparation(trackID:f.a.id,preparation:edited))
        }
    }
    #expect(f.model.track(.a)?.key == key)
    #expect(f.model.track(.a)?.preparation.correctedKey == correction)
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(!gate.timedOut)
    #expect(f.model.playback.core.snapshot()?.a.generation == submitted)
    #expect(f.model.loaded[.a] == f.a.id)
    if mode != "unchanged" {
        #expect(f.model.library.tracks.first { $0.id==f.a.id }?.preparation.correctedKey == correction)
    }
    #expect(f.model.track(.a)?.key == key)
    #expect(f.model.track(.a)?.preparation.correctedKey == correction)
    await f.model.finishForShutdown()
}

@Test(arguments:["plain-submitted","imported-submitted","plain-accepted","imported-accepted"]) @MainActor
func preparationPinLateAcceptanceMustReconcilePersistedManualGrid(_ cut: String) async throws {
    let imported = cut.hasPrefix("imported")
    let submittedCut = cut.hasSuffix("submitted")
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    if imported {
        try await pinTestCatalogue(f.model)
        f.model.adoptLibrary(try await f.model.service.reuseTraktorPreparationForExistingTracks())
    }
    var submitted: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        switch checkpoint {
        case .submitted(let generation) where submittedCut:
            submitted=generation
            await gate.hold()
            throw CancellationError()
        case .accepted(let generation) where !submittedCut:
            submitted=generation
            await gate.hold()
            throw CancellationError()
        default: break
        }
    }
    f.model.load(trackID:f.a.id,deck:.a)
    try #require(await gate.waitUntilEntered())
    let edited=try pinTestGrid(117)
    f.model.saveGrid(edited,deck:.a)
    await f.model.preparationWrites?.value
    #expect(f.model.gridDraft[.a] == nil)
    #expect(f.model.library.tracks.first { $0.id==f.a.id }?.preparation.grid == edited)
    #expect(f.model.grid(.a) == edited)
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    let native=try #require(f.model.playback.core.snapshot())
    print("LATE_GRID_REVIEW imported=\(imported) generation=\(native.a.generation) native=\(native.a.grid?.bpm ?? 0) model=\(f.model.grid(.a)?.bpm ?? 0) saved=\(f.model.library.tracks.first { $0.id==f.a.id }?.preparation.grid?.bpm ?? 0)")
    #expect(!gate.timedOut)
    #expect(native.a.generation == submitted)
    #expect(f.model.loaded[.a] == f.a.id)
    #expect(f.model.grid(.a) == native.a.grid)
    #expect(native.a.grid == edited)
    #expect(f.model.grid(.a) == edited)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinLateGridQueueFailureRetainsActualOwnershipAndSavedEdit() async throws {
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    var accepted: UInt64?
    var queueWasFull=false
    f.model.playback.loadCheckpoint = { checkpoint in
        switch checkpoint {
        case .decoded: await gate.hold()
        case .accepted(let generation):
            accepted=generation
            for _ in 0..<256 {
                do { try f.model.playback.core.setMasterBPM(120) }
                catch TransportError.queueFull { queueWasFull=true;break }
            }
            throw CancellationError()
        default: break
        }
    }
    f.model.load(trackID:f.a.id,deck:.a)
    try #require(await gate.waitUntilEntered())
    let edited=try pinTestGrid(117)
    f.model.saveGrid(edited,deck:.a)
    await f.model.preparationWrites?.value
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(!gate.timedOut && queueWasFull)
    #expect(f.model.loaded[.a] == f.a.id)
    #expect(f.model.playback.core.snapshot()?.a.generation == accepted)
    #expect(f.model.gridDraft[.a] == nil)
    #expect(f.model.grid(.a)?.bpm == 110)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    #expect(f.model.library.tracks.first { $0.id==f.a.id }?.preparation.grid == edited)
    #expect(!f.model.status.isEmpty)
    await pinTestLoad(f.model,f.a)
    #expect(f.model.grid(.a) == edited)
    #expect(f.model.playback.core.snapshot()?.a.grid == edited)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinLateGridSurvivesObsoleteAcceptanceAndReplacementFailure() async throws {
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    var submitted: UInt64?
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted(let generation)=checkpoint {
            submitted=generation
            await gate.hold()
            throw CancellationError()
        }
    }
    f.model.load(trackID:f.a.id,deck:.a)
    try #require(await gate.waitUntilEntered())
    let edited=try pinTestGrid(117)
    f.model.saveGrid(edited,deck:.a)
    await f.model.preparationWrites?.value
    f.model.load(trackID:f.b.id,deck:.a)
    try FileManager.default.removeItem(at:f.model.store.mediaDirectory.appendingPathComponent(f.b.mediaFilename))
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(!gate.timedOut)
    #expect(f.model.loaded[.a] == f.a.id)
    #expect(f.model.playback.core.snapshot()?.a.generation == submitted)
    #expect(f.model.grid(.a) == edited)
    #expect(f.model.playback.core.snapshot()?.a.grid == edited)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinLateGridForPreparingTwinKeepsPlayingDeckRunning() async throws {
    let f=try pinTestFixture(),gate=PinTestBarrier()
    let watchdog=gate.watchdog()
    defer { gate.open();watchdog.cancel();try? FileManager.default.removeItem(at:f.root) }
    await pinTestLoad(f.model,f.a,.a)
    f.model.pressPlay(deck:.a)
    _=f.model.playback.core.renderOffline(frames:256)
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted=checkpoint {
            await gate.hold()
            throw CancellationError()
        }
    }
    f.model.load(trackID:f.a.id,deck:.b)
    try #require(await gate.waitUntilEntered())
    let edited=try pinTestGrid(117)
    f.model.saveGrid(edited,deck:.a)
    await f.model.preparationWrites?.value
    gate.open()
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint=nil
    f.model.refreshPlayback()
    #expect(!gate.timedOut)
    #expect(f.model.playback.core.snapshot()?.a.phase == .playing)
    for deck in DeckID.allCases {
        #expect(f.model.grid(deck) == edited)
        #expect(f.model.playback.core.snapshot()?[deck].grid == edited)
    }
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinConfirmedGridRejectsAnObsoleteNativeGeneration() async throws {
    let f=try pinTestFixture()
    defer { try? FileManager.default.removeItem(at:f.root) }
    await pinTestLoad(f.model,f.a)
    let old=try #require(f.model.playback.generations[.a])
    await pinTestLoad(f.model,f.b)
    var committed=false
    #expect(throws:TransportError.stale) {
        try f.model.playback.reconcileGrid(pinTestGrid(117),deck:.a,generation:old) { committed=true }
    }
    #expect(!committed)
    #expect(f.model.loaded[.a] == f.b.id)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 130)
    await f.model.finishForShutdown()
}

@Test @MainActor
func preparationPinConfirmedGridSurvivesColdSourcePreparation() async throws {
    var base=URL(fileURLWithPath:#filePath)
    for _ in 0..<4 { base.deleteLastPathComponent() }
    let source=base.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let store=try WorkspaceStore(root:root)
    try FileManager.default.copyItem(at:source,to:store.mediaDirectory.appendingPathComponent("streamed.wav"))
    let analysis=AudioAnalysis(implementation:"Synthetic streamed grid",configurationID:"fixture",
        contentSHA256:try AudioAnalyzer.sha256(url:source),sampleRate:44100,frameCount:705600,channelCount:2,
        waveformFramesPerBin:441,waveform:[],bpm:120,beatAnchorFrame:0,tempoConfidence:1,key:nil,keyConfidence:0,chroma:[],timbre:[])
    let track=try Track(title:"Synthetic streamed grid",mediaFilename:"streamed.wav",analysis:analysis)
    let playback=try PlaybackController(offline:true,streamingPlayback:true)
    try await playback.load(track:track,store:store,deck:.a)
    let generation=try #require(playback.generations[.a])
    try playback.play(.a)
    await playback.flushSourcePreparations()
    _=playback.core.renderOffline(frames:256)
    try #require(playback.core.snapshot()?.a.phase == .playing)
    try playback.core.configureMaximumOutputFrames(65536)
    let before=playback.sourcePreparationRequests
    let grid=try BeatGrid(bpm:15,anchorFrame:0,sampleRate:44100)
    var commits=0
    try playback.reconcileGrid(grid,deck:.a,generation:generation) { commits+=1 }
    await playback.flushSourcePreparations()
    #expect(playback.sourcePreparationRequests > before)
    #expect(playback.sourcePreparationFailures == 0)
    #expect(commits == 1)
    #expect(playback.core.snapshot()?.a.grid == grid)
    #expect(!playback.core.streamingSummary().continuityFailed)
    playback.stopAudio()
}

@Test @MainActor
func preparationPinConfirmedGridDoesNotPublishANativeRejection() async throws {
    let f=try pinTestFixture()
    defer { try? FileManager.default.removeItem(at:f.root) }
    await pinTestLoad(f.model,f.a)
    let generation=try #require(f.model.playback.generations[.a])
    let rejected=f.model.playback.rejectedCommandCount
    var committed=false
    try f.model.playback.reconcileGrid(pinTestGrid(1),deck:.a,generation:generation) { committed=true }
    #expect(!committed)
    #expect(f.model.playback.rejectedCommandCount == rejected+1)
    #expect(f.model.playback.core.snapshot()?.a.generation == generation)
    #expect(f.model.playback.core.snapshot()?.a.grid?.bpm == 110)
    #expect(f.model.grid(.a)?.bpm == 110)
    await f.model.finishForShutdown()
}

@Test @MainActor
func recordingRetainsTitleForLateAcceptedCancelledLoad() async throws {
    let f = try pinTestFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    await f.model.toggleRecording()
    f.model.playback.loadCheckpoint = { checkpoint in
        if case .submitted = checkpoint { throw CancellationError() }
    }
    f.model.load(trackID: f.a.id, deck: .a)
    await f.model.playbackLoads?.value
    f.model.playback.loadCheckpoint = nil
    f.model.refreshPlayback()
    f.model.pressPlay(deck: .a)
    _ = f.model.playback.core.renderOffline(frames: 512)
    await f.model.toggleRecording()
    await f.model.flushRecordingList()
    let audio = try #require(f.model.recordings.first)
    let text = try String(contentsOf: audio.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(text.contains(f.a.title))
}

@Test @MainActor
func recordingRetainsBothTitlesAcrossRecorderStartup() async throws {
    let f = try pinTestFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    await pinTestLoad(f.model, f.a)
    f.model.pressPlay(deck: .a)
    let barrier = PinTestBarrier()
    let watchdog = barrier.watchdog()
    defer { barrier.open(); watchdog.cancel() }
    f.model.playback.recordingPreparedCheckpoint = { await barrier.hold() }
    let start = Task { await f.model.toggleRecording() }
    #expect(await barrier.waitUntilEntered())
    _ = f.model.playback.core.renderOffline(frames: 512)
    f.model.pressPlay(deck: .a)
    _ = f.model.playback.core.renderOffline(frames: 512)
    await pinTestLoad(f.model, f.b)
    f.model.pressPlay(deck: .a)
    _ = f.model.playback.core.renderOffline(frames: 512)
    barrier.open()
    await start.value
    f.model.playback.recordingPreparedCheckpoint = nil
    await f.model.toggleRecording()
    await f.model.flushRecordingList()
    let audio = try #require(f.model.recordings.first)
    let text = try String(contentsOf: audio.deletingPathExtension().appendingPathExtension("txt"), encoding: .utf8)
    #expect(text.contains(f.a.title))
    #expect(text.contains(f.b.title))
    #expect(!text.contains("Unknown Track"))
    #expect(!barrier.timedOut)
}
