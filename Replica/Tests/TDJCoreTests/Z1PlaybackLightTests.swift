import Foundation
import Testing

@testable import TDJCore

private struct Z1LightFixture {
    let core: SampleTransport
    let frames: UInt64
    let generation: UInt64

    init(downbeat: Int = 0, adaptive: Bool = false, gridAvailable: Bool = true) throws {
        core = try SampleTransport(sampleRate: 8000)
        let asset = try PCMAsset(interleavedStereo: [Float](repeating: 0, count: 60 * 8000 * 2), sampleRate: 8000)
        frames = asset.frames
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 8000, downbeatOffset: downbeat)
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 20, frame: 160000), .init(beat: 40, frame: 200000)],
            sampleRate: 8000)
        generation = try core.load(
            asset, deck: .a, grid: gridAvailable ? grid : nil, synced: adaptive, adaptiveMap: adaptive ? map : nil)
        try core.setMasterBPM(120)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    }

    func move(to seconds: Double) throws {
        if core.snapshot()?.a.phase == .playing {
            try core.play(deck: .a, generation: generation)
            core.processControlsWhileIdle()
        }
        try core.seek(frame: seconds * 8000, deck: .a, generation: generation)
        try core.play(deck: .a, generation: generation)
        core.processControlsWhileIdle()
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
        #expect(core.snapshot()?.a.phase == .playing)
    }

    func report(fx: Bool = false, enabled: Bool = false, knownLength: Bool = true) throws -> [UInt8] {
        Z1OutputReport.bytes(
            snapshot: try #require(core.snapshot()), mode: true, fxDecks: fx ? [.a] : [],
            enabledEffects: enabled ? [.a] : [], sourceFrames: (knownLength ? frames : nil, nil))
    }
}

@Test func z1AmberChangesFromFourBeatsToOneAtThirtyAndTenSeconds() throws {
    let fixture = try Z1LightFixture()
    for (seconds, brightness): (Double, UInt8) in [
        (29.999, 0), (30, 127), (31, 0), (32, 127), (49.5, 0), (50, 127), (50.5, 127), (50.75, 0), (10, 0),
    ] {
        try fixture.move(to: seconds)
        #expect(try fixture.report()[17] == brightness)
    }
    let shifted = try Z1LightFixture(downbeat: 2)
    try shifted.move(to: 30)
    #expect(try shifted.report()[17] == 0)
    try shifted.move(to: 31)
    #expect(try shifted.report()[17] == 127)
}

@Test func z1BlueGivesAShortBeatPulseAndKeepsFilterAndFXStatusVisible() throws {
    let fixture = try Z1LightFixture()
    for (seconds, brightness): (Double, UInt8) in [(0, 34), (0.05, 22), (0.1, 10), (0.5, 34)] {
        try fixture.move(to: seconds)
        #expect(try fixture.report()[18] == brightness)
        #expect(try fixture.report()[17] == 0)
    }
    try fixture.core.setMixer(.filterEnabled, value: 1, deck: .a)
    try fixture.move(to: 0)
    #expect(try fixture.report()[18] == 127)
    try fixture.move(to: 0.1)
    #expect(try fixture.report()[18] == 96)
    #expect(try fixture.report(fx: true, enabled: true)[17] == 127)
    #expect(try fixture.report(fx: true, enabled: true)[18] == 0)
    try fixture.move(to: 0.5)
    #expect(try fixture.report(fx: true, enabled: true)[18] == 24)
}

@Test func z1WarningUsesPlaybackSpeedAndAdaptiveBeatDistance() throws {
    let fixture = try Z1LightFixture()
    try fixture.core.setFreeRate(0.5, deck: .a, generation: fixture.generation)
    try fixture.move(to: 30)
    #expect(try fixture.report()[17] == 0)
    try fixture.core.setFreeRate(1.5, deck: .a, generation: fixture.generation)
    try fixture.move(to: 16)
    #expect(try fixture.report()[17] == 127)
    try fixture.move(to: 44.5)
    #expect(try fixture.report()[17] == 64)
    try fixture.move(to: 45.5)
    #expect(try fixture.report()[17] == 127)

    let adaptive = try Z1LightFixture(adaptive: true)
    try adaptive.move(to: 0)
    #expect(try adaptive.report()[17] == 0)
    try adaptive.move(to: 0.5)
    #expect(try adaptive.report()[18] == 10)
    try adaptive.move(to: 50)
    #expect(try adaptive.report()[17] == 127)
    try adaptive.move(to: 55.5)
    #expect(try adaptive.report()[17] == 127)
}

