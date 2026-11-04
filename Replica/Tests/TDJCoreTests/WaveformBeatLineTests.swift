import Testing

@testable import TDJCore

@Test func waveformBeatLinesKeepPixelPositionsAndDownbeats() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000, downbeatOffset: 1)
    for width in [900, 1800, 2700] {
        let beats = WaveformLayers.beatLines(grid: grid, left: 48000, span: 108000, width: width)
        #expect(beats.map(\.x) == (0..<5).map { Double($0 * width) / 4.5 })
        #expect(beats.map(\.downbeat) == [false, false, false, true, false])
    }
}

@Test func waveformBeatLinesFollowAdaptiveTempoAcrossSegments() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let map = BeatGridMap(
        anchors: [.init(beat: 0, frame: 0), .init(beat: 4, frame: 96000), .init(beat: 8, frame: 176000)],
        sampleRate: 48000, downbeatOffset: 2)
    let beats = WaveformLayers.beatLines(grid: grid, adaptiveMap: map, left: 72000, span: 104000, width: 1040)
    #expect(beats.map(\.x) == [0, 240, 440, 640, 840, 1040])
    #expect(beats.map(\.downbeat) == [false, false, false, true, false, false])
}

@Test func waveformBeatLinesClipEdgesAndBoundOverviewWork() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 48000)
    let beats = WaveformLayers.beatLines(grid: grid, left: -12000, span: 48000, width: 200)
    #expect(beats.map(\.x) == [50, 150])
    #expect(beats.map(\.downbeat) == [true, false])
    #expect(WaveformLayers.beatLines(grid: grid, left: 0, span: 24000 * 300, width: 900).isEmpty)
    #expect(WaveformLayers.beatLines(grid: grid, left: .nan, span: 48000, width: 900).isEmpty)
}
