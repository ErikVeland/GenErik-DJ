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
            candidate: strong, adaptiveCandidate: map, rhythmEvidence: .init(version: 1,
                features: [9.39375, 12.4375, 13.370186941964286, 0.020109753695928653, 11.791208791211538, 1]))
        let confidence = try #require(result.rhythmConfidence)
        #expect(confidence.observations == 159)
        #expect(confidence.calibrationVersion == 2)
        #expect(confidence.successes == 76)
        #expect(abs(confidence.probability - 0.39764451975203435) < 1e-12)
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
        #expect(weak.rhythmConfidence == nil)
        var unknown = result
        unknown.rhythmEvidence = .init(version: 2, features: result.rhythmEvidence!.features)
        #expect(unknown.rhythmConfidence == nil)
        unknown.rhythmEvidence = .init(version: 1, features: [.nan, 1, 1, 0, 1, 1])
        #expect(unknown.rhythmConfidence == nil)
        var oldProfile = DeepAnalysisProfile.current
        oldProfile.rhythmCalibrationVersion = nil
        let old = DeepBeatAnalysis(audio: result.audio, profile: oldProfile, coveredFrames: result.coveredFrames,
            windowCount: result.windowCount, candidate: strong, adaptiveCandidate: map, rhythmEvidence: result.rhythmEvidence)
        #expect(old.rhythmConfidence == nil)
        #expect(old.profile.id != result.profile.id)
        #expect(old.profile.inferenceID == result.profile.inferenceID)
    }
}
