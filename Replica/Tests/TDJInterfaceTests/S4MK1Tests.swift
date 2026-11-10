import TDJCore
import Testing

@testable import TDJInterface

@Test func s4Mk1KeepsMixerChannelsFixedWhenBothDeckLayersChange() {
    var controls = S4MK1Controls()
    #expect(controls.consume(s4Mk1Panel(7, 63)).isEmpty)
    #expect(controls.consume(s4Mk1Panel(8, 48)) == [.layer(.c), .layer(.d)])
    #expect(
        controls.consume(s4Mk1Panel(7, 35, 54, 57)) == [
            .action(.playA, .c, 1), .native(.cloneDeck(.d)), .action(.cueB, .d, 1),
        ])
    var pots = [UInt8](repeating: 0, count: 73)
    pots[0] = 2
    #expect(controls.consume(pots).isEmpty)
    s4Mk1Word(4080, at: 3, in: &pots)
    s4Mk1Word(4080, at: 11, in: &pots)
    #expect(controls.consume(pots) == [.pot(.levelB, .b, 1), .pot(.tempoA, .c, 1)])
    #expect(controls.consume(s4Mk1Panel(55)) == [.native(.samplePad(15, shifted: false))])
    #expect(controls.consume(s4Mk1Panel(57, 72)) == [.native(.crossfaderAssign(.c, .left))])
}

@Test func s4Mk1WrappedScratchAndHeldCueReleaseOnDeckSwitch() {
    var controls = S4MK1Controls()
    var panel = s4Mk1Panel()
    s4Mk1Word(1023, at: 13, in: &panel)
    s4Mk1Word(2800, at: 26, in: &panel)
    s4Mk1Word(65534, at: 30, in: &panel)
    #expect(controls.consume(panel).isEmpty)
    panel[1] = 1 << 5
    s4Mk1Word(1, at: 13, in: &panel)
    s4Mk1Word(3260, at: 26, in: &panel)
    s4Mk1Word(2, at: 30, in: &panel)
    let events = controls.consume(panel)
    #expect(events.prefix(2) == [.cue(.a, held: true), .action(.jogTouchA, .a, 1)])
    guard case .action(.jogA, .a, let rate)? = events.last else {
        Issue.record("Expected a forward scratch rate.")
        return
    }
    #expect(rate > 0.5)
    panel[2] = 1
    #expect(controls.consume(panel) == [.action(.jogTouchA, .a, 0), .cue(.a, held: false), .layer(.c)])
    #expect(controls.consume(s4Mk1Panel()).isEmpty)
}

@Test func s4Mk1OffsetButtonsUseFaderPositionAndLockOnlyTheirDeck() {
    var controls = S4MK1Controls()
    var pots = [UInt8](repeating: 0, count: 73)
    pots[0] = 2
    s4Mk1Word(4080, at: 11, in: &pots)
    _ = controls.consume(pots)
    _ = controls.consume(s4Mk1Panel())
    #expect(controls.consume(s4Mk1Panel(16)) == [.tempoPickup(.a, 1)])
    #expect(controls.consume(s4Mk1Panel(16, 17)) == [.tempoReset(.a)])
    s4Mk1Word(16, at: 11, in: &pots)
    s4Mk1Word(4080, at: 13, in: &pots)
    #expect(controls.consume(pots) == [.pot(.tempoB, .b, 1)])
    _ = controls.consume(s4Mk1Panel())
    #expect(controls.consume(s4Mk1Panel(17)).isEmpty)
    s4Mk1Word(4080, at: 11, in: &pots)
    #expect(controls.consume(pots) == [.pot(.tempoA, .a, 1)])
}

@Test func s4Mk1UsesTheSelectedBluePadAndSharedAmberAlert() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .c, grid: grid)
    try core.play(deck: .c, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    var feedback = S4MK2Lights.Feedback()
    var controls = S4MK1Controls()
    _ = controls.consume(s4Mk1Panel())
    _ = controls.consume(s4Mk1Panel(8))
    feedback.frames[.c] = 48_000 * 60
    let cues: [DeckID: [Int: PerformanceCueKind]] = [.c: [3: .loop]]
    let blue = S4MK1Lights.report(
        snapshot: snapshot, controls: controls, feedback: feedback, cueKinds: cues, snap: true,
        browsing: false)
    #expect(blue.count == 103 && blue[0] == 0x80)
    #expect(s4Mk1Lamp(72, in: blue) > 0 && s4Mk1Lamp(73, in: blue) == 0 && s4Mk1Lamp(116, in: blue) == 0)
    #expect(s4Mk1Lamp(5, in: blue) == 0 && s4Mk1Lamp(87, in: blue) == 31)
    _ = controls.consume(s4Mk1Panel())
    _ = controls.consume(s4Mk1Panel(8))
    feedback.frames[.c] = 48_000
    let amber = S4MK1Lights.report(
        snapshot: snapshot, controls: controls, feedback: feedback, cueKinds: cues, snap: true,
        browsing: false)
    #expect(s4Mk1Lamp(5, in: amber) > 0 && s4Mk1Lamp(72, in: amber) == 0)
    let frame = try ControllerBridgeFrame(kind: .s4MK1Lights, payload: amber)
    var decoder = ControllerBridgeDecoder()
    #expect(frame.encoded.count <= 128 && decoder.append(frame.encoded) == [frame])
}

@Test @MainActor func s4Mk1SelectsSplitAudioOnlyForTheWiredBridge() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "GenErik S4 Mk1 Bridge", wired: true)])
    #expect(controller.automaticOutputDevice == "S4 Mk1 Bridge")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([.init(name: "GenErik S4 Mk1 Bridge", wired: false)])
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
}

private func s4Mk1Panel(_ keys: Int...) -> [UInt8] {
    var report = [UInt8](repeating: 0, count: 32)
    report[0] = 1
    for key in keys { report[1 + key / 8] |= 1 << (key % 8) }
    return report
}

private func s4Mk1Word(_ value: UInt16, at offset: Int, in report: inout [UInt8]) {
    report[offset] = UInt8(truncatingIfNeeded: value)
    report[offset + 1] = UInt8(value >> 8)
}

private func s4Mk1Lamp(_ id: Int, in report: [UInt8]) -> UInt8 {
    let bit = (id - 1) * 5
    let offset = 1 + bit / 8
    let low = UInt16(report[offset])
    let high = offset + 1 < report.count ? UInt16(report[offset + 1]) : 0
    return UInt8(((high << 8 | low) >> (bit % 8)) & 31)
}
