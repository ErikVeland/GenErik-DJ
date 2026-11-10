import TDJCore
import Testing

@testable import TDJInterface

@Test func s2MK2NegotiatesFourCalibrationBlocksAndACombinedInputReport() throws {
    var startup = S2MK2AccessoryProtocol.startup()
    let input = Z1AccessoryProtocol.Frame(reportID: 1, payload: .init(repeating: 0, count: 66))
    #expect(try startup.consume(input) == nil)
    #expect(!startup.ready)
    for id in UInt8(0xd0)...0xd3 {
        #expect(
            try startup.consume(.init(reportID: id, payload: .init(repeating: 0, count: 32)))
                == (id == 0xd3 ? 1 : id + 1))
    }
    #expect(!startup.ready)
    #expect(throws: TransportError.invalid) {
        try startup.consume(.init(reportID: 1, payload: .init(repeating: 0, count: 98)))
    }
    #expect(try startup.consume(input) == nil)
    #expect(startup.ready)
}

@Test func s2MK2ReadsBothDecksAndCalibratesTheMixer() {
    var controls = S2MK2Controls()
    for id in UInt8(0xd0)...0xd3 {
        var block = [UInt8](repeating: 0xff, count: 32)
        if id == 0xd3 { block.replaceSubrange(28..<32, with: [0x00, 0x02, 0x00, 0x0a]) }
        controls.addCalibration(.init(reportID: id, payload: block))
    }
    var bytes = [UInt8](repeating: 0, count: 66)
    bytes.replaceSubrange(20..<66, with: Array(repeating: 0xff, count: 46))
    bytes[20] = 0
    bytes[21] = 6
    bytes[10] = 1
    #expect(controls.consume(bytes) == [.pot(.crossfader, .a, 0.5)])
    bytes[10] = 0
    _ = controls.consume(bytes)
    bytes[8] = 4
    bytes[10] = 1
    bytes[11] = 8
    bytes[16] = 0x21
    let events = controls.consume(bytes)
    #expect(events.contains(.action(.playA, .a, 1)))
    #expect(events.contains(.action(.syncB, .b, 1)))
    #expect(events.contains(.native(.browser(.load(.a)))))
    #expect(events.contains(.native(.move(.a, 1, shifted: false))))
    #expect(events.contains(.native(.loopSize(.a, 2, shifted: false))))
    #expect(controls.consume(bytes).isEmpty)
}

@Test func s2MK2ShiftedTransportAndJogReleaseDoNotLeakUnshiftedActions() {
    var controls = S2MK2Controls()
    var bytes = [UInt8](repeating: 0, count: 66)
    _ = controls.consume(bytes)
    bytes[10] = 9
    #expect(controls.consume(bytes) == [.action(.keylockA, .a, 1)])
    bytes[10] = 0
    bytes[9] = 2
    #expect(controls.consume(bytes) == [.action(.jogTouchB, .b, 1)])
    bytes[4] = 1
    bytes[9] = 0
    #expect(controls.consume(bytes) == [.action(.jogTouchB, .b, 0)])
}

@Test func s2MK2SendsBlueAndAmberToPadFourAndRestoresItsCueColor() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .a, grid: grid)
    let initial = try #require(core.snapshot())
    var feedback = S4MK2Lights.Feedback()
    let idle = S2MK2Lights.report(
        snapshot: initial, controls: .init(), feedback: feedback, cueKinds: [.a: [2: .grid, 3: .loop]])
    #expect(Array(idle[44...46]) == [48, 48, 48])
    #expect(Array(idle[47...49]) == [0, 48, 0])
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    feedback.frames[.a] = 48_000 * 60
    let blue = S2MK2Lights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(blue[47] == 0 && blue[48] == 0 && blue[49] > 80)
    #expect(Array(blue[59...61]) == [0, 0, 0])
    feedback.frames[.a] = 48_000
    let amber = S2MK2Lights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(amber[47] > amber[48] && amber[48] > 0 && amber[49] == 0)
    let framed = try S2MK2AccessoryProtocol.feedback(amber)
    #expect(framed.count == 75)
    #expect(Array(framed.prefix(6)) == [0xb3, 0xc3, 0, 70, 0, 0x83])
}

@Test @MainActor func s2MK2SelectsSplitAudioAndRestoresTheSavedRouteOnDisconnect() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Traktor Kontrol S2 MK2", wired: true)])
    #expect(controller.automaticOutputDevice == "S2 Mk2")
    #expect(controller.outputRoute == .masterAndHeadphones)
    try controller.setOutputRoute(.stereoMaster)
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([])
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func s2MK2RoutesGridPadsAndBothEffectsSections() {
    var controls = S2MK2Controls()
    var bytes: [UInt8] = .init(repeating: 0, count: 66)
    _ = controls.consume(bytes)
    bytes[10] = 0x0c
    #expect(controls.consume(bytes) == [.gridToggle(.a)])
    bytes[10] = 0x20
    bytes[12] = 0x0c
    bytes[13] = 0x88
    let events = controls.consume(bytes)
    #expect(events.contains(.gridDownbeat(.a, 2)))
    #expect(events.contains(.fxAssign(0, .a)))
    #expect(events.contains(.fxEnable(0, 0)))
    #expect(events.contains(.fxEnable(1, nil)))
    #expect(events.contains(.fxEnable(1, 2)))
    #expect(!events.contains(.pad(.a, 2, held: true, shifted: false)))
}

@Test func s2MK2SliceBankSpansTheEntireLoopWithFourPads() throws {
    let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000))
    let bank = try #require(
        S4MK2SliceBank(
            timing: timing, origin: 0, beats: 4, frames: 240_000, looping: true, count: 4))
    #expect(bank.range(slot: 3) == 72_000..<96_000)
    #expect(bank.range(slot: 4) == nil)
    #expect(bank.moved(groups: 1)?.range(slot: 0) == 96_000..<120_000)
}

@Test func s2MK2MicEngageTogglesOnlyOnTheDocumentedPressEdge() {
    var controls = S2MK2Controls()
    var bytes: [UInt8] = .init(repeating: 0, count: 66)
    func micEvents() -> [S4MK2Event] { controls.consume(bytes).filter { $0 == .native(.mic) } }

    bytes[9] = 0x08
    #expect(micEvents().isEmpty)
    bytes[9] = 0
    #expect(micEvents().isEmpty)
    bytes[9] = 0x04
    #expect(micEvents().isEmpty)
    bytes[9] = 0x08
    #expect(micEvents() == [.native(.mic)])
    #expect(micEvents().isEmpty)
    bytes[9] = 0
    #expect(micEvents().isEmpty)
    bytes[9] = 0x08
    #expect(micEvents() == [.native(.mic)])
}
