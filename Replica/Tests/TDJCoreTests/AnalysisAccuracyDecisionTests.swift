import Foundation
import Testing

@testable import TDJCore

@Test func openingBarTimingWobbleDoesNotDiscardTheSupportedGrid() throws {
    let beats = (0..<240).map { 0.25 + Double($0) * 0.6 }
    var bars = stride(from: 0, to: beats.count, by: 4).map { beats[$0] }
    bars[0] -= 0.10
    bars[1] -= 0.06
    bars[2] -= 0.03
    let fitted = try BeatThisGrid.fit(
        beats: beats, bars: bars, configuration: .init(), requireOpeningBar: true, checkCancellation: {})
    let grid = try #require(fitted)
    #expect(abs(grid.bpm - 100) < 0.02)
    #expect(abs(grid.firstBar - 0.25) < 0.01)
}

@Test func openingBarToleranceDoesNotAcceptAHalfBeatDisplacement() throws {
    let beats = (0..<240).map { 0.25 + Double($0) * 0.6 }
    var bars = stride(from: 0, to: beats.count, by: 4).map { beats[$0] }
    for index in 0..<4 { bars[index] += 0.3 }
    #expect(try BeatThisGrid.fit(
        beats: beats, bars: bars, configuration: .init(), requireOpeningBar: true, checkCancellation: {}) == nil)
}

@Test func repeatedTonalSectionsCanSupportABorderlineWholeTrackKey() {
    let key = MusicalKey(tonic: 1, mode: .major)
    let relative = MusicalKey(tonic: 10, mode: .minor)
    let ranking: [MusicalKeyEstimator.Candidate] = [.init(key: key, score: 0.43), .init(key: relative, score: 0.37)]
    let sections = [key, key, key, key, relative, relative]
    #expect(MusicalKeyEstimator.select(ranking: ranking, localKeys: sections).key == key)
    #expect(MusicalKeyEstimator.select(ranking: ranking, localKeys: [key]).key == nil)
    #expect(MusicalKeyEstimator.select(ranking: ranking, localKeys: sections.reversed()).key == key)
    #expect(MusicalKeyEstimator.select(ranking: ranking, localKeys: [key, relative, relative, relative]).key == nil)
    let uncertain: [MusicalKeyEstimator.Candidate] = [.init(key: key, score: 0.43), .init(key: relative, score: 0.42)]
    #expect(MusicalKeyEstimator.select(ranking: uncertain, localKeys: sections).key == nil)
}

@Test func tempoOctaveUsesRepeatedBeatSpacingWithoutInventingABar() throws {
    var beats: [Double] = []
    for index in 0..<240 {
        let time = 0.2 + Double(index) * 0.75
        beats.append(time)
        if index.isMultiple(of: 7) { beats.append(time + 0.375) }
    }
    let adjusted = try BeatThisTempo.refine(fallbackBPM: 160, beats: beats.sorted(), configuration: .init())
    #expect(adjusted == 80)
    let fast = (0..<480).map { 0.2 + Double($0) * 0.375 }
    #expect(try BeatThisTempo.refine(fallbackBPM: 160, beats: fast, configuration: .init()) == nil)
    #expect(try BeatThisTempo.refine(fallbackBPM: 80, beats: fast, configuration: .init()) == 160)
    #expect(try BeatThisTempo.refine(fallbackBPM: 160, beats: Array(beats.prefix(20)), configuration: .init()) == nil)
}

@Test func tempoOctaveRetainsAmbiguousOrLocallyChangingEvidence() throws {
    var beats: [Double] = []
    for section in 0..<6 {
        let period = section.isMultiple(of: 2) ? 0.75 : 0.375
        for index in 0..<Int(30 / period) { beats.append(Double(section * 30) + Double(index) * period) }
    }
    #expect(try BeatThisTempo.refine(fallbackBPM: 160, beats: beats, configuration: .init()) == nil)
    #expect(throws: CancellationError.self) {
        try BeatThisTempo.refine(fallbackBPM: 160, beats: beats, configuration: .init(), checkCancellation: {
            throw CancellationError()
        })
    }
}

@Test(arguments: [70.0, 85.0, 95.0])
func tempoOctaveDecisionFollowsSpacingAcrossTempos(_ bpm: Double) throws {
    let beats = (0..<240).map { 0.17 + Double($0) * 60 / bpm }
    #expect(try BeatThisTempo.refine(fallbackBPM: bpm * 2, beats: beats, configuration: .init()) == bpm)
    #expect(try BeatThisTempo.refine(fallbackBPM: bpm, beats: beats, configuration: .init()) == nil)
}

@Test func tempoOctaveUpgradeIsSelectiveAndProtectsManualPreparation() throws {
    var track = try syntheticTrack("a", bpm: 160)
    track.analysis.implementation = "Beat This small0 with DSP grid fallback"
    track.analysis.beatModelVersion = "BeatThis/small0-6074be2c-mel1-fit1"
    #expect(track.needsCurrentLibraryAnalysis)
    track.preparation.gridIsManual = true
    #expect(!track.needsCurrentLibraryAnalysis)
    track.preparation.gridIsManual = false
    track.preparation.gridLocked = true
    #expect(!track.needsCurrentLibraryAnalysis)
    track.preparation.gridLocked = false
    track.preparation.gridWasEditedByUser = true
    #expect(!track.needsCurrentLibraryAnalysis)
    track.preparation.gridWasEditedByUser = false
    track.analysis.beatModelVersion = "BeatThis/small0-6074be2c-mel1-fit2"
    #expect(!track.needsCurrentLibraryAnalysis)
    track.analysis.beatModelVersion = "BeatThis/small0-6074be2c-mel1-fit1"
    track.analysis.implementation = "Beat This small0 fitted grid"
    #expect(!track.needsCurrentLibraryAnalysis)
}

@Test func uncertainIndependentKeyRequestsReviewWithoutOverridingAuthority() throws {
    let key = MusicalKey(tonic: 2, mode: .major)
    let analysis = AudioAnalysis(
        implementation: "test", configurationID: "test", contentSHA256: String(repeating: "a", count: 64),
        sampleRate: 44100, frameCount: 441000, channelCount: 2, waveformFramesPerBin: 441, waveform: [],
        bpm: 120, beatAnchorFrame: 0, tempoConfidence: 1, key: key, keyConfidence: 0.15, chroma: [], timbre: [])
    var track = try Track(title: "Key confidence fixture", mediaFilename: "fixture.wav", analysis: analysis)
    #expect(track.keyDecision.needsReview)
    track.preparation.importKey(key, authority: .traktor)
    #expect(!track.keyDecision.needsReview)
    track.preparation.correctedKey = key
    #expect(track.keyDecision.authority == .manual)
    #expect(!track.keyDecision.needsReview)
}
