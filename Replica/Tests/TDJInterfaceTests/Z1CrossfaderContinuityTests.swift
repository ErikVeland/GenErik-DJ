import Foundation
import Testing

@testable import TDJCore
@testable import TDJInterface

private func crossfaderReport(_ position: UInt16) throws -> Z1InputReport {
    var controls = [UInt16](repeating: 2048, count: 14)
    controls[11] = 4095
    controls[12] = 4095
    controls[13] = position
    return try Z1InputReport(bytes: [1] + controls.flatMap { [UInt8($0 & 255), UInt8($0 >> 8)] } + [0])
}

@Test @MainActor func crossfaderPendingPositionYieldsToNewInputAndRejectsInvalidValues() throws {
    let controller = try PlaybackController(offline: true)
    defer { controller.stopAudio() }
    for _ in 0..<127 { try controller.core.setMixer(.master, value: 0.5) }
    try controller.setMixer(.crossfader, value: 0.1)
    try controller.setMixer(.crossfader, value: 0.75)
    controller.maintainControlState()
    #expect(controller.core.snapshot()?.crossfader == 0.75)
    for _ in 0..<127 { try controller.core.setMixer(.master, value: 0.5) }
    try controller.setMixer(.crossfader, value: 0.25)
    #expect(throws: TransportError.invalid) { try controller.setMixer(.crossfader, value: .nan) }
    controller.maintainControlState()
    #expect(controller.core.snapshot()?.crossfader == 0.25)
}

@Test @MainActor func crossfaderPendingPositionArrivesWithoutVisualPolling() async throws {
    let controller = try PlaybackController(offline: true)
    defer { controller.stopAudio() }
    for _ in 0..<127 { try controller.core.setMixer(.master, value: 0.5) }
    try controller.setMixer(.crossfader, value: 0.2)
    let deadline = ContinuousClock.now + .milliseconds(250)
    while controller.core.snapshot()?.crossfader != 0.2, ContinuousClock.now < deadline {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(controller.core.snapshot()?.crossfader == 0.2)
}

@Test @MainActor func z1CrossfaderReturnsFromSilenceAfterQueuePressureWithoutRestart() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let model = try ReplicaModel(root: root, playback: PlaybackController(offline: true))
    model.configureZ1Bridge(try Z1CrossfaderCalibration(minimum: 0, maximum: 4095))
    let core = model.playback.core
    let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0.4, count: 48000 * 8), sampleRate: 48000)
    let generation = try core.load(asset, deck: .a, grid: nil, synced: false)
    try core.play(deck: .a, generation: generation)
    model.receiveZ1(try crossfaderReport(4095))
    let muted = core.renderOffline(frames: 512)
    #expect(muted.left.last == 0)
    var full = false
    for _ in 0..<128 {
        do { try core.setMixer(.master, value: 0.5) } catch TransportError.queueFull {
            full = true
            break
        }
    }
    try #require(full)
    let before = try #require(core.snapshot()?.a.sourceFrame)
    model.receiveZ1(try crossfaderReport(0))
    for _ in 0..<3 {
        _ = core.renderOffline(frames: 512)
        model.playback.maintainControlState()
    }
    let audible = core.renderOffline(frames: 512)
    #expect(core.snapshot()?.crossfader == 0)
    #expect(core.snapshot()?.a.phase == .playing)
    #expect(try #require(core.snapshot()?.a.sourceFrame) > before)
    #expect(audible.left.suffix(256).allSatisfy { $0 > 0.15 })
    await model.finishForShutdown()
}
