import Foundation
import Testing
@testable import TDJCore

@Suite struct DeepRhythmConfidenceTests {
    @Test func reportsMeasuredReliabilityInsteadOfModelAgreement() throws {
        let analysis = try syntheticTrack("confidence", bpm: 120).analysis.replacingWaveform(
            [], configurationID: "test", frameCount: 1_323_000, decodedFrames: nil)
        let beats = (0..<60).map { 0.1 + Double($0) * 0.5 }
        let bars = beats.enumerated().compactMap { $0.offset % 4 == 0 ? $0.element : nil }
        let fitted = try DeepAdaptiveBeatCandidate.fit(beats: beats, bars: bars,
            sampleRate: analysis.sampleRate, frameCount: analysis.frameCount, checkCancellation: {})
        let map = try #require(fitted)
        let strong = DeepBeatCandidate(.init(bpm: 120, firstBar: 0.1, beatAgreement: 1,
                                            barAgreement: 1, residualMilliseconds: 0))
        let result = DeepBeatAnalysis(audio: .init(analysis), profile: .current, coveredFrames: analysis.frameCount,
            windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(analysis)).count,
            candidate: strong, adaptiveCandidate: map)
        let confidence = try #require(result.rhythmConfidence)
        #expect(confidence.observations == 43)
        #expect(confidence.successes == 26)
        #expect(confidence.probability == 27.0 / 45)
        #expect(result.needsReview)
        let track = try Track(title: "Confidence", mediaFilename: "confidence.wav", analysis: analysis)
        let updated = try track.adoptingDeepAnalysis(result)
        #expect(updated.analysis.adaptiveConfidence == confidence.probability)
        #expect(analysis.retainingDeepEvidence(from: updated.analysis).adaptiveConfidence == confidence.probability)
        let long = DeepBeatAnalysis(audio: .init(try syntheticTrack("long", bpm: 120).analysis.replacingWaveform(
            [], configurationID: "test", frameCount: 4_410_000, decodedFrames: nil)), profile: .current,
            coveredFrames: 4_410_000, windowCount: 4, candidate: strong, adaptiveCandidate: map)
        #expect(long.rhythmConfidence == nil)
        let weak = DeepBeatAnalysis(audio: result.audio, profile: .current, coveredFrames: result.coveredFrames,
            windowCount: result.windowCount, candidate: nil, adaptiveCandidate: map)
        #expect(weak.rhythmConfidence?.probability == 1.0 / 11)
    }
}
