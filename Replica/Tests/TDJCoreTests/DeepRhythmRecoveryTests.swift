import Foundation
import Testing
@testable import TDJCore

@Suite struct DeepRhythmRecoveryTests {
    @Test(arguments: [false, true])
    func recoversConsistentBarsWithExtraPeaks(missingBeat: Bool) throws {
        let result = try analyze(meter: 4, weakExtraBars: true, missingBeat: missingBeat)
        let candidate = try #require(result.adaptiveCandidate)
        #expect(candidate.observedBeatCount == 60)
        #expect(candidate.map.downbeatOffset == 2)
        #expect(abs(candidate.map.frame(atBeat: 18) / result.audio.sampleRate - 9.208) < 0.000001)
        #expect(result.rhythmConfidence == nil)
        #expect(result.rhythmEvidence == nil)
        #expect(result.needsReview)
    }

    @Test(arguments: [2, 3])
    func rejectsAmbiguousOrUnsupportedBars(_ meter: Int) throws {
        let result = try analyze(meter: meter, weakExtraBars: false, missingBeat: false)
        #expect(result.adaptiveCandidate == nil)
    }

    private func analyze(meter: Int, weakExtraBars: Bool, missingBeat: Bool) throws -> DeepBeatAnalysis {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let analysis = try syntheticTrack("recovery", bpm: 120).analysis.replacingWaveform(
            [], configurationID: "test", frameCount: 1_323_000, decodedFrames: nil)
        return try DeepBeatAnalyzer.run(checkpoints: .init(root: root, analysis: analysis),
            progress: { _, _ in }, checkCancellation: {}) { index, start in
            var beats = [Float](repeating: -6, count: 1500)
            var bars = beats
            for frame in 0..<1500 {
                let global = start + frame
                guard global >= 10, (global - 10).isMultiple(of: 25) else { continue }
                let beat = (global - 10) / 25
                guard beat < 60 else { continue }
                if !missingBeat || beat != 17 { beats[frame] = 10 }
                if beat % meter == (meter == 4 ? 2 : 0) { bars[frame] = 10 }
                else if weakExtraBars && beat.isMultiple(of: 2) { bars[frame] = 4 }
            }
            return .init(index: index, start: start, beats: beats, downbeats: bars)
        }
    }
}
