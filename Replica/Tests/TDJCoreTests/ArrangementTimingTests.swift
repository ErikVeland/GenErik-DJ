import XCTest

@testable import TDJCore

final class ArrangementTimingTests: XCTestCase {
    func testAdaptiveGridCountsActualBeatsAcrossTempoChange() throws {
        let grid = try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000)
        let map = BeatGridMap(
            anchors: [.init(beat: 0, frame: 0), .init(beat: 16, frame: 8000), .init(beat: 32, frame: 24000)],
            sampleRate: 1000)
        let value = TrackArrangement(sections: [], landmarks: [], musicalEnd: 24000, rhythmicEnd: nil)
        let status = value.status(
            frame: 8000, fileEnd: 26000, sampleRate: 1000, timing: BeatTiming(fixed: grid, adaptive: map),
            reliableGrid: true, playing: true, rate: 1)
        XCTAssertEqual(status.barsRemaining, 4)
        XCTAssertEqual(status.musicSeconds, 16)
    }
    func testTempoRateAffectsSecondsWithoutChangingBarsAndPauseHoldsPulse() throws {
        let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000))
        let value = TrackArrangement(sections: [], landmarks: [], musicalEnd: 20000, rhythmicEnd: nil)
        let paused = value.status(
            frame: 10250, fileEnd: 22000, sampleRate: 1000, timing: timing, reliableGrid: true, playing: false, rate: 2)
        XCTAssertEqual(paused.barsRemaining, 5)
        XCTAssertEqual(paused.musicSeconds, 4.875)
        XCTAssertEqual(paused.pulse, 0)
    }
    func testPickupKeepsItsActualPositionAndDismissedLandmarkIsHidden() throws {
        let timing = BeatTiming(fixed: try BeatGrid(bpm: 120, anchorFrame: 0, sampleRate: 1000))
        let marks = [
            ArrangementLandmark(frame: 1200, name: "Vocal", kind: .vocal),
            ArrangementLandmark(frame: 500, name: "Dismissed", state: .dismissed),
        ]
        let value = TrackArrangement(sections: [], landmarks: marks, musicalEnd: 20000, rhythmicEnd: nil)
        let status = value.status(
            frame: 0, fileEnd: 22000, sampleRate: 1000, timing: timing, reliableGrid: true, playing: true, rate: 1)
        XCTAssertEqual(status.nextEvent, "VOCAL IN 1 BAR")
        XCTAssertEqual(value.landmarks[0].frame, 1200)
    }
}
