import Foundation
import Testing

@testable import TDJCore

@Test func guidedPhaseRequiresSustainedAgreementAcrossBands() throws {
    let frames = (0..<24000).map { index -> MusicalPulseFrame in
        let time = Double(index) / 200
        let pulse = abs((time - 0.55).remainder(dividingBy: 0.75)) < 0.002 ? 1.0 : 0.0
        return .init(rms: pulse, bass: pulse, middle: pulse, high: pulse,
                     attackFrame: time * 44100, rise: pulse)
    }
    let measured = try MusicalRhythmAnalyzer.guidedPhase(
        frames: frames, sampleRate: 44100, framesPerBin: 220.5, bpm: 80.02, checkCancellation: {})
    let result = try #require(measured)
    #expect(abs(result.bpm - 80) < 0.01)
    #expect(abs(result.anchorSeconds - 0.55) < 0.005)
    let isolated = frames.map {
        MusicalPulseFrame(rms: 0, bass: 0, middle: 0, high: $0.high, attackFrame: $0.attackFrame, rise: $0.rise)
    }
    #expect(try MusicalRhythmAnalyzer.guidedPhase(
        frames: isolated, sampleRate: 44100, framesPerBin: 220.5, bpm: 80, checkCancellation: {}) == nil)
    #expect(throws: CancellationError.self) {
        try MusicalRhythmAnalyzer.guidedPhase(
            frames: frames, sampleRate: 44100, framesPerBin: 220.5, bpm: 80,
            checkCancellation: { throw CancellationError() })
    }
}

@Test func guidedPhaseUpgradesOnlyAutomaticTempoFallbacks() throws {
    var track = try syntheticTrack("a", bpm: 160)
    track.analysis.implementation = "Beat This small0 with DSP grid fallback"
    let result = DeepBeatAnalysis(
        audio: .init(track.analysis), profile: .current, coveredFrames: track.analysis.frameCount,
        windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(track.analysis)).count,
        candidate: nil, tempoCandidateBPM: 80,
        guidedPhase: .init(bpm: 80, anchorSeconds: 0.55, residualMilliseconds: 3,
                           occupancy: 0.9, coverage: 0.95, supportingBands: 3))
    let updated = try track.adoptingDeepAnalysis(result)
    #expect(updated.bpm == 80)
    #expect(abs(try #require(updated.grid).anchorFrame / track.analysis.sampleRate - 0.55) < 1e-9)
    #expect(updated.analysis.detectedDownbeatOffset == nil)
    #expect(try updated.adoptingDeepAnalysis(result) == updated)
    let restored = try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(updated))
    #expect(restored.analysis.deepBeatAnalysis == result)
    let shared = try CloudPreparationArchive.analysisOnly(track: updated, arrangement: nil)
        .automaticallyMergedTrack(matching: track)
    #expect(shared.grid == updated.grid)
    var older = updated
    var profile = DeepAnalysisProfile.current
    profile = .init(generation: profile.generation - 1, model: profile.model, weightsSHA256: profile.weightsSHA256,
                    conversion: profile.conversion, preprocessing: profile.preprocessing,
                    decisionPolicy: profile.decisionPolicy - 1, upgradeBenefit: "Earlier tempo decision")
    let oldResult = DeepBeatAnalysis(audio: result.audio, profile: profile, coveredFrames: result.coveredFrames,
                                    windowCount: result.windowCount, candidate: nil, tempoCandidateBPM: 80)
    older.analysis.deepBeatAnalysis = oldResult
    older.analysis.acceptedDeepBeatAnalysis = oldResult
    older.analysis.implementation = "BeatThis/final0 tempo octave with DSP beat phase"
    older.preparation.grid = try BeatGrid(bpm: 80, anchorFrame: 0.38 * track.analysis.sampleRate,
                                         sampleRate: track.analysis.sampleRate)
    #expect(try older.adoptingDeepAnalysis(result).grid == updated.grid)
    let previous = older
    let sharedUpgrade = try CloudPreparationArchive.analysisOnly(track: updated, arrangement: nil)
        .automaticallyMergedTrack(matching: previous)
    #expect(sharedUpgrade.grid == updated.grid)
    track.preparation.gridWasEditedByUser = true
    #expect(try track.adoptingDeepAnalysis(result).preparation == track.preparation)
    older.preparation.gridLocked = true
    #expect(try older.adoptingDeepAnalysis(result).preparation == older.preparation)
    var invalid = result
    invalid.guidedPhase = .init(bpm: 120, anchorSeconds: 0.55, residualMilliseconds: 3,
                               occupancy: 0.9, coverage: 0.95, supportingBands: 3)
    #expect(throws: (any Error).self) { try track.adoptingDeepAnalysis(invalid) }
}
