import TDJCore
import Testing

@testable import TDJInterface

@Test func z1Mk2LayerSwitchSeedsPotsAndDoesNotReplayHeldButtons() {
    var controls = Z1MK2Controls()
    var report: [UInt8] = [1, 0, 0x10] + .init(repeating: 0, count: 32)
    #expect(controls.consume(report).isEmpty)
    report[1] = 0x04
    report[29] = 0xff
    report[30] = 0x0f
    #expect(controls.consume(report) == [.layer])
    report[29] = 0x00
    #expect(controls.consume(report) == [.pot(.levelA, .c, Double(0xf00) / 4095)])
    report[2] = 0
    _ = controls.consume(report)
    report[2] = 0x10
    #expect(controls.consume(report) == [.cue(.c)])
}

@Test func x1Mk3EncodersWrapAndShiftDoesNotLeaveReverseHeld() {
    var controls = X1MK3Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 24)
    report[7] = 0x0f
    #expect(controls.consume(report).isEmpty)
    report[7] = 0
    report[1] = 0x40
    #expect(controls.consume(report) == [.reverse(.a, true), .loopSize(.a, 1, shifted: false)])
    report[1] = 1
    report[8] = 0xf0
    #expect(controls.consume(report) == [.reverse(.a, false), .browse(-1, groups: true)])
}

@Test func modularControllerReportsKeepBlueAndAmberOnTheCorrectSide() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .a, grid: grid)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    let z1 = TraktorModularLights.z1(snapshot, controls: .init(), frames: { _ in 48_000 * 60 }, enabled: [])
    #expect(z1.count == 47 && z1[0] == 0x80)
    #expect(z1[35..<41].allSatisfy { $0 == 0x2e })
    #expect(z1[41..<47].allSatisfy { $0 == 0 })
    let x1 = TraktorModularLights.x1(snapshot, controls: .init(), frames: { _ in 48_000 }, feedback: .init())
    #expect(x1.count == 50 && x1[0] == 0x80)
    #expect(x1[37..<43].allSatisfy { $0 == 0x0e })
    #expect(x1[43..<50].allSatisfy { $0 == 0 })
}

@Test @MainActor func z1Mk2RecognisesOnlyWiredFourChannelOutputNames() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Traktor Z1 MK2", wired: true)])
    #expect(controller.automaticOutputDevice == "Z1 Mk2")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([.init(name: "GenErik Z1 Mk2 Bridge", wired: true)])
    #expect(controller.automaticOutputDevice == "Z1 Mk2 Bridge")
    controller.updateOutputDevice([.init(name: "GenErik Z1 Mk2 Bridge", wired: false)])
    #expect(controller.automaticOutputDevice == nil)
}

@Test func x1Mk3LayerSwitchReleasesCueBeforeSwitchingTheTargetDeck() {
    var controls = X1MK3Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 24)
    _ = controls.consume(report)
    report[1] = 0x20
    #expect(controls.consume(report) == [.cue(.a, true)])
    report[4] = 0x80
    #expect(controls.consume(report) == [.cue(.a, false)])
    report[1] = 0
    #expect(controls.consume(report).isEmpty)
    report[1] = 0x22
    #expect(controls.consume(report) == [.action(.playA, .c), .cue(.c, true)])
}

@Test func z1Mk2StemKnobsFollowTheSelectedDeckAndLeaveEQAlone() {
    var controls = Z1MK2Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 34)
    _ = controls.consume(report)
    report[1] = 0x02
    report[3] = 128
    #expect(controls.consume(report) == [.mode(.a)])
    report[3] = 255
    report[4] = 15
    report[9] = 255
    report[10] = 15
    report[13] = 255
    report[14] = 15
    #expect(controls.consume(report) == [.stemGain(.a, 0, 1), .stemGain(.a, 3, 1), .pot(.gainB, .b, 1)])

    report[1] = 0x14
    #expect(controls.consume(report) == [.layer, .mode(.d)])
    report[13] = 0
    report[14] = 0
    #expect(controls.consume(report) == [.stemGain(.d, 0, 0)])
    report[1] = 0x08
    #expect(controls.consume(report) == [.mode(.d)])
    report[13] = 255
    report[14] = 15
    #expect(controls.consume(report) == [.pot(.gainB, .d, 1)])
}

@Test func x1Mk3PatternScreenUsesBoundedUTF8AndCarriesTheLiveStep() throws {
    let payload = X1PatternScreen.payload(
        side: 1, mode: true, kit: String(repeating: "å", count: 20),
        sound: "Snare", steps: 0x8421, cursor: 5, ducking: true)
    #expect(payload.count == 64)
    #expect(Array(payload.prefix(6)) == [1, 1, 0x21, 0x84, 5, 1])
    #expect(String(bytes: payload[6..<34], encoding: .utf8) == String(repeating: "å", count: 14))
    #expect(payload[34] == 0)
    var decoder = ControllerBridgeDecoder()
    let frame = try ControllerBridgeFrame(kind: .x1PatternScreen, payload: payload)
    #expect(decoder.append(frame.encoded) == [frame])
    #expect(X1PatternScreen.payload(side: 0, mode: false, kit: "", sound: "", steps: 0, cursor: nil, ducking: false)
        == .init(repeating: 0, count: 64))
}
