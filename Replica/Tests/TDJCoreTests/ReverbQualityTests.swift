import Foundation
import Testing

@testable import TDJCore

private func reverbImpulse(_ kind: PerformanceEffect, size: Double, polarity: Float = 1) throws -> (
    left: [Float], right: [Float]
) {
    let rate = 48000.0
    var samples = [Float](repeating: 0, count: 48000 * 4 * 2)
    samples[4800 * 2] = 0.5 * polarity
    samples[4800 * 2 + 1] = 0.5 * polarity
    let core = try SampleTransport(sampleRate: rate)
    let generation = try core.load(
        PCMAsset(interleavedStereo: samples, sampleRate: rate), deck: .a, grid: nil, synced: false)
    try core.setEffect(kind.rawValue, slot: 0, x: size, y: 1, enabled: true, deck: .a)
    try core.play(deck: .a, generation: generation)
    let audio = core.renderOffline(frames: 48000 * 4)
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    return (audio.left, audio.right)
}

@Test func reverbsProduceDenseStereoTailsWithoutCollapsingInMono() throws {
    for effect in [PerformanceEffect.reverb, .iceverb] {
        let audio = try reverbImpulse(effect, size: 0.5)
        let left = audio.left[24000..<48000].map(Double.init)
        let right = audio.right[24000..<48000].map(Double.init)
        let leftEnergy = left.reduce(0) { $0 + $1 * $1 }
        let rightEnergy = right.reduce(0) { $0 + $1 * $1 }
        let cross = zip(left, right).reduce(0) { $0 + $1.0 * $1.1 }
        let density = Double(left.filter { abs($0) > 1e-8 }.count) / Double(left.count)
        let monoEnergy = zip(left, right).reduce(0) { $0 + pow(($1.0 + $1.1) * 0.5, 2) }
        #expect(audio.left.allSatisfy { $0.isFinite && abs($0) < 1 })
        #expect(audio.right.allSatisfy { $0.isFinite && abs($0) < 1 })
        #expect(leftEnergy > 1e-8 && rightEnergy > 1e-8)
        #expect(density > 0.95)
        #expect(abs(cross / sqrt(leftEnergy * rightEnergy)) < 0.6)
        #expect(monoEnergy > (leftEnergy + rightEnergy) * 0.1)
    }
}

@Test func reverbSizeExtendsTheTailAndPolarityRemainsLinear() throws {
    for effect in [PerformanceEffect.reverb, .iceverb] {
        let short = try reverbImpulse(effect, size: 0)
        let long = try reverbImpulse(effect, size: 1)
        let inverted = try reverbImpulse(effect, size: 1, polarity: -1)
        let shortEnergy = short.left[96000..<144000].reduce(0.0) { $0 + Double($1) * Double($1) }
        let longEnergy = long.left[96000..<144000].reduce(0.0) { $0 + Double($1) * Double($1) }
        #expect(longEnergy > shortEnergy * 10)
        #expect(zip(long.left, inverted.left).allSatisfy { abs($0 + $1) < 1e-7 })
        #expect(zip(long.right, inverted.right).allSatisfy { abs($0 + $1) < 1e-7 })
    }
}

@Test func reverbReleasePreservesTheTailAndZeroYStopsIt() throws {
    for effect in [PerformanceEffect.reverb, .iceverb] {
        let rate = 48000.0
        var samples = [Float](repeating: 0, count: 48000 * 2 * 2)
        samples[4800 * 2] = 0.5
        samples[4800 * 2 + 1] = 0.5
        let core = try SampleTransport(sampleRate: rate)
        let generation = try core.load(
            PCMAsset(interleavedStereo: samples, sampleRate: rate), deck: .a, grid: nil, synced: false)
        try core.setEffect(effect.rawValue, slot: 0, x: 0.5, y: 1, enabled: true, deck: .a)
        try core.play(deck: .a, generation: generation)
        _ = core.renderOffline(frames: 24000)

        try core.setEffect(effect.rawValue, slot: 0, x: 0.5, y: 1, enabled: false, deck: .a)
        let released = core.renderOffline(frames: 4800)
        let lateEnergy = released.left[480...].reduce(0.0) { $0 + Double($1) * Double($1) }
        #expect(lateEnergy > 1e-8)
        #expect(released.left.allSatisfy { $0.isFinite })
        #expect(released.right.allSatisfy { $0.isFinite })

        try core.setEffect(effect.rawValue, slot: 0, x: 0.5, y: 0, enabled: false, deck: .a)
        let muted = core.renderOffline(frames: 960)
        #expect(muted.left[480...].allSatisfy { $0 == 0 })
        #expect(muted.right[480...].allSatisfy { $0 == 0 })

        try core.setEffect(effect.rawValue, slot: 0, x: 0.5, y: 1, enabled: true, deck: .a)
        let restarted = core.renderOffline(frames: 4800)
        #expect(restarted.left.allSatisfy { $0 == 0 })
        #expect(restarted.right.allSatisfy { $0 == 0 })
        #expect(core.acknowledgements().allSatisfy { $0.error == nil })
    }
}

