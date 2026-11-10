import TDJCore
import Testing

@testable import TDJInterface

@Test func s4MK2NegotiatesSixCalibrationReportsAndUsesOneFeedbackReport() throws {
    var startup = S4MK2AccessoryProtocol.startup()
    let buttons = Z1AccessoryProtocol.Frame(reportID: 1, payload: .init(repeating: 0, count: 98))
    #expect(try startup.consume(buttons) == nil)
    #expect(!startup.ready)
    for id in UInt8(0xd0)...0xd5 {
        let frame = Z1AccessoryProtocol.Frame(reportID: id, payload: .init(repeating: 0xff, count: 32))
        #expect(try startup.consume(frame) == (id == 0xd5 ? 1 : id + 1))
    }
    #expect(!startup.ready)
    #expect(try startup.consume(buttons) == nil)
    #expect(startup.ready)
    let report = try S4MK2AccessoryProtocol.feedback([0x83] + .init(repeating: 0, count: 174))
    #expect(Array(report.prefix(6)) == [0xb3, 0xc3, 0, 175, 0, 0x83])
    #expect(report.count == 180)
}

@Test func s4MK2SwitchesTheDeckSurfaceButKeepsMixerChannelsFixed() {
    var controls = S4MK2Controls()
    var bytes: [UInt8] = .init(repeating: 0, count: 98)
    func report() -> [S4MK2Event] { controls.consume(bytes) }
    bytes[12] = 1
    #expect(!report().contains(.action(.playA, .a, 1)))
    bytes[12] = 0
    bytes[14] = 0x20
    bytes[9] = 0x20
    #expect(report().contains(.layer(.c)))
    #expect(controls.layers == [.c, .d])
    bytes[12] = 1
    bytes[11] = 4
    bytes[14] = 0x40
    bytes[9] = 0x80
    bytes[0x3b + 19] = 0xf0
    bytes[0x3b + 20] = 0x0f
    let events = report()
    #expect(events.contains(.action(.playA, .c, 1)))
    #expect(events.contains(.action(.syncB, .d, 1)))
    #expect(events.contains(.action(.cueA, .a, 1)))
    #expect(events.contains(.action(.cueB, .d, 1)))
    #expect(events.contains(.pot(.levelA, .c, 1)))
}

@Test func s4MK2CalibratesTheCrossfaderAndReleasesAPlatterOnLayerChange() {
    var controls = S4MK2Controls()
    for id in UInt8(0xd0)...0xd5 {
        var block = [UInt8](repeating: 0xff, count: 32)
        if id == 0xd5 {
            block.replaceSubrange(28..<32, with: [0x00, 0x02, 0x00, 0x0a])
        }
        controls.addCalibration(.init(reportID: id, payload: block))
    }
    var bytes: [UInt8] = .init(repeating: 0, count: 98)
    bytes[27] = 6
    #expect(controls.consume(bytes).contains(.pot(.crossfader, .a, 0.5)))
    bytes[16] = 1
    #expect(controls.consume(bytes).contains(.action(.jogTouchA, .a, 1)))
    bytes[14] = 0x20
    #expect(controls.consume(bytes).contains(.action(.jogTouchA, .a, 0)))
    #expect(controls.touched.isEmpty)
    bytes[12] = 0x0c
    #expect(controls.consume(bytes).contains(.gridToggle(.c)))
    bytes[12] = 0x80
    #expect(controls.consume(bytes).contains(.gridDownbeat(.c, 0)))
}

@Test func s4MK2ShowsTheBluePulseAndAmberWarningForTheSelectedOuterDeck() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .c, grid: grid)
    try core.play(deck: .c, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    var controls = S4MK2Controls()
    var bytes = [UInt8](repeating: 0, count: 98)
    _ = controls.consume(bytes)
    bytes[14] = 0x20
    _ = controls.consume(bytes)

    var feedback = S4MK2Lights.Feedback()
    feedback.frames[.c] = 48_000 * 60
    let blue = S4MK2Lights.report(snapshot: snapshot, controls: controls, feedback: feedback)
    #expect(blue[62] == 0 && blue[63] == 0 && blue[64] > 80)
    #expect(blue[74] == 0 && blue[75] == 0 && blue[76] == 0)
    feedback.frames[.c] = 48_000
    let amber = S4MK2Lights.report(snapshot: snapshot, controls: controls, feedback: feedback)
    #expect(amber[62] > amber[63] && amber[63] > 0 && amber[64] == 0)
}

