import Foundation
import Testing

@testable import TDJCore

/// Four-on-the-floor kick with a short click and offbeat hats, 120 BPM at 44.1 kHz.
private func kickPattern(seconds: Double = 8) -> [Float] {
    let rate = 44100.0
    let frames = Int(seconds * rate)
    let beat = rate / 2
    var noise: UInt32 = 0x9e37_79b9
    return (0..<frames).flatMap { frame -> [Float] in
        let inBeat = Double(frame).truncatingRemainder(dividingBy: beat) / rate
        let offbeat = (Double(frame) + beat / 2).truncatingRemainder(dividingBy: beat) / rate
        noise = noise &* 1_664_525 &+ 1_013_904_223
        let white = Double(Int32(bitPattern: noise)) / Double(Int32.max)
        let kick = sin(2 * .pi * 55 * inBeat * (1 + 2 * exp(-inBeat / 0.02))) * exp(-inBeat / 0.12)
        let click = inBeat < 0.003 ? white * 0.6 : 0
        let hat = white * 0.25 * exp(-offbeat / 0.015)
        let value = Float(0.8 * kick + click + hat)
        return [value, value]
    }
}

private func longestFlatRun(_ heights: [Double]) -> Int {
    var longest = 0
    var run = 1
    for index in 1..<heights.count {
        if heights[index] > 1, abs(heights[index] - heights[index - 1]) < 1e-9 { run += 1 } else { run = 1 }
        longest = max(longest, run)
    }
    return longest
}

@Test func kickPatternDrawsSmoothEdgesAtDeckZoom() throws {
    let samples = kickPattern()
    let waveform = try samples.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    #expect(waveform.levels.count == 4 && waveform.levels[0].count == (samples.count / 2 + 63) / 64)
    // Deck zoom: five beats across a 900-point waveform on a 2x display.
    let span = WaveformLayers.defaultSeconds(bpm: 120) * 44100
    let columns = BandWaveformColumns(waveform, left: 44100, span: span, pixelWidth: 1800, height: 400)
    for heights in [columns.low, columns.mid, columns.high] { #expect(longestFlatRun(heights) <= 2) }
    // Lows form the broad kick body; transients reach the high layer at each beat.
    #expect(columns.low.max()! > 150)
    let beatPixels = (0..<5).map { Int((Double($0) * 22050) / (span / 1800)) }
    #expect(
        beatPixels.allSatisfy { pixel in (max(0, pixel - 6)..<min(1800, pixel + 12)).contains { columns.high[$0] > 20 }
        })
    // Between kicks the body falls away again: real shapes, not a solid block.
    #expect(columns.low.min()! < columns.low.max()! * 0.25)
}

@Test func bandWaveformSummariesKeepPeaksAtEveryLevel() throws {
    let samples = kickPattern(seconds: 4)
    let waveform = try samples.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    let peaks = waveform.levels.map { level in level.map(\.low).max()! }
    #expect(peaks.allSatisfy { abs($0 - peaks[0]) < 1e-6 })
    // The overview strip reads a coarse level: one value per pixel across the whole track.
    let overview = BandWaveformColumns(
        waveform, left: 0, span: Double(waveform.frameCount), pixelWidth: 1600, height: 60)
    #expect(overview.low.allSatisfy { $0 > 0 } && overview.low.count == 1600)
}

@Test func bandWaveformRetainsOutOfPhaseStereoTransients() throws {
    let mono = kickPattern(seconds: 2)
    var opposite = mono
    for frame in 0..<(opposite.count / 2) { opposite[2 * frame + 1] = -opposite[2 * frame + 1] }
    let reference = try mono.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    let stereo = try opposite.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    #expect(stereo.maximum == reference.maximum)
    #expect(stereo.levels == reference.levels)
    let span = Double(reference.frameCount)
    for width in [900, 1800, 2700] {
        let expected = BandWaveformColumns(reference, left: 0, span: span, pixelWidth: width, height: 240)
        let actual = BandWaveformColumns(stereo, left: 0, span: span, pixelWidth: width, height: 240)
        #expect(actual.low == expected.low)
        #expect(actual.mid == expected.mid)
        #expect(actual.high == expected.high)
    }
}

@Test func bandWaveformKeepsEitherChannelAndIgnoresChannelOrder() throws {
    let mono = kickPattern(seconds: 2)
    var left = mono
    var right = mono
    for frame in 0..<(mono.count / 2) {
        left[2 * frame + 1] = 0
        right[2 * frame] = 0
    }
    let reference = try mono.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    let leftOnly = try left.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    let rightOnly = try right.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    #expect(leftOnly.maximum == reference.maximum)
    #expect(rightOnly.maximum == reference.maximum)
    #expect(leftOnly.levels == reference.levels)
    #expect(rightOnly.levels == reference.levels)
}

