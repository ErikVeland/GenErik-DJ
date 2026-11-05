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