@Test func changingAReleasedReverbFadesWithoutReplayingItsHistory() throws {
    let rate = 48000.0
    var samples = [Float](repeating: 0, count: 48000 * 2 * 2)
    samples[4800 * 2] = 0.5
    samples[4800 * 2 + 1] = 0.5
    let core = try SampleTransport(sampleRate: rate)
    let generation = try core.load(
        PCMAsset(interleavedStereo: samples, sampleRate: rate), deck: .a, grid: nil, synced: false)
    try core.setEffect(PerformanceEffect.iceverb.rawValue, slot: 0, x: 0.5, y: 1, enabled: true, deck: .a)
    try core.play(deck: .a, generation: generation)
    _ = core.renderOffline(frames: 24000)
    try core.setEffect(PerformanceEffect.iceverb.rawValue, slot: 0, x: 0.5, y: 1, enabled: false, deck: .a)
    let released = core.renderOffline(frames: 480)
    let last = try #require(released.left.last)
    #expect(abs(last) > 1e-8)

    try core.setEffect(PerformanceEffect.delay.rawValue, slot: 0, x: 0.5, y: 1, enabled: false, deck: .a)
    let changed = core.renderOffline(frames: 960)
    #expect(abs(changed.left[0] - last) < abs(last) * 0.02 + 1e-7)
    #expect(changed.left[480...].allSatisfy { $0 == 0 })
    #expect(changed.right[480...].allSatisfy { $0 == 0 })

    try core.setEffect(PerformanceEffect.iceverb.rawValue, slot: 0, x: 0.5, y: 1, enabled: true, deck: .a)
    let restarted = core.renderOffline(frames: 4800)
    #expect(restarted.left.allSatisfy { $0 == 0 })
    #expect(restarted.right.allSatisfy { $0 == 0 })
    #expect(core.acknowledgements().allSatisfy { $0.error == nil })
}

@Test func delayAddsEchoesToAnUntouchedDryTrack() throws {
    func render(_ position: Double?) throws -> [Float] {
        var samples = [Float](repeating: 0, count: 24000)
        samples[800 * 2] = 0.5
        samples[800 * 2 + 1] = -0.5
        let core = try SampleTransport(sampleRate: 8000)
        let generation = try core.load(
            PCMAsset(interleavedStereo: samples, sampleRate: 8000), deck: .a, grid: nil, synced: false)
        if let position {
            try core.setEffect(PerformanceEffect.delay.rawValue, slot: 0, x: position, y: 1, enabled: true, deck: .a)
        }
        try core.play(deck: .a, generation: generation)
        return core.renderOffline(frames: 8000).left
    }
    let dry = try render(nil)
    for (position, delay) in [(0.0, 1000), (0.25, 2000)] {
        let audio = try render(position)
        // Full Y leaves the dry track at 100 % until the first echo arrives.
        #expect(audio[..<(800 + delay)] == dry[..<(800 + delay)])
        let pulse = dry[800]
        let firstEcho = audio[800 + delay]
        let secondEcho = audio[800 + delay * 2]
        #expect(abs(pulse) > 0.1)
        #expect(abs(firstEcho / pulse - 0.6) < 0.001)
        #expect(abs(secondEcho / firstEcho - 0.5) < 0.001)
    }
}
