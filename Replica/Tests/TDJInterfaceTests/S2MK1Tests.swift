import Foundation
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

@Test func s2Mk1DecodesCloneAndShiftFXWithoutOrdinaryLoadOrFX() {
    var controls = S2MK1Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 15)
    _ = controls.consume(report)
    report[13] = 0x80
    report[12] = 0x80
    report[11] = 0x0c
    report[10] = 0x06
    #expect(
        controls.consume(report) == [
            .native(.cloneDeck(.a)), .native(.crossfaderAssign(.a, .left)),
            .native(.cloneDeck(.b)), .native(.crossfaderAssign(.b, .right)),
        ])
    #expect(controls.consume(report).isEmpty)
}

@Test func s2Mk1HeldLoopEdgesConsumeJogTicksOnlyDuringAnActiveLoop() {
    var controls = S2MK1Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 15)
    report[1] = 255
    _ = controls.consume(report)
    report[9] = 0x40
    report[1] = 1
    #expect(controls.consume(report, activeLoop: { $0 == .a }) == [.native(.loopTrim(.a, end: false, ticks: 2))])
    report[9] = 0
    report[11] = 0x20
    report[5] = 1
    #expect(controls.consume(report, activeLoop: { $0 == .b }) == [.native(.loopTrim(.b, end: true, ticks: 1))])
    report[11] = 0
    report[9] = 0x40
    #expect(controls.consume(report) == [.loopMark(.a, end: false)])
}

@Test func s2Mk1TrimClampsWithoutMovingTheOtherEdge() {
    let bounds = S2MK1LoopBounds(start: 100, end: 400)
    #expect(bounds.trimming(end: false, by: 1000, frameCount: 800) == .init(start: 399, end: 400))
    #expect(bounds.trimming(end: true, by: 1000, frameCount: 800) == .init(start: 100, end: 800))
}

@Test @MainActor func s2Mk1CloneCopiesThePlayheadIntoAnIndependentStream() async throws {
    let (model, root, track) = try await loadPlayheadFixture(streaming: true)
    defer { try? FileManager.default.removeItem(at: root) }
    model.load(trackID: track.id, deck: .a)
    await model.playbackLoads?.value
    let position = track.analysis.sampleRate * 4
    model.jump(position, deck: .a, quantized: false)
    await model.playback.flushSourcePreparations()
    model.refreshPlayback()
    model.cloneTrackDeck(to: .b)
    await model.playbackLoads?.value
    model.refreshPlayback()

    let snapshot = try #require(model.playbackSnapshot)
    #expect(model.loaded[.b] == track.id)
    #expect(snapshot.a.sourceFrame == position && snapshot.b.sourceFrame == position)
    #expect(snapshot.b.phase == .ready && snapshot.b.synced)
    let source = try #require(model.playback.core.asset(generation: snapshot.a.generation))
    let clone = try #require(model.playback.core.asset(generation: snapshot.b.generation))
    #expect(source.isStreamed && clone.isStreamed && source !== clone)
    model.pressPlay(deck: .b, vinylStop: false)
    await model.flushTransportRequests()
    model.refreshPlayback()
    model.cloneTrackDeck(to: .b)
    await model.playbackLoads?.value
    #expect(model.playback.generations[.b] == snapshot.b.generation)
    await model.finishForShutdown()
}

@Test @MainActor func s2Mk1ShiftFXTogglesTheSelectedSideThroughAndBack() throws {
    let playback = try PlaybackController(offline: true)
    try playback.toggleCrossfaderAssignment(.left, deck: .a)
    #expect(playback.core.snapshot()?.a.mixer.crossfaderAssignment == .through)
    try playback.toggleCrossfaderAssignment(.right, deck: .a)
    #expect(playback.core.snapshot()?.a.mixer.crossfaderAssignment == .right)
    try playback.toggleCrossfaderAssignment(.right, deck: .a)
    #expect(playback.core.snapshot()?.a.mixer.crossfaderAssignment == .through)
    #expect(playback.core.snapshot()?.b.mixer.crossfaderAssignment == .right)
}
