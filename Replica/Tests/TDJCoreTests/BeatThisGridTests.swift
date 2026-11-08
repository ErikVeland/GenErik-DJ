import Testing

@testable import TDJCore

@Test func beatThisGridFitsBarPhaseDespiteExtraSubdivisionPeaks() throws {
    let period = 60.0 / 71
    let phase = 2.58
    var beats: [Double] = []
    var bars: [Double] = []
    for index in 0..<192 {
        let time = phase + Double(index) * period
        let observed = (time * 50).rounded() / 50
        beats.append(observed)
        if index.isMultiple(of: 3) { beats.append(observed + period / 2) }
        if index.isMultiple(of: 4) { bars.append(observed) }
        if index.isMultiple(of: 17) { bars.append(observed + period) }
    }
    let fitted = try BeatThisGrid.fit(
        beats: beats.sorted(), bars: bars.sorted(), configuration: .init(), checkCancellation: {})
    let grid = try #require(fitted)
    #expect(abs(grid.bpm - 71) < 0.02)
    #expect(abs(grid.firstBar - phase) < 0.02)
    #expect(grid.beatAgreement >= 0.72)
    #expect(grid.barAgreement >= 0.75)
}

@Test func beatThisLimitsOnlyLongMixesToTheOpening() {
    let rate = 44100.0
    let threshold = Int64(NativeAnalysisPlan.mixThresholdSeconds * rate)
    #expect(BeatThisAnalyzer.sourceFrameLimit(threshold, sampleRate: rate) == threshold)
    #expect(BeatThisAnalyzer.sourceFrameLimit(threshold + 1, sampleRate: rate) == 90 * 44100)
}

@Test func longMixGridUsesTheFirstSupportedDownbeatAfterTheIntro() throws {
    let beats = (0..<136).map { 12.38 + Double($0) * 0.5 }
    let bars = stride(from: 0, to: beats.count, by: 4).map { beats[$0] }
    let fitted = try BeatThisGrid.fit(
        beats: beats, bars: bars, configuration: .init(), requireOpeningBar: true, checkCancellation: {})
    let grid = try #require(fitted)
    #expect(abs(grid.bpm - 120) < 0.02)
    #expect(abs(grid.firstBar - 12.38) < 0.02)
}

@Test func longMixGridRejectsLaterPhaseWhenAnOpeningRunDisagrees() throws {
    let beats = (0..<160).map { 1.2 + Double($0) * 0.5 }
    let earlyBars = [1, 5, 9, 13].map { beats[$0] }
    let laterBars = stride(from: 16, to: beats.count, by: 4).map { beats[$0] }
    let bars = earlyBars + laterBars
    #expect(try BeatThisGrid.fit(beats: beats, bars: bars, configuration: .init(), checkCancellation: {}) != nil)
    #expect(
        try BeatThisGrid.fit(
            beats: beats, bars: bars, configuration: .init(), requireOpeningBar: true, checkCancellation: {}) == nil)
}
