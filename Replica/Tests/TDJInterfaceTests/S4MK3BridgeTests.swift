import TDJCore
import Testing

@testable import TDJInterface

@Test func s4MK3BridgeKeepsMixerChannelsFixedWhenDeckLayersChange() {
    var controls = S4MK3Controls()
    var buttons: [UInt8] = [1] + .init(repeating: 0, count: 22)
    _ = controls.consume(buttons)
    buttons[6] = 8
    buttons[8] = 8
    let events = controls.consume(buttons)
    #expect(events.contains(.layer(.c)))
    #expect(events.contains(.action(.cueA, .a, 1)))
    buttons[5] = 1
    #expect(controls.consume(buttons) == [.action(.playA, .c, 1)])
}

@Test func s4MK3BridgeCarriesPackedHighBitsAndRejectsBrokenFrames() throws {
    let report: [UInt8] = [0x80] + .init(repeating: 0xff, count: 94)
    let frame = try ControllerBridgeFrame(kind: .s4MK3Lights, payload: report)
    var decoder = ControllerBridgeDecoder()
    #expect(decoder.append(Array(frame.encoded.prefix(61))).isEmpty)
    #expect(decoder.append(Array(frame.encoded.dropFirst(61))) == [frame])
    var broken = frame.encoded
    broken[broken.count - 2] ^= 1
    #expect(decoder.append(broken).isEmpty)
}

@Test @MainActor func s4MK3BridgeRoutesFourChannelsOnlyForItsOwnWiredOutput() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Traktor Kontrol S4 MK3", wired: true)])
    #expect(controller.automaticOutputDevice == nil)
    controller.updateOutputDevice([.init(name: "GenErik S4 Mk3 Bridge", wired: true)])
    #expect(controller.automaticOutputDevice == "S4 Mk3 Bridge")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([])
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func s4MK3BridgeSendsBlueThenAmberUsingOnlyTheSelectedRing() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .a, grid: grid)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    let blue = S4MK3Lights.ring(side: 0, state: snapshot.a, frames: 48_000 * 60)
    let amber = S4MK3Lights.ring(side: 0, state: snapshot.a, frames: 48_000)
    let idle = S4MK3Lights.ring(side: 1, state: snapshot.b, frames: nil)
    #expect(Array(blue.prefix(3)) == [0x32, 0, 5])
    #expect(blue.count == 41 && blue[9...].allSatisfy { (44...47).contains($0) })
    #expect(amber[9...].allSatisfy { (12...15).contains($0) })
    #expect(Array(idle.prefix(3)) == [0x32, 1, 0])
    #expect(idle[3...].allSatisfy { $0 == 0 })
}

@Test func s4MK3BridgeUsesUnsignedWheelCountersAndReleasesTouch() {
    var controls = S4MK3Controls()
    var buttons: [UInt8] = [1] + .init(repeating: 0, count: 22)
    _ = controls.consume(buttons)
    buttons[17] = 16
    #expect(controls.consume(buttons) == [.action(.jogTouchA, .a, 1)])
    var wheels: [UInt8] = [3] + .init(repeating: 0, count: 43)
    wheels.replaceSubrange(8..<16, with: [0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff])
    #expect(controls.consume(wheels).isEmpty)
    wheels.replaceSubrange(8..<16, with: [0, 0x80, 0, 0, 0, 0, 0, 0])
    let events = controls.consume(wheels)
    #expect(events == [.action(.jogA, .a, 0.5 + (28_790.0 / 32_768) / 8)])
    buttons[17] = 0
    #expect(controls.consume(buttons) == [.action(.jogTouchA, .a, 0)])
}

@Test @MainActor func s4MK3DriverKitOptInEnablesOnlyThePhysicalWiredDevice() throws {
    let controller = try PlaybackController(offline: true)
    let hardware = AudioOutputDevice(name: "Traktor Kontrol S4 MK3", wired: true)
    controller.updateOutputDevice([hardware])
    #expect(controller.automaticOutputDevice == nil)
    controller.s4MK3DirectAudioEnabled = true
    controller.updateOutputDevice([hardware])
    #expect(controller.automaticOutputDevice == "S4 Mk3")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([.init(name: hardware.name, wired: false)])
    #expect(controller.automaticOutputDevice == nil)
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func s4MK3DedicatedStemButtonKeepsSamplesSeparateAndTracksHeldPart() {
    var controller = S4MK3Controls()
    var report: [UInt8] = [1] + .init(repeating: 0, count: 22)
    _ = controller.consume(report)
    report[6] = 1
    report[4] = 8
    _ = controller.consume(report)
    #expect(controller.stems == [.a])
    #expect(controller.stemContacts[.a] == 0)
    report[4] = 0
    report[5] = 0x20
    _ = controller.consume(report)
    #expect(controller.stemContacts[.a] == nil)
    #expect(controller.stemMuteHeld == [.a])
    report[5] = 0x10
    _ = controller.consume(report)
    #expect(controller.stems.isEmpty)
    #expect(controller.samples == [.a])
}
