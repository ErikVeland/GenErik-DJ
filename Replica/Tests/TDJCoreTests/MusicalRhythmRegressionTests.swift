import AVFoundation
import Foundation
import Testing

@testable import TDJCore

private func analyzeOffbeatRhythm(firstBeatIndex: Int, gain: Double, accented: Bool) throws -> AudioAnalysis {
    let sampleRate = 22050.0
    let frameCount = Int(sampleRate * 32)
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
    buffer.frameLength = buffer.frameCapacity
    let channels = try #require(buffer.floatChannelData)
    for channel in 0..<2 { for frame in 0..<frameCount { channels[channel][frame] = 0 } }
    func pulse(time: Double, frequency: Double, amplitude: Double, decay: Double) {
        let start = Int((time * sampleRate).rounded())
        for offset in 0..<Int((0.04 * sampleRate).rounded()) {
            let frame = start + offset
            guard frame < frameCount else { break }
            let seconds = Double(offset) / sampleRate
            let sample = Float(amplitude * exp(-seconds * decay) * cos(2 * .pi * frequency * seconds))
            channels[0][frame] += sample
            channels[1][frame] += sample
        }
    }
    for beat in 0..<64 {
        let time = Double(beat) * 0.5
        pulse(
            time: time, frequency: accented && (beat + firstBeatIndex).isMultiple(of: 4) ? 110 : 220,
            amplitude: 0.12 * gain, decay: 180)
        pulse(time: time + 0.25, frequency: 5200, amplitude: 0.35 * gain, decay: 250)
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }
    return try AudioAnalyzer.analyze(url: url)
}

@Test(arguments: [0, 1, 2, 3], [1.0, 0.1]) func strongOffbeatPercussionRetainsTheUnderlyingBeatAndBar(
    firstBeatIndex: Int, gain: Double
) throws {
    let analysis = try analyzeOffbeatRhythm(firstBeatIndex: firstBeatIndex, gain: gain, accented: true)
    let sampleRate = analysis.sampleRate
    let bpm = try #require(analysis.bpm)
    let anchor = try #require(analysis.beatAnchorFrame) / sampleRate
    #expect(abs(bpm - 120) <= 0.02)
    #expect(abs(anchor) <= 0.01)
    #expect(abs(anchor + 63 * 60 / bpm - 31.5) <= 0.02)
    #expect(analysis.detectedDownbeatOffset == (4 - firstBeatIndex) % 4)
    if let candidate = analysis.adaptiveCandidate {
        #expect(abs(candidate.frame(atBeat: 63) / sampleRate - 31.5) <= 0.02)
    }
}

@Test func identicalBeatAccentsDoNotInventABarPosition() throws {
    let analysis = try analyzeOffbeatRhythm(firstBeatIndex: 0, gain: 1, accented: false)
    #expect(abs(try #require(analysis.bpm) - 120) <= 0.02)
    #expect(analysis.detectedDownbeatOffset == nil)
    #expect(analysis.downbeatConfidence == nil)
}

@Test(arguments: [0.0, 3.25], [-1, 0, 1, 2, 3])
func driftingAudioProducesACandidateWithoutAcceptingPreparation(leadIn: Double, barOffset: Int) throws {
    let rate = 22050.0
    var time = leadIn
    var times = [Double]()
    for beat in 0..<128 {
        times.append(time)
        time += 0.5 + Double(beat) * 0.0005
    }
    let count = Int((time + 1) * rate)
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
    buffer.frameLength = buffer.frameCapacity
    let samples = try #require(buffer.floatChannelData)[0]
    for i in 0..<count { samples[i] = 0 }
    for (beat, t) in times.enumerated() {
        let start = Int(t * rate)
        for offset in 0..<700 {
            let seconds = Double(offset) / rate
            let frequency = barOffset < 0 || beat % 4 == barOffset ? 110.0 : 220.0
            samples[start + offset] += Float(0.5 * exp(-seconds * 180) * cos(2 * .pi * frequency * seconds))
        }
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    do {
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
    let analysis = try AudioAnalyzer.analyze(url: url)
    let map = try #require(analysis.adaptiveCandidate)
    for beat in [0, 32, 64, 96, 120, 127] {
        #expect(abs(map.frame(atBeat: Double(beat)) / rate - times[beat]) < 0.035)
    }
    #expect(try #require(map.anchors.last).frame / rate >= times[127] - 0.035)
    if barOffset >= 0 { #expect(map.downbeatOffset == barOffset) }
    let track = try Track(title: "Drifting clock", mediaFilename: url.lastPathComponent, analysis: analysis)
    #expect(track.preparation.adaptiveMap == nil)
    #expect(track.adaptiveMap == nil)
}