@Test func z1WarningRestoresStatusOnPauseAndStaysOffInLoops() throws {
    let fixture = try Z1LightFixture()
    try fixture.move(to: 50.25)
    #expect(try fixture.report(fx: true, enabled: true)[17] == 32)
    try fixture.move(to: 50)
    #expect(try fixture.report()[17] == 127)
    #expect(try fixture.report()[18] == 24)
    #expect(try fixture.report(knownLength: false)[17] == 0)
    try fixture.core.perform(.loop, deck: .a, generation: fixture.generation, value: 50 * 8000, end: 52 * 8000)
    fixture.core.processControlsWhileIdle()
    #expect(fixture.core.snapshot()?.a.loopEnabled == true)
    #expect(try fixture.report()[17] == 0)
    #expect(try fixture.report()[18] == 34)
    try fixture.core.play(deck: .a, generation: fixture.generation)
    fixture.core.processControlsWhileIdle()
    #expect(try fixture.report()[18] == 10)
    #expect(try fixture.report(fx: true, enabled: true)[17] == 127)
    #expect(try fixture.report(fx: true, enabled: true)[18] == 0)

    let noGrid = try Z1LightFixture(gridAvailable: false)
    try noGrid.move(to: 50)
    #expect(try noGrid.report()[17] == 0 && noGrid.report()[18] == 10)
}

@Test func z1LightsKeepChannelsIndependentAndDoNotChangePlaybackOrOtherFeedback() throws {
    let fixture = try Z1LightFixture()
    let asset = try #require(fixture.core.asset(generation: fixture.generation))
    let b = try fixture.core.load(
        asset, deck: .b, grid: BeatGrid(bpm: 90, anchorFrame: 0, sampleRate: 8000), sourceFrame: 2 * 8000,
        synced: false)
    try fixture.core.setMixer(.cue, value: 1, deck: .b)
    try fixture.core.play(deck: .b, generation: b)
    try fixture.move(to: 50)
    let before = try #require(fixture.core.snapshot())
    let bytes = try fixture.report()
    #expect(bytes[17] == 127 && bytes[20] == 0)
    #expect(bytes[18] == 24 && bytes[21] == 34)
    #expect(bytes[15] == 10 && bytes[16] == 127 && bytes[19] == 127)
    #expect(bytes[1..<15].allSatisfy { $0 == 0 })
    #expect(bytes.count == 22 && bytes[0] == 0x80)
    #expect(bytes.dropFirst().allSatisfy { $0 <= 127 })
    #expect(fixture.core.snapshot() == before)
    try fixture.core.play(deck: .b, generation: b)
    fixture.core.processControlsWhileIdle()
    #expect(try fixture.report()[21] == 10)
    #expect(try fixture.report()[17] == 127)
}

@Test func z1BluePulseFollowsTheAudioClockAtChangedTempo() throws {
    let fixture = try Z1LightFixture()
    try fixture.core.setFreeRate(0.5, deck: .a, generation: fixture.generation)
    try fixture.move(to: 0)
    #expect(try fixture.report()[18] == 34)
    _ = fixture.core.renderOffline(frames: 800)
    #expect(try fixture.report()[18] == 22)
    _ = fixture.core.renderOffline(frames: 800)
    #expect(try fixture.report()[18] == 10)
    _ = fixture.core.renderOffline(frames: 6400)
    #expect(try fixture.report()[18] == 34)
}

@Test(arguments: ["touch", "brake", "reverse", "ended"])
func z1PlaybackLightsStopDuringManualTransportOrAtTheEnd(action: String) throws {
    let fixture = try Z1LightFixture()
    try fixture.move(to: action == "ended" ? 59.99 : 50)
    switch action {
    case "touch":
        try fixture.core.perform(.touch, deck: .a, generation: fixture.generation, value: 50 * 8000)
    case "brake": try fixture.core.brake(.begin, deck: .a, generation: fixture.generation)
    case "reverse": try fixture.core.perform(.rate, deck: .a, generation: fixture.generation, value: -1)
    default: _ = fixture.core.renderOffline(frames: 82)
    }
    fixture.core.processControlsWhileIdle()
    #expect(fixture.core.acknowledgements().allSatisfy { $0.error == nil })
    #expect(try fixture.report()[17] == 0 && fixture.report()[18] == 10)
}
