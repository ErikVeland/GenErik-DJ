import AVFoundation
import Foundation
import Testing

@testable import TDJCore

private struct AccuracyProbeInput: Decodable {
    struct Row: Decodable { let id: String; let firstPass: AudioAnalysis }
    let manifest: AnalysisBenchmarkManifest
    let rows: [Row]
}

private struct AccuracyProbeOutput: Encodable {
    struct Grid: Encodable {
        let bpm: Double
        let anchor: Double
        let barOffset: Int?
        let confidence: Double?
        let frames: [MusicalBarFrame]
    }
    struct Key: Encodable { let key: MusicalKey; let score: Double }
    let id: String
    let chroma: [Double]
    let keyRanking: [Key]
    let untunedFrameKeyVotes: [String: Int]
    let grids: [Grid]
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["GENERIK_ACCURACY_PROBE"] != nil))
func accuracyProbeChecksAudioIdentityAndExportsDecisionEvidence() throws {
    let inputURL = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["GENERIK_ACCURACY_PROBE"]))
    let outputURL = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["GENERIK_ACCURACY_OUTPUT"]))
    try #require(!FileManager.default.fileExists(atPath: outputURL.path))
    let input = try JSONDecoder().decode(AccuracyProbeInput.self, from: Data(contentsOf: inputURL))
    var output: [AccuracyProbeOutput] = []
    for row in input.rows {
        let source = try #require(input.manifest.tracks.first { $0.id == row.id })
        let url = URL(fileURLWithPath: source.path)
        let hash = try AudioAnalyzer.sha256(url: url)
        try #require(hash == source.sha256)
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let rate = file.processingFormat.sampleRate
        let channels = Int(file.processingFormat.channelCount)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 32768))
        var pulses = MusicalPulseAccumulator(sampleRate: rate)
        let spectrum = try MusicalSpectrumAnalyzer(sampleRate: rate)
        var previous = 0.0, filtered = 0.0
        let highPass = exp(-2 * .pi * 20 / rate)
        while file.framePosition < file.length {
            try file.read(into: buffer)
            let data = try #require(buffer.floatChannelData)
            let length = Int(buffer.frameLength)
            guard length > 0 else { break }
            var powers = [Double](repeating: 0, count: channels)
            var monoPower = 0.0
            for frame in 0..<length {
                var mono = 0.0
                for channel in 0..<channels {
                    let value = Double(data[channel][frame])
                    powers[channel] += value * value
                    mono += value / Double(channels)
                }
                monoPower += mono * mono
            }
            let loudest = powers.indices.max { powers[$0] < powers[$1] } ?? 0
            for frame in 0..<length {
                var sample: Float = 0
                if monoPower < powers[loudest] * 0.05 { sample = data[loudest][frame] }
                else { for channel in 0..<channels { sample += data[channel][frame] / Float(channels) } }
                let value = Double(sample)
                filtered = value - previous + highPass * filtered
                previous = value
                pulses.consume(filtered)
                spectrum.consume(filtered)
            }
        }
        pulses.finish()
        let harmonic = spectrum.finish()
        #expect(zip(harmonic.chroma, row.firstPass.chroma).allSatisfy { abs($0 - $1) < 0.000001 })
        var votes: [String: Int] = [:]
        let groups = Dictionary(grouping: spectrum.harmonicFrames, by: { Int($0.seconds / 8) })
        for frames in groups.values {
            var chroma = [Double](repeating: 0, count: 12)
            for frame in frames { for pitch in 0..<12 { chroma[pitch] += frame.chroma[pitch] } }
            let key = MusicalKeyEstimator.rank(chroma)[0].key
            votes["\(key.tonic)-\(key.mode.rawValue)", default: 0] += 1
        }
        var grids: [AccuracyProbeOutput.Grid] = []
        if let bpm = row.firstPass.bpm, let anchorFrame = row.firstPass.beatAnchorFrame {
            for tempo in [bpm / 2, bpm, bpm * 2] where (60...200).contains(tempo) {
                let frames = try MusicalRhythmAnalyzer.barFrames(
                    frames: pulses.frames, binsPerSecond: rate / Double(pulses.framesPerBin),
                    period: 60 / tempo, anchor: anchorFrame / rate,
                    harmonicFrames: spectrum.harmonicFrames, checkCancellation: {})
                let bar = try MusicalRhythmAnalyzer.barStart(beats: frames)
                grids.append(.init(bpm: tempo, anchor: anchorFrame / rate, barOffset: bar.offset,
                                   confidence: bar.confidence, frames: frames))
            }
        }
        output.append(.init(id: row.id, chroma: harmonic.chroma,
                            keyRanking: MusicalKeyEstimator.rank(harmonic.chroma).map { .init(key: $0.key, score: $0.score) },
                            untunedFrameKeyVotes: votes, grids: grids))
        try JSONEncoder().encode(output).write(to: outputURL, options: .atomic)
        print("Accuracy evidence \(row.id): keys \(votes), bar choices \(grids.map { $0.barOffset ?? -1 })")
    }
    #expect(output.count == input.rows.count)
}
