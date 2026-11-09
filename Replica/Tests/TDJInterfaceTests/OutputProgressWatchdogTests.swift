import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func outputWatchdogUsesRenderProgressAndLimitsRepeatedRebuilds() throws {
    var watchdog = OutputProgressWatchdog()
    let core = try SampleTransport()
    let start = ContinuousClock.now
    func stalled(at now: ContinuousClock.Instant) -> Bool {
        watchdog.isStalled(frame: core.renderedOutputFrame, now: now)
    }
    func takeRestart() -> Bool { watchdog.takeRestart() }
    watchdog.arm(frame: core.renderedOutputFrame, now: start)
    for tick in 1...5 {
        _ = core.renderOffline(frames: 4800)
        #expect(!stalled(at: start + .milliseconds(100 * tick)))
    }
    let before = core.renderedOutputFrame
    core.processControlsWhileIdle()
    #expect(core.renderedOutputFrame == before)
    #expect(!stalled(at: start + .milliseconds(1200)))
    #expect(stalled(at: start + .milliseconds(1300)))
    #expect(takeRestart())

    let rebuilt = start + .milliseconds(1400)
    watchdog.arm(frame: core.renderedOutputFrame, now: rebuilt)
    #expect(stalled(at: rebuilt + .milliseconds(800)))
    #expect(!takeRestart())

    let restored = rebuilt + .seconds(1)
    watchdog.arm(frame: core.renderedOutputFrame, now: restored)
    for tick in 1...22 {
        _ = core.renderOffline(frames: 4800)
        #expect(!stalled(at: restored + .milliseconds(100 * tick)))
    }
    #expect(stalled(at: restored + .seconds(3)))
    #expect(takeRestart())
    watchdog.disarm()
    #expect(!stalled(at: restored + .seconds(10)))
}

@Test @MainActor func stalledOutputRebuildPreservesDecksAndRepeatedStallWaitsForPlay() throws {
    let controller = try PlaybackController(offline: true)
    let core = controller.core
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0.25, count: 192000), sampleRate: 48000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: true)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 1024)
    let before = try #require(core.snapshot())
    var restarts = 0

    controller.handleOutputEvent(.renderStalled(allowRestart: true)) { restarts += 1 }
    #expect(restarts == 1)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(core.snapshot()?.a.sourceFrame == before.a.sourceFrame)
    #expect(core.snapshot()?.masterBeat == before.masterBeat)
    #expect(core.snapshot()?.a.synced == true)

    controller.handleOutputEvent(.renderStalled(allowRestart: false)) { restarts += 1 }
    controller.retryOutputIfDue(now: .now + .seconds(10)) { restarts += 1 }
    #expect(restarts == 1)
    #expect(controller.snapshotAndMessages().1.contains {
        $0.error?.localizedDescription.contains("Press Play") == true
    })
    controller.stopAudio()
}