@Test func bandWaveformRetainsBothDistinctStereoBands() throws {
    let frames = 44100
    var stereo = [Float](repeating: 0, count: frames * 2)
    var swapped = stereo
    for frame in 0..<frames {
        let low = Float(0.6 * sin(2 * .pi * 60 * Double(frame) / 44100))
        let high = Float(0.2 * sin(2 * .pi * 8000 * Double(frame) / 44100))
        stereo[2 * frame] = low
        stereo[2 * frame + 1] = high
        swapped[2 * frame] = high
        swapped[2 * frame + 1] = low
    }
    let original = try stereo.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    let reversed = try swapped.withUnsafeBufferPointer { try BandWaveform(interleavedStereo: $0, sampleRate: 44100) }
    #expect(original.levels == reversed.levels)
    #expect(original.maximum.low > 0.5)
    #expect(original.maximum.high > 0.15)
    let silence = try [Float](repeating: 0, count: frames * 2).withUnsafeBufferPointer {
        try BandWaveform(interleavedStereo: $0, sampleRate: 44100)
    }
    #expect(silence.maximum == .init())
}

@Test func waveformContrastSeparatesKickAndSnareWithoutDimmingTheirAttacks() throws {
    var bins = [BandWaveform.Bin](repeating: .init(low: 0.2, mid: 0.15, high: 0.05), count: 40)
    bins[15].low = 1
    bins[25].mid = 1
    bins[25].high = 1
    let original = bins
    try BandWaveform.emphasiseAttacks(in: &bins, maximum: .init(low: 1, mid: 1, high: 1), sampleRate: 6400)
    #expect(bins[15] == original[15])
    #expect(bins[25] == original[25])
    #expect(bins[12].low > bins[13].low && bins[13].low > bins[14].low)
    #expect(bins[14].low < original[14].low)
    #expect(bins[14].mid == original[14].mid && bins[14].high == original[14].high)
    #expect(bins[24].mid < original[24].mid && bins[24].high < original[24].high)
    #expect(bins[24].low == original[24].low)
    #expect(bins[16] == original[16] && bins[26] == original[26])
}

@Test func waveformContrastLeavesSustainAndClearGapsIntact() throws {
    var sustained = [BandWaveform.Bin](repeating: .init(low: 0.8, mid: 0.5, high: 0.3), count: 100)
    let original = sustained
    try BandWaveform.emphasiseAttacks(
        in: &sustained, maximum: .init(low: 0.8, mid: 0.5, high: 0.3), sampleRate: 6400)
    #expect(sustained == original)
    var isolated = [BandWaveform.Bin](repeating: .init(), count: 100)
    isolated[20] = .init(low: 1, mid: 1, high: 1)
    let clearGaps = isolated
    try BandWaveform.emphasiseAttacks(in: &isolated, maximum: .init(low: 1, mid: 1, high: 1), sampleRate: 6400)
    #expect(isolated == clearGaps)
}

@Test func waveformContrastProtectsTheWholeRisingAttack() throws {
    var bins = [BandWaveform.Bin](repeating: .init(low: 0.2), count: 40)
    bins[13].low = 0.3
    bins[14].low = 0.8
    bins[15].low = 1
    let original = bins
    try BandWaveform.emphasiseAttacks(in: &bins, maximum: .init(low: 1), sampleRate: 6400)
    #expect(bins[13...15].elementsEqual(original[13...15]))
    #expect(bins[12].low < original[12].low)
}

@Test func waveformContrastPreservesAnAttackAtTheFileStart() throws {
    var bins = [BandWaveform.Bin](repeating: .init(low: 0.2), count: 40)
    bins[0].low = 0.1
    bins[1].low = 0.8
    bins[2].low = 1
    let original = bins
    try BandWaveform.emphasiseAttacks(in: &bins, maximum: .init(low: 1), sampleRate: 6400)
    #expect(bins[0...2].elementsEqual(original[0...2]))
}

@Test func waveformContrastKeepsItsTimingAcrossSampleRates() throws {
    for rate in [44100.0, 48000, 96000] {
        let hit = Int(rate * 0.25 / 64)
        var bins = [BandWaveform.Bin](repeating: .init(low: 0.2), count: hit * 2)
        bins[hit].low = 1
        try BandWaveform.emphasiseAttacks(in: &bins, maximum: .init(low: 1), sampleRate: rate)
        let faded = bins.indices.filter { $0 != hit && bins[$0].low < 0.2 }
        #expect(!faded.isEmpty && faded.allSatisfy { $0 < hit })
        #expect(faded.allSatisfy { Double(hit - $0) * 64 / rate <= 0.03 })
        #expect(bins[hit].low == 1)
    }
}

@Test func waveformContrastRemainsCancellable() throws {
    var bins = [BandWaveform.Bin](repeating: .init(low: 0.2), count: 1024)
    var checks = 0
    var cancelled = false
    do {
        try BandWaveform.emphasiseAttacks(in: &bins, maximum: .init(low: 1), sampleRate: 44100) {
            checks += 1
            if checks == 2 { throw CancellationError() }
        }
    } catch is CancellationError { cancelled = true }
    #expect(cancelled)
}
