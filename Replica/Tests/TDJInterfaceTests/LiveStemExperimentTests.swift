import Foundation
import TDJCore
import Testing

@testable import TDJInterface

@Test func liveStemExperimentLoadsAndRunsBundledSpleeter() throws {
    let separator = try SpleeterVocalMask()
    var input = [Float](repeating: 0, count: 2 * SpleeterVocalMask.inputFrames)
    for frame in 0..<SpleeterVocalMask.inputFrames {
        input[2 * frame] = 0.2 * sin(Float(frame) * 0.07)
        input[2 * frame + 1] = 0.3 * sin(Float(frame) * 0.13)
    }
    let vocals = try separator.vocals(in: input)
    #expect(vocals.count == 2 * SpleeterVocalMask.outputFrames)
    #expect(vocals.allSatisfy { $0.isFinite })
    #expect(vocals.contains { abs($0) > 0.00001 })
}

@Test func liveStemExperimentPreservesBothDecksAndFallsBack() throws {
    let core = try SampleTransport(sampleRate: 44_100, outputGain: 1)
    let a = try PCMAsset(interleavedStereo: .init(repeating: 0.4, count: 44_100 * 2), sampleRate: 44_100)
    let b = try PCMAsset(interleavedStereo: .init(repeating: 0.1, count: 44_100 * 2), sampleRate: 44_100)
    let genA = try core.load(a, deck: .a, grid: nil, synced: false, keylock: false)
    let genB = try core.load(b, deck: .b, grid: nil, synced: false, keylock: false)
    try core.play(deck: .a, generation: genA)
    try core.play(deck: .b, generation: genB)
    let original = try #require(core.renderOffline(frames: 512).left.last)

    #expect(core.beginLiveVocal(deck: .a, generation: genA, first: 0, capacity: 8192))
    let waiting = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(waiting - original) < 0.001)

    let vocal = [Float](repeating: 0.1, count: 8192 * 2)
    #expect(vocal.withUnsafeBufferPointer(core.appendLiveVocal))
    let frame = try #require(core.snapshot()).a.sourceFrame
    let isolated = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(isolated / original - 0.4) < 0.01)
    #expect(try #require(core.snapshot()).a.sourceFrame == frame + 512)
    #expect(try #require(core.snapshot()).b.sourceFrame == frame + 512)

    core.setLiveVocalMode(2)
    let instrumental = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(instrumental / original - 0.8) < 0.01)
    _ = core.renderOffline(frames: 4096)
    let fallback = try #require(core.renderOffline(frames: 512).left.last)
    #expect(abs(fallback - original) < 0.001)
}
