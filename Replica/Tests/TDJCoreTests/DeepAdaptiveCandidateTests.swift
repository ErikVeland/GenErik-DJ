import Foundation
import Testing

@testable import TDJCore

@Suite struct DeepAdaptiveCandidateTests {
    let rate = 48_000.0
    var beats: [Double] {
        (0..<80).map { index in
            let beat = Double(index)
            return 0.1 + beat * 0.5 + beat * beat * 0.0004
        }
    }
    var bars: [Double] { beats.enumerated().compactMap { $0.offset % 4 == 2 ? $0.element : nil } }

    @Test func retainsTheWholeDriftingTimelineAndBarPosition() throws {
        let fitted = try DeepAdaptiveBeatCandidate.fit(
            beats: beats, bars: bars, sampleRate: rate, frameCount: 2_400_000, checkCancellation: {})
        let result = try #require(fitted)
        #expect(result.map.downbeatOffset == 2)
        #expect(result.map.anchors.first?.beat == 0)
        #expect(result.map.anchors.last?.beat == 79)
        #expect(result.map.anchors.count <= 256)
        for (index, time) in beats.enumerated() {
            #expect(abs(result.map.frame(atBeat: Double(index)) / rate - time) <= 0.008001)
        }
        #expect(result.compressionErrorMilliseconds <= 8.001)
        #expect(try JSONDecoder().decode(DeepAdaptiveBeatCandidate.self, from: JSONEncoder().encode(result)) == result)
    }

    @Test func rejectsAnUnsupportedBarLengthAndMissingBeats() throws {
        let triple = beats.enumerated().compactMap { $0.offset % 3 == 0 ? $0.element : nil }
        let tripleResult = try DeepAdaptiveBeatCandidate.fit(
            beats: beats, bars: triple, sampleRate: rate, frameCount: 2_400_000, checkCancellation: {})
        #expect(tripleResult == nil)
        var missing = beats
        missing.remove(at: 40)
        let missingResult = try DeepAdaptiveBeatCandidate.fit(
            beats: missing, bars: bars, sampleRate: rate, frameCount: 2_400_000, checkCancellation: {})
        #expect(missingResult == nil)
    }

    @Test func doesNotTruncateASequenceToFitTheAnchorLimit() throws {
        let irregular = (0..<600).map { Double($0) * 0.5 + ($0 % 2 == 0 ? 0.02 : 0) }
        let bars = irregular.enumerated().compactMap { $0.offset % 4 == 0 ? $0.element : nil }
        let result = try DeepAdaptiveBeatCandidate.fit(
            beats: irregular, bars: bars, sampleRate: rate, frameCount: 15_000_000, checkCancellation: {})
        #expect(result == nil)
    }

    @Test func cancellationStopsTimelineConstruction() {
        #expect(throws: CancellationError.self) {
            try DeepAdaptiveBeatCandidate.fit(
                beats: beats, bars: bars, sampleRate: rate, frameCount: 2_400_000,
                checkCancellation: { throw CancellationError() })
        }
    }

    @Test(arguments: [false, true])
    func sharesAReviewCandidateWithoutChangingPlaybackPreparation(weakConstantFit: Bool) throws {
        let analysis = try syntheticTrack("a", bpm: 120).analysis.replacingWaveform(
            [], configurationID: "test", frameCount: 4_410_000, decodedFrames: nil)
        let track = try Track(title: "Review", mediaFilename: "review.wav", analysis: analysis)
        let fitted = try DeepAdaptiveBeatCandidate.fit(
            beats: beats, bars: bars, sampleRate: analysis.sampleRate,
            frameCount: analysis.frameCount, checkCancellation: {})
        let candidate = try #require(fitted)
        let result = DeepBeatAnalysis(
            audio: .init(analysis), profile: .current, coveredFrames: analysis.frameCount,
            windowCount: BeatThisWindows.starts(frameCount: BeatThisWindows.frameCount(analysis)).count,
            candidate: weakConstantFit ? DeepBeatCandidate(.init(
                bpm: 120, firstBar: 0.1, beatAgreement: 0.85, barAgreement: 0.95,
                residualMilliseconds: 30)) : nil, adaptiveCandidate: candidate)
        let updated = try track.adoptingDeepAnalysis(result)
        #expect(updated.preparation == track.preparation)
        #expect(updated.analysis.adaptiveCandidate == candidate.map)
        #expect(updated.analysis.adaptiveConfidence == nil)
        #expect(updated.analysis.acceptedDeepBeatAnalysis == nil)
        let refreshed = analysis.retainingDeepEvidence(from: updated.analysis)
        #expect(refreshed.adaptiveCandidate == candidate.map)
        #expect(refreshed.adaptiveConfidence == nil)
        let differentAudio = try syntheticTrack("different", bpm: 100).analysis
        #expect(differentAudio.retainingDeepEvidence(from: updated.analysis) == differentAudio)
        #expect(try updated.adoptingDeepAnalysis(result) == updated)
        let archive = CloudPreparationArchive.analysisOnly(track: updated, arrangement: nil)
        #expect(try archive.automaticallyMergedTrack(matching: track).analysis.adaptiveCandidate == candidate.map)
        var protected = track
        protected.preparation.gridWasEditedByUser = true
        let retained = try protected.adoptingDeepAnalysis(result)
        #expect(retained.preparation == protected.preparation)
        #expect(retained.analysis.adaptiveCandidate == nil)
        var existing = track
        existing.analysis.adaptiveCandidate = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 88_200)], sampleRate: analysis.sampleRate)
        #expect(try existing.adoptingDeepAnalysis(result).analysis.adaptiveCandidate == existing.analysis.adaptiveCandidate)
    }

    @Test func explicitAcceptanceCanResolveAMissingGrid() throws {
        let fitted = try DeepAdaptiveBeatCandidate.fit(
            beats: beats, bars: bars, sampleRate: rate, frameCount: 2_400_000, checkCancellation: {})
        let candidate = try #require(fitted)
        var preparation = Preparation()
        preparation.correctedKey = .init(tonic: 5, mode: .minor)
        try preparation.acceptAdaptive(candidate.map, frameCount: 2_400_000)
        #expect(preparation.adaptiveMap == candidate.map)
        #expect(preparation.grid?.sampleRate == rate)
        #expect(preparation.grid?.anchorFrame == candidate.map.frame(atBeat: 0))
        #expect(preparation.grid?.downbeatOffset == 2)
        #expect(preparation.correctedKey == .init(tonic: 5, mode: .minor))
        var locked = Preparation()
        locked.gridLocked = true
        #expect(throws: CoreError.invalidGrid) {
            try locked.acceptAdaptive(candidate.map, frameCount: 2_400_000)
        }
        #expect(locked.grid == nil && locked.adaptiveMap == nil)
    }
}
