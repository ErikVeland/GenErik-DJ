import TDJCore
import Testing

@testable import TDJInterface

@Test func beatpadDecodesOriginalMixerPitchAndTransport() {
    var midi = ControllerMIDIDecoder()
    var controls = BeatpadControls()
    let input: [UInt8] = [0x91, 0x60, 127, 0xb0, 0x4f, 127, 0xb4, 0x45, 0, 0xe1, 0, 64, 0x91, 0x0c, 127]
    let events = midi.append(input).flatMap { controls.consume($0, time: 1) }
    #expect(
        events == [
            .shared(.action(.playB, .b, 1)), .shared(.pot(.levelA, .a, 1)),
            .shared(.pot(.crossfader, .a, 0)), .shared(.pot(.tempoB, .b, 0.5)),
            .hotCue(.b, 0, delete: true),
        ])
}

@Test func beatpadAcceptsBothDocumentedJogNumbersAndReleasesWithShift() {
    var midi = ControllerMIDIDecoder()
    var controls = BeatpadControls()
    func read(_ bytes: [UInt8], at time: Double) -> [BeatpadEvent] {
        midi.append(bytes).flatMap { controls.consume($0, time: time) }
    }
    #expect(read([0x90, 0x63, 127], at: 1) == [.shared(.action(.jogTouchA, .a, 1))])
    let documented = read([0xb0, 0x43, 0x42], at: 1.005)
    let observed = read([0xb0, 0x63, 0x42], at: 1.010)
    for event in [documented.first, observed.first] {
        guard case .shared(.action(.jogA, .a, let value))? = event else {
            Issue.record("Expected scratch motion.")
            continue
        }
        #expect(value > 0.5 && value < 1)
    }
    #expect(read([0x90, 0x23, 0], at: 1.011) == [.shared(.action(.jogTouchA, .a, 0))])
    #expect(read([0xb1, 0x64, 0x3e], at: 1.012) == [.shared(.action(.wheelJogB, .b, 0.4375))])
}

@Test func beatpadUsesHardwarePadBanksAndMomentaryLoopRelease() {
    var midi = ControllerMIDIDecoder()
    var controls = BeatpadControls()
    let bytes: [UInt8] = [0x91, 0x49, 127, 0x50, 127, 0x10, 0, 0x5b, 127, 0xb4, 0x02, 0x3e]
    let events = midi.append(bytes).flatMap { controls.consume($0, time: 1) }
    #expect(
        events == [
            .roll(.b, 0.125, held: true), .roll(.b, 0.125, held: false),
            .shared(.native(.samplePad(7, shifted: false))), .shared(.native(.browser(.move(-2, groups: true)))),
        ])
}

@Test @MainActor func beatpadSelectsFourChannelAudioOnlyForTheOriginalWiredDevice() throws {
    let controller = try PlaybackController(offline: true)
    controller.updateOutputDevice([.init(name: "Reloop Beatpad", wired: true)])
    #expect(controller.automaticOutputDevice == "Beatpad")
    #expect(controller.outputRoute == .masterAndHeadphones)
    controller.updateOutputDevice([.init(name: "Beatpad 2", wired: true)])
    #expect(controller.automaticOutputDevice == nil)
    controller.updateOutputDevice([.init(name: "Beatpad", wired: false)])
    #expect(controller.outputRoute == .stereoMaster)
}

@Test func beatpadUsesBlueBeatRingAndRedGreenTrackEndColourOnTheCorrectDeck() throws {
    let core = try SampleTransport(sampleRate: 48_000)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0.25, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .b, grid: grid)
    try core.play(deck: .b, generation: generation)
    _ = core.renderOffline(frames: 256)
    let snapshot = try #require(core.snapshot())
    var feedback = BeatpadLights.Feedback()
    feedback.frames[.b] = 48_000 * 60
    let beat = BeatpadLights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(beat.contains(.init(channel: 1, note: 0x68, value: 127)))
    #expect(beat.contains(.init(channel: 0, note: 0x68, value: 0)))
    feedback.frames[.b] = 48_000
    let ending = BeatpadLights.report(snapshot: snapshot, controls: .init(), feedback: feedback)
    #expect(ending.contains(.init(channel: 1, note: 0x68, value: 0)))
    for light in UInt8(0x69)...0x6c {
        #expect(ending.contains(.init(channel: 1, note: light, value: 4)))
        #expect(ending.contains(.init(channel: 0, note: light, value: 0)))
    }
}

@Test func beatpadFaderStartRequiresExplicitEnableAndARealMovementFromZero() {
    var controls = BeatpadControls()
    var midi = ControllerMIDIDecoder()
    let bytes: [UInt8] = [0xb0, 0x4f, 0, 0x90, 0x22, 127, 0xb0, 0x4f, 127, 0x4f, 0]
    #expect(
        midi.append(bytes).flatMap { controls.consume($0, time: 1) } == [
            .shared(.pot(.levelA, .a, 0)), .shared(.pot(.levelA, .a, 1)), .faderStart(.a, 1),
            .shared(.pot(.levelA, .a, 0)), .faderStart(.a, 0),
        ])
}