@Test @MainActor func s4MK2SelectsSplitOutputWithoutChangingTheSavedChoice() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Traktor Kontrol S4 MK2", wired: true)])
    #expect(controller.automaticOutputDevice == "S4 Mk2")
    #expect(controller.outputRoute == .masterAndHeadphones)
    try controller.setOutputRoute(.stereoMaster)
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([])
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func s4MK2DecodesMovePadEdgesAndCueOwnershipAcrossLayers() {
    var controls = S4MK2Controls()
    var bytes = [UInt8](repeating: 0, count: 98)
    func report() -> [S4MK2Event] { controls.consume(bytes) }
    _ = report()
    bytes[18] = 1
    #expect(report().contains(.sliceMode(.a)))
    bytes[18] = 0
    bytes[12] = 0x82
    bytes[13] = 0x10
    let pressed = report()
    #expect(pressed.contains(.cue(.a, held: true)))
    #expect(pressed.contains(.pad(.a, 0, held: true, shifted: false)))
    #expect(pressed.contains(.pad(.a, 7, held: true, shifted: false)))
    bytes[12] = 0x02
    #expect(report().contains(.pad(.a, 0, held: false, shifted: false)))
    bytes[14] = 0x20
    #expect(report().contains(.cue(.a, held: false)))
    bytes[12] = 0
    #expect(!report().contains(.cue(.c, held: false)))
}

@Test func s4MK2UsesEightGridSlicesWithTrackAndLoopBoundaries() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let timing = BeatTiming(fixed: grid)
    let freeze = try #require(S4MK2SliceBank(timing: timing, origin: 2, beats: 4, frames: 144_000, looping: false))
    #expect(freeze.range(slot: 0) == 48_000..<60_000)
    #expect(freeze.range(slot: 7) == 132_000..<144_000)
    #expect(freeze.moved(groups: 1)?.range(slot: 0) == 48_000..<60_000)
    let loop = try #require(S4MK2SliceBank(timing: timing, origin: 1, beats: 2, frames: 144_000, looping: true))
    #expect(loop.range(slot: 7) == 66_000..<72_000)
}

@Test func s4MK2CueReleaseParksAndPlayKeepsTheDeckGoing() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.2, count: 192_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .c, grid: grid, synced: true)
    let start = SourceControl.performance(
        .touch, .c, generation, value: 24_000, end: 0, enabled: true, quantum: 0, touchRate: 1,
        followsPosition: true)
    try core.submit(start)
    _ = core.renderOffline(frames: 512)
    #expect(core.snapshot()?[.c].touchActive == true)
    try core.submit(.finishCueContact(deck: .c, generation: generation, cue: 24_000, continuePlaying: false))
    _ = core.renderOffline(frames: 512)
    let parked = try #require(core.snapshot()?[.c])
    #expect(parked.phase == .paused && parked.sourceFrame == 24_000 && parked.synced && !parked.touchActive)

    try core.submit(start)
    _ = core.renderOffline(frames: 512)
    try core.submit(.finishCueContact(deck: .c, generation: generation, cue: 24_000, continuePlaying: true))
    _ = core.renderOffline(frames: 512)
    let playing = try #require(core.snapshot()?[.c])
    #expect(playing.phase == .playing && playing.sourceFrame > 24_000 && playing.synced && !playing.touchActive)
}

@Test func s4MK2SliceFeedbackDistinguishesFreezeAndLoopAndShowsTheHeldPad() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let snapshot = try #require(core.snapshot())
    var feedback = S4MK2Lights.Feedback()
    feedback.sliceModes = [.a: false, .b: true]
    feedback.heldSlices = [.a: 1, .b: 6]
    let lights = S4MK2Lights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(lights[53] == 0 && lights[54] == 0 && lights[55] == 0x30)
    #expect(lights[58] == 0x7f)
    #expect(lights[65] == 0 && lights[66] == 0x30 && lights[67] == 0)
    #expect(lights[52 + 0x21 + 2] == 0x7f)
}

@Test func s4MK2MicVolumeUsesOnlyTheFactoryAnalogWord() {
    var controls = S4MK2Controls()
    var bytes = [UInt8](repeating: 0xff, count: 98)
    func levels() -> [Double] {
        controls.consume(bytes).compactMap { event in
            if case .micLevel(let level) = event { return level }
            return nil
        }
    }

    #expect(levels().isEmpty)
    bytes[34] = 0x00
    bytes[35] = 0x08
    #expect(levels() == [0.5])
    bytes[32] = 16
    bytes[33] = 0
    bytes[36] = 16
    bytes[37] = 0
    #expect(levels().isEmpty)
    bytes[34] = 16
    bytes[35] = 0
    #expect(levels() == [0])
    bytes[34] = 0xf0
    bytes[35] = 0x0f
    #expect(levels() == [1])
    #expect(levels().isEmpty)

    controls = .init()
    #expect(levels() == [1])
}
