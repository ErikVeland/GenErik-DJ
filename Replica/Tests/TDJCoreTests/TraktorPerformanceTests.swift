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

@Test func traktorPerformanceMk2DecodesBothVinylSidesAndReacquiresAfterNeedleDrop() throws {
    let core = try SampleTransport(sampleRate: 48_000, outputGain: 1)
    let owner = core.nativeAudioRenderOwnership(metrics: nil)
    try #require(SampleTransport.prepareMk2Position())
    core.setFactoryInput(layout: 6, mask: 0)

    func push(_ block: [Float]) {
        block.withUnsafeBufferPointer { buffer in
            let pointers = (0..<6).map { buffer.baseAddress?.advanced(by: $0) }
            tdj_s4_input_push(owner.engineHandle, pointers, [6, 6, 6, 6, 6, 6], 512, 6, 48_000)
        }
    }

    func symbols(low: UInt64, high: UInt64, count: Int) -> [Double] {
        var low = low
        var high = high
        return (0..<count).map { _ in
            let symbol = Double((high >> 45) & 1)
            let bit = (low ^ (low >> 35) ^ (low >> 40) ^ (high >> 6) ^ (high >> 46)) & 1
            low = (low >> 1) | (high << 63)
            high = (high >> 1) | (bit << 45)
            return symbol
        }
    }

    let sideA = symbols(low: 0x03fc00c60f8c1f00, high: 0xc6007c63e, count: 31_000)
    let sideB = symbols(low: 0xe73ff00f9fe0c7c1, high: 0x1ff9f00003, count: 101_000)
    func feed(_ symbols: [Double], at start: Int, direction: Int, input: Int) {
        for blockIndex in 0..<16 {
            var block = [Float](repeating: 0, count: 512 * 6)
            for i in 0..<512 {
                let cycles = Double(blockIndex * 512 + i) * 2500 / 48_000
                let cycle = Int(cycles)
                let phase = cycles - Double(cycle)
                let position = start + direction * cycle - (direction < 0 ? 109 : 0)
                let transition = min(1, max(0, (phase - 0.05) / 0.4))
                let mix = 0.5 - 0.5 * cos(transition * .pi)
                let symbol = symbols[position] * (1 - mix) + symbols[position + direction] * mix
                block[i * 6 + input] = Float(0.25 * cos(phase * 2 * .pi) + 0.09 * (2 * symbol - 1))
                block[i * 6 + input + 1] = Float(Double(direction) * 0.25 * sin(phase * 2 * .pi))
            }
            push(block)
        }
    }

    feed(sideA, at: 30_000, direction: 1, input: 0)
    let first = core.factoryTimecode(side: 0)
    #expect(abs(try #require(first.seconds) - 30_426.0 / 2500) < 0.002)
    #expect(abs(try #require(first.rate) - 1) < 0.025)
    #expect(core.factoryTimecode(side: 1).seconds == nil)

    push(.init(repeating: 0, count: 512 * 6))
    #expect(core.factoryTimecode(side: 0).seconds == nil)
    #expect(core.factoryTimecode(side: 0).rate == nil)

    feed(sideB, at: 100_000, direction: -1, input: 0)
    let drop = core.factoryTimecode(side: 0)
    #expect(abs(try #require(drop.seconds) - 99_574.0 / 2500) < 0.002)
    #expect(abs(try #require(drop.rate) + 1) < 0.025)
    #expect(drop.stamp > first.stamp)

    feed(sideB, at: 60_000, direction: 1, input: 2)
    #expect(abs(try #require(core.factoryTimecode(side: 1).seconds) - 60_426.0 / 2500) < 0.002)
    #expect(core.factoryTimecode(side: 0).seconds == nil)
}

@Test func traktorPerformanceStemSendBypassesOnlyTheUnsentSignal() throws {
    let core = try SampleTransport(sampleRate: 48_000, outputGain: 1)
    func asset(_ left: Float, _ right: Float) throws -> PCMAsset {
        try PCMAsset(
            interleavedStereo: (0..<12_000).flatMap { _ in [left, right] }, sampleRate: 48_000)
    }
    let stem = try PCMAsset(master: asset(0.3, 0.3),
                            stems: [asset(0.3, 0), asset(0, 0.3), asset(0, 0), asset(0, 0)])
    let generation = try core.load(stem, deck: .a, grid: nil, synced: false)
    try core.play(deck: .a, generation: generation)
    try core.setEffect(PerformanceEffect.gater.rawValue, slot: 0, x: 0, y: 1, enabled: true, deck: .a)
    core.setStemSends(.a, generation: generation, levels: 0xffff00ff)
    let full = core.renderOffline(frames: 4096)
    let gated = 1024..<4096
    #expect(full.left[gated].contains { abs($0) < 0.05 })
    #expect(full.right[gated].allSatisfy { abs($0 - 0.3) < 0.01 })

    core.setStemSends(.a, generation: generation, levels: 0xffff0080)
    let half = core.renderOffline(frames: 2048)
    #expect(half.left.dropFirst(512).contains { abs($0 - 0.15) < 0.03 })
    #expect(half.right.dropFirst(512).allSatisfy { abs($0 - 0.3) < 0.01 })

    try core.play(deck: .a, generation: generation)
    core.processControlsWhileIdle()
    let next = try core.load(stem, deck: .a, grid: nil, synced: false)
    try core.play(deck: .a, generation: next)
    core.setStemSends(.a, generation: generation, levels: 0)
    let fresh = core.renderOffline(frames: 4096)
    #expect(fresh.right[gated].contains { abs($0) < 0.05 })
    core.setStemSends(.a, generation: next, levels: 0xffff00ff)
    core.setStemSends(.a, generation: generation, levels: UInt32.max)
    let current = core.renderOffline(frames: 4096)
    #expect(current.right[gated].allSatisfy { abs($0 - 0.3) < 0.01 })
}
