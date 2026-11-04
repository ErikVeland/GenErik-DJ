import Foundation
import Testing

@testable import TDJCore

@Test func gridCorrectionsKeepMusicalCoordinatesSeparate() throws {
    var grid = try BeatGrid(bpm: 120, anchorFrame: 11025, sampleRate: 44100)
    let original = grid
    try grid.halveBPM()
    #expect(grid.bpm == 60)
    #expect(grid.anchorFrame == original.anchorFrame)
    try grid.doubleBPM()
    #expect(grid == original)
    try grid.selectDownbeat(2)
    #expect(grid.isDownbeat(2))
    #expect(grid.isDownbeat(-2))
    #expect(!grid.isDownbeat(0))
    #expect(grid.frame(atBeat: 8) == 187425)
    #expect(grid.beat(atFrame: 187425) == 8)
    #expect(grid.fourBeatInspection(from: 0, direction: -1, endFrame: 100000) == 0)
    #expect(grid.fourBeatInspection(from: 95000, direction: 1, endFrame: 100000) == 100000)
}

@Test func draggingWaveformKeepsGridFixedInTheViewport() throws {
    let grid = try BeatGrid(bpm: 120, anchorFrame: 11025, sampleRate: 44100)
    let drag = GridDrag(grid: grid, viewportFrame: 30000, framesPerPoint: 100)
    let first = try drag.preview(translationPoints: 15)
    let second = try drag.preview(translationPoints: 30)
    #expect(first.grid.anchorFrame == 9525)
    #expect(second.grid.anchorFrame == 8025)
    #expect(first.grid.anchorFrame - first.viewportFrame == grid.anchorFrame - 30000)
    #expect(second.grid.anchorFrame - second.viewportFrame == grid.anchorFrame - 30000)
}

@Test func invalidGridAndTapInputsDoNotMutateValidState() throws {
    var grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 44100)
    #expect(throws: CoreError.invalidGrid) { try grid.setBPM(.nan) }
    #expect(throws: CoreError.invalidGrid) { try grid.selectDownbeat(4) }
    #expect(throws: CoreError.invalidGrid) { try grid.shiftWaveform(bySourceFrames: .infinity) }
    #expect(grid.bpm == 120 && grid.anchorFrame == 0)
    var tap = TapTempo()
    #expect(try tap.tap(atMonotonicSeconds: 0) == nil)
    #expect(try tap.tap(atMonotonicSeconds: 0.5) == nil)
    #expect(try tap.tap(atMonotonicSeconds: 1) == 120)
    #expect(throws: CoreError.insufficientTaps) { try tap.tap(atMonotonicSeconds: 1) }
}
