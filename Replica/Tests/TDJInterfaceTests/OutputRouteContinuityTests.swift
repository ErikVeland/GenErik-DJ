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
