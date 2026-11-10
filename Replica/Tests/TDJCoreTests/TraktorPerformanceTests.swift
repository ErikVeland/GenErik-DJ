import CTDJTransport
import Foundation
import Testing

@testable import TDJCore

@Test func traktorPerformanceStemMixUsesTheDeckCursor() throws {
    func asset(_ value: Float) throws -> PCMAsset {
        try PCMAsset(interleavedStereo: .init(repeating: value, count: 96_000), sampleRate: 48_000)
    }
    let core = try SampleTransport(outputGain: 1)
    let stem = try PCMAsset(master: asset(0.4), stems: [asset(0.1), asset(0.2), asset(0.3), asset(0.4)])
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(stem, deck: .a, grid: grid)
    try core.play(deck: .a, generation: generation)
    let master = core.renderOffline(frames: 512).left.last!
    let frame = try #require(core.snapshot()).a.sourceFrame
    core.setStemMix(.a, settings: 127)
    let isolated = core.renderOffline(frames: 512).left.last!
    #expect(master > 0.05)
    #expect(abs(isolated / master - 0.25) < 0.01)
    #expect(try #require(core.snapshot()).a.sourceFrame == frame + 512)
    core.setStemMix(.a, settings: 0)
    #expect(abs(core.renderOffline(frames: 512).left.last!) < 0.001)
}

@Test func traktorPerformancePatternWaitsForTheNextBeatStep() throws {
    let core = try SampleTransport(outputGain: 1)
    let asset = try PCMAsset(interleavedStereo: .init(repeating: 0, count: 96_000), sampleRate: 48_000)
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48_000)
    let generation = try core.load(asset, deck: .a, grid: grid)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 1000)
    let settings: UInt64 = 3 | (1 << 16) | (1 << 20) | (255 << 43)
    core.setPatternUnit(0, settings: settings)
    #expect(core.renderOffline(frames: 4990).left.allSatisfy { $0 == 0 })
    #expect(core.renderOffline(frames: 96).left.contains { abs($0) > 0.01 })
    core.setPatternUnit(0, settings: 0)
    #expect(core.renderOffline(frames: 96).left.allSatisfy { $0 == 0 })
}

@Test(arguments: [1.0, -1.25, 0.35])
func traktorPerformanceTimecodeEstimatesSignedRate(rate: Double) {
    let phase = (0..<512).map { Double($0) * rate * 2500 / 48_000 * 2 * .pi }
    let left = phase.map { Float(0.25 * cos($0) + 0.45 * sin($0 / 30)) }
    let right = phase.map { Float(0.25 * sin($0) - 0.45 * cos($0 / 30)) }
    var speed = 0.0
    #expect(tdj_timecode_speed(left, right, UInt32(left.count), 48_000, &speed))
    #expect(abs(speed - rate) < 0.009)
    #expect(!tdj_timecode_speed(left, left, UInt32(left.count), 48_000, &speed))
    let silence = [Float](repeating: 0, count: 512)
    #expect(!tdj_timecode_speed(silence, silence, 512, 48_000, &speed))
    var invalid = left
    invalid[0] = .nan
    #expect(!tdj_timecode_speed(invalid, right, 512, 48_000, &speed))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["TDJ_STEM_FIXTURE"] != nil))
func traktorPerformanceDecodesARealFiveTrackContainer() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["TDJ_STEM_FIXTURE"])
    let asset = try await StemPCM.prepare(url: URL(fileURLWithPath: path)) { true }
    #expect(asset.hasStems)
    #expect(asset.frames >= 40_000)
    #expect(asset.sampleRate == 48_000)
}

@Test func traktorPerformanceZ2KeepsVinylOutOfTheMasterBus() throws {
    let core = try SampleTransport(sampleRate: 48_000, outputGain: 1)
    let owner = core.nativeAudioRenderOwnership(metrics: nil)
    try core.setMixer(.volume, value: 1, deck: .a)
    core.setS4MicLevel(1)
    core.setFactoryInput(layout: 6, mask: 0)
    func feed() {
        var block = [Float]()
        for i in 0..<1024 {
            let angle = Double(i) * 2500 / 48_000 * 2 * .pi
            block += [Float(0.25 * cos(angle)), Float(0.25 * sin(angle)), 0.5, 0.75, 0.125, 0.25]
        }
        block.withUnsafeBufferPointer { buffer in
            let pointers = (0..<6).map { buffer.baseAddress?.advanced(by: $0) }
            tdj_s4_input_push(owner.engineHandle, pointers, [6, 6, 6, 6, 6, 6], 1024, 6, 48_000)
        }
    }
    feed()
    let buses = core.renderBusesOffline(frames: 512)
    #expect(buses.left.last == 0.125)
    #expect(buses.right.last == 0.25)
    #expect(abs((core.factoryTimecode(side: 0).rate ?? 0) - 1) < 0.002)
    #expect(core.factoryTimecode(side: 1).rate == nil)
    core.setFactoryInput(layout: 6, mask: 2)
    try core.setMixer(.volume, value: 1, deck: .b)
    let line = core.renderBusesOffline(frames: 256)
    #expect(line.left.last == 0.625)
    #expect(line.right.last == 1)
}

@Test func traktorPerformanceS8OnlyRoutesTheSelectedInputPair() throws {
    let core = try SampleTransport(sampleRate: 48_000, outputGain: 1)
    try core.prepareExtraDecks()
    let owner = core.nativeAudioRenderOwnership(metrics: nil)
    try core.setMixer(.volume, value: 1, deck: .c)
    try core.setMixer(.volume, value: 1, deck: .d)
    core.setFactoryInput(layout: 4, mask: 8)
    let block = (0..<1024).flatMap { _ -> [Float] in [0.125, 0.25, 0.375, 0.5] }
    block.withUnsafeBufferPointer { buffer in
        let pointers = (0..<4).map { buffer.baseAddress?.advanced(by: $0) }
        tdj_s4_input_push(owner.engineHandle, pointers, [4, 4, 4, 4], 1024, 4, 48_000)
    }
    let buses = core.renderBusesOffline(frames: 512)
    #expect(buses.left.last == 0.375)
    #expect(buses.right.last == 0.5)
}
