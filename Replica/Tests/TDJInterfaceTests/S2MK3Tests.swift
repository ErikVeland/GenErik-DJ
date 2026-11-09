import TDJCore
import Testing

@testable import TDJInterface

@Test func s2MK3RequestsPotsOnlyAfterValidShortReport() throws {
    let short = [UInt8](repeating: 0, count: 19)
    let long = [UInt8](repeating: 0, count: 38)
    let wire = [0x33, 0xc3, 0, 20, 0, 1] + short + [0x33, 0xc3, 0, 39, 0, 2] + long
    for cut in 0...wire.count {
        var decoder = Z1AccessoryProtocol.Decoder(framing: .lengthPrefixed)
        var startup = S2MK3AccessoryProtocol.Startup()
        _ = try startup.consume(.init(reportID: 2, payload: long))
        #expect(!startup.ready)
        let frames = try decoder.append(Array(wire.prefix(cut))) + decoder.append(Array(wire.dropFirst(cut)))
        #expect(frames.count == 2)
        var requests: [UInt8] = []
        for frame in frames {
            if let next = try startup.consume(frame) { requests.append(next) }
        }
        #expect(requests == [2])
        #expect(startup.ready)
    }
    var startup = S2MK3AccessoryProtocol.Startup()
    #expect(throws: TransportError.invalid) { try startup.consume(.init(reportID: 1, payload: [0])) }
    #expect(
        try S2MK3AccessoryProtocol.feedback([0x80] + Array(repeating: 0, count: 61)).prefix(6)
            == [0xb3, 0xc3, 0, 62, 0, 0x80])
}

@Test func s2MK3UsesDocumentedControlsAndIgnoresHeldStartupButtons() {
    var controls = S2MK3Controls()
    var buttons = [UInt8](repeating: 0, count: 19)
    buttons[1] = 8
    #expect(controls.consume(.init(reportID: 1, payload: buttons)).isEmpty)
    buttons[1] = 0
    buttons[4] = 0x20
    buttons[3] = 0x02
    buttons[7] = 0x80
    let events = controls.consume(.init(reportID: 1, payload: buttons))
    #expect(events == [.action(.playB, 1), .action(.cueB, 1), .action(.jogTouchB, 1)])
    #expect(controls.consume(.init(reportID: 1, payload: buttons)).isEmpty)
    buttons[7] = 0
    buttons[0] = 0x20
    buttons[2] = 0x08
    buttons[9] = 0x0f
    #expect(
        controls.consume(.init(reportID: 1, payload: buttons))
            == [.deleteCue(.a, 7), .action(.loopDownA, 1), .action(.jogTouchB, 0)])

    var pots = [UInt8](repeating: 0, count: 38)
    _ = controls.consume(.init(reportID: 2, payload: pots))
    pots[4] = 0xff
    pots[5] = 0x0f
    #expect(controls.consume(.init(reportID: 2, payload: pots)) == [.pot(.crossfader, 1)])
    #expect(controls.consume(.init(reportID: 2, payload: pots)).isEmpty)
    pots[5] = 0xff
    #expect(controls.consume(.init(reportID: 2, payload: pots)).isEmpty)
}

@Test func s2MK3ShowsBlueBeatAmberWarningAndRestoresPad() throws {
    let core = try SampleTransport(sampleRate: 8000)
    let asset = try PCMAsset(interleavedStereo: Array(repeating: 0, count: 960000), sampleRate: 8000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000)
    let generation = try core.load(asset, deck: .a, grid: grid, synced: false)
    core.processControlsWhileIdle()
    func report(_ time: Double, play: Bool = true) throws -> [UInt8] {
        if core.snapshot()?.a.phase.active == true {
            try core.play(deck: .a, generation: generation)
            core.processControlsWhileIdle()
        }
        try core.seek(frame: time * 8000, deck: .a, generation: generation)
        if play { try core.play(deck: .a, generation: generation) }
        core.processControlsWhileIdle()
        return S2MK3Lights.report(
            snapshot: try #require(core.snapshot()), sourceFrames: (asset.frames, nil), cues: ([0], [7]))
    }
    let blue = try report(0)
    #expect(blue[0x14] == 0x2e)
    #expect(blue[0x0d] == 0x2e && blue[0x3b] == 0x2e)
    #expect(try report(0.25)[0x14] < blue[0x14])
    #expect(try report(30)[0x14] == 0x12)
    #expect(try report(31)[0x14] == 0x2d)
    #expect(try report(50.5)[0x14] == 0x12)
    #expect(try report(50.5, play: false)[0x14] == 0x7c)
}

@Test func s2MK3JogHandlesTickAndClockWrapAndReleases() {
    var controls = S2MK3Controls()
    var bytes = [UInt8](repeating: 0, count: 19)
    func wheel(_ ticks: UInt32, _ clock: UInt32) -> [UInt8] {
        let word = ticks | clock << 10
        return (0..<4).map { UInt8(truncatingIfNeeded: word >> (8 * $0)) }
    }
    bytes.replaceSubrange(11..<15, with: wheel(1023, 0x3fff00))
    #expect(controls.consume(.init(reportID: 1, payload: bytes)).isEmpty)
    bytes[7] = 0x40
    bytes.replaceSubrange(11..<15, with: wheel(0, 44))
    #expect(controls.consume(.init(reportID: 1, payload: bytes)) == [.action(.jogTouchA, 1), .action(.jogA, 0.625)])
    bytes[7] = 0
    bytes.replaceSubrange(11..<15, with: wheel(1, 344))
    #expect(controls.consume(.init(reportID: 1, payload: bytes)) == [.action(.jogTouchA, 0)])
}

@Test func s2MK3RemainingButtonsUseIndependentDeckModesAndEncoders() {
    var controls = S2MK3Controls()
    var data = [UInt8](repeating: 0, count: 19)
    func frame(_ data: [UInt8]) -> Z1AccessoryProtocol.Frame { .init(reportID: 1, payload: data) }
    data[5] = 0x80
    #expect(controls.consume(frame(data)).isEmpty)
    data[5] = 0
    _ = controls.consume(frame(data))
    data[0] = 0x80
    data[1] = 0x10
    data[4] = 0x40
    data[8] = 0x0f
    data[9] = 0x30
    data[6] = 0x09
    let events = controls.consume(frame(data))
    #expect(events.contains(.samplePad(0, shifted: false)))
    #expect(events.contains(.action(.hotcue1B, 1)))
    #expect(events.contains(.browser(.move(-1, groups: false))))
    #expect(events.contains(.browser(.move(3, groups: false))))
    #expect(events.contains(.browser(.load(.a))))
    #expect(events.contains(.browser(.load(.b))))
    data[3] = 0x80
    data[2] = 0x40
    data[5] = 0x80
    let shifted = controls.consume(frame(data))
    #expect(shifted.contains(.fx(.delay, [.b])))
    #expect(shifted.contains(.mic))
    #expect(controls.consume(frame(data)).isEmpty)
}

@Test func s2MK3GridJogDoesNotScratchAndCommitsOnlyOnRelease() {
    var controls = S2MK3Controls()
    var data = [UInt8](repeating: 0, count: 19)
    _ = controls.consume(.init(reportID: 1, payload: data))
    data[0] = 0x10
    data[7] = 0x40
    data[11] = 8
    #expect(controls.consume(.init(reportID: 1, payload: data)) == [.gridBegin(.a, anchor: false), .gridMove(.a, 8)])
    data[0] = 0
    data[11] = 9
    #expect(controls.consume(.init(reportID: 1, payload: data)) == [.gridEnd(.a)])
}
