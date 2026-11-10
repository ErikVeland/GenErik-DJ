import TDJCore
import Testing

@testable import TDJInterface

@Test func s3StartupAndTwoFeedbackReportsMatchNativeFraming() throws {
    var startup = S3AccessoryProtocol.startup()
    #expect(try startup.consume(.init(reportID: 1, payload: .init(repeating: 0, count: 21))) == 2)
    #expect(!startup.ready)
    #expect(try startup.consume(.init(reportID: 2, payload: .init(repeating: 0, count: 62))) == nil)
    #expect(startup.ready)
    for (id, count) in [(UInt8(0x80), 83), (0x81, 79)] {
        let report = try S3AccessoryProtocol.feedback([id] + .init(repeating: 0, count: count - 1))
        #expect(Array(report.prefix(6)) == [0xb3, 0xc3, 0, UInt8(count), 0, id])
        #expect(report.count == count + 5)
    }
}

@Test func s3UsesInnerMixerAndDoesNotFireHeldStartupButtons() {
    var controls = S3Controls()
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    func report() -> [NativeTraktorEvent] { controls.consume(.init(reportID: 1, payload: buttons)) }
    buttons[2] = 0x01
    #expect(report().isEmpty)
    buttons[2] = 0
    #expect(report().isEmpty)
    buttons[2] = 0x03
    buttons[5] = 0x02
    buttons[6] = 0x80
    buttons[7] = 0x03
    let events = report()
    let actions = events.compactMap { event -> ControllerAction? in
        if case .action(let action, _) = event { return action }
        return nil
    }
    #expect(Set(actions) == [.playA, .playB, .hotcue1A, .cueA, .cueB])
    var pots: [UInt8] = .init(repeating: 0xff, count: 62)
    pots[4] = 0xff
    pots[5] = 0x07
    pots[6] = 0
    pots[7] = 0
    pots[2] = 0
    pots[3] = 0
    #expect(controls.consume(.init(reportID: 2, payload: pots)) == [.pot(.levelA, 0.5), .pot(.levelB, 0)])
}

@Test func s3UsesTheIPadJogCounterAndReleasesOnGridOrJogChanges() {
    var controls = S3Controls()
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    func report() -> [NativeTraktorEvent] { controls.consume(.init(reportID: 1, payload: buttons)) }
    func wheel(_ counter: Int, _ timer: Int) {
        let word = counter | timer << 10
        for index in 0..<4 { buttons[13 + index] = UInt8(truncatingIfNeeded: word >> (index * 8)) }
    }
    wheel(1022, 0x3fff00)
    _ = report()
    buttons[9] = 0x10
    wheel(2, 0x158)
    let events = report()
    #expect(events.contains(.action(.jogTouchA, 1)))
    #expect(events.contains(.action(.jogA, 0.75)))
    buttons[0] = 0x80
    #expect(report() == [.action(.jogTouchA, 0), .gridBegin(.a, anchor: false)])
    wheel(8, 0x300)
    #expect(report() == [.gridMove(.a, 6)])
    buttons[0] = 0
    #expect(report() == [.gridEnd(.a)])
    #expect(controls.touched.isEmpty)
}

@Test func s3SelectsFxForOneChannelOrBoth() {
    var controls = S3Controls()
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    func report() -> [NativeTraktorEvent] { controls.consume(.init(reportID: 1, payload: buttons)) }
    _ = report()
    buttons[7] = 0x20
    #expect(report().isEmpty)
    buttons[6] = 0x10
    #expect(report() == [.fx(.delay, [.a])])
    buttons[6] = 0
    buttons[7] = 0
    #expect(report().isEmpty)
    buttons[7] = 0x40
    _ = report()
    buttons[7] = 0
    #expect(report() == [.fx(.flanger, [.a, .b])])
}

