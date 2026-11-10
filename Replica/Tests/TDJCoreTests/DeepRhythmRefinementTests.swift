import Foundation
import Testing
@testable import TDJCore

@Suite struct DeepRhythmRefinementTests {
    @Test(arguments: [0.0, 0.25, 0.5])
    func locatesThePeakBetweenFramesWithoutMovingPlateaus(_ fraction: Double) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let analysis = try syntheticTrack("refined", bpm: 120).analysis.replacingWaveform(
            [], configurationID: "test", frameCount: 1_323_000, decodedFrames: nil)
        let store = DeepAnalysisCheckpoints(root: root, analysis: analysis)
        let result = try DeepBeatAnalyzer.run(checkpoints: store, progress: { _, _ in }, checkCancellation: {}) { index, start in
            var beats = [Float](repeating: -6, count: 1500)
            var bars = beats
            for frame in 0..<1500 {
                let global = Double(start + frame)
                let beat = Int(((global - 10) / 25).rounded())
                guard (0..<60).contains(beat) else { continue }
                let delta = global - (10 + Double(beat) * 25 + fraction)
                if abs(delta) <= 1.5 {
                    beats[frame] = Float(4 - delta * delta)
                    if beat % 4 == 0 { bars[frame] = beats[frame] }
                }
            }
            return .init(index: index, start: start, beats: beats, downbeats: bars)
        }
        let map = try #require(result.adaptiveCandidate?.map)
        #expect(abs(map.frame(atBeat: 0) / analysis.sampleRate - (0.208 + fraction / 50)) < 0.000001)
        #expect(map.downbeatOffset == 0)
        #expect(abs(map.frame(atBeat: 56) / analysis.sampleRate - (28.208 + fraction / 50)) < 0.000001)
        if fraction == 0.25 {
            let payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
            let evidence = try #require(payload["rhythmEvidence"] as? [String: Any])
            let features = try #require(evidence["features"] as? [Double])
            #expect(features.count == 6)
            #expect(abs(features[0] - 3.9375) < 0.000001)
            #expect(abs(features[1] - 1) < 0.000001)
            #expect(abs(features[2] - 9.9375) < 0.000001)
            #expect(features[3] < 0.000001)
            #expect(features[4] < 0.000001)
            #expect(features[5] == 1)
        }
    }
}
