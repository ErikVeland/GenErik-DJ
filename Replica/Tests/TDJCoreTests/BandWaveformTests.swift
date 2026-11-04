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
