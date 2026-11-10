import Foundation
import Testing
@testable import TDJCore

@Suite struct LearnedKeyTests {
    @Test func acceptsStrongEvidenceAndPreservesManualAndImportedKeys() throws {
        let original = try syntheticTrack("learned", bpm: 120)
        let key = MusicalKey(tonic: 3, mode: .minor)
        let learned = LearnedKeyAnalysis(profile: .current, key: key, score: 0.85, featureFrames: Int(original.analysis.duration * 5) - 1)
        let result = DeepBeatAnalysis(
            audio: .init(original.analysis), profile: .current, coveredFrames: original.analysis.frameCount,
            windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(original.analysis)).count,
            candidate: nil, learnedKey: learned)
        let updated = try original.adoptingDeepAnalysis(result)
        #expect(updated.key == key)
        #expect(updated.analysis.keyConfidence == 39.0 / 40)
        #expect(updated.preparation == original.preparation)
        #expect(updated.keyGovernance?.events.count == 2)
        let refreshed = original.analysis.retainingDeepEvidence(from: updated.analysis)
        #expect(refreshed.key == key)
        let shared = CloudPreparationArchive.analysisOnly(track: updated, arrangement: nil)
        #expect(try shared.automaticallyMergedTrack(matching: original).key == key)
        var manual = original
        manual.preparation.correctedKey = .init(tonic: 9, mode: .major)
        #expect(try manual.adoptingDeepAnalysis(result).key == manual.key)
        var imported = original
        imported.preparation.importKey(.init(tonic: 6, mode: .major), authority: .traktor)
        #expect(try imported.adoptingDeepAnalysis(result).key == imported.key)
    }

    @Test func uncertainAndUnknownModelsCannotReplaceKeys() throws {
        let original = try syntheticTrack("learned-low", bpm: 120)
        let learned = LearnedKeyAnalysis(profile: .current, key: .init(tonic: 3, mode: .minor),
                                         score: 0.79, featureFrames: Int(original.analysis.duration * 5) - 1)
        let result = DeepBeatAnalysis(
            audio: .init(original.analysis), profile: .current, coveredFrames: original.analysis.frameCount,
            windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(original.analysis)).count,
            candidate: nil, learnedKey: learned)
        let updated = try original.adoptingDeepAnalysis(result)
        #expect(updated.key == original.key)
        #expect(updated.analysis.deepBeatAnalysis?.learnedKey == learned)
        #expect(learned.calibratedConfidence == 35.0 / 41)
        let invalid = LearnedKeyAnalysis(profile: .current, key: learned.key, score: .nan, featureFrames: 100)
        #expect(throws: CoreError.self) { try invalid.validate() }
    }
}