@Test func s3JogRingPulsesBlueAndWarnsAmberWithoutTakingOverThePads() throws {
    let core = try SampleTransport(sampleRate: 8000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0, count: 960_000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: false)
    core.processControlsWhileIdle()
    func reports(_ seconds: Double, playing: Bool = true) throws -> [[UInt8]] {
        if core.snapshot()?.a.phase.active == true { try core.play(deck: .a, generation: generation) }
        try core.seek(frame: seconds * 8000, deck: .a, generation: generation)
        if playing { try core.play(deck: .a, generation: generation) }
        core.processControlsWhileIdle()
        return S3Lights.reports(
            snapshot: try #require(core.snapshot()), sourceFrames: (asset.frames, nil), cues: ([7], []))
    }
    let beat = try reports(0)
    #expect(beat.map(\.count) == [83, 79])
    #expect(beat[0][0x43..<0x4b].allSatisfy { $0 == 0x2f })
    #expect(beat[0][0x4b..<0x53].allSatisfy { $0 == 0 })
    #expect(try reports(0.25)[0][0x43] != 0x2f)
    #expect(try reports(30)[0][0x43] == 0x13)
    #expect(try reports(31)[0][0x43] & 0xfc == 0x2c)
    #expect(try reports(50.5)[0][0x43] == 0x13)
    let paused = try reports(50.5, playing: false)
    #expect(paused[0][0x43] == 0)
    #expect(beat[0][0x19] == paused[0][0x19])
}

@Test func s3BrowsePadModesAndMoveStayOnTheCorrectDeck() {
    var controls = S3Controls()
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    func report() -> [NativeTraktorEvent] { controls.consume(.init(reportID: 1, payload: buttons)) }
    buttons[11] = 0xf0
    _ = report()
    buttons[11] = 0
    buttons[4] = 0x80
    buttons[8] = 0x08
    #expect(report() == [.browser(.move(1, groups: false)), .browser(.load(.b))])
    buttons[5] = 0x04
    buttons[8] = 0x10
    #expect(report() == [.samplePad(4, shifted: false), .loopRoll(.b, true)])
    buttons[3] = 0x02
    buttons[8] = 0x08
    #expect(report() == [.eject(.b), .loopRoll(.b, false)])
}

@Test func s3MasterKnobOnlyChangesSoftwareGainWhileShiftIsHeld() {
    var controls = S3Controls()
    var pots: [UInt8] = .init(repeating: 0xff, count: 62)
    pots[0x16] = 0
    pots[0x17] = 0
    #expect(controls.consume(.init(reportID: 2, payload: pots)).isEmpty)
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    _ = controls.consume(.init(reportID: 1, payload: buttons))
    buttons[3] = 0x02
    _ = controls.consume(.init(reportID: 1, payload: buttons))
    pots[0x16] = 0xff
    pots[0x17] = 0x0f
    #expect(controls.consume(.init(reportID: 2, payload: pots)) == [.pot(.master, 1)])
}

@Test func s3PreviewAndEXTUseNativeEdgesAndInputCommand() throws {
    var controls = S3Controls()
    var buttons: [UInt8] = .init(repeating: 0, count: 21)
    func report() -> [NativeTraktorEvent] { controls.consume(.init(reportID: 1, payload: buttons)) }
    _ = report()
    buttons[0] = 0x08
    #expect(report() == [.s3Preview(true)])
    buttons[10] = 0x01
    #expect(report() == [.s3PreviewSeek(1)])
    buttons[0] = 0
    #expect(report() == [.s3Preview(false)])
    buttons[6] = 0x04
    #expect(report() == [.s3EXT(shifted: false)])
    buttons[6] = 0
    _ = report()
    buttons[3] = 0x02
    buttons[6] = 0x04
    buttons[7] = 0x04
    #expect(report() == [.s3EXT(shifted: true), .s3EXTCue])
    let line = try S3AccessoryProtocol.feedback(S3AccessoryProtocol.inputSource(line: true))
    let mic = try S3AccessoryProtocol.feedback(S3AccessoryProtocol.inputSource(line: false))
    #expect(line.count == 38 && mic.count == 38)
    #expect(Array(line.prefix(8)) == [0xb3, 0xc3, 0, 33, 0, 0xf4, 0x20, 0])
    #expect(mic[7] == 0x08)
}

@Test func s3MasterMeterAndEXTFeedbackUseSeparateBytes() throws {
    let core = try SampleTransport()
    let reports = S3Lights.reports(
        snapshot: try #require(core.snapshot()), sourceFrames: (nil, nil), cues: ([], []),
        external: (true, true), master: (0, 1, false, true))
    #expect(reports[0][0x33] == 0xff && reports[0][0x3b] == 0xff)
    #expect(reports[1][0x3d...0x45].allSatisfy { $0 == 0 })
    #expect(reports[1][0x46...0x4d].allSatisfy { $0 == 0x7f })
    #expect(reports[1][0x4e] == 0x7e)
}
