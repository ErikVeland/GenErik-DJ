import Testing

@testable import TDJCore

@Test func openingBarSurvivesALaterHalfBarModelFlip() throws {
    let beats = (0..<160).map { 0.6 + Double($0) * 0.5 }
    var logits = [Float](repeating: -8, count: 4100)
    for (index, time) in beats.enumerated() {
        if index % 4 == 0 { logits[Int((time * 50).rounded())] = index < 16 ? 6 : 1 }
        if index % 4 == 2 { logits[Int((time * 50).rounded())] = index < 16 ? 1 : 8 }
    }
    let wrong = BeatThisGrid(bpm: 120, firstBar: 1.6, beatAgreement: 1, barAgreement: 0.9,
                             residualMilliseconds: 4)
    let fixed = try #require(BeatThisOpeningBar.correct(wrong, beats: beats, barLogits: logits))
    #expect(abs(fixed.firstBar - 0.6) < 1e-9)
    #expect(fixed.bpm == wrong.bpm)
    #expect(fixed.barAgreement < 0.72)
    logits[Int((4.6 * 50).rounded())] = -8
    #expect(BeatThisOpeningBar.correct(wrong, beats: beats, barLogits: logits) == nil)
}

@Test func openingBarDoesNotExtrapolateAcrossMissingOpeningBeats() {
    let wrong = BeatThisGrid(bpm: 120, firstBar: 1.6, beatAgreement: 0.99, barAgreement: 0.95,
                             residualMilliseconds: 5)
    let beats = [0.6, 1.1, 2.6, 3.1, 4.6]
    #expect(BeatThisOpeningBar.correct(wrong, beats: beats, barLogits: Array(repeating: 8, count: 4000)) == nil)
}

@Test func openingConflictRemovesOnlyThePreviousAutomaticReviewProposal() throws {
    var track = try syntheticTrack("a", bpm: 120)
    let current = DeepAnalysisProfile.current
    let old = DeepAnalysisProfile(generation: current.generation - 1, model: current.model,
        weightsSHA256: current.weightsSHA256, conversion: current.conversion, preprocessing: current.preprocessing,
        decisionPolicy: current.decisionPolicy - 1, upgradeBenefit: "Earlier bar decision")
    let previous = DeepBeatAnalysis(audio: .init(track.analysis), profile: old,
        coveredFrames: track.analysis.frameCount, windowCount: 1,
        candidate: .init(.init(bpm: 120, firstBar: 1, beatAgreement: 1, barAgreement: 0.95, residualMilliseconds: 5)))
    track.analysis.deepBeatAnalysis = previous
    track.analysis.adaptiveCandidate = previous.fixedReviewCandidate
    let corrected = DeepBeatAnalysis(audio: .init(track.analysis), profile: current,
        coveredFrames: track.analysis.frameCount, windowCount: 1,
        candidate: .init(.init(bpm: 120, firstBar: 0, beatAgreement: 1, barAgreement: 0.69,
                              residualMilliseconds: 5, openingPhaseCorrected: true)))
    #expect(try track.adoptingDeepAnalysis(corrected).analysis.adaptiveCandidate == nil)
    track.preparation.gridWasEditedByUser = true
    #expect(try track.adoptingDeepAnalysis(corrected).analysis.adaptiveCandidate == previous.fixedReviewCandidate)
}
