import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

@MainActor private struct ColdPlayRig {
    let actual: PlaybackController
    let reference: PlaybackController
    let root: URL
}

@MainActor private func coldPlayRig(keylock: Bool) async throws -> ColdPlayRig {
    var project = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { project.deleteLastPathComponent() }
    let source = project.appendingPathComponent("Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var complete = false
    defer { if !complete { try? FileManager.default.removeItem(at: root) } }
    let store = try WorkspaceStore(root: root)
    try FileManager.default.copyItem(at: source, to: store.mediaDirectory.appendingPathComponent("source.wav"))
    let analysis = AudioAnalysis(
        implementation: "cold-play-test", configurationID: "cold-play-test",
        contentSHA256: try AudioAnalyzer.sha256(url: source), sampleRate: 44100, frameCount: 705600, channelCount: 2,
        waveformFramesPerBin: 441, waveform: [], bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: nil,
        keyConfidence: 0, chroma: [], timbre: [])
    let track = try Track(title: "Cold Play", mediaFilename: "source.wav", analysis: analysis)
    let actual = try PlaybackController(offline: true, streamingPlayback: true)
    let reference = try PlaybackController(offline: true)
    let rig = ColdPlayRig(actual: actual, reference: reference, root: root)
    for controller in [actual, reference] {
        try await controller.load(track: track, store: store, deck: .a)
        try await controller.load(track: track, store: store, deck: .b)
        try controller.setKeylock(keylock, deck: .a)
        try controller.setKeylock(keylock, deck: .b)
        try controller.setSync(false, deck: .b)
        try controller.perform(.loop, deck: .a, value: 0, end: 44100)
        try controller.perform(.jump, deck: .b, value: Double(analysis.frameCount - 128))
        await controller.flushSourcePreparations()
        try controller.play(.b)
        await controller.flushSourcePreparations()
    }
    compareColdPlayAudio(rig, frames: 1024)
    for controller in [actual, reference] { try #require(controller.core.snapshot()?.b.phase == .ended) }
    let generation = try #require(actual.generations[.b])
    let asset = try #require(actual.core.asset(generation: generation))
    let ticket = try await asset.prepareSources(
        [.init(position: Double(analysis.frameCount - 128))], generation: generation,
        whileWaiting: { _ = actual.core.processControlsWhileIdle() })
    asset.releaseSourcePreparation(ticket)
    for controller in [actual, reference] {
        try controller.setSync(true, deck: .b)
        try controller.play(.a)
        await controller.flushSourcePreparations()
    }
    compareColdPlayAudio(rig, frames: 512)
    try #require(actual.core.snapshot()?.a.phase == .playing)
    try #require(actual.core.snapshot()?.b.phase == .ended)
    complete = true
    return rig
}

@MainActor private func compareColdPlayAudio(_ rig: ColdPlayRig, frames: Int) {
    let actual = rig.actual.core.renderOffline(frames: frames)
    let reference = rig.reference.core.renderOffline(frames: frames)
    #expect(actual.left == reference.left)
    #expect(actual.right == reference.right)
    let state = rig.actual.core.snapshot()
    let expected = rig.reference.core.snapshot()
    #expect(state?.a == expected?.a)
    #expect(state?.outputFrame == expected?.outputFrame)
    #expect(state?.masterBeat == expected?.masterBeat)
    #expect(state?.masterBPM == expected?.masterBPM)
}

@MainActor private func cancelColdPlay(afterRetry: Bool, keylock: Bool) async throws {
    let rig = try await coldPlayRig(keylock: keylock)
    defer {
        rig.actual.stopAudio()
        rig.reference.stopAudio()
        try? FileManager.default.removeItem(at: rig.root)
    }
    // Compare like-for-like meters after zero-frame control processing.
    _ = rig.actual.core.processControlsWhileIdle()
    _ = rig.reference.core.processControlsWhileIdle()
    let before = try #require(rig.actual.core.snapshot())
    #expect(before.a == rig.reference.core.snapshot()?.a)
    let coldBefore = rig.actual.core.streamingSummary().rejectedColdCommands
    let requestsBefore = rig.actual.sourcePreparationRequests
    try rig.actual.play(.b)
    _ = rig.actual.snapshotAndMessages()
    try #require(rig.actual.core.streamingSummary().rejectedColdCommands == coldBefore + 1)
    try #require(rig.actual.sourcePreparationRequests == requestsBefore + 1)
    try #require(rig.actual.preparingSourceDecks.contains(.b))
    try #require(rig.actual.core.snapshot()?.b.phase == .ended)
    if afterRetry {
        await rig.actual.flushSourcePreparations()
        let queued = try #require(rig.actual.core.snapshot())
        try #require(queued.b.phase == .queued && queued.b.targetBeat != nil)
        #expect(queued.outputFrame == before.outputFrame && queued.masterBeat == before.masterBeat)
    }
    try rig.actual.play(.b)
    #expect(!rig.actual.preparingSourceDecks.contains(.b))
    await rig.actual.flushSourcePreparations()
    let cancelled = try #require(rig.actual.core.snapshot())
    #expect(cancelled.b.phase != .playing && cancelled.b.phase != .queued)
    #expect(cancelled.b.targetBeat == nil)
    #expect(cancelled.a == before.a)
    #expect(cancelled.outputFrame == before.outputFrame)
    #expect(cancelled.masterBeat == before.masterBeat)
    // Cross two bar boundaries while late tasks can run between render batches.
    for _ in 0..<400 {
        await Task.yield()
        compareColdPlayAudio(rig, frames: 512)
        _ = rig.actual.snapshotAndMessages()
        #expect(rig.actual.core.snapshot()?.b.phase != .playing)
        #expect(rig.actual.core.snapshot()?.b.phase != .queued)
    }
    #expect(try #require(rig.actual.core.snapshot()).masterBeat > before.masterBeat + 8)
    #expect(rig.actual.core.snapshot()?.b.lastStartOutputFrame == cancelled.b.lastStartOutputFrame)
    #expect(rig.actual.sourcePreparationFailures == 0 && rig.actual.rejectedCommandCount == 0)
    #expect(!rig.actual.core.streamingSummary().continuityFailed)
}

@Test(.timeLimit(.minutes(1)), arguments: [false, true]) @MainActor
func secondPlayCancelsColdRestartBeforePreparationTaskRuns(_ keylock: Bool) async throws {
    try await cancelColdPlay(afterRetry: false, keylock: keylock)
}

@Test(.timeLimit(.minutes(1)), arguments: [false, true]) @MainActor
func secondPlayCancelsColdRestartAfterRetryQueuesBeforeBarStart(_ keylock: Bool) async throws {
    try await cancelColdPlay(afterRetry: true, keylock: keylock)
}
