import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test @MainActor func changingOutputRouteCannotStopPlayingAudio() throws {
    let controller = try PlaybackController(offline: true)
    let reference = try SampleTransport(sampleRate: controller.core.sampleRate)
    let asset = try PCMAsset(
        interleavedStereo: Array(repeating: 0.25, count: 96000 * 2), sampleRate: controller.core.sampleRate)
    for core in [controller.core, reference] {
        let generation = try core.load(asset, deck: .a, grid: nil)
        core.processControlsWhileIdle()
        _ = core.acknowledgements()
        try core.play(deck: .a, generation: generation)
        _ = core.renderOffline(frames: 1024)
    }
    let before = try #require(controller.core.snapshot())
    #expect(throws: TransportError.cache("Stop playback before changing audio routing.")) {
        try controller.setOutputRoute(.masterAndHeadphones)
    }
    let after = try #require(controller.core.snapshot())
    #expect(after.a.phase == .playing)
    #expect(after.a.sourceFrame == before.a.sourceFrame)
    #expect(controller.outputRoute == .stereoMaster)
    let actual = controller.core.renderOffline(frames: 512)
    let expected = reference.renderOffline(frames: 512)
    #expect(actual.left == expected.left)
    #expect(actual.right == expected.right)
    controller.stopAudio()
}

@Test @MainActor func outputRecoveryKeepsDecksAndHonoursInterruptionEnd() throws {
    let controller = try PlaybackController(offline: true)
    let core = controller.core
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: 48000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: true)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 1024)
    let before = try #require(core.snapshot())
    var restarts = 0
    func send(_ event: PlaybackController.OutputEvent) {
        controller.handleOutputEvent(event) { restarts += 1 }
    }
    send(.interruptionBegan)
    send(.configurationChanged)
    #expect(restarts == 0)
    #expect(controller.outputRecoveryPending)
    #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.synced == before.a.synced)
    #expect(core.snapshot()?.masterBeat == before.masterBeat)
    send(.interruptionEnded(shouldResume: true))
    #expect(restarts == 1)
    #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.synced == before.a.synced)
    #expect(core.snapshot()?.masterBeat == before.masterBeat)
    send(.interruptionBegan)
    send(.interruptionEnded(shouldResume: false))
    send(.configurationChanged)
    #expect(restarts == 1)
    #expect(controller.outputRecoveryPending)
    #expect(core.snapshot()?.a.synced == true)
    controller.stopAudio()
    send(.interruptionEnded(shouldResume: true))
    #expect(restarts == 1)
    #expect(!controller.outputRecoveryPending)
}

@Test @MainActor func outputRecoveryDoesNotAutoPlayOnStereoDisconnectOrMediaReset() throws {
    let controller = try PlaybackController(offline: true)
    let core = controller.core
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: nil)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 1024)
    let before = try #require(core.snapshot())
    var restarts = 0
    controller.handleOutputEvent(.routeChanged(disconnected: true)) { restarts += 1 }
    controller.handleOutputEvent(.routeChanged(disconnected: false)) { restarts += 1 }
    controller.handleOutputEvent(.mediaServicesReset) { restarts += 1 }
    #expect(restarts == 0)
    #expect(controller.outputRecoveryPending)
    #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.synced == before.a.synced)
    #expect(core.snapshot()?.masterBeat == before.masterBeat)
    controller.stopAudio()
}
