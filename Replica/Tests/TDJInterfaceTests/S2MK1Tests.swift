import TDJCore
import Testing

@testable import TDJInterface

@Test func s2Mk1DecodesIndependentReportsAndIgnoresHeldButtonsAtStartup() {
    var controls = S2MK1Controls()
    var buttons: [UInt8] = [1] + .init(repeating: 0, count: 15)
    var pots: [UInt8] = [2] + .init(repeating: 0, count: 51)
    buttons[13] = 0x10
    #expect(controls.consume(buttons).isEmpty)
    #expect(controls.consume(pots).isEmpty)
    buttons[13] = 0
    #expect(controls.consume(buttons).isEmpty)
    buttons[12] = 0x10
    buttons[11] = 0x08
    #expect(controls.consume(buttons) == [.native(.browser(.load(.a))), .action(.playB, .b, 1)])
    pots[0x2f] = 0xf0
    pots[0x30] = 0x0f
    #expect(controls.consume(pots) == [.pot(.crossfader, .a, 1)])
}

@Test func s2Mk1UsesBigEndianPressureCalibrationAndWrapsTheWheelTickByte() {
    var controls = S2MK1Controls()
    var calibration: [UInt8] = [0xd4, 0x0c, 0x1b, 0x0c, 0xe6, 0x0c, 0x9a, 0x0d, 0x58]
    calibration += .init(repeating: 0xff, count: 24)
    #expect(controls.consume(calibration).isEmpty)
    var pots: [UInt8] = [2] + .init(repeating: 0, count: 51)
    pots.replaceSubrange(0x0d...0x0e, with: [0x1b, 0x0c])
    pots.replaceSubrange(0x1d...0x1e, with: [0x9a, 0x0c])
    #expect(controls.consume(pots).isEmpty)
    pots[0x0d] = 0xee
    #expect(controls.consume(pots) == [.action(.jogTouchA, .a, 1)])
    var buttons: [UInt8] = [1, 0xff, 0x01, 0xfe, 0xff] + .init(repeating: 0, count: 11)
    #expect(controls.consume(buttons).isEmpty)
    buttons.replaceSubrange(1...4, with: [1, 0, 2, 0])
    let events = controls.consume(buttons)
    guard case .action(.jogA, .a, let rate)? = events.first else {
        Issue.record("Expected a positive scratch rate.")
        return
    }
    #expect(events.count == 1 && rate > 0.5 && rate <= 1)
    pots[0x0d] = 0x1b
    #expect(controls.consume(pots) == [.action(.jogTouchA, .a, 0)])
}

@Test func s2Mk1UsesBluePadsAndTheSeparateAmberLamp() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .a, grid: grid)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    var feedback = S4MK2Lights.Feedback()
    feedback.frames[.a] = 48_000 * 60
    let blue = S2MK1Lights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(blue.count == 62 && blue[0] == 0x80)
    #expect(blue[0x0d] > 0 && blue[0x2d] == 0 && blue[0x33] == 0)
    feedback.frames[.a] = 48_000
    let amber = S2MK1Lights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(amber[0x33] > 0 && amber[0x09] == 0)
}

@Test @MainActor func s2Mk1SelectsSplitAudioOnlyForTheWiredBridge() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "GenErik S2 Mk1 Bridge", wired: true)])
    #expect(controller.automaticOutputDevice == "S2 Mk1 Bridge")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([.init(name: "GenErik S2 Mk1 Bridge", wired: false)])
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func s2Mk1TempoResetLocksOnlyItsOwnFaderAndShiftMovesTheLoopOneStep() {
    var controls = S2MK1Controls()
    var buttons: [UInt8] = [1] + .init(repeating: 0, count: 15)
    var pots: [UInt8] = [2] + .init(repeating: 0, count: 51)
    _ = controls.consume(buttons)
    _ = controls.consume(pots)
    buttons[9] = 0x10
    buttons[13] = 0x80
    #expect(controls.consume(buttons) == [.tempoReset(.a)])
    pots[1] = 0x10
    pots[0x0f] = 0xf0
    pots[0x10] = 0x0f
    pots[0x1f] = 0xf0
    pots[0x20] = 0x0f
    #expect(controls.consume(pots) == [.native(.move(.a, 1, shifted: true)), .pot(.tempoB, .b, 1)])
    buttons[9] = 0
    _ = controls.consume(buttons)
    buttons[9] = 0x10
    #expect(controls.consume(buttons).isEmpty)
    pots[0x0f] = 0
    pots[0x10] = 0
    #expect(controls.consume(pots) == [.pot(.tempoA, .a, 0)])
}

@Test func s2Mk1UsesStoredFaderCalibration() {
    var controls = S2MK1Controls()
    var feature: [UInt8] = [0xd0] + .init(repeating: 0, count: 32)
    feature.replaceSubrange(21...24, with: [0xe8, 0x03, 0xb8, 0x0b])
    _ = controls.consume(feature)
    var pots: [UInt8] = [2] + .init(repeating: 0, count: 51)
    _ = controls.consume(pots)
    pots.replaceSubrange(0x2f...0x30, with: [0xd0, 0x07])
    #expect(controls.consume(pots) == [.pot(.crossfader, .a, 0.5)])
}
